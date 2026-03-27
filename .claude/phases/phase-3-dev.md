# ФАЗА 3: РАЗРАБОТКА — НЕПРЕРЫВНЫЙ ЦИКЛ

**Триггер:** человек явно подтвердил запуск.

---

## КРИТИЧЕСКОЕ ПРАВИЛО: КАК РАБОТАЕТ Task()

```
Task() — это БЛОКИРУЮЩИЙ вызов.

PM вызывает Task() → агент работает → агент завершается → Task() возвращает управление PM → PM продолжает.

PM НЕ "ждёт" и НЕ "завершает сессию". PM ОСТАЁТСЯ внутри цикла.
Task() сам ждёт завершения агента. PM не нужно ничего делать для ожидания.

ЗАПРЕЩЕНО:
  ✗ Писать "ожидаю завершения агента" и остановиться
  ✗ Писать отчёт и завершить ход до возврата Task()
  ✗ Просить пользователя "подождать" или "проверить позже"

ПРАВИЛЬНО:
  ✓ Вызвать Task() — PM заблокирован пока агент работает
  ✓ Task() вернул управление — PM СРАЗУ проверяет Backlog
  ✓ PM запускает следующий Task() — цикл продолжается
  ✓ PM отчитывается МЕЖДУ Task() вызовами, не вместо них
```

---

## ПРИНЦИП

PM работает как непрерывный цикл внутри одной сессии:

```
while (есть незавершённые задачи):
    1. Сканировать доску
    2. Выбрать следующую actionable задачу
    3. Запустить агента через Task()  ← БЛОКИРУЕТ, PM ждёт здесь
    4. Агент завершился → PM получил управление обратно
    5. Проверить результат в Backlog
    6. Составить краткий отчёт
    7. → goto 1
```

PM **никогда** не выходит из этого цикла до завершения всех задач или явной команды человека.

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

## 3.LOOP — Непрерывный цикл

### ШАГ 1: СКАНИРОВАТЬ ДОСКУ

```
all_tasks = backlog__task_list()

Сгруппировать:
  actionable_todo:     "To Do", зависимости разрешены, нет [AGENT-ACTIVE]
  actionable_fix:      "review-debug", нет [AGENT-ACTIVE]
  awaiting_qdev:       "qdev-check", нет [AGENT-ACTIVE]
  awaiting_review:     "code-review", нет [AGENT-ACTIVE]
  awaiting_qa:         "ready-for-testing", нет [AGENT-ACTIVE]
  human_await:         "review-human-await"
  completed:           "done" или "cancelled"
```

### ШАГ 2: ПРОВЕРИТЬ ЗАВЕРШЕНИЕ

```
Все задачи в done/cancelled → перейти к 3.DONE
Нет actionable задач → все заблокированы → сообщить человеку, ждать ввода
Есть actionable → перейти к ШАГ 3
```

### ШАГ 3: ВЫБРАТЬ СЛЕДУЮЩУЮ ЗАДАЧУ

PM выбирает ОДНУ задачу с наивысшим приоритетом:

```
Приоритет (сверху вниз — первая непустая группа):
  1. awaiting_qdev      — самые быстрые, разблокируют review
  2. awaiting_review    — разблокируют QA
  3. awaiting_qa        — финальная проверка
  4. actionable_fix     — исправления по ревью
  5. actionable_todo    — новые задачи
```

Выбрать первую задачу из группы с наивысшим приоритетом.

### ШАГ 4: ЗАПУСТИТЬ АГЕНТА

**PM вызывает Task() и ЖДЁТ его завершения. Это блокирующий вызов.**

#### Перед вызовом Task():

```
backlog__task_update(task.id, notes="[AGENT-ACTIVE {timestamp}]")
```

#### Вызов Task() — в зависимости от типа:

**DEV (todo или review-debug):**
```
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
  timeout=TIMEOUTS["DEV"]
)
```

**DEV (продолжение после timeout):**
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
По завершению добавь в notes: [PM-NOTIFY dev-complete TASK_ID={task.id}]
  """,
  model="claude-sonnet-4-5",
  timeout=TIMEOUTS["DEV_FIX"]
)
```

**QDEV (qdev-check):**
```
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

**REVIEW (code-review):**
```
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

**QA (ready-for-testing):**
```
Извлечь worktree и branch из [DEV-LOG] в notes

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

### ШАГ 5: ОБРАБОТАТЬ РЕЗУЛЬТАТ

**Task() вернул управление. PM СРАЗУ читает Backlog и обрабатывает.**

```
task_data = backlog__task_get(task.id)
notes = task_data.notes

# Снять метку активного агента
Заменить [AGENT-ACTIVE в notes на [AGENT-DONE {timestamp}]
backlog__task_update(task.id, notes=updated_notes)
```

**Определить что произошло:**

```
ЕСЛИ [PM-NOTIFY dev-complete] в notes:
  → DEV завершил. Статус в Backlog уже обновлён агентом (qdev-check).
  → На следующем тике QDEV подхватит.

ЕСЛИ [PM-NOTIFY qdev-complete] в notes:
  → Посмотреть [QDEV-LOG pass] или [QDEV-LOG fail]
  → pass → статус code-review (REVIEW на следующем тике)
  → fail → статус review-debug (DEV fix на следующем тике)

ЕСЛИ [PM-NOTIFY review-complete] в notes:
  → Посмотреть [REVIEW-REPORT] verdict
  → ОДОБРИТЬ → статус ready-for-testing (QA на следующем тике)
  → ОТКЛОНИТЬ → статус review-debug (DEV fix на следующем тике)
  → review-human-await → эскалация человеку

ЕСЛИ [PM-NOTIFY qa-complete] в notes:
  → Посмотреть [QA-REPORT]
  → PASS → задача done
  → FAIL → баги созданы в Backlog, DEV fix на следующем тике

ЕСЛИ нет [PM-NOTIFY] (timeout или crash):
  → Агент не успел. Составить отчёт о прогрессе (см. TIMEOUT ниже).
```

### ШАГ 6: ОТЧЁТ

PM кратко сообщает человеку что произошло:

```
[PM-LOG] ВОЛНА {N} — СТАТУС
  ────────────────────────────
  TASK-{id}: {title}
    Результат: {dev-complete / qdev-pass / review-одобрен / qa-pass / timeout}
    Прогресс:
      - ✅ {что сделано}
      - ❌ {что не сделано, если timeout}
    Время: {duration}
  ────────────────────────────

  Следующее действие:
    {какую задачу PM запустит сейчас}
```

### ШАГ 7: ЭСКАЛАЦИЯ (если нужна)

```
Если есть задачи в review-human-await:
  Спросить человека:
    "Задача {id} отклонена 3+ раз. A) DEV fix B) Cancel C) Ручной ревью"

  НЕ останавливать цикл — если есть другие actionable задачи, запускать их.
  Эскалация обрабатывается при следующем вводе человека.
```

### ШАГ 8: REVIEW-DEBT CLEANUP (каждые 5 итераций)

```
Каждые 5 итераций:
  Для задач в review-human-await старше 7 дней:
    backlog__task_update(id, status="cancelled",
      notes="[PM-LOG auto-cancelled | reason: review-debt-timeout]")
```

### ШАГ 9: GOTO ШАГ 1

```
→ Вернуться к ШАГ 1 (сканирование доски)
→ НИКОГДА не останавливаться между итерациями
→ Цикл продолжается пока есть незавершённые задачи
```

---

## ОБРАБОТКА TIMEOUT

Когда агент завершился по timeout (Task() вернул управление, но нет [PM-NOTIFY]):

```
[PM-LOG] ВОЛНА {N} — TIMEOUT АГЕНТА
  Задача: TASK-{id} ({title})
  Прогресс:
    - ✅ / ❌ Brainstorm ([DEV-LOG research-doc] в notes?)
    - ✅ / ❌ План ([DEV-LOG plan-ready] в notes?)
    - ✅ / ❌ Ветка ([DEV-LOG branch:] в notes?)
    - ✅ / ❌ Подзадачи (backlog__task_list → дочерние?)
    - ✅ / ❌ Код (git diff в worktree не пустой?)
    - ✅ / ❌ Тесты
    - ✅ / ❌ Коммит
  Диагностика:
    Время: {duration} из {timeout}
    Причина: контекст исчерпан / таймаут
  ────────────────────────────
  Решение:
    A) Запустить продолжение (рекомендуется если план создан)
    B) Вернуть в review-debug
    C) Отменить
  → Запускаю продолжение.
```

PM автоматически выбирает опцию A если план создан. Если ничего не сделано — спрашивает человека.

---

## ПРАВИЛА PM В ЦИКЛЕ

```
PM ДЕЛАЕТ:
  ✓ Вызывает Task() и ЖДЁТ завершения (блокирующий вызов)
  ✓ СРАЗУ после Task() — проверяет Backlog
  ✓ СРАЗУ запускает следующий Task() если есть actionable задачи
  ✓ Кратко отчитывается между Task() вызовами
  ✓ Обрабатывает timeout — запускает продолжение
  ✓ Непрерывно крутит цикл пока есть работа

PM НЕ ДЕЛАЕТ:
  ✗ НЕ пишет "ожидаю завершения" и не останавливается
  ✗ НЕ завершает сессию пока цикл не дошёл до 3.DONE
  ✗ НЕ прерывает работающих агентов
  ✗ НЕ просит человека подождать или проверить позже
  ✗ НЕ меняет статусы задач которые ведёт агент
  ✗ НЕ перезапускает агента без причины
```

---

## ПРИМЕР ПОЛНОГО ЦИКЛА

```
Итерация 1:
  Доска: TASK-41 (To Do), TASK-42 (To Do)
  Приоритет: TASK-41 (первая в списке)
  → Task(DEV, TASK-41)             ← PM заблокирован, DEV работает 18 мин
  → Task() вернул управление
  → backlog__task_get(TASK-41) → статус qdev-check, [DEV-LOG branch: main/TASK-41]
  → Отчёт: "TASK-41: DEV завершён, ветка создана, ожидает QDEV"

Итерация 2:
  Доска: TASK-41 (qdev-check), TASK-42 (To Do)
  Приоритет: TASK-41 QDEV (приоритет 1) перед TASK-42 DEV (приоритет 5)
  → Task(QDEV, TASK-41)            ← PM заблокирован, QDEV работает 3 мин
  → Task() вернул управление
  → [QDEV-LOG pass] → статус code-review
  → Отчёт: "TASK-41: QDEV pass, ожидает Review"

Итерация 3:
  Доска: TASK-41 (code-review), TASK-42 (To Do)
  Приоритет: TASK-41 REVIEW (приоритет 2) перед TASK-42 DEV (приоритет 5)
  → Task(REVIEW, TASK-41)          ← PM заблокирован, REVIEW работает 8 мин
  → Task() вернул управление
  → [REVIEW-REPORT verdict: ОДОБРИТЬ] → статус ready-for-testing
  → Отчёт: "TASK-41: Review одобрен, ожидает QA"

Итерация 4:
  Доска: TASK-41 (ready-for-testing), TASK-42 (To Do)
  Приоритет: TASK-41 QA (приоритет 3) перед TASK-42 DEV (приоритет 5)
  → Task(QA, TASK-41)              ← PM заблокирован, QA работает 10 мин
  → [QA-REPORT PASS] → задача done
  → Отчёт: "TASK-41: QA passed. Done."

Итерация 5:
  Доска: TASK-41 (done), TASK-42 (To Do)
  → Task(DEV, TASK-42)             ← PM переключается на следующую задачу
  → ...цикл продолжается...
```

---

## 3.DONE — Финальный отчёт

```
backlog__task_list() → подсчитать:
  done: {N}, cancelled: {N}

"Разработка завершена.
  Выполнено: {N} задач за {M} итераций
  Технический долг: {K} задач [REVIEW-DEBT]
  Timeouts: {T} (из них продолжены: {P})
  Полный список: backlog browser"
```

---

**После 3.DONE → перейти к завершению:**
```
Read(".claude/phases/phase-4-completion.md")
```
