# ФАЗА 2: SCRUM-МАСТЕР

**Триггер:** SA завершил работу, подзадачи созданы, артефакты консолидированы.

## 2.1 Создать задачу SCRUM-мастера

```
scrum_task_id = backlog__task_create(
  title="[SCRUM] {эпик}",
  description="""
Эпик: {analyst_task_id}

Задачи:
1. Проверить качество каждой подзадачи (описание, PASS/FAIL, сценарий, depends_on)
2. Token Budget Gate: 175 000 токенов на задачу. Если превышает → разбить.
3. Записать [SCRUM-REPORT] в notes эпика.
  """,
  acceptance_criteria="PASS: [SCRUM-REPORT] записан, все задачи прошли Token Budget Gate",
  depends_on=[analyst_task_id]
)
```

## 2.2 Запустить SCRUM-мастера

```
scrum_role = Read(".claude/agents/scrum-master.md")

Task(
  description="SCRUM верификация: {эпик}",
  prompt=f"{scrum_role}\n---\nSCRUM_TASK_ID: {scrum_task_id}\nEPIC_ID: {analyst_task_id}\nРежим MCP: BACKLOG\n\nПервое действие: backlog__task_get({scrum_task_id})",
  model="claude-sonnet-4-5",
  timeout=TIMEOUTS["SCRUM"]
)
```

## ⛔ CHECKPOINT

Полная остановка после [SCRUM-REPORT]. Сообщить человеку:

**Блок 1 — Беклог задач**

```
backlog__task_list() → задачи со статусом todo

"Беклог готов. Создано {N} задач:
  {TASK-1}: {название} — {критерий PASS}
  {TASK-2}: {название} — {критерий PASS}
  ...
Полный список: backlog browser"
```

**Блок 2 — Контрольные точки**

```
Bash(entire log --limit 5 2>/dev/null || echo "Entire недоступен")

"Для отката: entire rewind {метка}"
```

**Блок 3 — Подтверждение**

```
"Готов запустить разработку. Напиши: да / go / запускай"

Ждать ЯВНОГО подтверждения. Молчание ≠ подтверждение.
```

---

**После подтверждения → перейти к Фазе 3:**
```
Read(".claude/phases/phase-3-dev.md")
```
