# MySQL mastery labs

## Ground rules

1. Run [00-bootstrap.sql](00-bootstrap.sql) to reset the disposable schema.
2. Create a separate `.sql` file per lab. Put the question as a comment before each answer.
3. Before any data change, write and run the preview `SELECT`.
4. Compare your result to the expected *meaning*, not merely the number of rows. Explain output grain.
5. Attempt the lab first. Use [solutions.md](solutions.md) only to review your reasoning.

The bootstrap schema represents a compact shop. `order_items.unit_price` is purchase-time price; it can differ from current `products.price`. Orders may be `pending`, `paid`, `shipped`, or `cancelled`. Treat `paid` and `shipped` as revenue-recognized for a report only when the question explicitly says so.

## Progression

| Lab | Focus | Success criterion |
|---|---|---|
| 01 | inspection and CRUD | safe reads and controlled changes |
| 02 | filters/functions | correct NULL, date, and text logic |
| 03 | grouping | one summary row per stated grain |
| 04 | joins | no accidental multiplication or lost left rows |
| 05 | subqueries/CTEs/windows | queries are staged and testable |
| 06 | schema design | rules live in constraints/relationships |
| 07 | transactions | two-session stock safety scenario |
| 08 | indexes/operations | measured plan improvement and recovery reasoning |
| Capstone | full system | documented production-ready mini design |

Run a reset before each destructive lab. The point is to make mistakes where they are harmless.

