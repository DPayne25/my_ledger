
-- Cash Positions & Liquidity Snapshot

-- Total Liquid Balance (1)

CREATE VIEW IF NOT EXISTS v_total_liquid_balance AS (
    SELECT SUM(a.available_balance)
    FROM accounts AS a 
    WHERE a.account_type = 'checking' OR a.account_type = 'savings'
);

-- Total Funds Hold (2)

CREATE VIEW IF NOT EXISTS v_total_funds_hold AS (
    SELECT SUM(a.current_balance) - SUM(a.available_balance) AS funds_on_hold
    FROM accounts AS a
);

-- Account Balance Gap Account Calculation vs Pending Transactions (3)
CREATE VIEW IF NOT EXISTS v_balance_gap AS (
    SELECT a.account_name, a.bank_name, (a.current_balance - a.available_balance) AS accounts_data_gap, SUM(pt.amount) AS pending_data_gap
    FROM accounts AS a 
    INNER JOIN pending_transactions AS pt ON a.id = pt.id
    WHERE pt.is_settled = FALSE
    GROUP BY a.id
);

-- Account Percentage of Net Liquid Worth (4)
CREATE VIEW IF NOT EXISTS v_pct_net_liquid_worth AS (
    SELECT a1.account_name, ROUND((a1.available_balance / (SELECT SUM(a2.available_balance) FROM accounts AS a2))*100, 2) || '%' AS pct_net_liquid_worth
    FROM accounts AS a1
);

-- Stale Account Syncs(5)
CREATE VIEW IF NOT EXISTS v_stale_account_syncs AS (
    SELECT a.account_number, a.bank_name, a.last_synced_at
    FROM accounts AS a
    WHERE (last_synced_at + '2 minutes' < now())
);