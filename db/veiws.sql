
-- Cash Positions & Liquidity Snapshot

-- Total Liquid Balance

CREATE VIEW IF NOT EXISTS v_total_liquid_balance AS (
    SELECT SUM(a.available_balance) FROM accounts AS a WHERE a.account_type = 'checking' OR a.account_type = 'savings'
);

-- Total Funds Hold

CREATE VIEW IF NOT EXISTS v_total_funds_hold AS (
    SELECT SUM(a.current_balance) - SUM(a.available_balance)
    FROM accounts AS a
)

-- Account Balance Gap
CREATE VIEW IF NOT EXISTS v_balance_gap AS (
    SELECT a.account_name, a.bank_name, (current_balance - available_balance) AS accounts_balance_gap, SUM()
    FROM accounts AS a 
    INNER JOIN pending_transactions AS pt ON a.id = pt.id


)