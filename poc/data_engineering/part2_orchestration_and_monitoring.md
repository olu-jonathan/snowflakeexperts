# Part 2 — Orchestration and Monitoring in Snowflake

## Overview

In Part 1, we built the core pipeline:

```text
S3 Parquet
    ↓
BRONZE.MENU
    ↓
SILVER.MENU  (Dynamic Table)
    ↓
GOLD views
    ↓
Power BI
```

In Part 2, we add orchestration and monitoring so the pipeline can respond to new Bronze data.

```text
New data
   ↓
BRONZE.MENU
   ↓
BRONZE.MENU_STREAM
   ↓
Triggered parent task
   ↓
Refresh SILVER.MENU
   ↓
Child task
   ↓
Email current Bronze count
   ↓
Gold views
   ↓
Power BI
```

> **Design note:** Dynamic Tables normally manage their own refresh timing through `TARGET_LAG`. For this exercise, we intentionally use an orchestrator-managed Dynamic Table with `SCHEDULER = DISABLE`, allowing a task to explicitly issue `ALTER DYNAMIC TABLE ... REFRESH`. Snowflake documents this as an orchestrator-managed pattern.

---

# SECTION 1 — CREATE THE STREAM

## 1. What Is a Stream?

A Snowflake Stream provides change-data-capture information for a table.

For this project:

```text
    BRONZE.MENU
          |
          v
 BRONZE.MENU_STREAM
```

When new records are inserted into `BRONZE.MENU`, the stream provides the change signal that can be used by a task.

Create the stream:

```sql
CREATE STREAM IF NOT EXISTS BRONZE.MENU_STREAM
ON TABLE BRONZE.MENU;
```

Inspect it:

```sql
SHOW STREAMS
IN SCHEMA BRONZE;
```

Or:

```sql
DESC STREAM BRONZE.MENU_STREAM;
```

---

# SECTION 2 — TEST THE STREAM

## 1. Check for New Data

```sql
SELECT SYSTEM$STREAM_HAS_DATA(
    'BRONZE.MENU_STREAM'
);
```

The function is designed for use in a task `WHEN` condition and indicates whether the stream contains change data.

---

## 2. Add a Test Record

For demonstration purposes:

```sql
INSERT INTO BRONZE.MENU
SELECT PARSE_JSON('
{
  "COST_OF_GOODS_USD": 1.00,
  "ITEM_CATEGORY": "Beverage",
  "ITEM_SUBCATEGORY": "Test",
  "MENU_ID": 99999,
  "MENU_ITEM_HEALTH_METRICS_OBJ": "{"menu_item_health_metrics":[{"ingredients":["Test Beverage"],"is_dairy_free_flag":"Y","is_gluten_free_flag":"Y","is_healthy_flag":"Y","is_nut_free_flag":"Y"}],"menu_item_id":99999}",
  "MENU_ITEM_ID": 99999,
  "MENU_ITEM_NAME": "Test Beverage",
  "MENU_TYPE": "Test",
  "MENU_TYPE_ID": 99,
  "SALE_PRICE_USD": 5.00,
  "TRUCK_BRAND_NAME": "Test Truck"
}');
```

Then:

```sql
SELECT SYSTEM$STREAM_HAS_DATA(
    'BRONZE.MENU_STREAM'
);
```

---

# SECTION 3 — PREPARE THE SILVER DYNAMIC TABLE

For explicit task-controlled orchestration, configure the Dynamic Table with scheduling disabled.

> If you already created the Part 1 Dynamic Table using `TARGET_LAG`, treat this section as the orchestrator-managed version of that design. In a production environment, make changes carefully and account for the existing object's state and dependencies.

```sql
CREATE DYNAMIC TABLE IF NOT EXISTS SILVER.MENU
SCHEDULER = DISABLE
WAREHOUSE = COMPUTE_WH
REFRESH_MODE = INCREMENTAL
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

FROM BRONZE.MENU;
```

Verify:

```sql
SHOW DYNAMIC TABLES
IN SCHEMA SILVER;
```

---

# SECTION 4 — CREATE THE TRIGGERED PARENT TASK

## 1. Task Objective

The parent task watches the Bronze stream:

```text
MENU_STREAM
      |
      | SYSTEM$STREAM_HAS_DATA()
      ↓
MENU_REFRESH_TASK
      |
      | ALTER DYNAMIC TABLE ... REFRESH
      ↓
SILVER.MENU
```

Create it:

```sql
CREATE TASK IF NOT EXISTS BRONZE.MENU_REFRESH_TASK
    WAREHOUSE = COMPUTE_WH
    WHEN SYSTEM$STREAM_HAS_DATA(
        'BRONZE.MENU_STREAM'
    )
AS
    ALTER DYNAMIC TABLE SILVER.MENU REFRESH;
```

A triggered task uses `WHEN SYSTEM$STREAM_HAS_DATA(...)` and runs when change data is detected.

---

## 2. Start the Task

New tasks are suspended by default.

```sql
ALTER TASK BRONZE.MENU_REFRESH_TASK
RESUME;
```

Check it:

```sql
SHOW TASKS
IN SCHEMA BRONZE;
```

---

# SECTION 5 — CREATE EMAIL NOTIFICATION

## 1. Create an Email Integration

Snowflake's `SYSTEM$SEND_EMAIL()` requires an email notification integration.

Your administrator has created one for you titled my_email_int

Check the integration:

```sql
SHOW NOTIFICATION INTEGRATIONS;
```

Email recipients must satisfy Snowflake's notification requirements, including email verification where applicable.

---

# SECTION 6 — TEST SYSTEM$SEND_EMAIL()

Before adding email to the task graph, test it manually:

```sql
CALL SYSTEM$SEND_EMAIL(
    'MY_EMAIL_INT',
    'your.email@example.com',
    'Snowflake Email Test',
    'The Snowflake email notification integration is working.'
);
```

A successful call confirms that the notification integration and recipient configuration are working.

---

# SECTION 7 — CREATE THE CHILD MONITORING TASK

## 1. Child Task Objective

The child task runs **after the parent task succeeds**.

It will:

1. Query the current Bronze row count.
2. Build an email message.
3. Call `SYSTEM$SEND_EMAIL()`.
4. Send the current count to the recipient.

The dependency is:

```text
MENU_REFRESH_TASK
        |
        | AFTER
        ↓
MENU_EMAIL_TASK
```

---

## 2. Create the Child Task

```sql
CREATE TASK IF NOT EXISTS BRONZE.MENU_EMAIL_TASK
    WAREHOUSE = COMPUTE_WH
    AFTER BRONZE.MENU_REFRESH_TASK
AS
    CALL SYSTEM$SEND_EMAIL(
        'MY_EMAIL_INT',
        'your_email@gmail.com',
        'Dynamic Pipeline Update',
        'The data pipeline completed successfully. '
        || 'Current Bronze record count: '
        || (SELECT COUNT(*) FROM BRONZE.MENU)
    );
```

---

## 3. Resume the Child Task

```sql
ALTER TASK BRONZE.MENU_EMAIL_TASK
RESUME;
```

The resulting task graph is:

```text
MENU_REFRESH_TASK
        |
        +---- SUCCESS ----> MENU_EMAIL_TASK
```

---

# SECTION 8 — TEST THE COMPLETE PIPELINE

## Step 1 — Check the Current Bronze Count

```sql
SELECT COUNT(*) AS BRONZE_ROW_COUNT
FROM BRONZE.MENU;
```

---

## Step 2 — Add New Data

```sql
INSERT INTO BRONZE.MENU
SELECT PARSE_JSON('
{
  "COST_OF_GOODS_USD": 2.00,
  "ITEM_CATEGORY": "Food",
  "ITEM_SUBCATEGORY": "Test",
  "MENU_ID": 100000,
  "MENU_ITEM_HEALTH_METRICS_OBJ": "{"menu_item_health_metrics":[{"ingredients":["Test Ingredient 1","Test Ingredient 2"],"is_dairy_free_flag":"Y","is_gluten_free_flag":"Y","is_healthy_flag":"Y","is_nut_free_flag":"Y"}],"menu_item_id":100000}",
  "MENU_ITEM_ID": 100000,
  "MENU_ITEM_NAME": "Orchestration Test Item",
  "MENU_TYPE": "Test",
  "MENU_TYPE_ID": 100,
  "SALE_PRICE_USD": 8.00,
  "TRUCK_BRAND_NAME": "Orchestration Test Truck"
}');
```

---

## Step 3 — Confirm the Stream Detects the Change

```sql
SELECT SYSTEM$STREAM_HAS_DATA(
    'BRONZE.MENU_STREAM'
);
```

---

## Step 4 — Monitor the Parent Task

```sql
SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    ERROR_CODE,
    ERROR_MESSAGE
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        TASK_NAME => 'MENU_REFRESH_TASK',
        RESULT_LIMIT => 20
    )
)
ORDER BY SCHEDULED_TIME DESC;
```

---

## Step 5 — Verify the Silver Dynamic Table

```sql
SELECT *
FROM SILVER.MENU
WHERE MENU_ITEM_ID = 100000;
```

---

## Step 6 — Monitor the Child Task

```sql
SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    ERROR_CODE,
    ERROR_MESSAGE
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        TASK_NAME => 'MENU_EMAIL_TASK',
        RESULT_LIMIT => 20
    )
)
ORDER BY SCHEDULED_TIME DESC;
```

---

# SECTION 9 — MONITORING

## 1. Monitor Task History

Task history helps answer:

- Did the task run?
- Did it succeed?
- When did it start?
- When did it finish?
- Did it fail?
- What error occurred?

```sql
SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    ERROR_CODE,
    ERROR_MESSAGE
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        RESULT_LIMIT => 50
    )
)
ORDER BY SCHEDULED_TIME DESC;
```

---

## 2. Monitor the Dynamic Table

Inspect the object:

```sql
DESC DYNAMIC TABLE SILVER.MENU;
```

Snowflake also provides Dynamic Table refresh history and monitoring views.

Use these to investigate:

- Refresh status
- Refresh duration
- Refresh timing
- Data processed
- Refresh failures

---

## 3. Monitor the Stream

```sql
SHOW STREAMS
IN SCHEMA BRONZE;
```

You can also inspect:

```sql
DESC STREAM BRONZE.MENU_STREAM;
```

---

# SECTION 10 — POWER BI REFRESH

After the orchestration completes:

```text
BRONZE
   ↓
SILVER
   ↓
GOLD
```

the Gold views contain the updated data.

The Power BI behavior depends on the connection mode.

### Import Mode

Power BI stores a copy of the data in the semantic model.

Therefore:

```text
Snowflake task completes
        ↓
Gold data updated
        ↓
Power BI dataset refresh
        ↓
Report reflects new data
```

A Snowflake task completing does **not** by itself force an imported Power BI dataset to refresh.

### DirectQuery

Power BI queries Snowflake when the report requests data, subject to the Power BI model and configuration.

Therefore the logical flow is:

```text
New Bronze Data
      ↓
Stream
      ↓
Task
      ↓
Dynamic Table
      ↓
Gold View
      ↓
Power BI Query
```

---

# SECTION 11 — COMPLETE ARCHITECTURE

```text
                         S3
                          |
                          v
                 +----------------+
                 |   EXT_STAGE    |
                 +----------------+
                          |
                      COPY INTO
                          |
                          v
                 +----------------+
                 |  BRONZE.MENU   |
                 |    VARIANT     |
                 +----------------+
                          |
                          v
                 +----------------+
                 |  MENU_STREAM   |
                 |      CDC       |
                 +----------------+
                          |
              SYSTEM$STREAM_HAS_DATA()
                          |
                          v
                 +--------------------+
                 | MENU_REFRESH_TASK  |
                 |    PARENT TASK     |
                 +--------------------+
                          |
             ALTER DYNAMIC TABLE
                    ... REFRESH
                          |
                          v
                 +----------------+
                 |  SILVER.MENU   |
                 | Dynamic Table  |
                 +----------------+
                          |
                          v
                 +----------------+
                 |   GOLD VIEWS   |
                 +----------------+
                          |
                          v
                 +----------------+
                 |    POWER BI    |
                 +----------------+

                          +
                          |
                       AFTER
                          |
                          v
                 +----------------+
                 | MENU_EMAIL_TASK|
                 |   CHILD TASK   |
                 +----------------+
                          |
                          v
                 SYSTEM$SEND_EMAIL()
                          |
                          v
                       EMAIL
```

---

# SECTION 12 — WHY THIS PATTERN IS USEFUL

This exercise demonstrates several important Snowflake capabilities working together.

### Stream

Detects changes to the Bronze table.

### Triggered Task

Starts processing when the stream contains change data.

### Dynamic Table

Maintains the transformed Silver dataset.

### Task Dependency

Ensures the monitoring task runs after the refresh task succeeds.

### SYSTEM$SEND_EMAIL()

Provides operational notification.

### Gold Views

Expose business-ready data to downstream consumers.

### Power BI

Provides the presentation and analytics layer.

Together:

```text
INGEST
   ↓
DETECT
   ↓
ORCHESTRATE
   ↓
TRANSFORM
   ↓
AGGREGATE
   ↓
PRESENT
   ↓
MONITOR
```

---

# SECTION 13 — IMPORTANT PRODUCTION CONSIDERATIONS

## 1. Dynamic Tables Can Self-Refresh

For many workloads, the simpler architecture is:

```text
BRONZE
   ↓
DYNAMIC TABLE
   ↓
GOLD
   ↓
POWER BI
```

with a suitable `TARGET_LAG`.

Snowflake manages the refresh schedule and dependency ordering.

Use explicit stream/task orchestration when you need:

- Conditional processing
- Notifications
- External side effects
- Custom operational logic
- Existing task-based orchestration
- Explicit control over refresh timing

---

## 2. Be Careful With Stream Consumption

A stream is an offset-based CDC object.

If you build additional downstream processes that actually consume the stream, understand how each process advances the stream offset.

For this exercise, the stream is primarily being used as the signal for the task's `WHEN` condition.

---

## 3. Email Is an Operational Notification

The email should communicate useful operational information, for example:

```text
Snowflake Menu Pipeline Completed

Status: SUCCESS
Bronze Record Count: 125,430
```

For a production implementation, you could expand this to include:

- Pipeline status
- Bronze row count
- Number of new records
- Task execution time
- Dynamic Table refresh status
- Error details
- Pipeline run timestamp

---

# SECTION 14 — FINAL CHECKLIST

At the end of Part 2, you should have:

## Bronze

```text
BRONZE.EXT_STAGE
BRONZE.MENU
BRONZE.MENU_STREAM
```

## Silver

```text
SILVER.MENU
```

## Gold

```text
GOLD.MENU_PROFITABILITY
GOLD.MENU_CATEGORY_SUMMARY
GOLD.TRUCK_SUMMARY
```

## Orchestration

```text
BRONZE.MENU_REFRESH_TASK
BRONZE.MENU_EMAIL_TASK
```

## Notification

```text
APPLE_EMAIL_INT
```

## Presentation

```text
POWER BI
```

---

# SECTION 15 — THE BIG PICTURE

The key lesson is that Snowflake can provide much more than data storage.

You can build an integrated data platform that:

1. **Ingests** data from cloud storage.
2. **Preserves** raw semi-structured data.
3. **Detects** changes with Streams.
4. **Orchestrates** processing with Tasks.
5. **Transforms** data with Dynamic Tables.
6. **Creates** business-ready Gold views.
7. **Notifies** operators with email.
8. **Serves** analytical data to Power BI.

The resulting pattern is:

```text
              SOURCE
                 ↓
             BRONZE
                 ↓
              STREAM
                 ↓
               TASK
                 ↓
              SILVER
                 ↓
               GOLD
                 ↓
             POWER BI

                 +
                 ↓
              MONITOR
                 ↓
               EMAIL
```

This is the foundation for expanding the project into a production-style Snowflake data engineering solution using Snowpipe, additional task graphs, data quality checks, alerts, APIs, dbt, CI/CD, and more sophisticated observability.
