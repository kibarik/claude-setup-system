# claude-setup

Базовый шаблон для настройки AI-окружения проекта. Копируешь в корень репозитория — и сразу получаешь рабочий pipeline: PM-оркестрация, аналитика через Spec-Kitty, управление задачами через Backlog.md, сессии через Entire, worktree-менеджмент через Superset.

## Что внутри

```
.claude/
├── CLAUDE.md              # Системный промпт PM-агента
├── settings.json          # Хуки Claude Code (Entire интеграция)
├── agents/
│   ├── analyst.md         # SA — системный аналитик (Spec-Kitty цикл)
│   ├── developer.md       # Dev — разработчик (задача → PR)
│   ├── qa.md              # QA — тестировщик (PASS/FAIL с evidence)
│   └── git-sync.md        # Git Sync — синхронизация worktree
└── commands/
    └── spec-kitty.*.md    # 14 команд Spec-Kitty (specify, plan, checklist, tasks, ...)

.backlog/
└── config.yml             # Конфиг Backlog.md MCP

.entire/
├── settings.json          # Конфиг Entire (checkpoints, сессии)
└── .gitignore             # Игнор runtime-данных Entire

.superset/
└── config.json            # Конфиг Superset (worktree менеджер)

.gitignore                 # Общий gitignore (runtime-данные исключены, конфиги отслеживаются)
```

## Быстрый старт

### 1. Склонировать шаблон в свой проект

```bash
# Вариант A — скопировать содержимое в существующий проект
git clone git@github.com:ai-oxudevelopment/claude-setup.git /tmp/claude-setup
cp -r /tmp/claude-setup/.claude /tmp/claude-setup/.backlog \
      /tmp/claude-setup/.entire /tmp/claude-setup/.superset \
      /tmp/claude-setup/.gitignore \
      /path/to/your/project/
rm -rf /tmp/claude-setup

# Вариант B — использовать как основу нового проекта
git clone git@github.com:ai-oxudevelopment/claude-setup.git my-new-project
cd my-new-project
git remote set-url origin git@github.com:your-org/your-repo.git
```

### 2. Установить зависимости

```bash
# Backlog.md — управление задачами через MCP
npm install -g backlog.md

# Entire — сессии и checkpoints
npm install -g @anthropic/entire

# Superset — worktree менеджмент (опционально)
# Установка через https://superset.dev
```

### 3. Настроить MCP

Создай `.claude/mcp.json` (или `~/.claude/mcp.json` для глобального конфига):

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

### 4. Настроить проект

```bash
# Обновить имя проекта в Backlog
sed -i '' 's/my-project/your-project-name/' .backlog/config.yml
```

### 5. Запустить Claude Code

```bash
claude
```

PM-агент автоматически:
1. Проверит структуру `.claude/agents/`
2. Подключится к Backlog MCP
3. Создаст `[SYNC]` задачу
4. Будет готов к INTAKE

## Архитектура агентов

```
Человек
  │
  ▼
┌──────────┐     ┌──────────────┐
│    PM    │────▶│  Backlog MCP │
│ (CLAUDE) │     └──────────────┘
└────┬─────┘
     │ Task()
     ├────────────────────────────────┐
     ▼                                ▼
┌──────────┐  Spec-Kitty         ┌──────────┐
│    SA    │─────────────────────│  SCRUM   │
│ Analyst  │  specify → plan →   │  Master  │
└──────────┘  checklist → tasks  └────┬─────┘
                                      │ CHECKPOINT (ждёт "да")
                                      ▼
                                ┌──────────┐
                                │   Dev    │──▶ PR
                                └────┬─────┘
                                     ▼
                                ┌──────────┐
                                │    QA    │──▶ PASS / FAIL
                                └──────────┘
```

## Pipeline фазы

| Фаза | Агент | Вход | Выход |
|------|-------|------|-------|
| INTAKE | PM | Описание задачи | 6 ответов на вопросы |
| Фаза 1 | SA (Analyst) | INTAKE + Spec-Kitty | Спецификация, план, чеклист, подзадачи |
| Фаза 2 | SCRUM Master | Подзадачи | Верифицированный бэклог |
| CHECKPOINT | PM | SCRUM-REPORT | Явное "да" от человека |
| Фаза 3 | Developer | Задача из бэклога | PR в main |
| Фаза 4 | QA | PR + критерии | PASS/FAIL с evidence |
| Фаза 5 | PM | QA-REPORT | QA Gate (done / доработка) |

## Инструменты

| Инструмент | Назначение | Документация |
|-----------|-----------|-------------|
| [Backlog.md](https://github.com/MrLesk/Backlog.md) | Task management через MCP | `backlog__task_*()` |
| [Entire](https://entire.dev) | Session checkpoints | `entire checkpoint "label"` |
| [Spec-Kitty](https://github.com/spec-kitty) | Генерация спецификаций | `/spec-kitty.*` команды |
| [Superset](https://superset.dev) | Worktree менеджмент | `.superset/config.json` |

## Кастомизация

### Добавить своего агента

Создай файл `.claude/agents/my-agent.md` по шаблону:

```markdown
# MY AGENT -- АВТОНОМНЫЙ АГЕНТ

## ИДЕНТИЧНОСТЬ
Ты -- автономный агент. Одна задача, один результат.

## СТАРТОВЫЙ ПРОТОКОЛ
1. backlog__task_get(TASK_ID)
2. entire checkpoint "my-agent-start-{TASK_ID}"
3. ... твоя логика ...

## ФИНАЛЬНЫЙ ОТЧЁТ
backlog__task_update(TASK_ID, notes="[MY-AGENT-REPORT] ...")
```

### Изменить CLAUDE.md

`CLAUDE.md` — системный промпт PM-агента. Можно изменить:
- Фазы pipeline
- Вопросы INTAKE
- Правила верификации
- Checkpoint-стратегию

## Лицензия

Internal use — ai-oxudevelopment.
