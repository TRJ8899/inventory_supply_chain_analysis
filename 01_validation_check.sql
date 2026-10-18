-- 01_validation_check.sql
-- Purpose: check that the CSV imports worked and that SQL matches my Excel results.
-- Database: supply_chain (MySQL). Run one statement at a time (Ctrl+Enter).

USE supply_chain;

-- 1. Row counts after import.
-- Expected: product 120, supplier 12, sales 42,204, purchasing 3,159, daily_stock 43,800
SELECT 'product' AS table_name, COUNT(*) AS row_count FROM product
UNION ALL SELECT 'supplier', COUNT(*) FROM supplier
UNION ALL SELECT 'sales', COUNT(*) FROM sales
UNION ALL SELECT 'purchasing', COUNT(*) FROM purchasing
UNION ALL SELECT 'daily_stock', COUNT(*) FROM daily_stock;

-- 2. Look at the first rows and the column types (dates should be a DATE type).
SELECT * FROM sales LIMIT 5;
DESCRIBE sales;

-- 3. Sales lines per currency.
-- Expected: EUR 15,282, TRY 13,807, USD 13,115 (total 42,204)
SELECT sale_currency, COUNT(*) AS lines
FROM sales
GROUP BY sale_currency;

-- 4. Total net revenue in USD.
-- Net revenue = qty * unit_price * (1 - discount_rate), converted to USD.
-- Rates (fixed, Google currency converter, 10 Oct 2026): 1 USD = 0.89 EUR, 1 USD = 49.22 TRY.
-- Expected: about 67,810,606 (Excel gave 67,810,606.49, SQL 67,810,606.46: rounding in the rates)
SELECT SUM(qty * unit_price * (1 - discount_rate) *
  CASE sale_currency
    WHEN 'EUR' THEN 1/0.89
    WHEN 'TRY' THEN 1/49.22
    ELSE 1
  END) AS net_revenue_usd
FROM sales;

-- 5. Revenue per product, largest first.
-- Expected: product 64 on top (about 2,508,647)
SELECT product_id,
  SUM(qty * unit_price * (1 - discount_rate) *
    CASE sale_currency
      WHEN 'EUR' THEN 1/0.89
      WHEN 'TRY' THEN 1/49.22
      ELSE 1
    END) AS net_revenue_usd
FROM sales
GROUP BY product_id
ORDER BY net_revenue_usd DESC;
