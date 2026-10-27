# 07 — Advanced SQL: windows, JSON, full-text, spatial, generated columns

Advanced features are valuable when they make a query more accurate or maintainable. Use them only after you can state the result grain and test a small result set.

## 1. Window functions: calculate across related rows without collapsing them

`GROUP BY` collapses rows to one row per group. A **window function** keeps every input row while looking at its related “window” of rows.

```sql
WITH paid_order_totals AS (
  SELECT o.order_id, o.customer_id, o.created_at,
         SUM(oi.quantity * oi.unit_price) AS order_total
  FROM orders AS o JOIN order_items AS oi ON oi.order_id = o.order_id
  WHERE o.status = 'paid'
  GROUP BY o.order_id, o.customer_id, o.created_at
)
SELECT
  order_id, customer_id, created_at, order_total,
  ROW_NUMBER() OVER (
    PARTITION BY customer_id
    ORDER BY created_at, order_id
  ) AS purchase_number,
  SUM(order_total) OVER (
    PARTITION BY customer_id
    ORDER BY created_at, order_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS running_customer_spend
FROM paid_order_totals;
```

- `OVER(...)` turns an aggregate/ranking function into a window function.
- `PARTITION BY` resets the calculation per customer; omit it for one window across all rows.
- The window `ORDER BY` supplies sequence. Break ties with a stable key (`order_id`) for repeatable results.
- The explicit `ROWS` frame says “from the first row in this customer’s sequence through this physical row.” Make frames explicit for cumulative analytics.

### Ranking choices

```sql
SELECT product_id, category_id, price,
  ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY price DESC) AS row_num,
  RANK()       OVER (PARTITION BY category_id ORDER BY price DESC) AS rank_with_gaps,
  DENSE_RANK() OVER (PARTITION BY category_id ORDER BY price DESC) AS rank_without_gaps
FROM products;
```

For prices `100, 100, 80`, `ROW_NUMBER` is 1,2,3; `RANK` is 1,1,3; `DENSE_RANK` is 1,1,2. Choose based on what a tie should mean.

### Lag/lead and percent share

```sql
WITH monthly AS (
  SELECT DATE_FORMAT(created_at, '%Y-%m-01') AS month_start,
         SUM(oi.quantity * oi.unit_price) AS revenue
  FROM orders AS o JOIN order_items AS oi ON oi.order_id = o.order_id
  WHERE o.status = 'paid'
  GROUP BY DATE_FORMAT(o.created_at, '%Y-%m-01')
)
SELECT
  month_start, revenue,
  LAG(revenue) OVER (ORDER BY month_start) AS previous_month_revenue,
  revenue - LAG(revenue) OVER (ORDER BY month_start) AS month_change,
  ROUND(100 * revenue / SUM(revenue) OVER (), 2) AS pct_of_all_revenue
FROM monthly
ORDER BY month_start;
```

Because a window value is calculated after `WHERE`, filter on `ROW_NUMBER()` in an outer query/CTE, not directly in the same query’s `WHERE`.

## 2. JSON: flexible attributes with responsibility

`JSON` stores valid JSON and provides functions for querying it. It is useful for sparse, variable metadata that is owned and read as a document. It is not permission to hide core relational facts in one opaque blob.

```sql
CREATE TABLE product_metadata (
  product_id BIGINT UNSIGNED NOT NULL,
  attributes JSON NOT NULL,
  PRIMARY KEY (product_id),
  CONSTRAINT fk_metadata_product FOREIGN KEY (product_id)
    REFERENCES products(product_id) ON DELETE CASCADE
);

INSERT INTO product_metadata (product_id, attributes)
VALUES (1, JSON_OBJECT('colour', 'blue', 'warranty_months', 24, 'tags', JSON_ARRAY('sale','featured')));

SELECT
  product_id,
  attributes ->> '$.colour' AS colour,
  JSON_EXTRACT(attributes, '$.warranty_months') AS warranty_json
FROM product_metadata
WHERE attributes ->> '$.colour' = 'blue';
```

`->` returns JSON; `->>` unquotes/scalarises to text. A JSON path begins with `$`. If a JSON property becomes a frequent filter/sort/join, expose it with a generated column and index it:

```sql
ALTER TABLE product_metadata
  ADD COLUMN colour VARCHAR(30)
    GENERATED ALWAYS AS (attributes ->> '$.colour') STORED,
  ADD INDEX ix_product_metadata_colour (colour);
```

Validate important JSON fields in application logic and/or constraints generated from it. Relational columns remain best for identifiers, foreign keys, frequently queried attributes, and rules.

## 3. Generated columns

A generated column derives its value from other columns. `VIRTUAL` is computed as needed; `STORED` is materialized. Both can be indexed in modern MySQL; test the actual version and workload.

```sql
ALTER TABLE order_items
  ADD COLUMN line_total DECIMAL(12,2)
    GENERATED ALWAYS AS (quantity * unit_price) STORED;
```

Generated columns reduce repeated expression spelling and can support indexing. Do not make them a substitute for understanding currency rounding and immutable order history.

## 4. Full-text search

Normal B-tree indexes support equality/range/prefix patterns. They do not solve relevance-ranked text search. Use a `FULLTEXT` index and `MATCH ... AGAINST` for suitable natural-language documents.

```sql
ALTER TABLE products ADD FULLTEXT KEY ft_products_name (name);

SELECT product_id, name,
       MATCH(name) AGAINST ('database design' IN NATURAL LANGUAGE MODE) AS relevance
FROM products
WHERE MATCH(name) AGAINST ('database design' IN NATURAL LANGUAGE MODE)
ORDER BY relevance DESC;
```

Study token length, stopwords, language, and boolean mode before promising search behaviour. Full-text is not identical to Google-like search, typo tolerance, or semantic search.

## 5. Spatial data

MySQL supports spatial types such as `POINT`, `LINESTRING`, and `POLYGON`. Coordinate systems matter. GPS longitude/latitude should have the intended SRID, commonly 4326; do not silently swap latitude and longitude.

```sql
CREATE TABLE stores (
  store_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  location POINT NOT NULL SRID 4326,
  PRIMARY KEY (store_id),
  SPATIAL INDEX sx_stores_location (location)
) ENGINE=InnoDB;

INSERT INTO stores (name, location)
VALUES ('Central', ST_SRID(POINT(77.5946, 12.9716), 4326)); -- longitude, latitude

SELECT name,
       ST_Distance_Sphere(location, ST_SRID(POINT(77.6, 12.97), 4326)) AS metres_away
FROM stores;
```

Spatial queries require a domain-level decision about earth distance, projections, accuracy, and radius/bounding-box prefilters. Test nearby-border cases.

## 6. Recursive CTE for a hierarchy

```sql
WITH RECURSIVE category_tree AS (
  SELECT category_id, name, parent_category_id, 0 AS depth,
         CAST(name AS CHAR(1000)) AS path
  FROM categories
  WHERE parent_category_id IS NULL
  UNION ALL
  SELECT c.category_id, c.name, c.parent_category_id, ct.depth + 1,
         CONCAT(ct.path, ' > ', c.name)
  FROM categories AS c
  JOIN category_tree AS ct ON c.parent_category_id = ct.category_id
)
SELECT * FROM category_tree ORDER BY path;
```

Prevent cycles at data-entry time; a recursive query over a cyclic hierarchy is a design/validation problem. Set recursion limits and do not use recursive CTEs as a casual replacement for a better hierarchy model at massive scale.

## 7. Feature decision guide

Use windows for ranking/running/comparison analytics; CTEs for named query stages; JSON for flexible document-like metadata; generated columns for repeatable derived/indexed values; full-text for word search; spatial for geometry. None replaces a clear schema, primary keys, foreign keys, and measured indexes.
