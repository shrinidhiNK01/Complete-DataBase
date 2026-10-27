# 08 — Transactions, isolation, locks, and concurrency

Databases earn their place when things go wrong or happen simultaneously. A **transaction** groups statements so they succeed together or fail together.

## 1. ACID in plain English

- **Atomicity:** all transaction changes commit, or none do. Do not save a payment without its order update.
- **Consistency:** committed data obeys declared constraints and application invariants.
- **Isolation:** concurrent work should not create impossible/intermediate observations.
- **Durability:** after commit, a crash should not erase the acknowledged change.

InnoDB supports transactions. Confirm you are not assuming autocommit incorrectly:

```sql
SELECT @@autocommit;
```

When autocommit is on (usually `1`), each standalone modifying statement commits immediately unless you explicitly begin a transaction.

## 2. A safe stock reservation

```sql
START TRANSACTION;

SELECT product_id, stock_quantity
FROM inventory
WHERE product_id = 42
FOR UPDATE;

UPDATE inventory
SET stock_quantity = stock_quantity - 1
WHERE product_id = 42
  AND stock_quantity >= 1;

SELECT ROW_COUNT() AS rows_reserved;

-- If rows_reserved = 1, create the order item; otherwise report out of stock.
COMMIT;
```

`START TRANSACTION` begins a unit of work. `FOR UPDATE` obtains a write lock on selected existing rows so another transaction cannot change them until this one commits/rolls back. The guarded update is still essential: it encodes “never below zero” in the statement itself. Keep a transaction short; do not wait for user input, network calls, or long reports while holding locks.

If any required step fails:

```sql
ROLLBACK;
```

The rollback reverses uncommitted changes from this transaction. It cannot undo a statement already committed in an earlier transaction or all kinds of DDL.

## 3. Savepoints

```sql
START TRANSACTION;
INSERT INTO orders (customer_id, status) VALUES (1, 'pending');
SAVEPOINT after_order;

-- Attempt optional work.
INSERT INTO order_notes (order_id, note) VALUES (LAST_INSERT_ID(), 'Gift wrap');

-- If only the optional step fails:
ROLLBACK TO SAVEPOINT after_order;
COMMIT;
```

A savepoint is a partial rollback marker within a transaction. It is not a substitute for error handling and clearly defined business behaviour.

## 4. Isolation levels and anomalies

MySQL/InnoDB commonly defaults to `REPEATABLE READ`. The exact behaviour depends on locking vs consistent reads, indexes, and statements. Know the concepts:

| Anomaly | Meaning | Typical control |
|---|---|---|
| Dirty read | read someone else’s uncommitted change | `READ COMMITTED` or stronger |
| Non-repeatable read | same row read twice yields a different committed value | repeatable read / locking read |
| Phantom | repeated predicate finds newly inserted matching rows | next-key/range locks or serializable approach |
| Lost update | two writers overwrite each other’s intent | guarded update, locks, version check |

```sql
SELECT @@transaction_isolation;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
-- statements
COMMIT;
```

Do not change isolation globally because you read a blog post. Demonstrate the anomaly with two sessions, measure impact, and understand application expectations.

## 5. Locks, blocking, and deadlocks

Row locks protect changes, but a transaction may wait if another owns a conflicting lock. A **deadlock** happens when transaction A holds what B needs while B holds what A needs. InnoDB detects a deadlock, rolls one transaction back, and returns an error.

Deadlock recovery is normal engineering: retry the entire transaction a small number of times after detecting a deadlock. Make transactions short and acquire shared resources in a consistent order (for example, always lock lower product IDs first). Never retry an unknown partially committed business process blindly—design idempotency keys.

Useful diagnostic commands (privileges required):

```sql
SHOW ENGINE INNODB STATUS;
SHOW PROCESSLIST;
```

For production diagnosis use Performance Schema / sys schema where available; avoid killing sessions without identifying business impact.

## 6. Optimistic concurrency with a version

For less-contended edits, store a version number and change only if it still matches what the user read:

```sql
UPDATE customer_profiles
SET preferred_name = 'Ada', version = version + 1
WHERE customer_id = 7
  AND version = 12;
```

If `ROW_COUNT()` is zero, the profile changed or does not exist; reload and ask the user/application to reconcile. This prevents silent “last writer wins.”

## 7. Transaction checklist

Define the invariant, begin just before database work, use constraints and conditional updates, check affected-row counts, commit only when all required work is done, roll back on failure, and test with two simultaneous sessions. The database transaction protects database changes—not email, payment gateways, queues, or external APIs. For cross-system reliability, learn patterns such as an outbox and idempotency keys.

