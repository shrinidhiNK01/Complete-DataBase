# 02 — CRUD: create, read, update, delete

CRUD names the four daily data operations: **Create** rows (`INSERT`), **Read** rows (`SELECT`), **Update** existing rows (`UPDATE`), and **Delete** rows (`DELETE`). SQL is declarative: state the result/rule you want; MySQL chooses much of the execution method.

## 1. Insert data deliberately

```sql
INSERT INTO products (sku, name, price)
VALUES
  ('BK-001', 'Database Design', 29.99),
  ('BK-002', 'SQL Patterns',    34.50),
  ('KB-001', 'Mechanical Keyboard', 89.00);

SELECT LAST_INSERT_ID();
```

Always name the target columns. It protects you when column order changes and documents your intent. A single `INSERT` can add several rows. `LAST_INSERT_ID()` is connection-specific and usually reports the first generated value from the most recent auto-increment insert.

Other useful forms:

```sql
INSERT INTO products (sku, name, price, is_active)
VALUES ('BK-003', 'SQL Workbook', 19.99, FALSE);

INSERT INTO products (sku, name, price)
SELECT supplier_sku, supplier_name, supplier_price
FROM staging_products
WHERE supplier_price >= 0;
```

The second form copies query results into a table. Confirm source data and constraints first.

## 2. Read only what you need

```sql
SELECT product_id, sku, name, price
FROM products;

SELECT *
FROM products;
```

The first query is preferred in applications and reports: it is clear, stable, uses less bandwidth, and avoids exposing columns accidentally. `*` is fine for exploration, not a long-term API contract.

### Aliases and calculated columns

```sql
SELECT
  sku,
  name AS product_name,
  price,
  ROUND(price * 1.18, 2) AS price_including_tax
FROM products;
```

`AS` names an output column; it does not rename the underlying column. The expression is calculated for each output row. `ROUND(..., 2)` makes the displayed tax example readable; real tax rules may require more careful rounding policy.

## 3. Filter with `WHERE`

```sql
SELECT product_id, name, price
FROM products
WHERE price >= 30
  AND is_active = TRUE;
```

`WHERE` keeps only rows whose condition is true. Use parentheses when mixing `AND`/`OR`; relying on precedence is a source of subtle bugs.

```sql
-- Exact and range filtering
WHERE sku = 'BK-001'
WHERE price BETWEEN 20 AND 50              -- inclusive at both ends
WHERE created_at >= '2026-01-01'
  AND created_at <  '2026-02-01'           -- safe for DATETIME values

-- Membership and missing values
WHERE sku IN ('BK-001', 'BK-002')
WHERE is_active IS NULL                    -- not = NULL
WHERE name LIKE 'SQL%'                     -- % = any-length, _ = one character
WHERE name NOT LIKE '%used%'
```

For a `DATETIME`, do not write `created_at = '2026-01-01'` if you mean the whole day: it only matches midnight. The half-open range (`>= start`, `< next start`) is precise and index-friendly.

## 4. Sort, deduplicate, and limit

```sql
SELECT DISTINCT is_active
FROM products;

SELECT product_id, name, price
FROM products
ORDER BY price DESC, name ASC
LIMIT 10 OFFSET 0;
```

`DISTINCT` removes duplicate *result rows*, considering all selected columns. It does not repair duplicate source data. `ORDER BY` is required for a meaningful `LIMIT`; without an order, “first 10” has no guaranteed business meaning. For later pages, prefer keyset pagination (`WHERE (price, product_id) < (?, ?)`) over large offsets for large data.

## 5. Update safely

```sql
-- First inspect the exact target.
SELECT product_id, sku, price
FROM products
WHERE sku = 'BK-001';

UPDATE products
SET price = 31.99,
    updated_at = CURRENT_TIMESTAMP
WHERE sku = 'BK-001';
```

An `UPDATE` has three parts: target table, assignments in `SET`, and an optional filter. Without `WHERE`, it changes every row. MySQL Workbench may enable Safe Updates, which rejects many broad updates; that guard is useful but not a substitute for thought.

Assignments are based on the old row values unless you refer to earlier assignments in the same statement; avoid clever dependency and keep updates obvious.

```sql
UPDATE products
SET price = ROUND(price * 1.10, 2)
WHERE is_active = TRUE
  AND price < 30;
```

Run its `SELECT` equivalent first. In a critical change, wrap it in a transaction and check `ROW_COUNT()`.

## 6. Delete safely

```sql
SELECT * FROM products WHERE is_active = FALSE;

DELETE FROM products
WHERE is_active = FALSE;
```

Deletion removes rows; it is not normally the right way to hide a product that must remain in historical orders. Prefer a status (`is_active`, `archived_at`) when business history matters. Foreign key rules may block deletion or cascade it—learn those rules before deleting parent rows.

## 7. Common traps

- `NULL` is not equal to anything, even another `NULL`. Use `IS NULL`.
- Strings require single quotes: `WHERE sku = 'BK-001'`.
- `BETWEEN` includes both endpoints.
- `LIKE '%text%'` normally cannot use a normal prefix index effectively; it is also not full-text search.
- An update that matches zero rows is not necessarily an error; inspect the filter.
- A unique constraint error is valuable: it prevented a bad duplicate. Do not disable it to “fix” imports.

## 8. CRUD mini-lab

1. Add five products with explicit column lists.
2. Display active products from most expensive to least expensive.
3. Find products whose names contain `SQL` case-insensitively under your collation.
4. Raise only book prices by 5%, after previewing the affected rows.
5. Archive (do not delete) a product and prove that it no longer appears in the active catalogue query.

