DO $$
BEGIN

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname= 'account_type') THEN
        CREATE TYPE account_type AS ENUM ('checking', 'savings', 'credit');
    END IF;

END
$$;

-- users
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- accounts
CREATE TABLE IF NOT EXISTS accounts (
    id SERIAL PRIMARY KEY,
    users_id INTEGER REFERENCES users(id),
    account_name VARCHAR(255) NOT NULL,
    bank_name VARCHAR(255) NOT NULL,
    account_number VARCHAR(255) NOT NULL,
    account_type account_type NOT NULL,
    current_balance NUMERIC(11,2) NOT NULL, -- reported by Plaid; fallback, derive from transactions table
    available_balance NUMERIC(11,2) NOT NULL, -- usable balance
    plaid_account_id VARCHAR(255) NOT NULL UNIQUE, -- reported by Plaid
    last_synced_at TIMESTAMPTZ,
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- categories
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    category_name VARCHAR(255) NOT NULL UNIQUE,
    parent_id INTEGER REFERENCES categories(id),
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- transactions
CREATE TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    users_id INTEGER REFERENCES users(id),
    account_id INTEGER REFERENCES accounts(id),
    plaid_transaction_id VARCHAR(255) UNIQUE,
    merchant_name VARCHAR(255),
    category_id INTEGER REFERENCES categories(id),
    amount NUMERIC(11,2) NOT NULL,
    transaction_date TIMESTAMPTZ NOT NULL,
    transaction_description VARCHAR(255),
    is_manual BOOLEAN DEFAULT FALSE,
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- pending_transactions
CREATE TABLE IF NOT EXISTS pending_transactions (
    id SERIAL PRIMARY KEY,
    users_id INTEGER REFERENCES users(id),
    account_id INTEGER REFERENCES accounts(id),
    category_id INTEGER REFERENCES categories(id),
    plaid_transaction_id VARCHAR(255) UNIQUE,
    merchant_name VARCHAR(255),
    amount NUMERIC(11,2) NOT NULL, -- reported amount when first pending
    amount_hold NUMERIC(11,2), -- what is held against my balance may be redundant #TODO
    amount_settled NUMERIC(11,2), -- NULL until settled, then filled with the final charge
    settled_at TIMESTAMPTZ,
    is_settled BOOLEAN DEFAULT FALSE,
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- budgets (amount_spent is calculated from transactions table at time of query)
CREATE TABLE IF NOT EXISTS budgets (
    id SERIAL PRIMARY KEY,
    users_id INTEGER REFERENCES users(id),
    budget_month DATE
        CONSTRAINT month_date
            CHECK (budget_month = DATE_TRUNC('month', budget_month)::DATE),
    category_id INTEGER REFERENCES categories(id),
    amount_planned NUMERIC(11,2),
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- account_transfers
CREATE TABLE IF NOT EXISTS account_transfers (
    id SERIAL PRIMARY KEY,
    users_id INTEGER REFERENCES users(id),
    amount_transferred NUMERIC(11,2)
        CHECK (amount_transferred > 0),
    source_account_id INTEGER REFERENCES accounts(id),
    target_account_id INTEGER REFERENCES accounts(id),
    transfer_date TIMESTAMPTZ NOT NULL,
    logged_at TIMESTAMPTZ DEFAULT NOW()
);


INSERT INTO users (
                username, 
                email
            )
VALUES      (
                'dakotajpayne', 
                '32944319+DPayne25@users.noreply.github.com'
            )
ON CONFLICT (username) DO NOTHING;

SELECT * FROM users;

INSERT INTO categories (
                category_name,
                parent_id
            )
VALUES      (
                'needs',
                NULL
            ),
            (
                'savings',
                NULL
            ),
            (
                'wants',
                NULL
            ),
            (
                'investing',
                NULL
            )
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO categories (
                category_name,
                parent_id
            )
VALUES      ('rent', 1),
            ('light', 1),
            ('groceries', 1),
            ('gas', 1),
            ('insurance', 1),
            ('medical', 1),
            ('phone', 1),
            ('auto & car', 1),
            ('fees', 1),
            ('emergency fund', 2),
            ('fast food & dining', 3),
            ('food delivery', 3),
            ('work snacks', 3),
            ('shopping & retail', 3),
            ('subscriptions', 3),
            ('laundry', 3),
            ('p2p sent', 3), -- CashApp, Venmo, Zelle...
            ('brokerage', 4),
            ('retirement', 4)
ON CONFLICT (category_name) DO NOTHING;

SELECT * FROM categories;


SELECT 
    parent_category.category_name as parent_category,
    child_category.category_name as child_category
FROM categories AS parent_category
INNER JOIN 
    categories as child_category
    ON parent_category.id = child_category.parent_id
WHERE parent_category.parent_id IS NULL
ORDER BY parent_category.id;

SELECT * FROM accounts;
SELECT * FROM budgets;
SELECT * FROM categories;
SELECT * FROM pending_transactions;
SELECT * FROM transactions;
SELECT * FROM account_transfers;