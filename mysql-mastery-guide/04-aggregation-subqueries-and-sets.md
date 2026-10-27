# 04 — Aggregation, grouping, subqueries, CTEs, and set logic

An aggregate query turns many input rows into fewer summary rows. The most important question is its **grain**: “one output row per what?” If you cannot complete that sentence, do not write the query yet.

## 1. Aggregate functions

```sql
WITH paid_order_totals AS (
  SELECT o.order_id, o.customer_id, o.discount_code,
         SUM(oi.quantity * oi.unit_price) AS order_total
  FROM orders AS o
  JOIN order_items AS oi ON oi.order_id = o.order_id
  WHERE o.status = 'paid'
  GROUP BY o.order_id, o.customer_id, o.discount_code
)
SELECT
  COUNT(*) AS paid_orders,
  COUNT(discount_code) AS orders_with_a_code,
  COUNT(DISTINCT customer_id) AS buying_customers,
  SUM(order_total) AS revenue,
  AVG(order_total) AS average_order,
  MIN(order_total) AS smallest_order,
  MAX(order_total) AS largest_order
FROM paid_order_totals;
```

`COUNT(*)` counts rows, including rows where every selectable column may contain `NULL`. `COUNT(column)` counts only non-NULL values. `SUM`, `AVG`, `MIN`, and `MAX` ignore NULL values. `AVG` is not necessarily the value you want: average order value differs from average revenue per customer/day.

## 2. `GROUP BY` and `HAVING`

```sql
SELECT
  o.customer_id,
  COUNT(DISTINCT o.order_id) AS paid_orders,
  SUM(oi.quantity * oi.unit_price) AS lifetime_value
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status = 'paid'
GROUP BY o.customer_id
HAVING SUM(oi.quantity * oi.unit_price) >= 500
ORDER BY lifetime_value DESC;
```

First `WHERE` removes individual rows, then `GROUP BY` puts the remaining rows into one group per `customer_id`, then aggregates calculate values per group, and `HAVING` filters those groups. Put nonaggregate row conditions in `WHERE`; put conditions involving aggregates in `HAVING`.

With `ONLY_FULL_GROUP_BY` enabled (a good default), every selected expression must be grouped, aggregated, or functionally dependent on the group. This prevents arbitrary, misleading values.

### Calendar totals and rollups

```sql
SELECT
  YEAR(o.created_at) AS order_year,
  MONTH(o.created_at) AS order_month,
  SUM(oi.quantity * oi.unit_price) AS revenue
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status = 'paid'
GROUP BY YEAR(o.created_at), MONTH(o.created_at) WITH ROLLUP;
```

`WITH ROLLUP` adds subtotal/grand-total rows containing `NULL` in rolled-up grouping columns. Label them with `GROUPING()` where needed; never mistake them for actual unknown dates.

## 3. Subqueries: a query inside a query

### Scalar subquery

```sql
WITH paid_order_totals AS (
  SELECT o.order_id, SUM(oi.quantity * oi.unit_price) AS order_total
  FROM orders AS o JOIN order_items AS oi ON oi.order_id = o.order_id
  WHERE o.status = 'paid'
  GROUP BY o.order_id
)
SELECT order_id, order_total
FROM paid_order_totals
WHERE order_total > (SELECT AVG(order_total) FROM paid_order_totals);
```

The inner query returns one value. A scalar subquery must return at most one row. If it returns multiple rows, MySQL raises an error; that is a modelling/query clue, not something to hide.

### List subquery and `EXISTS`

```sql
SELECT customer_id, email
FROM customers
WHERE customer_id IN (
  SELECT customer_id
  FROM orders
  WHERE status = 'paid'
);

SELECT c.customer_id, c.email
FROM customers AS c
WHERE EXISTS (
  SELECT 1
  FROM orders AS o
  WHERE o.customer_id = c.customer_id
    AND o.status = 'paid'
);
```

`EXISTS` asks only whether at least one matching row exists. It is often the clearest choice when you do not need columns from the child table. For “customers with no paid order,” use `NOT EXISTS`, not `NOT IN`, unless you are certain the subquery cannot return NULL.

### Correlated subquery

```sql
SELECT p.product_id, p.name, p.price
FROM products AS p
WHERE p.price > (
  SELECT AVG(p2.price)
  FROM products AS p2
  WHERE p2.category_id = p.category_id
);
```

The inner query references the outer row (`p.category_id`), so it is correlated. It expresses “above the average in its own category.” It can be elegant, but inspect performance; a join, CTE, or window function may be clearer/faster at scale.

## 4. CTEs: named, temporary query results

```sql
WITH paid_orders AS (
  SELECT o.order_id, o.customer_id, o.created_at,
         SUM(oi.quantity * oi.unit_price) AS order_total
  FROM orders AS o JOIN order_items AS oi ON oi.order_id = o.order_id
  WHERE o.status = 'paid'
  GROUP BY o.order_id, o.customer_id, o.created_at
), customer_totals AS (
  SELECT customer_id, SUM(order_total) AS total_spent
  FROM paid_orders GROUP BY customer_id
)
SELECT customer_id, total_spent
FROM customer_totals
WHERE total_spent >= 500
ORDER BY total_spent DESC;
```

A **common table expression** exists for one statement. It improves readability by separating stages: filter → summarize → filter summaries. It is not automatically a stored table or a performance guarantee. CTEs can also be recursive for hierarchies.

```sql
WITH RECURSIVE numbers AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM numbers WHERE n < 10
)
SELECT n FROM numbers;
```

The anchor query starts recursion; the recursive member creates the next rows; its stopping condition is essential. Use recursion cautiously and set sensible depth limits for untrusted/application-provided hierarchies.

## 5. `UNION`, `INTERSECT`, and `EXCEPT`

```sql
SELECT email FROM newsletter_subscribers
UNION                         -- removes duplicate output rows
SELECT email FROM customers;

SELECT email FROM newsletter_subscribers
UNION ALL                     -- retains duplicates; usually faster
SELECT email FROM customers;
```

Set operators combine compatible result sets: same number of columns with compatible types. `UNION ALL` is usually the right default when duplicates carry meaning or cannot occur. MySQL 8.0.31+ also supports `INTERSECT` (common rows) and `EXCEPT` (left rows not on right); use `EXISTS`/joins when they better show relationship logic.

## 6. Typical reporting query, built in layers

Question: “For each paid order this month, show the customer and order amount only if the customer’s month-to-date spend exceeds 500.”

```sql
WITH month_orders AS (
  SELECT o.order_id, o.customer_id, o.created_at,
         SUM(oi.quantity * oi.unit_price) AS order_total
  FROM orders AS o JOIN order_items AS oi ON oi.order_id = o.order_id
  WHERE o.status = 'paid'
    AND o.created_at >= '2026-08-01'
    AND o.created_at <  '2026-09-01'
  GROUP BY o.order_id, o.customer_id, o.created_at
), customer_monthly_spend AS (
  SELECT customer_id, SUM(order_total) AS monthly_spend
  FROM month_orders
  GROUP BY customer_id
)
SELECT mo.order_id, mo.customer_id, mo.order_total, cms.monthly_spend
FROM month_orders AS mo
JOIN customer_monthly_spend AS cms USING (customer_id)
WHERE cms.monthly_spend > 500
ORDER BY cms.monthly_spend DESC, mo.created_at DESC;
```

Each CTE has a testable meaning. Run it independently while developing. This is safer than writing a single large query and guessing which clause is wrong.

## 7. Aggregation mistakes to catch

- A join before aggregation can multiply rows. Confirm the row count/grain before `SUM`.
- `WHERE` cannot filter `SUM(...)`; use `HAVING` or an outer query.
- `COUNT(*)` after a `LEFT JOIN` counts the preserved parent row even when no child exists. Count `child.primary_key` if you mean matching children.
- Do not use `DISTINCT` as a bandage for an incorrect join. Find the incorrect cardinality.
- Store money as `DECIMAL`; aggregate it with consistent currency/unit meaning.
