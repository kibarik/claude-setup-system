# Mission Control Architecture Analysis

## Overview
Mission Control is an open-source AI agent orchestration platform that manages AI agent fleets, dispatches tasks, tracks costs, and coordinates multi-agent workflows.

## Architecture

### Core Components
- **proxy.ts** - Auth gate + CSRF + network access control
- **app/page.tsx** - SPA shell that routes all panels
- **login/page.tsx** - Login page
- **api/** - 101 REST API routes
- **components/** - UI components (layout, dashboard, panels, chat)
- **lib/db.ts** - SQLite database (better-sqlite3, WAL mode)
- **lib/auth.ts** - Session + API key auth, RBAC
- **lib/migrations.ts** - 39 schema migrations
- **lib/scheduler.ts** - Background task scheduler
- **lib/skill-sync.ts** - Bidirectional disk ↔ DB skill sync
- **lib/skill-registry.ts** - Registry client & security scanner
- **lib/agent-evals.ts** - Four-layer agent eval framework
- **lib/security-events.ts** - Security event logger + trust scoring
- **store/index.ts** - Zustand state management

### Database Architecture
Based on OpenAPI schema, Mission Control uses SQLite with the following main entities:

#### Task Model
- **Status**: inbox, assigned, in_progress, quality_review, done
- **Priority**: critical, high, medium, low
- **Properties**: id, title, description, assigned_to, created_at, updated_at, metadata
- **Relationships**: Comments, agents, projects

#### Agent Model
- Registration and sync capabilities
- Multi-gateway support
- Framework adapters (OpenClaw, CrewAI, LangGraph, AutoGen, Claude SDK)

#### Session Model
- Claude CLI session management
- Gateway connections
- Authentication (session + API key auth, RBAC)

### API Endpoints (101 total)

#### Core Task Operations
- GET/POST /api/tasks - List/create tasks
- GET /api/tasks/queue - Poll next task for agent
- PUT /api/tasks/[id] - Update task
- GET /api/tasks/[id] - Get task details
- POST /api/tasks/[id]/broadcast - Broadcast to agents
- GET /api/tasks/[id]/comments - List task comments

#### Claude Code Integration
- GET /api/claude/sessions - List Claude CLI sessions
- POST /api/claude/sessions - Register Claude CLI session
- GET /api/claude-tasks - Get Claude Code teams and tasks

#### Agent Management
- GET/POST /api/agents - List/create agents
- POST /api/agents/register - Register new agent
- POST /api/agents/sync - Sync agent state

#### Security & Monitoring
- GET /api/security-audit - Security audit
- GET /api/security-scan - Security scan
- GET /api/activities - Activity monitoring
- GET /api/tokens - Token usage tracking

### Authentication & Authorization
- Session authentication - Cookie-based auth
- API key authentication - Headless access
- Role-based access control - Viewer, operator, admin roles
- Google Sign-In - OAuth integration with admin approval

### Real-time Features
- WebSocket + SSE - Push updates
- Smart polling - Pauses when away
- Live feed - Real-time activity updates
- Zero stale data - Smart caching strategy

### Claude Code Bridge
- Read-only integration - Surfaces Claude Code team tasks, sessions, and configs
- Auto-discovery - Finds Claude Code sessions
- Task synchronization - Displays Claude Code tasks on dashboard
- Session management - Manages Claude CLI connections

### Technology Stack
- Frontend: Next.js 16, TypeScript, Zustand
- Database: SQLite with better-sqlite3, WAL mode
- Authentication: Custom session + API key auth
- Real-time: WebSocket + Server-Sent Events
- Testing: Vitest (282 unit), Playwright (295 E2E)
- Framework: Multi-gateway adapters

## Key Insights

1. SQLite-based - Zero external dependencies, easy to deploy
2. Real-time first - WebSocket + SSE architecture
3. Extensive API - 101 REST endpoints for comprehensive control
4. Security-focused - Multi-layer security framework
5. Claude integration - Native support for Claude Code
6. Multi-agent support - Framework adapters for various agent platforms
7. Cost tracking - Built-in token usage and cost analysis
8. Quality gates - Aegis review system for task completion