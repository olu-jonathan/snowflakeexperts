# Streams in Snowflake

Change Data Capture (CDC) — track what's new, updated, or deleted in your tables.

---

## What is a Stream?

A Stream is a Snowflake object that records **changes** (inserts, updates, deletes) made to a table since the last time the stream was consumed. It acts as a bookmark or pointer into the table's change history.

```
    ┌─────────────────────────────────────────────────────────────────┐
    │                      BASE TABLE                                  │
    │                                                                  │
    │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  │
    │  │ Row 1│  │ Row 2│  │ Row 3│  │ Row 4│  │ Row 5│  │ Row 6│  │
    │  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘  │
    │                                    ▲                     ▲      │
    │                                    │                     │      │
    └────────────────────────────────────│─────────────────────│──────┘
                                         │                     │
                              ┌──────────┘                     │
                              │                                │
                    ┌─────────┴──────────┐          ┌──────────┴─────────┐
                    │   STREAM OFFSET    │          │    CURRENT STATE   │
                    │  (last consumed)   │          │   (latest change)  │
                    └────────────────────┘          └────────────────────┘
                              │                                │
                              │    ← STREAM SHOWS THESE →      │
                              │        (the delta)             │
                              └────────────────────────────────┘
```

**Key idea:** The stream doesn't store data — it points to a range of changes between two offsets.

---

## How the Offset Works

```
    TIME ──────────────────────────────────────────────────────────►

    ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
    │ INSERT  │     │ INSERT  │     │ UPDATE  │     │ INSERT  │
    │ Row A   │     │ Row B   │     │ Row A   │     │ Row C   │
    └─────────┘     └─────────┘     └─────────┘     └─────────┘
         ▲                                                ▲
         │                                                │
    STREAM OFFSET                                   CURRENT POSITION
    (last consumed)                                 (latest change)

         │◄──────── STREAM RETURNS THESE CHANGES ────────►│
```

When you **consume** a stream (use it in a DML statement like INSERT INTO ... SELECT FROM stream), the offset advances to the current position:

```
    BEFORE CONSUMPTION:
    ────────────[OFFSET]═══════════════════════[CURRENT]────────
                         ▲ stream has data ▲

    AFTER CONSUMPTION (offset advances):
    ═══════════════════════════════════════════[OFFSET/CURRENT]──
                                               ▲ stream is empty ▲
```

---

## Part 1: Creating a Stream

### Setup — Create a Practice Table

```sql
USE DATABASE GENERAL;
USE SCHEMA PUBLIC;

CREATE OR REPLACE TABLE GENERAL.PUBLIC.CUSTOMERS (
    id INTEGER AUTOINCREMENT,
    name VARCHAR(100),
    email VARCHAR(200),
    city VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Insert initial data
INSERT INTO GENERAL.PUBLIC.CUSTOMERS (name, email, city)
SELECT 'Alice', 'alice@example.com', 'Lagos'
UNION ALL SELECT 'Bob', 'bob@example.com', 'London'
UNION ALL SELECT 'Charlie', 'charlie@example.com', 'Tokyo';
```

### Create a Stream on the Table

```sql
CREATE OR REPLACE STREAM GENERAL.PUBLIC.CUSTOMERS_STREAM
    ON TABLE GENERAL.PUBLIC.CUSTOMERS;
```

### Check the Stream — It's Empty

```sql
SELECT * FROM GENERAL.PUBLIC.CUSTOMERS_STREAM;
```

Returns 0 rows. The stream was just created, so its offset is at the current state — nothing is "new" yet.

---

## Part 2: Seeing Changes in the Stream

### Insert New Rows

```sql
INSERT INTO GENERAL.PUBLIC.CUSTOMERS (name, email, city)
SELECT 'Diana', 'diana@example.com', 'Nairobi'
UNION ALL SELECT 'Eve', 'eve@example.com', 'Paris';
```

### Query the Stream

```sql
SELECT * FROM GENERAL.PUBLIC.CUSTOMERS_STREAM;
```

You'll see 2 rows with these metadata columns:

| Column | Description |
|--------|-------------|
| `METADATA$ACTION` | `INSERT` or `DELETE` |
| `METADATA$ISUPDATE` | `TRUE` if this is part of an UPDATE |
| `METADATA$ROW_ID` | Unique identifier for the row |

```
    ┌────┬────────┬───────────────────────┬─────────┬─────────────────┬──────────────────┐
    │ ID │ NAME   │ EMAIL                 │ CITY    │ METADATA$ACTION │ METADATA$ISUPDATE│
    ├────┼────────┼───────────────────────┼─────────┼─────────────────┼──────────────────┤
    │ 4  │ Diana  │ diana@example.com     │ Nairobi │ INSERT          │ FALSE            │
    │ 5  │ Eve    │ eve@example.com       │ Paris   │ INSERT          │ FALSE            │
    └────┴────────┴───────────────────────┴─────────┴─────────────────┴──────────────────┘
```

---

## Part 3: Updates and Deletes in Streams

### Update a Row

```sql
UPDATE GENERAL.PUBLIC.CUSTOMERS SET city = 'Dubai' WHERE name = 'Alice';
```

### Query the Stream Again

```sql
SELECT * FROM GENERAL.PUBLIC.CUSTOMERS_STREAM;
```

An UPDATE appears as a **DELETE of the old row + INSERT of the new row**, both with `METADATA$ISUPDATE = TRUE`:

```
    ┌────┬────────┬───────────────────┬─────────┬─────────────────┬──────────────────┐
    │ ID │ NAME   │ EMAIL             │ CITY    │ METADATA$ACTION │ METADATA$ISUPDATE│
    ├────┼────────┼───────────────────┼─────────┼─────────────────┼──────────────────┤
    │ 4  │ Diana  │ diana@example.com │ Nairobi │ INSERT          │ FALSE            │
    │ 5  │ Eve    │ eve@example.com   │ Paris   │ INSERT          │ FALSE            │
    │ 1  │ Alice  │ alice@example.com │ Lagos   │ DELETE          │ TRUE             │  ← old value
    │ 1  │ Alice  │ alice@example.com │ Dubai   │ INSERT          │ TRUE             │  ← new value
    └────┴────────┴───────────────────┴─────────┴─────────────────┴──────────────────┘
```

### Delete a Row

```sql
DELETE FROM GENERAL.PUBLIC.CUSTOMERS WHERE name = 'Bob';
```

```sql
SELECT * FROM GENERAL.PUBLIC.CUSTOMERS_STREAM;
```

Now you'll also see Bob's row with `METADATA$ACTION = 'DELETE'` and `METADATA$ISUPDATE = FALSE`.

---

## Part 4: Consuming a Stream

A stream is **consumed** when its data is used in a DML transaction (INSERT, MERGE, etc.) that commits successfully.

```sql
-- Create a target table for changes
CREATE OR REPLACE TABLE GENERAL.PUBLIC.CUSTOMERS_CHANGES_LOG (
    customer_id INTEGER,
    name VARCHAR(100),
    email VARCHAR(200),
    city VARCHAR(100),
    action VARCHAR(10),
    is_update BOOLEAN,
    captured_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Consume the stream: INSERT changes into the log
INSERT INTO GENERAL.PUBLIC.CUSTOMERS_CHANGES_LOG (customer_id, name, email, city, action, is_update)
SELECT id, name, email, city, METADATA$ACTION, METADATA$ISUPDATE
FROM GENERAL.PUBLIC.CUSTOMERS_STREAM;
```

### Check the Stream After Consumption

```sql
SELECT * FROM GENERAL.PUBLIC.CUSTOMERS_STREAM;
```

**Empty!** The offset has advanced. The stream now only shows changes made AFTER this point.

```
    BEFORE:  [old offset]════ changes ════[current]
    AFTER:   [offset has moved to current] ──── empty
```

### Verify the Log

```sql
SELECT * FROM GENERAL.PUBLIC.CUSTOMERS_CHANGES_LOG;
```

---

## Part 5: Stream Types

```
    ┌─────────────────────────────────────────────────────────────────────┐
    │                        STREAM TYPES                                   │
    ├─────────────────┬─────────────────────┬─────────────────────────────┤
    │    STANDARD     │    APPEND-ONLY      │      INSERT-ONLY            │
    │  (default)      │                     │  (external tables only)     │
    ├─────────────────┼─────────────────────┼─────────────────────────────┤
    │ Tracks:         │ Tracks:             │ Tracks:                     │
    │ • INSERT        │ • INSERT only       │ • INSERT only               │
    │ • UPDATE        │                     │                             │
    │ • DELETE        │ Ignores:            │ For:                        │
    │                 │ • UPDATE            │ • External tables           │
    │ Use for:        │ • DELETE            │ • Directory tables          │
    │ • Full CDC      │                     │                             │
    │ • SCD Type 2   │ Use for:            │                             │
    │ • Audit logs    │ • Event/log tables  │                             │
    │                 │ • Append-only data  │                             │
    └─────────────────┴─────────────────────┴─────────────────────────────┘
```

### Create an Append-Only Stream

```sql
CREATE OR REPLACE STREAM GENERAL.PUBLIC.CUSTOMERS_APPEND_STREAM
    ON TABLE GENERAL.PUBLIC.CUSTOMERS
    APPEND_ONLY = TRUE;
```

With append-only, updates and deletes are invisible to the stream — only new inserts appear.

---

## Part 6: Stream + Task Pattern

The most common production pattern: a task with a `WHEN` clause that only runs when the stream has data.

```
    ┌──────────────┐          ┌──────────────────┐         ┌──────────────────┐
    │  SOURCE      │  changes │     STREAM       │ trigger │      TASK        │
    │  TABLE       │─────────►│  (tracks delta)  │────────►│  (runs INSERT/   │
    │              │          │                  │         │   MERGE into     │
    └──────────────┘          └──────────────────┘         │   target)        │
                                                           └────────┬─────────┘
                                                                    │
                                                                    ▼
                                                           ┌──────────────────┐
                                                           │   TARGET TABLE   │
                                                           │  (transformed)   │
                                                           └──────────────────┘


    TASK BEHAVIOR:
    ┌────────────────────────────────────────────────────────────────────────┐
    │  Every 1 minute:                                                       │
    │                                                                        │
    │  IF SYSTEM$STREAM_HAS_DATA('stream') = TRUE  →  RUN the SQL           │
    │  IF SYSTEM$STREAM_HAS_DATA('stream') = FALSE →  SKIP (no credits)     │
    └────────────────────────────────────────────────────────────────────────┘
```

### Implementation

```sql
-- 1. Stream (already created)
-- GENERAL.PUBLIC.CUSTOMERS_STREAM

-- 2. Target table
CREATE OR REPLACE TABLE GENERAL.TRANSFORMED.CUSTOMERS_LATEST (
    id INTEGER,
    name VARCHAR(100),
    email VARCHAR(200),
    city VARCHAR(100),
    last_updated TIMESTAMP
);

-- 3. Task that only runs when stream has data
CREATE OR REPLACE TASK GENERAL.PUBLIC.PROCESS_CUSTOMER_CHANGES
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('GENERAL.PUBLIC.CUSTOMERS_STREAM')
AS
    MERGE INTO GENERAL.TRANSFORMED.CUSTOMERS_LATEST t
    USING (
        SELECT id, name, email, city
        FROM GENERAL.PUBLIC.CUSTOMERS_STREAM
        WHERE METADATA$ACTION = 'INSERT'
    ) s
    ON t.id = s.id
    WHEN MATCHED THEN UPDATE SET
        t.name = s.name,
        t.email = s.email,
        t.city = s.city,
        t.last_updated = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (id, name, email, city, last_updated)
        VALUES (s.id, s.name, s.email, s.city, CURRENT_TIMESTAMP());

-- 4. Resume the task
ALTER TASK GENERAL.PUBLIC.PROCESS_CUSTOMER_CHANGES RESUME;
```

### Test It

```sql
-- Insert new data into source
INSERT INTO GENERAL.PUBLIC.CUSTOMERS (name, email, city)
SELECT 'Frank', 'frank@example.com', 'Berlin';

-- Wait ~1 minute, then check target
SELECT * FROM GENERAL.TRANSFORMED.CUSTOMERS_LATEST;
```

---

## Part 7: Multiple Streams on One Table

You can create multiple streams on the same table. Each has its own independent offset.

```
    ┌──────────────────────────────┐
    │        BASE TABLE            │
    │      GENERAL.PUBLIC.CUSTOMERS│
    └──────┬──────────┬────────────┘
           │          │
           ▼          ▼
    ┌────────────┐  ┌────────────────┐
    │  Stream A  │  │   Stream B     │
    │ (for ETL)  │  │ (for audit)    │
    │ offset: 10 │  │ offset: 7      │
    └────────────┘  └────────────────┘
           │                 │
           ▼                 ▼
    ┌────────────┐  ┌────────────────┐
    │  Task A    │  │   Task B       │
    │ (transform)│  │  (log changes) │
    └────────────┘  └────────────────┘
```

Each stream tracks changes independently — consuming Stream A doesn't affect Stream B's offset.

```sql
-- Stream for ETL pipeline
CREATE OR REPLACE STREAM GENERAL.PUBLIC.CUSTOMERS_ETL_STREAM
    ON TABLE GENERAL.PUBLIC.CUSTOMERS;

-- Stream for audit logging
CREATE OR REPLACE STREAM GENERAL.PUBLIC.CUSTOMERS_AUDIT_STREAM
    ON TABLE GENERAL.PUBLIC.CUSTOMERS;
```

---

## Part 8: Stream Staleness

A stream becomes **stale** when the source table's data retention period expires before the stream is consumed. A stale stream cannot be read — you must recreate it.

```
    DATA RETENTION (default 1 day)
    ◄──────────────────────────────────────────────►

    ┌──────────────────────────────────────────────────────────────────────┐
    │                                                                      │
    │  [Stream offset]                                         [NOW]       │
    │       ▲                                                    ▲         │
    │       │                                                    │         │
    │       │◄─── If this gap exceeds retention period ────────►│         │
    │       │         the stream becomes STALE                   │         │
    │                                                                      │
    └──────────────────────────────────────────────────────────────────────┘
```

### Prevention

```sql
-- Check current retention
SHOW TABLES LIKE 'CUSTOMERS' IN SCHEMA GENERAL.PUBLIC;
-- Look at retention_time column

-- Increase retention to prevent stale streams
ALTER TABLE GENERAL.PUBLIC.CUSTOMERS SET DATA_RETENTION_TIME_IN_DAYS = 14;
```

### Check Stream Health

```sql
SHOW STREAMS IN SCHEMA GENERAL.PUBLIC;
-- Look at 'stale' column — should be FALSE
```

---

## Part 9: Streams on Views

You can create streams on views (not just tables). The stream tracks changes to the underlying base tables as seen through the view.

```sql
-- Create a view
CREATE OR REPLACE VIEW GENERAL.PUBLIC.ACTIVE_CUSTOMERS AS
SELECT * FROM GENERAL.PUBLIC.CUSTOMERS WHERE city IS NOT NULL;

-- Stream on the view
CREATE OR REPLACE STREAM GENERAL.PUBLIC.ACTIVE_CUSTOMERS_STREAM
    ON VIEW GENERAL.PUBLIC.ACTIVE_CUSTOMERS;
```

---

## Quick Reference

| Action | Syntax |
|--------|--------|
| Create standard stream | `CREATE STREAM s ON TABLE t;` |
| Create append-only stream | `CREATE STREAM s ON TABLE t APPEND_ONLY = TRUE;` |
| Query stream | `SELECT * FROM stream_name;` |
| Check if stream has data | `SELECT SYSTEM$STREAM_HAS_DATA('stream_name');` |
| Consume stream | Use in DML: `INSERT INTO ... SELECT FROM stream` |
| Task with stream trigger | `WHEN SYSTEM$STREAM_HAS_DATA('stream')` |
| Show streams | `SHOW STREAMS IN SCHEMA db.schema;` |
| Check staleness | `SHOW STREAMS ...` → look at `stale` column |

---

## Full Pipeline Example — End to End

```sql
-- ═══════════════════════════════════════════════════════
-- COMPLETE STREAM + TASK CDC PIPELINE
-- ═══════════════════════════════════════════════════════

-- 1. Source table (already exists: GENERAL.PUBLIC.WEATHER1)

-- 2. Stream
CREATE OR REPLACE STREAM GENERAL.PUBLIC.WEATHER_CDC_STREAM
    ON TABLE GENERAL.PUBLIC.WEATHER1;

-- 3. Target
CREATE TABLE IF NOT EXISTS GENERAL.TRANSFORMED.WEATHER_CDC_LOG (
    city VARCHAR,
    country VARCHAR,
    temp_c NUMBER,
    humidity NUMBER,
    change_action VARCHAR,
    captured_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- 4. Task (event-driven)
CREATE OR REPLACE TASK GENERAL.PUBLIC.WEATHER_CDC_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('GENERAL.PUBLIC.WEATHER_CDC_STREAM')
AS
    INSERT INTO GENERAL.TRANSFORMED.WEATHER_CDC_LOG (city, country, temp_c, humidity, change_action)
    SELECT
        nearest_area[0]:areaName[0].value::VARCHAR,
        nearest_area[0]:country[0].value::VARCHAR,
        current_condition[0]:temp_C::NUMBER,
        current_condition[0]:humidity::NUMBER,
        METADATA$ACTION
    FROM GENERAL.PUBLIC.WEATHER_CDC_STREAM;

-- 5. Resume
ALTER TASK GENERAL.PUBLIC.WEATHER_CDC_TASK RESUME;

-- 6. Test — load new weather data into WEATHER1, wait 1 min, check:
SELECT * FROM GENERAL.TRANSFORMED.WEATHER_CDC_LOG ORDER BY captured_at DESC;
```

---

## Exercises

1. Create a standard stream on `GENERAL.PUBLIC.CUSTOMERS`. Insert 3 rows, query the stream, then consume it with an INSERT INTO a log table. Confirm the stream is empty after.
2. Create an append-only stream on the same table. Update a row and delete a row. Query the stream — what do you see? Why?
3. Build a complete stream + task pipeline on `GENERAL.PUBLIC.WEATHER1` that logs new cities into `GENERAL.TRANSFORMED`.
4. Create two streams on the same table. Consume one but not the other. Verify they have independent offsets.
5. What happens if you SELECT from a stream without using it in a DML? Does the offset advance? Test it.
