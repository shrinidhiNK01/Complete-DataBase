# Lab solutions and reasoning checkpoints

Do not compare only query text: verify row grain and filters. These are reference solutions; equivalent queries can be equally good.

## Lab 01 — selected solutions

```sql
USE mysql_mastery_lab;
SELECT DATABASE();
SHOW TABLES;
SHOW CREATE TABLE orders;

SELECT sku, name, price
FROM products
WHERE is_active = TRUE
ORDER BY price DESC, name ASC;

SELECT product_id, sku, name
FROM products
WHERE name LIKE '%SQL%';

INSERT INTO products (category_id, sku, name, price, is_active)
VALUES (1, 'BK-LAB-001', 'Lab SQL Book', 20.00, TRUE);

SELECT LAST_INSERT_ID() AS new_product_id;
SELECT product_id, sku, price FROM products WHERE sku = 'BK-LAB-001';

-- Preview first.
SELECT product_id, sku, price, ROUND(price * 1.10, 2) AS proposed_price
FROM products WHERE sku = 'BK-LAB-001';

UPDATE products
SET price = ROUND(price * 1.10, 2)
WHERE sku = 'BK-LAB-001';

UPDATE products
SET is_active = FALSE
WHERE sku = 'BK-LAB-001';

SELECT sku, name FROM products WHERE is_active = TRUE;
```

The unique index `uq_products_sku` rejects a duplicate SKU. The correct response is to decide whether the incoming record is the same product/update or a genuinely new product—not to remove the rule.

## Lab 02 — selected solutions

```sql
SELECT
  CONCAT(first_name, ' ', last_name) AS full_name,
  LOWER(email) AS email_lower,
  COALESCE(city, 'City unknown') AS city_label
FROM customers;

SELECT customer_id, email
FROM customers
WHERE city IS NULL;

SELECT order_id, customer_id, created_at
FROM orders
WHERE created_at >= '2026-07-01'
  AND created_at <  '2026-08-01';

SELECT sku, name, price,
  CASE
    WHEN price < 30 THEN 'budget'
    WHEN price < 80 THEN 'standard'
    ELSE 'premium'
  END AS price_band
FROM products;

SELECT order_id, discount_code
FROM orders
WHERE discount_code IN ('WELCOME10', 'SUMMER');

SELECT order_id, discount_code
FROM orders
WHERE discount_code IS NULL;
```

The July query includes exactly `2026-07-01 00:00:00` through but not `2026-08-01 00:00:00`; it therefore includes every possible July time without hard-coding a final second.

## Lab 03 — aggregation solution

First calculate revenue at **one row per order**. Doing this in a CTE prevents order-item multiplication from being forgotten in later metrics.

```sql
WITH revenue_orders AS (
  SELECT o.order_id, o.customer_id, o.created_at,
         SUM(oi.quantity * oi.unit_price) AS order_total
  FROM orders AS o
  JOIN order_items AS oi ON oi.order_id = o.order_id
  WHERE o.status IN ('paid', 'shipped')
  GROUP BY o.order_id, o.customer_id, o.created_at
)
SELECT
  SUM(order_total) AS revenue,
  COUNT(*) AS revenue_order_count,
  COUNT(DISTINCT customer_id) AS paying_customer_count,
  AVG(order_total) AS average_order_value,
  MIN(order_total) AS smallest_order,
  MAX(order_total) AS largest_order
FROM revenue_orders;

WITH revenue_orders AS (
  SELECT o.order_id, o.customer_id, SUM(oi.quantity * oi.unit_price) AS order_total
  FROM orders AS o JOIN order_items AS oi ON oi.order_id = o.order_id
  WHERE o.status IN ('paid', 'shipped')
  GROUP BY o.order_id, o.customer_id
)
SELECT c.customer_id, c.email,
       COUNT(ro.order_id) AS revenue_orders,
       COALESCE(SUM(ro.order_total), 0) AS total_spend
FROM customers AS c
LEFT JOIN revenue_orders AS ro ON ro.customer_id = c.customer_id
GROUP BY c.customer_id, c.email
HAVING COALESCE(SUM(ro.order_total), 0) >= 100
ORDER BY total_spend DESC;
```

Notice `COUNT(ro.order_id)`, not `COUNT(*)`: the left join creates one preserved customer row even when there is no matching revenue order.

```sql
SELECT ca.name AS category,
       COALESCE(SUM(CASE WHEN o.status IN ('paid','shipped') THEN oi.quantity ELSE 0 END), 0) AS units_sold,
       COALESCE(SUM(CASE WHEN o.status IN ('paid','shipped')
                         THEN oi.quantity * oi.unit_price ELSE 0 END), 0) AS revenue
FROM categories AS ca
LEFT JOIN products AS p ON p.category_id = ca.category_id
LEFT JOIN order_items AS oi ON oi.product_id = p.product_id
LEFT JOIN orders AS o ON o.order_id = oi.order_id
GROUP BY ca.category_id, ca.name
ORDER BY revenue DESC;
```

## Lab 04 — join solution

```sql
-- Grain: one row per order item.
SELECT o.order_id, o.created_at, c.email, p.sku, p.name,
       oi.quantity, oi.unit_price,
       oi.quantity * oi.unit_price AS line_total
FROM orders AS o
JOIN customers AS c ON c.customer_id = o.customer_id
JOIN order_items AS oi ON oi.order_id = o.order_id
JOIN products AS p ON p.product_id = oi.product_id
ORDER BY o.order_id, oi.order_item_id;

-- Grain: one row per order.
SELECT o.order_id, c.email,
       SUM(oi.quantity * oi.unit_price) AS calculated_total
FROM orders AS o
JOIN customers AS c ON c.customer_id = o.customer_id
JOIN order_items AS oi ON oi.order_id = o.order_id
GROUP BY o.order_id, c.email;

-- Grain: one row per customer, including customers with zero revenue orders.
SELECT c.customer_id, c.email, COUNT(o.order_id) AS revenue_order_count
FROM customers AS c
LEFT JOIN orders AS o
  ON o.customer_id = c.customer_id
 AND o.status IN ('paid', 'shipped')
GROUP BY c.customer_id, c.email;

SELECT c.customer_id, c.email
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

SELECT c.customer_id, c.email
FROM customers AS c
WHERE NOT EXISTS (
  SELECT 1 FROM orders AS o WHERE o.customer_id = c.customer_id
);
```

To retain zero children, the `o.status` condition belongs in `ON`. Putting it in `WHERE` rejects the NULL-extended child columns and turns the result effectively into an inner join.

```sql
SELECT p.product_id, p.sku, p.name
FROM products AS p
WHERE NOT EXISTS (
  SELECT 1
  FROM order_items AS oi
  JOIN orders AS o ON o.order_id = oi.order_id
  WHERE oi.product_id = p.product_id
    AND o.status IN ('paid', 'shipped')
);
```

## Lab 05 — advanced-querying solution

```sql
-- Above average price in its own category: correlated version.
SELECT p.product_id, p.name, p.category_id, p.price
FROM products AS p
WHERE p.price > (
  SELECT AVG(p2.price)
  FROM products AS p2
  WHERE p2.category_id = p.category_id
);

-- Same idea: stage category averages once.
WITH category_averages AS (
  SELECT category_id, AVG(price) AS avg_price
  FROM products
  GROUP BY category_id
)
SELECT p.product_id, p.name, p.price, ca.avg_price
FROM products AS p
JOIN category_averages AS ca ON ca.category_id = p.category_id
WHERE p.price > ca.avg_price;

SELECT c.customer_id, c.email
FROM customers AS c
WHERE EXISTS (
  SELECT 1 FROM orders AS o
  WHERE o.customer_id = c.customer_id
    AND o.status IN ('paid','shipped')
);

WITH revenue_orders AS (
  SELECT o.order_id, o.customer_id, o.created_at,
         SUM(oi.quantity * oi.unit_price) AS order_total
  FROM orders AS o JOIN order_items AS oi ON oi.order_id = o.order_id
  WHERE o.status IN ('paid','shipped')
  GROUP BY o.order_id, o.customer_id, o.created_at
)
SELECT order_id, customer_id, created_at, order_total,
       ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at, order_id) AS purchase_number,
       SUM(order_total) OVER (
         PARTITION BY customer_id ORDER BY created_at, order_id
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_spend
FROM revenue_orders;
```

## Lab 06 — one defensible course schema

```sql
CREATE TABLE students (
  student_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  student_number VARCHAR(30) NOT NULL,
  email VARCHAR(254) NOT NULL,
  full_name VARCHAR(200) NOT NULL,
  UNIQUE KEY uq_students_number (student_number),
  UNIQUE KEY uq_students_email (email)
) ENGINE=InnoDB;

CREATE TABLE instructors (
  instructor_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(254) NOT NULL,
  full_name VARCHAR(200) NOT NULL,
  UNIQUE KEY uq_instructors_email (email)
) ENGINE=InnoDB;

CREATE TABLE courses (
  course_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  course_code VARCHAR(20) NOT NULL,
  title VARCHAR(200) NOT NULL,
  UNIQUE KEY uq_courses_code (course_code)
) ENGINE=InnoDB;

CREATE TABLE course_offerings (
  offering_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  course_id BIGINT UNSIGNED NOT NULL,
  instructor_id BIGINT UNSIGNED NOT NULL,
  term_code VARCHAR(30) NOT NULL,
  capacity INT UNSIGNED NOT NULL,
  UNIQUE KEY uq_offerings_course_term (course_id, term_code),
  KEY ix_offerings_instructor (instructor_id),
  CONSTRAINT chk_offerings_capacity CHECK (capacity > 0),
  CONSTRAINT fk_offerings_course FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE RESTRICT,
  CONSTRAINT fk_offerings_instructor FOREIGN KEY (instructor_id) REFERENCES instructors(instructor_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE enrollments (
  enrollment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  offering_id BIGINT UNSIGNED NOT NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  enrolled_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_enrollments_offering_student (offering_id, student_id),
  KEY ix_enrollments_student_time (student_id, enrolled_at),
  CONSTRAINT fk_enrollments_offering FOREIGN KEY (offering_id) REFERENCES course_offerings(offering_id) ON DELETE RESTRICT,
  CONSTRAINT fk_enrollments_student FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE RESTRICT
) ENGINE=InnoDB;
```

`RESTRICT` preserves course-history integrity; a real system might use soft deletion/inactivation for people/courses. Capacity enforcement needs a transaction/conditional state change or a seat-allocation design; a plain count check cannot safely prevent concurrent over-enrollment.

## Lab 07 — safe reservation reference

```sql
START TRANSACTION;

UPDATE inventory
SET stock_quantity = stock_quantity - 1,
    version = version + 1
WHERE product_id = 4
  AND stock_quantity >= 1;

SELECT ROW_COUNT() AS reservation_succeeded;
-- Application/routine: if zero, ROLLBACK and report no stock.
-- If one, insert the related line/order work, then:
COMMIT;
```

The guarded update is atomic. `FOR UPDATE` is useful when you must first read/coordinate several rows, but never separate a read from a later unguarded decrement. On deadlock, roll back the entire transaction and retry its whole idempotent unit a limited number of times.

## Lab 08 — expected reasoning

`EXPLAIN` answers how MySQL expects to access the rows; `EXPLAIN ANALYZE` supplies actual execution evidence. Prefer the range predicate over `DATE(created_at)` because the former permits an ordered index range seek. A replica replays committed changes, including a bad committed delete, so it cannot by itself restore the missing data. A restore test brings a backup into isolation first, verifies the required data/time, then performs a reviewed repair—not a blind overwrite of live service.

