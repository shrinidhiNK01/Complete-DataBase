# 09 — Transactions, indexes, performance, security, and operations

This is where a database moves from “works on my laptop” to a reliable system. Correctness comes first; performance and operations preserve that correctness under real data, concurrency, failure, and change.

## 1. ACID transactions

A **transaction** is a unit of work: all its changes commit together, or none do.

| Property | Meaning |
|---|---|
| Atomicity | All changes happen or none happen. |
| Consistency | A committed result obeys declared constraints and rules. |
| Isolation | Concurrent transactions behave according to the configured isolation level. |
| Durability | After commit, changes survive a crash according to PostgreSQL durability configuration. |

```sql
BEGIN;

INSERT INTO sales.orders (customer_id, status) VALUES (42, 'pending')
RETURNING order_id;

INSERT INTO sales.order_item (order_id, product_id, quantity, unit_price)
VALUES (1001, 7, 2, 299.00);

UPDATE inventory.stock
SET available_quantity = available_quantity - 2
WHERE product_id = 7
  AND available_quantity >= 2;

-- Check that exactly one stock row changed before accepting order.
COMMIT;
```

If any statement errors, `ROLLBACK;` undoes the transaction’s changes. In real application code, test row counts and raise/abort if stock update affected zero rows. Do not commit an order whose inventory reservation failed.

### Savepoints: partial rollback

```sql
BEGIN;
UPDATE academy.course SET list_price = list_price * 1.05;
SAVEPOINT price_trial;
DELETE FROM academy.course WHERE course_code = 'ACCIDENT';
ROLLBACK TO SAVEPOINT price_trial; -- keeps the price update, undoes delete
COMMIT;
```

Savepoints are useful inside a larger valid unit of work. They do not make unplanned broad changes safe; first preview the target rows.

## 2. MVCC and isolation intuition

PostgreSQL uses **multi-version concurrency control (MVCC)**. Writers do not usually block readers, and readers see a consistent snapshot. Updates create new row versions; old versions remain until no active transaction needs them, then vacuum can reclaim space.

```mermaid
sequenceDiagram
  participant A as Transaction A
  participant DB as PostgreSQL
  participant B as Transaction B
  A->>DB: BEGIN; read account balance = 100
  B->>DB: UPDATE balance; COMMIT
  A->>DB: later query at READ COMMITTED sees new committed data
  A->>DB: COMMIT
```

PostgreSQL’s default is **READ COMMITTED**: each statement sees rows committed before that statement begins. `REPEATABLE READ` gives a stable transaction snapshot; `SERIALIZABLE` makes concurrent transactions behave as if serially ordered, but may abort one with a serialization failure. Applications must retry the entire transaction on serialization/deadlock failures.

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
-- Read, validate condition, write.
COMMIT;
```

There is no isolation level that removes the need to model invariants and retry transient concurrency errors. Keep transactions short: do not hold one open while waiting for user input, making HTTP calls, or rendering a page.

## 3. Locks, deadlocks, and row-level coordination

`UPDATE` and `DELETE` take row locks. Concurrent changes to the same row wait. Explicit locking is sometimes necessary for a read-then-write decision:

```sql
BEGIN;
SELECT available_quantity
FROM inventory.stock
WHERE product_id = 7
FOR UPDATE;

-- Decide and update the locked row in the same short transaction.
COMMIT;
```

`FOR UPDATE` locks selected rows against conflicting writers/lockers. Use it only with a clear invariant. If two transactions wait on each other’s locks, PostgreSQL detects a **deadlock**, aborts one, and the application must retry it. Prevent deadlocks by accessing rows/tables in a consistent order and keeping transactions short.

For job queues, `FOR UPDATE SKIP LOCKED` can let multiple workers claim different pending jobs, but it deliberately skips locked work. Design retries, visibility timeouts, and starvation handling.

## 4. Indexes: data structures for access paths

An index can find candidate rows without scanning every table row. It costs disk space and makes writes more expensive because every insert/update/delete must maintain it. Index a proven query pattern, not every column.

```sql
CREATE INDEX enrollment_course_enrolled_at_idx
ON academy.enrollment (course_id, enrolled_at DESC);
```

This supports queries filtering by `course_id` then ordering/ranging by `enrolled_at`. The order of a multi-column B-tree index matters: it is most useful for leftmost key conditions.

| Index type | Good for | Example |
|---|---|---|
| B-tree (default) | equality, ranges, sorting | IDs, dates, prices, most keys |
| GIN | contains/membership in composite values | `jsonb`, arrays, full-text `tsvector` |
| GiST | ranges, geometry, nearest-neighbor patterns | overlaps, PostGIS |
| BRIN | very large physically correlated tables | append-only time series |
| Hash | equality only; niche | rarely better than B-tree |

### Index patterns

```sql
-- Unique index/constraint: enforce and speed lookup.
CREATE UNIQUE INDEX student_email_lower_uniq
ON academy.student (lower(email));

-- Partial index: only active data; predicate must match query usage.
CREATE INDEX enrollment_active_idx
ON academy.enrollment (course_id, enrolled_at DESC)
WHERE status = 'enrolled';

-- Cover selected values to enable index-only scans when visibility permits.
CREATE INDEX course_active_code_idx
ON academy.course (course_code)
INCLUDE (title, list_price)
WHERE active;
```

Prefer a normal unique constraint for straightforward uniqueness. An expression index is justified when you deliberately define equality as normalized equality. Consider PostgreSQL’s `citext` extension as an alternative for case-insensitive text, but document its collation/semantics.

PostgreSQL automatically creates indexes for primary keys/unique constraints; it does **not** automatically create an index for a foreign-key child column. Add one when joins or parent changes need it.

## 5. Measure with EXPLAIN, never guess

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT student_id, course_id, enrolled_at
FROM academy.enrollment
WHERE course_id = 3
  AND enrolled_at >= now() - interval '30 days'
ORDER BY enrolled_at DESC;
```

- `EXPLAIN` shows the planner’s estimated plan without running it.
- `ANALYZE` executes it and reports actual rows/times. **It runs the query**—do not point it at dangerous writes casually.
- `BUFFERS` shows cached/read buffer activity; it helps distinguish CPU/cache/I/O patterns.

Read each node’s **estimated rows** versus **actual rows**, its loops, filter removals, and time. A sequential scan is not automatically bad—on a small table or when many rows match, it is often optimal. Add/change an index only after identifying the predicate/join/order, table size/selectivity, and actual plan.

If estimates are wrong, run `ANALYZE` or investigate stale statistics, data skew, correlated columns, or an incorrect query/type cast. Never change random server settings as a first response.

## 6. Query performance principles

1. Return only needed columns/rows; push selective filters early when semantics permit.
2. Use an indexable predicate: avoid applying a function to an indexed column unless an expression index supports it.
3. Match parameter types to column types; implicit casts can prevent a desired index path.
4. Join on keys and aggregate at the correct grain. Fix accidental multiplication rather than adding `DISTINCT` blindly.
5. Avoid N+1 application queries; use a well-designed join/batch query when it fits.
6. Keep statistics current; autovacuum normally does this, but monitor it.
7. Test with production-like data distribution and concurrency, not 12 uniform rows.

## 7. Vacuum, analyze, bloat, and connection hygiene

MVCC creates dead row versions. **Autovacuum** removes reclaimable versions and runs analyze to keep statistics current. Do not disable it globally. Long-running transactions can prevent cleanup and create table bloat; find and fix those transactions.

`VACUUM` usually reclaims space for reuse; `VACUUM FULL` rewrites/locks a table and should be an exceptional planned operation. `ANALYZE` samples data for the planner. Monitor table growth, dead tuples, slow queries, replication lag, failed backups, connection count, and lock waits.

PostgreSQL uses a process per connection; applications commonly use a connection pool. Set sensible pool sizes, close/reuse connections correctly, and protect the database from connection storms. More connections do not automatically create more throughput.

## 8. Roles, privileges, and row-level security

Roles can own objects, log in, inherit memberships, and receive privileges. Start with least privilege.

```sql
CREATE ROLE app_owner NOLOGIN;
CREATE ROLE app_runtime LOGIN PASSWORD 'stored-in-secret-manager';

GRANT USAGE ON SCHEMA academy TO app_runtime;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA academy TO app_runtime;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA academy TO app_runtime;

ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA academy
GRANT SELECT, INSERT, UPDATE ON TABLES TO app_runtime;
```

Do not make runtime apps superusers or owners. Object ownership is powerful. Revoke unnecessary `CREATE` permission on shared schemas and set a safe `search_path` for applications/definer functions.

**Row-level security (RLS)** filters rows by policy for non-owner roles:

```sql
ALTER TABLE sales.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY orders_tenant_policy ON sales.orders
USING (tenant_id = current_setting('app.tenant_id', true)::bigint)
WITH CHECK (tenant_id = current_setting('app.tenant_id', true)::bigint);
```

RLS is powerful and easy to misunderstand. The table owner and roles with `BYPASSRLS` can bypass it unless force rules apply. Test each role and each command; set tenant context safely transaction-locally; do not treat RLS as a substitute for application authorization design.

## 9. Backup, restore, and migrations

Backups are only real when restore has been tested. Common tools:

```bash
# Custom-format logical backup (portable across environments/releases as supported).
pg_dump -Fc -d academy_db -f academy_db.dump

# Inspect then restore a custom backup into a new database.
pg_restore --list academy_db.dump
createdb academy_restore_test
pg_restore -d academy_restore_test academy_db.dump
```

Use `pg_dumpall` for cluster-wide globals/roles, and physical backup/PITR tooling for production recovery objectives. Define RPO (acceptable data loss) and RTO (acceptable recovery time), encrypt/protect backups, retain them appropriately, and rehearse restores.

Schema changes belong in ordered, reviewed migration files. A mature migration has: forward change, tested rollback/compensation strategy where possible, lock/runtime awareness, data backfill plan, deployment order, and observability. Never edit a migration already applied in shared environments; create a new migration.

## 10. Production readiness checklist

- [ ] Roles follow least privilege; secrets are not in source control.
- [ ] Constraints enforce core rules; migrations are reviewed and tested.
- [ ] Important queries have measured plans at realistic data volumes.
- [ ] Connection pool limits and timeouts are configured.
- [ ] Slow queries, errors, locks, vacuum health, disk, replication, and backups are monitored.
- [ ] Backups and restore/PITR procedures are tested regularly.
- [ ] Major-version upgrades have a rehearsed plan.
- [ ] Every client uses parameterized SQL and explicit transactions for multi-step writes.

## Operations lab

1. Put an order and its items in a transaction; deliberately violate a check and prove the whole transaction rolls back.
2. In two `psql` sessions, create a lock wait and observe it; then end both transactions cleanly.
3. Generate enough practice data to compare `EXPLAIN (ANALYZE, BUFFERS)` before and after one justified composite index.
4. Create a no-login owner role and restricted runtime role in a disposable database; verify denied operations.
5. Back up a practice database, restore it to a separate database, and run a row-count/checksum verification query.
