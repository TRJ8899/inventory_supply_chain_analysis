-- 03_demand_product_64.sql
-- Purpose: average daily demand and variability for my top product (64), over all 365 days of 2025.
-- A calendar of all dates is joined to sales so days with no sales count as 0.
-- Note: order_date was imported as a real DATE, so no STR_TO_DATE is needed
-- (my first version used STR_TO_DATE and returned 365 zero days).

USE supply_chain;

-- Expected (matches Excel): avg_daily 15.2767, sd_daily 6.4248, zero_days 6, total_units 5,576
WITH RECURSIVE days AS (
  SELECT DATE('2025-01-01') AS d
  UNION ALL
  SELECT d + INTERVAL 1 DAY FROM days WHERE d < '2025-12-31'
),
daily AS (
  SELECT days.d, COALESCE(SUM(s.qty), 0) AS units
  FROM days
  LEFT JOIN sales s
    ON s.product_id = 64
   AND s.order_date = days.d
  GROUP BY days.d
)
SELECT AVG(units) AS avg_daily,
       STDDEV_SAMP(units) AS sd_daily,
       SUM(units = 0) AS zero_days,
       SUM(units) AS total_units
FROM daily;
