# Decision Log: Inventory & Replenishment Project

Dataset: [Supply Chain & ERP Simulation, 365-Day Logistics](https://www.kaggle.com/datasets/umuttuygurr/supply-chain-v2) (Kaggle). **Synthetic data**, 1 year (2025-01-01 to 2025-12-31), one central warehouse.

**Business question:** Which products are at risk of stocking out, why (demand swings, late or partial supplier deliveries), and what reorder levels would improve availability without tying up too much cash in stock?

**AI use statement:** I used AI to explain concepts and to draft Excel formulas and SQL queries. I ran every formula myself, checked results against manual calculations, and recorded errors below. The analysis choices and conclusions are mine.

---

## Data overview (Stage 0)

| File | One row = | Connects through |
|---|---|---|
| product | one product (SKU), 120 rows | product_id |
| sales | one sales order line | product_id, customer_id, channel_id |
| purchasing | one purchase order line to a supplier | product_id, supplier_id, route_id |
| daily_stock | one product on one day (expected 120 x 365 = 43,800 rows) | product_id |
| supplier | one supplier (12) | supplier_id |

- Sales: **42,204 lines**. Products by currency: **EUR 44, TRY 39, USD 37** (total 120).
- Sales lines by currency: EUR 15,282, TRY 13,807, USD 13,115 (total 42,204, nothing missing).
- Purchasing has an order date and a receipt date but **no promised delivery date**. Planned lead time exists per route (lead_time_mean_days, lead_time_std_days in supply_route), so actual vs planned can still be compared.
- `uom` (unit of measure): EA = each, KG = kilograms. **Values found: EA and KG.** Quantities are only summed within one product, never across products.
- The README says some inactive products still have sales rows on purpose. Checked in SQL: 8 of 120 products are inactive and account for 4,354,676 USD of net revenue (about 6.4% of the 67.8 million total). Their revenue per product (about 544,000) is similar to active products (about 567,000), so they are not minor items. Decision: keep them in the ABC analysis, because they did sell in 2025, and flag them as inactive. Observation: all 8 inactive products sold from 1 Jan 2025 until 31 Dec 2025 (one until 16 Dec), with 1,136 to 4,832 units each, so the "inactive" flag does not reflect sales stopping. It is a label in the synthetic data (the README says stale SKUs are included on purpose). Purchasing also kept ordering all 8 products through the year (first orders between Dec 2024 and Jul 2025, last orders between 28 Nov and 31 Dec 2025, 3 to 103 order lines each), so the company treated them as active. Final decision: include them in the Stage 5 reorder-point work like any other product, and keep the inactive flag as a note only. My first plan was to exclude them, but the data did not support that. The flag has no real effect in this dataset.

---

## Validation checks and mistakes caught

| # | Check | Result | Action |
|---|---|---|---|
| 1 | Does each sale use its product's currency? (lookup + COUNTIF of mismatches) | 0 mismatches | Currency is consistent per product; convert once per row |
| 2 | First pivot used Sum of product_id instead of Count | Grand total was 7,260 (the sum 1+2+...+120), not 120 | Switched to Count. Lesson: sanity-check grand totals |
| 3 | Exchange rates entered upside down at first | Total revenue came out in the billions (about 44,900 USD per row vs about 280 in a spot-check row) | Quoted rates "1 USD = x" must be entered as =1/x |
| 4 | Revenue after fixing rates | Gross 75,643,773.84, net 67,810,606.49 | Discounts reduce revenue by about 10.4% |
| 5 | Revenue per row by currency | EUR about 2,679, USD about 1,991, TRY about 55 | TRY looked far too small, so investigated (next row) |
| 6 | Average price and quantity by currency | Avg unit price: EUR 283, TRY 332, USD 268. Avg qty about 8-9 in all three | Lira prices are numerically similar to euro prices, so after conversion TRY is about 1.1% of revenue. Likely a data-generation quirk, not a formula error |

---

## Assumptions

- **Revenue used:** net = qty x unit_price x (1 - discount_rate) x rate to USD. Assumption: unit_price is the price before discount (not confirmed from the data).
- **Exchange rates (fixed, one per currency):** 1 USD = 49.22 TRY and 1 USD = 0.89 EUR. Source: Google currency converter. Date retrieved: 10 October 2026. Real rates move over time, so this is a simplification.
- **ABC cut-offs:** A = cumulative share up to 80%, B up to 95%, C the rest. A product that crosses a cut-off can land in the lower class.
- Synthetic data: findings are practice results, not facts about a real company. The README notes that the link between discount and quantity is weak, so I will not draw pricing conclusions.

---

## Stage 1: ABC analysis

**ABC analysis in my own words:** ABC analysis ranks products by the revenue they bring in and splits them into three groups: A products make up the first 80% of revenue, B the next 15%, and C the rest. A company uses it to decide where to focus attention, because running out of an A product costs far more than running out of a C product. A products get tighter monitoring and larger safety stock; C products get simpler rules.

**Version 1, ranked across all products (USD):**

| Class | Products |
|---|---|
| A | 42 |
| B | 24 |
| C | 54 |

- 39 of the 54 class C products were lira products. In fact **all 39 lira products** fell into C. The classes were measuring currency level, not product importance.

**Version 2, ranked within each currency:**

| Currency | A | B | C | Total |
|---|---|---|---|---|
| EUR | 21 | 12 | 11 | 44 |
| TRY | 21 | 10 | 8 | 39 |
| USD | 20 | 10 | 7 | 37 |
| **All** | **62** | **32** | **26** | **120** |

- **37 of 120 products changed class** between versions (formula: SUMPRODUCT comparing the two class columns). Most are likely lira products moving up. To confirm: filter changed products by currency.
- Observation: about half of all products (62 of 120) are class A, so revenue is spread fairly evenly across products. Real data would usually show a sharper split. Likely a feature of the synthetic data.
- **Classification used for service levels in Stage 5:** the within-currency classes. Reason: they show each product's importance among comparable products, whereas the overall classes would give every lira product a low priority purely because of the currency. The overall version stays as the company-wide revenue view.

**Comparison with the dataset's answer key (`abc_segment_v22`):**

The key gives a class per product per period (267 rows, not 120 x 12): each row is a stretch of time during which a product stayed in one class, and 80 products keep one class all year. I imported it into MySQL and compared my within-currency class with each product's main class in the key (the class it spent the most days in).

| Currency | Products | Same class | Different |
|---|---|---|---|
| EUR | 44 | 42 | 2 |
| TRY | 39 | 34 | 5 |
| USD | 37 | 34 | 3 |
| **Total** | **120** | **110 (92%)** | **10** |

- All 10 differences are one class apart (A vs B, or B vs C). None is A vs C, so the two versions agree on which products matter.
- My top 18 products are all class A all year in the key, including product 64.
- The lira products agree with the key (21 are A in both). The key does not push lira products into C the way my first USD-converted ranking did, which supports ranking within each currency.
- The 5 TRY differences all go the same way (the key ranks them higher: 3 of my B are A in the key, 2 of my C are B). Possible reasons: different cut-offs, or a monthly versus yearly ranking. Not confirmed.
- Caveat: products that change class during the year, or tie between two classes, can look like disagreements.

---

## Mistakes made by the AI and caught during the work

- AI said the currencies looked inconsistent between product and purchasing rows. It had compared two different products. Corrected after checking the README.
- AI said "nearly all" lira products were in class C. The pivot showed all 39.

---

## Stage 2: Demand for one product

**Product studied:** product_id 64, the top product by net revenue. Currency: EUR. Unit of measure: EA (each), so "units" means items.

**Method:**
- Listed all 365 dates of 2025 in one column (a real calendar, not invented data). A pivot would skip days with no sales, and those days count as demand of zero. Leaving them out would make the average too high.
- Daily units per date: `=SUMIFS(sales!F:F, sales!B:B, 64, sales!E:E, A2)`. In words: add up quantity for product 64 on this date, 0 if nothing matched.
- Average: `=AVERAGE(B2:B366)`. Standard deviation: `=STDEV.S(B2:B366)`. Zero days: `=COUNTIF(B2:B366,0)`.

**Results:**

| Measure | Value |
|---|---|
| Average daily demand | about 15.28 units |
| Standard deviation | about 6.42 units |
| SD as a share of the average | about 42% |
| Days with zero sales | 6 of 365 |

- Rough range: most days fall between about 9 and 22 units (average plus or minus one SD).
- Total units for the year implied by the average: about 5,576 (15.28 x 365).

**Validation:**
- Confirmed in SQL: total units for product 64 are 5,576 (15.2767 x 365), so the Excel daily column adds up correctly.
- The implied yearly total is a whole number, which is what real unit counts should give.

**What I learned, in my own words:** `SUMIFS` adds up a column only for the rows that meet my conditions (here, product 64 and a given date), and returns 0 when nothing matches. The standard deviation shows how much daily sales swing around the average. A product whose sales swing a lot needs more buffer stock, because safety stock covers the days when sales run above average while I am still waiting for a delivery.

**Self-check (SD vs average):** average 20 with SD 2 is steady (SD is 10% of the average). Average 20 with SD 15 is jumpy (SD is 75%). Product 64 sits in between at about 42%, so I would call it moderately jumpy.

**Takeaway for Stage 5:** the average tells me how fast stock is used up, and the standard deviation decides how large the safety buffer needs to be.

---

## Stage 3: Redo the analysis in SQL (MySQL)

**Goal:** reproduce my Excel results with SQL, so each number is verified a second way.

**Setup:**
- Tool: MySQL (Workbench). Created database `supply_chain` and imported the original CSV files (not my edited Excel workbook): product, supplier, sales, purchasing, daily_stock.
- Row counts after import: product 120, supplier 12, sales 42,204, purchasing 3,159, daily_stock 43,800. All match the source CSV files (purchasing checked: the file has 3,160 rows including the header). Purchasing has fewer lines than the Kaggle description suggested, probably because this is a newer version of the dataset.
- MySQL imported the date columns as real dates (format 2025-01-01).

**Queries and results (SQL vs Excel):**

| Check | SQL result | Excel result | Match? |
|---|---|---|---|
| Sales lines per currency | EUR 15,282 / TRY 13,807 / USD 13,115 | same | Yes |
| Total net revenue (USD) | 67,810,606.46 | 67,810,606.49 | Yes, 3 cents apart (SQL uses exact rates 1/0.89 and 1/49.22; Excel used rounded rates) |
| Top product by revenue | product 64 (2,508,647) | product 64 | Yes |
| ABC classes, ranked across all products | A 42 / B 24 / C 54 | A 42 / B 24 / C 54 | Yes |
| ABC classes, ranked within each currency | EUR 21/12/11, TRY 21/10/8, USD 20/10/7 | same | Yes (my Excel workbook was lost, so I rebuilt this one in SQL and checked it against my earlier Excel pivot) |
| Product 64 average daily demand | 15.2767 | 15.27671 | Yes |
| Product 64 standard deviation | 6.4248 | 6.424766 | Yes |
| Product 64 zero-sales days | 6 | 6 | Yes |
| Product 64 total units in 2025 | 5,576 | not checked in Excel at the time | Now confirmed: 15.2767 x 365 = 5,576, so the Excel daily column adds up correctly |

**SQL techniques used (in my own words, fill in):**
- `GROUP BY` with `COUNT` and `SUM`: splits the rows into groups (by currency or product) and calculates one number per group. It is the SQL version of a pivot table.
- `CASE` for the exchange rate by currency: an if-then rule inside a query that picks the right rate for each row.
- A **view** (`product_revenue`): a saved query that can be used like a table, so later queries do not repeat the long revenue formula.
- Window functions (`SUM() OVER`): calculate across rows while keeping every row. `SUM() OVER ()` gives the total used for each product's share, `SUM() OVER (ORDER BY ... DESC)` gives the running total, and `PARTITION BY currency` restarts the calculation inside each currency.
- `LEFT JOIN` onto a list of all 365 dates: keeps every day, including days with no sales, and `COALESCE` turns the missing values into 0. Without it, the average demand would be too high.

**Mistakes and lessons:**
- When I pasted two statements and pressed Ctrl+Enter, only the statement under the cursor ran, so the second query seemed to do nothing. Fix: run one statement at a time, or select it first.
- My first demand query returned 365 zero days. Cause: it tried to convert dates that MySQL had already imported as real dates, so nothing matched. I knew it was wrong because a top product cannot sell nothing every day. Fix: compare the date column directly. Lesson: a result that is impossible is a signal to check the query, not the data.

**Conclusion:** SQL reproduced every Excel result, so the workflow is verified and I can use SQL to repeat the demand calculation for all 120 products later.

**Files saved (in `sql/`):**
- `01_validation_check.sql`: row counts, currency counts, revenue total, revenue per product
- `02_abc_analysis.sql`: the `product_revenue` and `abc_within_currency` views, overall and within-currency ABC with class counts
- `03_demand_product_64.sql`: daily demand for product 64
- `04_compare_with_abc_key.sql`: comparison with the answer key
- `05_supplier_lead_times.sql`: supplier scorecard, quarterly check for Suppliers X and Y, and actual vs planned lead time
- `06_reorder_points.sql`: reorder point and safety stock for product 64, the `reorder_points` view for all products, and the comparison with real stock

**Other lessons from this stage:**
- My Excel workbook was never saved, so I lost it. SQL reproduced every result, so nothing was lost, but from now on I save scripts and files after each stage and commit them to GitHub. The Excel file is not needed in the repo: the SQL files, dashboard and README are what matter.
- A query seemed to do nothing because the table was imported under a misspelled name (`abc_segement_v22` instead of `abc_segment`). Lesson: read the Output panel and check table names with `SHOW TABLES`.

---

## Stage 4: Supplier lead times

**Question:** when the company orders from a supplier, how long does it wait, how much does the wait vary, and does the full quantity arrive? Lead time is the second input (after demand) for reorder points in Stage 5.

**Definitions:** lead time = receipt_date minus order_date, in days. Fill rate = quantity received / quantity ordered. "Lines in full" = share of order lines where quantity received >= quantity ordered.

**Check:** the supplier lines add up to 3,159, the same as the purchasing table, so the join lost nothing. Dates in `purchasing` imported as real dates.

**Supplier scorecard (full year, 12 suppliers, query in `sql/05_supplier_lead_times.sql`):**

| Supplier | Country | Lines | Avg lead (days) | SD | Max | Fill rate | Lines in full |
|---|---|---|---|---|---|---|---|
| 3 | South Korea | 199 | 19.96 | 12.64 | 44 | 99.3% | 95.0% |
| 4 | Japan | 264 | 19.84 | 13.62 | 45 | 97.6% | 91.3% |
| 10 | China | 364 | 17.56 | 13.60 | 44 | 96.2% | 90.1% |
| 12 | USA | 247 | 15.23 | 12.35 | 45 | 98.1% | 91.9% |
| X (Fast/Exp) | China | 132 | 14.30 | 7.12 | 30 | 95.3% | 81.1% |
| Y (Slow/Chp) | Vietnam | 425 | 10.24 | 6.00 | 27 | 97.7% | 90.1% |
| 7 | Italy | 285 | 7.81 | 5.42 | 25 | 96.1% | 88.4% |
| 11 | Germany | 393 | 7.71 | 4.61 | 28 | 97.4% | 90.6% |
| 8 | USA | 187 | 7.40 | 4.34 | 24 | 97.0% | 90.4% |
| 5 | Germany | 212 | 6.82 | 4.49 | 23 | 97.7% | 89.6% |
| 6 | Germany | 157 | 6.42 | 4.51 | 25 | 95.8% | 85.4% |
| 9 | Turkey | 294 | 5.62 | 3.33 | 22 | 96.5% | 88.1% |

**Findings:**
- Lead times fall into three groups. Four suppliers (3, 4, 10, 12) average 15 to 20 days with an SD of 12 to 14 days and maximum waits of 44 to 45 days. Suppliers X and Y are in the middle (10 to 14 days, SD 6 to 7). Six suppliers average 5.6 to 7.8 days with an SD of 3.3 to 5.4.
- By quantity every supplier delivers 95 to 99%, but only 81 to 95% of order lines arrive complete: shortfalls are small but frequent. Supplier X is weakest (81% of lines in full), then Supplier 6 (85%).
- The labels "Fast/Exp" (X) and "Slow/Chp" (Y) do not match the data: over the full year X averages 14.3 days against 10.2 for Y.

**Quarterly check, Suppliers X and Y (2025 orders only):**

| | Q1 | Q2 | Q3 | Q4 |
|---|---|---|---|---|
| X avg lead (days) | 14.5 | 19.2 | 10.2 | 11.7 |
| Y avg lead (days) | 13.2 | 10.7 | 5.6 | 11.3 |
| X lines in full | 93% | 56% | 82% | 97% |
| Y lines in full | 86% | 89% | 88% | 96% |

- X is slower than Y in every quarter, so the labels do not hold in any quarter. X's worst quarter is Q2 (19.2 days, only 56% of lines in full), which is consistent with the README's Q2 capacity constraints and partial deliveries. Both improve in Q3 and get worse in Q4 (README: route changes in Q3, extreme weather in Q4). I connected these to the README myself, so it is a likely explanation, not proof.
- Caution: X has only 28 to 36 lines per quarter, so its quarterly numbers are noisy.

**Actual vs planned lead time (planned = lead_time_mean_days on the route each order used):**

| Supplier | Lines | Actual (days) | Planned (days) | Gap | Lines later than planned |
|---|---|---|---|---|---|
| X | 132 | 14.30 | 9.60 | +4.70 | 59% |
| 8 | 187 | 7.40 | 3.51 | +3.89 | 73% |
| 12 | 247 | 15.23 | 11.59 | +3.64 | 70% |
| 6 | 157 | 6.42 | 3.55 | +2.87 | 51% |
| 7 | 285 | 7.81 | 4.96 | +2.85 | 51% |
| 5 | 212 | 6.82 | 4.41 | +2.41 | 46% |
| 10 | 364 | 17.56 | 15.22 | +2.34 | 48% |
| 3 | 199 | 19.96 | 17.69 | +2.27 | 49% |
| 11 | 393 | 7.71 | 5.46 | +2.25 | 48% |
| 4 | 264 | 19.84 | 17.68 | +2.16 | 47% |
| 9 | 294 | 5.62 | 3.50 | +2.12 | 45% |
| Y | 425 | 10.24 | 8.77 | +1.47 | 48% |

- Every supplier is slower than planned on average, by 1.5 to 4.7 days. Planned lead times are optimistic.
- The gap is largest for X (+4.7 days) and for suppliers 8 and 12 (70 to 73% of lines later than planned). In relative terms Supplier 8 is the worst: planned 3.5 days, actual 7.4 (more than double).
- For several suppliers fewer than half of the lines are late even though the average gap is positive (for example Supplier 9: +2.1 days, 45% late). That points to a long tail: most deliveries are close to plan, and a few very late ones pull the average up. The README says lead times are modelled as right-skewed, which fits. Possible cause of the positive gaps: the README says weather and events add 2 to 7 days on top of the planned lead time. Not confirmed.

**Decision for Stage 5:** use the actual lead time average and SD from `purchasing`, not the planned lead time, because the plan understates real waits. The SD matters as much as the average: a product from Supplier 4 (SD about 14 days) needs a much larger buffer than one from Supplier 9 (SD about 3 days) even with the same demand.

**Files:** `sql/05_supplier_lead_times.sql` holds the scorecard, the quarterly check and the planned-vs-actual query.

**Stage 4 conclusion:** Suppliers 3, 4, 10 and 12 are the riskiest: average lead times of 15 to 20 days, a standard deviation of 12 to 14 days, and waits of up to 45 days. Safety stock grows with lead time variation, so products from these suppliers need much larger buffers (about 42 days of sales at reorder, against about 17 for the rest). They are also the products that ran out most often (Stage 5).

---

## Stage 5: Safety stock and reorder points

**Goal:** decide when to reorder each product. Reorder point = average demand during the wait + safety stock.
- Safety stock = Z x SQRT( L x sd_demand^2 + demand^2 x sd_lead^2 ), where L is the average lead time in days.
- Service level by within-currency ABC class: A 98% (Z 2.054), B 95% (Z 1.645), C 90% (Z 1.282). Reason: a stockout costs most on the products that matter most.
- Lead time inputs are actual, not planned (Stage 4 decision).

**Worked example, product 64** (class A, EUR; primary supplier 6 with 23 of its 27 purchase lines; backup Supplier 9 ignored because it rests on 4 orders):

| Input | Value |
|---|---|
| Average daily demand / SD | 15.28 / 6.42 units |
| Lead time (Supplier 6, product-level) / SD | 6.87 / 4.91 days |
| Demand during the wait | 105 units |
| Safety stock (98%) | 158 units |
| **Reorder point** | **263 units** |

- About 95% of the variance behind the safety stock comes from lead time (5,629) and only about 5% from demand (284). For this product, a steadier supplier would reduce the buffer far more than a better forecast. Setting the lead time SD to 1 day would cut safety stock from about 158 to about 47 (a what-if run).
- Check against real stock: product 64 had 0 days at zero stock in 2025. On-hand stock fell below 263 on 92 days, but stock plus orders already on the way never did. Lowest on-hand stock 51, average 334, highest 825.

**All 120 products** (`reorder_points` view): demand for each product over all 365 days, and lead time average and SD per primary supplier (supplier-level figures, because product-level ones can rest on very few orders). Product 64 comes out at 243.6 in this version (supplier-level lead time 6.42 days, SD 4.51) instead of 263.

**Comparison with real stock** (`daily_stock`), 120 products:

| | 33 products with a slow primary supplier (3, 4, 10, 12) | 87 other products |
|---|---|---|
| Average days at zero stock | 29.0 | 3.2 |
| Reorder point, in days of sales | about 42 | about 17 |

- 61 of 120 products had at least one stockout day, and 1,238 stockout days in total.
- The 10 products with the most stockout days all have a slow primary supplier. Six of them are class A (14, 90, 100, 24, 23, 6).
- The pattern holds in every class: class A slow-supplier products averaged about 30 days at zero stock (18 products) against about 3 for the other 44.
- Correlation between lead time SD and stockout days: about 0.73.
- Caveats: this is an association, not proof of cause. Some slow-supplier products had no stockouts. The formula is a benchmark, and the stock levels in a synthetic dataset may not follow any reorder rule.

**Mistakes and lessons:**
- My first all-products query failed because `lead` is a reserved word in MySQL 8. Renamed the table expression to `lead_times`.
- Two CSV exports were saved under each other's names. I caught it by checking the column names before loading them.

**Files:** `sql/06_reorder_points.sql`.

---

## Stage 6: Dashboard and slides

- Power BI report with three pages: which products matter, supplier reliability, and reorder points vs stockouts. Built from three CSV exports (`reorder_vs_stock`, `supplier_scorecard`, `abc_classes`), linked by product and supplier IDs, with a `Supplier group` column (slow suppliers 3, 4, 10, 12 vs the rest).
- Every dashboard figure was checked against SQL: 120 products, 67.8 million net revenue, 1,238 stockout days, 3,159 purchase lines, 61 products with a stockout, class counts per currency, and weakest delivery completeness of 81.1%.
- Lessons: my first `Supplier group` formula was created as a measure instead of a column and failed (a measure needs an aggregation). Cards show 1.238K for 1,238, which is the same number abbreviated.
- Slides: `inventory_analysis.pptx`. Files: `dashboard/inventory_dashboard.pbix` and three page screenshots.

---

## Open items and next steps

1. Estimate the holding cost of the extra stock that the recommendations require (needs each product's cost and holding cost rate from the `product` table).
2. Check lead times by quarter for every supplier, not only Suppliers X and Y.
3. Repeat the method on a real, messier dataset.
4. Look at customer churn separately: the sales data has customer IDs, so customers who stopped ordering could be analysed. Not part of this project.
