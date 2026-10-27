# 02 — Installation, connection, and everyday tools

## 1. Install PostgreSQL on Windows

Download the current supported Windows installer from the official PostgreSQL site (distributed by EDB), then follow the installer.

1. Select **PostgreSQL Server**, **pgAdmin 4**, and **Command Line Tools**. Stack Builder is optional.
2. Keep the installation directory unless your organization uses a managed location.
3. Set a long, unique password for the initial superuser named `postgres`. Save it in a password manager.
4. Leave port `5432` unless it conflicts with an existing service. The port is part of a connection address.
5. Choose a locale appropriate to your application. Collation affects sort/comparison behaviour and is hard to change later.
6. Finish installation. PostgreSQL normally runs as a Windows service.

**Security:** The `postgres` account is powerful. Do not use it as the application’s everyday login and never expose port 5432 directly to the public internet without a carefully designed network and TLS policy.

## 2. Install on macOS and Linux

Use the official PostgreSQL download page for packages/installers, or your operating system’s package manager. On Linux, packages commonly create a service and a system account named `postgres`; service commands vary by distribution. Confirm installation with:

```bash
psql --version
```

The client version need not exactly match the server, but it should be compatible. For production, follow your distribution/vendor’s upgrade and support policy rather than copying internet commands.

## 3. Connection anatomy

```text
postgresql://user:password@host:5432/database?sslmode=require
             |    |        |    |     |        |
             |    |        |    |     |        +-- connection options
             |    |        |    |     +-- database name
             |    |        |    +-- port
             |    |        +-- server address
             |    +-- secret (do not put this in source code)
             +-- role/login name
```

For local practice, the usual values are host `localhost`, port `5432`, login role `postgres`, and database `postgres`. A connection identifies both a server and a database. PostgreSQL does not let you switch databases mid-session: reconnect with `\c other_database` in `psql`.

## 4. `psql`: the essential command-line client

Start a local session (Windows PowerShell example):

```powershell
psql -U postgres -d postgres -h localhost -p 5432
```

If `psql` is not on `PATH`, launch **SQL Shell (psql)** from the Start menu or add PostgreSQL’s `bin` folder to `PATH`.

### The most useful `psql` meta-commands

Meta-commands begin with a backslash and are handled by `psql`, not SQL.

| Command | What it does |
|---|---|
| `\?` | Lists psql commands. |
| `\l` | Lists databases. |
| `\c database_name` | Connects to a database. |
| `\dn` | Lists schemas. |
| `\dt` | Lists visible tables. |
| `\d academy.student` | Describes columns, keys, indexes, and constraints. |
| `\df` | Lists functions. |
| `\du` | Lists roles. |
| `\x on` | Expanded output—great for wide rows. |
| `\timing on` | Shows query duration. |
| `\i path/to/file.sql` | Executes a SQL script. |
| `\e` | Opens the current query in your editor. |
| `\q` | Quits. |

Notice the difference between `\d` and SQL `DESCRIBE`. PostgreSQL does **not** support MySQL’s `DESCRIBE table` command; use `\d table`, information schema views, or catalog tables.

## 5. pgAdmin: graphical administration

pgAdmin is useful for browsing objects, running a query tool, viewing `EXPLAIN`, managing roles, and restoring backups. Create a server registration by supplying host, port, maintenance database, username, and password. A registration is only saved connection metadata; it does not create a server.

Use the **Query Tool** for multi-line SQL. Save scripts as `.sql` files in version control. A GUI query history is helpful but is not a migration system, audit trail, or backup.

## 6. Create, list, connect, and drop databases

Connect to the maintenance database `postgres` and run:

```sql
CREATE DATABASE academy_db;
```

`CREATE DATABASE` cannot run inside a transaction block. Connect to it:

```sql
-- psql meta-command, not SQL
\c academy_db

CREATE SCHEMA academy;
```

List databases via `\l` or query PostgreSQL’s catalog:

```sql
SELECT datname
FROM pg_database
WHERE datistemplate = false
ORDER BY datname;
```

Drop only a disposable database after confirming the target. You cannot drop the database to which you are currently connected.

```sql
-- Destructive: permanently removes the database and all its objects.
DROP DATABASE academy_db;
```

If active sessions block a drop, do not reflexively terminate them on a shared system. Identify the users/application owners first. For a local throwaway database only, reconnect elsewhere and use `DROP DATABASE academy_db WITH (FORCE);` on supported PostgreSQL releases.

## 7. Create a dedicated practice role

```sql
-- Run as an administrator, connected to postgres.
CREATE ROLE academy_user LOGIN PASSWORD 'replace-this-with-a-secret';
CREATE DATABASE academy_db OWNER academy_user;
```

The password in an example is deliberately not a real secret. In actual applications, place credentials in a secret manager or environment-specific secure configuration, not in Git, client-side code, screenshots, or chat logs.

Connect as the practice user:

```powershell
psql -U academy_user -d academy_db -h localhost
```

## 8. Run the companion schema

After creating `academy_db`, execute the supplied seed script from `psql`:

```text
\i 'C:/Users/Shrinidhi N K/Documents/Codex/2026-08-21/all-of-this-and-much-more/outputs/postgresql-master-handbook/lab-schema.sql'
```

Then verify:

```sql
SELECT * FROM academy.student;
\d academy.enrollment
```

The script is repeatable: it drops only the `academy` practice schema and recreates it. Read it before running it anywhere. Never treat a generic training script as safe for a production database.

## 9. SQL statement anatomy and errors

SQL normally ends with a semicolon. Whitespace and new lines are mostly for humans.

```sql
SELECT student_id, full_name
FROM academy.student
WHERE active = true
ORDER BY full_name;
```

When PostgreSQL reports an error, read the entire message: it identifies the problem type and shows a caret near the location. Typical causes are a missing comma, incorrect quote type, misspelled identifier, type mismatch, missing permission, violated constraint, or an uncommitted aborted transaction.

If the prompt changes to `academy_db=!#`, a statement failed inside an explicit transaction. Run `ROLLBACK;` before continuing. Do not keep issuing commands in an aborted transaction.

## 10. Essential documentation habit

In `psql`, use `\h SELECT` or `\h CREATE TABLE` for syntax help. PostgreSQL’s official documentation is versioned: make sure you are viewing the version that runs on your server. Good database work means checking exact behaviour when it matters, especially around locking, type casts, function volatility, backup/restore, and major-version upgrades.

## Setup checkpoint

You should be able to create a database, reconnect as a non-superuser, create a schema, execute a `.sql` file, describe a table, and explain why a GUI does not replace SQL scripts in version control.
