# Capstone — Marketplace from brief to operations

Build and document a mini marketplace. Treat the following like a take-home database project: submit a schema script, seed script, report script, and a short design/operations document.

## Brief

Customers have addresses. Products belong to categories and have current price. A customer checks out one or more items. An order must preserve item title, unit price, tax, discount, and shipping address as historical facts. Inventory cannot go below zero. Payments can have multiple attempts and must be auditable. Support staff need order history. Finance needs daily revenue; marketing needs customers who have not purchased for 90 days; operations needs products below reorder point.

## Required deliverables

1. An ER diagram and a one-sentence grain statement for every table.
2. DDL with named primary/foreign/unique/check constraints and essential indexes.
3. Seed data that includes: zero-order customer, cancelled order, multi-line order, product whose current price changed after a purchase, a failed then successful payment attempt, and low stock.
4. A stored procedure or clearly documented application transaction pseudocode for checkout/reservation. It must be safe under concurrent requests.
5. Ten reports, including the three stated above, customer lifetime value, top products per category, and a monthly running revenue metric.
6. One view for a least-privilege support/reporting role.
7. `EXPLAIN` evidence and a reasoned index decision for two reports.
8. A security/backup/recovery plan: accounts/privileges, backup types, restore-test cadence, RPO/RTO, and response to accidental deletion.

## Review rubric

| Area | Questions reviewers ask |
|---|---|
| Correctness | Can impossible rows enter? Does every query return its stated grain? |
| History | Does a changed product/address rewrite an old invoice? |
| Concurrency | Can two requests sell the same final unit? |
| Clarity | Are names, constraints, and queries readable without oral explanation? |
| Performance | Are indexes justified by measured workloads/plans? |
| Operations | Can the team restore, observe, and limit access? |

Aim for a design you can defend, not the largest number of tables.

