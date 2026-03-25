# ФАЗА 3: РАЗРАБОТКА — POLLING ОРКЕСТРАТОР

**Триггер:** человек явно подтвердил запуск.

## ПРИНЦИП

PM работает как диспетчер: запускает агентов, периодически проверяет статусы в Backlog, реагирует на изменения. PM **НИКОГДА** не прерывает работающих агентов. Агенты сами обновляют статусы в Backlog. PM только читает статусы и принимает решения.

```
ЦИКЛ PM:
  1. Проверить Backlog → что изменилось?
  2. Есть новые задачи для запуска? → запустить агентов
  3. Есть завершённые/заблокированные? → обработать
  4. Сообщить статус человеку
  5. Подождать → повторить
```

**Workflow задачи:**
```
DEV (todo) → QDEV (qdev-check) → REVIEW (code-review) → QA (ready-for-testing) → Done
                                        ↓ FAIL
                                  review-debug → DEV (fix)
```

---

## 3.0 Подготовка

```
developer_role = Read(".claude/agents/developer.md")
qdev_role      = Read(".claude/agents/qdev.md")
reviewer_role  = Read(".claude/agents/reviewer.md")
qa_role        = Read(".claude/agents/qa.md")
```

---

## 3.LOOP — Главный цикл оркестрации

### ШАГ 1: СКАНИРОВАТЬ ДОСКУ

```
all_tasks = backlog__task_list()

Сгруппировать по статусу:
  actionable_todo:     статус "To Do", зависимости разрешены, нет метки [AGENT-ACTIVE]
  actionable_fix:      статус "review-debug", нет метки [AGENT-ACTIVE]
  awaiting_qdev:       статус "qdev-check", нет метки [AGENT-ACTIVE]
  awaiting_review:     статус "code-review", нет метки [AGENT-ACTIVE]
  awaiting_qa:         статус "ready-for-testing", нет метки [AGENT-ACTIVE]
  in_progress:         статус "In Progress" И есть метка [AGENT-ACTIVE]
  human_await:         статус "review-human-await"
  completed:           статус "done" или "cancelled"
```

### ШАГ 2: ОЦЕНИТЬ СИТУАЦИЮ И СОСТАВИТЬ ОТЧЁТ

PM формирует отчёт текущего состояния:

```
[PM-LOG] ВОЛНА {N} — ОБЗОР ДОСКИ
  Всего задач: {total}
  ────────────────────────────
  ✅ Завершено:        {completed}
  🔄 В работе (агент): {in_progress}
  📋 Ожидает запуска:  {actionable_todo}
  🔧 На исправление:   {actionable_fix}
  🔍 Ожидает QDEV:     {awaiting_qdev}
  📝 Ожидает Review:   {awaiting_review}
  🧪 Ожидает QA:       {awaiting_qa}
  ⚠️  Ожидает человека: {human_await}
  ────────────────────────────

  Детали работающих агентов:
  {для каждой in_progress задачи:}
    TASK-{id}: {title}
      Запущен: {время из [AGENT-ACTIVE]}
      Последний лог: {последняя строка [DEV-LOG] или [QDEV-LOG]}

  Что можно запустить сейчас:
  {список actionable задач с типом агента}
```

### ШАГ 3: ПРОВЕРИТЬ ЗАВЕРШЕНИЕ

```
Если все задачи в done или cancelled:
  → Перейти к 3.DONE

Если нет actionable задач И нет in_progress:
  → Все заблокированы. Сообщить человеку, ждать.

Если есть in_progress но нет actionable:
  → Агенты работают. Ждать завершения текущего Task(). (см. ШАГ 5)
```

### ШАГ 4: ЗАПУСТИТЬ НОВЫХ АГЕНТОВ

**Принцип: запускать только то, что готово ПРЯМО СЕЙЧАС. Не ждать пока всё соберётся.**

**Приоритет запуска:**

```
1. QDEV (qdev-check)       — самые быстрые, разблокируют review
2. REVIEW (code-review)     — разблокируют QA или возвращают на fix
3. QA (ready-for-testing)   — финальная проверка
4. DEV fix (review-debug)   — исправления по ревью
5. DEV new (To Do)          — новые задачи
```

**Для каждой actionable задачи — запустить соответствующего агента:**

#### DEV (новая задача или fix)

```
backlog__task_update(task.id, notes="[AGENT-ACTIVE {timestamp}]")

Task(
  description="DEV: {task.title}",
  prompt=f"""{developer_role}
---
TASK_ID: {task.id}
EPIC_ID: {epic_id}
Режим MCP: BACKLOG

Первое действие: backlog__task_get({task.id})
Работай автономно. Обновляй статусы в Backlog по мере прогресса.
По завершению добавь в notes: [PM-NOTIFY dev-complete TASK_ID={task.id}]
  """,
  model="claude-sonnet-4-5",
  timeout=TIMEOUTS["DEV"] или TIMEOUTS["DEV_FIX"]
)
```

#### QDEV (проверка запускаемости)

```
backlog__task_update(task.id, notes="[AGENT-ACTIVE {timestamp}]")

Task(
  description="QDEV: {task.title}",
  prompt=f"""{qdev_role}
---
TASK_ID: {task.id}
Режим MCP: BACKLOG

Первое действие: backlog__task_get({task.id})
По завершению добавь в notes: [PM-NOTIFY qdev-complete TASK_ID={task.id}]
  """,
  model="claude-sonnet-4-5",
  timeout=TIMEOUTS["QDEV"]
)
```

#### REVIEW (code review)

```
backlog__task_update(task.id, notes="[AGENT-ACTIVE {timestamp}]")
epic_id = task.parent_id или task.id

Task(
  description="REVIEW: {task.title}",
  prompt=f"""{reviewer_role}
---
EPIC_ID: {epic_id}
TASK_IDs: {task.id}
Режим MCP: BACKLOG

Первое действие: backlog__task_get({epic_id})
По завершению добавь в notes: [PM-NOTIFY review-complete EPIC_ID={epic_id}]
  """,
  model="claude-opus-4-5",
  timeout=TIMEOUTS["REVIEW"]
)
```

#### QA (тестирование)

```
Извлечь worktree и branch из [DEV-LOG] в notes задачи

backlog__task_update(task.id, notes="[AGENT-ACTIVE {timestamp}]")

Task(
  description="QA: {task.title}",
  prompt=f"""{qa_role}
---
TASK_ID: {task.id}
Worktree: {worktree}
Ветка: {branch}
Режим MCP: BACKLOG

Первое действие: backlog__task_get({task.id})
По завершению добавь в notes: [PM-NOTIFY qa-complete TASK_ID={task.id}]
  """,
  model="claude-sonnet-4-5",
  timeout=TIMEOUTS["QA"]
)
```

### ШАГ 4b: ОБРАБОТКА ЗАВЕРШЁННОГО АГЕНТА

**После того как Task() вернул управление PM-у:**

```
Прочитать обновлённые notes задачи: backlog__task_get(task.id)

ЕСЛИ [PM-NOTIFY dev-complete]:
  → DEV завершил. Проверить текущий статус задачи в Backlog.
  → Статус qdev-check → QDEV будет запущен на следующем тике
  → Снять метку: [AGENT-ACTIVE] → [AGENT-DONE {timestamp}]

ЕСЛИ [PM-NOTIFY qdev-complete]:
  → Проверить вердикт (pass/fail) из [QDEV-LOG]
  → Статус code-review → REVIEW на следующем тике
  → Статус review-debug → DEV fix на следующем тике
  → Снять метку [AGENT-ACTIVE]

ЕСЛИ [PM-NOTIFY review-complete]:
  → Проверить вердикт из [REVIEW-REPORT]
  → Статус ready-for-testing → QA на следующем тике
  → Статус review-debug → DEV fix на следующем тике
  → Статус review-human-await → эскалация (ШАГ 6)
  → Снять метку [AGENT-ACTIVE]

ЕСЛИ [PM-NOTIFY qa-complete]:
  → Проверить вердикт из [QA-REPORT]
  → PASS → задача done
  → FAIL → баги созданы, DEV fix на следующем тике
  → Снять метку [AGENT-ACTIVE]

ЕСЛИ [TIMEOUT] (агент не успел):
  → Оценить прогресс (см. ОБРАБОТКА TIMEOUT ниже)
  → Снять метку [AGENT-ACTIVE]
```

### ШАГ 5: СЛЕДУЮЩИЙ ТИК

```
→ Вернуться к ШАГ 1 (сканирование доски)
```

PM не ждёт фиксированное время. Цикл работает так:
- Запустил агента → агент завершился (или timeout) → сканировать доску → запустить следующих → повторить

Каждый раз PM видит актуальное состояние всех задач и принимает решение что делать дальше.

### ШАГ 6: ЭСКАЛАЦИЯ (review-human-await)

```
Для задач в review-human-await:
  "Задача {id} отклонена 3+ раз.
   Варианты:
     A) Вернуть в review-debug — DEV продолжит
     B) Закрыть как cancelled
     C) Ручной ревью
   Скажи A/B/C."

Ждать решения. НЕ блокировать другие задачи.
Остальные задачи продолжают обрабатываться в цикле.
```

### ШАГ 7: REVIEW-DEBT CLEANUP (каждые 5 тиков)

```
Каждые 5 итераций цикла:
  Для задач в review-human-await:
    Проверить дату из [REVIEW-ESCALATION date:{date}]
    Если прошло > 7 дней:
      backlog__task_update(id, status="cancelled",
        notes="[PM-LOG auto-cancelled | reason: review-debt-timeout]")
```

---

## ПРАВИЛА PM В ЦИКЛЕ

```
PM ДЕЛАЕТ:
  ✓ Сканирует Backlog (backlog__task_list)
  ✓ Читает notes задач (backlog__task_get)
  ✓ Запускает агентов (Task())
  ✓ Обновляет метки [AGENT-ACTIVE] / [AGENT-DONE]
  ✓ Формирует отчёт для человека
  ✓ Принимает решения по timeout/блокировкам
  ✓ Эскалирует review-human-await

PM НЕ ДЕЛАЕТ:
  ✗ НЕ прерывает работающих агентов
  ✗ НЕ ждёт завершения ВСЕХ агентов перед следующим действием
  ✗ НЕ выполняет код/анализ сам
  ✗ НЕ меняет статусы задач которые ведёт агент (агент сам обновляет)
  ✗ НЕ перезапускает агента без причины (timeout, crash, блокировка)
```

---

## ФОРМАТ ОТЧЁТА PM (после каждого тика)

```
[PM-LOG] ВОЛНА {N} — СТАТУС
  ────────────────────────────
  TASK-{id}: {title}
    Статус: {текущий статус в Backlog}
    Агент: {тип} | {работает / завершён / timeout}
    Прогресс:
      - ✅ {что сделано — из notes задачи}
      - ❌ {что не сделано}
    Время работы: {duration}
  ────────────────────────────

  Решения:
    TASK-{id}: {что PM решил — запустить, ждать, эскалировать}

  Следующие действия:
    {список задач к запуску на следующем тике}
```

---

## ОБРАБОТКА TIMEOUT — ПРОДОЛЖЕНИЕ РАБОТЫ

Когда агент завершился по timeout, PM оценивает прогресс и решает:

```
[PM-LOG] ВОЛНА {N} — TIMEOUT АГЕНТА
  Задача: TASK-{id} ({title})
  Прогресс DEV-агента:
    - ✅ / ❌ Brainstorm завершён
    - ✅ / ❌ План реализации создан
    - ✅ / ❌ Ветка создана
    - ✅ / ❌ Подзадачи в Backlog
    - ✅ / ❌ Код написан (git diff)
    - ✅ / ❌ Тесты
    - ✅ / ❌ Коммиты
  Диагностика:
    Время: {start} → {end} ({duration} из {timeout})
    Причина: {контекст исчерпан / таймаут / ошибка}
    Статус: {текущий статус в Backlog}
  ────────────────────────────
  Решение:
    A) Запустить нового DEV-агента с продолжением (рекомендуется)
       → Агент получит TASK_ID и начнёт с того места где остановился
       → Timeout: DEV_FIX (25 мин)
    B) Перевести в review-debug для перезапуска
    C) Отменить задачу
```

**Продолжение работы агента (опция A):**

```
Task(
  description="DEV (продолжение): {task.title}",
  prompt=f"""{developer_role}
---
TASK_ID: {task.id}
EPIC_ID: {epic_id}
Режим MCP: BACKLOG
РЕЖИМ: ПРОДОЛЖЕНИЕ

Предыдущий агент не завершил работу.
Первое действие: backlog__task_get({task.id})
Прочитай notes — там записан прогресс предыдущего агента.
Продолжи с того места где остановился.
НЕ повторяй уже выполненные шаги (brainstorm, план, ветка).
  """,
  model="claude-sonnet-4-5",
  timeout=TIMEOUTS["DEV_FIX"]
)
```

---

## 3.DONE — Финальный отчёт

```
backlog__task_list() → подсчитать:
  done: {N}, cancelled: {N}

"Разработка завершена.
  Выполнено: {N} задач за {M} волн
  Технический долг: {K} задач [REVIEW-DEBT]
  Timeouts: {T} (из них продолжены: {P})
  Полный список: backlog browser"
```

---

## HELPER: Связь TASK_ID ↔ REVIEW_TASK_ID

```
Извлечение REVIEW задачи из notes:
  Искать [REVIEW-TASK-ID {task_id}] в notes
  Fallback: искать задачи с "[REVIEW]" и task_id в названии
```

---

**После 3.DONE → перейти к завершению:**
```
Read(".claude/phases/phase-4-completion.md")
```
