# Lab 08 — Plans, security, backup, and recovery thinking

1. Run `EXPLAIN` for recent orders of one customer. Identify selected key, rows estimate, and whether an index is plausible.
2. Compare plans for `DATE(created_at) = '2026-08-02'` versus the equivalent half-open date range. Explain why data size matters even if your tiny lab gives similar plans.
3. Create a deliberately useful composite index for a documented query, capture before/after plans, then remove it only in this lab schema.
4. Demonstrate why an index on `(customer_id, created_at)` does not generally serve a query filtering only on `created_at` as well as an index beginning with `created_at`.
5. Write a least-privilege grant plan for a reporting user that can read only `v_paid_order_summary`, not base customer PII. (Do not run account creation on a shared server without permission.)
6. Write a backup runbook: schedule, target, encryption/access, retention, RPO, RTO, restore command, and validation checks.
7. Given “an administrator ran `DELETE FROM order_items` at 10:17”, write an incident response sequence. Include why you restore to an isolated database first.

**Stretch:** Explain why a read replica is not a defence against a destructive statement that was committed on the primary.

