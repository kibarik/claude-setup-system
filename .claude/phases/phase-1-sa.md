# ФАЗА 1: SA — АНАЛИТИК

**Триггер:** INTAKE завершён.

## 1.0 Подтвердить доступность Spec-Kitty

```
Bash(ls .claude/commands/spec-kitty.*.md 2>/dev/null | wc -l)
Если < 5 → предложить установку через Setup-агента
Если ≥ 5 → продолжить
```

## 1.0b Проверить статус Serena и Context7

```
Bash(claude mcp list 2>/dev/null | grep -i serena  || echo "NOT_FOUND") → serena_ok
Bash(claude mcp list 2>/dev/null | grep -i context7 || echo "NOT_FOUND") → ctx7_ok
```

## 1.1 Создать задачу аналитика

```
analyst_task_id = backlog__task_create(
  title="[ANALYST] {название}",
  description="""
## Бизнес-контекст
{из INTAKE — проблема, кто страдает}

## Пользователь и его победа
{из INTAKE}

## Сценарий демонстрации
{шаг 1 → шаг 2 → ожидаемый результат}

## Критерии завершённости
{PASS если ... / FAIL если ...}

## Ограничения и зависимости
{технологии, сроки, блокеры}

## Существующие артефакты
{ссылки, файлы}
  """,
  acceptance_criteria="PASS: [SA-REPORT] в notes, подзадачи созданы с PASS/FAIL критериями"
)
```

## 1.2 Создать PM-CHECK задачу

**Выполняется ВСЕГДА для каждой analyst_task_id.**

```
pm_check_id = backlog__task_create(
  title="[PM-CHECK] Проверить результат SA: {название}",
  description="""
[ ] [SA-REPORT] присутствует в notes
[ ] Подзадачи созданы через MCP с PASS/FAIL критериями
[ ] Зависимости (depends_on) проставлены
[ ] [SA-ASSUMPTION] задокументированы
  """,
  depends_on=[analyst_task_id]
)
```

## 1.3 Запустить SA агента

```
analyst_role = Read(".claude/agents/analyst.md")

# Валидация: файл должен содержать SA-роль
Обязательные маркеры: "ФАЗА 0", "Explore", "SA-REPORT"
Запрещённые маркеры: "ФАЗА 3: РАЗРАБОТКА", "DEV-агент"
Если запрещённые найдены → СТОП: конфигурационная ошибка

tools_context = """
Доступные MCP:
  Backlog: доступен
  Serena: {serena_ok} — если да, используй для навигации по коду
  Context7: {ctx7_ok} — если да, используй для документации библиотек
"""

Task(
  description="SA аналитика: {название задачи}",
  prompt=f"{analyst_role}\n---\nTASK_ID: {analyst_task_id}\nРежим MCP: BACKLOG\n{tools_context}\nПервое действие: backlog__task_get({analyst_task_id})",
  model="claude-opus-4-5",
  timeout=TIMEOUTS["SA"]
)
```

### 1.3b Протокол взаимодействия с SA

SA может задавать вопросы пользователю. Это нормально.

```
Когда SA задаёт вопрос:
  1. Показать вопрос пользователю дословно
  2. Ждать ответ
  3. Сохранить решение:
     backlog__task_update(analyst_task_id,
       notes="[SA-DECISION] Вопрос: {X} | Решение: {Y}")
  4. Передать ответ агенту
```

## 1.4 Мониторинг

```
Task() завершился → backlog__task_get(analyst_task_id) → найти [SA-REPORT]
Есть → перейти к 1.5
Нет  → повторить Task() с инструкцией завершить [SA-REPORT]
```

### 1.4b /compact после SA

```
/compact "Сохрани только:
  - analyst_task_id, pm_check_id
  - FEATURE_DIR (из SA-REPORT)
  - feature_name
  - Текущий шаг: SA завершён, следующий = qSA аудит (1.5)
  Всё остальное — сбросить."
```

## 1.5 qSA Аудит

**Триггер:** [SA-REPORT] получен и содержит FEATURE_DIR.

```
# Извлечь FEATURE_DIR из notes analyst_task_id (строка "[SA-REPORT | FEATURE_DIR: ...]")
feature_dir = извлечь из backlog__task_get(analyst_task_id).notes

qsa_task_id = backlog__task_create(
  title="[QSA] Аудит артефактов: {feature_name}",
  description="""
FEATURE_DIR: {feature_dir}
Оригинальный запрос пользователя:
{полный текст из INTAKE}
  """,
  depends_on=[analyst_task_id]
)

qsa_role = Read(".claude/agents/qsa.md")

iteration = 1
qsa_approved = False

while iteration <= 3 and not qsa_approved:
  Task(
    description="qSA аудит итерация {iteration}: {feature_name}",
    prompt=f"{qsa_role}\n---\nQSA_TASK_ID: {qsa_task_id}\nИтерация: {iteration}",
    model="claude-sonnet-4-5",
    timeout=TIMEOUTS["REVIEW"]
  )

  qsa_result = backlog__task_get(qsa_task_id)
  если notes содержит "[QSA-APPROVED" → qsa_approved = True; break
  если notes содержит "[QSA-REJECTED" → извлечь gaps

  backlog__task_update(analyst_task_id,
    notes=f"[QSA-CYCLE | iter: {iteration} | verdict: {'APPROVED' if qsa_approved else 'REJECTED'}]")

  если не qsa_approved и iteration < 3:
    Task(
      description="SA доработка по замечаниям qSA итерация {iteration}",
      prompt=f"{analyst_role}\n---\nTASK_ID: {analyst_task_id}\nДоработай артефакты по замечаниям:\n{gaps}",
      model="claude-opus-4-5",
      timeout=TIMEOUTS["SA"]
    )

  iteration += 1

если не qsa_approved:
  backlog__task_update(analyst_task_id, status="review-human-await",
    notes=f"[QSA-ESCALATION | iter: 3 | unresolved_gaps: {gaps}]")

  Показать человеку:
    "SA аналитика не прошла проверку качества после 3 итераций.

    Оригинальный запрос: {текст из INTAKE}

    Незакрытые расхождения:
    {нумерованный список gaps}

    Варианты:
    A) Уточнить требования — я перезапущу SA с новым контекстом
    B) Принять as-is — перейти к Transfer Agent (задачи получат [QSA-ACCEPTED-WITH-GAPS])
    C) Полный перезапуск SA с нуля"

  Ждать явного ответа (A/B/C):
    A → получить уточнения, обновить analyst_task_id description, iteration=1, перезапустить SA
    B → backlog__task_update(analyst_task_id, notes+="[QSA-ACCEPTED-WITH-GAPS]"), продолжить к 1.6
    C → iteration=1, Task(SA, полный перезапуск от ФАЗЫ 0)
```

## 1.6 Transfer Agent

**Триггер:** qSA вернул [QSA-APPROVED] или человек выбрал вариант B.

```
transfer_task_id = backlog__task_create(
  title="[TRANSFER] Перенос в Backlog: {feature_name}",
  description="""
FEATURE_DIR: {feature_dir}
EPIC_ID: {analyst_task_id}
  """,
  depends_on=[qsa_task_id]
)

transfer_role = Read(".claude/agents/spec-transfer.md")

Task(
  description="Transfer Spec-Kitty → Backlog: {feature_name}",
  prompt=f"{transfer_role}\n---\nTRANSFER_TASK_ID: {transfer_task_id}",
  model="claude-sonnet-4-5",
  timeout=TIMEOUTS["CONSOLIDATION"]
)

# Верификация
transfer_result = backlog__task_get(transfer_task_id)
если notes не содержит "[TRANSFER-REPORT" →
  повторить Task(transfer_role) с инструкцией завершить отчёт

backlog__task_update(pm_check_id, status="done",
  notes="[PM-LOG verified | evidence: transfer_task_id]")
```

## 1.7 Переход к SCRUM Master

**Триггер:** [TRANSFER-REPORT] получен.

---

**После завершения Фазы 1 → перейти к Фазе 2:**
```
Read(".claude/phases/phase-2-scrum.md")
```
