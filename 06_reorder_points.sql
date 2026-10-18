-- 06_reorder_points.sql
-- Purpose (Stage 5): safety stock and reorder point per product.
--   Reorder point  = average daily demand x lead time + safety stock
--   Safety stock   = Z x SQRT( L x sd_demand^2 + demand^2 x sd_lead^2 )
-- Z depends on the service level: A products 98% (Z 2.054), B 95% (Z 1.645), C 90% (Z 1.282).
-- Run one statement at a time (Ctrl+Enter).

USE supply_chain;

-- 1. Product 64 by hand (primary supplier 6, product-level lead time).
-- Inputs: demand 15.27671 (SD 6.424766), lead time 6.8696 days (SD 4.911067), Z 2.054 (98%).
-- Result: demand during lead time 104.94, safety stock 157.94, reorder point 262.88
-- The lead time variation part (5,629) is about 95% of the total variance (5,629 + 284).
WITH inp AS (
  SELECT 15.27671 AS d, 6.424766 AS sd_d, 6.8696 AS L, 4.911067 AS sd_L, 2.054 AS z
)
SELECT
  d * L AS demand_during_lead_time,
  L * POW(sd_d, 2) AS demand_swing_part,
  POW(d, 2) * POW(sd_L, 2) AS lead_time_swing_part,
  z * SQRT(L * POW(sd_d, 2) + POW(d, 2) * POW(sd_L, 2)) AS safety_stock,
  d * L + z * SQRT(L * POW(sd_d, 2) + POW(d, 2) * POW(sd_L, 2)) AS reorder_point
FROM inp;

-- 2. All products, saved as a view (reorder_points) so later queries and the dashboard can reuse it.
-- Returns 120 rows.
-- Demand: daily units over all 365 days (zero-sales days included).
-- Lead time: average and SD per supplier (all purchase lines), for each product's PRIMARY supplier
--   (supplier-level figures are steadier than product-level ones, which can rest on very few orders).
-- Service level: from the within-currency ABC class (view abc_within_currency from 02_abc_analysis.sql).
-- Checks: 120 rows; product 64 avg_daily about 15.28 and sd_daily about 6.42;
--   product 64 will differ slightly from section 1 because it uses supplier-level lead time (6.42 days, SD 4.51).
CREATE OR REPLACE VIEW reorder_points AS
WITH RECURSIVE days AS (
  SELECT DATE('2025-01-01') AS d
  UNION ALL
  SELECT d + INTERVAL 1 DAY FROM days WHERE d < '2025-12-31'
),
daily AS (
  SELECT p.product_id, days.d, COALESCE(SUM(s.qty), 0) AS units
  FROM product p
  CROSS JOIN days
  LEFT JOIN sales s ON s.product_id = p.product_id AND s.order_date = days.d
  GROUP BY p.product_id, days.d
),
demand AS (
  SELECT product_id, AVG(units) AS avg_daily, STDDEV_SAMP(units) AS sd_daily
  FROM daily
  GROUP BY product_id
),
lead_times AS (
  SELECT supplier_id,
         AVG(DATEDIFF(receipt_date, order_date)) AS lead_avg,
         STDDEV_SAMP(DATEDIFF(receipt_date, order_date)) AS lead_sd
  FROM purchasing
  GROUP BY supplier_id
),
base AS (
  SELECT p.product_id, p.is_active, a.currency,
         a.abc_class_within_currency AS abc_class,
         ps.supplier_id AS primary_supplier,
         ps.min_order_qty,
         d.avg_daily, d.sd_daily, l.lead_avg, l.lead_sd,
         CASE a.abc_class_within_currency
           WHEN 'A' THEN 2.054 WHEN 'B' THEN 1.645 ELSE 1.282 END AS z
  FROM product p
  JOIN abc_within_currency a ON a.product_id = p.product_id
  JOIN product_supplier ps ON ps.product_id = p.product_id AND ps.is_primary = 'True'
  JOIN demand d ON d.product_id = p.product_id
  JOIN lead_times l ON l.supplier_id = ps.supplier_id
)
SELECT product_id, is_active, currency, abc_class, primary_supplier,
       avg_daily, sd_daily, lead_avg, lead_sd, z,
       avg_daily * lead_avg AS demand_during_lead_time,
       z * SQRT(lead_avg * POW(sd_daily, 2) + POW(avg_daily, 2) * POW(lead_sd, 2)) AS safety_stock,
       avg_daily * lead_avg
         + z * SQRT(lead_avg * POW(sd_daily, 2) + POW(avg_daily, 2) * POW(lead_sd, 2)) AS reorder_point
FROM base;

-- Look at the view (biggest reorder points first within each class).
SELECT * FROM reorder_points ORDER BY abc_class, reorder_point DESC;

-- 3. Reorder point vs real stock, all products. Exported as reorder_vs_stock.csv for the dashboard.
-- Results (checked on the export): the 33 products with a slow primary supplier (3, 4, 10, 12) average
-- 29.0 days at zero stock, against 3.2 for the other 87; their reorder points are about 42 days of sales
-- against 17. All 10 products with the most stockout days have one of those four suppliers.
-- May take several seconds, because the view rebuilds the daily demand table.
SELECT r.product_id, r.is_active, r.currency, r.abc_class, r.primary_supplier,
  r.avg_daily, r.lead_avg, r.lead_sd,
  r.safety_stock, r.reorder_point,
  r.reorder_point / r.avg_daily AS reorder_point_days_of_sales,
  s.avg_on_hand, s.min_on_hand, s.stockout_days,
  s.days_stock_plus_on_order_below_reorder
FROM reorder_points r
JOIN (
  SELECT ds.product_id,
    AVG(ds.on_hand_qty) AS avg_on_hand,
    MIN(ds.on_hand_qty) AS min_on_hand,
    SUM(ds.on_hand_qty = 0) AS stockout_days,
    SUM(ds.on_hand_qty + ds.in_transit_qty < rp.reorder_point) AS days_stock_plus_on_order_below_reorder
  FROM daily_stock ds
  JOIN reorder_points rp ON rp.product_id = ds.product_id
  GROUP BY ds.product_id
) s ON s.product_id = r.product_id
ORDER BY r.abc_class, s.stockout_days DESC;
