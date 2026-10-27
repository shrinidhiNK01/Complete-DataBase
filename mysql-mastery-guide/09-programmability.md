# 09 — Views, stored procedures, functions, triggers, and events

Programmability puts reusable logic near the data. It can centralize permissions or stable reporting logic, but it can also hide complexity and make deployments/testing harder. Keep source-controlled SQL definitions and use it deliberately.

## 1. Views: saved queries, not necessarily saved data

```sql
CREATE OR REPLACE VIEW v_paid_order_summary AS
SELECT
  o.order_id,
  o.created_at,
  c.customer_id,
  c.email,
  SUM(oi.quantity * oi.unit_price) AS calculated_total
FROM orders AS o
JOIN customers AS c ON c.customer_id = o.customer_id
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status = 'paid'
GROUP BY o.order_id, o.created_at, c.customer_id, c.email;

SELECT * FROM v_paid_order_summary WHERE created_at >= '2026-08-01';
```

A view names a `SELECT`. It can simplify repeated queries and expose only approved columns. A regular MySQL view does not automatically store a materialized snapshot; performance still depends on its underlying query. Changes to base tables can make views invalid—test them in migrations.

## 2. Stored procedures

A procedure performs work and may return result sets or output parameters. Change the delimiter in clients that otherwise end statements at `;`.

```sql
DELIMITER //

CREATE PROCEDURE get_customer_orders(IN p_customer_id BIGINT UNSIGNED,
                                     IN p_limit INT UNSIGNED)
BEGIN
  SELECT o.order_id, o.status, o.created_at,
         SUM(oi.quantity * oi.unit_price) AS calculated_total
  FROM orders AS o
  JOIN order_items AS oi ON oi.order_id = o.order_id
  WHERE o.customer_id = p_customer_id
  GROUP BY o.order_id, o.status, o.created_at
  ORDER BY o.created_at DESC, o.order_id DESC
  LIMIT p_limit;
END//

DELIMITER ;

CALL get_customer_orders(1, 20);
DROP PROCEDURE IF EXISTS get_customer_orders;
```

- `DELIMITER //` changes the client’s statement terminator temporarily; it is not SQL executed by the server.
- `IN` is an input parameter. `OUT` returns a value through a caller variable. `INOUT` does both.
- Validate inputs, control transaction boundaries explicitly, and give routines predictable error behaviour.

```sql
DELIMITER //
CREATE PROCEDURE count_customer_orders(IN p_customer_id BIGINT UNSIGNED,
                                       OUT p_order_count INT)
BEGIN
  SELECT COUNT(*) INTO p_order_count
  FROM orders
  WHERE customer_id = p_customer_id;
END//
DELIMITER ;

CALL count_customer_orders(1, @count);
SELECT @count;
```

## 3. User-defined functions

A function returns one value and can be used in an expression. Keep functions deterministic and side-effect-free where possible; a `SELECT` that secretly changes data is difficult to reason about.

```sql
DELIMITER //
CREATE FUNCTION line_total(p_quantity INT, p_unit_price DECIMAL(10,2))
RETURNS DECIMAL(12,2)
DETERMINISTIC
RETURN p_quantity * p_unit_price//
DELIMITER ;

SELECT line_total(3, 19.99);
```

The `DETERMINISTIC` declaration says the same inputs give the same output. Declare characteristics truthfully, especially when binary logging/replication is used. Application code or a generated column is often easier to test for simple business calculations.

## 4. Triggers: automatic reactions to row changes

```sql
CREATE TABLE product_price_audit (
  audit_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT UNSIGNED NOT NULL,
  old_price DECIMAL(10,2) NOT NULL,
  new_price DECIMAL(10,2) NOT NULL,
  changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

DELIMITER //
CREATE TRIGGER trg_products_price_audit
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
  IF NOT (OLD.price <=> NEW.price) THEN
    INSERT INTO product_price_audit (product_id, old_price, new_price)
    VALUES (NEW.product_id, OLD.price, NEW.price);
  END IF;
END//
DELIMITER ;
```

Triggers run automatically for each affected row. `OLD` is the pre-change row (not available in `INSERT`); `NEW` is the new row (not available in `DELETE`). The null-safe comparison detects changes even when a value can be NULL. Triggers are appropriate for narrow, unavoidable invariants/audits; they are risky for hidden cross-table workflows, expensive bulk operations, and surprises. Document them beside the table.

## 5. Scheduled events

MySQL’s Event Scheduler can run SQL on a schedule when enabled by an administrator.

```sql
SET GLOBAL event_scheduler = ON; -- admin decision; persists only as configured

CREATE EVENT ev_archive_old_sessions
ON SCHEDULE EVERY 1 DAY
DO
  DELETE FROM sessions
  WHERE expires_at < CURRENT_TIMESTAMP - INTERVAL 30 DAY;
```

Events need monitoring, error handling strategy, permissions, and a clear deployment owner. An external scheduler may be operationally clearer for application workflows.

## 6. When to choose what

| Need | Prefer |
|---|---|
| Simplify a stable read/report and restrict columns | view |
| A multi-step database operation called by many clients | procedure, or application service if easier to test/deploy |
| Pure scalar calculation used in SQL | function or generated expression |
| Tiny automatic row-level audit/invariant | trigger, sparingly |
| Recurring database maintenance | event or managed external scheduler |

Use `SHOW CREATE VIEW`, `SHOW CREATE PROCEDURE`, `SHOW CREATE FUNCTION`, and `SHOW TRIGGERS` to inspect definitions. Version-control them; do not let production be the only copy of database logic.
