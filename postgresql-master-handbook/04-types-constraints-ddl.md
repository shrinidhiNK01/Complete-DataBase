# 04 — Types, constraints, and schema evolution

Your schema is executable business policy. Types state what a value *is*; constraints state what values are *valid*. Putting these rules in the database makes every client—web app, import job, admin tool, and future service—follow them.

## 1. Choose types by meaning, not storage guesswork

| Requirement | Prefer | Why / warning |
|---|---|---|
| Generated row identifier | `bigint GENERATED ... AS IDENTITY` | Simple, efficient surrogate key. IDs are not guaranteed gapless. |
| Short/long human text | `text` | PostgreSQL treats `text` and unlimited `varchar` similarly. Add a check if a real length rule exists. |
| Fixed upper bound text | `varchar(n)` | Enforces maximum length; not a performance shortcut. |
| Whole number | `smallint`, `integer`, `bigint` | Choose by legitimate range, not today’s sample values. |
| Exact money/rate | `numeric(p,s)` | Exact decimal; avoid binary float for currency. |
| Scientific approximate value | `double precision` | Fast approximate floating point. |
| True/false | `boolean` | Store `true`, `false`, or `NULL` only when unknown is meaningful. |
| Calendar day | `date` | No time zone/moment included. |
| Clock time | `time` / `time with time zone` | Prefer only for a recurring wall-clock fact. |
| Real-world instant | `timestamptz` | Stores an instant; displays in session time zone. |
| Flexible document | `jsonb` | Queryable/indexable JSON; do not use it to evade modeling. |
| List/collection native to PostgreSQL | `type[]` | Useful for bounded homogeneous data; not a default replacement for relation tables. |
| Controlled small domain | `CHECK` or `CREATE TYPE ... AS ENUM` | Check is easier to evolve; enum is useful for stable values. |

### `numeric` versus `double precision`

```sql
SELECT 0.1::numeric + 0.2::numeric AS exact_decimal,
       0.1::double precision + 0.2::double precision AS approximate_binary;
```

Use `numeric(12,2)` for an amount that must equal a decimal currency value. Use `double precision` for a measurement/model where tiny rounding differences are acceptable. Money is a business domain, not merely “a number”; often store amount as `numeric` plus a three-letter currency code.

### Timestamp intuition

```sql
SET TIME ZONE 'Asia/Kolkata';
SELECT now(), current_date, current_time;
```

`now()` returns a `timestamptz`: a single moment displayed in your session’s time zone. If a customer purchased at that instant, all users should agree on the moment even though they see different local clock times. Store it as `timestamptz`. A birthday is not an instant; use `date`. A shop’s daily opening time is usually `time` plus the shop’s named time zone in business rules.

## 2. Constraints, one by one

```sql
CREATE TABLE academy.assignment (
  assignment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  course_id     bigint NOT NULL REFERENCES academy.course(course_id),
  title         text NOT NULL CHECK (btrim(title) <> ''),
  max_score     numeric(6,2) NOT NULL CHECK (max_score > 0),
  due_at        timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT assignment_title_per_course_unique UNIQUE (course_id, title)
);
```

| Constraint | Promise it enforces |
|---|---|
| `NOT NULL` | A value must exist. |
| `DEFAULT expr` | Use a value when insert omits the column—not when it explicitly sends `NULL`. |
| `PRIMARY KEY` | Unique, non-null row identity; one per table (possibly composite). |
| `UNIQUE` | No duplicate values/combinations. PostgreSQL normally allows multiple NULLs because NULL is unknown. |
| `CHECK (condition)` | Each non-null row value must make the expression true; `NULL` passes, so add `NOT NULL` when required. |
| `FOREIGN KEY` | Referenced parent row must exist (or child key may be null if allowed). |
| `EXCLUDE` | PostgreSQL-specific: disallow overlapping/conflicting ranges/geometries. |

**Important:** PostgreSQL assumes a `CHECK` expression is immutable for the same row values. Do not write a check that depends on `now()`, another table, or mutable external state. Use a trigger, transaction logic, or redesigned model for cross-row/cross-table rules.

## 3. Keys: natural, surrogate, and composite

A **candidate key** can uniquely identify a row. A **primary key** is the candidate key chosen as the table’s official identity. A **natural key** comes from the domain, such as a verified ISO code. A **surrogate key** is generated without business meaning, such as an identity `bigint`.

```sql
CREATE TABLE academy.enrollment (
  student_id bigint NOT NULL REFERENCES academy.student(student_id),
  course_id  bigint NOT NULL REFERENCES academy.course(course_id),
  enrolled_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (student_id, course_id)
);
```

This join table uses a composite primary key: the pair must not repeat. You can add a surrogate `enrollment_id` when another table must reference one enrollment or it has an independent lifecycle, but still retain `UNIQUE (student_id, course_id)` if the pair must be unique.

Identity values can have gaps: a rolled-back transaction may consume one, sequences can be cached, and values are not timestamps. A gap is normal; never use `MAX(id) + 1` to generate identifiers.

## 4. Schema namespaces and names

```sql
CREATE SCHEMA IF NOT EXISTS sales;
CREATE TABLE sales.invoice (...);
```

Use lowercase `snake_case`, descriptive singular/plural table names consistently, and semantic names such as `placed_at`, `unit_price`, `billing_address`. Avoid spaces, keywords, and opaque abbreviations. Never use quoted camel case unless an integration forces it: `"OrderItems"` must be quoted exactly forever.

## 5. ALTER TABLE: evolve intentionally

Schema changes are migrations: reviewed, versioned, tested changes that move every environment forward.

```sql
-- Add an optional column: usually quick.
ALTER TABLE academy.course ADD COLUMN description text;

-- Add a column with a default for new inserts.
ALTER TABLE academy.course ADD COLUMN published boolean NOT NULL DEFAULT false;

-- Add a temporary legacy field before demonstrating a rename.
ALTER TABLE academy.course ADD COLUMN legacy_reference text;

-- Change type only with an explicit conversion rule when needed.
ALTER TABLE academy.course
  ALTER COLUMN list_price TYPE numeric(12,2)
  USING list_price::numeric(12,2);

-- Rename a column only after impact analysis.
ALTER TABLE academy.course RENAME COLUMN legacy_reference TO legacy_code;

-- Drop a column only after a compatibility period and backup.
ALTER TABLE academy.course DROP COLUMN legacy_code;
```

The final two lines are examples, not a recommended sequence. A rename can break SQL, ORM mappings, views, functions, reports, and integrations. A drop can destroy facts. In production use a compatibility period: add new column, backfill, read both if needed, switch writers/readers, validate, then remove the old column in a later release.

## 6. Add constraints safely to existing large tables

Existing data may violate a new rule. First inspect it, clean it, then add and validate deliberately.

```sql
-- Find bad data before constraining it.
SELECT course_id, list_price
FROM academy.course
WHERE list_price IS NULL OR list_price < 0;

-- On large production tables, add first without validating old rows.
ALTER TABLE academy.course
  ADD CONSTRAINT course_list_price_nonnegative
  CHECK (list_price >= 0) NOT VALID;

-- New/changed rows are checked; validate existing rows in a planned operation.
ALTER TABLE academy.course
  VALIDATE CONSTRAINT course_list_price_nonnegative;
```

The `NOT VALID` technique reduces disruptive validation work when adding certain constraints, especially foreign keys and checks. It is not a license to leave old invalid data forever.

For `NOT NULL`, a staged technique can reduce surprises: add a check `NOT VALID`, validate it, then set `NOT NULL` after analyzing lock impact for your PostgreSQL version and table size.

## 7. DROP and CASCADE: understand dependency graphs

```sql
DROP TABLE academy.course;
-- Or, only after reviewing dependencies:
DROP TABLE academy.course CASCADE;
```

Plain `DROP` fails if other objects depend on the table. That failure is a safety feature. `CASCADE` tells PostgreSQL to delete dependent objects too—perhaps views, foreign keys, or functions. It is convenient in a disposable training schema and dangerous in a shared database. Inspect dependencies and have a backup/migration plan before using it.

## 8. Normalization: prevent anomalies

Normalization organizes facts so one fact is stored once. It prevents:

- **Update anomaly:** a customer address copied on 100 order rows diverges after one edit.
- **Insert anomaly:** you cannot record a product until someone orders it.
- **Delete anomaly:** deleting the last order also removes the only product description.

First normal form (1NF) means atomic values—no comma-separated “red, blue, green” field. Second normal form (2NF) means a non-key attribute depends on the whole key, not part of a composite key. Third normal form (3NF) means non-key attributes depend on the key, not another non-key attribute.

Example: `order_items(order_id, product_id, product_name, quantity)` repeats `product_name`, which belongs to `product`. Store `product_id` on the item and join when current product data is wanted. Preserve historical purchase facts such as `unit_price` and sometimes `product_name_at_purchase` on the order item if history must remain true even after a product changes.

Normalize first. Denormalize only after measuring a real query/performance need and documenting how redundant data stays correct.

## Practice

1. Design `academy.submission` with a composite unique constraint so one student submits at most once per assignment.
2. Add a `score` that is either null (not graded) or between zero and the assignment’s max score. Explain why a plain `CHECK` cannot compare it to a different row in `assignment`.
3. Add a `status` with allowed values `draft`, `submitted`, `graded`; decide whether `CHECK` or enum better fits a system expected to add states yearly.
4. Write a migration plan for splitting `full_name` into `given_name` and `family_name` without breaking applications.
