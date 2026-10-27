# Selected lab solutions and reasoning

Use these to compare reasoning after attempting the labs. Equivalent correct SQL is expected; the important parts are grain, null behaviour, constraints, transaction boundaries, and evidence.

## Lab 1 — Inspect columns and constraints

```sql
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'academy'
ORDER BY table_name, ordinal_position;

SELECT
  conrelid::regclass AS table_name,
  conname AS constraint_name,
  contype AS constraint_type,
  pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE connamespace = 'academy'::regnamespace
ORDER BY table_name::text, constraint_name;
```

`contype` values include `p` primary, `u` unique, `f` foreign key, and `c` check. A table has one primary key because that is its declared official identity; it may have many unique constraints/indexes serving other candidate keys and query paths.

## Lab 4 — Stable keyset page

```sql
-- First page
SELECT course_id, course_code, created_at
FROM academy.course
ORDER BY created_at, course_id
LIMIT 2;

-- Next page: substitute the last row returned by the preceding page.
SELECT course_id, course_code, created_at
FROM academy.course
WHERE (created_at, course_id) > (TIMESTAMPTZ '2026-01-05 02:30:00+00', 2)
ORDER BY created_at, course_id
LIMIT 2;
```

The pair is lexicographically compared: a later timestamp wins, or at equal timestamp a larger ID wins. The tiebreaker prevents loss/duplication among equal timestamps. Add an index on `(created_at, course_id)` only if the actual query plan/workload warrants it.

## Lab 5 — One row per course report

```sql
SELECT
  c.course_id,
  c.course_code,
  count(e.student_id) AS total_enrollments,
  count(*) FILTER (WHERE e.status = 'completed') AS completed_enrollments,
  count(*) FILTER (WHERE e.status = 'cancelled') AS cancelled_enrollments,
  count(DISTINCT e.student_id) AS distinct_learners,
  min(e.enrolled_at) AS first_enrolled_at,
  max(e.enrolled_at) AS latest_enrolled_at,
  avg(e.final_score) AS average_final_score
FROM academy.course AS c
LEFT JOIN academy.enrollment AS e ON e.course_id = c.course_id
GROUP BY c.course_id, c.course_code
HAVING count(e.student_id) >= 2
ORDER BY total_enrollments DESC, c.course_id;
```

The desired grain is one row per course. `count(e.student_id)` is essential: with a left join, `count(*)` would count a placeholder row for a course with no enrollment. `avg` ignores ungraded null scores.

## Lab 6 — Latest enrollment, preserving no-enrollment students

```sql
WITH ranked_enrollment AS (
  SELECT
    e.*,
    row_number() OVER (
      PARTITION BY e.student_id
      ORDER BY e.enrolled_at DESC, e.course_id DESC
    ) AS rn
  FROM academy.enrollment AS e
)
SELECT
  s.student_id,
  s.full_name,
  r.course_id,
  r.enrolled_at
FROM academy.student AS s
LEFT JOIN ranked_enrollment AS r
  ON r.student_id = s.student_id
 AND r.rn = 1
ORDER BY s.student_id;
```

Filtering `r.rn = 1` in the `ON` retains students with no enrollment. Moving it to `WHERE` would remove those null-extended rows and change the left join into an effective inner join.

## Lab 7 — Age band and date intervals

```sql
SELECT full_name,
       CASE
         WHEN birth_date IS NULL THEN 'unknown'
         WHEN birth_date > current_date - interval '25 years' THEN 'under 25'
         WHEN birth_date > current_date - interval '40 years' THEN '25 to 39'
         ELSE '40 or older'
       END AS age_band
FROM academy.student;

-- Calendar month in a known reporting zone, converted to instants.
WHERE enrolled_at >= TIMESTAMPTZ '2026-03-01 00:00:00+05:30'
  AND enrolled_at <  TIMESTAMPTZ '2026-04-01 00:00:00+05:30';

-- Rolling duration, different business meaning.
WHERE enrolled_at >= now() - interval '7 days'
  AND enrolled_at < now();
```

Age rules depend on a definition of “today” and can be a legal/business concern. The example gives basic bands; do not use it for age-restricted compliance logic without an approved policy.

## Lab 8 — Top two scores per course, including ties

```sql
WITH scored AS (
  SELECT
    e.course_id,
    e.student_id,
    e.final_score,
    dense_rank() OVER (
      PARTITION BY e.course_id
      ORDER BY e.final_score DESC NULLS LAST
    ) AS score_position
  FROM academy.enrollment AS e
  WHERE e.final_score IS NOT NULL
)
SELECT *
FROM scored
WHERE score_position <= 2
ORDER BY course_id, score_position, student_id;
```

`dense_rank` returns the two highest *distinct score values*, retaining all tied students. `rank` may create a gap after ties, and `row_number` returns exactly two rows but arbitrarily excludes ties unless a deterministic non-score tiebreaker answers a real business rule.

## Lab 9 — Safe balance transfer

```sql
BEGIN;

-- Lock account rows in a fixed order to reduce deadlock risk.
SELECT account_id, balance
FROM bank.account
WHERE account_id IN (10, 20)
ORDER BY account_id
FOR UPDATE;

UPDATE bank.account
SET balance = balance - 500
WHERE account_id = 10
  AND balance >= 500;
-- Application must verify exactly 1 row changed; otherwise ROLLBACK.

UPDATE bank.account
SET balance = balance + 500
WHERE account_id = 20;

COMMIT;
```

The non-negative check is a last line of defense, but the conditional debit gives a clear insufficiency signal. Both debit and credit must be in one transaction. Retry the full unit of work if PostgreSQL reports a serialization or deadlock error.

## Lab 10 — Synthetic data and plan test

```sql
CREATE TABLE lab.event (
  event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id bigint NOT NULL,
  occurred_at timestamptz NOT NULL,
  payload text NOT NULL
);

INSERT INTO lab.event (tenant_id, occurred_at, payload)
SELECT
  (g % 100) + 1,
  TIMESTAMPTZ '2026-01-01 00:00+00' + g * interval '1 minute',
  repeat('x', 80)
FROM generate_series(1, 100000) AS g;

ANALYZE lab.event;

EXPLAIN (ANALYZE, BUFFERS)
SELECT event_id, occurred_at
FROM lab.event
WHERE tenant_id = 42
  AND occurred_at >= TIMESTAMPTZ '2026-02-01 00:00+00'
ORDER BY occurred_at DESC
LIMIT 50;

CREATE INDEX event_tenant_occurred_idx
ON lab.event (tenant_id, occurred_at DESC);
```

Rerun the same plan after index creation. Do not claim “the index works” only because an index scan appears: compare actual rows, buffer reads/hits, cost/time, write cost, and the selectivity of the real workload.

## Lab 12 — Idempotent payment receipt

```sql
INSERT INTO store.payment (order_id, provider, provider_reference, amount, status)
VALUES ($1, $2, $3, $4, 'captured')
ON CONFLICT (provider, provider_reference)
DO NOTHING
RETURNING payment_id;
```

The unique provider reference prevents two successful retries from creating two payment rows. `DO NOTHING` alone does not prove the existing payment matches the same order/amount/status; fetch and validate the existing event when integrity/security requires that guarantee. Then transition order state in the same transaction under the correct locking/state predicate.
