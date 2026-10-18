-- 05_supplier_lead_times.sql
-- Purpose (Stage 4): lead time and fill rate per supplier.
-- Results and conclusions: docs/decision_log.md, Stage 4.
-- Lead time = days from order_date to receipt_date.
-- Fill rate = quantity received / quantity ordered.

USE supply_chain;

-- 1. Check the purchasing dates imported as real dates (format 2025-01-01).
SELECT order_date, receipt_date FROM purchasing LIMIT 3;

-- 2. Supplier scorecard (one row per supplier, 12 rows).
SELECT su.supplier_id, su.supplier_name, su.supplier_country,
  COUNT(*) AS po_lines,
  AVG(DATEDIFF(p.receipt_date, p.order_date)) AS avg_lead_days,
  STDDEV_SAMP(DATEDIFF(p.receipt_date, p.order_date)) AS sd_lead_days,
  MAX(DATEDIFF(p.receipt_date, p.order_date)) AS max_lead_days,
  SUM(p.qty_received) / SUM(p.qty_ordered) AS fill_rate,
  AVG(p.qty_received >= p.qty_ordered) AS share_of_lines_in_full
FROM purchasing p
JOIN supplier su ON su.supplier_id = p.supplier_id
GROUP BY su.supplier_id, su.supplier_name, su.supplier_country
ORDER BY avg_lead_days DESC;

-- 3. Quarterly check for Suppliers X (id 1, "Fast/Exp") and Y (id 2, "Slow/Chp").
-- Result: X is slower than Y in every quarter; X's worst quarter is Q2 (19.2 days, 56% of lines in full).
-- Dec 2024 orders are left out so quarters line up with 2025.
SELECT su.supplier_name, QUARTER(p.order_date) AS qtr,
  COUNT(*) AS po_lines,
  AVG(DATEDIFF(p.receipt_date, p.order_date)) AS avg_lead_days,
  STDDEV_SAMP(DATEDIFF(p.receipt_date, p.order_date)) AS sd_lead_days,
  AVG(p.qty_received >= p.qty_ordered) AS share_in_full
FROM purchasing p
JOIN supplier su ON su.supplier_id = p.supplier_id
WHERE su.supplier_id IN (1, 2)
  AND p.order_date >= '2025-01-01'
GROUP BY su.supplier_name, QUARTER(p.order_date)
ORDER BY su.supplier_name, qtr;

-- 4. Actual vs planned lead time per supplier.
-- Requires the supply_route table (import SUPPLY_ROUTE.csv first).
-- Planned lead time = lead_time_mean_days on the route each order line used.
-- Check: the total of po_lines is 3,159 (no lines lost in the join). Every supplier is 1.5 to 4.7 days slower than planned.
SELECT su.supplier_id, su.supplier_name,
  COUNT(*) AS po_lines,
  AVG(DATEDIFF(p.receipt_date, p.order_date)) AS avg_actual_days,
  AVG(r.lead_time_mean_days) AS avg_planned_days,
  AVG(DATEDIFF(p.receipt_date, p.order_date)) - AVG(r.lead_time_mean_days) AS avg_gap_days,
  AVG(DATEDIFF(p.receipt_date, p.order_date) > r.lead_time_mean_days) AS share_later_than_planned
FROM purchasing p
JOIN supplier su ON su.supplier_id = p.supplier_id
JOIN supply_route r ON r.route_id = p.route_id
GROUP BY su.supplier_id, su.supplier_name
ORDER BY avg_gap_days DESC;
