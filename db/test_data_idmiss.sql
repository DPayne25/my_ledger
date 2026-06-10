-- ============================================================
-- SAMPLE DATA -- ADJUSTED FOR YOUR CURRENT DB STATE
-- ============================================================
--
-- Companion to sample-data.sql. That file assumed category IDs
-- 5-23 (the seed order from a clean schema.sql run). Your actual
-- DB shows IDs 9-27 because earlier inserts consumed IDs 5-8
-- before the child categories were seeded.
--
-- This file mirrors the same data with your actual category IDs.
--
-- LESSON: SERIAL sequences don't roll back on failed or deleted
-- inserts. Hardcoding IDs from an assumed seed order is fragile.
-- The robust pattern is to resolve names at insert time:
--
--   INSERT INTO transactions (..., category_id, ...)
--   VALUES (..., (SELECT id FROM categories WHERE category_name='rent'), ...);
--
-- For bulk inserts, wrap lookups in a CTE:
--
--   WITH c AS (SELECT id, category_name FROM categories)
--   INSERT INTO transactions (users_id, account_id, category_id, ...)
--   SELECT 1, 1, c.id, ...
--   FROM (VALUES ('rent', 1100.00, '2025-12-01'), ...) AS v(cat_name, amt, dt)
--   JOIN c ON c.category_name = v.cat_name;
--
-- Use this pattern in your Rust ingestion layer.
-- ============================================================
--
-- CATEGORY ID MAPPING (your current DB):
--   1=needs        2=savings       3=wants         4=investing
--   9=rent         10=light        11=groceries    12=gas
--   13=insurance   14=medical      15=phone        16=auto & car
--   17=fees        18=emergency fund
--   19=fast food & dining          20=food delivery
--   21=work snacks                 22=shopping & retail
--   23=subscriptions               24=laundry      25=p2p sent
--   26=brokerage   27=retirement
--
-- VERIFY YOUR ACCOUNT IDS too -- this file assumes accounts have
-- IDs 1-4 in this order: Primary Checking, Emergency Savings,
-- Cash App, Quicksilver. If your accounts table has different
-- IDs, adjust the account_id values in the inserts below. Run:
--   SELECT id, account_name FROM accounts ORDER BY id;
--
-- SIGN CONVENTION (Plaid default):
--   amount > 0  =>  money OUT of account (spend)
--   amount < 0  =>  money INTO account   (income, refund)
-- ============================================================


-- ============================================================
-- ACCOUNTS
-- ============================================================
INSERT INTO accounts (users_id, account_name, bank_name, account_number, account_type, current_balance, available_balance, plaid_account_id, last_synced_at)
VALUES
  (1, 'Primary Checking',   'Chase',       '****1234', 'checking', 2847.32, 2691.15, 'plaid_acct_chase_chk', NOW() - INTERVAL '2 hours'),
  (1, 'Emergency Savings',  'Chase',       '****5678', 'savings',  1240.00, 1240.00, 'plaid_acct_chase_sav', NOW() - INTERVAL '2 hours'),
  (1, 'Cash App',           'Cash App',    '****9999', 'savings',   312.50,  312.50, 'plaid_acct_cashapp',   NOW() - INTERVAL '6 hours'),
  (1, 'Quicksilver',        'Capital One', '****4321', 'credit',    487.23,  487.23, 'plaid_acct_capone_cc', NOW() - INTERVAL '2 hours')
ON CONFLICT (plaid_account_id) DO NOTHING;


-- ============================================================
-- TRANSACTIONS -- December 2025
-- ============================================================
INSERT INTO transactions (users_id, account_id, plaid_transaction_id, merchant_name, category_id, amount, transaction_date, transaction_description) VALUES
-- Income
(1, 1, 'txn_25_12_05_pay', 'GXO Payroll',   NULL,  -1850.00, '2025-12-05 08:00:00-05', 'Biweekly paycheck'),
(1, 1, 'txn_25_12_19_pay', 'GXO Payroll',   NULL,  -1850.00, '2025-12-19 08:00:00-05', 'Biweekly paycheck'),
-- Recurring needs
(1, 1, 'txn_25_12_01_rent',   'Flexible Finance',  9,  1100.00, '2025-12-01 09:00:00-05', 'December rent'),
(1, 1, 'txn_25_12_03_light',  'AES Indiana',      10,    88.42, '2025-12-03 10:15:00-05', 'Electric bill'),
(1, 1, 'txn_25_12_05_phone',  'T-Mobile',         15,    55.00, '2025-12-05 11:00:00-05', 'Phone bill'),
(1, 1, 'txn_25_12_07_ins',    'Progressive',      13,   142.50, '2025-12-07 09:30:00-05', 'Auto insurance'),
-- Groceries + gas
(1, 1, 'txn_25_12_06_kroger', 'Kroger',    11,  87.34, '2025-12-06 18:20:00-05', 'Weekly groceries'),
(1, 1, 'txn_25_12_20_kroger', 'Kroger',    11, 102.18, '2025-12-20 17:45:00-05', 'Weekly groceries'),
(1, 4, 'txn_25_12_10_gas',    'Speedway',  12,  38.20, '2025-12-10 07:30:00-05', 'Gas'),
(1, 4, 'txn_25_12_24_gas',    'Speedway',  12,  41.15, '2025-12-24 12:00:00-05', 'Gas'),
-- Subscriptions
(1, 4, 'txn_25_12_15_nflx', 'Netflix', 23, 15.49, '2025-12-15 00:01:00-05', 'Monthly sub'),
(1, 4, 'txn_25_12_18_spot', 'Spotify', 23, 10.99, '2025-12-18 00:01:00-05', 'Monthly sub'),
(1, 1, 'txn_25_12_22_oai',  'OpenAI',  23, 20.00, '2025-12-22 00:01:00-05', 'Monthly sub'),
-- Wants -- post-payday cluster
(1, 4, 'txn_25_12_05_chip',  'Chipotle',     19, 13.45, '2025-12-05 12:15:00-05', 'Lunch (payday)'),
(1, 4, 'txn_25_12_06_dd',    'DoorDash',     20, 32.40, '2025-12-06 19:30:00-05', 'Dinner delivery'),
(1, 4, 'txn_25_12_19_amzn',  'Amazon',       22, 78.99, '2025-12-19 20:00:00-05', 'Retail (post-payday)'),
(1, 4, 'txn_25_12_22_tb',    'Taco Bell',    19,  9.85, '2025-12-22 12:30:00-05', 'Lunch'),
-- Investing
(1, 1, 'txn_25_12_22_fido', 'Fidelity', 26, 100.00, '2025-12-22 09:00:00-05', 'Monthly brokerage');


-- ============================================================
-- TRANSACTIONS -- January 2026 (winter light spike, 3-paycheck month)
-- ============================================================
INSERT INTO transactions (users_id, account_id, plaid_transaction_id, merchant_name, category_id, amount, transaction_date, transaction_description) VALUES
(1, 1, 'txn_26_01_02_pay', 'GXO Payroll',   NULL, -1850.00, '2026-01-02 08:00:00-05', 'Biweekly paycheck'),
(1, 1, 'txn_26_01_16_pay', 'GXO Payroll',   NULL, -1850.00, '2026-01-16 08:00:00-05', 'Biweekly paycheck'),
(1, 1, 'txn_26_01_30_pay', 'GXO Payroll',   NULL, -1850.00, '2026-01-30 08:00:00-05', 'Biweekly paycheck (3rd-check month)'),
(1, 1, 'txn_26_01_01_rent',   'Flexible Finance',  9, 1100.00, '2026-01-01 09:00:00-05', 'January rent'),
(1, 1, 'txn_26_01_03_light',  'AES Indiana',      10,  112.78, '2026-01-03 10:15:00-05', 'Electric (cold)'),
(1, 1, 'txn_26_01_05_phone',  'T-Mobile',         15,   55.00, '2026-01-05 11:00:00-05', 'Phone'),
(1, 1, 'txn_26_01_07_ins',    'Progressive',      13,  142.50, '2026-01-07 09:30:00-05', 'Auto insurance'),
(1, 1, 'txn_26_01_10_kroger', 'Kroger',           11,   91.40, '2026-01-10 18:20:00-05', 'Groceries'),
(1, 1, 'txn_26_01_24_meijer', 'Meijer',           11,   76.12, '2026-01-24 11:30:00-05', 'Groceries'),
(1, 4, 'txn_26_01_08_gas',    'Speedway',         12,   39.80, '2026-01-08 07:30:00-05', 'Gas'),
(1, 4, 'txn_26_01_22_gas',    'Speedway',         12,   42.10, '2026-01-22 18:00:00-05', 'Gas'),
(1, 4, 'txn_26_01_15_nflx', 'Netflix', 23, 15.49, '2026-01-15 00:01:00-05', 'Monthly sub'),
(1, 4, 'txn_26_01_18_spot', 'Spotify', 23, 10.99, '2026-01-18 00:01:00-05', 'Monthly sub'),
(1, 1, 'txn_26_01_22_oai',  'OpenAI',  23, 20.00, '2026-01-22 00:01:00-05', 'Monthly sub'),
(1, 4, 'txn_26_01_02_cfa',   'Chick-fil-A', 19, 11.20, '2026-01-02 12:30:00-05', 'Lunch (payday)'),
(1, 4, 'txn_26_01_17_dd',    'DoorDash',    20, 28.75, '2026-01-17 19:00:00-05', 'Delivery (post-payday)'),
(1, 4, 'txn_26_01_25_tb',    'Taco Bell',   19,  8.40, '2026-01-25 12:15:00-05', 'Lunch'),
(1, 1, 'txn_26_01_29_med',   'CVS Pharmacy',14, 47.30, '2026-01-29 14:00:00-05', 'Prescription'),
(1, 1, 'txn_26_01_22_fido',  'Fidelity',    26,100.00, '2026-01-22 09:00:00-05', 'Monthly brokerage');


-- ============================================================
-- TRANSACTIONS -- February 2026 (peak winter, fee event, p2p)
-- ============================================================
INSERT INTO transactions (users_id, account_id, plaid_transaction_id, merchant_name, category_id, amount, transaction_date, transaction_description) VALUES
(1, 1, 'txn_26_02_13_pay', 'GXO Payroll', NULL, -1850.00, '2026-02-13 08:00:00-05', 'Paycheck'),
(1, 1, 'txn_26_02_27_pay', 'GXO Payroll', NULL, -1850.00, '2026-02-27 08:00:00-05', 'Paycheck'),
(1, 1, 'txn_26_02_01_rent',   'Flexible Finance',  9, 1100.00, '2026-02-01 09:00:00-05', 'February rent'),
(1, 1, 'txn_26_02_03_light',  'AES Indiana',      10,  128.55, '2026-02-03 10:15:00-05', 'Electric (coldest)'),
(1, 1, 'txn_26_02_05_phone',  'T-Mobile',         15,   55.00, '2026-02-05 11:00:00-05', 'Phone'),
(1, 1, 'txn_26_02_07_ins',    'Progressive',      13,  142.50, '2026-02-07 09:30:00-05', 'Insurance'),
(1, 1, 'txn_26_02_14_kroger', 'Kroger',           11,   95.18, '2026-02-14 18:00:00-05', 'Groceries'),
(1, 1, 'txn_26_02_28_meijer', 'Meijer',           11,   82.45, '2026-02-28 11:00:00-05', 'Groceries'),
(1, 4, 'txn_26_02_06_gas',    'Speedway',         12,   40.50, '2026-02-06 07:30:00-05', 'Gas'),
(1, 4, 'txn_26_02_20_gas',    'Speedway',         12,   43.25, '2026-02-20 17:30:00-05', 'Gas'),
(1, 1, 'txn_26_02_11_fee',    'Chase NSF Fee',    17,   35.00, '2026-02-11 03:15:00-05', 'Overdraft fee'),
(1, 4, 'txn_26_02_15_nflx', 'Netflix', 23, 15.49, '2026-02-15 00:01:00-05', 'Sub'),
(1, 4, 'txn_26_02_18_spot', 'Spotify', 23, 10.99, '2026-02-18 00:01:00-05', 'Sub'),
(1, 1, 'txn_26_02_22_oai',  'OpenAI',  23, 20.00, '2026-02-22 00:01:00-05', 'Sub'),
(1, 4, 'txn_26_02_13_chip',  'Chipotle',  19, 14.20, '2026-02-13 12:30:00-05', 'Lunch (payday)'),
(1, 4, 'txn_26_02_14_amzn',  'Amazon',    22,124.50, '2026-02-14 21:00:00-05', 'Impulse retail'),
(1, 4, 'txn_26_02_27_dd',    'DoorDash',  20, 35.10, '2026-02-27 19:30:00-05', 'Delivery (payday)'),
(1, 1, 'txn_26_02_15_p2p',   'Cash App',  25, 50.00, '2026-02-15 14:00:00-05', 'Sent to friend'),
(1, 1, 'txn_26_02_22_fido',  'Fidelity',  26,100.00, '2026-02-22 09:00:00-05', 'Brokerage');


-- ============================================================
-- TRANSACTIONS -- March 2026 (shoulder season, laundry)
-- ============================================================
INSERT INTO transactions (users_id, account_id, plaid_transaction_id, merchant_name, category_id, amount, transaction_date, transaction_description) VALUES
(1, 1, 'txn_26_03_13_pay', 'GXO Payroll', NULL, -1850.00, '2026-03-13 08:00:00-05', 'Paycheck'),
(1, 1, 'txn_26_03_27_pay', 'GXO Payroll', NULL, -1850.00, '2026-03-27 08:00:00-05', 'Paycheck'),
(1, 1, 'txn_26_03_01_rent',   'Flexible Finance',  9, 1100.00, '2026-03-01 09:00:00-05', 'March rent'),
(1, 1, 'txn_26_03_03_light',  'AES Indiana',      10,   94.20, '2026-03-03 10:15:00-05', 'Electric'),
(1, 1, 'txn_26_03_05_phone',  'T-Mobile',         15,   55.00, '2026-03-05 11:00:00-05', 'Phone'),
(1, 1, 'txn_26_03_07_ins',    'Progressive',      13,  142.50, '2026-03-07 09:30:00-05', 'Insurance'),
(1, 1, 'txn_26_03_14_kroger', 'Kroger',           11,   88.90, '2026-03-14 18:00:00-04', 'Groceries'),
(1, 1, 'txn_26_03_28_meijer', 'Meijer',           11,   79.65, '2026-03-28 11:00:00-04', 'Groceries'),
(1, 4, 'txn_26_03_05_gas',    'Speedway',         12,   37.40, '2026-03-05 07:30:00-05', 'Gas'),
(1, 4, 'txn_26_03_19_gas',    'Speedway',         12,   39.95, '2026-03-19 17:00:00-04', 'Gas'),
(1, 4, 'txn_26_03_15_nflx', 'Netflix', 23, 15.49, '2026-03-15 00:01:00-04', 'Sub'),
(1, 4, 'txn_26_03_18_spot', 'Spotify', 23, 10.99, '2026-03-18 00:01:00-04', 'Sub'),
(1, 1, 'txn_26_03_22_oai',  'OpenAI',  23, 20.00, '2026-03-22 00:01:00-04', 'Sub'),
(1, 4, 'txn_26_03_13_cfa',   'Chick-fil-A', 19, 12.80, '2026-03-13 12:30:00-04', 'Lunch (payday)'),
(1, 4, 'txn_26_03_27_dd',    'DoorDash',    20, 30.20, '2026-03-27 19:30:00-04', 'Delivery'),
(1, 4, 'txn_26_03_29_amzn',  'Amazon',      22, 45.99, '2026-03-29 20:00:00-04', 'Random retail'),
(1, 4, 'txn_26_03_10_laundry','Laundromat', 24, 12.50, '2026-03-10 19:00:00-04', 'Wash & dry'),
(1, 1, 'txn_26_03_22_fido',  'Fidelity',    26,100.00, '2026-03-22 09:00:00-04', 'Brokerage');


-- ============================================================
-- TRANSACTIONS -- April 2026 (manual entry, uncategorized, work snacks)
-- ============================================================
INSERT INTO transactions (users_id, account_id, plaid_transaction_id, merchant_name, category_id, amount, transaction_date, transaction_description, is_manual) VALUES
(1, 1, 'txn_26_04_10_pay', 'GXO Payroll', NULL, -1850.00, '2026-04-10 08:00:00-04', 'Paycheck', FALSE),
(1, 1, 'txn_26_04_24_pay', 'GXO Payroll', NULL, -1850.00, '2026-04-24 08:00:00-04', 'Paycheck', FALSE),
(1, 1, 'txn_26_04_01_rent',   'Flexible Finance',  9, 1100.00, '2026-04-01 09:00:00-04', 'April rent', FALSE),
(1, 1, 'txn_26_04_03_light',  'AES Indiana',      10,   76.30, '2026-04-03 10:15:00-04', 'Electric (mild)', FALSE),
(1, 1, 'txn_26_04_05_phone',  'T-Mobile',         15,   55.00, '2026-04-05 11:00:00-04', 'Phone', FALSE),
(1, 1, 'txn_26_04_07_ins',    'Progressive',      13,  142.50, '2026-04-07 09:30:00-04', 'Insurance', FALSE),
(1, 1, 'txn_26_04_11_kroger', 'Kroger',           11,   93.20, '2026-04-11 18:00:00-04', 'Groceries', FALSE),
(1, 1, 'txn_26_04_25_meijer', 'Meijer',           11,   85.40, '2026-04-25 11:00:00-04', 'Groceries', FALSE),
(1, 4, 'txn_26_04_02_gas',    'Speedway',         12,   38.85, '2026-04-02 07:30:00-04', 'Gas', FALSE),
(1, 4, 'txn_26_04_16_gas',    'Speedway',         12,   40.20, '2026-04-16 17:30:00-04', 'Gas', FALSE),
(1, 4, 'txn_26_04_15_nflx', 'Netflix', 23, 15.49, '2026-04-15 00:01:00-04', 'Sub', FALSE),
(1, 4, 'txn_26_04_18_spot', 'Spotify', 23, 10.99, '2026-04-18 00:01:00-04', 'Sub', FALSE),
(1, 1, 'txn_26_04_22_oai',  'OpenAI',  23, 20.00, '2026-04-22 00:01:00-04', 'Sub', FALSE),
(1, 4, 'txn_26_04_10_chip',  'Chipotle', 19, 13.95, '2026-04-10 12:30:00-04', 'Lunch (payday)', FALSE),
(1, 4, 'txn_26_04_11_amzn',  'Amazon',   22,189.00, '2026-04-11 21:30:00-04', 'Big impulse buy', FALSE),
(1, 4, 'txn_26_04_24_dd',    'DoorDash', 20, 41.75, '2026-04-24 19:30:00-04', 'Delivery (payday)', FALSE),
(1, 4, 'txn_26_04_18_snack', 'Office Vending', 21, 4.25, '2026-04-18 14:30:00-04', 'Work snacks', FALSE),
-- Uncategorized (NULL category) -- tests Q188
(1, 4, 'txn_26_04_20_unk',   'Unknown Merchant', NULL, 22.50, '2026-04-20 16:00:00-04', 'Categorize this', FALSE),
-- Manual entry, no plaid_transaction_id -- tests Q190
(1, 1, NULL,                  'Cash withdrawal -- coffee tip', 19, 5.00, '2026-04-12 08:30:00-04', 'Manual entry', TRUE),
(1, 1, 'txn_26_04_22_fido',  'Fidelity', 26, 100.00, '2026-04-22 09:00:00-04', 'Brokerage', FALSE);


-- ============================================================
-- TRANSACTIONS -- May 2026 (refund event, p2p)
-- ============================================================
INSERT INTO transactions (users_id, account_id, plaid_transaction_id, merchant_name, category_id, amount, transaction_date, transaction_description) VALUES
(1, 1, 'txn_26_05_08_pay', 'GXO Payroll', NULL, -1850.00, '2026-05-08 08:00:00-04', 'Paycheck'),
(1, 1, 'txn_26_05_22_pay', 'GXO Payroll', NULL, -1850.00, '2026-05-22 08:00:00-04', 'Paycheck'),
(1, 1, 'txn_26_05_01_rent',   'Flexible Finance',  9, 1100.00, '2026-05-01 09:00:00-04', 'May rent'),
(1, 1, 'txn_26_05_03_light',  'AES Indiana',      10,   82.10, '2026-05-03 10:15:00-04', 'Electric'),
(1, 1, 'txn_26_05_05_phone',  'T-Mobile',         15,   55.00, '2026-05-05 11:00:00-04', 'Phone'),
(1, 1, 'txn_26_05_07_ins',    'Progressive',      13,  142.50, '2026-05-07 09:30:00-04', 'Insurance'),
(1, 1, 'txn_26_05_09_kroger', 'Kroger',           11,   98.65, '2026-05-09 18:00:00-04', 'Groceries'),
(1, 1, 'txn_26_05_23_meijer', 'Meijer',           11,   89.20, '2026-05-23 11:00:00-04', 'Groceries'),
(1, 4, 'txn_26_05_07_gas',    'Speedway',         12,   41.30, '2026-05-07 07:30:00-04', 'Gas'),
(1, 4, 'txn_26_05_21_gas',    'Speedway',         12,   43.95, '2026-05-21 17:30:00-04', 'Gas'),
(1, 4, 'txn_26_05_15_nflx', 'Netflix', 23, 15.49, '2026-05-15 00:01:00-04', 'Sub'),
(1, 4, 'txn_26_05_18_spot', 'Spotify', 23, 10.99, '2026-05-18 00:01:00-04', 'Sub'),
(1, 1, 'txn_26_05_22_oai',  'OpenAI',  23, 20.00, '2026-05-22 00:01:00-04', 'Sub'),
(1, 4, 'txn_26_05_08_chip',  'Chipotle',  19, 14.10, '2026-05-08 12:30:00-04', 'Lunch (payday)'),
(1, 4, 'txn_26_05_09_dd',    'DoorDash',  20, 33.45, '2026-05-09 19:00:00-04', 'Delivery'),
(1, 4, 'txn_26_05_22_amzn',  'Amazon',    22, 65.20, '2026-05-22 20:00:00-04', 'Retail (payday)'),
-- Refund (negative spend in wants)
(1, 4, 'txn_26_05_25_refund','Amazon Refund', 22, -45.00, '2026-05-25 14:00:00-04', 'Returned item'),
(1, 1, 'txn_26_05_15_p2p',   'Cash App',  25, 75.00, '2026-05-15 16:00:00-04', 'Sent to friend'),
(1, 1, 'txn_26_05_22_fido',  'Fidelity',  26,100.00, '2026-05-22 09:00:00-04', 'Brokerage');


-- ============================================================
-- TRANSACTIONS -- June 2026 partial (current month)
-- ============================================================
INSERT INTO transactions (users_id, account_id, plaid_transaction_id, merchant_name, category_id, amount, transaction_date, transaction_description) VALUES
(1, 1, 'txn_26_06_05_pay', 'GXO Payroll', NULL, -1850.00, '2026-06-05 08:00:00-04', 'Paycheck'),
(1, 1, 'txn_26_06_01_rent',  'Flexible Finance',  9, 1100.00, '2026-06-01 09:00:00-04', 'June rent'),
(1, 1, 'txn_26_06_03_light', 'AES Indiana',      10,   91.40, '2026-06-03 10:15:00-04', 'Electric'),
(1, 1, 'txn_26_06_05_phone', 'T-Mobile',         15,   55.00, '2026-06-05 11:00:00-04', 'Phone'),
(1, 1, 'txn_26_06_07_ins',   'Progressive',      13,  142.50, '2026-06-07 09:30:00-04', 'Insurance'),
(1, 1, 'txn_26_06_06_kroger','Kroger',           11,   94.80, '2026-06-06 18:00:00-04', 'Groceries'),
(1, 4, 'txn_26_06_04_gas',   'Speedway',         12,   42.20, '2026-06-04 07:30:00-04', 'Gas'),
(1, 4, 'txn_26_06_05_chip',  'Chipotle', 19, 13.50, '2026-06-05 12:30:00-04', 'Lunch (payday)'),
(1, 4, 'txn_26_06_06_dd',    'DoorDash', 20, 36.20, '2026-06-06 19:30:00-04', 'Delivery'),
(1, 4, 'txn_26_06_08_amzn',  'Amazon',   22, 52.99, '2026-06-08 20:30:00-04', 'Retail');


-- ============================================================
-- PENDING TRANSACTIONS
-- ============================================================
INSERT INTO pending_transactions (users_id, account_id, category_id, plaid_transaction_id, merchant_name, amount, amount_hold, amount_settled, settled_at, is_settled) VALUES
-- Currently pending: gas pump pre-auth ($75 hold for a ~$42 fillup expected)
(1, 4, 12, 'pend_gas_active',     'Speedway',           42.00,  75.00, NULL, NULL, FALSE),
-- Currently pending: restaurant ticket ($25 charge, $30 hold for tip)
(1, 4, 19, 'pend_rest_active',    'Local Restaurant',   25.00,  30.00, NULL, NULL, FALSE),
-- Settled: gas pump where final < hold
(1, 4, 12, 'pend_gas_settled',    'Speedway',           50.00, 100.00, 41.80, '2026-06-04 11:00:00-04', TRUE),
-- Settled: restaurant where final > pending (tip added, 20%+ delta)
(1, 4, 19, 'pend_rest_settled',   'Bru Burger',         28.00,  35.00, 36.40, '2026-06-02 13:00:00-04', TRUE),
-- Anomaly: hold mismatch (hold < amount)
(1, 4, 22, 'pend_anomaly',        'Online Shop XYZ',    60.00,  45.00, NULL, NULL, FALSE);


-- ============================================================
-- BUDGETS
-- ============================================================
INSERT INTO budgets (users_id, budget_month, category_id, amount_planned) VALUES
-- June 2026 (current)
(1, '2026-06-01',  9, 1100.00),  -- rent
(1, '2026-06-01', 10,  100.00),  -- light
(1, '2026-06-01', 11,  400.00),  -- groceries
(1, '2026-06-01', 12,  180.00),  -- gas
(1, '2026-06-01', 13,  145.00),  -- insurance
(1, '2026-06-01', 15,   55.00),  -- phone
(1, '2026-06-01', 19,   80.00),  -- fast food (chronic under-budget)
(1, '2026-06-01', 20,   60.00),  -- food delivery
(1, '2026-06-01', 22,   75.00),  -- shopping & retail
(1, '2026-06-01', 23,   50.00),  -- subs
(1, '2026-06-01', 26,  100.00),  -- brokerage
-- May 2026
(1, '2026-05-01',  9, 1100.00),
(1, '2026-05-01', 10,   90.00),
(1, '2026-05-01', 11,  400.00),
(1, '2026-05-01', 19,   80.00),
-- April 2026 (April's Amazon blowout vs $100 retail budget)
(1, '2026-04-01',  9, 1100.00),
(1, '2026-04-01', 22,  100.00),
(1, '2026-04-01', 19,   80.00);


-- ============================================================
-- ACCOUNT TRANSFERS
-- ============================================================
INSERT INTO account_transfers (users_id, amount_transferred, source_account_id, target_account_id, transfer_date) VALUES
-- Monthly emergency fund (Checking -> Savings)
(1, 100.00, 1, 2, '2025-12-22 09:00:00-05'),
(1, 100.00, 1, 2, '2026-01-22 09:00:00-05'),
(1, 100.00, 1, 2, '2026-02-22 09:00:00-05'),
(1, 100.00, 1, 2, '2026-03-22 09:00:00-04'),
(1, 100.00, 1, 2, '2026-04-22 09:00:00-04'),
(1, 100.00, 1, 2, '2026-05-22 09:00:00-04'),
-- Cash App auto-save
(1,  25.00, 1, 3, '2026-02-15 09:00:00-05'),
(1,  25.00, 1, 3, '2026-04-15 09:00:00-04'),
-- Round-trip (Savings -> Checking, back 3 days later) -- tests Q175
(1, 200.00, 2, 1, '2026-02-10 14:00:00-05'),
(1, 200.00, 1, 2, '2026-02-13 09:00:00-05'),
-- Credit card payoff (Checking -> Quicksilver)
(1, 350.00, 1, 4, '2026-05-15 09:00:00-04');


-- ============================================================
-- Verify counts:
--   SELECT COUNT(*) AS txns FROM transactions;
--   SELECT COUNT(*) AS pending FROM pending_transactions;
--   SELECT COUNT(*) AS budgets FROM budgets;
--   SELECT COUNT(*) AS transfers FROM account_transfers;
-- ============================================================