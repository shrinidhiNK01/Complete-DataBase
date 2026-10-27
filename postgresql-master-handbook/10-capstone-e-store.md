# 10 — Capstone: design and build an e-store database

This capstone connects modeling, constraints, transactions, indexes, analytics, and operations. Build it in a fresh database/schema. It is deliberately small enough to understand and realistic enough to teach professional decisions.

## 1. Requirements before tables

The store sells products. Customers place orders. An order contains one or more line items. Product price and name may change later, but an old invoice must remain historically accurate. Stock must never become negative. Orders can be placed, paid, shipped, cancelled, or refunded. A customer may have many addresses; an order needs a snapshot of the shipping address used at checkout.

```mermaid
erDiagram
  CUSTOMER ||--o{ CUSTOMER_ADDRESS : owns
  CUSTOMER ||--o{ SALES_ORDER : places
  CUSTOMER_ADDRESS ||--o{ SALES_ORDER : ships_to
  SALES_ORDER ||--|{ ORDER_ITEM : contains
  PRODUCT ||--o{ ORDER_ITEM : sold_as
  PRODUCT ||--|| INVENTORY : has
  SALES_ORDER ||--o{ PAYMENT : receives
  CUSTOMER {
    bigint customer_id PK
    citext email UK
  }
  PRODUCT {
    bigint product_id PK
    text sku UK
    numeric list_price
  }
  SALES_ORDER {
    bigint order_id PK
    bigint customer_id FK
    text status
  }
  ORDER_ITEM {
    bigint order_id PK_FK
    integer line_no PK
    bigint product_id FK
    numeric unit_price
    integer quantity
  }
```

Notice the history decision: an order item references the current product **and** stores `product_name`/`unit_price` snapshots. A product table alone cannot tell you what the customer agreed to pay last year.

## 2. Build the schema

```sql
CREATE SCHEMA store;
CREATE EXTENSION IF NOT EXISTS citext; -- Optional; enables case-insensitive email type.

CREATE TABLE store.customer (
  customer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email citext NOT NULL UNIQUE,
  full_name text NOT NULL CHECK (btrim(full_name) <> ''),
  created_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE store.customer_address (
  address_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id bigint NOT NULL REFERENCES store.customer(customer_id),
  label text NOT NULL DEFAULT 'shipping',
  recipient_name text NOT NULL,
  line1 text NOT NULL,
  line2 text,
  city text NOT NULL,
  postal_code text NOT NULL,
  country_code char(2) NOT NULL CHECK (country_code ~ '^[A-Z]{2}$'),
  UNIQUE (address_id, customer_id)
);

CREATE TABLE store.product (
  product_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sku text NOT NULL UNIQUE CHECK (sku = upper(btrim(sku))),
  product_name text NOT NULL CHECK (btrim(product_name) <> ''),
  list_price numeric(12,2) NOT NULL CHECK (list_price >= 0),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE store.inventory (
  product_id bigint PRIMARY KEY REFERENCES store.product(product_id),
  available_quantity integer NOT NULL CHECK (available_quantity >= 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE store.sales_order (
  order_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id bigint NOT NULL REFERENCES store.customer(customer_id),
  shipping_address_id bigint NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'paid', 'shipped', 'cancelled', 'refunded')),
  placed_at timestamptz NOT NULL DEFAULT now(),
  paid_at timestamptz,
  shipped_at timestamptz,
  cancelled_at timestamptz,
  currency_code char(3) NOT NULL DEFAULT 'INR' CHECK (currency_code ~ '^[A-Z]{3}$'),
  CHECK ((status <> 'paid') OR paid_at IS NOT NULL),
  CHECK ((status <> 'shipped') OR shipped_at IS NOT NULL),
  FOREIGN KEY (shipping_address_id, customer_id)
    REFERENCES store.customer_address(address_id, customer_id)
);

CREATE TABLE store.order_item (
  order_id bigint NOT NULL REFERENCES store.sales_order(order_id) ON DELETE RESTRICT,
  line_no integer NOT NULL CHECK (line_no > 0),
  product_id bigint NOT NULL REFERENCES store.product(product_id),
  product_name_at_sale text NOT NULL,
  unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0),
  quantity integer NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (order_id, line_no),
  UNIQUE (order_id, product_id)
);

CREATE TABLE store.payment (
  payment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id bigint NOT NULL REFERENCES store.sales_order(order_id),
  provider text NOT NULL,
  provider_reference text NOT NULL,
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  status text NOT NULL CHECK (status IN ('authorized', 'captured', 'failed', 'refunded')),
  received_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_reference)
);
```

### Key design review

- `customer_address` has `UNIQUE (address_id, customer_id)` purely so the order can prove the chosen address belongs to the same customer. The composite foreign key prevents cross-customer address use.
- `order_item` has `(order_id, line_no)` identity because line position is part of the invoice. `UNIQUE (order_id, product_id)` means a product appears at most once per order; omit it if duplicates are meaningful.
- Check constraints handle row-local truth. They cannot prove an order has at least one item, payment totals equal order totals, or payment amount equals a multi-row sum; handle those with an explicit transaction/workflow or a carefully designed trigger.
- `deleted_at` demonstrates soft delete. Default queries must consciously filter it; a partial index can support that access path.

## 3. Place an order safely

The following is a teaching workflow. In an application, execute it with parameterized SQL in one transaction and treat returned IDs/row counts as evidence.

```sql
BEGIN;

-- 1. Lock and decrement only when enough stock exists.
WITH reserved AS (
  UPDATE store.inventory
  SET available_quantity = available_quantity - 2,
      updated_at = now()
  WHERE product_id = 7
    AND available_quantity >= 2
  RETURNING product_id
)
SELECT count(*) AS reserved_count FROM reserved;
-- Require reserved_count = 1. If zero, ROLLBACK with “out of stock”.

-- 2. Create the order. Assume returned order_id is 5001.
INSERT INTO store.sales_order (customer_id, shipping_address_id)
VALUES (42, 91)
RETURNING order_id;

-- 3. Snapshot product data in the line item.
INSERT INTO store.order_item
  (order_id, line_no, product_id, product_name_at_sale, unit_price, quantity)
SELECT 5001, 1, p.product_id, p.product_name, p.list_price, 2
FROM store.product AS p
WHERE p.product_id = 7 AND p.active;

-- Require one inserted row. Then record successful payment and transition state.
INSERT INTO store.payment (order_id, provider, provider_reference, amount, status)
VALUES (5001, 'demo_gateway', 'txn-unique-001', 598.00, 'captured');

UPDATE store.sales_order
SET status = 'paid', paid_at = now()
WHERE order_id = 5001 AND status = 'pending';

COMMIT;
```

For a robust implementation, avoid hardcoded `5001`: hold it in application code, use a function, or chain statements with data-changing CTEs. Payment provider callbacks must be idempotent—the unique provider reference helps ensure retries do not insert duplicate payments. Make state transitions explicit; a simple status check permits some invalid jumps, so an application state machine or trigger may be justified if every writer needs enforcement.

## 4. Business queries

### Invoice total from line facts

```sql
SELECT
  o.order_id,
  o.placed_at,
  o.currency_code,
  sum(oi.unit_price * oi.quantity) AS order_total
FROM store.sales_order AS o
JOIN store.order_item AS oi ON oi.order_id = o.order_id
WHERE o.order_id = 5001
GROUP BY o.order_id, o.placed_at, o.currency_code;
```

### Customer spending, including zero-order customers

```sql
WITH order_totals AS (
  SELECT o.order_id, o.customer_id, sum(oi.unit_price * oi.quantity) AS total
  FROM store.sales_order AS o
  JOIN store.order_item AS oi ON oi.order_id = o.order_id
  WHERE o.status IN ('paid', 'shipped')
  GROUP BY o.order_id, o.customer_id
)
SELECT c.customer_id, c.full_name,
       coalesce(sum(ot.total), 0) AS lifetime_spend
FROM store.customer AS c
LEFT JOIN order_totals AS ot ON ot.customer_id = c.customer_id
WHERE c.deleted_at IS NULL
GROUP BY c.customer_id, c.full_name
ORDER BY lifetime_spend DESC, c.customer_id;
```

### Monthly revenue with a running total

```sql
WITH monthly AS (
  SELECT date_trunc('month', o.paid_at) AS month,
         sum(oi.unit_price * oi.quantity) AS revenue
  FROM store.sales_order AS o
  JOIN store.order_item AS oi ON oi.order_id = o.order_id
  WHERE o.status IN ('paid', 'shipped')
  GROUP BY 1
)
SELECT month, revenue,
       sum(revenue) OVER (ORDER BY month) AS running_revenue
FROM monthly
ORDER BY month;
```

## 5. Index intentionally

```sql
CREATE INDEX sales_order_customer_placed_idx
ON store.sales_order (customer_id, placed_at DESC);

CREATE INDEX order_item_product_idx ON store.order_item (product_id);
CREATE INDEX payment_order_idx ON store.payment (order_id);

CREATE INDEX active_product_sku_idx
ON store.product (sku) WHERE active;

CREATE INDEX active_customer_email_idx
ON store.customer (email) WHERE deleted_at IS NULL;
```

These serve plausible query/foreign-key paths. Confirm with production-like `EXPLAIN (ANALYZE, BUFFERS)` before declaring them required. The unique constraints already create indexes for their keys.

## 6. Capstone extension challenges

1. Add promotions without allowing an arbitrary negative price. Decide where discount snapshot facts belong.
2. Support partial captures/refunds and prove no order is over-refunded. What requires transaction-level coordination?
3. Add product categories with a many-to-many `product_category` bridge.
4. Support multiple warehouse stock locations. Determine the inventory primary key and locking statement.
5. Add tenant isolation using a `tenant_id` and row-level security. Test with two runtime roles/tenant contexts.
6. Write migrations, seed data, test data, and a backup/restore verification plan. The capstone is complete only when it can be operated, not merely created.
