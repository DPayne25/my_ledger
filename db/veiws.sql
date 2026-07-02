
-- Cash Positions & Liquidity Snapshot

-- Total Liquid Balance (1)

CREATE OR REPLACE VIEW v_total_liquid_balance AS (
    SELECT SUM(a.available_balance) AS total_liquid_balance
    FROM accounts AS a 
    WHERE a.account_type = 'checking' OR a.account_type = 'savings'
);

-- Total Funds Hold (2)
CREATE OR REPLACE VIEW v_total_funds_hold AS (
    SELECT SUM(a.current_balance) - SUM(a.available_balance) AS funds_on_hold
    FROM accounts AS a
);

-- Account Balance Gap Account Calculation vs Pending Transactions (3)
CREATE OR REPLACE VIEW v_balance_gap AS (
    SELECT a.account_name, a.bank_name, a.id, (a.current_balance - a.available_balance) AS accounts_data_gap, SUM(pt.amount_hold) AS pending_data_gap
    FROM accounts AS a 
    LEFT JOIN pending_transactions AS pt ON a.id = pt.account_id AND pt.is_settled = FALSE
    GROUP BY a.id
);

-- Account Percentage of Net Liquid Worth (4)
CREATE OR REPLACE VIEW v_pct_net_liquid_worth AS (
    SELECT a1.account_name, ROUND((a1.available_balance / (SELECT SUM(a2.available_balance) FROM accounts AS a2))*100, 2) || '%' AS pct_net_liquid_worth
    FROM accounts AS a1
);

-- Stale Account Syncs(5)
CREATE OR REPLACE VIEW v_stale_sync_account AS (
    SELECT a.account_number, a.bank_name, a.last_synced_at
    FROM accounts AS a
    WHERE (last_synced_at + '24 hours' < now())
);

-- True Liquid Net Worth (6)
CREATE OR REPLACE VIEW v_total_assets AS (
    SELECT ((SELECT SUM(a1.available_balance) FROM accounts AS a1 WHERE account_type = 'checking' OR account_type = 'savings') - SUM(a.current_balance)) AS true_liquid_net_worth 
    FROM accounts AS a 
    WHERE account_type = 'credit'
);

-- Spendable Cash (7) {May be unnecessary since the current_balance vs available_balance already make this discrepancy}
SELECT (SUM(a.available_balance) - SUM(pt.amount)) AS spendable_cash FROM accounts AS a LEFT JOIN pending_transactions AS pt ON a.id = pt.account_id AND pt.is_settled IS FALSE;

-- Account Overdraft Risk (8)
CREATE OR REPLACE VIEW v_overdraft_risk AS(
    SELECT bank_name, account_number, account_type, available_balance 
    FROM accounts 
    WHERE available_balance < 1000
);

-- Ratio Savings:Checking (9)
CREATE OR REPLACE VIEW v_savings_to_checking_ratio AS (
    SELECT ROUND((SUM(a.current_balance) / (SELECT SUM(a1.current_balance) FROM accounts AS a1 WHERE a1.account_type = 'checking')), 2) AS "savings:checking" FROM accounts AS a WHERE a.account_type = 'savings'
);

-- Credit Balance Trend Over Last 90 Days (10)
-- CREATE OR REPLACE VIEW v_credit_balance_trend AS ()

-- Average Needs Burn Rate (11)
WITH daily_needs AS (
    SELECT generate_series(now()::date - INTERVAL '90 days 1 second', now()::date, INTERVAL '1 day') AS day_at
)
    SELECT daily_needs.day_at, SUM(t.amount) AS amount_spent
    FROM transactions AS t
        LEFT JOIN daily_needs
            ON t.transaction_date::date = daily_needs.day_at
    GROUP BY daily_needs.day_at
SELECT AVG(t.amount) AS avg_daily_burn_need 
FROM transactions AS t 
INNER JOIN categories AS cat ON t.category_id = cat.id 
WHERE cat.category_name = 'needs' AND (t.transaction_date::date > CURRENT_DATE - INTERVAL '90 days') AND t.category_id IS NOT NULL

SELECT * FROM transactions