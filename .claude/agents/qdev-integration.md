# QDEV Integration Guide

## Что изменилось

Добавлен QDEV-агент (Quality DEV Verification) для проверки запускаемости кода между DEV и REVIEW этапами.

## Изменённые файлы

1. **.claude/agents/qdev.md** — новый агент QDEV
2. **.backlog/config.yml** — добавлен статус `qdev-check`

## Интеграция в PM процесс

### 1. Добавить QDEV timeout

В CLAUDE.md добавить в словарь TIMEOUTS:

```python
TIMEOUTS = {
    "SETUP": 10 * 60 * 1000,
    "GIT_SYNC": 5 * 60 * 1000,
    "SA": 30 * 60 * 1000,
    "SCRUM": 15 * 60 * 1000,
    "CONSOLIDATION": 10 * 60 * 1000,
    "DEV": 20 * 60 * 1000,
    "DEV_FIX": 25 * 60 * 1000,
    "QDEV": 10 * 60 * 1000,      # ← НОВЫЙ
    "REVIEW": 10 * 60 * 1000,
    "QA": 15 * 60 * 1000,
    "DEBUG": 15 * 60 * 1000,
}
```

### 2. Обновить статусы в CLAUDE.md

В секции "### Статусы" добавить:

```markdown
| → qdev-check | DEV завершил | `task_update(id, status="qdev-check")` |
| → code-review | QDEV прошёл | `task_update(id, status="code-review")` |
```

И обновить условие для code-review:

```markdown
| → code-review | QDEV одобрил | `task_update(id, status="code-review")` |
```

### 3. Интеграция в Фазу 3 (параллельный оркестратор)

В секции "### 3.LOOP — Главный цикл оркестрации" добавить новую очередь:

```python
# Сгруппировать по статусу
todo          = [t for t in all_tasks if t.status == "To Do"
                 and not_blocked(t)]
qdev_check    = [t for t in all_tasks if t.status == "qdev-check"]  # ← НОВАЯ ОЧЕРЕДЬ
code_review   = [t for t in all_tasks if t.status == "code-review"]
review_debug  = [t for t in all_tasks if t.status == "review-debug"]
```

В секции "#### Шаг D: Запустить ВСЕ агенты параллельно" добавить:

```python
# ── QDEV агенты ───────────────────────────────────────────────────
for task in qdev_check:
    qdev_role = Read(".claude/agents/qdev.md")
    Task(
        description=f"QDEV: {task.title}",
        prompt=f"""{qdev_role}
---
TASK_ID: {task.id}
Режим MCP: BACKLOG

Первое действие: backlog__task_get({task.id})
Проверить запускаемость кода.
По завершению добавить в notes: [PM-NOTIFY qdev-complete TASK_ID={task.id}]
        """,
        model="claude-sonnet-4-5",
        subagent_type="general-purpose",
        timeout=TIMEOUTS["QDEV"]
    )
```

### 4. Изменить переход после DEV

В DEV агенте (developer.md) изменить Шаг 6:

```markdown
6. Перевести задачи в qdev-check (вместо code-review):
   backlog__task_update(TASK_ID, status="qdev-check",
     notes="[DEV-LOG qdev-pending | ветка: {branch} | worktree: {WORKTREE_PATH}]")
```

### 5. Обновить таблицу статусов

В .backlog/config.yml статусы теперь в таком порядке:

```yaml
statuses:
  - To Do
  - In Progress
  - qdev-check      # ← НОВЫЙ
  - code-review
  - review-debug
  - ready-for-testing
  - review-human-await
  - Done
```

## Процесс работы

```
DEV → qdev-check → QDEV проверяет
                      ↓ PASS
                   code-review → REVIEW
                      ↓ PASS
                   ready-for-testing → QA

При FAIL: QDEV → review-debug → DEV исправляет
```
