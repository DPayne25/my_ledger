# MyLedger

A personal financial management system, built from scratch, that treats budgeting as a data and statistics problem rather than a retail app problem.

## Why This Exists

Mainstream budgeting apps (Mint, YNAB, EveryDollar, etc.) flatten personal finance into fixed categories and pre-built charts. They don't let you ask arbitrary questions of your own data, they don't expose the underlying model, and they don't scale their advice to *your* numbers. MyLedger exists because the actual goal is financial control with full statistical ownership — not app convenience. Skill growth in SQL, Rust, and data engineering is a side effect of building this, not the point of it.

## Philosophy

**Store facts, derive everything else.**
Tables hold only what was observed or declared — a Plaid balance, an opening balance, a transaction amount. Anything computed from those facts (derived balances, drift, burn rates, runway) lives in a view, never a stored column. If the schema has a column, someone wrote that number down; it isn't a guess that might go stale.

**Scale-invariant, percentage-based thinking.**
A dollar amount means nothing on its own — it means something relative to income, budget, or net worth. Transactions are evaluated as a percentage of a reference balance so they can be projected onto a different scale (a goal balance, a future net worth). This comes directly from a trading background: position sizing and risk are always expressed as a percentage of capital, never a fixed dollar figure.

**Mechanical, not motivational.**
Budgeting decisions are treated as an optimization problem — burn rate, runway, contribution match capture, opportunity cost — not a moral narrative about discipline or willpower. The system is built to answer "what is mathematically optimal here" rather than "how should I feel about this purchase."

**Every dollar has a job before it's spent.**
The compensation match is captured first (guaranteed, risk-free return), then liabilities are pre-funded aggressively to buy time (buffer measured in days of runway, not just a savings balance), and only the remainder is discretionary. See `budgeting-financial-perspective.md` for the full reasoning behind this ordering.

**The long-horizon goal is a CTA (Commodity Trading Advisor) business.**
Budgeting discipline and clean data are the foundation for eventually operating a trading business — the same percentage-of-capital thinking that governs the household budget is meant to govern trading risk later. This is why the schema is built to eventually separate trading capital from retirement contributions.

## What It Does

- Ingests transactions and account balances (manually now, via Plaid sync soon) into a normalized Postgres schema
- Tracks pending vs. settled transactions as a full lifecycle, so in-flight holds never corrupt a balance calculation
- Isolates transfers between your own accounts from spending, so net worth and burn-rate views can't double-count money moving between your own pockets
- Provides a growing library of SQL views for cash position, burn rate, budget variance, and (soon) opportunity-cost / shadow-portfolio analysis
- Will eventually power a small Rust ingestion service and a lightweight UI (SSH-from-phone queries today, Power BI dashboard for now)

## Architecture at a Glance

| Layer | Tool |
|---|---|
| Storage | PostgreSQL, local Debian server |
| Ingestion (in progress) | Rust, Plaid API |
| Query/inspection | TablePlus (GUI), SSH via Termux (phone) |
| Visualization (v1) | Power BI, connected directly to Postgres |
| Statistical logic | SQL views (`v_*`) — no calculated columns in tables |

### Core Tables

| Table | Purpose | Key relationships |
|---|---|---|
| `users` | Single-user root record | referenced by every other table |
| `accounts` | Bank/card accounts, Plaid metadata, balances | `users_id` |
| `categories` | Hierarchical budget categories (Needs/Wants/Savings/Investing) | self-referencing `parent_id` |
| `transactions` | Settled transaction history | `account_id`, `category_id` |
| `pending_transactions` | In-flight holds, pre-settlement | `account_id`, `category_id`, shares `plaid_transaction_id` with `transactions` once settled |
| `budgets` | Planned amount per category per month | `category_id`, month constrained to first-of-month |
| `account_transfers` | Movement between the user's own accounts | `source_account_id`, `target_account_id` — isolated from `transactions` |

### Balance Model
Three-tier fallback for balance truth: **Plaid-reported balance → cached balance → transaction-sum derivation.** `opening_balance` and `plaid_current_balance` are stored facts; `derived_balance`, `balance_drift`, and `balance_display` are computed in views.


## Current Status

- Schema deployed and stable; core invariants (balance = opening + transaction sum + transfer net; available = current − unsettled holds) verified against reconciled sample data
- Tier-1 SQL views (cash position, liquidity snapshot) in progress
- Plaid Sandbox integration in pre-code phase — auth flow and `/transactions/sync` vs `/transactions/get` reviewed, Rust ingestion layer not yet started
- Open design question: percentage-based transaction normalization (single goal balance vs. multiple named scenarios; liquid-only vs. true net worth as the divisor)

## Roadmap

1. Finish Tier-1 views → Tier-2 (needs baseline, burn rate, income) → Tier-3 (runway snapshot, budget variance)
2. Build Plaid ingestion in Rust: auth + Item creation → `/accounts/get` + `/transactions/sync` → gap analysis against schema
3. Full debt inventory (starting from statements, extending to a credit report pull)
4. Resolve percentage-normalization design questions
5. Add a dedicated CTA trading-capital category, separate from retirement
6. Lock annualization convention (4 vs. 4.333 weeks/month) across laundry budget, paycheck math, and `budgets`

## Repo Contents

- `schema.sql` — table definitions, enums, seed categories
- `veiws.sql` — SQL views (cash position / liquidity snapshot, in progress)
- `test_data_idmiss.sql` — reconciled sample data enforcing balance/hold/settlement invariants
- `budgeting-financial-perspective.md` — the financial philosophy behind buffer strategy and 401k match capture
- `my-ledger_priority_views.md` — goal-to-view dependency mapping and build sequencing
