# Lab 02 — Filtering, functions, dates, and conditions

1. Return customer full names using `CONCAT`, with email in lowercase and a label that uses `COALESCE(city, 'City unknown')`.
2. Find customers where city is unknown. Explain why `city = NULL` is wrong.
3. List orders made in July 2026. Use a half-open `DATETIME` range, not `MONTH(created_at) = 7` alone.
4. For each product, show a price band: `budget` (<30), `standard` (30–79.99), or `premium` (80+). Test the boundaries.
5. Return orders that used one of `WELCOME10` or `SUMMER`, and separately orders without any discount code.
6. Show a formatted order date for display **and** retain the original `created_at` for correct sorting.
7. Explain whether a product name search using `%SQL%` is likely to use a normal prefix index efficiently.

**Stretch:** Write a query that finds customers whose email begins with a letter you choose, case behaviour according to the active collation.

