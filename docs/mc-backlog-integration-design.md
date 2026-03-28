# Mission Control ↔ Backlog.MD Integration Design

## Architecture Overview

### Components
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Mission       │    │   Bridge       │    │   Backlog.MD    │    │   PM Agent      │
│   Control       │◄──►│   Service      │◄──►│   MCP Server    │◄──►│   (Optional)    │
│   Dashboard     │    │                │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
       │                       │                       │                       │
       │                       │                       │                       │
       └───────────────────────┼───────────────────────┼───────────────────────┘
                             │
                    ┌─────────────────┐
                    │   Data Store   │
                    │   (SQLite DB)  │
                    └─────────────────┘
```

### Data Flow
1. **Task Creation**:
   - PO creates task in MC Dashboard
   - Bridge Service polls /api/tasks for new tasks
   - Bridge maps MC task to Backlog format via backlog__task_create()
   - Backlog.MD updates status

2. **Status Updates**:
   - PM Agent updates task in Backlog.MD
   - Backlog.MD notifies via webhook/polling
   - Bridge Service translates Backlog status to MC format
   - Bridge calls /api/tasks/[id] to update MC task

3. **Real-time Sync**:
   - WebSocket connections for real-time updates
   - Smart polling to avoid excessive API calls
   - Conflict resolution via timestamps

## Status Mapping Table

| Mission Control Status | Backlog Status | Mapping Logic | Notes |
|----------------------|----------------|---------------|-------|
| inbox | To Do | Default mapping | New tasks |
| assigned | In Progress | When agent assigned | Trigger sync |
| in_progress | In Progress | Direct mapping | Keep MC status |
| quality_review | Review | Special handling | Requires approval |
| done | Done | Task completion | Final state |
| cancelled | Cancelled | On task deletion | Optional mapping |

### Bidirectional Mapping Rules
- **Forward (MC → Backlog)**: All MC statuses map to Backlog statuses
- **Backward (Backlog → MC)**: Only active statuses map back (To Do, In Progress, Review)
- **Conflict Resolution**: Use timestamps to determine latest update
- **Idempotency**: Include task hash in updates to prevent duplicates

## Implementation Requirements

### Bridge Service (Node.js/TypeScript)
```typescript
interface BridgeService {
  // Core operations
  syncTasksFromMC(): Promise<void>;      // Pull tasks from MC
  syncTasksToMC(): Promise<void>;        // Push updates to MC
  handleWebhook(data: WebhookData): void; // Handle Backlog events

  // Configuration
  config: {
    mcApiUrl: string;
    mcApiKey: string;
    pollingInterval: number;
    webhookSecret: string;
  };

  // Error handling
  retryLogic: ExponentialBackoff;
  errorQueue: DeadLetterQueue;
}
```

### Key Implementation Details

#### 1. Authentication
- **MC API Key**: Use environment variable for API authentication
- **Backlog.MD**: Use existing MCP credentials or service account
- **Security**: HTTPS for all API calls, request signing for webhooks

#### 2. Polling Strategy
- **MC Polling**: Every 30 seconds (configurable)
- **Backlog Polling**: Use webhook if available, else 60 seconds
- **Smart Polling**: Pause when no activity detected

#### 3. Error Handling
```typescript
enum ErrorCode {
  MC_API_ERROR = 'MC_API_ERROR',
  BACKLOG_MCP_ERROR = 'BACKLOG_MCP_ERROR',
  CONFLICT_RESOLUTION = 'CONFLICT_RESOLUTION',
  NETWORK_ERROR = 'NETWORK_ERROR',
  AUTH_ERROR = 'AUTH_ERROR'
}

interface ErrorContext {
  task?: Task;
  error: Error;
  retryCount: number;
  timestamp: Date;
}
```

#### 4. Conflict Resolution
- **Timestamp Comparison**: Use `updated_at` fields
- **Hash-based Deduplication**: Create task SHA-256 hash
- **Manual Override**: Log conflicts for manual resolution

### Webhook Configuration (Optional)
```
POST /webhooks/backlog
Headers:
  - X-Webhook-Signature: sha256=signature
  - Content-Type: application/json

Body:
{
  "task_id": "string",
  "new_status": "string",
  "timestamp": "integer",
  "hash": "string"
}
```

## Integration Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     MISSION CONTROL DASHBOARD                │
├─────────────────────────────────────────────────────────────────┤
│  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ API Gateway (/api/tasks, /api/claude-tasks)
┌─────────────────────────────────────────────────────────────────┐
│                    BRIDGE SERVICE                             │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  MC Poller     │  │   Translator   │  │ Backlog MCP    │  │
│  │  (30s)         │  │   Logic        │  │  Client        │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Webhook       │  │  Error Handler │  │  Retry Queue    │  │
│  │  Handler       │  │  & Logger      │  │  (DLQ)         │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ Webhook / API
┌─────────────────────────────────────────────────────────────────┐
│                   BACKLOG.MD MCP SERVER                       │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Task Store    │  │  Agent Logic   │  │  Webhook       │  │
│  │  (SQLite)      │  │  Engine        │  │  Handler       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐                       │
│  │  Document      │  │  Decision      │                       │
│  │  Store         │  │  Engine        │                       │
│  └─────────────────┘  └─────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

## Error Handling Strategy

### Error Scenarios
1. **MC API Unavailable**: Retry with exponential backoff
2. **Backlog MCP Error**: Log to dead-letter queue, notify admin
3. **Conflicting Updates**: Log for manual review
4. **Network Issues**: Queue operations, retry when available

### Recovery Mechanisms
- **Automatic Retry**: Exponential backoff with max 5 attempts
- **Dead Letter Queue**: Store failed operations for manual review
- **Health Checks**: Monitor service availability
- **Alerting**: Notify on critical errors

## Performance Considerations

### Optimization Strategies
1. **Batch Operations**: Process multiple tasks in single API calls
2. **Caching**: Cache frequently accessed tasks
3. **Lazy Loading**: Only load necessary task data
4. **Connection Pooling**: Reuse HTTP connections

### Monitoring & Metrics
- Task sync success rate
- API response times
- Error rates by type
- Queue backlog size

## Security Requirements

### Data Protection
- API keys encrypted at rest
- HTTPS for all communications
- Request signing for webhooks
- Audit logging for all operations

### Access Control
- Service account with minimal required permissions
- IP whitelisting for bridge service
- Rate limiting on API endpoints

## Implementation Timeline

### Phase 1: Core Bridge Service
- [ ] Set up MC API client
- [ ] Implement polling from MC
- [ ] Create backlog__task_create() integration
- [ ] Basic error handling

### Phase 2: Bidirectional Sync
- [ ] Implement webhook handling
- [ ] Add status mapping logic
- [ ] Implement conflict resolution
- [ ] Add retry mechanisms

### Phase 3: Advanced Features
- [ ] Real-time WebSocket updates
- [ ] PM Agent integration
- [ ] Performance monitoring
- [ ] Health checks and alerting

## Configuration Example

### Environment Variables
```env
# Mission Control Configuration
MC_API_URL=https://mc.example.com
MC_API_KEY=your-api-key-here
MC_POLLING_INTERVAL=30

# Backlog.MD Configuration
BACKLOG_MCP_URL=mcp://localhost:8080
BACKLOG_WEBHOOK_URL=https://bridge.example.com/webhooks
BACKLOG_WEBHOOK_SECRET=your-secret-here

# Bridge Configuration
BRIDGE_LOG_LEVEL=info
BRIDGE_MAX_RETRIES=5
BRIDGE_RETRY_DELAY=30
BRIDGE_CACHE_TTL=300
```

This integration design provides a comprehensive blueprint for connecting Mission Control with Backlog.MD while ensuring data consistency, error handling, and performance optimization.