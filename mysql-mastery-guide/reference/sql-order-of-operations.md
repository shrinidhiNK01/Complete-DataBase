# SQL clause order: a pocket reference

## Written order

```sql
SELECT [DISTINCT] select_list
FROM source
JOIN other_source ON join_condition
WHERE row_condition
GROUP BY grouping_columns
HAVING group_condition
ORDER BY output_or_expression
LIMIT count OFFSET skipped_rows;
```

## Simplified logical order

1. `FROM` and `JOIN` build candidate rows.
2. `WHERE` filters individual rows.
3. `GROUP BY` creates groups.
4. Aggregate functions compute per group.
5. `HAVING` filters groups.
6. Window functions compute over the remaining result.
7. `SELECT` forms output expressions/aliases.
8. `DISTINCT` removes duplicate output rows.
9. `ORDER BY` sorts.
10. `LIMIT` restricts output.

This model explains common errors: a `SELECT` alias is generally too late for `WHERE`; aggregate filters go in `HAVING`; a window function filter needs a CTE/outer query.

