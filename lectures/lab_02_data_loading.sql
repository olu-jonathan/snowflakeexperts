-- Lab 2: Load CSV, JSON, and Parquet files and set up Snowpipe auto-ingest

/***********************************************************************
 * LAB 2: DATA LOADING & UNLOADING
 * Module 3: Data Loading & Unloading
 * 
 * Objectives:
 *   - Create file formats for CSV, JSON, and Parquet
 *   - Create internal and external stages
 *   - Load data using COPY INTO with various options
 *   - Transform data during load
 *   - Set up Snowpipe for continuous loading
 *   - Unload data to a stage
 *
 * Prerequisites: Completed Lab 1 (<your_lastname>_DB database exists)
 * Role Required: SYSADMIN
 ***********************************************************************/


-- =====================================================================
-- SETUP: Ensure environment is ready
-- =====================================================================

USE ROLE _________;
USE DATABASE _________;
USE SCHEMA RAW;


-- =====================================================================
-- PART 1: FILE FORMAT OBJECTS
-- =====================================================================

-- File formats define HOW Snowflake should parse incoming files
-- Once created, they can be reused across multiple COPY commands

-- Step 1: CSV file format
CREATE OR REPLACE FILE FORMAT csv_format
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1                   -- First row is column headers
    FIELD_OPTIONALLY_ENCLOSED_BY = '"' -- Handle quoted fields
    NULL_IF = ('NULL', 'null', '')     -- Treat these as NULL
    TRIM_SPACE = TRUE                  -- Remove leading/trailing spaces
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    COMMENT = 'Standard CSV with headers';

-- Step 2: JSON file format
CREATE OR REPLACE FILE FORMAT json_format
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE          -- If file is a JSON array, unwrap it
    STRIP_NULL_VALUES = FALSE         -- Keep null keys
    ALLOW_DUPLICATE = FALSE
    COMMENT = 'Standard JSON array format';

-- Step 3: Parquet file format
CREATE OR REPLACE FILE FORMAT parquet_format
    TYPE = 'PARQUET'
    COMPRESSION = 'SNAPPY'            -- Common Parquet compression
    COMMENT = 'Standard Parquet with Snappy compression';

-- Step 4: Pipe-delimited CSV (common in legacy systems)
CREATE OR REPLACE FILE FORMAT pipe_delimited_format
    TYPE = 'CSV'
    FIELD_DELIMITER = '|'
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('NULL', 'null', '\\N', '')
    DATE_FORMAT = 'YYYY-MM-DD'
    TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS';

-- View all file formats
SHOW FILE FORMATS IN SCHEMA <your_lastname>_DB.RAW;


-- =====================================================================
-- PART 2: STAGES (Internal)
-- =====================================================================

-- Stages are locations where data files are stored before/after loading

-- Step 5: Create named internal stages
CREATE OR REPLACE STAGE raw_data_stage
    FILE_FORMAT = csv_format
    COMMENT = 'Stage for raw CSV data files';

CREATE OR REPLACE STAGE json_data_stage
    FILE_FORMAT = json_format
    COMMENT = 'Stage for JSON data files';

CREATE OR REPLACE STAGE parquet_data_stage
    FILE_FORMAT = parquet_format
    COMMENT = 'Stage for Parquet data files';

CREATE OR REPLACE STAGE export_stage
    FILE_FORMAT = csv_format
    COMMENT = 'Stage for data exports/unloads';

-- List all stages
SHOW STAGES IN SCHEMA _______.RAW;


-- =====================================================================
-- PART 3: PREPARING SAMPLE DATA (Simulating file uploads)
-- =====================================================================

-- In production, you would PUT files to stages or use external stages.
-- For this lab, we'll create source tables and simulate the load process.

-- Step 6: Create source data to simulate CSV loading
CREATE OR REPLACE TEMPORARY TABLE csv_source_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS product_id,
    'Product_' || SEQ4() AS product_name,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Clothing'
        WHEN 2 THEN 'Home & Garden'
        WHEN 3 THEN 'Sports'
    END AS category,
    ROUND(UNIFORM(9.99, 999.99, RANDOM()), 2) AS price,
    ROUND(UNIFORM(0, 500, RANDOM())) AS stock_quantity,
    DATEADD('day', -UNIFORM(1, 365, RANDOM()), CURRENT_DATE()) AS created_date
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- Step 7: Create source data to simulate JSON loading (events)
CREATE OR REPLACE TEMPORARY TABLE json_source_events AS
SELECT
    OBJECT_CONSTRUCT(
        'event_id', UUID_STRING(),
        'event_type', CASE MOD(SEQ4(), 5)
            WHEN 0 THEN 'page_view'
            WHEN 1 THEN 'add_to_cart'
            WHEN 2 THEN 'purchase'
            WHEN 3 THEN 'search'
            WHEN 4 THEN 'logout'
        END,
        'timestamp', DATEADD('minute', -UNIFORM(1, 10000, RANDOM()), CURRENT_TIMESTAMP())::STRING,
        'user_id', UNIFORM(1000, 9999, RANDOM()),
        'properties', OBJECT_CONSTRUCT(
            'page', '/page/' || UNIFORM(1, 50, RANDOM()),
            'device', CASE MOD(SEQ4(), 3) WHEN 0 THEN 'mobile' WHEN 1 THEN 'desktop' ELSE 'tablet' END,
            'browser', CASE MOD(SEQ4(), 4) WHEN 0 THEN 'Chrome' WHEN 1 THEN 'Firefox' WHEN 2 THEN 'Safari' ELSE 'Edge' END,
            'duration_seconds', UNIFORM(5, 300, RANDOM())
        )
    ) AS event_data
FROM TABLE(GENERATOR(ROWCOUNT => 5000));


-- =====================================================================
-- PART 4: LOADING CSV DATA
-- =====================================================================

-- Step 8: Create the target table for CSV data
CREATE OR REPLACE TABLE products (
    product_id      INTEGER,
    product_name    VARCHAR(100),
    category        VARCHAR(50),
    price           NUMBER(10,2),
    stock_quantity  INTEGER,
    created_date    DATE,
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()  -- audit column
);

-- Step 9: Load data (simulating COPY INTO from a stage)
-- In production with actual files, the command would be:
--
--   COPY INTO products (product_id, product_name, category, price, stock_quantity, created_date)
--   FROM @raw_data_stage/products/
--   FILE_FORMAT = csv_format
--   PATTERN = '.*products.*[.]csv'
--   ON_ERROR = 'CONTINUE'
--   PURGE = TRUE;
--

-- For this lab, we insert from our source table (simulating the load):
INSERT INTO products (product_id, product_name, category, price, stock_quantity, created_date)
SELECT product_id, product_name, category, price, stock_quantity, created_date
FROM csv_source_products;

-- Verify the load
SELECT COUNT(*) AS rows_loaded FROM products;
SELECT * FROM products LIMIT 10;

-- Step 10: COPY INTO with transformation during load
-- You can transform columns during the COPY process
CREATE OR REPLACE TABLE products_transformed (
    product_id      INTEGER,
    product_name    VARCHAR(100),
    category_upper  VARCHAR(50),       -- Transformed: uppercase
    price_with_tax  NUMBER(10,2),      -- Transformed: price + 10% tax
    in_stock        BOOLEAN,           -- Transformed: derived field
    load_date       DATE
);

-- Simulating transformation during COPY:
-- In production: COPY INTO products_transformed
--   FROM (SELECT $1, $2, UPPER($3), $4 * 1.10, $5 > 0, CURRENT_DATE() FROM @raw_data_stage)
INSERT INTO products_transformed
SELECT
    product_id,
    product_name,
    UPPER(category),
    price * 1.10,
    stock_quantity > 0,
    CURRENT_DATE()
FROM csv_source_products;

SELECT * FROM products_transformed LIMIT 10;


-- =====================================================================
-- PART 5: LOADING JSON DATA
-- =====================================================================

-- Step 11: Create table for raw JSON events (VARIANT column)
CREATE OR REPLACE TABLE raw_events (
    event_raw   VARIANT,
    _loaded_at  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Load JSON data into VARIANT column
-- In production: COPY INTO raw_events FROM @json_data_stage FILE_FORMAT = json_format;
INSERT INTO raw_events (event_raw)
SELECT event_data FROM json_source_events;

-- Verify
SELECT COUNT(*) FROM raw_events;
SELECT event_raw FROM raw_events LIMIT 5;

-- Step 12: Query JSON data with dot notation
SELECT
    event_raw:event_id::STRING AS event_id,
    event_raw:event_type::STRING AS event_type,
    event_raw:timestamp::TIMESTAMP_NTZ AS event_timestamp,
    event_raw:user_id::INTEGER AS user_id,
    event_raw:properties:device::STRING AS device,
    event_raw:properties:browser::STRING AS browser,
    event_raw:properties:duration_seconds::INTEGER AS duration_sec
FROM raw_events
LIMIT 20;

-- Step 13: Create a structured table from JSON (ELT pattern)
USE SCHEMA <your_lastname>_DB.STAGING;

CREATE OR REPLACE TABLE events_parsed AS
SELECT
    event_raw:event_id::STRING AS event_id,
    event_raw:event_type::STRING AS event_type,
    event_raw:timestamp::TIMESTAMP_NTZ AS event_timestamp,
    event_raw:user_id::INTEGER AS user_id,
    event_raw:properties:page::STRING AS page_url,
    event_raw:properties:device::STRING AS device_type,
    event_raw:properties:browser::STRING AS browser,
    event_raw:properties:duration_seconds::INTEGER AS duration_seconds,
    CURRENT_TIMESTAMP() AS parsed_at
FROM <your_lastname>_DB.RAW.raw_events;

-- Verify the parsed table
SELECT * FROM events_parsed LIMIT 10;

-- Analytics on parsed events
SELECT
    event_type,
    device_type,
    COUNT(*) AS event_count,
    AVG(duration_seconds) AS avg_duration,
    MIN(event_timestamp) AS first_event,
    MAX(event_timestamp) AS last_event
FROM events_parsed
GROUP BY event_type, device_type
ORDER BY event_count DESC;


-- =====================================================================
-- PART 6: LOADING PARQUET DATA
-- =====================================================================

USE SCHEMA <your_lastname>_DB.RAW;

-- Step 14: Query Parquet metadata before loading
-- When you have Parquet files on a stage, you can inspect their schema:
--
--   SELECT * FROM TABLE(INFER_SCHEMA(
--       LOCATION => '@parquet_data_stage',
--       FILE_FORMAT => 'parquet_format'
--   ));
--

-- Step 15: Create table from Parquet schema (auto-detect)
-- In production with actual Parquet files:
--
--   CREATE OR REPLACE TABLE sales_data
--       USING TEMPLATE (
--           SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
--           FROM TABLE(INFER_SCHEMA(
--               LOCATION => '@parquet_data_stage/sales/',
--               FILE_FORMAT => 'parquet_format'
--           ))
--       );
--

-- For this lab, we create the table manually (simulating Parquet load):
CREATE OR REPLACE TABLE sales_data (
    sale_id         INTEGER,
    product_id      INTEGER,
    customer_id     INTEGER,
    sale_date       DATE,
    quantity        INTEGER,
    unit_price      NUMBER(10,2),
    total_amount    NUMBER(10,2),
    region          VARCHAR(20),
    channel         VARCHAR(20)
);

-- Generate sample sales data (simulating Parquet content)
INSERT INTO sales_data
SELECT
    SEQ4() AS sale_id,
    UNIFORM(1, 1000, RANDOM()) AS product_id,
    UNIFORM(1, 5, RANDOM()) AS customer_id,
    DATEADD('day', -UNIFORM(0, 180, RANDOM()), CURRENT_DATE()) AS sale_date,
    UNIFORM(1, 10, RANDOM()) AS quantity,
    ROUND(UNIFORM(10, 500, RANDOM()), 2) AS unit_price,
    quantity * unit_price AS total_amount,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'North America'
        WHEN 1 THEN 'Europe'
        WHEN 2 THEN 'Asia Pacific'
        WHEN 3 THEN 'Latin America'
    END AS region,
    CASE MOD(SEQ4(), 3)
        WHEN 0 THEN 'Online'
        WHEN 1 THEN 'Retail'
        WHEN 2 THEN 'Wholesale'
    END AS channel
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

SELECT COUNT(*) AS total_sales FROM sales_data;
SELECT * FROM sales_data LIMIT 10;


-- =====================================================================
-- PART 7: DATA VALIDATION AND ERROR HANDLING
-- =====================================================================

-- Step 16: VALIDATION_MODE - test a load without actually loading
-- In production:
--
--   COPY INTO products
--   FROM @raw_data_stage/products_new.csv
--   FILE_FORMAT = csv_format
--   VALIDATION_MODE = 'RETURN_ERRORS';   -- Show only rows with errors
--
--   COPY INTO products
--   FROM @raw_data_stage/products_new.csv
--   FILE_FORMAT = csv_format
--   VALIDATION_MODE = 'RETURN_5_ROWS';   -- Preview first 5 rows
--

-- Step 17: Check load history
-- This shows the history of COPY INTO operations
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'PRODUCTS',
    START_TIME => DATEADD('hour', -24, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC;


-- =====================================================================
-- PART 8: DATA UNLOADING (EXPORT)
-- =====================================================================

-- Step 18: Unload data to a stage as CSV
COPY INTO @export_stage/analytics/sales_summary_
FROM (
    SELECT
        region,
        channel,
        DATE_TRUNC('month', sale_date) AS sale_month,
        COUNT(*) AS transaction_count,
        SUM(total_amount) AS total_revenue,
        AVG(total_amount) AS avg_order_value
    FROM sales_data
    GROUP BY region, channel, sale_month
    ORDER BY sale_month, region
)
FILE_FORMAT = (TYPE = 'CSV' HEADER = TRUE COMPRESSION = 'GZIP')
OVERWRITE = TRUE
MAX_FILE_SIZE = 50000000   -- 50MB per file
SINGLE = FALSE;            -- Allow multiple output files

-- Step 19: Verify the exported files
LIST @export_stage/analytics/;

-- Step 20: Unload as JSON
COPY INTO @export_stage/json_export/events_
FROM (
    SELECT OBJECT_CONSTRUCT(
        'event_id', event_id,
        'event_type', event_type,
        'timestamp', event_timestamp,
        'user_id', user_id,
        'device', device_type
    ) AS json_record
    FROM <your_lastname>_DB.STAGING.events_parsed
    LIMIT 1000
)
FILE_FORMAT = (TYPE = 'JSON' COMPRESSION = 'GZIP');

LIST @export_stage/json_export/;


-- =====================================================================
-- PART 9: SNOWPIPE SETUP (Continuous Loading)
-- =====================================================================

-- Step 21: Create a table for Snowpipe to load into
CREATE OR REPLACE TABLE streaming_events (
    event_raw       VARIANT,
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _file_name      VARCHAR(500),
    _file_row_number INTEGER
);

-- Step 22: Create a pipe for auto-ingestion
-- NOTE: For actual auto-ingest, you need an external stage with
-- cloud event notifications configured (S3 SQS, Azure Event Grid, etc.)
--
-- This example shows the DDL pattern:

CREATE OR REPLACE PIPE events_pipe
    AUTO_INGEST = FALSE   -- Set to TRUE with external stage + notifications
    COMMENT = 'Pipe for continuous event ingestion'
AS
COPY INTO streaming_events (event_raw, _file_name, _file_row_number)
FROM (
    SELECT
        $1,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER
    FROM @json_data_stage
)
FILE_FORMAT = json_format;

-- Step 23: Check pipe status
SELECT SYSTEM$PIPE_STATUS('events_pipe');

-- View pipe definition
SHOW PIPES;
DESCRIBE PIPE events_pipe;

-- Step 24: Manually trigger the pipe (for testing)
-- ALTER PIPE events_pipe REFRESH;

-- Step 25: Monitor pipe loading history
-- SELECT *
-- FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
--     TABLE_NAME => 'STREAMING_EVENTS',
--     START_TIME => DATEADD('hour', -24, CURRENT_TIMESTAMP())
-- ));


-- =====================================================================
-- PART 10: METADATA COLUMNS AND ADVANCED LOADING
-- =====================================================================

-- Step 26: Using metadata columns during load
-- Snowflake provides metadata about the source file during COPY:
--   METADATA$FILENAME        - Name of the source file
--   METADATA$FILE_ROW_NUMBER - Row number within the file
--   METADATA$FILE_CONTENT_KEY - Hash of file content
--   METADATA$FILE_LAST_MODIFIED - File modification timestamp
--   METADATA$START_SCAN_TIME - When Snowflake started scanning

-- Example pattern (for reference):
--
--   COPY INTO target_table (col1, col2, source_file, row_num)
--   FROM (
--       SELECT
--           $1,
--           $2,
--           METADATA$FILENAME,
--           METADATA$FILE_ROW_NUMBER
--       FROM @my_stage
--   )
--   FILE_FORMAT = csv_format
--   PATTERN = '.*2024.*[.]csv';  -- Only load files matching pattern


-- =====================================================================
-- PART 11: ANALYTICS ON LOADED DATA
-- =====================================================================

USE SCHEMA <your_lastname>_DB.ANALYTICS;

-- Step 27: Create an analytics view combining loaded data
CREATE OR REPLACE VIEW sales_dashboard AS
SELECT
    s.region,
    s.channel,
    p.category,
    DATE_TRUNC('week', s.sale_date) AS sale_week,
    COUNT(*) AS transactions,
    SUM(s.quantity) AS units_sold,
    SUM(s.total_amount) AS revenue,
    AVG(s.total_amount) AS avg_order_value,
    COUNT(DISTINCT s.customer_id) AS unique_customers
FROM <your_lastname>_DB.RAW.sales_data s
LEFT JOIN <your_lastname>_DB.RAW.products p ON s.product_id = p.product_id
GROUP BY s.region, s.channel, p.category, sale_week;

-- Query the dashboard view
SELECT * FROM sales_dashboard
WHERE sale_week >= DATEADD('week', -4, CURRENT_DATE())
ORDER BY sale_week DESC, revenue DESC
LIMIT 20;

-- Revenue by region
SELECT
    region,
    SUM(revenue) AS total_revenue,
    SUM(transactions) AS total_transactions,
    ROUND(SUM(revenue) / SUM(transactions), 2) AS avg_transaction_value
FROM sales_dashboard
GROUP BY region
ORDER BY total_revenue DESC;


-- =====================================================================
-- CLEANUP (OPTIONAL)
-- =====================================================================

-- Uncomment to clean up:
-- DROP PIPE events_pipe;
-- REMOVE @export_stage;
-- The database and warehouse from Lab 1 persist for future labs.


-- =====================================================================
-- EXERCISES FOR PRACTICE
-- =====================================================================

/*
EXERCISE 1: Create a new file format for TSV (tab-separated values)
             and a corresponding stage.

EXERCISE 2: Create a table with columns that match a different
             JSON structure (e.g., user profiles with nested address).
             Write a query that flattens the nested address.

EXERCISE 3: Unload the top 100 customers by lifetime value as a
             Parquet file to the export stage.

EXERCISE 4: Write a COPY INTO statement that:
             - Loads only files modified in the last 7 days
             - Skips files with more than 10 errors
             - Logs the filename and row number as audit columns
             - Uses MATCH_BY_COLUMN_NAME for Parquet

EXERCISE 5: Create a pipe that would auto-ingest from an external
             S3 stage. Include the METADATA$FILENAME column.
             (Don't need actual S3 - just write correct DDL)

EXERCISE 6: Query COPY_HISTORY and LOAD_HISTORY views to build
             a monitoring dashboard for your data loads.
*/
