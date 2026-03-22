# Project Overview: claude-setup

## Purpose
Базовый шаблон для настройки AI-окружения проекта с PM-оркестрацией. Копируется в корень репозитория и предоставляет готовый pipeline: PM-оркестрация, аналитика через Spec-Kitty, управление задачами через Backlog.md, сессии через Entire, worktree-менеджмент через Superset.

## Tech Stack
- **Backlog.md** — Task management через MCP
- **Spec-Kitty** — Генерация SDD-спецификаций
- **Entire** — Session checkpoints, управляемый контекст
- **Superset** — Worktree менеджмент
- **Serena MCP** — Семантическая навигация по коду

## Project Structure
```
CLAUDE.md                  # Системный промпт PM-агента (единственный источник истины)
.claude/
├── settings.json          # Хуки Claude Code (Entire интеграция)
├── agents/
│   ├── analyst.md         # SA — системный аналитик (Spec-Kitty цикл)
│   ├── developer.md       # Dev — разработчик (задача → PR)
│   ├── reviewer.md        # Reviewer — code review агент
│   ├── qa.md              # QA — тестировщик (PASS/FAIL с evidence)
│   ├── scrum-master.md    # Scrum — верификация бэклога
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

.serena/
└── memories/              # Knowledge base проекта
```

## Key Concepts

### Pipeline Phases
1. **INTAKE** — PM задаёт 6 вопросов о задаче
2. **Phase 1 (SA)** — Analyst генерирует спецификацию через Spec-Kitty
3. **Phase 2 (SCRUM)** — Scrum Master верифицирует бэклог
4. **CHECKPOINT** — PM ждёт явного "да" от человека
5. **Phase 3 (Dev)** — Developer реализует задачу → PR
6. **Phase 4 (QA)** — QA тестирует → PASS/FAIL с evidence
7. **Phase 5 (QA Gate)** — PM проверяет результат

### Agent Roles
| Agent | File | Responsibility | Limitations |
|-------|------|----------------|-------------|
| **PM** | `CLAUDE.md` (корень проекта) | Оркестрация, управление Backlog через MCP, вызов агентов | Не пишет код, не анализирует, не читает кодовую базу |
| **SA** | analyst.md | Генерирует спецификации через Spec-Kitty, создаёт подзадачи | Не создаёт файлы вручную, не пишет код |
| **Dev** | developer.md | Реализует одну задачу, открывает PR | Не берёт больше одной задачи, не закрывает без PR |
| **Reviewer** | reviewer.md | Проводит code review задач | Только review, не исправляет |
| **QA** | qa.md | Тестирует по критериям, выносит PASS/FAIL | Не исправляет баги, вердикт только с evidence |
| **Scrum** | scrum-master.md | Верифицирует бэклог, Token Budget Gate (175k токенов/задача) | Не переписывает задачи с нуля |
| **Git Sync** | git-sync.md | Синхронизирует worktree, git pull, субмодули | Не удаляет entire-ветки |

### Integration Points
- **Entire hooks** (.claude/settings.json) — автоматические checkpoints на событиях Task/TodoWrite
- **Backlog MCP** — task management через интерфейс MCP
- **Spec-Kitty commands** — 14 slash-команд для генерации спецификаций
