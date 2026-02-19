# Vaultra — API Request/Response Schemas

> Explicit JSON shapes for all REST API endpoints. Use for Pydantic models, OpenAPI generation, and frontend TypeScript types.

Base path: `/api/v1`. All responses use `application/json`.

---

## Authentication

### POST /auth/signup

**Request**:
```json
{
  "email": "user@example.com",
  "password": "SecureP@ss123",
  "name": "Jane Doe"
}
```

**Response** (201):
```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "Jane Doe",
    "avatar_url": null,
    "created_at": "2025-02-19T12:00:00Z"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Validation**: `email` valid format; `password` min 8 chars; `name` required.

---

### POST /auth/login

**Request**:
```json
{
  "email": "user@example.com",
  "password": "SecureP@ss123"
}
```

**Response** (200):
```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "Jane Doe",
    "avatar_url": null
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Errors**: 401 if invalid credentials.

---

### GET /auth/me

**Headers**: `Authorization: Bearer <token>`

**Response** (200):
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "name": "Jane Doe",
  "avatar_url": null,
  "businesses": [
    { "id": "660e8400-e29b-41d4-a716-446655440001", "name": "Acme Inc", "role": "owner" },
    { "id": "660e8400-e29b-41d4-a716-446655440002", "name": "Side Biz", "role": "admin" }
  ]
}
```

---

## Users & Businesses

### GET /users/me

Same as GET /auth/me.

### PATCH /users/me

**Request**:
```json
{
  "name": "Jane Smith",
  "avatar_url": "https://..."
}
```
All fields optional.

**Response** (200): Updated user object (same shape as auth/me user).

### POST /users/businesses

**Request**:
```json
{
  "name": "Acme Inc",
  "legal_entity": "Acme Inc LLC",
  "industry": "retail",
  "revenue_estimate": 500000.00,
  "founded_at": "2020-01-15"
}
```
Required: `name`. Optional: others.

**Response** (201):
```json
{
  "id": "660e8400-e29b-41d4-a716-446655440001",
  "name": "Acme Inc",
  "legal_entity": "Acme Inc LLC",
  "industry": "retail",
  "revenue_estimate": 500000.00,
  "founded_at": "2020-01-15",
  "created_at": "2025-02-19T12:00:00Z"
}
```

### PATCH /users/businesses/{id}

**Request**: Same fields as POST; all optional.

**Response** (200): Updated business object.

---

## Stripe Integration

### GET /integrations/stripe/connect?business_id={uuid}

**Response**: 302 Redirect to Stripe OAuth URL.

### GET /integrations/stripe/callback?code=...&state=...&business_id={uuid}

**Response**: 302 Redirect to `/dashboard?business_id={uuid}`.

### GET /integrations/stripe/status?business_id={uuid}

**Response** (200):
```json
{
  "connected": true,
  "account_id": "acct_xxx",
  "last_synced_at": "2025-02-19T11:45:00Z"
}
```
Or `{ "connected": false }` if not connected.

---

## Metrics & Readiness

### GET /metrics?business_id={uuid}

**Response** (200):
```json
{
  "business_id": "660e8400-e29b-41d4-a716-446655440001",
  "period_start": "2025-01-20",
  "period_end": "2025-02-19",
  "revenue_total": 125000.50,
  "revenue_volatility": 0.32,
  "chargeback_count": 2,
  "chargeback_ratio": 0.008,
  "refund_count": 5,
  "refund_ratio": 0.02,
  "payout_reliability": 0.98,
  "transaction_count": 250,
  "average_transaction_size": 500.00,
  "mrr": null
}
```

### GET /metrics/history?business_id={uuid}&start_date=2025-01-01&end_date=2025-02-19

**Response** (200):
```json
{
  "metrics": [
    {
      "period_start": "2025-01-01",
      "period_end": "2025-01-31",
      "revenue_total": 98000,
      "revenue_volatility": 0.35,
      "chargeback_ratio": 0.01,
      "payout_reliability": 0.95
    },
    { ... }
  ]
}
```

### GET /readiness?business_id={uuid}

**Response** (200):
```json
{
  "business_id": "660e8400-e29b-41d4-a716-446655440001",
  "score": 72,
  "tier": "funding_ready",
  "components": {
    "revenue_stability": 0.8,
    "risk_signals": 0.6,
    "payout_reliability": 0.95
  },
  "created_at": "2025-02-19T12:00:00Z"
}
```

### GET /readiness/history?business_id={uuid}&limit=30

**Response** (200):
```json
{
  "scores": [
    { "score": 72, "tier": "funding_ready", "created_at": "2025-02-19T12:00:00Z" },
    { "score": 68, "tier": "improving", "created_at": "2025-02-18T12:00:00Z" }
  ]
}
```

---

## Recommendations

### GET /recommendations?business_id={uuid}&status=pending&priority=high

**Query params**: `business_id` required; `status`, `priority` optional.

**Response** (200):
```json
{
  "recommendations": [
    {
      "id": "770e8400-e29b-41d4-a716-446655440001",
      "business_id": "660e8400-e29b-41d4-a716-446655440001",
      "title": "Reduce chargebacks",
      "description": "Your chargeback ratio (0.8%) is approaching 2%. Consider improving dispute descriptors.",
      "priority": "high",
      "category": "risk",
      "status": "pending",
      "estimated_impact": "+5-10 points",
      "created_at": "2025-02-19T02:00:00Z"
    }
  ]
}
```

### PATCH /recommendations/{id}

**Request**:
```json
{
  "status": "accepted"
}
```
Or `"status": "dismissed"`.

**Response** (200): Updated recommendation object.

---

## Agent

### POST /agent/chat

**Request**:
```json
{
  "business_id": "660e8400-e29b-41d4-a716-446655440001",
  "message": "What's hurting my funding readiness?",
  "conversation_id": null
}
```
`conversation_id` optional; omit for new conversation.

**Response** (200):
```json
{
  "conversation_id": "880e8400-e29b-41d4-a716-446655440001",
  "message_id": "990e8400-e29b-41d4-a716-446655440001",
  "response": "Based on your metrics, the main factors affecting your readiness are...",
  "tool_calls": []
}
```

### GET /agent/conversations/{id}

**Response** (200):
```json
{
  "id": "880e8400-e29b-41d4-a716-446655440001",
  "business_id": "660e8400-e29b-41d4-a716-446655440001",
  "messages": [
    { "role": "user", "content": "What's hurting my funding readiness?", "created_at": "2025-02-19T12:00:00Z" },
    { "role": "assistant", "content": "Based on your metrics...", "created_at": "2025-02-19T12:00:05Z" }
  ]
}
```

---

## Error Response (all endpoints)

**Format**:
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

**Codes**: `VALIDATION_ERROR`, `UNAUTHORIZED`, `FORBIDDEN`, `NOT_FOUND`, `CONFLICT`, `INTERNAL_ERROR`
