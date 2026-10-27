# 12 — Mastery checklist, interview prompts, and next steps

## 1. Core fluency checklist

You are ready to call yourself practically proficient when you can do every item from a blank editor and explain *why*.

- Create a schema with `utf8mb4`, InnoDB tables, primary keys, foreign keys, `NOT NULL`, `UNIQUE`, `CHECK`, defaults, and useful indexes.
- Explain the difference between `NULL`, `''`, and `0`; filter NULL correctly.
- Insert many rows with explicit columns; select specific columns; use safe updates/deletes.
- Correctly combine `WHERE`, `ORDER BY`, `LIMIT`, `DISTINCT`, `CASE`, `LIKE`, dates, and functions.
- Explain `COUNT(*)` vs `COUNT(column)` and `WHERE` vs `HAVING`.
- Write one-to-many and many-to-many joins without accidental row multiplication.
- Use a CTE, correlated/uncorrelated subquery, `EXISTS`, conditional aggregation, and windows where appropriate.
- Model an order system including immutable purchase-time facts.
- Use transactions, interpret `ROW_COUNT()`, explain isolation, and recover from a deadlock with retry.
- Read a plan, propose/test an index, explain composite-index order and sargability.
- Set least-privilege grants, plan a backup/restore test, and explain why a replica is not a backup.

## 2. High-value interview questions (answer aloud)

1. What is the difference between a DBMS, RDBMS, SQL, and MySQL?
2. Why is a primary key different from a unique key? When would you use a surrogate key plus a natural unique key?
3. Explain one-to-many and many-to-many using an e-commerce example.
4. When should `ON DELETE CASCADE` be used—and when is it dangerous?
5. Compare `WHERE` and `HAVING`; give a query that needs both.
6. What happens if a `LEFT JOIN` child filter is put in `WHERE`?
7. Why can joins inflate a sum? How do you diagnose it?
8. Why is `NOT IN (subquery)` dangerous when NULL is possible?
9. Explain `DATETIME` vs `TIMESTAMP`, and describe your timezone policy.
10. What makes a predicate non-sargable? Rewrite `DATE(created_at) = ...`.
11. How does a composite index `(a, b, c)` help? What is the leftmost-prefix principle?
12. What does `EXPLAIN ANALYZE` add beyond `EXPLAIN`?
13. Give a transaction-safe approach to prevent inventory from becoming negative.
14. What is a deadlock, and what should an application do?
15. Why is a replica not a backup? What is a restore test?

## 3. Capstone: build a marketplace database

Build it in four iterations. Do not copy a prebuilt answer before you attempt each design.

**Iteration A — model:** customers, addresses, categories, products, inventory, carts/orders, order items, payments, shipments, coupons. Draw an ER diagram and write table grain + keys + deletion rules. Decide which facts are historical snapshots (shipping address, unit price, tax, product title).

**Iteration B — transactional workflows:** create order → reserve stock → insert lines → compute/validate totals → create payment intent. Make failure paths explicit. Test concurrent attempts to buy the final unit.

**Iteration C — reports:** daily revenue, best sellers, customers without a purchase in 90 days, repeat purchase cohorts, category ranking per month, running customer spend, inventory reorder report. Use CTEs/windows intentionally.

**Iteration D — production:** profile two slow reports, add/test indexes, restrict application accounts, write backup and restore runbooks, add audit/monitoring decisions, and explain a replication/failover plan.

## 4. Deliberate-practice routine

For 45–60 minutes per session: 10 minutes recall (write syntax from memory), 20 minutes lab problem, 15 minutes debug a deliberately broken query, 10 minutes explain the result as if teaching. Revisit old labs after a week without notes. Mastery is reliable reasoning, not memorizing commands.

## 5. What to learn next

After these notes, deepen: MySQL Shell and dump utilities; Performance Schema/sys schema; binary logging, GTIDs and replication; online schema migration; partitioning; query/application observability; connection pooling; encryption/key management; data warehousing; and how MySQL differs from PostgreSQL/SQL Server. Read the exact release manual for the server you operate—syntax and operational capabilities change.

