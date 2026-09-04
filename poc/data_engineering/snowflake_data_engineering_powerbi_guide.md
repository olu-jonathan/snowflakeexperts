# Snowflake Data Engineering & Analytics Guide

This guide is a practical introduction to Snowflake objects, data engineering patterns, and a simple path from raw semi-structured data to a Power BI dashboard.

---

# SECTION 1 - BASICS

Snowflake provides a wide range of objects for storing, transforming, securing, governing, and serving data.

## 1. 20 Common Snowflake Objects

| # | Snowflake Object | What it does |
|---|---|---|
| 1 | **Database** | Top-level container that organizes schemas and data objects. |
| 2 | **Schema** | Logical container for tables, views, stages, procedures, and other objects. |
| 3 | **Table** | Stores structured data in rows and columns. |
| 4 | **View** | Stores a SQL query that presents data without physically storing the result. |
| 5 | **Materialized View** | Physically stores query results to improve performance for repeated queries. |
| 6 | **Dynamic Table** | Automatically maintains transformed data based on a target freshness. |
| 7 | **External Table** | Lets you query data stored outside Snowflake, such as files in cloud storage. |
| 8 | **Iceberg Table** | Stores and manages Apache Iceberg table data with Snowflake. |
| 9 | **Stage** | Provides a location for loading data into or unloading data from Snowflake. |
| 10 | **File Format** | Defines how Snowflake should interpret files such as CSV, JSON, or Parquet. |
| 11 | **Stream** | Captures changes to table data for incremental processing. |
| 12 | **Task** | Executes SQL or procedures on a schedule or based on dependencies. |
| 13 | **Pipe** | Automates continuous data loading from staged files using Snowpipe. |
| 14 | **Sequence** | Generates sequential numeric values, commonly used for surrogate keys. |
| 15 | **Stored Procedure** | Encapsulates procedural logic that can be executed on demand. |
| 16 | **User-Defined Function (UDF)** | Performs reusable custom calculations or transformations. |
| 17 | **Semantic View** | Defines business-friendly entities, metrics, relationships, and semantics for analytics and AI. |
| 18 | **Cortex Search Service** | Provides fast search over Snowflake-hosted text and semi-structured data for AI applications. |
| 19 | **Cortex Agent** | Uses AI to reason over enterprise data and invoke tools to answer questions. |
| 20 | **Network Policy** | Controls which IP addresses or network locations can access Snowflake. |

## 2. Basic Object DDL

The following examples use:

- Database: `APPLE_DB`
- Schema: `BRONZE`

### Database

```sql
CREATE DATABASE IF NOT EXISTS APPLE_DB;
```

### Schema

```sql
CREATE SCHEMA IF NOT EXISTS APPLE_DB.BRONZE;
```

### Table

A simple table can be created to hold raw menu records. Because the source is semi-structured JSON/Parquet, a single `VARIANT` column is a useful Bronze-layer design.

```sql
CREATE TABLE IF NOT EXISTS APPLE_DB.BRONZE.MENU (
    RAW_DATA VARIANT
);
```

### View

A view exposes selected attributes from the raw menu data without creating another physical copy of the data.

```sql
CREATE VIEW IF NOT EXISTS APPLE_DB.BRONZE.MENU_VW AS
SELECT
    RAW_DATA:MENU_ID::NUMBER              AS MENU_ID,
    RAW_DATA:MENU_ITEM_ID::NUMBER         AS MENU_ITEM_ID,
    RAW_DATA:MENU_ITEM_NAME::VARCHAR      AS MENU_ITEM_NAME,
    RAW_DATA:ITEM_CATEGORY::VARCHAR       AS ITEM_CATEGORY,
    RAW_DATA:SALE_PRICE_USD::NUMBER(10,2) AS SALE_PRICE_USD
FROM APPLE_DB.BRONZE.MENU;
```

### Stage

A stage points Snowflake to a location containing files that can be loaded or unloaded.

```sql
CREATE STAGE IF NOT EXISTS APPLE_DB.BRONZE.EXT_STAGE;
```

### File Format

A file format defines how Snowflake interprets a particular file type.

```sql
CREATE FILE FORMAT IF NOT EXISTS APPLE_DB.BRONZE.PARQUET_FORMAT
    TYPE = PARQUET;
```

### Stream

A stream records changes made to a table so that downstream processing can identify new or changed records.

```sql
CREATE STREAM IF NOT EXISTS APPLE_DB.BRONZE.MENU_STREAM
    ON TABLE APPLE_DB.BRONZE.MENU;
```

### Task

A task can automate SQL execution on a schedule.

```sql
CREATE TASK IF NOT EXISTS APPLE_DB.BRONZE.MENU_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
    SELECT COUNT(*)
    FROM APPLE_DB.BRONZE.MENU;
```

> **Note:** Creating a task does not automatically start it. Use `ALTER TASK ... RESUME` after reviewing the task definition and dependencies.

---

# SECTION 2 - DATA ENGINEERING IN SNOWFLAKE

## 1. Introduction

Many modern data sources produce **semi-structured data** rather than traditional relational rows and columns.

Examples include:

- JSON from REST APIs
- XML documents
- Parquet files
- Avro files
- Application event payloads
- IoT messages
- Logs
- Nested API responses

Snowflake provides native support for semi-structured data through the `VARIANT`, `OBJECT`, and `ARRAY` data types.

A common Snowflake data engineering pattern is to initially preserve the source structure in a raw layer and then progressively transform the data into business-friendly relational structures.

This approach is particularly useful because it allows engineers to:

1. Preserve the original source data.
2. Inspect and understand the source structure.
3. Transform nested data using Snowflake SQL.
4. Build reusable analytical data products.
5. Serve trusted data to BI tools such as Power BI.

---

## 2. Medallion Architecture

A common architecture for implementing this pattern is the **Medallion Architecture**.

```text
                SOURCE SYSTEMS
                     |
                     v
              +-------------+
              |    BRONZE   |
              | Raw / Source|
              +-------------+
                     |
                     v
              +-------------+
              |    SILVER   |
              | Cleaned /   |
              | Transformed |
              +-------------+
                     |
                     v
              +-------------+
              |     GOLD    |
              | Business /  |
              | Analytics   |
              +-------------+
                     |
                     v
              +-------------+
              | PRESENTATION|
              | Power BI /  |
              | Reporting   |
              +-------------+
```

### Bronze

The Bronze layer contains data close to its original source format.

Typical characteristics:

- Raw
- Minimally transformed
- Source-aligned
- Often stored as `VARIANT` for semi-structured data
- Useful for replaying or reprocessing data

### Silver

The Silver layer contains cleaned, standardized, and transformed data.

Typical activities include:

- Flattening JSON
- Extracting attributes
- Casting data types
- Standardizing names
- Removing duplicates
- Applying business rules
- Joining related data

### Gold

The Gold layer contains business-ready data.

Typical objects include:

- Aggregated tables
- Analytical views
- Business metrics
- Reporting datasets
- Dimensional models

The Gold layer is generally the layer consumed by BI and analytics applications.

---

## 3. Create the Bronze Database and Schema

```sql
CREATE DATABASE IF NOT EXISTS APPLE_DB;

CREATE SCHEMA IF NOT EXISTS APPLE_DB.BRONZE;
```

---

## 4. Create the External Stage

The following stage points to the Snowflake quickstart data stored in Amazon S3.

```sql
CREATE STAGE IF NOT EXISTS APPLE_DB.BRONZE.EXT_STAGE
URL = 's3://sfquickstarts/data-engineering-with-snowpark-python/'
;
```

You can inspect the files available in the stage with:

```sql
LIST @APPLE_DB.BRONZE.EXT_STAGE;
```

---

## 5. Create the Bronze Menu Table

Because the source Parquet data contains semi-structured menu information, we can initially store the record as a single `VARIANT` column.

```sql
CREATE TABLE IF NOT EXISTS APPLE_DB.BRONZE.MENU (
    RAW_DATA VARIANT
);
```

---

## 6. Load the Menu Data

Load the Parquet file into the Bronze table.

```sql
COPY INTO APPLE_DB.BRONZE.MENU
FROM '@"APPLE_DB"."BRONZE"."EXT_STAGE"/pos/menu/menu.snappy.parquet'
FILE_FORMAT = (
    TYPE = PARQUET
);
```

Verify the loaded data:

```sql
SELECT *
FROM APPLE_DB.BRONZE.MENU
LIMIT 10;
```

Inspect the JSON structure:

```sql
SELECT
    RAW_DATA
FROM APPLE_DB.BRONZE.MENU
LIMIT 1;
```

You should see attributes similar to:

```json
{
  "COST_OF_GOODS_USD": 0.5,
  "ITEM_CATEGORY": "Beverage",
  "ITEM_SUBCATEGORY": "Cold Option",
  "MENU_ID": 10063,
  "MENU_ITEM_HEALTH_METRICS_OBJ": "...",
  "MENU_ITEM_ID": 95,
  "MENU_ITEM_NAME": "Bottled Soda",
  "MENU_TYPE": "Ethiopian",
  "MENU_TYPE_ID": 9,
  "SALE_PRICE_USD": 3,
  "TRUCK_BRAND_NAME": "Tasty Tibs"
}
```

---

## 7. Explore the Semi-Structured Data

Snowflake's colon notation allows you to access attributes inside a `VARIANT`.

For example:

```sql
SELECT
    RAW_DATA:MENU_ID::NUMBER              AS MENU_ID,
    RAW_DATA:MENU_ITEM_ID::NUMBER         AS MENU_ITEM_ID,
    RAW_DATA:MENU_ITEM_NAME::VARCHAR      AS MENU_ITEM_NAME,
    RAW_DATA:ITEM_CATEGORY::VARCHAR       AS ITEM_CATEGORY,
    RAW_DATA:ITEM_SUBCATEGORY::VARCHAR    AS ITEM_SUBCATEGORY,
    RAW_DATA:MENU_TYPE::VARCHAR            AS MENU_TYPE,
    RAW_DATA:TRUCK_BRAND_NAME::VARCHAR     AS TRUCK_BRAND_NAME,
    RAW_DATA:SALE_PRICE_USD::NUMBER(10,2)  AS SALE_PRICE_USD,
    RAW_DATA:COST_OF_GOODS_USD::NUMBER(10,2) AS COST_OF_GOODS_USD
FROM APPLE_DB.BRONZE.MENU;
```

---

## 8. Understanding the Nested Health Metrics Object

The menu data contains a nested attribute called:

```text
MENU_ITEM_HEALTH_METRICS_OBJ
```

The value itself is a JSON string containing another object and an array of health metrics.

Conceptually, the structure looks like:

```text
MENU_ITEM_HEALTH_METRICS_OBJ
    |
    +-- menu_item_health_metrics
            |
            +-- ingredients[]
            +-- is_dairy_free_flag
            +-- is_gluten_free_flag
            +-- is_healthy_flag
            +-- is_nut_free_flag
```

For example:

```json
{
  "menu_item_health_metrics": [
    {
      "ingredients": [
        "12 Oz Bottle Soda"
      ],
      "is_dairy_free_flag": "Y",
      "is_gluten_free_flag": "Y",
      "is_healthy_flag": "N",
      "is_nut_free_flag": "Y"
    }
  ],
  "menu_item_id": 95
}
```

Because the nested object is stored as a string, use `TRY_PARSE_JSON()` before navigating through it.

---

## 9. Create the Silver Schema

```sql
CREATE SCHEMA IF NOT EXISTS APPLE_DB.SILVER;
```

---

## 10. Create the Silver Dynamic Table

A Dynamic Table is useful when you want Snowflake to maintain a transformed dataset automatically as the underlying data changes.

The following example transforms the raw menu data into a relational Silver structure.

It also extracts up to seven ingredients from the nested ingredients array.

```sql
CREATE DYNAMIC TABLE IF NOT EXISTS APPLE_DB.SILVER.MENU
TARGET_LAG = '1 hour'
WAREHOUSE = COMPUTE_WH
AS
SELECT
    RAW_DATA:MENU_ID::NUMBER
        AS MENU_ID,

    RAW_DATA:MENU_ITEM_ID::NUMBER
        AS MENU_ITEM_ID,

    RAW_DATA:MENU_ITEM_NAME::VARCHAR
        AS MENU_ITEM_NAME,

    RAW_DATA:MENU_TYPE::VARCHAR
        AS MENU_TYPE,

    RAW_DATA:MENU_TYPE_ID::NUMBER
        AS MENU_TYPE_ID,

    RAW_DATA:TRUCK_BRAND_NAME::VARCHAR
        AS TRUCK_BRAND_NAME,

    RAW_DATA:ITEM_CATEGORY::VARCHAR
        AS ITEM_CATEGORY,

    RAW_DATA:ITEM_SUBCATEGORY::VARCHAR
        AS ITEM_SUBCATEGORY,

    RAW_DATA:SALE_PRICE_USD::NUMBER(10,2)
        AS SALE_PRICE_USD,

    RAW_DATA:COST_OF_GOODS_USD::NUMBER(10,2)
        AS COST_OF_GOODS_USD,

    TRY_PARSE_JSON(
        RAW_DATA:MENU_ITEM_HEALTH_METRICS_OBJ::VARCHAR
    ):menu_item_health_metrics[0]:ingredients[0]::VARCHAR
        AS INGREDIENTS_1,

    TRY_PARSE_JSON(
        RAW_DATA:MENU_ITEM_HEALTH_METRICS_OBJ::VARCHAR
    ):menu_item_health_metrics[0]:ingredients[1]::VARCHAR
        AS INGREDIENTS_2,

    TRY_PARSE_JSON(
        RAW_DATA:MENU_ITEM_HEALTH_METRICS_OBJ::VARCHAR
    ):menu_item_health_metrics[0]:ingredients[2]::VARCHAR
        AS INGREDIENTS_3,

    TRY_PARSE_JSON(
        RAW_DATA:MENU_ITEM_HEALTH_METRICS_OBJ::VARCHAR
    ):menu_item_health_metrics[0]:ingredients[3]::VARCHAR
        AS INGREDIENTS_4,

    TRY_PARSE_JSON(
        RAW_DATA:MENU_ITEM_HEALTH_METRICS_OBJ::VARCHAR
    ):menu_item_health_metrics[0]:ingredients[4]::VARCHAR
        AS INGREDIENTS_5,

    TRY_PARSE_JSON(
        RAW_DATA:MENU_ITEM_HEALTH_METRICS_OBJ::VARCHAR
    ):menu_item_health_metrics[0]:ingredients[5]::VARCHAR
        AS INGREDIENTS_6,

    TRY_PARSE_JSON(
        RAW_DATA:MENU_ITEM_HEALTH_METRICS_OBJ::VARCHAR
    ):menu_item_health_metrics[0]:ingredients[6]::VARCHAR
        AS INGREDIENTS_7,

    TRY_PARSE_JSON(
        RAW_DATA:MENU_ITEM_HEALTH_METRICS_OBJ::VARCHAR
    ):menu_item_health_metrics[0]:is_dairy_free_flag::VARCHAR
        AS IS_DAIRY_FREE_FLAG,

    TRY_PARSE_JSON(
        RAW_DATA:MENU_ITEM_HEALTH_METRICS_OBJ::VARCHAR
    ):menu_item_health_metrics[0]:is_gluten_free_flag::VARCHAR
        AS IS_GLUTEN_FREE_FLAG,

    TRY_PARSE_JSON(
        RAW_DATA:MENU_ITEM_HEALTH_METRICS_OBJ::VARCHAR
    ):menu_item_health_metrics[0]:is_healthy_flag::VARCHAR
        AS IS_HEALTHY_FLAG,

    TRY_PARSE_JSON(
        RAW_DATA:MENU_ITEM_HEALTH_METRICS_OBJ::VARCHAR
    ):menu_item_health_metrics[0]:is_nut_free_flag::VARCHAR
        AS IS_NUT_FREE_FLAG

FROM APPLE_DB.BRONZE.MENU;
```

### Verify the Dynamic Table

```sql
SELECT *
FROM APPLE_DB.SILVER.MENU
LIMIT 20;
```

You can also inspect the Dynamic Table definition:

```sql
DESC DYNAMIC TABLE APPLE_DB.SILVER.MENU;
```

---

## 11. Why Use a Dynamic Table Here?

The Bronze table contains source-oriented data, while the Silver Dynamic Table contains a continuously maintained transformation.

Conceptually:

```text
BRONZE.MENU
     |
     |  JSON extraction
     |  type conversion
     |  nested-object parsing
     |  ingredient extraction
     v
SILVER.MENU
```

This reduces the need to repeatedly execute the same transformation manually and provides a clean foundation for downstream analytics.

---

# SECTION 3 - GOLD AND PRESENTATION

## 1. Create the Gold Schema

The Gold layer will contain business-friendly analytical views.

```sql
CREATE SCHEMA IF NOT EXISTS APPLE_DB.GOLD;
```

---

## 2. Create a Menu Profitability View

This view calculates revenue, estimated cost, and gross profit per menu item.

```sql
CREATE VIEW IF NOT EXISTS APPLE_DB.GOLD.MENU_PROFITABILITY AS
SELECT
    MENU_ID,
    MENU_ITEM_ID,
    MENU_ITEM_NAME,
    TRUCK_BRAND_NAME,
    MENU_TYPE,
    ITEM_CATEGORY,
    ITEM_SUBCATEGORY,

    SALE_PRICE_USD,
    COST_OF_GOODS_USD,

    SALE_PRICE_USD - COST_OF_GOODS_USD
        AS GROSS_PROFIT_USD,

    CASE
        WHEN SALE_PRICE_USD <> 0
        THEN
            ((SALE_PRICE_USD - COST_OF_GOODS_USD)
             / SALE_PRICE_USD) * 100
        ELSE 0
    END AS GROSS_MARGIN_PERCENT,

    IS_DAIRY_FREE_FLAG,
    IS_GLUTEN_FREE_FLAG,
    IS_HEALTHY_FLAG,
    IS_NUT_FREE_FLAG,

    INGREDIENTS_1,
    INGREDIENTS_2,
    INGREDIENTS_3,
    INGREDIENTS_4,
    INGREDIENTS_5,
    INGREDIENTS_6,
    INGREDIENTS_7

FROM APPLE_DB.SILVER.MENU;
```

---

## 3. Create a Category Summary View

This view summarizes the menu by category.

```sql
CREATE VIEW IF NOT EXISTS APPLE_DB.GOLD.MENU_CATEGORY_SUMMARY AS
SELECT
    ITEM_CATEGORY,
    COUNT(*) AS MENU_ITEM_COUNT,
    ROUND(AVG(SALE_PRICE_USD), 2) AS AVG_SALE_PRICE_USD,
    ROUND(AVG(COST_OF_GOODS_USD), 2) AS AVG_COST_USD,
    ROUND(
        AVG(SALE_PRICE_USD - COST_OF_GOODS_USD),
        2
    ) AS AVG_GROSS_PROFIT_USD,
    ROUND(
        AVG(
            CASE
                WHEN SALE_PRICE_USD <> 0
                THEN ((SALE_PRICE_USD - COST_OF_GOODS_USD)
                      / SALE_PRICE_USD) * 100
            END
        ),
        2
    ) AS AVG_GROSS_MARGIN_PERCENT

FROM APPLE_DB.SILVER.MENU
GROUP BY ITEM_CATEGORY;
```

---

## 4. Create a Food Truck Summary View

```sql
CREATE VIEW IF NOT EXISTS APPLE_DB.GOLD.TRUCK_SUMMARY AS
SELECT
    TRUCK_BRAND_NAME,
    COUNT(*) AS MENU_ITEM_COUNT,
    COUNT(DISTINCT MENU_TYPE) AS MENU_TYPE_COUNT,
    ROUND(AVG(SALE_PRICE_USD), 2) AS AVG_MENU_PRICE_USD,
    ROUND(
        AVG(SALE_PRICE_USD - COST_OF_GOODS_USD),
        2
    ) AS AVG_GROSS_PROFIT_USD,
    ROUND(
        AVG(
            CASE
                WHEN SALE_PRICE_USD <> 0
                THEN ((SALE_PRICE_USD - COST_OF_GOODS_USD)
                      / SALE_PRICE_USD) * 100
            END
        ),
        2
    ) AS AVG_GROSS_MARGIN_PERCENT

FROM APPLE_DB.SILVER.MENU
GROUP BY TRUCK_BRAND_NAME;
```

---

## 5. Validate the Gold Layer

Run:

```sql
SELECT *
FROM APPLE_DB.GOLD.MENU_PROFITABILITY
ORDER BY GROSS_PROFIT_USD DESC
LIMIT 20;
```

Then:

```sql
SELECT *
FROM APPLE_DB.GOLD.MENU_CATEGORY_SUMMARY
ORDER BY AVG_GROSS_PROFIT_USD DESC;
```

And:

```sql
SELECT *
FROM APPLE_DB.GOLD.TRUCK_SUMMARY
ORDER BY AVG_GROSS_PROFIT_USD DESC;
```

---

# SECTION 4 - PRESENTATION WITH POWER BI

## 1. Connect Power BI to Snowflake

Power BI Desktop includes a native Snowflake connector.

Open **Power BI Desktop**.

Select:

**Home → Get Data → Snowflake**

Enter your Snowflake connection information.

### Server

Enter your Snowflake account/server identifier.

For example:

```text
<account_identifier>.snowflakecomputing.com
```

Depending on your Snowflake account configuration, Power BI may also accept the Snowflake account URL/identifier presented by your Snowflake environment.

### Warehouse

Use a warehouse appropriate for BI workloads.

For example:

```text
COMPUTE_WH
```

### Database

Enter:

```text
APPLE_DB
```

### Authentication

Select the authentication method available in your environment.

For a basic username/password connection:

```text
Username: <your_snowflake_username>
Password: <your_snowflake_password>
```

Use your Snowflake credentials and do not place credentials directly in SQL scripts or Power BI report definitions.

---

## 2. Select the Gold Schema

After connecting to Snowflake, navigate to:

```text
APPLE_DB
    |
    +-- GOLD
         |
         +-- MENU_PROFITABILITY
         +-- MENU_CATEGORY_SUMMARY
         +-- TRUCK_SUMMARY
```

Select the Gold views.

For the primary dashboard, start with:

```text
APPLE_DB.GOLD.MENU_PROFITABILITY
```

and optionally add:

```text
APPLE_DB.GOLD.MENU_CATEGORY_SUMMARY
APPLE_DB.GOLD.TRUCK_SUMMARY
```

Use **Load** to import the data into Power BI, or **DirectQuery** when your reporting architecture requires queries to execute against Snowflake.

---

# SECTION 5 - BUILD A BEAUTIFUL POWER BI DASHBOARD

## 1. Dashboard Goal

Create a professional **Menu Analytics Dashboard** that answers questions such as:

- How many menu items do we have?
- What is the average selling price?
- What is the average gross profit?
- Which menu categories are most profitable?
- Which food trucks have the strongest margins?
- Which menu items have the highest gross profit?
- What percentage of menu items meet different health characteristics?

---

## 2. Recommended Dashboard Layout

### Header

Create a clean title:

```text
MENU ANALYTICS
Snowflake Data Engineering & BI
```

Add a small subtitle:

```text
Bronze → Silver → Gold → Power BI
```

---

## 3. KPI Cards

Place four KPI cards across the top.

### Card 1 — Menu Items

Use:

```text
COUNT(MENU_ITEM_ID)
```

Label:

```text
Total Menu Items
```

### Card 2 — Average Price

Use:

```text
AVERAGE(SALE_PRICE_USD)
```

Label:

```text
Average Sale Price
```

### Card 3 — Average Gross Profit

Use:

```text
AVERAGE(GROSS_PROFIT_USD)
```

Label:

```text
Average Gross Profit
```

### Card 4 — Average Gross Margin

Use:

```text
AVERAGE(GROSS_MARGIN_PERCENT)
```

Label:

```text
Average Gross Margin %
```

---

## 4. Recommended Charts

### Chart 1 — Profitability by Category

Use a clustered bar chart.

**Axis:**

```text
ITEM_CATEGORY
```

**Value:**

```text
AVG(GROSS_PROFIT_USD)
```

Sort descending by gross profit.

This immediately shows which menu categories generate the strongest average profit.

---

### Chart 2 — Top 10 Menu Items

Use a horizontal bar chart.

**Axis:**

```text
MENU_ITEM_NAME
```

**Value:**

```text
GROSS_PROFIT_USD
```

Apply a visual-level filter:

```text
Top N → 10
```

Sort from highest to lowest.

---

### Chart 3 — Food Truck Performance

Use a clustered column chart.

**Axis:**

```text
TRUCK_BRAND_NAME
```

**Values:**

```text
AVG(GROSS_PROFIT_USD)
AVG(GROSS_MARGIN_PERCENT)
```

This provides a comparison of profitability across food truck brands.

---

### Chart 4 — Menu Category Mix

Use a donut chart.

**Legend:**

```text
ITEM_CATEGORY
```

**Values:**

```text
COUNT(MENU_ITEM_ID)
```

This shows the composition of the menu.

---

### Chart 5 — Health Characteristics

Create a bar chart showing counts of menu items by health characteristic.

Examples:

```text
IS_HEALTHY_FLAG
IS_DAIRY_FREE_FLAG
IS_GLUTEN_FREE_FLAG
IS_NUT_FREE_FLAG
```

You can create separate measures for each characteristic.

For example:

```DAX
Healthy Items =
CALCULATE(
    COUNTROWS('MENU_PROFITABILITY'),
    'MENU_PROFITABILITY'[IS_HEALTHY_FLAG] = "Y"
)
```

---

## 5. Add Dashboard Filters

Add slicers for:

```text
TRUCK_BRAND_NAME
MENU_TYPE
ITEM_CATEGORY
ITEM_SUBCATEGORY
IS_HEALTHY_FLAG
IS_DAIRY_FREE_FLAG
IS_GLUTEN_FREE_FLAG
IS_NUT_FREE_FLAG
```

This allows users to interactively explore the menu data.

---

## 6. Recommended Dashboard Design

A simple professional layout:

```text
┌─────────────────────────────────────────────────────────────┐
│                 MENU ANALYTICS                              │
│             Snowflake → Power BI                            │
├────────────┬────────────┬────────────┬──────────────────────┤
│   ITEMS    │ AVG PRICE  │ AVG PROFIT │ AVG MARGIN           │
├────────────┴────────────┴────────────┴──────────────────────┤
│                                                             │
│  Profitability by Category       │  Menu Category Mix       │
│                                   │                         │
├───────────────────────────────────┼─────────────────────────┤
│                                   │                         │
│  Top 10 Menu Items                │  Food Truck Performance │
│                                   │                         │
├───────────────────────────────────┴─────────────────────────┤
│ Filters: Truck | Type | Category | Healthy | Dietary Flags │
└─────────────────────────────────────────────────────────────┘
```

Keep the design clean:

- Use one consistent font.
- Keep the number of colors limited.
- Use whitespace between visuals.
- Avoid unnecessary borders.
- Use descriptive chart titles.
- Format currency as USD.
- Format margins as percentages.
- Sort charts logically.
- Use tooltips to expose additional metrics.
- Keep slicers together rather than scattering them throughout the report.

---

## 7. Suggested Dashboard Story

The dashboard should tell a simple story:

### Page 1 — Executive Overview

Show:

- Total menu items
- Average price
- Average gross profit
- Average gross margin
- Category profitability
- Top menu items
- Food truck performance

### Page 2 — Menu Analysis

Show:

- Menu types
- Categories
- Subcategories
- Pricing distribution
- Ingredient information
- Health attributes

### Page 3 — Profitability

Show:

- Gross profit by item
- Gross margin by category
- Gross profit by food truck
- Highest and lowest margin items

---

# SECTION 6 - END-TO-END ARCHITECTURE

The complete solution now looks like this:

```text
                 S3 PARQUET FILE
                       |
                       v
             +-------------------+
             |   BRONZE STAGE    |
             |    EXT_STAGE      |
             +-------------------+
                       |
                    COPY INTO
                       |
                       v
             +-------------------+
             |  BRONZE.MENU      |
             |     VARIANT       |
             +-------------------+
                       |
                 JSON Parsing
                 & Transformation
                       |
                       v
             +-------------------+
             |  SILVER.MENU      |
             |  DYNAMIC TABLE    |
             +-------------------+
                       |
              Business Aggregation
                       |
                       v
             +-------------------+
             |     GOLD          |
             |   Analytical      |
             |     Views         |
             +-------------------+
                       |
                       v
             +-------------------+
             |     POWER BI      |
             |    Dashboard      |
             +-------------------+
```

This demonstrates a complete Snowflake data engineering workflow: **ingest raw semi-structured data, preserve it in Bronze, transform it into Silver using a Dynamic Table, create business-ready Gold views, and present the results through Power BI.**
