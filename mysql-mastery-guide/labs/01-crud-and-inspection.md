# Lab 01 — Inspection and CRUD

1. Verify the active database, list tables, and display `SHOW CREATE TABLE orders`.
2. Show only active products. Return SKU, name, and price; sort expensive first, then name.
3. Find all products whose name contains `SQL`. Do not use `SELECT *`.
4. Insert a new active book with a unique SKU. Show the generated ID and prove the row exists.
5. Preview, then increase that one new book’s price by 10%. Show the old/new values in your worksheet or transaction notes.
6. Mark the new book inactive instead of deleting it. Write a catalogue query that proves it is hidden.
7. Try inserting a duplicate SKU. Explain the exact rule that stops it. Roll back/reset rather than removing a constraint.
8. Try an update without `WHERE` only in a transaction, roll it back, and explain why a preview query is safer than trusting Safe Updates.

**Stretch:** Write one `INSERT ... SELECT` that adds a test product based on an existing product, but with a new SKU and a 15% discount.

