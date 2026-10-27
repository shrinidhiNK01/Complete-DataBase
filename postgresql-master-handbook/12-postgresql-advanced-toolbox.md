# 12 — PostgreSQL advanced toolbox: specialized features and architecture

This chapter is intentionally last. These features are powerful only after tables, constraints, joins, transactions, and plans feel natural. Choose them for a demonstrated requirement—not because PostgreSQL makes them available.

## 1. Generated columns, domains, enums, and ranges

### Generated columns

```sql
CREATE TABLE booking.reservation (
  reservation_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  duration interval GENERATED ALWAYS AS (ends_at - starts_at) STORED,
  CHECK (ends_at > starts_at)
);
```

A stored generated column is computed from the same row. It prevents duplicate application calculations and can be indexed. Its expression must be immutable and cannot refer to another row/table. Use it for deterministic derivatives, not a live “age now” field.

### Domain

```sql
CREATE DOMAIN shared.email_address AS text
  CHECK (VALUE = lower(btrim(VALUE)) AND VALUE ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$');
```

A domain gives a reusable type-level check. Do not mistake this simple expression for comprehensive RFC email validation; usually the real rule is “reasonable syntax plus verified ownership.” Domains work well for carefully stable, cross-table policy.

### Enum versus lookup table

```sql
CREATE TYPE shipping_status AS ENUM ('pending', 'packed', 'shipped', 'delivered');
```

Enums preserve a closed, ordered set and are convenient for very stable values. A lookup table is better when labels/configuration change, values need metadata, users administer values, or deployment needs flexible additions. A text `CHECK` is a simple middle option.

### Range and exclusion constraints

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE booking.room_booking (
  booking_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  room_id bigint NOT NULL,
  stay tstzrange NOT NULL,
  EXCLUDE USING gist (room_id WITH =, stay WITH &&)
);
```

`tstzrange` represents a timestamp interval; `&&` means overlaps. This constraint says the same room cannot have overlapping stays, even under concurrency. It is a textbook case where a database constraint is stronger than “check available, then insert” application logic. Decide inclusive/exclusive bounds deliberately—`[)` (inclusive start, exclusive end) lets one stay end exactly as another begins.

## 2. Arrays and composite data

PostgreSQL arrays can store a bounded homogeneous list:

```sql
CREATE TABLE content.article (
  article_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  title text NOT NULL,
  tags text[] NOT NULL DEFAULT '{}'
);

SELECT title FROM content.article WHERE tags @> ARRAY['postgresql'];
```

Arrays suit values owned by one row with no independent attributes, permissions, or relationships. If tags need descriptions, aliases, audit history, user management, or many queries, make `tag` and `article_tag` tables. Use a GIN index for a proven containment query pattern.

## 3. Partitioning: manage very large tables

Partitioning splits one logical table into child tables, commonly by time or tenant.

```sql
CREATE TABLE audit.event (
  event_id bigint GENERATED ALWAYS AS IDENTITY,
  occurred_at timestamptz NOT NULL,
  tenant_id bigint NOT NULL,
  payload jsonb NOT NULL,
  PRIMARY KEY (event_id, occurred_at)
) PARTITION BY RANGE (occurred_at);

CREATE TABLE audit.event_2026_08
PARTITION OF audit.event
FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
```

Partitions help when tables are truly large and queries prune whole partitions, retention drops a whole time slice, or maintenance benefits. They add operational work: create future partitions, manage indexes/constraints per partition, monitor planning, and handle cross-partition uniqueness limits. Partitioning is not a substitute for good indexes or an automatic speed boost. Measure first.

## 4. Bulk load and extract

```sql
-- Server-side COPY: PostgreSQL server must be able to read this path.
COPY academy.student (full_name, email, birth_date)
FROM '/server-visible/import/students.csv'
WITH (FORMAT csv, HEADER true);

-- psql client-side equivalent: file is read by your psql machine.
\copy academy.student (full_name, email, birth_date)
FROM 'C:/local/import/students.csv' WITH (FORMAT csv, HEADER true)
```

`COPY` is efficient and security-sensitive. Validate encoding, delimiter, quote rules, null representation, duplicate handling, errors, and permissions. For an important import, load into a staging table first, profile/validate rows, then insert valid data into the constrained target in a controlled transaction. The same principle applies to exports: use explicit columns and protect sensitive data.

## 5. Extensions

An extension packages database objects/features. Popular examples include `pg_trgm` for similarity search, `citext` for case-insensitive text, `uuid-ossp`/`pgcrypto` for UUID generation, `postgis` for geospatial data, and `pg_stat_statements` for query statistics.

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX course_title_trgm_idx
ON academy.course USING gin (title gin_trgm_ops);

SELECT title, similarity(title, 'postgress performence') AS score
FROM academy.course
WHERE title % 'postgress performence'
ORDER BY score DESC;
```

Extensions are server-side dependencies. Assess availability in managed services, version upgrade path, permission requirements, security posture, backup/restore needs, and expected workload before adopting one.

## 6. UUIDs and globally generated IDs

Identity bigint keys are excellent for many systems. UUIDs can help when IDs are generated independently across services/offline clients or exposure of sequential IDs is undesirable.

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE api.request (
  request_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  received_at timestamptz NOT NULL DEFAULT now()
);
```

UUIDs are larger and less naturally ordered than incrementing integers; random insertion patterns can affect B-tree locality. Use them for stated distributed/identifier requirements, not as a reflex. Modern time-ordered UUID choices may help some workloads but require careful version/tool compatibility decisions.

## 7. Advisory locks

Advisory locks are application-defined coordination locks, separate from table row locks.

```sql
SELECT pg_advisory_xact_lock(42, 202608);
-- Safely run a singleton job for tenant 42/month 202608 inside this transaction.
```

Transaction-scoped advisory locks release automatically on commit/rollback. They can coordinate a migration, scheduled job, or per-tenant resource when no natural data row exists. They do not enforce a data invariant by themselves and can become a hidden global bottleneck; document lock keys and timeouts.

## 8. Replication, high availability, and recovery concepts

| Mechanism | Main purpose |
|---|---|
| Physical streaming replication | Maintain a byte-level standby for HA/read replicas. |
| Logical replication | Replicate selected tables/changes to another PostgreSQL system. |
| Write-ahead log (WAL) archiving + base backups | Point-in-time recovery (PITR). |
| Connection pooler | Manage high client connection counts; not a database replica. |

High availability is not a switch. Define failure domains, RPO/RTO, failover ownership, monitoring, replica lag policy, backup integrity, network/TLS, and restore drills. A read replica can be stale; decide which reads may tolerate it. A replica is not a replacement for independent tested backups—corruption or mistaken deletion can replicate too.

## 9. Observability and diagnostics

Useful built-in sources include `pg_stat_activity` (sessions), `pg_locks` (locks), `pg_stat_user_tables` (table/vacuum activity), `pg_stat_user_indexes` (index usage), and, where enabled, `pg_stat_statements` (aggregated query statistics).

```sql
SELECT pid, usename, application_name, state, wait_event_type, wait_event,
       now() - query_start AS running_for, query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_start;
```

Treat live query text as sensitive: it can contain data or operational details. Build a monitoring practice around query latency, error rate, lock waits, connection saturation, cache/I/O, vacuum health, table/index growth, replication lag, and backup success. Alerts need owners and runbooks, not merely dashboards.

## 10. Advanced-toolbox decision questions

Before adding any advanced feature, answer:

1. What precise business or operational requirement does it solve?
2. Why are simpler relational tables/constraints/indexes insufficient?
3. What is the query/write/maintenance cost?
4. What breaks during upgrade, restore, replica failover, or developer onboarding?
5. How will we test correctness, monitor health, and reverse the decision?

That discipline is more valuable than memorizing feature names.
