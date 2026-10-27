# MySQL: Beginner to Mastery

This is a practical, step-by-step MySQL learning path. It is written in plain English, but it does not avoid the ideas that make a database reliable in real life. Run every code block yourself. Change values, deliberately cause errors, read them, and fix them.

**Target:** MySQL Server 8.4+ using the InnoDB storage engine. Most examples also work on MySQL 8.0. Check the [official manual](https://dev.mysql.com/doc/) whenever a feature is version-sensitive.

## How to use this guide

1. Read one module, execute its examples in a scratch database, and write a one-paragraph explanation in your own words.
2. Do the matching lab without opening its solution. A query that works is not necessarily a good query: also explain why its result is correct.
3. Keep a `mistakes.sql` file. Every useful database error belongs there, together with its cause and repair.
4. Build the capstone only after finishing the labs. It combines modelling, SQL, transactions, indexes, security, and reporting.

## Learning map

| Stage | Read | You will be able to do |
|---|---|---|
| Foundations | 00–03 | install MySQL, define schemas, create safe tables |
| Everyday querying | 04–06 | insert, filter, sort, group, join, and change data |
| Professional SQL | 07–09 | use windows, JSON, transactions, views, and routines |
| Production thinking | 10–11 | optimize, secure, back up, diagnose, and scale |
| Mastery | `labs/` | solve realistic problems from a blank editor |

## File guide

- [00-roadmap.md](00-roadmap.md) — mental model, workflow, installation and Workbench.
- [01-foundations-and-ddl.md](01-foundations-and-ddl.md) — databases, tables, types, constraints, DDL.
- [02-crud-and-basic-queries.md](02-crud-and-basic-queries.md) — `INSERT`, `SELECT`, `UPDATE`, `DELETE`.
- [03-expressions-functions-and-filtering.md](03-expressions-functions-and-filtering.md) — text, numbers, dates, conditions.
- [04-aggregation-subqueries-and-sets.md](04-aggregation-subqueries-and-sets.md) — grouping, `HAVING`, subqueries, CTEs.
- [05-data-modelling-and-relationships.md](05-data-modelling-and-relationships.md) — normalisation, keys, relationship design.
- [06-joins.md](06-joins.md) — joins with an order-management data set.
- [07-advanced-sql.md](07-advanced-sql.md) — windows, JSON, full-text, spatial, generated columns.
- [08-transactions-and-concurrency.md](08-transactions-and-concurrency.md) — ACID, locks, isolation, deadlocks.
- [09-programmability.md](09-programmability.md) — views, procedures, functions, triggers, events.
- [10-indexes-explain-and-performance.md](10-indexes-explain-and-performance.md) — indexing and evidence-led tuning.
- [11-security-backup-and-operations.md](11-security-backup-and-operations.md) — accounts, privileges, backup, restore, observability.
- [12-interview-and-mastery-checklist.md](12-interview-and-mastery-checklist.md) — revision and self-assessment.
- [13-architecture-and-scaling.md](13-architecture-and-scaling.md) — InnoDB internals, partitioning, and scaling choices.
- [14-import-export-migrations-and-apps.md](14-import-export-migrations-and-apps.md) — loading data, safe integrations, and migrations.
- [labs/README.md](labs/README.md) — executable progressive labs, solutions, and capstone.

> **Safety rule:** Never execute `UPDATE` or `DELETE` against important data until you have first run the same `WHERE` clause as a `SELECT`, know the row count, and have a tested backup/transaction plan.
