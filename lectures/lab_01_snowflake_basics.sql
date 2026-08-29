-- Lab 1: Create your first database, schema, warehouse, and run queries
-- Co-authored with CoCo

/***********************************************************************
 * LAB 1: SNOWFLAKE BASICS
 * Module 2: Introduction to Snowflake
 * 
 * Objectives:
 *   - Create and manage databases and schemas
 *   - Create and configure virtual warehouses
 *   - Understand Snowflake object hierarchy
 *   - Run basic queries and explore Snowsight features
 *
 * Prerequisites: A Snowflake account (trial or paid)
 * Role Required: SYSADMIN (or ACCOUNTADMIN for warehouse creation)
 ***********************************************************************/


-- =====================================================================
-- PART 1: SETTING UP YOUR ENVIRONMENT
-- =====================================================================

-- Step 1: Set your role context

-- Step 2: Create your first database
-- Databases are the top-level container for all your data objects. This has been done for you
CREATE OR REPLACE DATABASE <YOUR_LASTNAME>_DB;

-- Verify the database was created
SHOW DATABASES LIKE '<YOUR_LASTNAME>_DB';

-- Step 3: Create schemas to organize your objects
-- Schemas group related tables, views, and other objects
CREATE OR REPLACE SCHEMA <YOUR_LASTNAME>_DB.RAW;        -- For raw/landing data
CREATE OR REPLACE SCHEMA <YOUR_LASTNAME>_DB.STAGING;    -- For cleaned/staged data
CREATE OR REPLACE SCHEMA <YOUR_LASTNAME>_DB.ANALYTICS;  -- For business-ready data

-- View all schemas in our database
SHOW SCHEMAS IN DATABASE <YOUR_LASTNAME>_DB;

-- Step 4: Set your working context
USE DATABASE <YOUR_LASTNAME>_DB;
USE SCHEMA RAW;


-- =====================================================================
-- PART 2: CREATING AND CONFIGURING A VIRTUAL WAREHOUSE
-- =====================================================================

-- Step 5: Create a warehouse for your compute needs
-- Warehouses provide the compute power to run queries -- (This has been done for you)
CREATE OR REPLACE WAREHOUSE COMPUTE_WH 
    WAREHOUSE_SIZE = 'X-SMALL'        -- Smallest size (1 credit/hour)
    AUTO_SUSPEND = 60                  -- Suspend after 60 seconds of inactivity
    AUTO_RESUME = TRUE                 -- Automatically resume when queries arrive
    INITIALLY_SUSPENDED = TRUE         -- Don't start billing immediately
    COMMENT = 'Warehouse for data engineering learning exercises';



-- =====================================================================
-- PART 3: CREATING TABLES
-- =====================================================================

-- Step 7: Create tables with different types
USE SCHEMA <YOUR_LASTNAME>_DB.RAW;

-- Permanent table (default) - has Time Travel and Fail-safe
CREATE OR REPLACE TABLE customers (
    customer_id     INTEGER AUTOINCREMENT,
    first_name      VARCHAR(50) NOT NULL,
    last_name       VARCHAR(50) NOT NULL,
    email           VARCHAR(100),
    signup_date     DATE DEFAULT CURRENT_DATE(),
    is_active       BOOLEAN DEFAULT TRUE,
    metadata        VARIANT,  -- For semi-structured data
    PRIMARY KEY (customer_id)
);

-- Transient table - has Time Travel but NO Fail-safe (lower storage cost)
CREATE OR REPLACE TRANSIENT TABLE orders (
    order_id        INTEGER AUTOINCREMENT,
    customer_id     INTEGER NOT NULL,
    order_date      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    total_amount    NUMBER(10,2),
    status          VARCHAR(20) DEFAULT 'pending',
    order_details   VARIANT
);

-- Temporary table - exists only for the session (no Time Travel or Fail-safe)
CREATE OR REPLACE TEMPORARY TABLE temp_import_log (
    log_id          INTEGER AUTOINCREMENT,
    file_name       VARCHAR(255),
    rows_loaded     INTEGER,
    load_timestamp  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Step 8: View table properties
DESCRIBE TABLE customers;
DESCRIBE TABLE orders;

-- Show all tables in the current schema
SHOW TABLES IN SCHEMA <YOUR_LASTNAME>_DB.RAW;


-- =====================================================================
-- PART 4: INSERTING AND QUERYING DATA
-- =====================================================================

-- Step 9: Insert sample data
INSERT INTO customers (first_name, last_name, email, signup_date, is_active, metadata)
VALUES
    ('Alice',   'Johnson',  'alice@example.com',   '2024-01-15', TRUE,
        PARSE_JSON('{"source": "web", "plan": "premium"}')),
    ('Bob',     'Smith',    'bob@example.com',     '2024-02-20', TRUE,
        PARSE_JSON('{"source": "referral", "plan": "basic"}')),
    ('Charlie', 'Williams', 'charlie@example.com', '2024-03-10', FALSE,
        PARSE_JSON('{"source": "organic", "plan": "premium"}')),
    ('Diana',   'Brown',    'diana@example.com',   '2024-04-05', TRUE,
        PARSE_JSON('{"source": "ad_campaign", "plan": "enterprise"}')),
    ('Eve',     'Davis',    'eve@example.com',     '2024-05-22', TRUE,
        PARSE_JSON('{"source": "web", "plan": "basic"}'));

INSERT INTO orders (customer_id, order_date, total_amount, status, order_details)
VALUES
    (1, '2024-06-01 10:30:00', 150.00, 'completed',
        PARSE_JSON('{"items": [{"sku": "A100", "qty": 2}, {"sku": "B200", "qty": 1}]}')),
    (1, '2024-06-15 14:20:00', 75.50,  'completed',
        PARSE_JSON('{"items": [{"sku": "C300", "qty": 1}]}')),
    (2, '2024-06-10 09:00:00', 200.00, 'shipped',
        PARSE_JSON('{"items": [{"sku": "A100", "qty": 4}]}')),
    (3, '2024-06-20 16:45:00', 50.00,  'pending',
        PARSE_JSON('{"items": [{"sku": "D400", "qty": 1}]}')),
    (4, '2024-07-01 11:00:00', 500.00, 'completed',
        PARSE_JSON('{"items": [{"sku": "E500", "qty": 5}, {"sku": "A100", "qty": 2}]}')),
    (4, '2024-07-10 08:30:00', 125.00, 'shipped',
        PARSE_JSON('{"items": [{"sku": "B200", "qty": 3}]}')),
    (5, '2024-07-15 13:15:00', 300.00, 'completed',
        PARSE_JSON('{"items": [{"sku": "C300", "qty": 2}, {"sku": "D400", "qty": 2}]}'));

-- Step 10: Basic queries
-- Simple SELECT
SELECT * FROM customers;

-- Filtering and sorting
SELECT first_name, last_name, email, signup_date
FROM customers
WHERE is_active = TRUE
ORDER BY signup_date DESC;

-- Aggregation
SELECT status, COUNT(*) AS order_count, SUM(total_amount) AS total_revenue
FROM orders
GROUP BY status
ORDER BY total_revenue DESC;


-- =====================================================================
-- PART 5: JOINS AND WINDOW FUNCTIONS
-- =====================================================================

-- Step 11: JOIN customers with orders
SELECT
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    COUNT(o.order_id) AS total_orders,
    SUM(o.total_amount) AS lifetime_value
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY customer_name, c.email
ORDER BY lifetime_value DESC NULLS LAST;

-- Step 12: Window functions
SELECT
    c.first_name || ' ' || c.last_name AS customer_name,
    o.order_date,
    o.total_amount,
    SUM(o.total_amount) OVER (PARTITION BY o.customer_id ORDER BY o.order_date) AS running_total,
    ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.order_date) AS order_sequence,
    RANK() OVER (ORDER BY o.total_amount DESC) AS amount_rank
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
ORDER BY customer_name, o.order_date;


-- =====================================================================
-- PART 6: WORKING WITH SEMI-STRUCTURED DATA (VARIANT)
-- =====================================================================

-- Step 13: Query VARIANT columns using dot notation
SELECT
    first_name,
    last_name,
    metadata:source::STRING AS acquisition_source,
    metadata:plan::STRING AS plan_type
FROM customers;

-- Step 14: Flatten nested arrays in order details
SELECT
    o.order_id,
    o.order_date,
    f.value:sku::STRING AS product_sku,
    f.value:qty::INTEGER AS quantity
FROM orders o,
LATERAL FLATTEN(input => o.order_details:items) f;


-- =====================================================================
-- PART 7: VIEWS
-- =====================================================================

-- Step 15: Create a view in the analytics schema
USE SCHEMA <YOUR_LASTNAME>_DB.ANALYTICS;

CREATE OR REPLACE VIEW customer_summary AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS full_name,
    c.email,
    c.metadata:plan::STRING AS plan_type,
    c.signup_date,
    c.is_active,
    COUNT(o.order_id) AS total_orders,
    COALESCE(SUM(o.total_amount), 0) AS lifetime_value,
    MAX(o.order_date) AS last_order_date,
    DATEDIFF('day', MAX(o.order_date), CURRENT_TIMESTAMP()) AS days_since_last_order
FROM <YOUR_LASTNAME>_DB.RAW.customers c
LEFT JOIN <YOUR_LASTNAME>_DB.RAW.orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, full_name, c.email, plan_type, c.signup_date, c.is_active;

-- Query the view
SELECT * FROM customer_summary ORDER BY lifetime_value DESC;


-- =====================================================================
-- PART 8: EXPLORING METADATA AND SYSTEM FUNCTIONS
-- =====================================================================

-- Step 16: Useful system functions
SELECT CURRENT_ACCOUNT();
SELECT CURRENT_USER();
SELECT CURRENT_ROLE();
SELECT CURRENT_WAREHOUSE();
SELECT CURRENT_DATABASE();
SELECT CURRENT_SCHEMA();

-- Step 17: Information schema queries
SELECT table_catalog, table_schema, table_name, table_type, row_count, bytes
FROM <YOUR_LASTNAME>_DB.INFORMATION_SCHEMA.TABLES
WHERE table_schema != 'INFORMATION_SCHEMA'
ORDER BY table_schema, table_name;

-- Step 18: Query history (requires ACCOUNTADMIN or appropriate privileges)
-- SELECT query_id, query_text, user_name, warehouse_name, 
--        execution_status, total_elapsed_time
-- FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
--     dateadd('hours', -1, current_timestamp()), current_timestamp()))
-- ORDER BY start_time DESC
-- LIMIT 20;


-- =====================================================================
-- PART 9: CLEANUP (OPTIONAL)
-- =====================================================================

-- Uncomment to clean up resources after the lab:
-- DROP DATABASE <YOUR_LASTNAME>_DB;
-- DROP WAREHOUSE <YOUR_LASTNAME>_DB_WH;


-- =====================================================================
-- EXERCISES FOR PRACTICE
-- =====================================================================

/*
EXERCISE 1: Create a new schema called "EXPERIMENTS" in <YOUR_LASTNAME>_DB
             and create a table called "products" with columns:
             product_id, name, category, price, created_at

EXERCISE 2: Insert 5 products and write a query that shows
             the most expensive product in each category

EXERCISE 3: Create a view that joins orders with the products
             (hint: use the SKU from the VARIANT column)

EXERCISE 4: Use SHOW commands to explore:
             - All roles available to you
             - All warehouses
             - All databases you can access

EXERCISE 5: Resize your warehouse to SMALL, run a query,
             then resize back to X-SMALL. Check the query profile
             to see the difference.
*/
