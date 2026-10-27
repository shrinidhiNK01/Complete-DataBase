-- MySQL Mastery Lab — disposable practice schema
-- Run this file in a local learning environment. It deletes only mysql_mastery_lab.

DROP DATABASE IF EXISTS mysql_mastery_lab;
CREATE DATABASE mysql_mastery_lab
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE mysql_mastery_lab;

CREATE TABLE customers (
  customer_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email VARCHAR(254) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  city VARCHAR(100) NULL,
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (customer_id),
  UNIQUE KEY uq_customers_email (email)
) ENGINE=InnoDB;

CREATE TABLE categories (
  category_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  PRIMARY KEY (category_id),
  UNIQUE KEY uq_categories_name (name)
) ENGINE=InnoDB;

CREATE TABLE products (
  product_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id BIGINT UNSIGNED NULL,
  sku VARCHAR(40) NOT NULL,
  name VARCHAR(150) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (product_id),
  UNIQUE KEY uq_products_sku (sku),
  KEY ix_products_category_id (category_id),
  CONSTRAINT chk_products_price CHECK (price >= 0),
  CONSTRAINT fk_products_category FOREIGN KEY (category_id)
    REFERENCES categories(category_id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE orders (
  order_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id BIGINT UNSIGNED NOT NULL,
  status ENUM('pending','paid','shipped','cancelled') NOT NULL,
  discount_code VARCHAR(30) NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (order_id),
  KEY ix_orders_customer_created (customer_id, created_at),
  KEY ix_orders_status_created (status, created_at),
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
    REFERENCES customers(customer_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE order_items (
  order_item_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (order_item_id),
  UNIQUE KEY uq_order_items_order_product (order_id, product_id),
  KEY ix_order_items_product_id (product_id),
  CONSTRAINT chk_order_items_quantity CHECK (quantity > 0),
  CONSTRAINT chk_order_items_unit_price CHECK (unit_price >= 0),
  CONSTRAINT fk_order_items_order FOREIGN KEY (order_id)
    REFERENCES orders(order_id) ON DELETE CASCADE,
  CONSTRAINT fk_order_items_product FOREIGN KEY (product_id)
    REFERENCES products(product_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE inventory (
  product_id BIGINT UNSIGNED NOT NULL,
  stock_quantity INT NOT NULL,
  version INT NOT NULL DEFAULT 1,
  PRIMARY KEY (product_id),
  CONSTRAINT chk_inventory_nonnegative CHECK (stock_quantity >= 0),
  CONSTRAINT fk_inventory_product FOREIGN KEY (product_id)
    REFERENCES products(product_id) ON DELETE CASCADE
) ENGINE=InnoDB;

INSERT INTO customers (email, first_name, last_name, city, joined_at) VALUES
  ('ada@example.com',    'Ada',    'Lovelace', 'Bengaluru', '2026-01-05 10:00:00'),
  ('grace@example.com',  'Grace',  'Hopper',   'Chennai',   '2026-01-18 11:00:00'),
  ('alan@example.com',   'Alan',   'Turing',   'Mumbai',    '2026-02-02 09:00:00'),
  ('margaret@example.com','Margaret','Hamilton','Bengaluru', '2026-02-20 14:00:00'),
  ('linus@example.com',  'Linus',  'Torvalds', NULL,        '2026-03-10 16:00:00'),
  ('new@example.com',    'New',    'Customer', 'Delhi',     '2026-08-10 12:00:00');

INSERT INTO categories (name) VALUES ('Books'), ('Hardware'), ('Courses');

INSERT INTO products (category_id, sku, name, price, is_active) VALUES
  (1, 'BK-SQL',  'SQL Patterns',        34.50, TRUE),
  (1, 'BK-DES',  'Database Design',     29.99, TRUE),
  (1, 'BK-OLD',  'Legacy SQL Notes',    12.00, FALSE),
  (2, 'HW-KEY',  'Mechanical Keyboard', 89.00, TRUE),
  (2, 'HW-MOU',  'Wireless Mouse',      25.00, TRUE),
  (3, 'CR-DBA',  'MySQL Administration',120.00, TRUE);

INSERT INTO inventory (product_id, stock_quantity) VALUES
  (1, 40), (2, 25), (3, 0), (4, 6), (5, 18), (6, 12);

INSERT INTO orders (customer_id, status, discount_code, created_at) VALUES
  (1, 'paid',      'WELCOME10', '2026-06-02 09:20:00'), -- order 1
  (1, 'shipped',   NULL,        '2026-07-15 14:10:00'), -- order 2
  (2, 'paid',      NULL,        '2026-07-20 12:00:00'), -- order 3
  (3, 'cancelled', NULL,        '2026-07-23 16:00:00'), -- order 4
  (4, 'paid',      'SUMMER',   '2026-08-02 10:00:00'), -- order 5
  (4, 'pending',   NULL,        '2026-08-05 13:45:00'), -- order 6
  (5, 'paid',      NULL,        '2026-08-09 08:30:00'); -- order 7

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
  (1, 1, 2, 34.50), (1, 5, 1, 25.00),
  (2, 4, 1, 89.00), (2, 2, 1, 29.99),
  (3, 2, 3, 29.99),
  (4, 1, 1, 34.50),
  (5, 6, 1, 120.00), (5, 1, 1, 34.50),
  (6, 5, 2, 25.00),
  (7, 4, 1, 89.00), (7, 5, 2, 25.00);

-- Trust no stored order total blindly: calculate it at the correct grain.
SELECT o.order_id, o.status, SUM(oi.quantity * oi.unit_price) AS calculated_total
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.status
ORDER BY o.order_id;

