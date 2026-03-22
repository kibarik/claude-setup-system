# Code Style & Conventions: claude-setup

## Documentation Style

### Agent Files (.claude/agents/*.md)
- Используются markdown-файлы с чёткой структурой
- Основные секции: ИДЕНТИЧНОСТЬ, СТАРТОВЫЙ ПРОТОКОЛ, ФИНАЛЬНЫЙ ОТЧЁТ
- Каждый агент имеет строго определённую роль и ограничения
- Промпты на русском языке (для этого проекта)

### CLAUDE.md (PM Agent)
- Определяет полный pipeline разработки
- Жёсткие запреты на определённые действия (таблицы "Запрещено → Правильное действие")
- Алгоритмизация всех процессов
- MCP-first подход (все операции через backlog__*)

## Naming Conventions

### Task Titles
- `[SYNC]` — задачи синхронизации
- `[ANALYST]` — задачи SA-аналитика
- `[PM-CHECK]` — задачи верификации PM
- `[SCRUM]` — задачи Scrum Master
- `[DEV]` — задачи разработки
- `[REVIEW]` — задачи review
- `[QA]` — задачи тестирования
- `[BUG]` — баг-репорты
- `[DOCS]` — задачи документации
- `[SETUP]` — задачи настройки окружения

### Memory Logs (в notes задач)
- `[PM-LOG]` — записи PM
- `[SYNC-REPORT]` — отчёт Git Sync
- `[SA-REPORT]` — отчёт SA
- `[SA-DECISION]` — решения принятые SA
- `[SA-ASSUMPTION]` — предположения SA
- `[SCRUM-REPORT]` — отчёт Scrum
- `[DEV-LOG]` — лог разработки
- `[REVIEW-REPORT]` — отчёт review
- `[QA-LOG]` — лог тестирования
- `[DOCS-REPORT]` — отчёт консолидации доков

### Checkpoint Labels
- Формат: `{phase}-{action}-{TASK_ID}`
- Примеры: `sa-start-123`, `dev-pr-456`

## Configuration Files

### .claude/settings.json
- Определяет hooks для Entire integration
- События: SessionStart, SessionEnd, PreToolUse, PostToolUse, UserPromptSubmit
- Разрешения: deny для .entire/metadata/**

### .backlog/config.yml
- `project_name`: имя проекта
- `statuses`: массив статусов (To Do → In Progress → Done)
- `default_status`: начальный статус
- `auto_open_browser`: открывать web interface
- `default_port`: порт для browser (6420)

## MCP Integration Patterns

### Backlog MCP Operations
```python
# Чтение
backlog__task_list()                    # Список всех задач
backlog__task_get(id)                   # Получить задачу

# Запись
backlog__task_create(title, description)  # Создать задачу
backlog__task_update(id, status=..., notes=...)  # Обновить

# Документы
backlog__doc_create(title, content)     # Создать документ
backlog__doc_list()                     # Список документов

# Решения
backlog__decision_create(title, content, status)  # Архитектурное решение
backlog__decision_list()                # Список решений
```

### Status Transitions (Правила перехода)
| Transition | Condition | Action |
|------------|-----------|--------|
| → in-progress | агент запущен | task_update(id, status="in-progress") |
| → code-review | DEV завершил | task_update(id, status="code-review") |
| → review-debug | REVIEW отклонил | task_update(id, status="review-debug") |
| → review-human-await | 3+ отклонений | task_update(id, status="review-human-await") |
| → ready-for-testing | REVIEW одобрил | task_update(id, status="ready-for-testing") |
| → done | QA Gate пройден | task_update(id, status="done") |

## Evidence Requirements

Все логи ДОЛЖНЫ содержать `evidence` — реальные данные, не слова:
- `[PM-LOG verified | evidence: task_id=123]` ✓
- `[PM-LOG verified | evidence: проверено]` ✗ (это слова, не evidence)

Для QA:
- `[QA-LOG verified | evidence: <вывод тестов>]` ✓
- Вывод тестов обязателен, без него вердикт не принимается

## Task Decomposition Rules

### Token Budget Gate (175k токенов/задача)
Признаки превышения:
- >3 модулей
- >2 интеграций
- >5 итераций тестов
- Описание содержит "и также", "а ещё", "плюс к этому"

Действие: Разбить на подзадачи через backlog__task_create()

## Git Workflow

### Worktree Strategy
- Каждая задача — отдельный worktree
- Worktree создаётся через spec-kitty implement
- После merge — cleanup через spec-kitty merge

### Branch Protection
- Основная разработка в worktree (не в main)
- PR — обязательный этап перед merge
- Code review — обязателен
