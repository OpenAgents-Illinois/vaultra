# Vaultra — Data Model Specification

> PostgreSQL schemas, relationships, and migration strategy. Spec-driven; implementation follows.

## Entity Relationship Overview

```
users ──┬──< user_business_memberships >── businesses
        │                                      │
        │                                      ├──< integration_accounts
        │                                      ├──< financial_metric_snapshots
        │                                      ├──< readiness_scores
        │                                      ├──< recommendations
        │                                      └──< agent_conversations
        │
        └──< agent_conversations
```

---

## Tables

### 1. users

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | |
| email | VARCHAR(255) | UNIQUE, NOT NULL | |
| hashed_password | VARCHAR(255) | nullable (OAuth users) | bcrypt |
| name | VARCHAR(255) | | |
| avatar_url | VARCHAR(512) | | OAuth provider |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes**: `UNIQUE (email)`

---

### 2. businesses

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | |
| name | VARCHAR(255) | NOT NULL | Business name |
| legal_entity | VARCHAR(255) | | Legal entity name |
| industry | VARCHAR(100) | | e.g., retail, saas |
| revenue_estimate | DECIMAL(15,2) | | Annual revenue (optional) |
| founded_at | DATE | | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

---

### 3. user_business_memberships

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| user_id | UUID | FK users.id, PK | |
| business_id | UUID | FK businesses.id, PK | |
| role | VARCHAR(20) | NOT NULL, default 'owner' | owner, admin, viewer |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes**: `(business_id)` for lookups by business

---

### 4. integration_accounts

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | |
| business_id | UUID | FK businesses.id, NOT NULL | |
| provider | VARCHAR(50) | NOT NULL | stripe |
| external_id | VARCHAR(255) | NOT NULL | Stripe account ID |
| access_token_encrypted | TEXT | | Encrypted OAuth token |
| metadata | JSONB | | stripe_user_id, etc. |
| status | VARCHAR(20) | default 'active' | active, revoked, error |
| last_synced_at | TIMESTAMPTZ | | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes**: `UNIQUE (business_id, provider)`, `(provider, external_id)`

---

### 5. stripe_events (raw event log)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | |
| integration_id | UUID | FK integration_accounts.id | |
| stripe_event_id | VARCHAR(255) | NOT NULL, UNIQUE | Idempotency |
| event_type | VARCHAR(100) | NOT NULL | charge.created, payout.paid |
| payload | JSONB | | Minimal; no PCI |
| processed_at | TIMESTAMPTZ | | Null until processed |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes**: `UNIQUE (stripe_event_id)`, `(integration_id, created_at)`, `(processed_at)` where processed_at is null

---

### 6. financial_metric_snapshots

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | |
| business_id | UUID | FK businesses.id, NOT NULL | |
| period_start | DATE | NOT NULL | Inclusive |
| period_end | DATE | NOT NULL | Inclusive |
| revenue_total | DECIMAL(15,2) | | Sum of successful charges |
| revenue_volatility | DECIMAL(10,4) | | Std dev / mean |
| chargeback_count | INT | default 0 | |
| chargeback_ratio | DECIMAL(5,4) | | chargebacks / transactions |
| refund_count | INT | default 0 | |
| refund_ratio | DECIMAL(5,4) | | |
| payout_reliability | DECIMAL(5,4) | | % payouts completed on time (0-1) |
| transaction_count | INT | default 0 | |
| average_transaction_size | DECIMAL(15,2) | | Mean charge amount |
| mrr | DECIMAL(15,2) | | Subscription MRR (if applicable) |
| metrics_json | JSONB | | Extensible: extra KPIs |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes**: `UNIQUE (business_id, period_start, period_end)`, `(business_id, period_end DESC)`

---

### 7. readiness_scores

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | |
| business_id | UUID | FK businesses.id, NOT NULL | |
| score | INT | NOT NULL, CHECK (0–100) | 0–100 |
| tier | VARCHAR(30) | NOT NULL | not_ready, improving, funding_ready, highly_attractive |
| components | JSONB | | Breakdown: { revenue_stability: 0.8, risk_signals: 0.6 } |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes**: `(business_id, created_at DESC)` — one row per computation; latest = current

---

### 8. recommendations

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | |
| business_id | UUID | FK businesses.id, NOT NULL | |
| title | VARCHAR(255) | NOT NULL | |
| description | TEXT | | |
| priority | VARCHAR(20) | default 'medium' | low, medium, high |
| category | VARCHAR(50) | | cash_flow, risk, revenue, etc. |
| status | VARCHAR(20) | default 'pending' | pending, accepted, dismissed |
| metric_refs | JSONB | | Which metrics triggered this |
| estimated_impact | VARCHAR(100) | | Qualitative |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes**: `(business_id, status)`, `(business_id, created_at DESC)`

---

### 9. agent_conversations

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | |
| business_id | UUID | FK businesses.id, NOT NULL | |
| user_id | UUID | FK users.id, NOT NULL | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes**: `(business_id, updated_at DESC)`, `(user_id)`

---

### 10. agent_messages

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | |
| conversation_id | UUID | FK agent_conversations.id, NOT NULL | |
| role | VARCHAR(20) | NOT NULL | user, assistant |
| content | TEXT | NOT NULL | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes**: `(conversation_id, created_at)` for ordering

---

## Enums (PostgreSQL ENUM or VARCHAR)

| Enum | Values |
|------|--------|
| membership_role | owner, admin, viewer |
| integration_provider | stripe |
| integration_status | active, revoked, error |
| recommendation_priority | low, medium, high |
| recommendation_status | pending, accepted, dismissed |
| readiness_tier | not_ready, improving, funding_ready, highly_attractive |

---

## Migration Strategy

- **Tool**: Alembic
- **Location**: `backend/alembic/`
- **Naming**: `YYYYMMDD_HHMM_description.py`

**Initial migration** will create all tables above in order (respecting FK dependencies).

**Subsequent migrations** for:
- New columns (add with default or nullable first)
- New tables
- Index changes
- Data backfills if needed

---

## Sample Queries (for reference)

```sql
-- Latest readiness for a business
SELECT * FROM readiness_scores
WHERE business_id = :bid
ORDER BY created_at DESC
LIMIT 1;

-- Pending recommendations
SELECT * FROM recommendations
WHERE business_id = :bid AND status = 'pending'
ORDER BY
  CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
  created_at DESC;

-- Metrics for last 6 months
SELECT * FROM financial_metric_snapshots
WHERE business_id = :bid
  AND period_end >= CURRENT_DATE - INTERVAL '6 months'
ORDER BY period_end DESC;
```

---

## Document Links

| Document | Purpose |
|----------|---------|
| [SPEC.md](./SPEC.md) | Product scope |
| [TECH_STACK.md](./TECH_STACK.md) | Technology choices |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Services, APIs |
| **DATA_MODEL.md** | This document: schemas |
