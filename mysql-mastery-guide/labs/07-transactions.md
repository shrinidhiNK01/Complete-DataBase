# Lab 07 — Transactions and concurrency

Use two Workbench tabs/connections named Session A and Session B. Reset first.

1. In Session A, start a transaction and select inventory product 4 `FOR UPDATE`. Do not commit.
2. In Session B, attempt to update the same inventory row. Observe that it waits. Cancel/commit safely and record what happened.
3. Write a transaction-safe reservation: decrement stock for product 4 only if it is positive. Check `ROW_COUNT()`. Roll back the first attempt and commit the second.
4. Attempt to reserve product 3 (stock 0). Prove no negative stock appears.
5. Add an optimistic concurrency update with `version`; run it once with the current version, then repeat with a stale version.
6. Create a controlled deadlock only if you understand the risk: Session A locks product 4 then 5; Session B locks product 5 then 4. Capture the error, roll back/retry, and explain the consistent-lock-order cure.

**Reflection:** Which rules belong in a `CHECK`, which in a conditional `UPDATE`, and which require the surrounding transaction?

