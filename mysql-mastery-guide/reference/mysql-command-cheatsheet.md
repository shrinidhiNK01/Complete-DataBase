# MySQL command cheat sheet (use with understanding)

```sql
-- Navigate and inspect
SHOW DATABASES; USE database_name; SHOW TABLES;
DESCRIBE table_name; SHOW CREATE TABLE table_name; SHOW INDEX FROM table_name;

-- Data
INSERT INTO t (a, b) VALUES (1, 'x');
SELECT a, b FROM t WHERE a = 1 ORDER BY b LIMIT 10;
UPDATE t SET b = 'y' WHERE a = 1;
DELETE FROM t WHERE a = 1;

-- Structure
CREATE TABLE t (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) NOT NULL);
ALTER TABLE t ADD COLUMN created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;
DROP TABLE t; -- permanent definition + data loss

-- Safety
START TRANSACTION; SAVEPOINT s1; ROLLBACK TO s1; COMMIT; ROLLBACK;

-- Access and plans
EXPLAIN SELECT ...;
EXPLAIN ANALYZE SELECT ...; -- executes the query
SHOW PROCESSLIST;
```

Before `UPDATE`, `DELETE`, `DROP`, `TRUNCATE`, or DDL: confirm `SELECT DATABASE()`, preview rows, identify a backup/transaction path, and check affected rows.

