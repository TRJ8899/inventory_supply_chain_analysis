-- 02_abc_analysis.sql
-- Purpose: ABC analysis in SQL, first across all products, then within each currency.
-- Run one statement at a time (Ctrl+Enter). Run the views first, in this order.

USE supply_chain;

-- 1. View: net revenue per product in USD (used by everything below).
CREATE OR REPLACE VIEW product_revenue AS
SELECT product_id,
  SUM(qty * unit_price * (1 - discount_rate) *
    CASE sale_currency
      WHEN 'EUR' THEN 1/0.89
      WHEN 'TRY' THEN 1/49.22
      ELSE 1
    END) AS net_revenue_usd
FROM sales
GROUP BY product_id;

-- Quick check: should show 5 products with revenue.
SELECT * FROM product_revenue LIMIT 5;

-- 2. ABC across all products (cut-offs: A up to 80%, B up to 95%, C the rest).
-- Expected: top product 64 in class A.
WITH shares AS (
  SELECT product_id, net_revenue_usd,
    net_revenue_usd / SUM(net_revenue_usd) OVER () AS revenue_share
  FROM product_revenue
),
running AS (
  SELECT product_id, net_revenue_usd, revenue_share,
    SUM(revenue_share) OVER (ORDER BY net_revenue_usd DESC) AS cumulative_share
  FROM shares
)
SELECT product_id, net_revenue_usd, revenue_share, cumulative_share,
  CASE WHEN cumulative_share <= 0.8 THEN 'A'
       WHEN cumulative_share <= 0.95 THEN 'B'
       ELSE 'C' END AS abc_class
FROM running
ORDER BY net_revenue_usd DESC;

-- 3. Count of products per class (overall).
-- Expected: A 42, B 24, C 54 (matches Excel)
WITH shares AS (
  SELECT product_id, net_revenue_usd,
    net_revenue_usd / SUM(net_revenue_usd) OVER () AS revenue_share
  FROM product_revenue
),
running AS (
  SELECT product_id, net_revenue_usd, revenue_share,
    SUM(revenue_share) OVER (ORDER BY net_revenue_usd DESC) AS cumulative_share
  FROM shares
)
SELECT abc_class, COUNT(*) AS products
FROM (
  SELECT CASE WHEN cumulative_share <= 0.8 THEN 'A'
              WHEN cumulative_share <= 0.95 THEN 'B'
              ELSE 'C' END AS abc_class
  FROM running
) t
GROUP BY abc_class;

-- 4. View: ABC within each currency.
-- Why: after conversion to USD every lira product fell into class C (a currency effect),
-- so each product is ranked only against products of its own currency.
CREATE OR REPLACE VIEW abc_within_currency AS
WITH rev AS (
  SELECT p.product_id, p.pro_currency AS currency, pr.net_revenue_usd
  FROM product_revenue pr
  JOIN product p ON p.product_id = pr.product_id
),
shares AS (
  SELECT product_id, currency, net_revenue_usd,
    net_revenue_usd / SUM(net_revenue_usd) OVER (PARTITION BY currency) AS share_in_currency
  FROM rev
),
running AS (
  SELECT product_id, currency, net_revenue_usd, share_in_currency,
    SUM(share_in_currency) OVER (PARTITION BY currency ORDER BY net_revenue_usd DESC) AS cumulative_in_currency
  FROM shares
)
SELECT product_id, currency, net_revenue_usd, share_in_currency, cumulative_in_currency,
  CASE WHEN cumulative_in_currency <= 0.8 THEN 'A'
       WHEN cumulative_in_currency <= 0.95 THEN 'B'
       ELSE 'C' END AS abc_class_within_currency
FROM running;

-- 5. Count per currency and class (within currency).
-- Expected: EUR 21/12/11, TRY 21/10/8, USD 20/10/7 (matches Excel)
SELECT currency, abc_class_within_currency, COUNT(*) AS products
FROM abc_within_currency
GROUP BY currency, abc_class_within_currency
ORDER BY currency, abc_class_within_currency;
