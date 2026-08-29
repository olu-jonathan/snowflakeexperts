# Data Modeling: Star Schema


A practical guide to dimensional modeling using the star schema pattern — the foundation of analytics-ready data warehouses.

---

## What is Data Modeling?

Data modeling is the process of organizing data into structures optimized for a specific purpose. In data warehousing, we model data for **fast analytical queries** — not for transaction processing.

| Modeling Style | Optimized For | Example |
|---------------|---------------|---------|
| Normalized (3NF) | Write efficiency, data integrity | OLTP systems (apps, payments) |
| Denormalized (Star Schema) | Read efficiency, query speed | OLAP systems (analytics, dashboards) |

---

## The Star Schema

A star schema consists of:

1. **Fact Table** — the center of the star. Contains measurable events (metrics/measures) and foreign keys to dimensions.
2. **Dimension Tables** — the points of the star. Contain descriptive attributes that give context to facts.

### Visual Diagram

```
                    ┌──────────────┐
                    │  DIM_DATE    │
                    │──────────────│
                    │ date_key (PK)│
                    │ full_date    │
                    │ day_of_week  │
                    │ month        │
                    │ quarter      │
                    │ year         │
                    └──────┬───────┘
                           │
┌──────────────┐   ┌──────┴───────────────┐   ┌──────────────────┐
│ DIM_PRODUCT  │   │    FACT_SALES        │   │  DIM_STORE       │
│──────────────│   │──────────────────────│   │──────────────────│
│ product_key  ├───┤ date_key (FK)        ├───┤ store_key (PK)   │
│ product_name │   │ product_key (FK)     │   │ store_name       │
│ category     │   │ store_key (FK)       │   │ city             │
│ brand        │   │ customer_key (FK)    │   │ state            │
│ unit_price   │   │ quantity_sold        │   │ region           │
└──────────────┘   │ total_amount         │   └──────────────────┘
                   │ discount_amount      │
                   └──────┬───────────────┘
                          │
                   ┌──────┴───────┐
                   │ DIM_CUSTOMER │
                   │──────────────│
                   │ customer_key │
                   │ first_name   │
                   │ last_name    │
                   │ segment      │
                   │ city         │
                   └──────────────┘
```

### Why "Star"?

When diagrammed, the fact table in the center with dimension tables surrounding it looks like a star.

---

## Key Concepts

| Term | Definition |
|------|-----------|
| **Fact** | A measurable event or metric (revenue, quantity, duration) |
| **Dimension** | Descriptive context (who, what, where, when) |
| **Grain** | The level of detail one row in the fact table represents |
| **Surrogate Key** | An artificial integer key (e.g., `product_key`) used instead of natural keys |
| **Foreign Key** | A column in the fact table that references a dimension's primary key |

---

## Rules of Star Schema

1. **One fact table per business process** (sales, shipments, registrations)
2. **Dimensions describe the "who, what, where, when, how"**
3. **Facts contain only measures and foreign keys** — no descriptive text
4. **Grain must be clearly defined** before building the schema
5. **Dimensions are denormalized** — flatten hierarchies into single tables

---

## Demo 1: Simple Retail Star Schema

Let's build a complete star schema from scratch using simple tables.

### Step 1: Create Dimension Tables

```sql
-- Date dimension
CREATE OR REPLACE TABLE ANALYTICS.DIM_DATE (
    date_key        INTEGER PRIMARY KEY,
    full_date       DATE,
    day_of_week     VARCHAR(10),
    month_name      VARCHAR(10),
    quarter         INTEGER,
    year            INTEGER
);

INSERT INTO ANALYTICS.DIM_DATE VALUES
(20240101, '2024-01-01', 'Monday',    'January',  1, 2024),
(20240102, '2024-01-02', 'Tuesday',   'January',  1, 2024),
(20240115, '2024-01-15', 'Monday',    'January',  1, 2024),
(20240201, '2024-02-01', 'Thursday',  'February', 1, 2024),
(20240315, '2024-03-15', 'Friday',    'March',    1, 2024);

-- Product dimension
CREATE OR REPLACE TABLE ANALYTICS.DIM_PRODUCT (
    product_key     INTEGER PRIMARY KEY,
    product_name    VARCHAR(50),
    category        VARCHAR(30),
    brand           VARCHAR(30),
    unit_price      DECIMAL(10,2)
);

INSERT INTO ANALYTICS.DIM_PRODUCT VALUES
(1, 'Laptop Pro 15',     'Electronics', 'TechCorp',  1200.00),
(2, 'Wireless Mouse',    'Electronics', 'TechCorp',    35.00),
(3, 'Office Chair',      'Furniture',   'ComfortCo',  450.00),
(4, 'Standing Desk',     'Furniture',   'ComfortCo',  800.00),
(5, 'Notebook Pack',     'Stationery',  'PaperPlus',   12.00);

-- Store dimension
CREATE OR REPLACE TABLE ANALYTICS.DIM_STORE (
    store_key       INTEGER PRIMARY KEY,
    store_name      VARCHAR(50),
    city            VARCHAR(30),
    state           VARCHAR(30),
    region          VARCHAR(20)
);

INSERT INTO ANALYTICS.DIM_STORE VALUES
(1, 'Downtown Flagship', 'New York',    'New York',    'Northeast'),
(2, 'Mall Express',      'Los Angeles', 'California',  'West'),
(3, 'Suburb Outlet',     'Chicago',     'Illinois',    'Midwest');

-- Customer dimension
CREATE OR REPLACE TABLE ANALYTICS.DIM_CUSTOMER (
    customer_key    INTEGER PRIMARY KEY,
    first_name      VARCHAR(30),
    last_name       VARCHAR(30),
    segment         VARCHAR(20),
    city            VARCHAR(30)
);

INSERT INTO ANALYTICS.DIM_CUSTOMER VALUES
(1, 'Alice',   'Johnson', 'Corporate', 'New York'),
(2, 'Bob',     'Smith',   'Consumer',  'Los Angeles'),
(3, 'Charlie', 'Brown',   'Corporate', 'Chicago'),
(4, 'Diana',   'Lee',     'Consumer',  'New York');
```

### Step 2: Create the Fact Table

```sql
CREATE OR REPLACE TABLE ANALYTICS.FACT_SALES (
    sale_id         INTEGER PRIMARY KEY,
    date_key        INTEGER REFERENCES ANALYTICS.DIM_DATE(date_key),
    product_key     INTEGER REFERENCES ANALYTICS.DIM_PRODUCT(product_key),
    store_key       INTEGER REFERENCES ANALYTICS.DIM_STORE(store_key),
    customer_key    INTEGER REFERENCES ANALYTICS.DIM_CUSTOMER(customer_key),
    quantity_sold   INTEGER,
    total_amount    DECIMAL(10,2),
    discount_amount DECIMAL(10,2)
);

INSERT INTO ANALYTICS.FACT_SALES VALUES
(1, 20240101, 1, 1, 1, 2, 2400.00, 0.00),
(2, 20240101, 2, 1, 2, 5,  175.00, 10.00),
(3, 20240102, 3, 2, 3, 1,  450.00, 50.00),
(4, 20240115, 4, 3, 1, 1,  800.00, 0.00),
(5, 20240201, 5, 1, 4, 10, 120.00, 0.00),
(6, 20240201, 1, 2, 2, 1, 1200.00, 100.00),
(7, 20240315, 2, 3, 3, 3,  105.00, 5.00),
(8, 20240315, 3, 1, 4, 2,  900.00, 0.00);
```

### Step 3: Query the Star Schema

```sql
-- Total sales by region
SELECT
    s.region,
    SUM(f.total_amount) AS total_revenue,
    SUM(f.quantity_sold) AS total_units
FROM ANALYTICS.FACT_SALES f
JOIN ANALYTICS.DIM_STORE s ON f.store_key = s.store_key
GROUP BY s.region
ORDER BY total_revenue DESC;

-- Sales by product category and quarter
SELECT
    p.category,
    d.quarter,
    SUM(f.total_amount) AS revenue,
    COUNT(*) AS num_transactions
FROM ANALYTICS.FACT_SALES f
JOIN ANALYTICS.DIM_PRODUCT p ON f.product_key = p.product_key
JOIN ANALYTICS.DIM_DATE d ON f.date_key = d.date_key
GROUP BY p.category, d.quarter
ORDER BY p.category, d.quarter;

-- Top customers by spend
SELECT
    c.first_name || ' ' || c.last_name AS customer_name,
    c.segment,
    SUM(f.total_amount) AS total_spend,
    SUM(f.discount_amount) AS total_discounts
FROM ANALYTICS.FACT_SALES f
JOIN ANALYTICS.DIM_CUSTOMER c ON f.customer_key = c.customer_key
GROUP BY customer_name, c.segment
ORDER BY total_spend DESC;
```

Notice how every query follows the same pattern: **start from the fact table, JOIN to dimensions, aggregate measures, GROUP BY dimension attributes**.

---

## Demo 2: Banking Transactions Star Schema

A simple star schema modeling bank transactions with 3 dimensions and 1 fact table.

### Diagram

```
┌──────────────────┐                        ┌──────────────────┐
│  DIM_ACCOUNT     │                        │  DIM_BRANCH      │
│──────────────────│                        │──────────────────│
│ account_key (PK) │                        │ branch_key (PK)  │
│ account_number   │                        │ branch_name      │
│ account_type     │                        │ city             │
│ open_date        │                        │ state            │
└────────┬─────────┘                        └────────┬─────────┘
         │                                           │
         │         ┌────────────────────────┐        │
         └─────────┤  FACT_TRANSACTION      ├────────┘
                   │────────────────────────│
                   │ transaction_id (PK)    │
                   │ account_key (FK)       │
                   │ branch_key (FK)        │
                   │ customer_key (FK)      │
                   │ transaction_date       │
                   │ transaction_type       │
                   │ amount                 │
                   └───────────┬────────────┘
                               │
                   ┌───────────┴────────────┐
                   │  DIM_CUSTOMER          │
                   │────────────────────────│
                   │ customer_key (PK)      │
                   │ first_name             │
                   │ last_name              │
                   │ email                  │
                   │ customer_since         │
                   │ tier                   │
                   └────────────────────────┘
```

**Grain:** One row per banking transaction.

### Create the Tables

```sql
-- Branch dimension
CREATE OR REPLACE TABLE ANALYTICS.DIM_BRANCH (
    branch_key      INTEGER PRIMARY KEY,
    branch_name     VARCHAR(50),
    city            VARCHAR(30),
    state           VARCHAR(30)
);

INSERT INTO ANALYTICS.DIM_BRANCH VALUES
(1, 'Main Street Branch',  'Houston',     'Texas'),
(2, 'Airport Branch',      'Dallas',      'Texas'),
(3, 'Midtown Branch',      'Atlanta',     'Georgia');

-- Account dimension
CREATE OR REPLACE TABLE ANALYTICS.DIM_ACCOUNT (
    account_key     INTEGER PRIMARY KEY,
    account_number  VARCHAR(20),
    account_type    VARCHAR(20),
    open_date       DATE
);

INSERT INTO ANALYTICS.DIM_ACCOUNT VALUES
(1, 'CHK-10001', 'Checking', '2021-03-15'),
(2, 'SAV-20001', 'Savings',  '2020-08-22'),
(3, 'CHK-10002', 'Checking', '2023-01-10'),
(4, 'SAV-20002', 'Savings',  '2022-11-05'),
(5, 'CHK-10003', 'Checking', '2024-02-01');

-- Customer dimension
CREATE OR REPLACE TABLE ANALYTICS.DIM_BANK_CUSTOMER (
    customer_key    INTEGER PRIMARY KEY,
    first_name      VARCHAR(30),
    last_name       VARCHAR(30),
    email           VARCHAR(60),
    customer_since  DATE,
    tier            VARCHAR(20)
);

INSERT INTO ANALYTICS.DIM_BANK_CUSTOMER VALUES
(1, 'James',   'Okafor',   'james.okafor@email.com',   '2019-05-10', 'Gold'),
(2, 'Maria',   'Santos',   'maria.santos@email.com',   '2021-02-18', 'Silver'),
(3, 'Tunde',   'Adeyemi',  'tunde.adeyemi@email.com',  '2020-11-30', 'Gold'),
(4, 'Sarah',   'Mitchell', 'sarah.mitchell@email.com', '2023-07-22', 'Bronze'),
(5, 'David',   'Chen',     'david.chen@email.com',     '2022-01-05', 'Silver');

-- Fact table: transactions
CREATE OR REPLACE TABLE ANALYTICS.FACT_TRANSACTION (
    transaction_id    INTEGER PRIMARY KEY,
    account_key       INTEGER REFERENCES ANALYTICS.DIM_ACCOUNT(account_key),
    branch_key        INTEGER REFERENCES ANALYTICS.DIM_BRANCH(branch_key),
    customer_key      INTEGER REFERENCES ANALYTICS.DIM_BANK_CUSTOMER(customer_key),
    transaction_date  DATE,
    transaction_type  VARCHAR(20),
    amount            DECIMAL(12,2)
);

INSERT INTO ANALYTICS.FACT_TRANSACTION VALUES
(1,  1, 1, 1, '2024-06-01', 'Deposit',    5000.00),
(2,  1, 1, 1, '2024-06-03', 'Withdrawal', -200.00),
(3,  2, 2, 2, '2024-06-01', 'Deposit',    10000.00),
(4,  3, 3, 3, '2024-06-05', 'Deposit',    1500.00),
(5,  3, 3, 3, '2024-06-07', 'Withdrawal', -750.00),
(6,  4, 1, 4, '2024-06-10', 'Transfer',   -3000.00),
(7,  5, 2, 5, '2024-06-10', 'Deposit',    2200.00),
(8,  2, 2, 2, '2024-06-12', 'Withdrawal', -500.00),
(9,  1, 3, 1, '2024-06-15', 'Deposit',    1800.00),
(10, 4, 1, 4, '2024-06-15', 'Deposit',    6000.00);
```

### Query the Banking Star Schema

```sql
-- Total deposits and withdrawals by branch
SELECT
    b.branch_name,
    b.city,
    SUM(CASE WHEN f.amount > 0 THEN f.amount ELSE 0 END) AS total_deposits,
    SUM(CASE WHEN f.amount < 0 THEN f.amount ELSE 0 END) AS total_withdrawals,
    SUM(f.amount) AS net_flow
FROM ANALYTICS.FACT_TRANSACTION f
JOIN ANALYTICS.DIM_BRANCH b ON f.branch_key = b.branch_key
GROUP BY b.branch_name, b.city
ORDER BY net_flow DESC;

-- Transaction volume by account type
SELECT
    a.account_type,
    COUNT(*) AS num_transactions,
    SUM(f.amount) AS net_amount,
    AVG(ABS(f.amount)) AS avg_transaction_size
FROM ANALYTICS.FACT_TRANSACTION f
JOIN ANALYTICS.DIM_ACCOUNT a ON f.account_key = a.account_key
GROUP BY a.account_type;

-- Spending by customer tier
SELECT
    c.tier,
    COUNT(*) AS num_transactions,
    SUM(CASE WHEN f.amount > 0 THEN f.amount ELSE 0 END) AS total_deposits,
    SUM(CASE WHEN f.amount < 0 THEN ABS(f.amount) ELSE 0 END) AS total_withdrawals
FROM ANALYTICS.FACT_TRANSACTION f
JOIN ANALYTICS.DIM_BANK_CUSTOMER c ON f.customer_key = c.customer_key
GROUP BY c.tier
ORDER BY total_deposits DESC;

-- Full star query: all 3 dimensions joined
SELECT
    c.first_name || ' ' || c.last_name AS customer_name,
    c.tier,
    a.account_number,
    a.account_type,
    b.branch_name,
    COUNT(*) AS num_transactions,
    SUM(f.amount) AS balance_change
FROM ANALYTICS.FACT_TRANSACTION f
JOIN ANALYTICS.DIM_BANK_CUSTOMER c ON f.customer_key = c.customer_key
JOIN ANALYTICS.DIM_ACCOUNT a ON f.account_key = a.account_key
JOIN ANALYTICS.DIM_BRANCH b ON f.branch_key = b.branch_key
GROUP BY customer_name, c.tier, a.account_number, a.account_type, b.branch_name
ORDER BY balance_change DESC;
```

This example shows that a star schema doesn't need to be complex — even with just 3 dimensions and 1 fact table, you get flexible, readable analytics queries.

---

## Demo 3: Star Schema with the Weather Table

Now let's apply star schema thinking to the `RAW.WEATHER` table from our semi-structured data lessons. The weather data has current conditions, location info, and forecast data — a perfect candidate for dimensional modeling.

### The Source Data

Recall that `RAW.WEATHER` has VARIANT columns: `CURRENT_CONDITION`, `NEAREST_AREA`, `REQUEST`, and `WEATHER`. We previously created `RAW.WEATHER_VW` to flatten these into readable columns.

### Designing the Star Schema

```
                   ┌────────────────────┐
                   │  DIM_DATE          │
                   │────────────────────│
                   │ date_key (PK)      │
                   │ observation_date   │
                   │ day_of_week        │
                   │ month              │
                   │ year               │
                   └─────────┬──────────┘
                             │
┌──────────────────┐  ┌──────┴──────────────────┐  ┌──────────────────────┐
│ DIM_LOCATION     │  │  FACT_WEATHER_OBS       │  │ DIM_WEATHER_CONDITION│
│──────────────────│  │─────────────────────────│  │──────────────────────│
│ location_key (PK)├──┤ date_key (FK)           ├──┤ condition_key (PK)   │
│ area_name        │  │ location_key (FK)       │  │ weather_code         │
│ country          │  │ condition_key (FK)      │  │ weather_desc         │
│ region           │  │ temp_c                  │  └──────────────────────┘
│ latitude         │  │ temp_f                  │
│ longitude        │  │ humidity                │
│ population       │  │ feels_like_c            │
└──────────────────┘  │ windspeed_kmph          │
                      │ precip_mm               │
                      │ pressure                │
                      │ uv_index                │
                      │ visibility              │
                      │ cloudcover              │
                      └─────────────────────────┘
```

**Grain:** One row per weather observation per city per observation time.

### Step 1: Build Dimensions from Weather Data

```sql
-- Location dimension (extracted from NEAREST_AREA)
CREATE OR REPLACE TABLE ANALYTICS.DIM_LOCATION AS
SELECT
    ROW_NUMBER() OVER (ORDER BY nearest_area[0]:areaName[0].value::VARCHAR) AS location_key,
    nearest_area[0]:areaName[0].value::VARCHAR   AS area_name,
    nearest_area[0]:country[0].value::VARCHAR    AS country,
    nearest_area[0]:region[0].value::VARCHAR     AS region,
    nearest_area[0]:latitude::FLOAT              AS latitude,
    nearest_area[0]:longitude::FLOAT             AS longitude,
    nearest_area[0]:population::INTEGER          AS population
FROM RAW.WEATHER;

-- Weather condition dimension (extracted from CURRENT_CONDITION)
CREATE OR REPLACE TABLE ANALYTICS.DIM_WEATHER_CONDITION AS
SELECT DISTINCT
    current_condition[0]:weatherCode::INTEGER         AS condition_key,
    current_condition[0]:weatherCode::VARCHAR         AS weather_code,
    current_condition[0]:weatherDesc[0].value::VARCHAR AS weather_desc
FROM RAW.WEATHER;

-- Date dimension (generated from observation dates)
CREATE OR REPLACE TABLE ANALYTICS.DIM_OBS_DATE AS
SELECT DISTINCT
    TO_NUMBER(TO_CHAR(CURRENT_DATE(), 'YYYYMMDD')) AS date_key,
    CURRENT_DATE()                                  AS observation_date,
    DAYNAME(CURRENT_DATE())                         AS day_of_week,
    MONTHNAME(CURRENT_DATE())                       AS month_name,
    YEAR(CURRENT_DATE())                            AS year
;
```

### Step 2: Build the Fact Table

```sql
-- Fact table: weather observations (measures = temperature, humidity, wind, etc.)
CREATE OR REPLACE TABLE ANALYTICS.FACT_WEATHER_OBS AS
SELECT
    ROW_NUMBER() OVER (ORDER BY nearest_area[0]:areaName[0].value) AS obs_id,
    TO_NUMBER(TO_CHAR(CURRENT_DATE(), 'YYYYMMDD'))           AS date_key,
    l.location_key                                            AS location_key,
    current_condition[0]:weatherCode::INTEGER                 AS condition_key,
    -- Measures
    current_condition[0]:temp_C::FLOAT                        AS temp_c,
    current_condition[0]:temp_F::FLOAT                        AS temp_f,
    current_condition[0]:humidity::FLOAT                      AS humidity,
    current_condition[0]:FeelsLikeC::FLOAT                    AS feels_like_c,
    current_condition[0]:windspeedKmph::FLOAT                 AS windspeed_kmph,
    current_condition[0]:precipMM::FLOAT                      AS precip_mm,
    current_condition[0]:pressure::FLOAT                      AS pressure,
    current_condition[0]:uvIndex::INTEGER                     AS uv_index,
    current_condition[0]:visibility::FLOAT                    AS visibility,
    current_condition[0]:cloudcover::INTEGER                  AS cloudcover
FROM RAW.WEATHER w
JOIN ANALYTICS.DIM_LOCATION l
    ON nearest_area[0]:areaName[0].value::VARCHAR = l.area_name;
```

### Step 3: Query the Weather Star Schema

```sql
-- Average temperature by country
SELECT
    l.country,
    l.area_name,
    AVG(f.temp_c) AS avg_temp_c,
    AVG(f.humidity) AS avg_humidity
FROM ANALYTICS.FACT_WEATHER_OBS f
JOIN ANALYTICS.DIM_LOCATION l ON f.location_key = l.location_key
GROUP BY l.country, l.area_name
ORDER BY avg_temp_c DESC;

-- Weather conditions breakdown
SELECT
    wc.weather_desc,
    COUNT(*) AS num_observations,
    AVG(f.windspeed_kmph) AS avg_wind,
    AVG(f.precip_mm) AS avg_precipitation
FROM ANALYTICS.FACT_WEATHER_OBS f
JOIN ANALYTICS.DIM_WEATHER_CONDITION wc ON f.condition_key = wc.condition_key
GROUP BY wc.weather_desc;

-- Full star query: All dimensions joined
SELECT
    d.observation_date,
    l.area_name,
    l.country,
    wc.weather_desc,
    f.temp_c,
    f.humidity,
    f.windspeed_kmph,
    f.precip_mm
FROM ANALYTICS.FACT_WEATHER_OBS f
JOIN ANALYTICS.DIM_OBS_DATE d ON f.date_key = d.date_key
JOIN ANALYTICS.DIM_LOCATION l ON f.location_key = l.location_key
JOIN ANALYTICS.DIM_WEATHER_CONDITION wc ON f.condition_key = wc.condition_key
ORDER BY f.temp_c DESC;
```

---

## Fact Table Types

| Type | Description | Example |
|------|------------|---------|
| **Transaction Fact** | One row per event | Each sale, each weather observation |
| **Periodic Snapshot** | One row per time period | Daily inventory levels, monthly balance |
| **Accumulating Snapshot** | One row per lifecycle | Order: placed → shipped → delivered |

---

## Star Schema vs Snowflake Schema

```
STAR SCHEMA                          SNOWFLAKE SCHEMA
(Denormalized dimensions)            (Normalized dimensions)

┌──────────┐                         ┌──────────┐
│DIM_PRODUCT│                         │DIM_PRODUCT│
│──────────│                         │──────────│
│product_key│                         │product_key│
│name       │                         │name       │
│category ◄─── flat!                  │category_key──►┌───────────┐
│brand      │                         └──────────┘    │DIM_CATEGORY│
└──────────┘                                          │───────────│
                                                      │category_key│
                                                      │name        │
                                                      │department──►┌──────────────┐
                                                      └───────────┘ │DIM_DEPARTMENT│
                                                                    └──────────────┘
```

| Feature | Star Schema | Snowflake Schema |
|---------|-------------|------------------|
| Query simplicity | Fewer JOINs | More JOINs |
| Query performance | Faster reads | Slower reads |
| Storage | Some redundancy | Less redundancy |
| Best for | Analytics / BI | Very large dimensions |

**Recommendation:** Start with star schema. Only snowflake a dimension if it has millions of rows with repeated hierarchical data.

---

## Design Checklist

Before building your star schema, answer these questions:

- [ ] **What is the business process?** (sales, weather observations, shipments)
- [ ] **What is the grain?** (one row = one sale? one daily snapshot?)
- [ ] **What are the dimensions?** (who, what, where, when)
- [ ] **What are the measures?** (amounts, quantities, durations)
- [ ] **What queries will be run?** (helps validate the design)

---

## Key Takeaways

| Concept | What You Learned |
|---------|-----------------|
| Star Schema | Fact table at center, dimension tables around it |
| Fact Table | Contains foreign keys + numeric measures |
| Dimension Table | Contains descriptive attributes for grouping/filtering |
| Grain | Defines what one row in the fact table represents |
| Query Pattern | Start from fact → JOIN dimensions → aggregate → GROUP BY |
| Weather Example | Raw JSON data can be modeled into a proper star schema |
| Denormalization | Star schema trades storage for query simplicity and speed |

---

## Practice Exercises

1. Add a `DIM_TIME` dimension to the weather star schema that includes `observation_time`, `hour`, and `am_pm`.
2. Create an accumulating snapshot fact table that tracks a weather alert lifecycle: `issued → active → expired`.
3. Write a query against the retail star schema that answers: "What product category sold the most units in Q1 2024, broken down by region?"
4. Add a new city to `RAW.WEATHER`, then rebuild the `FACT_WEATHER_OBS` table — does your `DIM_LOCATION` need updating too?
