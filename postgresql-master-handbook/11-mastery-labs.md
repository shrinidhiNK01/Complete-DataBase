# 11 — Mastery labs: deliberate practice from basics to production

Do these labs in a separate practice database using [lab-schema.sql](lab-schema.sql). Attempt every task before opening [solutions.md](solutions.md). For every write statement: show the preview query, use a transaction when appropriate, and record what evidence proves success.

## Lab 1 — Database navigation and inspection

**Aim:** Become fluent with objects before changing them.

1. Create `academy_db` and execute the seed script.
2. Use `\l`, `\dn`, `\dt academy.*`, and `\d academy.enrollment`.
3. Query `information_schema.columns` to list each `academy` table, column, type, nullable flag, and default.
4. Identify every primary, unique, check, and foreign-key constraint from `pg_constraint` or `\d` output.
5. Explain why there can be several indexes but only one primary key per table.

**Mastery check:** You can differentiate database, schema, table, constraint, index, and role without using them interchangeably.

## Lab 2 — Safe CRUD journal

**Aim:** Treat changing data as a controlled operation.

1. Insert a sixth learner using an explicit column list and `RETURNING`.
2. Attempt an insert with a duplicate email and explain the error’s protecting constraint.
3. Preview all active learners joined after 1 April 2026, then update only them to a known testing value in a new optional column. Roll it back.
4. Delete the learner only inside a transaction, inspect `RETURNING`, then roll it back.
5. Compare `DELETE`, `TRUNCATE`, and `DROP` in a throwaway table. Verify what survives each command.

**Evidence:** Save the exact `SELECT` predicate you used to preview each `UPDATE`/`DELETE`.

## Lab 3 — Data-quality design

**Aim:** Turn English rules into types and constraints.

Design `academy.certificate`:

- one certificate per completed enrollment;
- serial number unique and nonblank;
- issued timestamp required;
- optional revoked timestamp that cannot precede issue;
- issuer name required.

Write `CREATE TABLE`, then construct at least five invalid inserts, each violating a different declared rule. Explain which rule **cannot** be guaranteed with a simple check (hint: confirm enrollment status in another table) and propose a solution.

## Lab 4 — Query fundamentals sprint

**Aim:** Read every query as a precise English sentence.

1. Return active courses ordered by highest list price, then code; include `NULLS LAST` even if no price is null.
2. Return every distinct month containing an enrollment.
3. Find students with case-insensitive name containing `a` and a non-null birth date.
4. Return courses whose title has exactly three characters in a chosen position using `_` and `LIKE` (make your own test rows if needed).
5. Paginate courses first with `LIMIT/OFFSET`, then convert it to keyset pagination using `(created_at, course_id)`.

## Lab 5 — Aggregation and reporting

**Aim:** Select the correct grain before writing SQL.

1. Produce one row per course: total enrollments, completed enrollments, cancelled enrollments, distinct learners, min/max enrollment time, average final score.
2. Keep courses with at least two enrollments using `HAVING`, not `WHERE`.
3. Generate monthly enrollment totals, a grand total, and explain rollup nulls using `grouping()`.
4. Find courses whose enrollment count exceeds the average enrollment count for enrolled courses.
5. Explain the difference among `count(*)`, `count(final_score)`, and `count(DISTINCT student_id)` using actual output.

## Lab 6 — Relationships and joins

**Aim:** Make joins predictable rather than trial-and-error.

1. Draw the ERD for the academy schema and label cardinalities.
2. Return every course with enrollment count including zero-enrollment courses.
3. Return every student with their latest enrollment; retain students with no enrollment.
4. Find students never enrolled using `NOT EXISTS`; then demonstrate why a careless `NOT IN` fails after adding a null to a test subquery.
5. Write a query that accidentally multiplies rows; explain exactly which relationship caused it and fix it by aggregating at the right grain.

## Lab 7 — Strings, dates, CASE, and JSON

**Aim:** Transform data while preserving meaning.

1. Produce an instructor display label with `concat_ws`, normalized email with `lower`, and character count of name.
2. Derive learner age band from birth date, leaving unknown birth dates explicitly labelled `unknown`.
3. Write half-open range predicates for “enrollments in March 2026” and “previous seven 24-hour periods.” Explain why they are different.
4. Add a `jsonb` metadata table for import events. Enforce object-shaped payloads, write queries for `source`, and add a GIN index after inspecting the plan/use case.
5. Format dates only in final output with `to_char`; keep comparisons as dates/timestamps.

## Lab 8 — Windows and CTEs

**Aim:** Preserve detail while performing analytical calculations.

1. Rank learners by final score within each course using `rank`, `dense_rank`, and `row_number`; explain ties.
2. Return two most recent enrollments per learner using a CTE and `row_number` with deterministic tiebreaker.
3. Create daily enrollment counts and a running total by course.
4. Use `lag` to calculate time since previous enrollment for each learner.
5. Create a view exposing course-level completion rate. Decide how a course with zero enrollment should appear.

## Lab 9 — Transactions and concurrency

**Aim:** Make a multi-step change atomic under competing work.

1. In a new schema, build a two-account transfer table with non-negative balance checks.
2. Transfer funds in one transaction. Force a failure halfway and prove neither account changed.
3. Open two `psql` sessions. Cause one to wait on a row lock, inspect the blocking query, then cleanly release it.
4. Reproduce a simple deadlock with two rows only in a disposable table. Explain why PostgreSQL aborts one transaction and why retry is correct.
5. Design an optimistic update using a `version` column and `WHERE id = $1 AND version = $2`.

## Lab 10 — Index and plan investigation

**Aim:** Use evidence rather than index superstition.

1. Insert at least 100,000 synthetic rows into a disposable event table with a timestamp and tenant ID. Use `generate_series`.
2. Run a selective tenant/time-range query with `EXPLAIN (ANALYZE, BUFFERS)`.
3. Add one composite B-tree index matching filter/order; rerun the plan and compare estimated vs actual rows, buffers, and elapsed time.
4. Run a low-selectivity query and explain why a sequential scan may remain correct.
5. Add a partial index for active rows; prove which query uses it and why another does not.

## Lab 11 — Routines, triggers, and security

**Aim:** Use server-side code only where it earns its complexity.

1. Create an immutable `grade_label` function and test every boundary/NULL case.
2. Create a set-returning function for a course roster. Compare plan/results to the direct query.
3. Add an `updated_at` trigger to a disposable table and test inserts, no-op updates, and multi-row updates.
4. Create a login runtime role limited to one schema. Prove denied `DROP` and allowed `SELECT` using separate connections.
5. Explain the security risks of dynamic SQL and `SECURITY DEFINER` in your own words.

## Lab 12 — Capstone production simulation

**Aim:** Demonstrate end-to-end competence.

1. Build the e-store schema from chapter 10 using migrations, not copy/paste in a GUI only.
2. Seed at least 50 customers, 100 products, 300 orders, and realistic multi-item orders.
3. Implement an idempotent payment callback using a unique provider reference.
4. Implement stock reservation that cannot go negative under concurrent checkout.
5. Build three reporting queries: monthly revenue, top products, and inactive customers.
6. Add only evidence-backed indexes; attach before/after plans.
7. Make a backup, restore it to a different database, verify row counts and constraints, then document recovery steps.

## Final self-assessment rubric

| Level | You can do this |
|---|---|
| Beginner | Create tables and write basic CRUD with a known schema. |
| Intermediate | Design keys/constraints, join correctly, aggregate, and use transactions safely. |
| Advanced | Write windows/CTEs, model history, analyze plans, and resolve most query bugs. |
| Production-ready | Reason about isolation, permissions, migrations, backups/restores, monitoring, and failure modes. |
| Mastery | Defend tradeoffs with evidence, teach the model clearly, and improve systems without sacrificing correctness. |

For each lab, keep a small learning log: requirement, initial hypothesis, SQL, result/error, corrected reasoning, and what constraint/test would prevent the same mistake. This turns errors into reusable skill.
