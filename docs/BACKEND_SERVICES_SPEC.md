# Vaultra — Backend Services Specification

> Detailed specifications for each backend service module: interfaces, business logic, and implementation requirements.

## Service Module Overview

Each service module implements business logic independently, following dependency injection patterns. Services are called by FastAPI route handlers and can be tested in isolation.

---

## Auth Service

**Module**: `app/auth/service.py`

### Interface

```python
class AuthService:
    async def signup(self, email: str, password: str, name: str) -> tuple[User, str]:
        """Create new user account. Returns (user, jwt_token)."""
    
    async def login(self, email: str, password: str) -> tuple[User, str]:
        """Authenticate user. Returns (user, jwt_token). Raises 401 if invalid."""
    
    async def oauth_google(self, code: str, state: str) -> tuple[User, str]:
        """Handle Google OAuth callback. Returns (user, jwt_token)."""
    
    async def get_current_user(self, token: str) -> User:
        """Validate JWT and return user. Raises 401 if invalid."""
    
    async def refresh_token(self, token: str) -> str:
        """Generate new JWT for user (if refresh token valid)."""
```

### Business Logic

- **Password hashing**: Use `bcrypt` with cost factor 12
- **JWT**: Sign with `JWT_SECRET`, expire in 7 days, include `user_id` and `email` in payload
- **OAuth state**: Validate state parameter to prevent CSRF
- **Email uniqueness**: Enforce at DB level, return 409 Conflict if duplicate

---

## Users Service

**Module**: `app/users/service.py`

### Interface

```python
class UsersService:
    async def get_user_profile(self, user_id: UUID) -> UserProfile:
        """Get user profile with businesses."""
    
    async def update_user_profile(self, user_id: UUID, updates: dict) -> User:
        """Update user fields (name, avatar_url)."""
    
    async def create_business(self, user_id: UUID, data: BusinessCreate) -> Business:
        """Create business and add user as owner."""
    
    async def update_business(self, business_id: UUID, user_id: UUID, updates: dict) -> Business:
        """Update business. Requires user to be member with 'owner' or 'admin' role."""
    
    async def get_user_businesses(self, user_id: UUID) -> list[Business]:
        """List all businesses user is a member of."""
```

### Business Logic

- **Business ownership**: First user to create business is `owner` role
- **Authorization**: Check `user_business_memberships` table for role before updates
- **Validation**: Business name required, industry optional but validated against enum

---

## Stripe Service

**Module**: `app/stripe/service.py`

### Interface

```python
class StripeService:
    async def initiate_connect(self, business_id: UUID, user_id: UUID) -> str:
        """Generate Stripe OAuth URL. Returns redirect URL."""
    
    async def handle_connect_callback(self, code: str, business_id: UUID) -> IntegrationAccount:
        """Exchange OAuth code for account_id, store in DB, enqueue backfill job."""
    
    async def get_connection_status(self, business_id: UUID) -> ConnectionStatus:
        """Check if Stripe is connected, return account_id and last_synced_at."""
    
    async def handle_webhook(self, payload: str, signature: str) -> None:
        """Verify webhook signature, process event, store in stripe_events table."""
    
    async def sync_account_data(self, account_id: str, business_id: UUID) -> None:
        """Background job: Fetch charges, payouts, disputes from Stripe API, store in DB."""
```

### Business Logic

- **Stripe Connect**: Standard (OAuth). Use `stripe.OAuth.token` to exchange code for `stripe_user_id`; store in `integration_accounts.external_id`. Use account-specific API keys or `Stripe-Account` header when fetching data.
- **Webhook verification**: Use `stripe.Webhook.construct_event()` with `STRIPE_WEBHOOK_SECRET`
- **Idempotency**: Check `stripe_events.event_id` before processing
- **Data sync**: Fetch last 90 days on initial connect, then incremental updates
- **Error handling**: Retry failed syncs with exponential backoff, log to DLQ after 3 failures

---

## Metrics Service

**Module**: `app/metrics/service.py`

### Interface

```python
class MetricsService:
    async def compute_metrics(self, business_id: UUID, start_date: date, end_date: date) -> FinancialMetrics:
        """Aggregate raw Stripe data into metrics. Called by background job."""
    
    async def get_latest_metrics(self, business_id: UUID) -> FinancialMetrics:
        """Get most recent metric snapshot from financial_metric_snapshots table."""
    
    async def get_metric_history(self, business_id: UUID, start_date: date, end_date: date) -> list[FinancialMetrics]:
        """Get time-series metrics from snapshots table."""
    
    async def compute_readiness_score(self, business_id: UUID, metrics: FinancialMetrics) -> ReadinessScore:
        """Calculate 0-100 score + tier from metrics. Called by background job."""
    
    async def get_readiness_score(self, business_id: UUID) -> ReadinessScore:
        """Get latest readiness score from readiness_scores table."""
    
    async def get_readiness_history(self, business_id: UUID, limit: int = 30) -> list[ReadinessScore]:
        """Get score history (last N days)."""
```

### Business Logic

**Metrics computed**:
- `revenue_total`: Sum of successful charges in period
- `revenue_volatility`: Coefficient of variation (std dev / mean)
- `chargeback_ratio`: Chargebacks / total charges
- `payout_reliability`: % of payouts completed on time
- `average_transaction_size`: Mean charge amount
- `transaction_count`: Total charges

**Readiness score calculation**:
- Base score: 50
- Revenue trend: +10 if increasing, -5 if declining
- Volatility: -10 if > 0.5, +5 if < 0.2
- Chargeback ratio: -15 if > 2%, +5 if < 0.5%
- Payout reliability: +10 if > 95%, -10 if < 80%
- Clamp to 0-100 range

**Tiers** (stored as snake_case enum in DB; display labels for UI):
- 0-40: `not_ready` (display: "Not ready")
- 41-70: `improving` (display: "Improving")
- 71-85: `funding_ready` (display: "Funding-ready")
- 86-100: `highly_attractive` (display: "Highly attractive")

---

## Recommendations Service

**Module**: `app/recommendations/service.py`

### Interface

```python
class RecommendationsService:
    async def generate_recommendations(self, business_id: UUID) -> list[Recommendation]:
        """Run rules engine, generate recommendations. Called by background job."""
    
    async def get_recommendations(self, business_id: UUID, status: str | None = None, priority: str | None = None) -> list[Recommendation]:
        """List recommendations for business, optionally filtered."""
    
    async def update_recommendation_status(self, recommendation_id: UUID, user_id: UUID, status: str) -> Recommendation:
        """Mark recommendation as 'accepted' or 'dismissed'."""
```

### Business Logic

**Rules engine** (examples):
- If `chargeback_ratio > 2%`: Generate "Reduce chargebacks" recommendation
- If `revenue_volatility > 0.5`: Generate "Stabilize revenue streams" recommendation
- If `payout_reliability < 80%`: Generate "Improve payout timing" recommendation
- If `readiness_score < 50`: Generate "Focus on core metrics" recommendation

**Priority levels**:
- `high`: Score impact > 10 points
- `medium`: Score impact 5-10 points
- `low`: Score impact < 5 points

**Status lifecycle**:
- `pending` → `accepted` or `dismissed`
- Once dismissed, don't regenerate same recommendation for 30 days

---

## Agent Service

**Module**: `app/agent/service.py`

### Interface

```python
class AgentService:
    async def chat(self, business_id: UUID, user_id: UUID, message: str, conversation_id: UUID | None = None) -> AgentResponse:
        """Process user message, call MCP tools, query RAG, return LLM response."""
    
    async def get_conversation(self, conversation_id: UUID, user_id: UUID) -> Conversation:
        """Get conversation history."""
    
    async def get_readiness_breakdown(self, business_id: UUID) -> dict:
        """MCP tool: Return score components and what helps/hurts."""
    
    async def get_top_recommendations(self, business_id: UUID, limit: int = 5) -> list[Recommendation]:
        """MCP tool: Return top N recommendations."""
    
    async def get_metric_summary(self, business_id: UUID) -> dict:
        """MCP tool: Return revenue, volatility, chargebacks summary."""
    
    async def get_business_context(self, business_id: UUID) -> dict:
        """MCP tool: Return business profile (name, industry, revenue_estimate)."""
    
    async def search_knowledge(self, query: str, top_k: int = 5) -> list[dict]:
        """MCP tool: RAG query to Pinecone, return relevant chunks."""
```

### Business Logic

**Chat flow**:
1. Create or load conversation
2. Resolve business_id from user context
3. Call relevant MCP tools based on message intent (simple keyword matching or LLM-based routing)
4. Query Pinecone RAG for relevant knowledge chunks
5. Build prompt: system instructions + tool results + RAG context + conversation history + user message
6. Call LLM provider (OpenAI or Ollama)
7. Persist message and response to `agent_messages` table
8. Return response

**MCP tools**:
- Tools are Python functions that call other services (metrics, recommendations)
- Tools return structured data (dicts) that are injected into LLM prompt

**RAG**:
- Embed user query with OpenAI `text-embedding-3-small`
- Query Pinecone index `vaultra-knowledge-dev` (or prod index)
- Retrieve top-k chunks with metadata
- Inject chunks into prompt with citations

---

## Jobs Service

**Module**: `app/jobs/service.py`

### Background Jobs

**Job runner**: ARQ (async Redis queue) or Kubernetes CronJobs

**Jobs**:

1. **`stripe_sync`** (every 15 minutes):
   - For each connected Stripe account, fetch incremental data
   - Store in `stripe_events` table
   - Idempotent by event ID

2. **`compute_metrics`** (hourly):
   - For each business with Stripe connected, compute metrics for last 30 days
   - Store in `financial_metric_snapshots` table

3. **`compute_readiness`** (hourly, after metrics):
   - For each business, compute readiness score from latest metrics
   - Store in `readiness_scores` table

4. **`generate_recommendations`** (daily):
   - For each business, run rules engine
   - Generate new recommendations, store in `recommendations` table

5. **`send_notification_digest`** (daily):
   - Email users with new recommendations (stub in MVP)

---

## Error Handling Standards

### HTTP Status Codes

- `200 OK`: Success
- `201 Created`: Resource created
- `400 Bad Request`: Validation error (include error details in body)
- `401 Unauthorized`: Missing or invalid authentication
- `403 Forbidden`: Valid auth but insufficient permissions
- `404 Not Found`: Resource not found
- `409 Conflict`: Resource conflict (e.g., duplicate email)
- `422 Unprocessable Entity`: Semantic validation error
- `500 Internal Server Error`: Server error (log details, return generic message)

### Error Response Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": {
      "field": "email",
      "reason": "Invalid email format"
    }
  }
}
```

---

## Document Links

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | API endpoints, module boundaries |
| [DATA_MODEL.md](./DATA_MODEL.md) | Database schemas |
| [IMPLEMENTATION_SPEC.md](./IMPLEMENTATION_SPEC.md) | Implementation patterns |
| **BACKEND_SERVICES_SPEC.md** | This document: service interfaces and business logic |
