# PostgreSQL quick reference

## Everyday SQL

```sql
-- Create / inspect
CREATE SCHEMA app;
CREATE TABLE app.item (
  item_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL,
  price numeric(12,2) NOT NULL CHECK (price >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);
\d app.item

-- Insert/read/change/remove
INSERT INTO app.item (name, price) VALUES ('Notebook', 199.00) RETURNING item_id;
SELECT item_id, name, price FROM app.item WHERE price >= 100 ORDER BY price DESC;
UPDATE app.item SET price = 249.00 WHERE item_id = 1 RETURNING *;
DELETE FROM app.item WHERE item_id = 1 RETURNING *;

-- Transaction
BEGIN;
-- statements
COMMIT; -- or ROLLBACK;
```

## Clause order and logical order

```sql
SELECT [DISTINCT] expressions
FROM source
JOIN source ON match
WHERE row_condition
GROUP BY group_columns
HAVING group_condition
ORDER BY result_expression
LIMIT n OFFSET n;
```

Logical order: `FROM/JOIN → WHERE → GROUP BY → aggregate → HAVING → SELECT → DISTINCT → ORDER BY → LIMIT`.

## Null rules

```sql
col IS NULL        -- correct
col IS NOT NULL    -- correct
col = NULL         -- never true
coalesce(col, 0)   -- use fallback only when 0 means the right thing
nullif(value, '')  -- turn special sentinel into NULL
```

## Join patterns

```sql
-- matched rows only
FROM parent p JOIN child c ON c.parent_id = p.parent_id

-- every parent, even with no child
FROM parent p LEFT JOIN child c ON c.parent_id = p.parent_id

-- parents without children
WHERE NOT EXISTS (SELECT 1 FROM child c WHERE c.parent_id = p.parent_id)
```

## Aggregation / window

```sql
SELECT key, count(*), avg(value)
FROM t GROUP BY key HAVING count(*) >= 2;

SELECT *, row_number() OVER (PARTITION BY key ORDER BY occurred_at DESC, id DESC)
FROM t;
```

## psql

| Command | Meaning |
|---|---|
| `\l`, `\c db`, `\dn`, `\dt`, `\d schema.table` | navigate/inspect |
| `\du`, `\df`, `\x on`, `\timing on` | roles/functions/output/timing |
| `\i file.sql`, `\e`, `\q` | run file/edit/quit |
| `\h SELECT`, `\?` | SQL/psql help |

## Fast troubleshooting

| Symptom | First checks |
|---|---|
| “relation does not exist” | correct database/schema, identifier case, `search_path`, migration applied |
| “column does not exist” | table alias, spelling, actual table version, quoted identifier case |
| unique/FK/check error | read constraint name; fix input/business rule, not the constraint |
| transaction aborted | `ROLLBACK;`, fix original error, retry transaction |
| unexpected join duplicates | state expected grain; inspect cardinalities; aggregate before joining |
| query slow | `EXPLAIN (ANALYZE, BUFFERS)`, row estimates, filter/order, index evidence |
| rows blocked | inspect transactions/locks; keep transaction short; avoid killing blindly |
