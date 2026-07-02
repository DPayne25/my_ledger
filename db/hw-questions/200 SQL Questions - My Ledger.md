# 200 SQL Questions — Budgeting Database

A practice set for handwriting Postgres queries against your budgeting schema. Questions ladder from descriptive to prescriptive. They are deliberately written to push you toward **views, CTEs, and window functions** — not one-line SELECTs.

---

## Schema Reference

### `users`

|Column|Purpose|
|---|---|
|`id`|PK|
|`username`, `email`|identity|
|`logged_at`|row created timestamp|

### `accounts`

|Column|Purpose|
|---|---|
|`id`|PK|
|`users_id`|FK → users|
|`account_name`, `bank_name`, `account_number`|display + identification|
|`account_type`|ENUM: `checking`, `savings`, `credit`|
|`current_balance`|Plaid's reported balance (settled view)|
|`available_balance`|What you can actually spend right now (current minus holds)|
|`plaid_account_id`|external Plaid ref|
|`last_synced_at`|last Plaid pull — staleness indicator|

> **Key idea:** `current_balance - available_balance` ≈ float / pending holds. Watch this gap.

### `categories`

|Column|Purpose|
|---|---|
|`id`|PK|
|`category_name`|unique label|
|`parent_id`|self-FK → categories.id; NULL means top-level|

Top-level (parent_id IS NULL): `needs` (id 1), `savings` (id 2), `wants` (id 3), `investing` (id 4). Everything else is a child.

> **Key idea:** This is a 2-level hierarchy. You'll mostly aggregate child spend up to parent. **Recursive CTEs** are overkill but elegant if you ever go 3+ levels deep.

### `transactions`

|Column|Purpose|
|---|---|
|`id`|PK|
|`users_id`, `account_id`, `category_id`|FKs|
|`plaid_transaction_id`|external ref, unique|
|`merchant_name`|string from Plaid|
|`amount`|NUMERIC(11,2). **Sign convention matters** — confirm whether spend is positive or negative in your Plaid feed before writing queries|
|`transaction_date`|when it happened|
|`transaction_description`|freeform|
|`is_manual`|TRUE = you typed it in, not Plaid|
|`logged_at`|row created|

### `pending_transactions`

|Column|Purpose|
|---|---|
|`amount`|what Plaid first reported as pending|
|`amount_hold`|what's actually held against your available balance|
|`amount_settled`|NULL until settlement; then the final amount|
|`is_settled`, `settled_at`|settlement state|

> **Key idea:** The three amounts can differ — auth $20, hold $25, settle $18.47 (e.g., gas pumps, restaurant tips). Comparing them surfaces float risk.

### `budgets`

|Column|Purpose|
|---|---|
|`budget_month`|first of month (enforced by CHECK constraint)|
|`category_id`|what you're budgeting for|
|`amount_planned`|the target|

> **Key idea:** `amount_spent` is **not stored** — you compute it by joining to `transactions` filtered to that month and category.

### `account_transfers`

|Column|Purpose|
|---|---|
|`source_account_id`, `target_account_id`|both FK → accounts|
|`amount_transferred`|CHECK > 0|
|`transfer_date`|when|

> **Key idea:** Transfers are not transactions. Don't double-count. When computing income/spend from `transactions`, you may also want to net out transfer-shaped activity that leaked into the transactions table.

---

## Postgres Techniques You'll Reach For

Most of these 200 questions are unanswerable with `SELECT … WHERE … GROUP BY` alone. Bookmark these:

- **CTEs (`WITH`)** — multi-step queries: https://www.postgresql.org/docs/current/queries-with.html
- **Window functions** — running totals, rolling averages, rank, lag/lead: https://www.postgresql.org/docs/current/tutorial-window.html
- **Date/time functions** (`DATE_TRUNC`, `EXTRACT`, `AGE`, intervals): https://www.postgresql.org/docs/current/functions-datetime.html
- **Aggregates + `FILTER` clause** — conditional aggregates without CASE: https://www.postgresql.org/docs/current/sql-expressions.html#SYNTAX-AGGREGATES
- **`generate_series`** — for filling date gaps, zero-spend days: https://www.postgresql.org/docs/current/functions-srf.html
- **`LATERAL` joins** — per-row subqueries (e.g., "for each merchant, get last 3 txns"): https://www.postgresql.org/docs/current/queries-table-expressions.html#QUERIES-LATERAL
- **Recursive CTEs** — hierarchical category walks: https://www.postgresql.org/docs/current/queries-with.html#QUERIES-WITH-RECURSIVE
- **Percentile / ordered-set aggregates** (`PERCENTILE_CONT`, `MODE`): https://www.postgresql.org/docs/current/functions-aggregate.html#FUNCTIONS-ORDEREDSET-TABLE
- **`COALESCE`, `NULLIF`, `GREATEST`, `LEAST`**: https://www.postgresql.org/docs/current/functions-conditional.html
- **Views and materialized views** — many of these belong in views: https://www.postgresql.org/docs/current/sql-createview.html · https://www.postgresql.org/docs/current/sql-creatematerializedview.html

When a question feels impossible: it's probably a window function or a `generate_series` + LEFT JOIN.

---

## The 200 Questions

### A. Cash Position & Liquidity Snapshot (1–10)

1. Total liquid balance right now across all `checking` and `savings` accounts.
2. Total `current_balance` vs total `available_balance` across all accounts — what's the gap, and what does that gap represent?
3. Per account, the gap between `current_balance` and `available_balance`, joined to the pending transactions that explain it.
4. Each account's share of total net liquid worth as a percentage.
5. Accounts whose `last_synced_at` is older than 24 hours (stale-data risk before you trust any dashboard).
6. Total assets (checking + savings) minus total credit liabilities (sum of credit `current_balance`) — true net liquid position.
7. Total available balance minus all unsettled `amount_hold` — your "actually-actually" spendable cash.
8. Accounts whose available balance is below a threshold you define (e.g., $100) — overdraft risk list.
9. Ratio of total savings to total checking — am I parking too much in zero-yield checking?
10. For each credit account, current balance trend over the last 90 days (are you carrying or paying off?).

### B. Burn Rate & Days of Sovereign Runway (11–25)

11. Average daily burn from `needs` categories only, last 30 days.
12. Average daily burn across all categories, last 90 days.
13. Given current liquid balance, days of `needs`-only runway remaining.
14. Days of total-spend runway (needs + wants) at current liquidity.
15. Standard deviation of daily total spend, last 90 days — how volatile is your burn?
16. Largest single-day spend in the last 90 days; express it as a multiple of your average daily burn.
17. Median daily spend vs mean daily spend, last 90 days (gap signals spike-distortion).
18. Bare-survival daily burn rate = (avg monthly rent + light + groceries) / 30.
19. Count of zero-spend days in the last 90 days.
20. Trend of weekly total burn over the last 12 weeks — slope direction.
21. Steady-state daily burn after trimming the top 5% largest transactions (outlier-robust).
22. Days until current available balance hits zero at your trailing 30-day burn rate.
23. Seasonal burn — average daily spend bucketed by calendar month, last 24 months.
24. Weekday vs weekend daily burn rates side by side.
25. Project total spend for the rest of the current calendar month from month-to-date pace.

### C. Bill Runway / Inverse Buffer Tracking (26–40)

26. Average monthly spend per `needs` child category over the last 6 months — your 1-month baseline.
27. What 3 months of pre-paid needs costs, broken down by category.
28. For each recurring bill merchant (rent, light, phone, insurance), the most recent payment amount, the trailing-6-month average, and the variance.
29. For each needs category, estimated "days ahead" — last payment amount divided by daily proration of monthly cost.
30. Your monthly fixed nut — sum of trailing 3-month averages for rent + light + phone + insurance.
31. Variance in `light` (utility) bills by quarter — are seasonal spikes predictable enough to pre-fund?
32. Lump sum needed today to push each needs category to a 90-day pre-paid state.
33. Of all needs spending in the last 12 months, % that was fixed recurring vs variable (groceries, gas, medical).
34. Months where a needs category received a payment ≥ 2× its trailing average (lump-sum / inverse buffer evidence).
35. Peak single-month needs total in last 12 months, with the categories that drove the spike.
36. Your true monthly liability floor — minimum required across needs even in austerity mode (rent + light + phone + insurance + base groceries).
37. Last 3 months of needs spend side by side — is the floor stable or drifting up?
38. For each needs category, the median number of days between successive payments (validates billing cycle).
39. Needs payments unusually high vs that merchant's historical average (z-score > 2).
40. If 100% of last-90-days' wants spend had been redirected to needs prepayment, how many days of buffer would that have purchased?

### D. Income vs Spending Flow (41–55)

41. Total inflow per month, last 12 months. (First decide: how do you identify income — positive amounts? specific merchant patterns? `is_manual`?)
42. Month-over-month income variance — coefficient of variation.
43. Net cash flow per month (income − all spending) for the last 12 months.
44. Months that ran a deficit, and the deficit amount.
45. Average days between a payday inflow and the next 5 largest outflows.
46. Savings rate per month = (income − spending) / income.
47. Needs-to-income ratio per month.
48. Wants-to-income ratio per month.
49. Investing-to-income ratio per month.
50. Classify each of the last 12 months as `surplus`, `break-even`, or `deficit` and count each.
51. Linear trend of net monthly cash flow over the last 12 months — slope and sign.
52. Of surplus dollars in surplus months, how many were actually moved to savings/investing accounts via transfers vs left sitting in checking.
53. Top 5 largest individual inflows in the last 12 months — what one-off boosts did you get?
54. Hypothetical balance if every surplus dollar had been transferred to savings — vs reality.
55. By pay period (assume biweekly anchored on a date you pick), what % of net inflow survived until the next pay period.

### E. Budget Variance: Planned vs Actual (56–75)

56. For the current month and each budgeted category: `amount_planned`, `amount_spent`, dollar variance, % variance.
57. Categories over budget this month — sorted by dollar overrun.
58. Categories under budget this month — sorted by unused dollars (reallocation candidates).
59. Categories over budget in ≥4 of the last 6 months — chronic overspend list.
60. Categories under budget in ≥4 of the last 6 months — chronic overestimate list.
61. Average dollar variance per category over the last 12 months.
62. Average absolute % variance per category — your forecasting error per category.
63. For each category, the median day-of-month at which 50% of the monthly budget is consumed.
64. For each category, the median day-of-month at which 100% of the monthly budget is exceeded.
65. Total dollars under budget (planned but unspent) across the last 12 months.
66. Total dollars over budget (spent above plan) across the last 12 months.
67. For categories with no budget set this month, suggest one = trailing 3-month average of actual spend.
68. Months with smallest aggregate absolute variance — your most accurate budgeting months.
69. % of months in the last 12 each category was over budget.
70. Budget Stress Index per category = (months over budget) × (avg % overshoot when over).
71. Months where total spending across all categories exceeded total planned.
72. Per category, slope of `amount_planned` over the last 12 months — are you ratcheting budgets up?
73. Months with planning gaps — any needs category with no budget row.
74. Compare planning accuracy at the parent-category level — are you better at planning needs vs wants vs investing?
75. Running YTD variance per category (cumulative actual − cumulative planned, month by month).

### F. Needs Deep-Dive (76–90)

76. Annual rent spend, expressed as % of annual gross income.
77. Annual transportation total = sum of `gas`, `auto & car`, and any portion of `insurance` attributable to auto.
78. Transportation cost per day (annual transportation / 365).
79. Annual grocery spend vs annual fast food + food delivery spend — the "real food / convenience food" ratio.
80. % of needs spending concentrated in your single biggest needs merchant (single-point-of-failure check).
81. Year-over-year growth per needs category (last 12 months vs prior 12 months).
82. Monthly medical spend average + coefficient of variation (how lumpy is medical?).
83. All `fees` transactions in the last 12 months and the total — direct leakage to penalties/service charges.
84. Annual phone spend as % of annual income.
85. Quarterly trend: grocery / (fast food + delivery) — is the convenience tax growing or shrinking?
86. Needs categories with no transactions in the last 90 days — moved elsewhere or genuinely dormant?
87. Needs-creep detector: for each recurring needs merchant, slope of payment amount over last 12 months.
88. Standard deviation of `light` bills per quarter — seasonal predictability.
89. Top 5 needs merchants by 12-month spend.
90. For each of those top 5, the median days between payments (confirms cycle).

### G. Wants Bottlenecks & Leak Detection (91–115)

91. Annual wants total and its % of annual gross income.
92. Wants subcategories ranked by 12-month spend.
93. Annual "I didn't cook" tax = fast food + food delivery + work snacks.
94. Average fast-food + delivery transactions per week, last 12 weeks.
95. Average transaction size: fast food vs food delivery vs groceries — per-meal cost comparison.
96. Total spend on `subscriptions`, with each recurring subscription merchant listed.
97. For each subscription merchant: last charge date, average days between charges, average amount.
98. Subscriptions whose amount has increased over time (price hikes).
99. Total P2P sent in the last 12 months — outflow to friends/individuals.
100. Top 10 single wants transactions by dollar amount, last 12 months.
101. Wants spend on weekends vs weekdays — share of total.
102. Distribution of wants spend by week-of-month (1st, 2nd, 3rd, 4th week) — when are you most vulnerable?
103. Average wants spend by day of week.
104. Days where wants spend > needs spend.
105. Average days between `shopping & retail` transactions.
106. % of wants spend that occurs within 48 hours after an income inflow.
107. Wants merchants with 5+ transactions in the last 90 days — your habit vendors.
108. Trend of monthly wants total over the last 12 months — growing, shrinking, or oscillating?
109. Dollar value per month of a hypothetical 30% wants cut.
110. Days of bill-buffer per month a 50% wants cut would purchase (use your daily burn from question 18).
111. Single wants subcategory that, if eliminated YTD, would have produced the largest savings.
112. Per wants subcategory, median transaction vs mean — skew indicator.
113. Binge weeks: weeks where wants spend ≥ 2× its trailing 4-week average.
114. Longest streak of consecutive days with zero wants spending.
115. Monthly want-to-need ratio across the last 12 months — austerity vs indulgence trajectory.

### H. Savings & Investing Capture Rate (116–130)

116. Total emergency fund contributions in the last 12 months.
117. Total brokerage + retirement contributions in the last 12 months.
118. Monthly savings rate = (savings + investing) / income.
119. Monthly retirement contribution vs monthly wants spend — is your future smaller than your fast food habit?
120. YTD cumulative emergency fund contributions, month by month.
121. Months with zero contribution to savings or investing.
122. Per month, ratio of investing contributions to wants spend.
123. Year-end retirement contribution projection at current run rate.
124. Average days between brokerage deposits.
125. Match-capture velocity: per pay period, are you contributing enough to capture the full 3% (you'll need to define "estimated gross income per period").
126. Gap between actual retirement contribution YTD and (3% × YTD gross income estimate).
127. At current monthly savings pace, months until you hit emergency fund milestones ($1k, $5k, $10k).
128. Investing-to-fast-food dollar ratio over the last 12 months.
129. P2P sent vs brokerage contributions over 12 months — are you funding others more than your future?
130. Months where investing > all wants spend combined (peak discipline months).

### I. Merchant-Level Insight (131–145)

131. Top 20 merchants by 12-month total spend.
132. Top 20 merchants by 12-month transaction count.
133. Merchants with ≥10 transactions and NULL `category_id` — categorization debt.
134. Per top-10 merchant: average transaction size and standard deviation.
135. Merchants whose YoY spend grew (last 12mo vs prior 12mo) — and by how much.
136. Merchants that appeared for 3+ consecutive months then disappeared — lapsed habits.
137. Single-charge merchants with a single transaction > $100 — one-off events.
138. "Cost of convenience" — top 10 `food delivery` merchants by 12-month spend.
139. Merchants where max transaction is ≥ 5× min transaction — high-variance vendors.
140. Per merchant: transactions deviating > 2σ from the merchant's own historical mean — per-merchant anomalies.
141. Merchants charging more frequently than monthly — high-frequency drains.
142. Long-tail merchants — those with 1–2 transactions each, but collectively summing > $1000.
143. For top 5 wants merchants, average days between transactions (habit interval).
144. % of monthly spend captured by top 5 merchants — vendor concentration.
145. Subscription merchants whose charge amounts strictly increased over the last 12 charges.

### J. Temporal Patterns (146–160)

146. Average daily spend by day of week.
147. Total monthly spend by week of month (1st, 2nd, 3rd, 4th, 5th).
148. Spend by hour of day (only meaningful if your `transaction_date` has hour-level resolution).
149. Total spend in the 7 days post-payday vs 7 days pre-payday.
150. Monthly spend heatmap: category × month over the last 12 months.
151. Calendar months where total spend consistently exceeds the trailing 12-month average — "expensive seasons."
152. Spend in the week before and the week of major holidays (Thanksgiving, Christmas, etc).
153. Beginning-of-month (days 1–10) vs end-of-month (days 21–end) spend ratio per category.
154. Per category, the calendar month with highest historical spend — its "high tide."
155. Weekly net flow (income − spend) per ISO week — best and worst weeks.
156. Trajectory of liquid balance over the last 30 days (slope, improving or declining).
157. Longest streak of consecutive days with at least one transaction.
158. Days with > 5 separate transactions — possible dysregulation flags.
159. Moving 7-day, 30-day, 90-day burn rates plotted alongside each other.
160. Single weekday in the last 12 months with highest cumulative wants spend.

### K. Pending & Float Risk (161–170)

161. Total `amount_hold` across all currently unsettled pending transactions.
162. Pending transactions older than 5 days that haven't settled — investigate whether the merchant typically settles or drops.
163. Average days between a transaction going pending and settling.
164. For each merchant, average difference between `amount` (initial pending) and `amount_settled` (final).
165. Average difference between `amount_hold` and `amount_settled` per merchant — over-hold tendencies.
166. Pending rows where `amount_hold` > `amount` — auth/hold mismatch.
167. True available balance = `available_balance` − Σ `amount_hold` for unsettled pendings, per account.
168. Currently pending transactions over a threshold you define.
169. Pending transactions where settlement is overdue relative to the merchant's median lag.
170. Per day in the last 30 days, count and total of pending transactions in flight — uncertainty index.

### L. Account Transfers (171–180)

171. Total amount transferred between accounts, last 12 months.
172. Per (source, target) pair: total transfers and count — dominant routes.
173. Per account, transfers in − transfers out — net transfer flow.
174. Transfers within 3 days of a payday — paycheck routing patterns.
175. Round-trip transfers — money moved out of an account then back in within X days (robbing-Peter-to-pay-Paul signal).
176. % of savings-account inflow that came from transfers vs external sources (from `transactions`).
177. Average monthly transfer volume into savings.
178. Months with zero transfers to savings.
179. For each transfer into a credit account, days until the next credit-account transaction (paying off then re-spending).
180. Edge list for a cash-flow graph: source_account → target_account, weight = 12-month total transfer volume.

### M. Anomaly Detection (181–190)

181. Transactions where amount is > 3σ from that category's mean.
182. Days where total spend is > 3σ from your trailing-90-day daily mean.
183. Merchants with a single transaction whose amount jumped > 50% from the prior transaction at that merchant.
184. New merchants in the last 30 days never seen in the prior 12 months.
185. Expected recurring charges that did NOT appear this month (compare merchant's typical cadence to actual).
186. Duplicate-looking transactions — same merchant + same amount within 24 hours.
187. Negative-amount transactions (refunds, reversals) by category — recovered dollars.
188. Transactions with NULL `category_id` — uncategorized leakage.
189. Pending transactions where `amount_settled` differs from initial `amount` by > 20%.
190. Manual transactions (`is_manual = TRUE`) per category — manual entries can skew aggregates.

### N. Forecasting, Synthesis & Forward View (191–200)

191. Project the rest of the current month's spend per category from month-to-date pace.
192. End-of-year projected total per parent category at current run rate.
193. Months until emergency fund hits a target you define, at current contribution pace.
194. Project 1-year, 3-year, 5-year retirement balance at current contribution pace, given an assumed annual return rate (parameterize the rate).
195. Forecast next month's needs spend per category from 6-month trailing average.
196. Forecast next quarter's wants spend with a simple seasonality adjustment (compare same quarter prior year vs trailing quarter).
197. The "Inverse Buffer" lump sum: today's prepay needed per needs merchant to reach 90 days ahead.
198. Freeze scenario: if income → 0 tomorrow, with current liquidity + question-197 prepayments deployed, how many days of total runway do you have?
199. Smallest behavior change with largest annual yield: rank candidates like "cut delivery 1×/week," "cancel subscription X," "reduce shopping & retail 20%" by annual dollar impact.
200. **Financial Peace Index** — design and compute a composite monthly score combining: (a) days of runway, (b) savings rate, (c) average absolute budget variance, (d) wants/needs ratio, (e) 401k match capture %. Define weights, normalize each component to 0–100, and track this index month-over-month. This is the one query that, if you can write it, means you've internalized every other section.

---

## How to use this list

- Treat every question as a candidate **view** or **CTE**, not a one-shot query.
- When a question requires "average daily burn," you'll write that subquery once and reuse it ten times — extract it.
- The earlier sections build primitives (burn rate, monthly aggregates, category rollups). The later sections compose them. Don't skip ahead.
- When stuck: re-read the linked Postgres docs section for the technique you suspect you need. Most "I can't do this" walls are actually "I haven't met `LATERAL` yet" walls.