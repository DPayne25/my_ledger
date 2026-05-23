CREATE TABLE IF NOT EXISTS 'users' (
    'id' SERIAL PRIMARY KEY,
    'username' VARCHAR(255) NOT NULL UNIQUE,
    'email' VARCHAR(255) NOT NULL UNIQUE,
    'logged_at' TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXITS 'accounts' (
    'id' SERIAL PRIMARY KEY,
    'user_id' FOREIGN KEY REFERENCES users(id),
    'account_name' VARCHAR(255) NOT NULL,
    'bank_name' VARCHAR(255) NOT NULL,
    'account_number' VARCHAR(255) NOT NULL,
    'logged_at' TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS 'categories' (
    'id' SERIAL PRIMARY KEY,
    'category_name' VARCHAR(255) NOT NULL UNIQUE,
    'parent_id' INTEGER REFERENCES categories(id),
    'logged_at' TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS 'transactions' (
    'id' SERIAL PRIMARY KEY,
    'user_id' FOREIGN KEY REFERENCES users(id),
    'account_id' FOREIGN KEY REFERENCES accounts(id),
    'merchant_name' VARCHAR(255),
    'category_id' FOREIGN KEY REFERENCES categories(id),
    'amount' NUMERIC(11,2) NOT NULL,
    'transaction_date' TIMESTAMPTZ NOT NULL,
    'description' VARCHAR(255),
    'logged_at' TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS 'pending_transactions' (
    'id' SERIAL PRIMARY KEY,
    'user_id' FOREIGN KEY REFERENCES users(id),
    'account_id' FOREIGN KEY REFERENCES accounts(id),
    'category_id' FOREIGN KEY REFERENCES categories(id),
    'plaid_transaction_id'
    'amount' NUMERIC(11,2) NOT NULL, -- reported amount when first pending
    'amount_hold' NUMERIC(11,2) -- what is held against my balance
    'amount_settled' NUMERIC(11,2), -- NULL until settled, then filled with the final charge
    'transaction_date' TIMESTAMPTZ NOT NULL,
    'is_settled' BOOLEAN DEFAULT FALSE,
);

CREATE TABLE IF NOT EXISTS 'budgets' (
    'id' SERIAL PRIMARY KEY,
    'user_id' FOREIGN KEY REFERENCES users(id),
    'month' TIMESTAMPTZ
    'category' FOREIGN KEY REFERENCES categories(id),
    'amount_planned' NUMERIC(11,2),
    'amount_spent' NUMERIC (11,2),
    'logged_at' TIMESTAMPTZ DEFAULT NOW()
);