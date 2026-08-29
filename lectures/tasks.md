# Tasks in Snowflake

Automate and schedule SQL operations using Snowflake Tasks.

---

## What is a Task?

A Task is a scheduled object in Snowflake that runs a SQL statement (or calls a stored procedure) on a defined schedule. Think of it as Snowflake's built-in **cron job**.

Key characteristics:
- Runs on a schedule (CRON or interval)
- Can call procedures, run SQL, or trigger pipelines
- Can form DAGs (chains of dependent tasks)
- Created in a **suspended** state — you must explicitly resume them
- Can be serverless (no warehouse needed) or warehouse-bound

---

## Part 1: Your First Task

### Create a Simple Scheduled Task

Let's start by scheduling our `hello_world` procedure from the stored procedures lesson.

```sql
CREATE OR REPLACE TASK GENERAL.PUBLIC.hello_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '1 MINUTE'
AS
    CALL hello_world();
```

**Important:** Tasks are created **suspended** by default. They won't run until you resume them.

### Check Task Status

```sql
SHOW TASKS IN SCHEMA GENERAL.PUBLIC;
```

Look at the `state` column — it will say `suspended`.

### Resume the Task

```sql
ALTER TASK GENERAL.PUBLIC.hello_task RESUME;
```

Now the task will execute every 1 minute.

### Suspend the Task

```sql
ALTER TASK GENERAL.PUBLIC.hello_task SUSPEND;
```

Always suspend tasks when you're done testing to avoid unnecessary credit usage.

---

## Part 2: CRON Scheduling

The interval format (`'1 MINUTE'`, `'5 MINUTES'`, `'1 HOUR'`) is simple but limited. For precise schedules, use CRON syntax.

### CRON Format

```
USING CRON <minute> <hour> <day-of-month> <month> <day-of-week> <timezone>
```

| Field | Values |
|-------|--------|
| Minute | 0–59 |
| Hour | 0–23 |
| Day of month | 1–31 |
| Month | 1–12 |
| Day of week | 0–6 (Sun=0) |
| Timezone | e.g. `America/New_York`, `UTC` |

### Examples

```sql
-- Every day at 6:00 AM UTC
CREATE OR REPLACE TASK GENERAL.PUBLIC.daily_morning_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
AS
    SELECT 'Good morning!';

-- Every Monday at 9:00 AM Lagos time
CREATE OR REPLACE TASK GENERAL.PUBLIC.weekly_monday_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 9 * * 1 Africa/Lagos'
AS
    SELECT 'Start of the week!';

-- Every 15 minutes (using interval instead of CRON)
CREATE OR REPLACE TASK GENERAL.PUBLIC.frequent_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '15 MINUTE'
AS
    SELECT 1;
```

---

## Part 3: Tasks That Do Real Work

### Task That Runs a SQL Statement

```sql
CREATE OR REPLACE TASK GENERAL.PUBLIC.refresh_conditions_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '60 MINUTE'
AS
    CREATE OR REPLACE TABLE GENERAL.TRANSFORMED.CURRENT_CONDITIONS AS
    SELECT
        nearest_area[0]:areaName[0].value::VARCHAR AS city,
        nearest_area[0]:country[0].value::VARCHAR AS country,
        current_condition[0]:temp_C::NUMBER AS temp_c,
        current_condition[0]:humidity::NUMBER AS humidity_pct,
        current_condition[0]:weatherDesc[0].value::VARCHAR AS weather_description,
        CURRENT_TIMESTAMP() AS refreshed_at
    FROM GENERAL.PUBLIC.WEATHER1;
```

### Task That Calls a Stored Procedure

```sql
-- Using our transform procedure from the stored_procedures lesson
CREATE OR REPLACE TASK GENERAL.PUBLIC.transform_weather_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 */6 * * * UTC'  -- Every 6 hours
AS
    CALL GENERAL.TRANSFORMED.transform_weather();
```

---

## Part 4: Task Chains (DAGs)

Tasks can depend on other tasks. The child task runs **after** its parent completes successfully.

**Parent-Child Task Relationship:**

```
        ┌───────────────────────────────┐
        │     pipeline_step1_load       │  ← ROOT TASK (has SCHEDULE)
        │     SCHEDULE = '60 MINUTE'    │
        └───────────────┬───────────────┘
                        │
                        │  executes AFTER step 1 succeeds
                        ▼
        ┌───────────────────────────────────┐
        │   pipeline_step2_transform        │  ← CHILD TASK (no schedule)
        │   AFTER pipeline_step1_load       │
        └───────────────┬───────────────────┘
                        │
                        │  executes AFTER step 2 succeeds
                        ▼
        ┌───────────────────────────────────────┐
        │       pipeline_step3_log              │  ← GRANDCHILD TASK
        │   AFTER pipeline_step2_transform      │
        └───────────────────────────────────────┘


    ╔══════════════════════════════════════════════════════════════╗
    ║  TO RESUME:   resume children FIRST, then root (bottom-up) ║
    ║  TO SUSPEND:  suspend root FIRST, then children (top-down) ║
    ╚══════════════════════════════════════════════════════════════╝
```

### Create a Pipeline: Load → Transform → Log



```sql
-- Root task (has a schedule)
CREATE OR REPLACE TASK GENERAL.PUBLIC.pipeline_step1_load
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '60 MINUTE'
AS
    -- Simulate a load step
    CREATE OR REPLACE TEMPORARY TABLE GENERAL.PUBLIC.staging_temp AS
    SELECT * FROM GENERAL.PUBLIC.WEATHER1;

-- Child task (runs AFTER step 1 — no schedule, uses AFTER keyword)
CREATE OR REPLACE TASK GENERAL.PUBLIC.pipeline_step2_transform
    WAREHOUSE = COMPUTE_WH
    AFTER GENERAL.PUBLIC.pipeline_step1_load
AS
    CREATE OR REPLACE TABLE GENERAL.TRANSFORMED.CURRENT_CONDITIONS AS
    SELECT
        nearest_area[0]:areaName[0].value::VARCHAR AS city,
        current_condition[0]:temp_C::NUMBER AS temp_c,
        current_condition[0]:humidity::NUMBER AS humidity_pct,
        CURRENT_TIMESTAMP() AS transformed_at
    FROM GENERAL.PUBLIC.WEATHER1;

-- Grandchild task (runs AFTER step 2)
CREATE OR REPLACE TASK GENERAL.PUBLIC.pipeline_step3_log
    WAREHOUSE = COMPUTE_WH
    AFTER GENERAL.PUBLIC.pipeline_step2_transform
AS
    INSERT INTO GENERAL.TRANSFORMED.PROCEDURE_LOG (procedure_name, status, message)
    VALUES ('pipeline', 'SUCCESS', 'Pipeline completed at ' || CURRENT_TIMESTAMP()::VARCHAR);
```

### Resuming a DAG

**Important order:** Resume child tasks FIRST, then the root task.

```sql
-- Resume from bottom up
ALTER TASK GENERAL.PUBLIC.pipeline_step3_log RESUME;
ALTER TASK GENERAL.PUBLIC.pipeline_step2_transform RESUME;
ALTER TASK GENERAL.PUBLIC.pipeline_step1_load RESUME;
```

### Suspending a DAG

Suspend in reverse — root task FIRST, then children.

```sql
-- Suspend from top down
ALTER TASK GENERAL.PUBLIC.pipeline_step1_load SUSPEND;
ALTER TASK GENERAL.PUBLIC.pipeline_step2_transform SUSPEND;
ALTER TASK GENERAL.PUBLIC.pipeline_step3_log SUSPEND;
```

---

## Part 5: Monitoring Tasks

### View Task History

```sql
-- See recent task executions
SELECT
    name,
    state,
    scheduled_time,
    completed_time,
    error_code,
    error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 50
))
ORDER BY scheduled_time DESC;
```

### Check If a Task Is Running

```sql
SHOW TASKS IN SCHEMA GENERAL.PUBLIC;
```

Key columns:
- `state` — `started` (active) or `suspended`
- `schedule` — the CRON or interval expression
- `predecessors` — parent tasks (for DAGs)

### Manually Trigger a Task (for testing)

```sql
EXECUTE TASK GENERAL.PUBLIC.hello_task;
```

This runs the task immediately, regardless of its schedule or suspended state.

---

## Part 6: Serverless Tasks

Serverless tasks don't need a warehouse — Snowflake manages the compute automatically. Good for lightweight or unpredictable workloads.

```sql
CREATE OR REPLACE TASK GENERAL.PUBLIC.serverless_hello
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
    SCHEDULE = '5 MINUTE'
AS
    CALL hello_world();
```

Note: No `WAREHOUSE` parameter — instead you specify `USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE`.

---

## Part 7: Task Configuration Options

### Auto-Suspend After Failures

```sql
-- Suspend task after 3 consecutive failures
CREATE OR REPLACE TASK GENERAL.PUBLIC.careful_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '30 MINUTE'
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
AS
    CALL GENERAL.TRANSFORMED.transform_weather();
```

### Task with a Timeout

```sql
CREATE OR REPLACE TASK GENERAL.PUBLIC.bounded_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '60 MINUTE'
    USER_TASK_TIMEOUT_MS = 300000  -- 5 minute timeout
AS
    SELECT 'This will timeout if it takes more than 5 minutes';
```

---

## Part 8: Practical Exercise — Schedule the Weather Pipeline

Let's put it all together with a real pipeline:

```sql
-- Step 1: Create the scheduled task that transforms weather data
CREATE OR REPLACE TASK GENERAL.PUBLIC.weather_etl_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 8,14,20 * * * UTC'  -- Runs at 8am, 2pm, 8pm UTC
    SUSPEND_TASK_AFTER_NUM_FAILURES = 5
AS
    CALL GENERAL.TRANSFORMED.transform_weather();

-- Step 2: Test it manually first
EXECUTE TASK GENERAL.PUBLIC.weather_etl_task;

-- Step 3: Check it worked
SELECT * FROM GENERAL.TRANSFORMED.CURRENT_CONDITIONS;

-- Step 4: If happy, resume for ongoing automation
ALTER TASK GENERAL.PUBLIC.weather_etl_task RESUME;

-- Step 5: Verify it's running
SHOW TASKS LIKE 'weather_etl_task' IN SCHEMA GENERAL.PUBLIC;
```

---

## Cleanup

```sql
-- Suspend and drop all tasks created in this lesson
ALTER TASK IF EXISTS GENERAL.PUBLIC.hello_task SUSPEND;
ALTER TASK IF EXISTS GENERAL.PUBLIC.daily_morning_task SUSPEND;
ALTER TASK IF EXISTS GENERAL.PUBLIC.weekly_monday_task SUSPEND;
ALTER TASK IF EXISTS GENERAL.PUBLIC.frequent_task SUSPEND;
ALTER TASK IF EXISTS GENERAL.PUBLIC.refresh_conditions_task SUSPEND;
ALTER TASK IF EXISTS GENERAL.PUBLIC.transform_weather_task SUSPEND;
ALTER TASK IF EXISTS GENERAL.PUBLIC.pipeline_step1_load SUSPEND;
ALTER TASK IF EXISTS GENERAL.PUBLIC.pipeline_step2_transform SUSPEND;
ALTER TASK IF EXISTS GENERAL.PUBLIC.pipeline_step3_log SUSPEND;
ALTER TASK IF EXISTS GENERAL.PUBLIC.serverless_hello SUSPEND;
ALTER TASK IF EXISTS GENERAL.PUBLIC.careful_task SUSPEND;
ALTER TASK IF EXISTS GENERAL.PUBLIC.bounded_task SUSPEND;
ALTER TASK IF EXISTS GENERAL.PUBLIC.weather_etl_task SUSPEND;

-- Then drop them
DROP TASK IF EXISTS GENERAL.PUBLIC.hello_task;
DROP TASK IF EXISTS GENERAL.PUBLIC.daily_morning_task;
DROP TASK IF EXISTS GENERAL.PUBLIC.weekly_monday_task;
DROP TASK IF EXISTS GENERAL.PUBLIC.frequent_task;
DROP TASK IF EXISTS GENERAL.PUBLIC.refresh_conditions_task;
DROP TASK IF EXISTS GENERAL.PUBLIC.transform_weather_task;
DROP TASK IF EXISTS GENERAL.PUBLIC.pipeline_step3_log;
DROP TASK IF EXISTS GENERAL.PUBLIC.pipeline_step2_transform;
DROP TASK IF EXISTS GENERAL.PUBLIC.pipeline_step1_load;
DROP TASK IF EXISTS GENERAL.PUBLIC.serverless_hello;
DROP TASK IF EXISTS GENERAL.PUBLIC.careful_task;
DROP TASK IF EXISTS GENERAL.PUBLIC.bounded_task;
DROP TASK IF EXISTS GENERAL.PUBLIC.weather_etl_task;
```

---

## Quick Reference

| Action | Syntax |
|--------|--------|
| Create task (interval) | `CREATE TASK t WAREHOUSE=W SCHEDULE='5 MINUTE' AS ...` |
| Create task (CRON) | `CREATE TASK t WAREHOUSE=W SCHEDULE='USING CRON 0 6 * * * UTC' AS ...` |
| Create child task | `CREATE TASK child WAREHOUSE=W AFTER parent_task AS ...` |
| Resume | `ALTER TASK t RESUME;` |
| Suspend | `ALTER TASK t SUSPEND;` |
| Run manually | `EXECUTE TASK t;` |
| View history | `SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(...))` |
| Drop | `DROP TASK t;` (must be suspended first) |

---

---

## Advanced Section: Streams + Tasks (Event-Driven Pipelines)

> **Note:** This section covers Streams — Snowflake's Change Data Capture (CDC) mechanism. Streams paired with Tasks enable event-driven pipelines that only process NEW data.

### What is a Stream?

A Stream tracks changes (INSERT, UPDATE, DELETE) on a table since the last time it was consumed. Think of it as a **bookmark** that remembers what's new.

```sql
-- Create a stream on the weather table
CREATE OR REPLACE STREAM GENERAL.PUBLIC.weather_stream
    ON TABLE GENERAL.PUBLIC.WEATHER1;
```

### How Streams Work

When you query a stream, it shows rows that changed since the last DML that consumed it:

```sql
-- See what's new (won't consume the stream — just a peek)
SELECT * FROM GENERAL.PUBLIC.weather_stream;
```

Each row has metadata columns:
- `METADATA$ACTION` — `INSERT` or `DELETE`
- `METADATA$ISUPDATE` — `TRUE` if this is part of an UPDATE (shows as DELETE + INSERT)
- `METADATA$ROW_ID` — unique row identifier

### Stream + Task: Only Process New Data

The magic is in `SYSTEM$STREAM_HAS_DATA()` — it tells the task to only run when there's new data:

```sql
-- Task that only fires when new data arrives
CREATE OR REPLACE TASK GENERAL.PUBLIC.process_new_weather
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('GENERAL.PUBLIC.WEATHER_STREAM')
AS
    INSERT INTO GENERAL.TRANSFORMED.CURRENT_CONDITIONS
    SELECT
        nearest_area[0]:areaName[0].value::VARCHAR AS city,
        nearest_area[0]:country[0].value::VARCHAR AS country,
        current_condition[0]:temp_C::NUMBER AS temp_c,
        current_condition[0]:humidity::NUMBER AS humidity_pct,
        current_condition[0]:weatherDesc[0].value::VARCHAR AS weather_description,
        CURRENT_TIMESTAMP() AS refreshed_at
    FROM GENERAL.PUBLIC.weather_stream
    WHERE METADATA$ACTION = 'INSERT';
```

**How this works:**
1. Task checks every 1 minute: "Does the stream have new data?"
2. If NO → task skips (no credits used)
3. If YES → task runs the INSERT, which **consumes** the stream (resets the bookmark)
4. Next check finds nothing new, skips again... until more data arrives

### Stream Types

| Type | Tracks | Use Case |
|------|--------|----------|
| Standard | INSERT + UPDATE + DELETE | Full CDC, SCD Type 2 |
| Append-only | INSERT only | Log tables, event data |
| Insert-only | INSERT only (on external tables) | External data |

```sql
-- Append-only stream (ignores updates and deletes)
CREATE OR REPLACE STREAM GENERAL.PUBLIC.weather_append_stream
    ON TABLE GENERAL.PUBLIC.WEATHER1
    APPEND_ONLY = TRUE;
```

### Full Pattern: Incremental Pipeline

```sql
-- 1. Source table
-- (GENERAL.PUBLIC.WEATHER1 already exists)

-- 2. Stream to track changes
CREATE OR REPLACE STREAM GENERAL.PUBLIC.weather_changes
    ON TABLE GENERAL.PUBLIC.WEATHER1;

-- 3. Target table (if not exists)
CREATE TABLE IF NOT EXISTS GENERAL.TRANSFORMED.WEATHER_INCREMENTAL (
    city VARCHAR,
    country VARCHAR,
    temp_c NUMBER,
    humidity_pct NUMBER,
    weather_description VARCHAR,
    loaded_at TIMESTAMP
);

-- 4. Task that processes only new rows
CREATE OR REPLACE TASK GENERAL.PUBLIC.incremental_weather_load
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('GENERAL.PUBLIC.WEATHER_CHANGES')
AS
    INSERT INTO GENERAL.TRANSFORMED.WEATHER_INCREMENTAL
    SELECT
        nearest_area[0]:areaName[0].value::VARCHAR,
        nearest_area[0]:country[0].value::VARCHAR,
        current_condition[0]:temp_C::NUMBER,
        current_condition[0]:humidity::NUMBER,
        current_condition[0]:weatherDesc[0].value::VARCHAR,
        CURRENT_TIMESTAMP()
    FROM GENERAL.PUBLIC.weather_changes
    WHERE METADATA$ACTION = 'INSERT';

-- 5. Resume
ALTER TASK GENERAL.PUBLIC.incremental_weather_load RESUME;

-- 6. Test: Insert new data into source and watch the stream trigger the task
-- (Load more cities via the UI or INSERT)
```

### Checking Stream Status

```sql
-- See if stream has unconsumed data
SELECT SYSTEM$STREAM_HAS_DATA('GENERAL.PUBLIC.WEATHER_CHANGES');

-- View stream metadata
SHOW STREAMS IN SCHEMA GENERAL.PUBLIC;
```

### Stream Staleness Warning

Streams go **stale** if the data retention period on the source table expires before the stream is consumed. A stale stream is unusable — you must recreate it.

```sql
-- Check retention (default is 1 day for standard edition)
SHOW TABLES LIKE 'WEATHER1' IN SCHEMA GENERAL.PUBLIC;
-- Look at 'retention_time' column

-- Increase retention to avoid stale streams
ALTER TABLE GENERAL.PUBLIC.WEATHER1 SET DATA_RETENTION_TIME_IN_DAYS = 14;
```

### Why Streams + Tasks > Regular Scheduled Tasks

| Approach | Behavior | Credits |
|----------|----------|---------|
| Scheduled task (no stream) | Runs EVERY interval, even if nothing changed | Wastes credits |
| Stream + task with WHEN clause | Only runs when new data exists | Efficient |

---

## Exercises

**Basic:**
1. Create a task that calls `hello_world()` every 2 minutes. Resume it, check task history, then suspend.
2. Create a CRON task that runs at noon every weekday.
3. Create a 2-step DAG: first task refreshes `CURRENT_CONDITIONS`, second task logs the completion.
4. Use `EXECUTE TASK` to manually test your DAG.

**Advanced (Streams):**
5. Create a stream on `GENERAL.PUBLIC.WEATHER1`. Load new city data and query the stream to see what's new.
6. Build a stream + task pipeline that incrementally loads only new weather data into `GENERAL.TRANSFORMED.WEATHER_INCREMENTAL`.
7. What happens if you query the stream AFTER the task consumes it? Why?
