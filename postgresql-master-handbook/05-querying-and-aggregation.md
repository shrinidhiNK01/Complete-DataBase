# 05 — Querying, functions, filtering, and aggregation

This chapter turns stored facts into answers. The examples use the `academy` companion schema, but the thinking applies to every relational database.

## 1. Filter rows with `WHERE`

```sql
SELECT student_id, full_name, email
FROM academy.student
WHERE active = true
  AND joined_at >= DATE '2026-01-01';
```

`WHERE` keeps rows whose condition is true. Rows where it is false **or unknown (`NULL`)** are excluded. Parenthesize conditions when meaning could be unclear.

### Comparison and logical operators

| Category | Operators | Example |
|---|---|---|
| Comparison | `=`, `<>`/`!=`, `<`, `<=`, `>`, `>=` | `list_price >= 1000` |
| Logical | `AND`, `OR`, `NOT` | `active AND list_price > 0` |
| Null test | `IS NULL`, `IS NOT NULL` | `score IS NULL` |
| Set membership | `IN (...)`, `NOT IN (...)` | `status IN ('draft','submitted')` |
| Range | `BETWEEN a AND b` | `score BETWEEN 40 AND 100` |
| Pattern | `LIKE`, `ILIKE`, `SIMILAR TO` | `email ILIKE '%@example.com'` |

### Three-valued logic and the `NOT IN` trap

```sql
SELECT 1 WHERE 1 NOT IN (2, NULL); -- returns no row: result is unknown
```

If the right-side list/subquery may contain `NULL`, `NOT IN` can unexpectedly return nothing. Prefer `NOT EXISTS` for anti-joins:

```sql
SELECT s.student_id, s.full_name
FROM academy.student AS s
WHERE NOT EXISTS (
  SELECT 1
  FROM academy.enrollment AS e
  WHERE e.student_id = s.student_id
);
```

## 2. Sort deterministically with `ORDER BY`

```sql
SELECT course_code, title, list_price
FROM academy.course
ORDER BY list_price DESC NULLS LAST, course_code ASC;
```

No `ORDER BY` means no guaranteed order—ever. Add a tie-breaker such as a primary key when pagination must be stable. PostgreSQL defaults to `NULLS FIRST` with descending order and `NULLS LAST` with ascending order; state your desired placement explicitly when it matters.

## 3. Remove duplicate result values with `DISTINCT`

```sql
SELECT DISTINCT date_trunc('month', enrolled_at) AS enrollment_month
FROM academy.enrollment
ORDER BY enrollment_month;
```

`DISTINCT` compares the *selected expressions*, not whole base rows. It can conceal a bad join that multiplies rows; understand why duplicates exist before removing them. PostgreSQL’s `DISTINCT ON` selects one row per group, but requires careful ordering:

```sql
-- Latest enrollment for each student (PostgreSQL-specific).
SELECT DISTINCT ON (student_id) student_id, course_id, enrolled_at
FROM academy.enrollment
ORDER BY student_id, enrolled_at DESC, course_id;
```

A window-function solution is often more portable and expressive; see chapter 07.

## 4. Pattern matching and text search basics

```sql
SELECT full_name, email
FROM academy.student
WHERE full_name ILIKE 'an%'       -- case-insensitive: starts with an
   OR email ILIKE '%@example.com'; -- any characters before domain
```

In `LIKE`, `%` means any sequence and `_` means exactly one character. Escape a literal wildcard using `ESCAPE` if necessary. Prefix patterns can potentially use suitable indexes; leading wildcard patterns (`'%term'`) generally cannot use a normal B-tree index efficiently. For serious language search, use PostgreSQL full-text search (chapter 07) or trigram indexing.

## 5. Limit results and paginate correctly

```sql
SELECT course_id, course_code, title
FROM academy.course
WHERE active
ORDER BY course_id
LIMIT 20 OFFSET 40;
```

`LIMIT` caps output. `OFFSET` skips rows but grows slower for deep pages and can skip/duplicate rows if inserts occur between requests. For scalable, stable “next page” navigation, use **keyset pagination**:

```sql
-- Page after the last seen (created_at, course_id).
SELECT course_id, title, created_at
FROM academy.course
WHERE (created_at, course_id) > (TIMESTAMPTZ '2026-08-01 10:00+00', 42)
ORDER BY created_at, course_id
LIMIT 20;
```

The ordering columns need a unique tie-breaker and an index matching the filter/order pattern.

## 6. String functions

```sql
SELECT
  concat(given_name, ' ', family_name) AS display_name,
  concat_ws(' / ', course_code, title, NULL) AS label,
  substr(title FROM 1 FOR 12) AS short_title,
  replace(course_code, '-', '_') AS normalized_code,
  reverse('Postgres') AS reversed,
  upper(course_code) AS upper_code,
  lower(email) AS normalized_email,
  char_length(title) AS characters,
  left(course_code, 2) AS prefix,
  right(course_code, 3) AS suffix,
  btrim('  tidy  ') AS trimmed
FROM academy.course;
```

- `concat` turns NULL arguments into empty text; `||` returns NULL if either side is NULL.
- `concat_ws(separator, ...)` skips NULL values and inserts the separator only between present values.
- `substr`/`substring` positions start at 1.
- `char_length` counts characters; byte length can differ for Unicode.
- `trim`, `btrim`, `ltrim`, `rtrim` remove specified/default whitespace.

Do not “clean” important raw source data invisibly in a `SELECT`. Decide whether normalization belongs at input time, in a generated/normalized column, or as an explicit reporting expression.

## 7. Date, time, and interval functions

```sql
SELECT
  current_date,
  current_time,
  now(),
  clock_timestamp(),
  date_trunc('month', now()) AS month_start,
  to_char(now(), 'YYYY-MM-DD HH24:MI TZ') AS formatted,
  now() + interval '7 days' AS one_week_later,
  age(current_date, DATE '2000-02-29') AS approximate_age;
```

`now()` is fixed at the start of the current transaction; `clock_timestamp()` changes while a statement/function runs. Prefer real timestamp comparisons over formatted strings. `to_char` is for display, not storage or logic.

### Date math with half-open ranges

Avoid `BETWEEN` for timestamp periods where the end must be exclusive. A safe “events in August” predicate is:

```sql
WHERE placed_at >= TIMESTAMPTZ '2026-08-01 00:00:00+00'
  AND placed_at <  TIMESTAMPTZ '2026-09-01 00:00:00+00'
```

This works even if timestamp precision changes and lets adjacent periods meet without overlap. Convert a user’s local calendar boundaries to proper instants before querying.

## 8. `CASE`: derive categories

```sql
SELECT
  full_name,
  CASE
    WHEN active = false THEN 'inactive'
    WHEN joined_at >= now() - interval '30 days' THEN 'new'
    ELSE 'established'
  END AS learner_segment
FROM academy.student;
```

`CASE` returns the first matching branch. Keep all result branches type-compatible. It is excellent for labels, conditional aggregates, and simple transformations—not a replacement for properly modeled workflow state.

## 9. Aggregates: summarize sets of rows

```sql
SELECT
  count(*) AS all_enrollments,
  count(completed_at) AS completed_enrollments,
  count(DISTINCT student_id) AS enrolled_students,
  min(enrolled_at) AS first_enrollment,
  max(enrolled_at) AS latest_enrollment
FROM academy.enrollment;
```

Most aggregates ignore NULL inputs. `count(*)` counts rows; `count(column)` counts only non-null column values. `sum`, `avg`, `min`, and `max` return NULL for no input rows. Use `coalesce(sum(amount), 0)` only when zero is semantically correct for the empty set.

```sql
SELECT
  course_id,
  count(*) AS enrollments,
  avg(final_score) FILTER (WHERE final_score IS NOT NULL) AS average_score,
  count(*) FILTER (WHERE completed_at IS NOT NULL) AS completed
FROM academy.enrollment
GROUP BY course_id;
```

`FILTER (WHERE ...)` is clean PostgreSQL syntax for conditional aggregation.

## 10. GROUP BY, HAVING, and ROLLUP

```sql
SELECT
  course_id,
  count(*) AS enrollment_count
FROM academy.enrollment
GROUP BY course_id
HAVING count(*) >= 5
ORDER BY enrollment_count DESC;
```

`WHERE` filters individual input rows **before** grouping. `HAVING` filters completed groups **after** aggregate values exist. Every selected expression must be aggregated or functionally dependent on/grouped by the group keys.

```sql
SELECT
  date_trunc('month', enrolled_at) AS month,
  course_id,
  count(*) AS enrollments,
  grouping(date_trunc('month', enrolled_at)) AS is_grand_total,
  grouping(course_id) AS is_month_total
FROM academy.enrollment
GROUP BY ROLLUP (date_trunc('month', enrolled_at), course_id)
ORDER BY month NULLS LAST, course_id NULLS LAST;
```

`ROLLUP` produces detailed groups, month subtotals, and a grand total. Rollup-generated nulls can look like real NULL values; `grouping(...)` tells which dimension was rolled up.

## 11. Subqueries and `EXISTS`

```sql
-- Courses whose enrollment count is above the overall average course count.
SELECT c.course_code, c.title
FROM academy.course AS c
WHERE (
  SELECT count(*)
  FROM academy.enrollment AS e
  WHERE e.course_id = c.course_id
) > (
  SELECT avg(enrollment_count)
  FROM (
    SELECT count(*) AS enrollment_count
    FROM academy.enrollment
    GROUP BY course_id
  ) AS counts
);
```

A subquery can return one scalar, a one-column set, or a relation. A **correlated subquery** refers to the outer row (`c.course_id`) and is logically evaluated per outer row; PostgreSQL may optimize it differently. Use `EXISTS` when the question is “does at least one related row exist?” because it communicates intent and does not care which row was found.

## 12. Set operations

```sql
SELECT email FROM academy.student
UNION                         -- removes duplicates
SELECT email FROM academy.instructor;

SELECT email FROM academy.student
UNION ALL                     -- keeps duplicates; usually faster
SELECT email FROM academy.instructor;

SELECT student_id FROM academy.student
EXCEPT
SELECT student_id FROM academy.enrollment;
```

Both queries in a set operation must return the same number of compatible columns. Use `UNION ALL` unless duplicate elimination is a real requirement.

## Query lab

1. List active courses ordered by price high-to-low then code, returning only the first five.
2. Find learners with no enrollment using `NOT EXISTS`.
3. Produce course-level enrollment count, completed count, and average non-null score; keep only courses with two or more enrollments.
4. Use `CASE` to label each score `excellent` (90+), `pass` (40–89.99), `fail` (<40), or `ungraded` (NULL).
5. Write a half-open timestamp query for the previous calendar month in a chosen reporting time zone.
