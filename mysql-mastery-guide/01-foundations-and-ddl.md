# 01 — Tables, data types, constraints, and DDL

**DDL** (Data Definition Language) defines structure: `CREATE`, `ALTER`, `DROP`, `TRUNCATE`. DDL changes the schema, so review it as carefully as application code.

## 1. Design before typing `CREATE TABLE`

Start from rules, not columns. For a product catalogue: every product has a stable identity; SKU is unique; price is never negative; product can be inactive; creation time is recorded. Translate each rule into a column, type, and constraint.

```sql
USE mysql_mastery_lab;

CREATE TABLE products (
  product_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  sku        VARCHAR(40) NOT NULL,
  name       VARCHAR(150) NOT NULL,
  price      DECIMAL(10,2) NOT NULL,
  active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (product_id),
  CONSTRAINT uq_products_sku UNIQUE (sku),
  CONSTRAINT chk_products_price CHECK (price >= 0)
) ENGINE = InnoDB;
```

Read the definition from top to bottom:

- `BIGINT UNSIGNED` holds a large, non-negative integer. Use the smallest type that safely covers the domain; `INT UNSIGNED` is often enough.
- `NOT NULL` means the column must have a value. It is not the same as empty text (`''`) or zero (`0`).
- `AUTO_INCREMENT` asks MySQL to generate an ID when you omit it. IDs may have gaps; an ID is identity, not a count or sequence with business meaning.
- `VARCHAR(150)` stores variable-length text up to 150 characters. The number is a domain rule, not a performance magic number.
- `DECIMAL(10,2)` stores exact base-10 numeric values: up to 10 digits total, 2 after the decimal. Use it for money.
- `DEFAULT` supplies a value only when an insert omits the column. Explicit `NULL` does not mean “use default.”
- `PRIMARY KEY` is unique and non-null. A table has one primary key, though it can have multiple columns.
- `UNIQUE` prevents duplicate non-`NULL` SKU values. Understand how nullable unique columns behave before relying on them.
- `CHECK` rejects rows that violate a predicate. It is a rule, not a friendly UI message.
- `InnoDB` is MySQL’s standard transactional engine; it supports foreign keys and row locking.

Inspect what MySQL actually created:

```sql
DESCRIBE products;
SHOW CREATE TABLE products;
SHOW INDEX FROM products;
```

`DESCRIBE` is a compact overview. `SHOW CREATE TABLE` is authoritative: it reveals columns, constraints, engine, options, and MySQL’s normalized definition.

## 2. Common data types: choose by meaning

| Need | Usually choose | Avoid / reason |
|---|---|---|
| Whole count | `TINYINT`, `INT`, `BIGINT` (+ `UNSIGNED` if never negative) | using text for numbers |
| Money, exact measurement | `DECIMAL(p,s)` | `FLOAT`/`DOUBLE` because binary approximations can surprise |
| Approximate scientific value | `DOUBLE` | comparing floating values with `=` |
| Short variable text | `VARCHAR(n)` | arbitrary giant limits |
| Long article/notes | `TEXT` | assuming it is automatically searchable |
| Fixed code | `CHAR(n)` only when truly fixed | using it for normal names |
| True/false | `BOOLEAN` (`TINYINT(1)` synonym) | allowing unknown states accidentally |
| Date only | `DATE` | storing dates as strings |
| Time only | `TIME` | mixing it with duration without thought |
| Moment without timezone conversion | `DATETIME` | forgetting timezone policy |
| Audit timestamp | `TIMESTAMP` | relying on server default timezone unknowingly |
| JSON document | `JSON` | using it to avoid relational design |
| Binary file | usually object storage + URL/metadata | putting large files in ordinary rows without a reason |

`NULL` means “unknown/not applicable/not yet known”; it does not mean empty or zero. Three-valued logic follows: `NULL = NULL` is not true—it is unknown. Test with `IS NULL` or `IS NOT NULL`.

## 3. Identifiers, naming, and comments

Use consistent, readable `snake_case` names: singular or plural is your team’s choice; inconsistency is the problem. Avoid spaces, reserved words, and names whose meaning changes. A good foreign key is `customer_id`, not `id2`.

Use backticks only when an identifier requires quoting. Use **single quotes** for string/date literals:

```sql
SELECT 'Ada' AS correct_text;      -- string
SELECT `name` FROM products;       -- identifier, only if needed
```

## 4. Altering safely

Schema evolution should be backward-compatible when applications are live. A safe sequence is often: add nullable column → deploy code that writes it → backfill in batches → add `NOT NULL`/constraint when data is clean.

```sql
ALTER TABLE products
  ADD COLUMN description TEXT NULL AFTER name;

ALTER TABLE products
  MODIFY COLUMN name VARCHAR(200) NOT NULL;

ALTER TABLE products
  RENAME COLUMN active TO is_active;

ALTER TABLE products
  DROP COLUMN description;
```

`ADD`, `MODIFY`, `RENAME COLUMN`, and `DROP` change definition. The final line permanently removes the data in that column. On big tables, schema changes can take time and can lock or rebuild data depending on MySQL version/operation. Test a copy and plan the deployment.

## 5. `DROP`, `TRUNCATE`, and `DELETE` are different

| Statement | Removes | Can use `WHERE`? | Typical use |
|---|---|---:|---|
| `DELETE FROM t` | selected rows | yes | business/data cleanup; transactional in InnoDB |
| `TRUNCATE TABLE t` | all rows | no | fast reset of a scratch table |
| `DROP TABLE t` | table definition and rows | no | remove an obsolete table |
| `DROP DATABASE d` | the entire schema | no | remove a disposable database |

Before destructive DDL, inspect the active database and object name, back up what matters, and obtain peer review.

## 6. Table template

```sql
CREATE TABLE example_entity (
  example_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  business_code VARCHAR(50) NOT NULL,
  status ENUM('draft', 'active', 'archived') NOT NULL DEFAULT 'draft',
  note TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                       ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (example_id),
  UNIQUE KEY uq_example_entity_business_code (business_code),
  CONSTRAINT chk_example_status CHECK (status IN ('draft', 'active', 'archived'))
) ENGINE=InnoDB;
```

`ENUM` can express a small, stable state set, but it makes changing values a schema change. A lookup table is often more flexible. `ON UPDATE CURRENT_TIMESTAMP` changes `updated_at` whenever the row is changed; do not confuse it with a business event date.

## 7. DDL practice

Create `categories` with an auto-generated ID, unique nonempty name, optional parent category (self-reference comes later), and timestamps. Then use `SHOW CREATE TABLE`; explain every line MySQL returns.

