# ФАЗА 3: РАЗРАБОТКА — ПАРАЛЛЕЛЬНЫЙ ОРКЕСТРАТОР

**Триггер:** человек явно подтвердил запуск.

**Принцип:** PM работает волнами. Каждая волна — запуск агентов для всех actionable задач. Цикл продолжается до завершения беклога.

**Workflow:**
```
DEV (todo) → QDEV (qdev-check) → REVIEW (code-review) → [цикл исправлений] → QA (ready-for-testing) → Done
```

## 3.0 Подготовка

```
developer_role = Read(".claude/agents/developer.md")
qdev_role      = Read(".claude/agents/qdev.md")
reviewer_role  = Read(".claude/agents/reviewer.md")
qa_role        = Read(".claude/agents/qa.md")
```

## 3.LOOP — Главный цикл

### Шаг A: Сканировать доску

```
backlog__task_list() → сгруппировать по статусу:

  todo:                задачи без блокирующих зависимостей → очередь DEV
  review-debug:        исправления по ревью → очередь DEV (fix)
  qdev-check:          ожидают проверку запускаемости → очередь QDEV
  code-review:         ожидают ревью → очередь REVIEW
  ready-for-testing:   ожидают тестирование → очередь QA
  review-human-await:  ожидают человека → эскалация (шаг F)
  done / cancelled:    пропустить
```

### Шаг B: Проверить завершение

```
Если все задачи в done или cancelled → перейти к 3.DONE
Если есть actionable задачи → перейти к шагу C
Если все задачи заблокированы → сообщить человеку, ждать
```

### Шаг C: Пометить задачи как активные

```
Для каждой задачи из очередей:
  backlog__task_update(task_id, notes="[AGENT-ACTIVE {timestamp}]")
```

### Шаг Cbis: REVIEW-DEBT Cleanup

```
Для задач в review-human-await:
  Проверить дату из [REVIEW-ESCALATION date:{date}]
  Если прошло > 7 дней → backlog__task_update(id, status="cancelled",
    notes="[PM-LOG auto-cancelled | reason: review-debt-timeout]")
```

### Шаг D: Запустить агентов

Запускать ВСЕ агенты параллельно в одном шаге.

**DEV агенты** (для задач из todo и review-debug):

```
Для каждой задачи из очереди DEV:
  Task(
    description="DEV: {task.title}",
    prompt=f"{developer_role}\n---\nTASK_ID: {task.id}\nEPIC_ID: {epic_id}\nРежим MCP: BACKLOG\nПервое действие: backlog__task_get({task.id})\nПо завершению: [PM-NOTIFY dev-complete TASK_ID={task.id}]",
    model="claude-sonnet-4-5",
    timeout=TIMEOUTS["DEV"] или TIMEOUTS["DEV_FIX"]
  )
```

**QDEV агенты** (для задач в qdev-check):

```
Для каждой задачи из очереди QDEV:
  Task(
    description="QDEV: {task.title}",
    prompt=f"{qdev_role}\n---\nTASK_ID: {task.id}\nРежим MCP: BACKLOG\nПервое действие: backlog__task_get({task.id})\nПо завершению: [PM-NOTIFY qdev-complete TASK_ID={task.id}]",
    model="claude-sonnet-4-5",
    timeout=TIMEOUTS["QDEV"]
  )
```

**REVIEW агенты** (для задач в code-review):

```
Для каждой задачи из очереди REVIEW:
  epic_id = task.parent_id или task.id
  Task(
    description="REVIEW: {task.title}",
    prompt=f"{reviewer_role}\n---\nEPIC_ID: {epic_id}\nTASK_IDs: {task.id}\nРежим MCP: BACKLOG\nПервое действие: backlog__task_get({epic_id})\nПо завершению: [PM-NOTIFY review-complete EPIC_ID={epic_id}]",
    model="claude-opus-4-5",
    timeout=TIMEOUTS["REVIEW"]
  )
```

**QA агенты** (для задач в ready-for-testing):

```
Для каждой задачи из очереди QA:
  Извлечь worktree и branch из [DEV-LOG] в notes задачи
  Task(
    description="QA: {task.title}",
    prompt=f"{qa_role}\n---\nTASK_ID: {task.id}\nWorktree: {worktree}\nВетка: {branch}\nРежим MCP: BACKLOG\nПервое действие: backlog__task_get({task.id})\nПо завершению: [PM-NOTIFY qa-complete TASK_ID={task.id}]",
    model="claude-sonnet-4-5",
    timeout=TIMEOUTS["QA"]
  )
```

### Шаг E: После завершения волны

```
Для каждой обработанной задачи:
  Заменить [AGENT-ACTIVE на [AGENT-DONE в notes
```

### Шаг F: Эскалация review-human-await

```
Для задач в review-human-await:
  Сообщить человеку:
    "Задача {id} отклонена 3+ раз. Варианты:
      A) Вернуть в review-debug (DEV продолжит)
      B) Закрыть как cancelled
      C) Ручной ревью"
  Ждать решения.
```

### Шаг G: Следующая волна

```
→ Вернуться к шагу A
```

## 3.DONE — Финальный отчёт

```
backlog__task_list() → подсчитать:
  done: {N}, cancelled: {N}

"Разработка завершена.
  Выполнено задач: {N}
  Технический долг: {M} задач [REVIEW-DEBT]
  Полный список: backlog browser"
```

---

## HELPER: Связь TASK_ID ↔ REVIEW_TASK_ID

```
Извлечение REVIEW задачи из notes:
  Искать паттерн [REVIEW-TASK-ID {task_id}] в notes задачи
  Если не найден → fallback: искать задачи с "[REVIEW]" и task_id в названии
```

---

**После 3.DONE → перейти к завершению:**
```
Read(".claude/phases/phase-4-completion.md")
```
