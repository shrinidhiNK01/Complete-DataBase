# Lab 04 — Join reasoning

For each answer, first write the intended output grain in a SQL comment.

1. Return one row per order item containing order ID, order time, customer email, SKU, current product name, quantity, purchase-time unit price, and line total.
2. Return one row per order including customer email and calculated order total. Explain why the first query cannot simply be used without aggregation.
3. Return every customer and the number of revenue orders, including `new@example.com` even though this customer has none.
4. Find customers with no orders of any status using a `LEFT JOIN`/NULL test; then write the equivalent using `NOT EXISTS`.
5. Demonstrate the `LEFT JOIN`/`WHERE` trap: write an incorrect query that loses no-order customers, then fix it by moving the status condition to `ON`.
6. Return products never purchased in a revenue order. Be deliberate about cancelled/pending line items.
7. Add a query that intentionally uses `CROSS JOIN` to create every category × status combination, then left join a summary so zero counts appear.

**Stretch:** Explain how a missing `ON` condition changes the row count for customers × orders.

