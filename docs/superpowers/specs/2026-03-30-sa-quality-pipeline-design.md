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

### Hard-gate: проверка Spec-Kitty

**Кто проверяет:** SA (перед завершением ФАЗЫ 1) и qSA (перед началом аудита).

**Два уровня проверки (оба обязательны):**

**Уровень 1 — CLI (статус workflow):**
```bash
spec-kitty agent feature check-prerequisites --json
spec-kitty dashboard
```
Проверяет: Specify ✅, Plan ✅, Tasks ✅

**Уровень 2 — Shell (физическое наличие артефактов):**
```bash
test -s {FEATURE_DIR}/research.md       # файл ненулевого размера
ls {FEATURE_DIR}/contracts/ | wc -l    # ≥1 файл
ls {FEATURE_DIR}/checklists/ | wc -l   # ≥1 файл
test -s {FEATURE_DIR}/quickstart.md    # файл ненулевого размера
test -s {FEATURE_DIR}/data-model.md    # файл ненулевого размера
```

CLI проверяет завершённость workflow. Shell проверяет физические файлы. Оба уровня должны пройти.

**Если `spec-kitty dashboard` недоступен:**
```
[BLOCKED: spec-kitty dashboard unavailable]
→ SA/qSA останавливается
→ PM создаёт задачу [SETUP] для восстановления инструмента
→ Цикл не продолжается до устранения
```

### FEATURE_DIR: источник правды

`FEATURE_DIR` — абсолютный путь к директории фичи в Spec-Kitty, например:
`/path/to/project/kitty-specs/001-feature-name/`

**Создаётся:** автоматически Spec-Kitty на шаге `/spec-kitty.specify`.

**Как получить:** из вывода CLI команды:
```bash
spec-kitty agent feature check-prerequisites --json
# → JSON поле "FEATURE_DIR"
```

**Как передаётся между агентами:** через notes задачи в Backlog:
```
[SA-REPORT | FEATURE_DIR: /absolute/path/to/kitty-specs/001-feature/]
```
Каждый следующий агент читает FEATURE_DIR из notes родительской задачи.

### Разделение ответственности

| Агент | Ответственность |
|-------|----------------|
| SA | Исследование + полный цикл Spec-Kitty |
| qSA | Аудит артефактов против оригинального запроса |
| Transfer Agent | Механический перенос WP → Backlog (включая artifact links) |
| SCRUM Master | Верификация самодостаточности каждой задачи |

---

## Секция 2: SA Agent — обязательный Spec-Kitty

### Изменения в `analyst.md`

**Удаляется полностью из analyst.md:**
- Весь раздел `## ПРОВЕРКА SPEC-KITTY` (условие Если < 5 → ФАЗА 1-FALLBACK)
- Весь раздел `## ФАЗА 1-FALLBACK: БЕЗ SPEC-KITTY` (включая Self-Review)
- Весь раздел `## ФАЗА 2: ПЕРЕНОС В BACKLOG` (Шаги A, A.2, A.3, B — полностью)

**Остаётся без изменений:**
- `## ФАЗА 0: ИССЛЕДОВАНИЕ` (4 Explore-агента, brainstorm, adversarial)
- `## ФАЗА 1: SPEC-KITTY ЦИКЛ` (Этапы 1-4 + Финальная проверка)

**Добавляется в конец ФАЗЫ 1 (после финальной проверки):**

```
### Artifact Gate

Выполнить оба уровня проверки (CLI + Shell) из Секции 1.
Если что-то не прошло → SA возвращается и создаёт недостающее.
Если timeout → [SA-BLOCKED: incomplete artifacts | missing: {список}] → СТОП
```

**Обновлённый формат SA-REPORT (заменяет текущий):**
```
[SA-REPORT]
FEATURE_DIR: {абсолютный путь}
Workflow: Specify ✅ | Plan ✅ | Tasks ✅
Artifacts: research ✅ | contracts ✅ | checklists ✅ | quickstart ✅ | data-model ✅
WP count: {N}
Исследование: {research_doc_id в Backlog}
```

**SA завершается** после SA-REPORT. Перенос в Backlog — не задача SA.

---

## Секция 3: qSA Agent (аудитор)

### Новый файл: `.claude/agents/qsa.md`

**Идентичность:** Автономный аудитор. Получает оригинальный запрос пользователя и FEATURE_DIR из notes. Цель — найти расхождения между тем, что просили, и тем, что сделал SA.

**Стартовый протокол:**
```
1. backlog__task_get(QSA_TASK_ID)
   → извлечь оригинальный запрос пользователя
   → извлечь FEATURE_DIR из [SA-REPORT] в notes
2. Выполнить оба уровня проверки (CLI + Shell) из Секции 1
3. Если что-то не ✅ → [QSA-BLOCKED: incomplete | missing: {список}] → СТОП
4. Прочитать все 5 артефактов из FEATURE_DIR
5. → АУДИТ
```

**Аудит по 4 измерениям с конкретными критериями:**

**Полнота** — все требования покрыты в spec.md?
- Каждая функция из запроса присутствует как user story или acceptance criteria?
- Все edge cases из запроса (debounce, fallback, locale normalization и т.п.) явно описаны?
- Нефункциональные требования (latency, error rates) задокументированы?

**Точность** — contracts и data-model соответствуют запросу?
- Типы данных в contracts совпадают с описанными в запросе?
- data-model включает все сущности упомянутые в запросе?
- API endpoints соответствуют описанным методам (search, searchDropdown и т.п.)?

**Тестируемость** — checklists и quickstart дают однозначный PASS/FAIL?
- Каждый checklist item завершается бинарным критерием?
- quickstart.md содержит выполнимые шаги (не "проверить качество")?
- Есть конкретные примеры входных данных и ожидаемых результатов?

**Самодостаточность** — разработчик может работать без вопросов?
- Нет ссылок "см. существующий код" без указания конкретных файлов?
- Все аббревиатуры и термины объяснены или взяты из запроса?
- Нет открытых "TODO: уточнить" в артефактах?

**Вердикт:**
```
APPROVED → [QSA-APPROVED | iteration: N] → PM продолжает к Transfer Agent

REJECTED → [QSA-REJECTED | iteration: N | gaps:
  1. {измерение}: {конкретное расхождение с указанием файла и строки}
  2. ...
]
```

### Протокол итераций (в `phase-1-sa.md`)

```
iteration = 1
while iteration <= 3:
  Task(SA, prompt="Доработай артефакты по замечаниям qSA: {gaps из QSA-REJECTED}")
  Task(qSA, prompt="Повторный аудит итерация {iteration}")
  backlog__task_update(analyst_task_id,
    notes="[QSA-CYCLE | iter: {iteration} | verdict: {APPROVED/REJECTED}]")
  if APPROVED → break
  iteration += 1

if не APPROVED после 3 итераций:
  backlog__task_update(analyst_task_id, status="review-human-await",
    notes="[QSA-ESCALATION | iter: 3 | unresolved_gaps: {список}]")

  Показать человеку:
    "SA аналитика не прошла проверку качества после 3 итераций.

    Оригинальный запрос: {текст из INTAKE}

    Незакрытые расхождения:
    {нумерованный список gaps с измерением и файлом}

    Варианты:
    A) Уточнить требования — я перезапущу SA с новым контекстом
       (analyst_task_id сохраняется, gap list очищается, WP файлы будут пересозданы)
    B) Принять as-is — перейти к Transfer Agent несмотря на gaps
       (задачи получат маркер [QSA-ACCEPTED-WITH-GAPS])
    C) Полный перезапуск SA с нуля
       (analyst_task_id сохраняется, iteration сбрасывается в 1)"

  Ждать явного ответа человека (A/B/C) перед продолжением.

  При ответе A:
    → Получить уточнения от человека
    → backlog__task_update(analyst_task_id, description=original+"\\n## Уточнения:\\n{новый контекст}")
    → iteration = 1, перезапустить Task(SA)
    → Spec-Kitty WP файлы будут перезаписаны SA при повторном запуске

  При ответе B:
    → Продолжить к Transfer Agent
    → backlog__task_update(analyst_task_id, notes+="[QSA-ACCEPTED-WITH-GAPS]")

  При ответе C:
    → iteration = 1, Task(SA, полный перезапуск от ФАЗЫ 0)
```

---

## Секция 4: Transfer Agent

### Новый файл: `.claude/agents/spec-transfer.md`

**Идентичность:** Автономный агент-переносчик. Единственная цель — механически перенести WP файлы в Backlog, добавив секцию ссылок на артефакты в каждую задачу.

**Источник:** `FEATURE_DIR/tasks/WPxx-slug.md`
**Назначение:** `backlog__task_create()` для каждого WP

**Протокол переноса:**
```
1. backlog__task_get(TRANSFER_TASK_ID)
   → извлечь FEATURE_DIR из [SA-REPORT]
   → извлечь epic_id

2. Bash(cat {FEATURE_DIR}/tasks.md) → порядок WP и зависимости

3. Bash(ls {FEATURE_DIR}/tasks/*.md | sort) → список WP файлов

4. Инициализировать wp_to_task_id = {}

5. Для каждого WPxx-slug.md (в порядке из tasks.md):
   a. Прочитать frontmatter: work_package_id, dependencies, subtasks, title
   b. Прочитать тело WP файла полностью
   c. Преобразовать dependencies: ["WP01"] → [wp_to_task_id["WP01"]]
      Если referenced WP ещё не создан → создать текущий без depends_on,
        добавить [TRANSFER-WARN: forward-dependency {WP_ID}] в notes,
        после создания всех WP — обновить depends_on через backlog__task_update()
      Если WP ID не существует в tasks.md:
        [TRANSFER-WARN: unknown dependency {WP_ID} for {WPxx}]
        → создать задачу без depends_on + note с предупреждением
   d. Добавить секцию в конец описания (абсолютные пути к файлам):
      ---
      ## Дополнительные материалы
      При затруднениях или вопросах обратись к артефактам исследования:
      - 📍 Контекст и решения: `{FEATURE_DIR}/research.md`
      - 📜 API контракты: `{FEATURE_DIR}/contracts/`
      - 💾 Модели данных: `{FEATURE_DIR}/data-model.md`
      - ✅ Критерии приёмки: `{FEATURE_DIR}/checklists/`
      - 🚀 Сценарии валидации: `{FEATURE_DIR}/quickstart.md`
   e. backlog__task_create(
        title="[WP{xx}] {title}",
        description={тело WP + секция артефактов},
        depends_on=[resolved backlog IDs]
      )
   f. wp_to_task_id[work_package_id] = new_task_id

6. Пройти по wp_to_task_id — исправить forward-dependency задачи через backlog__task_update()

7. backlog__task_update(epic_id, notes="[TRANSFER-REPORT] + маппинг")
```

**Финальный отчёт:**
```
[TRANSFER-REPORT]
Перенесено WP: N
Маппинг: WP01→TASK-X, WP02→TASK-Y, ...
Предупреждения: {список TRANSFER-WARN или "нет"}
Зависимости проставлены: N из N (включая исправленные forward deps)
```

**Абсолютные запреты:**
- Не переформулировать содержимое WP
- Не добавлять комментарии кроме секции "Дополнительные материалы"
- Не менять порядок без явного depends_on из tasks.md

**Ссылки на артефакты** используют абсолютные пути файловой системы (агенты запускаются на той же машине и имеют доступ к этим файлам).

---

## Секция 5: Enhanced SCRUM Master

### Изменения в `scrum-master.md`

**Новый принцип:** каждую задачу читать как разработчик, который видит её впервые без какого-либо контекста. Если нужно открыть другой файл чтобы понять задачу — задача провалила проверку.

**12-пунктовый чеклист на каждую задачу:**

```
ТЕКУЩИЕ ПРОВЕРКИ P1-P5 (без изменений):
  [ ] P1. Описание самодостаточно (понять без других задач и внешних ссылок)
  [ ] P2. Есть чёткий критерий: PASS если {X} / FAIL если {Y}
  [ ] P3. Есть сценарий демонстрации: шаг 1 → шаг 2 → ожидаемый результат
  [ ] P4. Перечислены зависимости (depends_on)
  [ ] P5. Не содержит "и также" / "а ещё" / "плюс к этому"

НОВЫЕ ПРОВЕРКИ N1-N7:
  [ ] N1. Контекст кодовой базы — указаны конкретные файлы/модули для изменения
  [ ] N2. Зависимости данных — какие модели/типы использует задача, они описаны в тексте?
  [ ] N3. Edge cases — перечислены явно (не "обработать ошибки", а конкретные случаи)
  [ ] N4. Интеграционные точки — как задача стыкуется с соседними WP?
  [ ] N5. Риски реализации — что может пойти не так при выполнении?
  [ ] N6. Self-sufficiency test — можно ли реализовать без чтения других задач?
  [ ] N7. Секция "Дополнительные материалы" присутствует с абсолютными путями
```

**Режим исправления (per-task):**
```
failed = количество пунктов не прошедших проверку для данной задачи

failed ≤ 2 → SCRUM исправляет сам через backlog__task_update()

failed ≥ 3 → [SCRUM-RETURN: {task_id} | failed_checks: {список пунктов}]
  → Transfer Agent перечитывает соответствующий WP файл из FEATURE_DIR
  → Transfer Agent обновляет задачу через backlog__task_update()
  → SCRUM повторно проверяет только эту задачу (не весь batch)

  Лимит возвратов к Transfer Agent: максимум 3 раза на задачу.
  После 3 возвратов без исправления:
    → [SCRUM-ESCALATION: {task_id} | reason: WP file may be deficient]
    → Показать человеку задачу и WP файл, запросить решение
    → Ждать явного ответа перед продолжением
```

**Подсчёт self-sufficiency score:**
```
score = количество задач где ВСЕ 7 пунктов N1-N7 прошли
      / общее количество задач
      × 100%

Пример: 9 из 10 задач прошли все N1-N7 → score = 90%
```

**Поведение при score < 90%:**
```
SCRUM-REPORT помечается: [SCORE-WARNING: {X}% < 90%]
Цикл НЕ блокируется — SCRUM продолжает.
PM на CHECKPOINT показывает предупреждение человеку вместе со списком задач
  не прошедших N1-N7, но не блокирует запуск разработки.
```

**Расширенный SCRUM-REPORT:**
```
[SCRUM-REPORT]
Проверено задач: N
Исправлено самостоятельно (failed ≤ 2): N
Возвращено Transfer Agent (failed ≥ 3): N
  - {task_id}: failed P2, N1, N3
  - {task_id}: failed N2, N4, N5
Эскалировано человеку: N (лимит возвратов исчерпан)
Self-sufficiency score (N1-N7): X% (N/N задач прошли все 7 пунктов)
{если X% < 90%: [SCORE-WARNING] — список задач не прошедших N1-N7}
Итог: Готов к разработке / Требуется доработка
```

---

## Изменения в `phase-1-sa.md`

Текущая структура phase-1-sa.md: шаги 1.0 → 1.1 → 1.2 → 1.3 → 1.4 → 1.4b → 1.5 → 1.6

**Новая структура после изменений:**

```
1.0   Подтвердить доступность Spec-Kitty      ← без изменений
1.0b  Проверить статус Serena и Context7       ← без изменений
1.1   Создать задачу аналитика                ← без изменений
1.2   Создать PM-CHECK задачу                  ← без изменений
1.3   Запустить SA агента                      ← без изменений
1.3b  Протокол взаимодействия с SA             ← без изменений
1.4   Мониторинг [SA-REPORT]                   ← без изменений
1.4b  /compact после SA                        ← без изменений

[НОВОЕ] 1.5   qSA цикл (до 3 итераций + эскалация)
[НОВОЕ] 1.6   Transfer Agent шаг
[НОВОЕ] 1.7   SCRUM Master шаг

← Шаги 1.5 (Верификация) и 1.6 (Консолидация) удаляются и заменяются выше
```

**Новый шаг 1.5 — qSA цикл:**
```
qsa_task_id = backlog__task_create(
  title="[QSA] Аудит артефактов: {feature_name}",
  description="FEATURE_DIR: {из SA-REPORT}\\nОригинальный запрос: {из INTAKE}",
  depends_on=[analyst_task_id]
)
qsa_role = Read(".claude/agents/qsa.md")

→ Выполнить цикл как описано в Секции 3 этого документа
```

**Новый шаг 1.6 — Transfer Agent:**
```
transfer_task_id = backlog__task_create(
  title="[TRANSFER] Перенос в Backlog: {feature_name}",
  description="FEATURE_DIR: {из SA-REPORT}\\nEPIC_ID: {analyst_task_id}",
  depends_on=[qsa_task_id]
)
transfer_role = Read(".claude/agents/spec-transfer.md")

Task(
  description="Transfer: {feature_name}",
  prompt=f"{transfer_role}\\n---\\nTRANSFER_TASK_ID: {transfer_task_id}",
  model="claude-sonnet-4-5",
  timeout=TIMEOUTS["CONSOLIDATION"]
)
```

**Новый шаг 1.7 — SCRUM Master:**
```
→ Перейти к Фазе 2 (phase-2-scrum.md) — без изменений
```

---

## Затронутые файлы

| Файл | Изменение |
|------|-----------|
| `.claude/agents/analyst.md` | Удалить: FALLBACK раздел, ФАЗУ 2 (Шаги A, A.2, A.3, B). Добавить: Artifact Gate. Обновить: SA-REPORT формат |
| `.claude/agents/qsa.md` | Создать новый агент с 4 измерениями аудита |
| `.claude/agents/spec-transfer.md` | Создать новый агент с протоколом переноса и forward-dependency handling |
| `.claude/agents/scrum-master.md` | Расширить до 12-пунктового чеклиста; добавить режим исправления с лимитом 3 возврата; добавить score N1-N7 |
| `.claude/phases/phase-1-sa.md` | Заменить шаги 1.5-1.6 на новые: qSA цикл (1.5), Transfer Agent (1.6), SCRUM (1.7) |

---

## Критерии успеха

- Каждая задача в Backlog содержит секцию "Дополнительные материалы" с абсолютными путями к артефактам
- qSA одобряет SA артефакты не более чем за 2 итерации (в норме)
- SCRUM N1-N7 score ≥ 90% задач с первой проверки
- Разработчик не задаёт уточняющих вопросов по содержанию задачи
