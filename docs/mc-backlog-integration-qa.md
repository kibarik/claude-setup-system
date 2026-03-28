# Mission Control ↔ Backlog.MD Integration - Critical Questions & Answers

## 1. Database Schema Architecture

### Q: What is the exact database schema for Mission Control?
**A:** Mission Control uses SQLite with the following core entities:

**Tasks Table**:
```sql
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT CHECK(status IN ('inbox', 'assigned', 'in_progress', 'quality_review', 'done')),
  priority TEXT CHECK(priority IN ('critical', 'high', 'medium', 'low')),
  assigned_to TEXT,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER DEFAULT (strftime('%s', 'now')),
  metadata TEXT,
  project_id INTEGER,
  FOREIGN KEY (project_id) REFERENCES projects(id)
);
```

**Agents Table**:
```sql
CREATE TABLE agents (
  id INTEGER PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  type TEXT,
  gateway TEXT,
  config TEXT,
  created_at INTEGER DEFAULT (strftime('%s', 'now'))
);
```

**Sessions Table**:
```sql
CREATE TABLE sessions (
  id INTEGER PRIMARY KEY,
  agent_id INTEGER,
  session_id TEXT UNIQUE,
  status TEXT,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY (agent_id) REFERENCES agents(id)
);
```

## 2. API Endpoints Detail

### Q: What are the exact API endpoints for task operations?
**A:** Mission Control exposes 101 REST endpoints with these key task operations:

**Core Task Endpoints**:
- `GET /api/tasks` - List tasks with filtering (status, assigned_to, priority)
- `POST /api/tasks` - Create new task
- `GET /api/tasks/queue` - Poll task queue for agents
- `PUT /api/tasks/[id]` - Update task status/details
- `GET /api/tasks/[id]` - Get specific task
- `POST /api/tasks/[id]/broadcast` - Broadcast to multiple agents
- `GET /api/tasks/[id]/comments` - Get task comments

**Claude Code Integration**:
- `GET /api/claude/sessions` - List Claude CLI sessions
- `POST /api/claude/sessions` - Register new session
- `GET /api/claude-tasks` - Get Claude Code teams and tasks

**Authentication**:
- Uses session cookies and API keys
- Role-based access control (viewer, operator, admin)
- Supports Google OAuth integration

## 3. Claude Code Bridge Implementation

### Q: How does the Claude Code bridge technically work?
**A:** The Claude Code bridge implementation:

**Architecture**:
1. **Session Discovery**: Scans `~/.claude` directory for active sessions
2. **Task Integration**: Reads `~/.claude/backlog/tasks.json` for task data
3. **Real-time Updates**: Polls for changes and syncs to dashboard
4. **Read-only Display**: Shows tasks in MC dashboard without direct manipulation

**Technical Details**:
```typescript
// Bridge implementation pattern
class ClaudeCodeBridge {
  private sessions: Session[] = [];

  async discoverSessions(): Promise<Session[]> {
    // Scan ~/.claude for session files
    // Parse session metadata and status
    return this.sessions;
  }

  async getTasks(): Promise<Task[]> {
    // Read from ~/.claude/backlog/tasks.json
    // Transform to MC format
    return transformedTasks;
  }

  async syncToDashboard(): Promise<void> {
    // Call MC API to display tasks
    // No write operations, only display
  }
}
```

**Limitations**:
- Read-only integration
- Does not modify Claude Code tasks
- Only surfaces data in MC dashboard
- Manual updates still require Claude Code CLI

## 4. Backlog.MD Listening Mechanism

### Q: How to listen for changes in Backlog.MD?
**A:** Backlog.MD supports multiple update mechanisms:

**Option 1: Webhook (Recommended)**
- Configure webhook in Backlog.MD settings
- Bridge service receives real-time updates
- Low latency, efficient sync

**Option 2: Polling**
- Bridge polls Backlog.MD periodically
- Interval: 60 seconds (configurable)
- Simpler setup, less efficient

**Implementation**:
```typescript
// Webhook handler
app.post('/webhooks/backlog', (req, res) => {
  const signature = req.headers['x-webhook-signature'];
  const payload = req.body;

  if (!verifySignature(payload, signature)) {
    return res.status(401).send('Invalid signature');
  }

  const { task_id, new_status, timestamp } = payload;
  handleTaskUpdate(task_id, new_status, timestamp);
  res.send('OK');
});
```

## 5. Status Mapping Design

### Q: How to map MC statuses ↔ Backlog statuses?
**A:** Comprehensive status mapping with bidirectional logic:

**Forward Mapping (MC → Backlog)**:
| MC Status | Backlog Status | Trigger |
|-----------|----------------|---------|
| inbox | To Do | New task creation |
| assigned | In Progress | Agent assignment |
| in_progress | In Progress | Direct sync |
| quality_review | Review | Quality gate activation |
| done | Done | Task completion |

**Backward Mapping (Backlog → MC)**:
| Backlog Status | MC Status | Action |
|----------------|-----------|--------|
| To Do | inbox | Create in MC |
| In Progress | in_progress | Update status |
| Review | quality_review | Apply quality gate |
| Done | done | Mark completed |
| Cancelled | cancelled | Handle deletion |

**Conflict Resolution**:
- Use `updated_at` timestamps
- Newer timestamp wins
- Hash-based deduplication
- Manual override option

## 6. Conflict Handling Strategy

### Q: How to handle simultaneous updates from both systems?
**A:** Multi-layer conflict resolution:

**1. Timestamp-based Resolution**:
```typescript
interface Task {
  id: string;
  mc_updated_at: number;
  backlog_updated_at: number;
  mc_status: string;
  backlog_status: string;
}

function resolveConflict(task: Task): string {
  if (task.mc_updated_at > task.backlog_updated_at) {
    return task.mc_status;
  } else if (task.backlog_updated_at > task.mc_updated_at) {
    return task.backlog_status;
  } else {
    // Equal timestamps - use system priority
    return 'backlog'; // Or 'mc' based on config
  }
}
```

**2. Operational Queue**:
- Store conflicting updates in dead-letter queue
- Notify admins of conflicts
- Manual resolution interface
- Auto-resolution after N days

**3. Prevention Mechanisms**:
- Lock tasks during critical operations
- Use optimistic locking with version numbers
- Implement request timeouts
- Add operation timestamps

## 7. Idempotency Implementation

### Q: How to ensure idempotent operations?
**A:** Comprehensive idempotency strategy:

**1. Request Hashing**:
```typescript
function generateTaskHash(task: Task): string {
  const payload = {
    id: task.id,
    title: task.title,
    status: task.status,
    updated_at: task.updated_at
  };
  return createHash('sha256').update(JSON.stringify(payload)).digest('hex');
}
```

**2. Idempotency Keys**:
```typescript
const idempotencyCache = new Map();

app.post('/api/tasks', (req, res) => {
  const idempotencyKey = req.headers['x-idempotency-key'];

  if (idempotencyCache.has(idempotencyKey)) {
    return res.status(200).json(idempotencyCache.get(idempotencyKey));
  }

  // Process request
  const result = await createTask(req.body);
  idempotencyCache.set(idempotencyKey, result);
  return res.status(201).json(result);
});
```

**3. Deduplication**:
- Store processed hashes in memory
- TTL-based cleanup (24 hours)
- Batch processing for bulk operations
- Database-level constraints

## 8. Error Handling Architecture

### Q: What if MC is unavailable? What if Backlog is unavailable?
**A:** Robust error handling with fallback strategies:

**MC Unavailable Scenarios**:
1. **Temporary Outage**:
   - Queue operations locally
   - Exponential backoff retries
   - Graceful degradation to read-only mode

2. **Extended Outage**:
   - Switch to local cache mode
   - Alert administrators
   - Switch to manual sync mode

**Backlog.MD Unavailable Scenarios**:
1. **MCP Service Down**:
   - Use polling fallback
   - Cache locally
   - Continue MC operations

2. **Complete Service Loss**:
   - Store in dead-letter queue
   - Notify admins
   - Temporarily disable bidirectional sync

**Error Hierarchy**:
```typescript
enum ErrorSeverity {
  CRITICAL = 'CRITICAL',    // System unusable
  HIGH = 'HIGH',            // Major functionality loss
  MEDIUM = 'MEDIUM',        // Reduced functionality
  LOW = 'LOW',              // Minor issues
  INFO = 'INFO'             // Informational only
}
```

**Recovery Procedures**:
- Automated retry with jitter
- Circuit breaker patterns
- Health check endpoints
- Manual override capabilities

## 9. Authentication & Authorization

### Q: How to authenticate the bridge service?
**A:** Multi-layer authentication strategy:

**Mission Control Authentication**:
```typescript
// API Key authentication
const authHeaders = {
  'Authorization': `Bearer ${process.env.MC_API_KEY}`,
  'Content-Type': 'application/json'
};

// Session-based alternative
const sessionAuth = {
  'Cookie': `session=${process.env.MC_SESSION_ID}`
};
```

**Backlog.MD Authentication**:
- Use existing MCP server credentials
- Service account with minimal permissions
- Token-based authentication for API calls

**Security Measures**:
- HTTPS for all communications
- Request signing for webhooks
- IP whitelisting
- Rate limiting
- Audit logging

**Service Account Setup**:
```typescript
interface ServiceAccount {
  id: string;
  name: string;
  permissions: string[];
  api_key: string;
  created_at: Date;
  last_used: Date;
}
```

This comprehensive Q&A document addresses the most critical aspects of the Mission Control ↔ Backlog.MD integration, providing technical details and implementation guidance for each component.