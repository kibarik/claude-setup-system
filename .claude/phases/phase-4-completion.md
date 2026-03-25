# ФАЗЫ 4-6: ТЕСТИРОВАНИЕ, QA GATE, ЗАВЕРШЕНИЕ

## ФАЗА 4: ТЕСТИРОВАНИЕ

**Триггер:** задачи в `ready-for-testing` после одобрения REVIEW-агентом.

```
Извлечь из notes задачи:
  worktree_path — из [DEV-LOG worktree:{path}]
  branch_name   — из [DEV-LOG branch:{name}]

qa_role = Read(".claude/agents/qa.md")

Task(
  description="QA: {название}",
  prompt=f"{qa_role}\n---\nTASK_ID: {task_id}\nWorktree: {worktree_path}\nВетка: {branch_name}\nРежим MCP: BACKLOG\nПервое действие: backlog__task_get({task_id})\nПротестируй E2E. Вердикт без реального вывода тестов не принимается.",
  model="claude-sonnet-4-5",
  timeout=TIMEOUTS["QA"]
)
```

**PASS** → Фаза 5

**FAIL** — для каждого бага:

```
backlog__task_create(title="[BUG] {описание}",
                     description="шаги + ожидаемое + факт",
                     depends_on=[task_id])
backlog__task_update(task_id, status="todo",
                     notes="[PM-LOG bug_filed | evidence: {bug_id}]")
→ Обратно в Фазу 3 для бага
```

---

## ФАЗА 5: QA GATE

**Триггер:** QA вернул PASS с `evidence` в логе.

```
backlog__task_get(task_id) → критерии и сценарий демонстрации

Проверить ключевые элементы:
  Если Browser MCP доступен → playwright_navigate + screenshot
  Если недоступен → Task(prompt="Предоставь логи/скриншоты для сценария")

FAIL:
  backlog__task_create(title="[ДОРАБОТКА] {проблема}", depends_on=[task_id])
  НЕ закрывать task — ждать исправления

PASS:
  Валидация: проверить что "ready-for-testing" есть в истории статусов задачи
  Если нет → заблокировать переход, [PM-LOG action:blocked]
  Если да  → backlog__task_update(task_id, status="done",
               notes="[PM-LOG verified | evidence: сценарий X пройден]")
```

---

## ФАЗА 6: ЗАВЕРШЕНИЕ

```
backlog__task_list() → финальный чек-лист:
  [ ] Все задачи: done или cancelled
  [ ] Каждый переход: [PM-LOG] с evidence
  [ ] Нет задач с depends_on на незакрытые
  [ ] E2E тесты зелёные

Сообщить человеку → ждать обратной связи.
```
