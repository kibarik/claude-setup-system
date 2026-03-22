# Suggested Commands: claude-setup

## Development Commands

### Backlog.md
```bash
# Task management
backlog board              # Kanban-доска в терминале
backlog browser            # Веб-интерфейс со всеми артефактами
backlog task list          # Список задач
backlog task get <id>      # Получить задачу

# Documents and Decisions
backlog doc list           # Список документов
backlog decision list      # Список архитектурных решений

# Configuration
backlog init               # Инициализация backlog в проекте
```

### Spec-Kitty
```bash
# Workflow commands (14 total)
spec-kitty specify         # Создать/обновить спецификацию
spec-kitty plan            # Создать план реализации
spec-kitty checklist       # Генерировать чек-лист приёмки
spec-kitty tasks           # Декомпозировать на work packages
spec-kitty dashboard       # Прогресс генерации спецификации
spec-kitty status          # Показать kanban board
spec-kitty implement       # Создать worktree для задачи
spec-kitty review          # Code review задачи
spec-kitty accept          # Финальная приёмка фичи
spec-kitty merge           # Слияние в main и cleanup
spec-kitty analyze         # Анализ соответствия артефактов
spec-kitty clarify         # Уточнение спецификации
spec-kitty research        # Phase 0 исследование
spec-kitty constitution    # Создание проектной конституции
```

### Entire
```bash
# Session management
entire log                 # Лог чекпоинтов сессии
entire log --limit 5       # Последние 5 чекпоинтов
entire rewind <label>      # Откат к чекпоинту

# Hooks (configured in .claude/settings.json)
entire hooks claude-code session-start
entire hooks claude-code session-end
entire hooks claude-code pre-task
entire hooks claude-code post-task
entire hooks claude-code user-prompt-submit
```

### Git Worktree Management
```bash
# Через Superset (.superset/config.json)
# Управление worktree для изолированной разработки
```

## System Utilities (Darwin/macOS)

### File System
```bash
ls -la                     # List files with details
find . -name "*.md"        # Search files by pattern
pwd                        # Print working directory
```

### Git
```bash
git status                 # Check repository status
git pull                   # Pull latest changes
git checkout <branch>      # Switch branch
git submodule update --init --recursive  # Init submodules
```

### Search
```bash
grep -r "pattern" .        # Recursive search
find . -type f -name "*.json"  # Find files by type
```

## Claude Code
```bash
claude                     # Запуск Claude Code
claude mcp list            # Список MCP-серверов
claude mcp add <name>      # Добавить MCP-сервер
```

## Checkpoint System

### Default Checkpoints
| Label | Moment |
|-------|--------|
| `sa-start-{TASK_ID}` | SA начал работу |
| `sa-specify-{TASK_ID}` | Specification сгенерирована |
| `sa-plan-{TASK_ID}` | Plan сгенерирован |
| `sa-checklist-{TASK_ID}` | Checklist сгенерирован |
| `sa-complete-{TASK_ID}` | Все этапы SA завершены |
| `dev-start-{TASK_ID}` | Dev начал реализацию |
| `dev-plan-{TASK_ID}` | Dev написал план |
| `dev-pr-{TASK_ID}` | PR открыт |
| `qa-start-{TASK_ID}` | QA начал тестирование |
| `qa-complete-{TASK_ID}` | QA вынес вердикт PASS |
| `qa-fail-{TASK_ID}` | QA вынес вердикт FAIL |
