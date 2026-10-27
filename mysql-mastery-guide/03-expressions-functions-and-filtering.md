# 03 — Expressions, functions, conditions, and dates

SQL expressions transform values. A function consumes values and returns a value. Use functions to express business logic close to the data—but avoid wrapping indexed columns in functions inside filters when a range condition can do the job.

## 1. Text functions

```sql
SELECT
  CONCAT(first_name, ' ', last_name) AS full_name,
  CONCAT_WS(' / ', city, state, country) AS location,
  SUBSTRING(sku, 1, 2) AS sku_prefix,
  LEFT(sku, 2), RIGHT(sku, 3),
  UPPER(email), LOWER(email),
  CHAR_LENGTH(name) AS characters,
  TRIM('  clean me  ') AS clean_text,
  REPLACE(name, 'Book', 'Guide') AS renamed,
  REVERSE(sku) AS backwards
FROM customers;
```

- `CONCAT` returns `NULL` if any argument is `NULL`; `CONCAT_WS(separator, ...)` skips `NULL` values (but not empty strings).
- `SUBSTRING(text, start, length)` starts at 1. `LEFT` and `RIGHT` are concise for prefixes/suffixes.
- `CHAR_LENGTH` counts characters; `LENGTH` counts bytes, which differs for Unicode.
- `TRIM` removes leading/trailing spaces. Do not use formatting functions to hide dirty source data permanently—clean or validate it at write time.

## 2. Numbers and `CASE`

```sql
SELECT
  price,
  ROUND(price * 0.18, 2) AS tax,
  ABS(-7) AS absolute_value,
  CEIL(12.1) AS round_up,
  FLOOR(12.9) AS round_down,
  CASE
    WHEN price >= 100 THEN 'premium'
    WHEN price >= 30 THEN 'standard'
    ELSE 'budget'
  END AS price_band
FROM products;
```

`CASE` is SQL’s conditional expression. It returns the first matching result. Order overlapping rules from most specific/highest threshold to lowest. `CASE` can be used in `SELECT`, `ORDER BY`, aggregations, and updates.

```sql
SELECT
  SUM(CASE WHEN o.status = 'paid' THEN oi.quantity * oi.unit_price ELSE 0 END) AS paid_revenue,
  SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_line_count
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id;
```

This is conditional aggregation: it produces several metrics in one grouped query.

## 3. Boolean and relational operators

`=`, `<>`/`!=`, `<`, `<=`, `>`, `>=` compare values. `AND`, `OR`, and `NOT` combine conditions. A condition involving `NULL` may yield **unknown**, and `WHERE` keeps only true.

```sql
WHERE (country = 'IN' OR country = 'SG')
  AND is_active = TRUE
  AND deleted_at IS NULL;
```

`IN` is concise equality membership. Be careful with `NOT IN (subquery)` if the subquery can return `NULL`: unknown values can make every comparison fail. `NOT EXISTS` is usually safer for anti-joins.

## 4. Dates, timezones, and date maths

```sql
SELECT
  CURDATE() AS today,
  CURTIME() AS current_time,
  NOW() AS current_datetime,
  DATE_ADD(CURDATE(), INTERVAL 14 DAY) AS two_weeks_from_now,
  DATE_SUB(CURDATE(), INTERVAL 1 MONTH) AS one_month_ago,
  DATEDIFF('2026-12-31', '2026-01-01') AS day_difference,
  TIMESTAMPDIFF(HOUR, '2026-01-01 09:00:00', '2026-01-02 12:30:00') AS whole_hours;
```

`DATE` has no time; `DATETIME` is a calendar date-time literal; `TIMESTAMP` is stored/converted relative to session timezone. Establish one policy early—commonly store event instants in UTC, convert at application/report boundaries, and keep the user’s timezone as data. Check it:

```sql
SELECT @@session.time_zone, @@global.time_zone, UTC_TIMESTAMP();
```

Format only at presentation time:

```sql
SELECT DATE_FORMAT(created_at, '%Y-%m-%d %H:%i') AS display_time
FROM orders;
```

`DATE_FORMAT` returns text, so avoid sorting/filtering on its result. Filter raw dates using a range:

```sql
WHERE created_at >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
  AND created_at <  DATE_ADD(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH);
```

For maximum index friendliness, calculate date boundaries in the application or a variable once rather than applying a function to `created_at`.

## 5. `COALESCE`, `NULLIF`, and null-safe comparisons

```sql
SELECT
  COALESCE(nickname, first_name, 'Anonymous') AS display_name,
  NULLIF(discount_code, '') AS null_when_blank,
  (a <=> b) AS null_safe_equal
FROM customer_profiles;
```

`COALESCE` returns the first non-NULL input. `NULLIF(a,b)` returns `NULL` when values match—useful for turning blank import strings into missing values. `<=>` is MySQL’s null-safe equality operator: it regards two `NULL`s as equal.

## 6. The logical-thinking template

For every condition, make a small truth table in your head. Example: “active users who signed in in the last 30 days, excluding internal emails.” Then write grouped conditions deliberately:

```sql
WHERE is_active = TRUE
  AND last_login_at >= CURRENT_TIMESTAMP - INTERVAL 30 DAY
  AND email NOT LIKE '%@company.example'
```

Ask: what happens if `last_login_at` is NULL? It is excluded, because the comparison is unknown. If that is not desired, say so with `OR last_login_at IS NULL`.
