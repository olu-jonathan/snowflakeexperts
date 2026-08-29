# Stored Procedures in Snowflake

A progressive tutorial from basic syntax to building a real transformation pipeline.

---

## What is a Stored Procedure?

A stored procedure is a reusable block of code that:
- Accepts parameters
- Executes SQL statements (one or many)
- Can contain logic (IF/ELSE, loops, variables)
- Runs under caller's or owner's rights
- Can be scheduled via Tasks for automation

Think of it as a **function you save in Snowflake** that you can call anytime.

---

## Part 1: Your First Stored Procedure

### Hello World

```sql
CREATE OR REPLACE PROCEDURE hello_world()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    RETURN 'Hello from Snowflake!';
END;
```

Call it:

```sql
CALL hello_world();
```

---

### With a Parameter

```sql
CREATE OR REPLACE PROCEDURE greet(name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    RETURN 'Hello, ' || name || '!';
END;
```

```sql
CALL greet('Seun');
-- Returns: Hello, Seun!
```

---

## Part 2: Variables and Simple Logic

### Using Variables

```sql
CREATE OR REPLACE PROCEDURE calculate_discount(price NUMBER, discount_pct NUMBER)
RETURNS NUMBER(10,2)
LANGUAGE SQL
AS
DECLARE
    discount_amount NUMBER(10,2);
    final_price NUMBER(10,2);
BEGIN
    discount_amount := price * (discount_pct / 100);
    final_price := price - discount_amount;
    RETURN final_price;
END;
```

```sql
CALL calculate_discount(100, 15);
-- Returns: 85.00
```

### IF / ELSE Logic

```sql
CREATE OR REPLACE PROCEDURE check_temperature(temp_c NUMBER)
RETURNS VARCHAR
LANGUAGE SQL
AS
DECLARE
    result VARCHAR;
BEGIN
    IF (temp_c >= 30) THEN
        result := 'Hot';
    ELSEIF (temp_c >= 20) THEN
        result := 'Warm';
    ELSEIF (temp_c >= 10) THEN
        result := 'Cool';
    ELSE
        result := 'Cold';
    END IF;
    RETURN result;
END;
```

```sql
CALL check_temperature(25);
-- Returns: Warm
```

---

## Part 3: Procedures That Execute SQL

### Create a Table Inside a Procedure

```sql
CREATE OR REPLACE PROCEDURE create_sample_table(table_name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    EXECUTE IMMEDIATE 'CREATE OR REPLACE TABLE ' || table_name || ' (id INT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP())';
    RETURN 'Table ' || table_name || ' created successfully';
END;
```

```sql
CALL create_sample_table('GENERAL.PUBLIC.MY_TEST_TABLE');
```

### Insert and Return Row Count

```sql
CREATE OR REPLACE PROCEDURE insert_and_count(target_table VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
DECLARE
    row_count INTEGER;
BEGIN
    EXECUTE IMMEDIATE 'INSERT INTO ' || target_table || ' (id) SELECT SEQ4() FROM TABLE(GENERATOR(ROWCOUNT => 10))';
    
    LET rs RESULTSET := (EXECUTE IMMEDIATE 'SELECT COUNT(*) AS cnt FROM ' || target_table);
    LET cur CURSOR FOR rs;
    OPEN cur;
    FETCH cur INTO row_count;
    CLOSE cur;
    
    RETURN 'Inserted rows. Total count: ' || row_count::VARCHAR;
END;
```

```sql
CALL insert_and_count('GENERAL.PUBLIC.MY_TEST_TABLE');
```

---

## Part 4: Procedures with RESULTSET and Cursors

### Loop Through Results

```sql
CREATE OR REPLACE PROCEDURE list_tables_in_schema(db_name VARCHAR, schema_name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
DECLARE
    table_list VARCHAR DEFAULT '';
    tbl_name VARCHAR;
    rs RESULTSET;
    cur CURSOR FOR rs;
BEGIN
    rs := (SELECT table_name FROM IDENTIFIER(:db_name || '.INFORMATION_SCHEMA.TABLES') 
           WHERE table_schema = :schema_name AND table_type = 'BASE TABLE'
           ORDER BY table_name);
    OPEN cur;
    
    FOR row_var IN cur DO
        table_list := table_list || row_var.TABLE_NAME || ', ';
    END FOR;
    
    RETURN TRIM(table_list, ', ');
END;
```

```sql
CALL list_tables_in_schema('GENERAL', 'PUBLIC');
```

---

## Part 5: Error Handling

```sql
CREATE OR REPLACE PROCEDURE safe_drop_table(full_table_name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE IF EXISTS ' || full_table_name;
    RETURN 'Table ' || full_table_name || ' dropped successfully';
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error: ' || SQLERRM;
END;
```

```sql
CALL safe_drop_table('GENERAL.PUBLIC.MY_TEST_TABLE');
```

---

## Part 6: Real-World Application — Weather Data Transformation Pipeline

Now let's build a procedure that transforms `GENERAL.PUBLIC.WEATHER1` (VARIANT columns) into 3 structured tables in `GENERAL.TRANSFORMED`.

### Understanding the Source

`GENERAL.PUBLIC.WEATHER1` has these VARIANT columns:
- `CURRENT_CONDITION` — array with current weather readings
- `NEAREST_AREA` — array with location info
- `WEATHER` — array with forecast data including astronomy

### The Transformation Procedure

```sql
CREATE OR REPLACE PROCEDURE GENERAL.TRANSFORMED.transform_weather()
RETURNS VARCHAR
LANGUAGE SQL
AS
DECLARE
    rows_current INTEGER;
    rows_location INTEGER;
    rows_forecast INTEGER;
BEGIN

    -- ============================================
    -- Transformation 1: Current Conditions
    -- Extracts real-time weather readings per city
    -- ============================================
    CREATE OR REPLACE TABLE GENERAL.TRANSFORMED.CURRENT_CONDITIONS AS
    SELECT
        nearest_area[0]:areaName[0].value::VARCHAR AS city,
        nearest_area[0]:country[0].value::VARCHAR AS country,
        current_condition[0]:temp_C::NUMBER AS temp_c,
        current_condition[0]:temp_F::NUMBER AS temp_f,
        current_condition[0]:FeelsLikeC::NUMBER AS feels_like_c,
        current_condition[0]:FeelsLikeF::NUMBER AS feels_like_f,
        current_condition[0]:humidity::NUMBER AS humidity_pct,
        current_condition[0]:cloudcover::NUMBER AS cloud_cover_pct,
        current_condition[0]:pressure::NUMBER AS pressure_mb,
        current_condition[0]:visibility::NUMBER AS visibility_km,
        current_condition[0]:uvIndex::NUMBER AS uv_index,
        current_condition[0]:windspeedKmph::NUMBER AS wind_speed_kmph,
        current_condition[0]:winddir16Point::VARCHAR AS wind_direction,
        current_condition[0]:weatherDesc[0].value::VARCHAR AS weather_description,
        current_condition[0]:precipMM::NUMBER(10,1) AS precipitation_mm,
        current_condition[0]:observation_time::VARCHAR AS observation_time,
        CURRENT_TIMESTAMP() AS transformed_at
    FROM GENERAL.PUBLIC.WEATHER1;

    SELECT COUNT(*) INTO rows_current FROM GENERAL.TRANSFORMED.CURRENT_CONDITIONS;

    -- ============================================
    -- Transformation 2: Location Details
    -- Extracts geographic info per city
    -- ============================================
    CREATE OR REPLACE TABLE GENERAL.TRANSFORMED.LOCATIONS AS
    SELECT
        nearest_area[0]:areaName[0].value::VARCHAR AS city,
        nearest_area[0]:country[0].value::VARCHAR AS country,
        nearest_area[0]:region[0].value::VARCHAR AS region,
        nearest_area[0]:latitude::FLOAT AS latitude,
        nearest_area[0]:longitude::FLOAT AS longitude,
        nearest_area[0]:population::NUMBER AS population,
        CURRENT_TIMESTAMP() AS transformed_at
    FROM GENERAL.PUBLIC.WEATHER1;

    SELECT COUNT(*) INTO rows_location FROM GENERAL.TRANSFORMED.LOCATIONS;

    -- ============================================
    -- Transformation 3: Daily Forecast with Astronomy
    -- Extracts forecast data using LATERAL FLATTEN
    -- ============================================
    CREATE OR REPLACE TABLE GENERAL.TRANSFORMED.DAILY_FORECAST AS
    SELECT
        nearest_area[0]:areaName[0].value::VARCHAR AS city,
        nearest_area[0]:country[0].value::VARCHAR AS country,
        w.value:date::DATE AS forecast_date,
        w.value:maxtempC::NUMBER AS max_temp_c,
        w.value:mintempC::NUMBER AS min_temp_c,
        w.value:avgtempC::NUMBER AS avg_temp_c,
        w.value:totalSnow_cm::NUMBER(10,1) AS total_snow_cm,
        w.value:sunHour::NUMBER(10,1) AS sun_hours,
        w.value:uvIndex::NUMBER AS uv_index,
        w.value:astronomy[0].sunrise::VARCHAR AS sunrise,
        w.value:astronomy[0].sunset::VARCHAR AS sunset,
        w.value:astronomy[0].moon_phase::VARCHAR AS moon_phase,
        CURRENT_TIMESTAMP() AS transformed_at
    FROM GENERAL.PUBLIC.WEATHER1,
    LATERAL FLATTEN(input => weather) w;

    SELECT COUNT(*) INTO rows_forecast FROM GENERAL.TRANSFORMED.DAILY_FORECAST;

    -- ============================================
    -- Return summary
    -- ============================================
    RETURN 'Transformation complete! ' ||
           'CURRENT_CONDITIONS: ' || rows_current::VARCHAR || ' rows, ' ||
           'LOCATIONS: ' || rows_location::VARCHAR || ' rows, ' ||
           'DAILY_FORECAST: ' || rows_forecast::VARCHAR || ' rows.';

END;
```

### Run the Pipeline

```sql
CALL GENERAL.TRANSFORMED.transform_weather();
```

### Verify the Results

```sql
-- Check current conditions
SELECT * FROM GENERAL.TRANSFORMED.CURRENT_CONDITIONS;

-- Check locations
SELECT * FROM GENERAL.TRANSFORMED.LOCATIONS;

-- Check daily forecast (multiple rows per city — one per forecast day)
SELECT * FROM GENERAL.TRANSFORMED.DAILY_FORECAST ORDER BY city, forecast_date;
```

---

## Part 7: Making It Production-Ready

### Add Logging

```sql
CREATE OR REPLACE TABLE GENERAL.TRANSFORMED.PROCEDURE_LOG (
    procedure_name VARCHAR,
    status VARCHAR,
    message VARCHAR,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE PROCEDURE GENERAL.TRANSFORMED.transform_weather_with_logging()
RETURNS VARCHAR
LANGUAGE SQL
AS
DECLARE
    result VARCHAR;
BEGIN

    CALL GENERAL.TRANSFORMED.transform_weather() INTO result;
    
    INSERT INTO GENERAL.TRANSFORMED.PROCEDURE_LOG (procedure_name, status, message)
    VALUES ('transform_weather', 'SUCCESS', :result);
    
    RETURN result;

EXCEPTION
    WHEN OTHER THEN
        INSERT INTO GENERAL.TRANSFORMED.PROCEDURE_LOG (procedure_name, status, message)
        VALUES ('transform_weather', 'FAILED', SQLERRM);
        RETURN 'FAILED: ' || SQLERRM;
END;
```

```sql
CALL GENERAL.TRANSFORMED.transform_weather_with_logging();

-- Check the log
SELECT * FROM GENERAL.TRANSFORMED.PROCEDURE_LOG ORDER BY executed_at DESC;
```

### Schedule with a Task (Preview)

```sql
-- This would run the transformation every hour
CREATE OR REPLACE TASK GENERAL.TRANSFORMED.hourly_weather_transform
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 * * * * America/New_York'
AS
    CALL GENERAL.TRANSFORMED.transform_weather_with_logging();

-- Tasks are created suspended — resume to activate:
-- ALTER TASK GENERAL.TRANSFORMED.hourly_weather_transform RESUME;
```

---

## Quick Reference

| Concept | Syntax |
|---------|--------|
| Create procedure | `CREATE OR REPLACE PROCEDURE name(params) RETURNS type LANGUAGE SQL AS BEGIN ... END;` |
| Declare variable | `DECLARE var_name TYPE [DEFAULT value];` |
| Assign variable | `var_name := expression;` |
| Dynamic SQL | `EXECUTE IMMEDIATE 'SQL string';` |
| SELECT into variable | `SELECT col INTO :var FROM table;` |
| Call procedure | `CALL procedure_name(args);` |
| Call and capture result | `CALL proc() INTO :my_var;` |
| IF logic | `IF (cond) THEN ... ELSEIF ... ELSE ... END IF;` |
| Loop | `FOR row IN cursor DO ... END FOR;` |
| Error handling | `BEGIN ... EXCEPTION WHEN OTHER THEN ... END;` |
| Reference variable in SQL | Use colon prefix: `:var_name` |

---

## Exercises

1. Write a procedure that accepts a city name and returns its current temperature from `GENERAL.TRANSFORMED.CURRENT_CONDITIONS`.
2. Modify `transform_weather` to also create a table `HOURLY_FORECAST` by flattening `weather[]:hourly[]`.
3. Write a procedure that compares two cities and returns which one is warmer.
4. Add a `TRUNCATE` before each `CREATE OR REPLACE` to make the procedure idempotent using `INSERT INTO` instead.
5. Create a procedure that drops all tables in `GENERAL.TRANSFORMED` that are older than 7 days (hint: use `INFORMATION_SCHEMA.TABLES.CREATED`).
