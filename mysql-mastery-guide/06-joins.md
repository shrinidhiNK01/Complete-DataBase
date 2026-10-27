# 06 — Joins: combining related tables correctly

A join combines rows from two sources. The database does not “know” your business meaning from similar-looking columns; you must provide the relationship condition and then verify the result grain.

## 1. The join habit that prevents most bugs

1. State the output grain: “one row per order item,” for example.
2. Identify the relationship: `orders.customer_id` references `customers.customer_id`.
3. Start with primary keys and a small filter; inspect rows.
4. Add one table at a time. Compare expected vs actual row count.
5. Aggregate only after the join’s cardinality is correct.

## 2. Inner join

```sql
SELECT
  o.order_id,
  o.created_at,
  c.customer_id,
  c.email,
  o.status
FROM orders AS o
JOIN customers AS c
  ON c.customer_id = o.customer_id;
```

An **inner join** returns only pairs that match the `ON` condition. `o` and `c` are aliases; qualify columns (`o.status`) whenever multiple tables are involved. This avoids ambiguity and makes code review safer.

`JOIN ... USING (customer_id)` is a shorter option when both sides use the same column name. It returns one shared join column; use `ON` when explicitness or different names help.

## 3. Left join: keep all rows on the left

```sql
SELECT
  c.customer_id,
  c.email,
  o.order_id
FROM customers AS c
LEFT JOIN orders AS o
  ON o.customer_id = c.customer_id;
```

Every customer appears. A customer with no orders has `NULL` for the `orders` columns. This makes left joins ideal for “include zero activity” reporting.

### The `WHERE` trap

This accidentally becomes an inner join because NULL child rows fail the `WHERE` condition:

```sql
-- Wrong if you need customers with zero paid orders too.
SELECT c.customer_id, o.order_id
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.customer_id
WHERE o.status = 'paid';
```

Place the child filter in `ON` to retain unmatched parents:

```sql
SELECT c.customer_id, c.email, o.order_id
FROM customers AS c
LEFT JOIN orders AS o
  ON o.customer_id = c.customer_id
 AND o.status = 'paid';
```

To find parents with no children, test the nullable child PK:

```sql
SELECT c.customer_id, c.email
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;
```

## 4. Multi-table joins: order details

```sql
SELECT
  o.order_id,
  c.email,
  p.sku,
  p.name,
  oi.quantity,
  oi.unit_price,
  oi.quantity * oi.unit_price AS line_total
FROM orders AS o
JOIN customers AS c ON c.customer_id = o.customer_id
JOIN order_items AS oi ON oi.order_id = o.order_id
JOIN products AS p ON p.product_id = oi.product_id
WHERE o.status IN ('paid', 'shipped')
ORDER BY o.order_id, oi.order_item_id;
```

Output grain is one **order item**. If one order has three lines, it appears three times; that is correct. To get one row per order, aggregate line totals or query the orders table separately.

```sql
SELECT
  o.order_id,
  SUM(oi.quantity * oi.unit_price) AS computed_total
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
GROUP BY o.order_id;
```

## 5. Cross joins and self joins

`CROSS JOIN` makes every left row pair with every right row (a Cartesian product). It is useful for intentional combinations such as every date × every store, but it grows as `left_count × right_count`. Never omit a join condition by accident.

```sql
SELECT d.calendar_date, s.store_id
FROM calendar_days AS d
CROSS JOIN stores AS s;
```

A self join uses the same table twice:

```sql
SELECT
  e.employee_name,
  m.employee_name AS manager_name
FROM employees AS e
LEFT JOIN employees AS m ON m.employee_id = e.manager_id;
```

## 6. Right joins and full outer joins

`RIGHT JOIN` preserves the right table; reverse table order and use `LEFT JOIN` in most teams for consistent reading. MySQL does not provide a native `FULL OUTER JOIN`; when truly needed, combine a left join with unmatched rows from the reversed direction via `UNION ALL`, carefully avoiding duplicate matches. Often a report requirement can be expressed more simply using a base/calendar table plus left joins.

## 7. Join debugging checklist

- Are the joined columns really keys? Joining `name` rather than `id` can duplicate/mis-match rows.
- Is your output grain correct after each join?
- Did an optional relationship need `LEFT JOIN`?
- Are child-side filters in `ON` when unmatched parents must remain?
- Did a many-to-many table multiply counts? Aggregate before or after at the correct grain.
- Does `EXPLAIN` show indexes for large joins? See Module 10.

