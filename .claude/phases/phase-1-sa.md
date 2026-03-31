# ФАЗА 1: SA — АНАЛИТИК

**Триггер:** INTAKE завершён.

## 1.0 Подтвердить доступность Spec-Kitty

**Spec-Kitty проверяется через Skill tool, НЕ через Bash.**

```
Skill(skill="spec-kitty.status")
  → ответил → продолжить
  → ошибка   → предложить установку через Setup-агента, перейти в fallback-режим
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
  prompt=f"""{analyst_role}
---
TASK_ID: {analyst_task_id}
Режим MCP: BACKLOG
{tools_context}

КРИТИЧНО — КАК ВЫЗЫВАТЬ SPEC-KITTY:
  Spec-Kitty доступен через Skill tool. Синтаксис:
    Skill(skill="spec-kitty.specify", args="...")
    Skill(skill="spec-kitty.plan", args="...")
    Skill(skill="spec-kitty.checklist", args="...")
    Skill(skill="spec-kitty.tasks", args="...")
    Skill(skill="spec-kitty.dashboard", args="...")
  НЕ искать через Bash. НЕ читать файлы .claude/commands/. Использовать только Skill tool.

Первое действие: backlog__task_get({analyst_task_id})""",
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
  - Список подзадач
  - research_doc_id, consolidated_doc_id
  - feature_name
  - Текущий шаг: SA завершён, следующий = консолидация + SCRUM
  Всё остальное — сбросить."
```

## 1.5 Верификация

```
backlog__task_list() → найти подзадачи analyst_task_id

Для каждой подзадачи → backlog__task_get(id):
  ✓ описание с контекстом
  ✓ PASS/FAIL критерий
  ✓ сценарий демонстрации
  ✓ зависимости (depends_on)

Если неполно (попытка 1) → повторный Task(SA) с уточнениями
Если неполно (попытка 2) → сообщить человеку варианты:
  A) Откатиться к checkpoint и перезапустить
  B) Перезапустить SA полностью
  C) Дополнить описание вручную

backlog__task_update(pm_check_id, status="done",
  notes="[PM-LOG verified | evidence: analyst_task_id]")
```

## 1.6 Консолидация артефактов Spec-Kitty

**Триггер:** верификация 1.5 пройдена.

```
consolidation_task_id = backlog__task_create(
  title="[DOCS] Консолидация артефактов: {feature_name}",
  description="Объединить артефакты Spec-Kitty в единый документ Backlog.",
  depends_on=[analyst_task_id]
)

Task(
  description="Консолидация артефактов: {feature_name}",
  prompt="""
Ты — агент-консолидатор. Собери артефакты Spec-Kitty в один документ.

ПРАВИЛО: Все файловые артефакты хранятся в docs/. Никогда не писать в корневую директорию.

TASK_ID: {consolidation_task_id}
FEATURE_NAME: {feature_name}

Шаг 1: Найти kitty-specs/ внутри docs/
  Bash(find docs/ -type d -name "kitty-specs" 2>/dev/null | head -5)
  Если не найдено в docs/ → проверить корень как fallback:
    Bash(find . -maxdepth 2 -type d -name "kitty-specs" 2>/dev/null | head -5)
  Если найдено в корне → переместить: Bash(mv kitty-specs docs/kitty-specs)

Шаг 2: Прочитать все артефакты из docs/kitty-specs/ (spec.md, research.md, data-model.md, contracts/, checklists/, tasks/)

Шаг 3: backlog__doc_create(title="{feature_name}", content={объединённый документ})

Шаг 4: backlog__task_update({consolidation_task_id}, status="done",
  notes="[DOCS-REPORT] doc_id: {id}")
  """,
  model="claude-sonnet-4-5",
  timeout=TIMEOUTS["CONSOLIDATION"]
)
```

---

**После завершения Фазы 1 → перейти к Фазе 2:**
```
Read(".claude/phases/phase-2-scrum.md")
```
