# Lab 05 — Subqueries, CTEs, and windows

1. Find products priced above the average price of their own category. Solve once with a correlated subquery and once with a CTE/join.
2. Find customers who have at least one revenue order using `EXISTS`; then find those with no revenue order using `NOT EXISTS`.
3. Use CTEs to calculate each revenue order total, then customer lifetime spend, then return customers over 100. Run each CTE stage independently while developing.
4. Return each revenue order with its purchase number for that customer using `ROW_NUMBER()`.
5. Return each revenue order with running spend per customer using an explicit window frame.
6. For every category, return the two most expensive active products. Use `ROW_NUMBER` or `DENSE_RANK`; explain what ties should do.
7. Build month revenue first, then return previous-month revenue and the difference using `LAG`.

**Stretch:** Build a recursive CTE that generates the integers 1–12 and left joins monthly revenue so months with zero revenue appear.

