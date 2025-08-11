-- Drop database if it exists, then recreate it
-- Connect to maintenance database to be able to drop target DB
\c postgres

-- Terminate existing connections to the target database (if any)
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'test_db' AND pid <> pg_backend_pid();

-- Drop and recreate the database
DROP DATABASE IF EXISTS test_db;
CREATE DATABASE test_db OWNER postgres;
GRANT ALL PRIVILEGES ON DATABASE test_db TO postgres;

-- Connect to the (re)created database
\c test_db

-- Optional: create extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Drop table if it exists, then recreate it
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    age INT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Log the initialization
SELECT 'Database test_db and table users initialized successfully' AS status;