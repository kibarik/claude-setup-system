# claude-setup-system

Система автономной оркестрации AI-агентов для Claude Code. PM-агент управляет полным циклом разработки — от постановки задачи до готового PR — делегируя работу специализированным агентам через MCP-протокол.

---

## Зачем это нужно

AI-модели хорошо генерируют код. Но процесс разработки — это не только код: это постановка задачи, декомпозиция, аналитика, code review, тестирование и контроль качества. Всё это требует координации и дисциплины.

**claude-setup-system** решает эту проблему: вы описываете задачу, а PM-агент автономно проводит её через весь pipeline — от анализа до тестирования.

---

## Архитектура

```
Человек
  │
  ▼
┌──────────┐     ┌──────────────┐
│    PM    │────▶│  Backlog MCP │  ← управление задачами
│ (CLAUDE) │     └──────────────┘
└────┬─────┘
     │ Task()
     ├───────────────────────────────────┐
     ▼                                   ▼
┌──────────┐  Spec-Kitty            ┌──────────┐
│    SA    │────────────────────────│  SCRUM   │
│ Analyst  │  specify → plan →      │  Master  │
└──────────┘  checklist → tasks     └────┬─────┘
                                         │ CHECKPOINT (ждёт "да")
                                         ▼
     ┌──────────┐    ┌──────────┐    ┌──────────┐
     │   Dev    │───▶│ Reviewer │───▶│    QA    │
     └──────────┘    └──────────┘    └──────────┘
          │               │               │
          ▼               ▼               ▼
        Code          Approved         PASS/FAIL
```

### 8 специализированных агентов

| Агент | Файл | Функция |
|-------|------|---------|
| **PM** | `CLAUDE.md` | Оркестрация процесса, управление Backlog через MCP |
| **Setup** | `agents/setup.md` | Проверка и настройка MCP-инструментов |
| **Git Sync** | `agents/git-sync.md` | Синхронизация worktree, git pull, субмодули |
| **SA (Analyst)** | `agents/analyst.md` | Генерация спецификаций через Spec-Kitty |
| **SCRUM Master** | `agents/scrum-master.md` | Верификация бэклога, Token Budget Gate |
| **Developer** | `agents/developer.md` | Реализация одной задачи → PR |
| **Reviewer** | `agents/reviewer.md` | Code review с вердиктом Approved/Rejected |
| **QA** | `agents/qa.md` | Тестирование, PASS/FAIL с evidence |
| **QDev** | `agents/qdev.md` | Проверка запускаемости кода |

### Статусы задач

```
To Do → In Progress → qdev-check → code-review → review-debug → ready-for-testing → Done
```

Полная матрица переходов: `.claude/shared/statuses.md`

---

## Что внутри

```
.claude/
├── agents/                    # 8 агентов (analyst, developer, reviewer, qa, qdev, scrum-master, git-sync, setup)
├── commands/                  # 14 команд Spec-Kitty (specify, plan, checklist, tasks, ...)
├── phases/                    # 4 модуля фаз (SA → SCRUM → Dev → Completion)
├── shared/statuses.md         # Единый справочник статусов и переходов
├── templates/                 # Шаблоны для explore-задач и fallback-спецификаций
├── mcp.json                   # Конфигурация MCP-серверов
└── settings.json              # Hooks для Entire (session, task, stop events)

.backlog/
└── config.yml                 # Конфигурация Backlog.md (статусы, порт, формат дат)

.entire/
├── settings.json              # Конфигурация Entire (checkpoints, сессии)
└── .gitignore                 # Игнор runtime-данных

.continue/
└── checks/                    # 10 проверок качества кода (тесты, безопасность, архитектура)

.serena/
├── project.yml                # Конфигурация Serena (language server protocol)
└── memories/                  # Память агента между сессиями

.superset/
└── config.json                # Конфигурация Superset (worktree менеджмент)

docs/
└── agent-orchestration-research.md  # Исследование инструментов оркестрации

CLAUDE.md                      # Системный промпт PM-агента
```

---

## Быстрый старт

### 1. Склонировать

```bash
# Вариант A — в существующий проект
git clone git@github.com:kibarik/claude-setup-system.git /tmp/claude-setup
cp -r /tmp/claude-setup/.claude /tmp/claude-setup/.backlog \
      /tmp/claude-setup/.entire /tmp/claude-setup/.continue \
      /tmp/claude-setup/.serena /tmp/claude-setup/.superset \
      /tmp/claude-setup/CLAUDE.md /tmp/claude-setup/.gitignore \
      /path/to/your/project/
rm -rf /tmp/claude-setup

# Вариант B — как основа нового проекта
git clone git@github.com:kibarik/claude-setup-system.git my-project
cd my-project
git remote set-url origin git@github.com:your-org/your-repo.git
```

### 2. Установить инструменты

```bash
# Backlog.md — управление задачами через MCP (обязательно)
npm install -g backlog.md

# Spec-Kitty — генерация спецификаций (обязательно для SA-агента)
npm install -g spec-kitty

# Entire — сессии и checkpoints (рекомендуется)
npm install -g @anthropic/entire

# Superset — worktree менеджмент (опционально)
# Установка через https://superset.dev
```

### 3. Настроить MCP

Отредактируйте `.claude/mcp.json` — укажите абсолютный путь к проекту:

```json
{
  "mcpServers": {
    "backlog": {
      "command": "backlog",
      "args": ["mcp", "start"],
      "env": {
        "BACKLOG_CWD": "/absolute/path/to/your/project"
      }
    }
  }
}
```

### 4. Обновить имя проекта

```bash
# В .backlog/config.yml замените project_name на своё
sed -i '' 's/lean-spoonbill/your-project-name/' .backlog/config.yml
```

### 5. Проверить

```bash
claude          # Запустить Claude Code
/mcp            # Проверить что MCP-серверы подключены
```

---

## Как работать

### Шаг 1 — Запуск

Откройте Claude Code в директории проекта. PM-агент автоматически:
1. Проверит наличие инструментов (Setup-агент)
2. Синхронизирует git (Git Sync-агент)
3. Проверит подключение к Backlog MCP
4. Запросит задачу

### Шаг 2 — Описать задачу

PM задаст 6 вопросов в рамках INTAKE:

1. Какую бизнес-проблему решает задача?
2. Кто пользователь результата и как выглядит его "победа"?
3. Как выглядит демонстрация? ("открыть X → нажать Y → увидеть Z")
4. Критерий завершённости — что значит "сделано"?
5. Ограничения: сроки, технологии, зависимости?
6. Существующие артефакты: документы, схемы, код?

**Качество ответов на INTAKE — это 90% успеха.**

### Шаг 3 — Автономная работа

После INTAKE PM запускает pipeline:

| Фаза | Агент | Что происходит |
|------|-------|----------------|
| 1. Аналитика | SA (Analyst) | Spec-Kitty генерирует спецификацию, план, чеклист, подзадачи |
| 2. Верификация | SCRUM Master | Проверяет бэклог, Token Budget Gate (175k токенов/задача) |
| **CHECKPOINT** | **PM** | **Ждёт явное "да" от человека перед разработкой** |
| 3. Разработка | Developer | Непрерывный цикл: задача → код → PR |
| 3a. QDev | QDev | Проверка запускаемости кода |
| 3b. Review | Reviewer | Code review (до 3 итераций, потом эскалация) |
| 4. Тестирование | QA | PASS/FAIL с evidence |

### Мониторинг

```bash
backlog board              # Kanban-доска в терминале
backlog browser            # Веб-интерфейс со всеми артефактами
spec-kitty dashboard       # Прогресс генерации спецификации
entire log                 # Лог чекпоинтов сессии
```

---

## Фазы pipeline

### Фаза 1 — SA (Системный аналитик)

Агент исследует кодовую базу и через Spec-Kitty генерирует 4 артефакта:
- **Specification** — спецификация фичи
- **Plan** — технический план реализации
- **Checklist** — чеклист приёмки
- **Tasks** — декомпозиция на задачи

Подробности: `.claude/phases/phase-1-sa.md`

### Фаза 2 — SCRUM Master

Верифицирует бэклог после SA:
- Проверяет что каждая задача укладывается в 175k токенов контекста
- Валидирует критерии приёмки
- Оценивает зависимости между задачами

Подробности: `.claude/phases/phase-2-scrum.md`

### Фаза 3 — Разработка (непрерывный цикл)

Параллельный оркестратор: PM берёт задачи из бэклога и запускает цикл `Dev → QDev → Reviewer`. Цикл продолжается до завершения всех задач или эскалации.

Подробности: `.claude/phases/phase-3-dev.md`

### Фазы 4-6 — Тестирование и завершение

QA-агент тестирует по критериям из спецификации. Вердикт PASS/FAIL с evidence. При FAIL — задача возвращается в работу.

Подробности: `.claude/phases/phase-4-completion.md`

---

## Проверки качества кода

В `.continue/checks/` — 10 автоматических проверок, которые применяются при code review:

| # | Проверка | Файл |
|---|----------|------|
| 1 | Качество тестов | `01-test-quality.md` |
| 2 | Отсутствие debug-артефактов | `02-no-debug-artifacts.md` |
| 3 | Обработка ошибок | `03-error-handling.md` |
| 4 | Нет over-engineering | `04-no-overengineering.md` |
| 5 | Базовая безопасность | `05-security-basics.md` |
| 6 | Код запускается | `06-code-runs.md` |
| 7 | Соответствие архитектуре | `07-architecture-fit.md` |
| 8 | Краевые случаи | `08-edge-cases.md` |
| 9 | Расширенная безопасность | `09-security-extended.md` |
| 10 | Простота | `10-simplicity.md` |

---

## Инструменты

| Инструмент | Назначение | Обязательность |
|-----------|-----------|----------------|
| [Backlog.md](https://github.com/MrLesk/Backlog.md) | Task management через MCP | Обязательно |
| [Spec-Kitty](https://github.com/spec-kitty) | Генерация SDD-спецификаций | Обязательно |
| [Entire](https://entire.dev) | Session checkpoints, управление контекстом | Рекомендуется |
| [Serena](https://github.com/oraios/serena) | Language Server Protocol для агентов | Опционально |
| [Superset](https://superset.dev) | Worktree менеджмент | Опционально |

---

## Кастомизация

### Добавить агента

Создайте файл `.claude/agents/my-agent.md`:

```markdown
# MY AGENT — АВТОНОМНЫЙ АГЕНТ

## ИДЕНТИЧНОСТЬ
Ты — автономный агент. Одна задача, один результат.

## СТАРТОВЫЙ ПРОТОКОЛ
1. backlog__task_get(TASK_ID)
2. entire checkpoint "my-agent-start-{TASK_ID}"
3. ... логика ...

## ФИНАЛЬНЫЙ ОТЧЁТ
backlog__task_update(TASK_ID, notes="[MY-AGENT-REPORT] ...")
```

### Изменить pipeline

- **Фазы** — редактируйте `.claude/phases/phase-*.md`
- **Статусы** — обновите `.claude/shared/statuses.md` и `.backlog/config.yml`
- **INTAKE вопросы** — измените секцию INTAKE в `CLAUDE.md`
- **Checkpoint-стратегию** — настройте в `CLAUDE.md` и `.claude/settings.json`

### Добавить MCP-сервер

Добавьте конфигурацию в `.claude/mcp.json`:

```json
{
  "mcpServers": {
    "backlog": { "..." : "..." },
    "my-server": {
      "command": "my-mcp-server",
      "args": ["start"]
    }
  }
}
```

---

## FAQ

### PM-агент начал писать код вместо делегирования

Claude Code заточен на самостоятельное написание кода. Остановите генерацию и напомните ограничения. Промпт `CLAUDE.md` постоянно дорабатывается для минимизации такого поведения.

### Задача застряла в review-debug

После 3 неудачных итераций review задача переходит в `review-human-await`. Проверьте через `backlog board` и примите решение вручную.

### Как управляется контекст PM-агента?

[Entire](https://entire.dev) управляет контекстом через систему checkpoints. PM создаёт checkpoint перед каждой фазой, что позволяет откатиться к любому моменту процесса.

### Какой размер задач оптимален?

SCRUM Master проверяет через Token Budget Gate: одна задача должна укладываться в 175k токенов контекста. Если больше — задача дробится.

---

## Лицензия

MIT
