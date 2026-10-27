# 14 — Import/export, migrations, and application access

Data rarely begins life perfectly in one table. Imports must be repeatable, validated, observable, and safe to rerun.

## 1. Use a staging table for messy imports

Do not load a vendor CSV directly into critical tables when it may contain duplicates, blanks, invalid dates, or changing column meanings. Load raw values into a staging table, profile/clean them, then insert validated records transactionally into the real schema.

```sql
CREATE TABLE staging_products (
  source_sku VARCHAR(100) NULL,
  source_name VARCHAR(300) NULL,
  source_price VARCHAR(100) NULL
) ENGINE=InnoDB;

-- File permissions and LOCAL capability must be deliberately configured.
LOAD DATA LOCAL INFILE 'C:/safe-import/products.csv'
INTO TABLE staging_products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(source_sku, source_name, source_price);

SELECT source_sku, source_price
FROM staging_products
WHERE source_sku IS NULL OR TRIM(source_sku) = ''
   OR TRIM(source_price) NOT REGEXP '^[0-9]+(\\.[0-9]{1,2})?$';
```

Treat `LOAD DATA` as a security-sensitive server/client file operation. Set safe file paths/capabilities, avoid untrusted files, and understand CSV quoting/newline encoding. For complex parsing, validate in an application/ETL process and retain an import error report.

## 2. Transform and make imports idempotent

An import is **idempotent** when rerunning the same batch produces the intended final state rather than duplicate data. Use a source identifier and a unique key. Then decide whether a repeated source row should be ignored, updated, or reported for human review.

```sql
INSERT INTO products (sku, name, price)
SELECT TRIM(source_sku), TRIM(source_name), CAST(source_price AS DECIMAL(10,2))
FROM staging_products
WHERE TRIM(source_sku) <> ''
  AND TRIM(source_price) REGEXP '^[0-9]+(\\.[0-9]{1,2})?$'
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  price = VALUES(price);
```

`ON DUPLICATE KEY UPDATE` is a MySQL upsert pattern. Do not use it casually: it can overwrite a human correction with stale feed data. Store batch IDs/source timestamps and make conflict policy explicit. In newer MySQL style, prefer a row alias rather than relying on deprecated `VALUES(column)` usage where your target version recommends it.

## 3. Export carefully

For small query results, a client export is convenient. For reproducible operational exports, use a scripted command with least-privilege credentials, stable query/schema selection, secure destination, and logs. CSV escaping, delimiter, character set, line endings, and NULL representation must be agreed with the consumer.

```sql
SELECT customer_id, email, joined_at
FROM customers
INTO OUTFILE '/secure-server-directory/customers.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';
```

`INTO OUTFILE` writes from the server and is restricted by server file settings/privileges; it will not overwrite an existing file. Do not export personal data without a legitimate, authorized purpose and protection plan.

## 4. Application queries: parameterize everything that is data

Never construct SQL by concatenating untrusted input:

```text
Unsafe idea: "SELECT * FROM customers WHERE email = '" + input + "'"
Safe idea:  prepare "SELECT customer_id, email FROM customers WHERE email = ?"
            bind input as a string parameter
            execute
```

Prepared statements keep data separate from SQL syntax and protect against SQL injection. They do not parameterize identifiers (such as a dynamic column name); choose those from a strict application-owned allowlist. Grant the application only the minimal database actions it needs, and use a connection pool sized for real concurrency rather than one new connection per request.

## 5. Migrations: evolve schema as code

Store every schema change in an ordered, reviewed migration file. A migration should have an owner, target version, up/down or recovery plan, data backfill strategy, tested lock/online-DDL behaviour, and verification query.

Safe broad pattern:

```text
1. Add a nullable/backward-compatible column or table.
2. Deploy application code that can read both old and new forms.
3. Backfill existing rows in measured batches.
4. Validate data and monitor application behaviour.
5. Add NOT NULL / constraints when clean.
6. Remove obsolete code/columns only after a deliberate retention window.
```

Do not edit an already-applied migration in shared environments. Add a new corrective migration. For large transformations, throttled batches and resumable jobs are safer than one massive transaction that blocks/overloads the system.

## 6. Integration checklist

- Use a supported connector/driver and keep it patched.
- Set connection charset/timezone intentionally.
- Use transactions for units of related writes.
- Parameterize data; use allowlists for dynamic SQL structure.
- Set timeouts and bound result sizes; paginate deterministic queries.
- Collect query latency/errors safely; redact secrets and sensitive values.
- Version-control migrations, routines, views, permissions, and seed data as appropriate.
