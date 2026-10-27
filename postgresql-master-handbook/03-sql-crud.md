# 03 — SQL and CRUD: create, read, update, delete

CRUD is the fundamental lifecycle of rows: **Create**, **Read**, **Update**, **Delete**. Before using it, distinguish table definition (DDL) from row changes (DML).

## 1. Create a table

```sql
CREATE TABLE academy.course (
  course_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  course_code text NOT NULL UNIQUE,
  title       text NOT NULL,
  list_price  numeric(10, 2) NOT NULL CHECK (list_price >= 0),
  active      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);
```

The statement says exactly what is allowed: every course has an automatically generated ID, a unique code, a title, a non-negative price, a known active state, and creation timestamp. PostgreSQL creates supporting indexes for a primary key and unique constraint.

Inspect it:

```sql
-- psql
\d academy.course

-- portable inspection query
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'academy' AND table_name = 'course'
ORDER BY ordinal_position;
```

## 2. INSERT: add rows deliberately

Always name target columns in application and training SQL. It protects the statement from column order changes and makes the mapping visible.

```sql
INSERT INTO academy.course (course_code, title, list_price)
VALUES
  ('SQL-101', 'SQL foundations', 2999.00),
  ('PG-201', 'PostgreSQL query patterns', 3999.00);
```

Omitted `active` and `created_at` use their defaults. The identity column is generated. To see generated values, use `RETURNING`:

```sql
INSERT INTO academy.course (course_code, title, list_price)
VALUES ('PG-301', 'PostgreSQL performance', 4999.00)
RETURNING course_id, course_code, created_at;
```

`RETURNING` is PostgreSQL’s clean answer to “what did the database actually insert/update/delete?” It avoids an unsafe “select the last row” pattern.

### Insert from a query

```sql
INSERT INTO academy.course_archive (course_id, course_code, title, list_price, archived_at)
SELECT course_id, course_code, title, list_price, now()
FROM academy.course
WHERE active = false;
```

This copies a result set, not a hard-coded list. The target columns and selected expressions must be compatible in number and type.

## 3. SELECT: read without changing data

```sql
SELECT course_code, title, list_price
FROM academy.course
WHERE active = true
ORDER BY list_price DESC, course_code ASC;
```

Logical reading order is useful for understanding a query:

```text
FROM / JOIN → WHERE → GROUP BY → aggregates → HAVING → SELECT → DISTINCT → ORDER BY → LIMIT/OFFSET
```

This is not necessarily PostgreSQL’s physical execution plan. The planner may rearrange operations while preserving the result.

### Avoid `SELECT *` in durable queries

`SELECT *` is fine for quick exploration. In views, APIs, reports, or application code, list columns. You document the contract, avoid accidentally exposing sensitive data, and prevent a new column from silently changing the result shape.

```sql
SELECT course_id, course_code, title, list_price
FROM academy.course;
```

### Aliases make outputs and joins readable

```sql
SELECT
  c.course_code AS code,
  c.title AS course_title,
  c.list_price * 1.18 AS price_with_tax
FROM academy.course AS c;
```

`AS` is optional for table aliases (`FROM academy.course c`), but explicit aliases help learners. A column alias is usually visible in `ORDER BY`, but not reliably in `WHERE` because `WHERE` logically runs before `SELECT`.

## 4. UPDATE: change targeted rows

```sql
UPDATE academy.course
SET list_price = list_price * 1.10
WHERE course_code = 'SQL-101'
RETURNING course_id, course_code, list_price;
```

Line-by-line: find course rows whose code is `SQL-101`; compute the new price from each row’s old price; return proof of the actual update. Without `WHERE`, **every row** is updated.

Safe workflow for an important update:

```sql
BEGIN;

-- 1. Preview exactly the rows and intended value.
SELECT course_id, course_code, list_price, list_price * 1.10 AS new_price
FROM academy.course
WHERE course_code = 'SQL-101';

-- 2. Make the same predicate part of the update.
UPDATE academy.course
SET list_price = list_price * 1.10
WHERE course_code = 'SQL-101';

-- 3. Verify row count/result; keep if correct.
COMMIT;
-- Or undo every change above: ROLLBACK;
```

Do not use a test `UPDATE` and then immediately “reverse” it as your safety plan. A transaction is clearer and safer.

## 5. DELETE: remove rows, carefully

```sql
DELETE FROM academy.course
WHERE course_code = 'PG-301'
RETURNING course_id, course_code;
```

`DELETE` removes matching rows. It does not remove the table. Without `WHERE`, it deletes all rows. Foreign keys may reject the delete, cascade it to dependent rows, or set a foreign key to null—depending on the declared rule. Study that rule before deleting a parent row.

### DELETE versus TRUNCATE versus DROP

| Command | Removes | Can use `WHERE`? | Transactional in PostgreSQL? | Keeps table definition? |
|---|---|---:|---:|---:|
| `DELETE FROM t` | matching rows | Yes | Yes | Yes |
| `TRUNCATE t` | all rows, fast | No | Yes | Yes |
| `DROP TABLE t` | table, data, constraints, indexes | No | Yes | No |

`TRUNCATE` takes stronger locks and can optionally restart identities: `TRUNCATE academy.course RESTART IDENTITY;`. It is not a casual substitute for `DELETE`; it has different locking and trigger semantics.

## 6. MERGE and upsert

An **upsert** means “insert if new, otherwise update.” PostgreSQL commonly uses `INSERT ... ON CONFLICT`:

```sql
INSERT INTO academy.course (course_code, title, list_price)
VALUES ('SQL-101', 'SQL foundations', 3199.00)
ON CONFLICT (course_code)
DO UPDATE SET
  title = EXCLUDED.title,
  list_price = EXCLUDED.list_price
RETURNING course_id, course_code, list_price;
```

`EXCLUDED` is the proposed row that conflicted. The conflict target must match a unique index/constraint. Do not use upsert merely to hide bad duplicate input: decide which fields a repeat delivery is allowed to overwrite, and prevent stale events from overwriting newer facts.

PostgreSQL also supports standard `MERGE` for more complex matching actions. Use it when its single-statement match semantics make the business rule clearer; test concurrent behavior and remember that a unique constraint is still your final integrity protection.

## 7. Quotes, identifiers, and literals

- Single quotes: string/date values: `'SQL-101'`, `'2026-08-21'`.
- Double quotes: exact identifiers: `"Order"`. Avoid these; unquoted `order_items` is simpler.
- Dollar quotes: function bodies: `$$ ... $$`.
- Parameters: use `$1`, `$2`, etc. in prepared SQL/functions, or your driver’s parameter feature. **Never** build SQL by concatenating user input.

```sql
-- In an application, use a parameter rather than turning input into SQL text.
SELECT course_id, title
FROM academy.course
WHERE course_code = $1;
```

Parameterized queries are a security boundary against SQL injection and also handle quoting/type conversion more reliably.

## 8. CRUD practice

1. Create a `academy.instructor` table with identity key, full name, unique email, hire date, and active default.
2. Insert three instructors, returning their generated IDs.
3. Select active instructors whose names contain `an`, case-insensitively.
4. In a transaction, give one instructor a corrected email, verify it, then roll back.
5. Add a unique conflict test by attempting the same email twice. Read the error; do not remove the constraint.
