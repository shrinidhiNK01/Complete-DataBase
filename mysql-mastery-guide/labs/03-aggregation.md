# Lab 03 — Aggregation and reporting

For revenue questions in this lab, include only `paid` and `shipped` orders.

1. Return total revenue, number of revenue orders, number of distinct paying customers, average order value, smallest, and largest order value. Do not trust a nonexistent `orders.total` column: calculate line totals.
2. Return one row per revenue order with its calculated total. State why `GROUP BY o.order_id` has that grain.
3. Return one row per customer with revenue order count and total spend. Include customers with zero revenue orders.
4. Find customers whose total spend is at least 100. Use `HAVING`, not a filter on an alias in `WHERE`.
5. Return one row per category with quantity sold and revenue. Include categories that have zero sales if you can.
6. Return monthly revenue, in chronological order. Do not sort a human-formatted month label.
7. Use conditional aggregation to return paid-order count and cancelled-order count in one query.

**Stretch:** Add `WITH ROLLUP` to a status-by-month summary and label the grand total clearly.

