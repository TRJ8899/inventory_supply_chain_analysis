-- 04_compare_with_abc_key.sql
-- Purpose: compare my within-currency ABC classes with the dataset's answer key (ABC_SEGMENT_v22.csv).
-- Before running: import ABC_SEGMENT_v22.csv into a table called abc_segment
-- (right-click Tables -> Table Data Import Wizard).
-- Requires the view abc_within_currency from 02_abc_analysis.sql.

USE supply_chain;

-- 1. Check the import. Expected: 267 rows
SELECT COUNT(*) FROM abc_segment;

-- 2. Compare my class with each product's main class in the key
-- (the class it spent the most days in; ties are broken arbitrarily).
WITH key_days AS (
  SELECT product_id, abc_class,
         SUM(DATEDIFF(period_end, period_start) + 1) AS days
  FROM abc_segment
  GROUP BY product_id, abc_class
),
key_main AS (
  SELECT product_id, abc_class AS key_class
  FROM (
    SELECT product_id, abc_class,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY days DESC) AS rn
    FROM key_days
  ) t
  WHERE rn = 1
)
SELECT a.currency,
       a.abc_class_within_currency AS my_class,
       k.key_class,
       COUNT(*) AS products
FROM abc_within_currency a
JOIN key_main k ON k.product_id = a.product_id
GROUP BY a.currency, a.abc_class_within_currency, k.key_class
ORDER BY a.currency, my_class, k.key_class;
