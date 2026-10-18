# Inventory and Supplier Analysis

**Which products run out of stock, why, and what should the company do about it?**

A supply chain analytics project in SQL, Excel and Power BI. It is a simulated business case on **synthetic data**, so the results show the method and are not facts about a real company.

**Audience:** inventory planning and procurement leads.

## Executive summary

- **Revenue is concentrated.** 62 of 120 products (class A) bring in 79% of net revenue (67.8 million USD).
- **Four suppliers cause most of the stockouts.** Suppliers 3, 4, 10 and 12 take 15 to 20 days on average, vary by 12 to 14 days, and sometimes take 45. The 33 products they supply averaged about **29 days at zero stock** in 2025, against about **3 days** for the other 87 products.
- **Planned lead times are too optimistic.** Every supplier is 1.5 to 4.7 days slower than planned, on average.
- **Recommendation:** raise reorder points for the 33 affected products (starting with the 18 class A items), ask the four suppliers for steadier deliveries, and plan with actual lead times. Details and trade-offs are below.

## Why this project

Logistics and supply chain analyst roles ask for the same things: stock accuracy and replenishment, supplier performance, and the ability to turn operational data into recommendations using Excel, SQL and Power BI. I built one question that uses all of them: **where is stock short, and what is causing it?**

## Data and how it was pulled

- **Source:** Kaggle, [Supply Chain & ERP Simulation, 365-Day Logistics](https://www.kaggle.com/datasets/umuttuygurr/supply-chain-v2). Synthetic, one warehouse, 2025.
- **Size:** 120 products, 12 suppliers, 42,204 sales lines, 3,159 purchase lines, 43,800 daily stock rows. Prices come in three currencies (EUR, TRY, USD).
- **Pipeline:** downloaded the CSV files, imported them into MySQL (product, sales, purchasing, daily stock, supplier, product-supplier, supply route, and the dataset's own ABC classification used as a cross-check), then validated.
- **Validation:** row counts, currency checks, revenue totals matched between Excel and SQL (within 3 cents, from rounding in the exchange rates), and sanity checks that caught two of my own mistakes (a reversed exchange rate and a date format error). All checks are in `docs/decision_log.md`.

## Method

| Step | What was done | File |
|---|---|---|
| 1. Validate | Row counts, currency counts, revenue total, revenue per product | `sql/01_validation_check.sql` |
| 2. ABC analysis | Rank products by net revenue in USD (A up to 80%, B up to 95%), then rank again within each currency | `sql/02_abc_analysis.sql` |
| 3. Demand | Average and variation of daily sales, including days with no sales | `sql/03_demand_product_64.sql` |
| 4. Cross-check | Compare my classes with the dataset's own | `sql/04_compare_with_abc_key.sql` |
| 5. Suppliers | Lead time, its variation, fill rate, actual vs planned | `sql/05_supplier_lead_times.sql` |
| 6. Reorder points | Safety stock and reorder point for every product, compared with real stock | `sql/06_reorder_points.sql` |

**Reorder point** = average demand during the supplier's lead time + **safety stock**, where safety stock = Z x SQRT( lead time x demand variance + demand squared x lead time variance ). Z reflects the service level: 98% for class A, 95% for class B, 90% for class C.

## Findings

1. **A currency effect distorted the first ranking.** Converted to USD, all 39 lira products fell into class C, because lira prices are numerically similar to euro prices but worth far less. Ranking within each currency fixed it (A 62, B 32, C 26; 37 products changed class). The result matches the dataset's own classification for 110 of 120 products, and all 10 differences are one class apart.
2. **Demand is not the main driver of buffer stock; lead time variation is.** For the top product (64), demand averages 15.3 units a day (standard deviation 6.4). About 95% of the variance behind its safety stock comes from lead time, so a steadier supplier would cut the buffer far more than a better forecast.
3. **Suppliers fall into three groups.** Average lead times range from 5.6 days (Supplier 9) to 20 days (Supplier 3). By quantity every supplier delivers 95 to 99%, but only 81 to 95% of order lines arrive complete. Supplier X, labelled "Fast/Exp", is slower than Supplier Y ("Slow/Chp") in every quarter.
4. **Stockouts follow supplier variability.** Products from the four slow suppliers need about 42 days of sales on hand at reorder, against about 17 for the rest, and ran out about nine times as often. All 10 products with the most stockout days have one of those suppliers, and the pattern holds in each ABC class. The correlation between lead time variation and stockout days is about 0.73. Not every such product ran out, so this is a strong tendency, not a rule, and it does not prove cause.

## Recommendations

| # | Action | Why | How to measure |
|---|---|---|---|
| 1 | Raise reorder points on the 33 products from suppliers 3, 4, 10 and 12, starting with the 18 class A products | They average about 29 days at zero stock against about 3 elsewhere | Days at zero stock per product |
| 2 | Ask those four suppliers for steadier deliveries, and review Supplier X (81% of lines in full, 19 days in Q2) | Their lead time variation drives most of the buffer needed | Lead time standard deviation and share of lines delivered in full, monthly |
| 3 | Plan with actual lead times, not planned ones | Every supplier is 1.5 to 4.7 days slower than planned; Supplier 8's plan is less than half of reality | Gap between actual and planned lead time |
| 4 | Review the scorecard and the reorder points monthly | Supplier behaviour changes through the year | The Power BI dashboard |

**Trade-off:** higher reorder points mean more cash tied up in stock. I have not yet priced this. The first next step is to estimate holding cost from each product's cost and holding cost rate, so the saving from fewer stockouts can be set against it.

## Where the method applies

It needs three inputs: sales history, supplier lead times, and stock levels. Any business that holds stock can use it, for example a grocery retailer replenishing from many suppliers, a field service company stocking parts on trucks, or a distribution centre. The currency lesson transfers too: check the units and currencies before ranking anything.

## Dashboard and slides

Three Power BI pages: which products matter, supplier reliability, and reorder points vs stockouts. The report is `dashboard/inventory_dashboard.pbix`, and the presentation is `inventory_analysis.pptx`.

![Which products matter](dashboard/page1_products.png)
![Supplier reliability](dashboard/page2_suppliers.png)
![Reorder points vs stockouts](dashboard/page3_reorder.png)

## Limitations

- Synthetic data: no real-world conclusions.
- One fixed exchange rate per currency (Google, 10 October 2026). Real rates change.
- Assumes `unit_price` is the price before discount (not confirmed from the data).
- The safety stock formula assumes roughly bell-shaped demand and lead times. Supplier lead times have a long tail, so it may understate the risk of very late deliveries.
- The comparison with real stock uses my formula as a benchmark. The synthetic stock levels may not follow any reorder rule.
- Lead times use supplier-level figures for the full catalogue. Product 64's own orders give a reorder point of 263 units, against 244 from the supplier-level version.

## Next steps

1. Estimate the holding cost of the extra stock the recommendations require.
2. Check lead times by quarter for every supplier (done for X and Y: X's worst quarter is Q2).
3. Repeat the method on a real, messier dataset.

## Repository structure

```
README.md
inventory_analysis.pptx   presentation
sql/                      queries 01 to 06, run in order (02 creates the views the later files use)
docs/decision_log.md      every assumption, check and mistake, stage by stage
dashboard/                Power BI report and page screenshots
```

**To reproduce:** download the dataset from the Kaggle link, import the CSV files into a MySQL 8 database named `supply_chain` (table names in lowercase, e.g. `sales`, `product`), and run the SQL files in order.

## Use of AI

I used AI to explain concepts and to draft queries and formulas. I ran every query myself, checked results by hand and against my Excel work, and recorded the errors I caught in `docs/decision_log.md`. The analysis choices and conclusions are mine.
