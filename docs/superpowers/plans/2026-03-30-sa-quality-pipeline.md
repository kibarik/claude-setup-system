# SA Quality Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Переделать пайплайн Фазы 1 так, чтобы SA использовал Spec-Kitty обязательно, независимый qSA аудитор проверял артефакты, отдельный Transfer Agent переносил задачи в Backlog, а SCRUM master верифицировал самодостаточность каждой задачи.

**Architecture:** Пять файлов-изменений: `analyst.md` (убрать fallback + перенос, добавить artifact gate), два новых агента (`qsa.md`, `spec-transfer.md`), расширенный `scrum-master.md` (12-пунктовый чеклист + score), обновлённый `phase-1-sa.md` (новые шаги 1.5-1.7).

**Tech Stack:** Markdown agent prompts, Backlog.md MCP, Spec-Kitty CLI, bash shell commands.

---

## File Structure

| Файл | Действие | Ответственность |
|------|----------|----------------|
| `.claude/agents/analyst.md` | Modify | Удалить FALLBACK и ФАЗУ 2; добавить Artifact Gate; обновить SA-REPORT формат |
| `.claude/agents/qsa.md` | Create | Новый агент-аудитор с 4 измерениями, 3 итерациями, эскалацией |
| `.claude/agents/spec-transfer.md` | Create | Новый агент-переносчик WP→Backlog с forward-dependency handling |
| `.claude/agents/scrum-master.md` | Modify | 12-пунктовый чеклист (P1-P5 + N1-N7), fix mode с лимитом 3, score |
| `.claude/phases/phase-1-sa.md` | Modify | Заменить шаги 1.5-1.6 на qSA цикл (1.5) + Transfer Agent (1.6) + SCRUM (1.7) |

---

## Task 1: Обновить `analyst.md` — убрать fallback и перенос, добавить Artifact Gate

**Files:**
- Modify: `.claude/agents/analyst.md`

- [ ] **Step 1: Прочитать текущий файл**

```bash
cat .claude/agents/analyst.md
```

Убедиться что присутствуют разделы: `## ПРОВЕРКА SPEC-KITTY`, `## ФАЗА 1-FALLBACK`, `## ФАЗА 2: ПЕРЕНОС В BACKLOG`, `## ФИНАЛЬНЫЙ ОТЧЁТ`.

- [ ] **Step 2: Удалить раздел `## ПРОВЕРКА SPEC-KITTY`**

Найти и удалить блок:
```
## ПРОВЕРКА SPEC-KITTY

```bash
Bash(ls .claude/commands/spec-kitty.*.md 2>/dev/null | wc -l)
Если ≥ 5 → ФАЗА 1: SPEC-KITTY
Если < 5 → ФАЗА 1-FALLBACK
```
```

Заменить на:
```markdown
## ПРОВЕРКА SPEC-KITTY

```
spec-kitty agent feature check-prerequisites --json
→ если недоступен: [SA-BLOCKED: spec-kitty unavailable] → СТОП
```

Spec-Kitty обязателен. Fallback не существует.
```

- [ ] **Step 3: Удалить весь раздел `## ФАЗА 1-FALLBACK: БЕЗ SPEC-KITTY`**

Удалить полностью от строки `## ФАЗА 1-FALLBACK: БЕЗ SPEC-KITTY` до следующего раздела `## ФАЗА 2:` (не включая его).

- [ ] **Step 4: Добавить Artifact Gate в конец `## ФАЗА 1: SPEC-KITTY ЦИКЛ`**

После блока `### Финальная проверка` добавить:

```markdown
### Artifact Gate

**Два уровня проверки (оба обязательны):**

Уровень 1 — CLI:
```bash
spec-kitty agent feature check-prerequisites --json
spec-kitty dashboard
```
Убедиться: Specify ✅, Plan ✅, Tasks ✅

Уровень 2 — Shell:
```bash
test -s {FEATURE_DIR}/research.md
ls {FEATURE_DIR}/contracts/ | wc -l    # ≥1
ls {FEATURE_DIR}/checklists/ | wc -l   # ≥1
test -s {FEATURE_DIR}/quickstart.md
test -s {FEATURE_DIR}/data-model.md
```

Если что-то не прошло → SA возвращается и создаёт недостающий артефакт.
Если timeout → `[SA-BLOCKED: incomplete artifacts | missing: {список}]` → СТОП
```

- [ ] **Step 5: Удалить весь раздел `## ФАЗА 2: ПЕРЕНОС В BACKLOG`**

Удалить полностью от строки `## ФАЗА 2: ПЕРЕНОС В BACKLOG` до `## ФИНАЛЬНЫЙ ОТЧЁТ` (не включая его).

- [ ] **Step 6: Обновить `## ФИНАЛЬНЫЙ ОТЧЁТ`**

Заменить текущий шаблон в `## ФИНАЛЬНЫЙ ОТЧЁТ` на:

```markdown
## ФИНАЛЬНЫЙ ОТЧЁТ

```
backlog__task_update(TASK_ID, notes="""
[SA-REPORT]
FEATURE_DIR: {абсолютный путь}
Workflow: Specify ✅ | Plan ✅ | Tasks ✅
Artifacts: research ✅ | contracts ✅ | checklists ✅ | quickstart ✅ | data-model ✅
WP count: {N}
Исследование: {research_doc_id в Backlog}
""")
```

SA завершается после этого отчёта. Перенос задач в Backlog — задача Transfer Agent, не SA.
```

- [ ] **Step 7: Верифицировать результат**

```bash
# Проверить что FALLBACK удалён
grep -c "ФАЗА 1-FALLBACK" .claude/agents/analyst.md
# Expected: 0

# Проверить что ФАЗА 2 удалена
grep -c "ФАЗА 2: ПЕРЕНОС" .claude/agents/analyst.md
# Expected: 0

# Проверить что Artifact Gate добавлен
grep -c "Artifact Gate" .claude/agents/analyst.md
# Expected: 1

# Проверить что SA-REPORT содержит FEATURE_DIR
grep -c "FEATURE_DIR" .claude/agents/analyst.md
# Expected: ≥1
```

- [ ] **Step 8: Commit**

```bash
git add .claude/agents/analyst.md
git commit -m "feat: make Spec-Kitty mandatory in SA agent, remove fallback and transfer phase"
```

---

## Task 2: Создать `.claude/agents/qsa.md` — агент-аудитор

**Files:**
- Create: `.claude/agents/qsa.md`

- [ ] **Step 1: Создать файл с идентичностью и стартовым протоколом**

Создать `.claude/agents/qsa.md` со следующим содержимым:

```markdown
# QSA — АУДИТОР АРТЕФАКТОВ SA

## TIMEOUT

**15 минут** на полный цикл аудита.

---

## ИДЕНТИЧНОСТЬ

Ты — автономный аудитор. Получаешь оригинальный запрос пользователя и FEATURE_DIR.
Единственная цель: найти расхождения между тем, что просили, и тем, что сделал SA.
Ты НЕ улучшаешь артефакты сам. Только выносишь вердикт с конкретными gaps.

---

## АБСОЛЮТНЫЕ ЗАПРЕТЫ

- Начинать аудит до проверки hard-gate
- Изменять артефакты самостоятельно
- Выносить APPROVED при наличии любого незакрытого gap
- Принимать размытые критерии ("хорошее качество") — только бинарные

---

## СТАРТОВЫЙ ПРОТОКОЛ

```
1. backlog__task_get(QSA_TASK_ID)
   → извлечь оригинальный запрос пользователя из description
   → извлечь FEATURE_DIR из notes (строка "[SA-REPORT | FEATURE_DIR: ...]")

2. Hard-gate уровень 1 — CLI:
   Bash(spec-kitty agent feature check-prerequisites --json)
   Bash(spec-kitty dashboard)
   → убедиться: Specify ✅, Plan ✅, Tasks ✅
   → если нет: [QSA-BLOCKED: workflow incomplete | missing: {список}] → СТОП

3. Hard-gate уровень 2 — Shell:
   Bash(test -s {FEATURE_DIR}/research.md && echo OK || echo MISSING)
   Bash(ls {FEATURE_DIR}/contracts/ 2>/dev/null | wc -l)
   Bash(ls {FEATURE_DIR}/checklists/ 2>/dev/null | wc -l)
   Bash(test -s {FEATURE_DIR}/quickstart.md && echo OK || echo MISSING)
   Bash(test -s {FEATURE_DIR}/data-model.md && echo OK || echo MISSING)
   → если что-то отсутствует: [QSA-BLOCKED: artifacts incomplete | missing: {список}] → СТОП

4. Прочитать все 5 артефактов:
   Read({FEATURE_DIR}/research.md)
   Read({FEATURE_DIR}/contracts/) — все файлы в директории
   Read({FEATURE_DIR}/checklists/) — все файлы в директории
   Read({FEATURE_DIR}/quickstart.md)
   Read({FEATURE_DIR}/data-model.md)

5. → АУДИТ
```

---

## АУДИТ ПО 4 ИЗМЕРЕНИЯМ

### Измерение 1 — Полнота

Сравнить spec.md с оригинальным запросом:

```
[ ] Каждая функция из запроса присутствует как user story или acceptance criteria?
[ ] Все edge cases из запроса явно описаны? (debounce, fallback, locale normalization и т.п.)
[ ] Нефункциональные требования задокументированы? (latency, error rates, limits)
```

### Измерение 2 — Точность

Проверить contracts и data-model:

```
[ ] Типы данных в contracts совпадают с описанными в запросе?
[ ] data-model включает все сущности упомянутые в запросе?
[ ] API endpoints соответствуют описанным методам и сигнатурам?
```

### Измерение 3 — Тестируемость

Проверить checklists и quickstart:

```
[ ] Каждый checklist item завершается бинарным критерием (да/нет, ≤X ms, etc.)?
[ ] quickstart.md содержит выполнимые конкретные шаги (не "проверить качество")?
[ ] Есть конкретные примеры входных данных и ожидаемых результатов?
```

### Измерение 4 — Самодостаточность

```
[ ] Нет ссылок "см. существующий код" без указания конкретных файлов?
[ ] Все аббревиатуры и термины объяснены или взяты из запроса?
[ ] Нет открытых "TODO: уточнить" в артефактах?
```

---

## ВЕРДИКТ

```
Все 12 пунктов прошли →

backlog__task_update(QSA_TASK_ID, notes="""
[QSA-APPROVED | iteration: {N}]
Все 4 измерения: ✅
""")

Есть хотя бы один не пройденный пункт →

backlog__task_update(QSA_TASK_ID, notes="""
[QSA-REJECTED | iteration: {N} | gaps:
  1. {измерение}: {конкретное расхождение} | файл: {filename}, строка: {N}
  2. ...
]
""")
```

APPROVED → завершить работу, PM продолжает к Transfer Agent.
REJECTED → завершить работу, PM перезапустит SA с gaps.
```

- [ ] **Step 2: Верифицировать файл**

```bash
# Проверить наличие ключевых секций
grep -c "СТАРТОВЫЙ ПРОТОКОЛ" .claude/agents/qsa.md      # Expected: 1
grep -c "QSA-BLOCKED" .claude/agents/qsa.md              # Expected: ≥2
grep -c "QSA-APPROVED" .claude/agents/qsa.md             # Expected: 1
grep -c "QSA-REJECTED" .claude/agents/qsa.md             # Expected: 1
grep -c "Измерение" .claude/agents/qsa.md                # Expected: 4
grep -c "FEATURE_DIR" .claude/agents/qsa.md              # Expected: ≥3
```

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/qsa.md
git commit -m "feat: add qSA auditor agent with 4-dimension artifact review"
```

---

## Task 3: Создать `.claude/agents/spec-transfer.md` — агент-переносчик

**Files:**
- Create: `.claude/agents/spec-transfer.md`

- [ ] **Step 1: Создать файл**

Создать `.claude/agents/spec-transfer.md` со следующим содержимым:

```markdown
# SPEC-TRANSFER — АГЕНТ ПЕРЕНОСА В BACKLOG

## TIMEOUT

**10 минут** на полный перенос.

---

## ИДЕНТИЧНОСТЬ

Ты — автономный агент-переносчик. Единственная цель: механически перенести WP файлы
из Spec-Kitty в Backlog, добавив секцию ссылок на артефакты исследования.

Ты НЕ интерпретируешь содержимое. НЕ улучшаешь формулировки. НЕ добавляешь контент
кроме секции "Дополнительные материалы".

---

## АБСОЛЮТНЫЕ ЗАПРЕТЫ

- Переформулировать содержимое WP файлов
- Добавлять комментарии кроме секции "Дополнительные материалы"
- Менять порядок WP без явного depends_on из tasks.md
- Пропускать WP файлы

---

## СТАРТОВЫЙ ПРОТОКОЛ

```
1. backlog__task_get(TRANSFER_TASK_ID)
   → извлечь FEATURE_DIR из description или notes
   → извлечь EPIC_ID из description

2. Bash(cat {FEATURE_DIR}/tasks.md)
   → запомнить порядок WP и зависимости

3. Bash(ls {FEATURE_DIR}/tasks/*.md | sort)
   → получить список WP файлов

4. Инициализировать:
   wp_to_task_id = {}        — маппинг WP ID → backlog task ID
   forward_deps = {}         — {task_id: [WP_ID, ...]} для исправления после создания всех WP

5. → ПРОТОКОЛ ПЕРЕНОСА
```

---

## ПРОТОКОЛ ПЕРЕНОСА

Для каждого WPxx-slug.md **в порядке из tasks.md**:

```
a. Read({FEATURE_DIR}/tasks/WPxx-slug.md)
   → извлечь frontmatter: work_package_id, dependencies, subtasks, title
   → сохранить полное тело файла

b. Разрешить зависимости:
   resolved_deps = []
   для каждого dep в dependencies:
     если dep в wp_to_task_id → resolved_deps.append(wp_to_task_id[dep])
     если dep НЕ в wp_to_task_id и dep существует в tasks.md →
       forward_deps[current_wp] = forward_deps.get(current_wp, []) + [dep]
       (будет исправлено после создания всех WP)
     если dep НЕ существует в tasks.md →
       [TRANSFER-WARN: unknown dependency {dep} for {work_package_id}]
       (пропустить эту зависимость)

c. Составить description = тело WP файла + следующая секция:
   ---
   ## Дополнительные материалы
   При затруднениях или вопросах обратись к артефактам исследования:
   - 📍 Контекст и решения: `{FEATURE_DIR}/research.md`
   - 📜 API контракты: `{FEATURE_DIR}/contracts/`
   - 💾 Модели данных: `{FEATURE_DIR}/data-model.md`
   - ✅ Критерии приёмки: `{FEATURE_DIR}/checklists/`
   - 🚀 Сценарии валидации: `{FEATURE_DIR}/quickstart.md`

d. backlog__task_create(
     title="[{work_package_id}] {title}",
     description={description из шага c},
     depends_on={resolved_deps}
   )
   → wp_to_task_id[work_package_id] = новый task_id
```

---

## ИСПРАВЛЕНИЕ FORWARD DEPENDENCIES

После создания всех WP задач:

```
для каждого (wp_id, dep_list) в forward_deps:
  task_id = wp_to_task_id[wp_id]
  resolved = [wp_to_task_id[dep] for dep in dep_list if dep in wp_to_task_id]
  backlog__task_update(task_id, depends_on=resolved)
```

---

## ОБНОВЛЕНИЕ ЭПИКА

```
backlog__task_update(EPIC_ID, notes="""
[TRANSFER-REPORT]
Перенесено WP: {N}
Маппинг: {WP01→TASK-X, WP02→TASK-Y, ...}
Предупреждения: {список TRANSFER-WARN или "нет"}
Зависимости проставлены: {N} из {N} (включая исправленные forward deps)
""")
```
```

- [ ] **Step 2: Верифицировать файл**

```bash
grep -c "СТАРТОВЫЙ ПРОТОКОЛ" .claude/agents/spec-transfer.md    # Expected: 1
grep -c "TRANSFER-WARN" .claude/agents/spec-transfer.md          # Expected: ≥2
grep -c "TRANSFER-REPORT" .claude/agents/spec-transfer.md        # Expected: 1
grep -c "Дополнительные материалы" .claude/agents/spec-transfer.md  # Expected: 1
grep -c "forward_deps" .claude/agents/spec-transfer.md           # Expected: ≥2
grep -c "FEATURE_DIR" .claude/agents/spec-transfer.md            # Expected: ≥5
```

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/spec-transfer.md
git commit -m "feat: add spec-transfer agent for mechanical WP→Backlog transfer"
```

---

## Task 4: Обновить `scrum-master.md` — 12-пунктовый чеклист и fix mode

**Files:**
- Modify: `.claude/agents/scrum-master.md`

- [ ] **Step 1: Прочитать текущий файл**

```bash
cat .claude/agents/scrum-master.md
```

Найти раздел `## ПРОВЕРКА КАЧЕСТВА КАЖДОЙ ЗАДАЧИ` — это текущий 5-пунктовый чеклист (P1-P5).

- [ ] **Step 2: Добавить новый принцип перед чеклистом**

В начало раздела `## ПРОВЕРКА КАЧЕСТВА КАЖДОЙ ЗАДАЧИ` добавить:

```markdown
**Принцип:** Читай каждую задачу как разработчик, видящий её впервые без какого-либо контекста.
Если нужно открыть другой файл чтобы понять задачу — задача провалила проверку.
```

- [ ] **Step 3: Расширить чеклист до 12 пунктов**

Заменить текущий чеклист (5 пунктов) на расширенный (12 пунктов):

```markdown
```
ТЕКУЩИЕ ПРОВЕРКИ P1-P5:
  [ ] P1. Описание самодостаточно (понять без других задач и внешних ссылок)
  [ ] P2. Есть чёткий критерий: PASS если {X} / FAIL если {Y}
  [ ] P3. Есть сценарий демонстрации: шаг 1 → шаг 2 → ожидаемый результат
  [ ] P4. Перечислены зависимости (depends_on)
  [ ] P5. Не содержит "и также" / "а ещё" / "плюс к этому"

НОВЫЕ ПРОВЕРКИ N1-N7:
  [ ] N1. Контекст кодовой базы — указаны конкретные файлы/модули для изменения
  [ ] N2. Зависимости данных — какие модели/типы использует задача, описаны в тексте?
  [ ] N3. Edge cases — перечислены явно (не "обработать ошибки", а конкретные случаи)
  [ ] N4. Интеграционные точки — как задача стыкуется с соседними WP?
  [ ] N5. Риски реализации — что может пойти не так при выполнении?
  [ ] N6. Self-sufficiency test — можно ли реализовать без чтения других задач?
  [ ] N7. Секция "Дополнительные материалы" присутствует с абсолютными путями к артефактам
```
```

- [ ] **Step 4: Обновить раздел "Если что-то отсутствует" — добавить fix mode**

Заменить текущий блок `Если что-то отсутствует:` на:

```markdown
**Режим исправления (per-task):**

```
failed = количество пунктов не прошедших проверку для данной задачи

failed ≤ 2 →
  SCRUM исправляет сам через backlog__task_update()
  Добавить в description недостающий контент с маркером [SCRUM-FIXED: {пункт}]

failed ≥ 3 →
  backlog__task_update(task_id,
    notes="[SCRUM-RETURN | failed: {список пунктов} | return_count: {N}]")
  PM перезапускает Transfer Agent для этой задачи (Transfer Agent перечитывает WP файл)
  SCRUM повторно проверяет только эту задачу после возврата

  Лимит возвратов: максимум 3 на задачу.
  После 3 возвратов без исправления:
    → backlog__task_update(task_id, notes="[SCRUM-ESCALATION: WP file may be deficient]")
    → PM показывает задачу и WP файл человеку, ждёт явного решения
```
```

- [ ] **Step 5: Добавить подсчёт self-sufficiency score и обновить ФИНАЛЬНЫЙ ОТЧЁТ**

В конце файла, в разделе `## ФИНАЛЬНЫЙ ОТЧЁТ`, заменить шаблон `[SCRUM-REPORT]` на расширенный:

```markdown
```
entire checkpoint "sm-complete-{EPIC_ID}" 2>/dev/null || true

# Подсчёт self-sufficiency score:
# score = задачи где ВСЕ N1-N7 прошли / все задачи × 100%

backlog__task_update(EPIC_ID, notes="""
[SCRUM-REPORT]
Проверено задач: {N}
Исправлено самостоятельно (failed ≤ 2): {N}
Возвращено Transfer Agent (failed ≥ 3): {N}
  {task_id}: failed {список пунктов}
Эскалировано человеку: {N} (лимит возвратов исчерпан)
Self-sufficiency score (N1-N7): {X}% ({N}/{N} задач прошли все 7 пунктов)
{если X% < 90%: [SCORE-WARNING] — список задач не прошедших N1-N7}
Итог: Готов к разработке / Требуется доработка
""")
```
```

- [ ] **Step 6: Верифицировать результат**

```bash
grep -c "N1\." .claude/agents/scrum-master.md         # Expected: ≥1
grep -c "N7\." .claude/agents/scrum-master.md         # Expected: ≥1
grep -c "SCRUM-RETURN" .claude/agents/scrum-master.md # Expected: ≥1
grep -c "SCRUM-ESCALATION" .claude/agents/scrum-master.md # Expected: ≥1
grep -c "SCORE-WARNING" .claude/agents/scrum-master.md # Expected: ≥1
grep -c "self-sufficiency" .claude/agents/scrum-master.md # Expected: ≥1
```

- [ ] **Step 7: Commit**

```bash
git add .claude/agents/scrum-master.md
git commit -m "feat: extend SCRUM master with 12-point checklist, fix mode, and N1-N7 score"
```

---

## Task 5: Обновить `phase-1-sa.md` — добавить qSA цикл и Transfer Agent

**Files:**
- Modify: `.claude/phases/phase-1-sa.md`

- [ ] **Step 1: Прочитать текущий файл**

```bash
cat .claude/phases/phase-1-sa.md
```

Найти шаги 1.5 (Верификация) и 1.6 (Консолидация) — они будут заменены.

- [ ] **Step 2: Удалить шаг 1.5 (Верификация)**

Удалить полностью раздел `## 1.5 Верификация` (от заголовка до следующего раздела `## 1.6`).

- [ ] **Step 3: Удалить шаг 1.6 (Консолидация)**

Удалить полностью раздел `## 1.6 Консолидация артефактов Spec-Kitty` (от заголовка до конца файла, не включая строку `**После завершения Фазы 1`).

- [ ] **Step 4: Добавить новый шаг 1.5 — qSA цикл**

Добавить после шага 1.4b:

```markdown
## 1.5 qSA Аудит

**Триггер:** [SA-REPORT] получен и содержит FEATURE_DIR.

```
qsa_task_id = backlog__task_create(
  title="[QSA] Аудит артефактов: {feature_name}",
  description="""
FEATURE_DIR: {из SA-REPORT}
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
    B → backlog__task_update(analyst_task_id, notes+="[QSA-ACCEPTED-WITH-GAPS]"), продолжить
    C → iteration=1, Task(SA, полный перезапуск от ФАЗЫ 0)
```
```

- [ ] **Step 5: Добавить новый шаг 1.6 — Transfer Agent**

Добавить после шага 1.5:

```markdown
## 1.6 Transfer Agent

**Триггер:** qSA вернул [QSA-APPROVED] или человек выбрал вариант B.

```
transfer_task_id = backlog__task_create(
  title="[TRANSFER] Перенос в Backlog: {feature_name}",
  description="""
FEATURE_DIR: {из SA-REPORT}
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
```
```

- [ ] **Step 6: Обновить финальный переход на Фазу 2**

Заменить строку:
```
**После завершения Фазы 1 → перейти к Фазе 2:**
```
на:

```markdown
## 1.7 Переход к SCRUM Master

**Триггер:** [TRANSFER-REPORT] получен.

---

**После завершения Фазы 1 → перейти к Фазе 2:**
```

- [ ] **Step 7: Верифицировать результат**

```bash
# Старые шаги удалены
grep -c "1.5 Верификация" .claude/phases/phase-1-sa.md          # Expected: 0
grep -c "1.6 Консолидация" .claude/phases/phase-1-sa.md         # Expected: 0

# Новые шаги добавлены
grep -c "1.5 qSA" .claude/phases/phase-1-sa.md                  # Expected: 1
grep -c "1.6 Transfer" .claude/phases/phase-1-sa.md             # Expected: 1
grep -c "1.7" .claude/phases/phase-1-sa.md                      # Expected: 1
grep -c "QSA-ESCALATION" .claude/phases/phase-1-sa.md           # Expected: 1
grep -c "TRANSFER-REPORT" .claude/phases/phase-1-sa.md          # Expected: 1
```

- [ ] **Step 8: Commit**

```bash
git add .claude/phases/phase-1-sa.md
git commit -m "feat: add qSA cycle and Transfer Agent steps to Phase 1 pipeline"
```

---

## Task 6: Финальная верификация

**Files:** все 5 файлов

- [ ] **Step 1: Проверить связность пайплайна**

```bash
# SA-REPORT содержит FEATURE_DIR (SA → qSA → Transfer Agent)
grep "FEATURE_DIR" .claude/agents/analyst.md
grep "FEATURE_DIR" .claude/agents/qsa.md
grep "FEATURE_DIR" .claude/agents/spec-transfer.md

# qSA-APPROVED присутствует в phase-1-sa.md как условие перехода
grep "QSA-APPROVED" .claude/phases/phase-1-sa.md

# Transfer Agent добавляет Дополнительные материалы
grep "Дополнительные материалы" .claude/agents/spec-transfer.md

# SCRUM проверяет N7 (наличие Дополнительных материалов)
grep "N7" .claude/agents/scrum-master.md
```

- [ ] **Step 2: Проверить что новые агенты в списке агентов в CLAUDE.md не нужно обновлять**

```bash
grep -i "qsa\|spec-transfer" CLAUDE.md || echo "Не упомянуты — окей, агенты вызываются динамически"
```

- [ ] **Step 3: Финальный commit если есть незакоммиченные изменения**

```bash
git status
# Если чисто — всё готово
git log --oneline -5
```

Ожидаемый лог последних коммитов:
```
feat: add qSA cycle and Transfer Agent steps to Phase 1 pipeline
feat: extend SCRUM master with 12-point checklist, fix mode, and N1-N7 score
feat: add spec-transfer agent for mechanical WP→Backlog transfer
feat: add qSA auditor agent with 4-dimension artifact review
feat: make Spec-Kitty mandatory in SA agent, remove fallback and transfer phase
docs: finalize SA quality pipeline spec (all review issues resolved)
docs: add SA quality pipeline redesign spec
```
