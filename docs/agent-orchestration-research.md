# Research: Agent Orchestration Tools

**Дата:** 2026-03-27
**Задача:** Найти OpenSource инструменты для двухуровневой системы оркестрации
**Требование:** Product Owner видит только статусы, PM-agent управляет деталями

---

## Критерии выбора

1. **Dashboard visibility** для Product Owner
2. **Task tracking** — создание фич/багов, отслеживание статусов
3. **Agent orchestration** — управление AI-агентами
4. **Integration API** — возможность интеграции с Backlog.MD
5. **OpenSource** — доступность исходного кода
6. **Claude Code compatible** — поддержка или совместимость с Claude Code

---

## Top Candidates

### 1. Mission Control ⭐ (RECOMMENDED)

**Репозиторий:** https://github.com/builderz-labs/mission-control
**Stars:** 3464★
**License:** MIT
**Tech Stack:** Next.js 16, TypeScript, SQLite

**Ключевые возможности:**
- 32 панели управления: tasks, agents, skills, logs, tokens, memory, security, cron, alerts, webhooks, pipelines
- Real-time updates: WebSocket + SSE push
- Zero external deps: SQLite, single `pnpm start`
- Role-based access: viewer, operator, admin
- Quality gates: Aegis review system
- Skills Hub: ClawdHub + skills.sh registry
- Multi-gateway: OpenClaw, CrewAI, LangGraph, AutoGen, Claude SDK
- **Claude Code bridge: read-only интеграция!**
- Agent eval & security: 4-layer framework, trust scoring, secret detection

**Установка:**
```bash
git clone https://github.com/builderz-labs/mission-control.git
cd mission-control
bash install.sh --local
open http://localhost:3000/setup
```

**Почему подходит:**
- ✅ Dashboard для PO (32 панели, real-time updates)
- ✅ Task tracking (создание, обновление, статусы)
- ✅ Agent orchestration (multi-gateway)
- ✅ Integration API (REST + WebSocket)
- ✅ OpenSource (MIT)
- ✅ Claude Code bridge (готовая интеграция!)

**Архитектура двухуровневой системы:**
```
Product Owner → Mission Control Dashboard
                    ↓ (API)
              PM-agent + Backlog.MD
                    ↓ (Task())
        SA → Dev → QA agents
```

---

### 2. AgentsMesh

**Репозиторий:** https://github.com/AgentsMesh/AgentsMesh
**Stars:** 1101★
**Описание:** AI Agent Fleet Command Center — orchestrate Claude Code, Codex CLI, Gemini CLI, Aider from single platform

**Ключевые возможности:**
- Multi-platform support (Claude Code, Codex, Gemini, Aider)
- Unified dashboard
- Agent fleet management

**Почему подходит:**
- ✅ Dashboard
- ✅ Agent orchestration
- ✅ Claude Code compatible
- ❌ Меньше звёзд чем Mission Control
- ❌ Меньше documentation

---

### 3. Bindu

**Репозиторий:** https://github.com/GetBindu/Bindu
**Stars:** 2579★
**Описание:** Turn any AI agent into a living microservice — interoperable, observable, composable

**Ключевые возможности:**
- Microservice architecture
- Observability
- Composability

**Почему подходит:**
- ✅ Agent orchestration
- ✅ OpenSource
- ❌ Microservice подход (сложнее для PO level)
- ❌ Нет готового dashboard

---

### 4. TAKT Agent Koordination Topology

**Репозиторий:** https://github.com/nrslib/takt
**Stars:** 861★
**Описание:** Define agent coordination in YAML

**Ключевые возможности:**
- YAML-based workflow definition
- Declarative coordination

**Почему подходит:**
- ✅ Agent orchestration
- ✅ OpenSource
- ❌ Нет dashboard
- ❌ YAML config (не подходит для PO)

---

## Альтернативные инструменты

### Ruflo (Claude-focused)
**Stars:** ~1500★ (из multi-agent topic)
**Описание:** Leading agent orchestration platform for Claude

**Почему не выбран:**
- Меньше documentation
- Меньше community чем Mission Control

### OpenClaw Multi-Agent System
**Stars:** ~1200★
**Описание:** 9 specialized AI agents with real-time dashboard

**Почему не выбран:**
- Более сложная архитектура
- Меньше фокус на интеграции

### Zeroshot
**Stars:** 1377★
**Описание:** Autonomous engineering team in CLI — supports Claude Code

**Почему не выбран:**
- CLI-focused (не dashboard для PO)

---

## Рекомендация

**Выбрать Mission Control** как верхний уровень оркестрации.

**Обоснование:**
1. Наибольшее количество звёзд (3464★)
2. Готовая Claude Code bridge
3. 32 панели управления — максимум visibility для PO
4. Real-time updates — PO видит прогресс мгновенно
5. Zero external deps — простой setup
6. Role-based access — PO как viewer, PM-agent как operator
7. OpenSource MIT — можно форкнуть и модифицировать

**Next Steps:**
1. ✅ TASK-29.1: Изучить Mission Control locally
2. ✅ TASK-29.2: Спроектировать bridge с Backlog.MD
3. ✅ TASK-29.3: Реализовать bridge
4. ✅ TASK-29.4: Documentation

---

## Links

- [Mission Control GitHub](https://github.com/builderz-labs/mission-control)
- [Agent Orchestration Topic](https://github.com/topics/agent-orchestration)
- [Multi-Agent Topic](https://github.com/topics/multi-agent)
- [Claude Code Docs](https://docs.anthropic.com/claude-code)
