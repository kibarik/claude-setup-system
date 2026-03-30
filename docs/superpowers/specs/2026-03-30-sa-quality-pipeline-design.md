# SA Quality Pipeline Redesign

**Date:** 2026-03-30
**Status:** Approved
**Approach:** Full Phase 1 redesign (Approach B)

---

## Problem Statement

SA-агенты генерируют задачи с низким качеством описания:
- Поверхностная аналитика без глубокого исследования кодовой базы
- Spec-Kitty обходится через fallback-путь
- SA сам переносит задачи в Backlog (нет разделения ответственности)
- Нет независимого аудита артефактов
- SCRUM master проверяет формальные признаки, не содержательное качество
- Разработчик не знает где искать дополнительный контекст

---

## Solution: Новый пайплайн Фазы 1

```
SA (Spec-Kitty ОБЯЗАТЕЛЕН)
  → qSA audit (до 3 итераций → эскалация человеку)
  → Transfer Agent (Spec-Kitty → Backlog)
  → Enhanced SCRUM Master
  → CHECKPOINT → человек
```

---

## Секция 1: Общий пайплайн

### Ключевые принципы

**Hard-gate на Spec-Kitty:**
Проверяется не количество файлов конфигурации, а фактическое исполнение workflow и наличие всех артефактов:

Workflow (все три обязательны ✅):
- Specify
- Plan
- Tasks

Artifacts (все пять обязательны в `kitty-specs/###-feature/`):
- `research.md`
- `contracts/`
- `checklists/`
- `quickstart.md`
- `data-model.md`

Проверяется через `spec-kitty dashboard` и `spec-kitty agent feature check-prerequisites --json`.

**Разделение ответственности:**
- SA: исследование + Spec-Kitty полный цикл
- qSA: аудит артефактов против оригинального запроса
- Transfer Agent: механический перенос WP → Backlog
- SCRUM Master: верификация самодостаточности каждой задачи

---

## Секция 2: SA Agent — обязательный Spec-Kitty

### Изменения в `analyst.md`

**Удаляется полностью:**
- ФАЗА 1-FALLBACK (всё содержимое)
- Условие `Если < 5 → ФАЗА 1-FALLBACK`
- ФАЗА 2: ПЕРЕНОС В BACKLOG (перенос задач — отдельный агент)

**ФАЗА 0: ИССЛЕДОВАНИЕ** — без изменений (4 параллельных Explore-агента, чтение файлов, brainstorm, adversarial анализ).

**ФАЗА 1: SPEC-KITTY** — безусловная, старт:
```
spec-kitty agent feature check-prerequisites --json
→ если недоступен: [SA-BLOCKED: spec-kitty unavailable] → СТОП
```

Полный цикл: specify → plan → tasks (все этапы обязательны).

**Проверка артефактов перед завершением:**
```
spec-kitty dashboard → Workflow: Specify ✅, Plan ✅, Tasks ✅

Bash(ls {FEATURE_DIR}/research.md)    → обязателен
Bash(ls {FEATURE_DIR}/contracts/)     → обязателен
Bash(ls {FEATURE_DIR}/checklists/)    → обязателен
Bash(ls {FEATURE_DIR}/quickstart.md)  → обязателен
Bash(ls {FEATURE_DIR}/data-model.md)  → обязателен
```

Если что-то отсутствует → SA возвращается и создаёт недостающее.
Если timeout → `[SA-BLOCKED: incomplete artifacts | missing: {список}]`.

**Завершение SA:**
Финальный отчёт `[SA-REPORT]` с `FEATURE_DIR`. Перенос в Backlog — не задача SA.

---

## Секция 3: qSA Agent (аудитор)

### Новый файл: `.claude/agents/qsa.md`

**Идентичность:** Автономный аудитор. Получает оригинальный запрос пользователя и артефакты SA. Цель — найти расхождения между тем, что просили, и тем, что сделал SA.

**Стартовый протокол:**
```
1. backlog__task_get(QSA_TASK_ID)  → получить оригинальный запрос + FEATURE_DIR
2. spec-kitty dashboard            → проверить workflow ✅ и все 5 артефактов
3. Если что-то не ✅ → [QSA-BLOCKED: incomplete] → СТОП
4. Прочитать все 5 артефактов из FEATURE_DIR
5. → АУДИТ
```

**Аудит по 4 измерениям:**
- **Полнота** — все требования из оригинального запроса покрыты в spec.md?
- **Точность** — contracts и data-model соответствуют реальным бизнес-правилам из запроса?
- **Тестируемость** — checklists и quickstart дают однозначный PASS/FAIL?
- **Самодостаточность** — разработчик может работать только по этим артефактам без дополнительных вопросов?

**Вердикт:**
```
APPROVED → [QSA-APPROVED | iteration: N] → СТОП, PM продолжает
REJECTED → [QSA-REJECTED | iteration: N | gaps: {конкретный список}] → SA на доработку
```

**Протокол итераций (в `phase-1-sa.md`):**
```
iteration = 1
while iteration <= 3:
  Task(SA, "доработать по замечаниям qSA: {gaps}")
  Task(qSA, "повторный аудит")
  if APPROVED → break
  iteration += 1

if iteration > 3 и не APPROVED:
  → [QSA-ESCALATION] показать человеку:
    - оригинальный запрос
    - список незакрытых gaps после 3 итераций
    - варианты: уточнить требования / принять as-is / перезапустить SA
```

---

## Секция 4: Transfer Agent

### Новый файл: `.claude/agents/spec-transfer.md`

**Идентичность:** Автономный агент-переносчик. Не интерпретирует, не улучшает, не дополняет. Механически переносит структуру из Spec-Kitty в Backlog.

**Источник:** `FEATURE_DIR/tasks/WPxx-slug.md`
**Назначение:** `backlog__task_create()` для каждого WP

**Протокол переноса:**
```
1. backlog__task_get(TRANSFER_TASK_ID) → получить FEATURE_DIR
2. Bash(ls {FEATURE_DIR}/tasks/*.md)   → список WP файлов
3. Прочитать tasks.md                  → порядок и зависимости
4. Для каждого WPxx-slug.md:
   - Прочитать frontmatter: work_package_id, dependencies, subtasks
   - Прочитать тело: Objective, Context, Definition of Done, Risks
   - backlog__task_create(
       title="[WP{xx}] {title}",
       description={полное содержимое WP файла},
       depends_on=[mapped backlog IDs из dependencies]
     )
   - Сохранить маппинг: WP01 → backlog_task_id
5. После всех WP → обновить родительский эпик ссылками на подзадачи
```

**Финальный отчёт:**
```
[TRANSFER-REPORT]
Перенесено WP: N
Маппинг: WP01→TASK-X, WP02→TASK-Y, ...
Зависимости проставлены: да/нет
```

**Абсолютные запреты:**
- Не переформулировать содержимое WP
- Не добавлять свои комментарии в описание задач
- Не менять порядок без явного depends_on из tasks.md

---

## Секция 5: Enhanced SCRUM Master

### Изменения в `scrum-master.md`

**Новый принцип:** каждую задачу читать как разработчик, который видит её впервые без какого-либо контекста. Если нужно открыть другой файл чтобы понять задачу — задача провалила проверку.

**Расширенный чеклист (добавляется к текущим проверкам):**
```
ТЕКУЩИЕ ПРОВЕРКИ (остаются):
  [ ] Критерий PASS/FAIL
  [ ] Сценарий демонстрации
  [ ] depends_on проставлен
  [ ] Нет тест-заглушек
  [ ] Internal contracts для новых компонентов

НОВЫЕ ПРОВЕРКИ:
  [ ] Контекст кодовой базы — указаны конкретные файлы/модули для изменения
  [ ] Зависимости данных — какие модели/типы использует задача, они описаны?
  [ ] Edge cases — перечислены явно, не "обработать ошибки"
  [ ] Интеграционные точки — как задача стыкуется с соседними WP?
  [ ] Риски реализации — что может пойти не так?
  [ ] Self-sufficiency test — можно ли реализовать без чтения других задач?
  [ ] Ссылки на артефакты исследования присутствуют
```

**Обязательная секция в каждой задаче (если отсутствует — SCRUM добавляет):**
```markdown
## Дополнительные материалы
При затруднениях или вопросах обратись к артефактам исследования:
- 📍 Контекст и решения: `{FEATURE_DIR}/research.md`
- 📜 API контракты: `{FEATURE_DIR}/contracts/`
- 💾 Модели данных: `{FEATURE_DIR}/data-model.md`
- ✅ Критерии приёмки: `{FEATURE_DIR}/checklists/`
- 🚀 Сценарии валидации: `{FEATURE_DIR}/quickstart.md`
```

**Режим исправления:**
```
Задача не прошла ≤2 пунктов → SCRUM исправляет сам через backlog__task_update()
Задача не прошла ≥3 пунктов → [SCRUM-RETURN] → вернуть Transfer Agent
  с конкретным списком gaps → Transfer Agent перечитывает WP файл и обновляет задачу
```

**Расширенный SCRUM-REPORT:**
```
[SCRUM-REPORT]
Проверено: N задач
Исправлено самостоятельно: N
Возвращено на доработку: N (список с причинами)
Self-sufficiency score: N/N задач прошли
Итог: Готов / Требуется доработка
```

---

## Затронутые файлы

| Файл | Изменение |
|------|-----------|
| `.claude/agents/analyst.md` | Удалить FALLBACK и ФАЗУ 2 переноса, добавить artifact gate |
| `.claude/agents/qsa.md` | Создать новый агент |
| `.claude/agents/spec-transfer.md` | Создать новый агент |
| `.claude/agents/scrum-master.md` | Расширить чеклист, добавить ссылки на артефакты, новый режим исправления |
| `.claude/phases/phase-1-sa.md` | Добавить qSA цикл (3 итерации + эскалация) и Transfer Agent шаг |

---

## Критерии успеха

- Каждая задача в Backlog содержит ссылки на артефакты исследования
- qSA одобряет SA артефакты не более чем за 2 итерации (в норме)
- SCRUM self-sufficiency score ≥ 90% задач с первой проверки
- Разработчик не задаёт уточняющих вопросов по содержанию задачи
