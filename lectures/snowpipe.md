# Snowpipe Tutorial

*Co-authored with CoCo*

## What is Snowpipe?

Snowpipe is Snowflake's continuous data ingestion service. It loads data from files as soon as they arrive in a stage — automatically and in near real-time — without requiring manual COPY INTO commands or scheduled tasks.

---

## How Snowpipe Works

1. A file lands in your external stage (e.g., an S3 bucket).
2. An S3 event notification triggers Snowpipe.
3. Snowpipe queues the file and loads it into the target table within seconds.

Snowpipe uses serverless compute managed by Snowflake (no warehouse needed).

---

## Prerequisites

- `my_s3_stage` already created and pointing to your S3 bucket
- Create a new folder called `for_snowpipe` in your S3 bucket (this keeps Snowpipe files separate from other data)

---

## Step 1: Create a Target Table

```sql
CREATE OR REPLACE TABLE snowpipe_demo (
  id INT,
  name STRING,
  amount DECIMAL(10,2),
  created_at TIMESTAMP
);
```

---

## Step 2: Create a File Format

```sql
CREATE OR REPLACE FILE FORMAT snowpipe_csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  NULL_IF = ('NULL', 'null', '');
```

---

## Step 3: Create the Pipe

```sql
CREATE OR REPLACE PIPE my_snowpipe
  AUTO_INGEST = TRUE
  AS
  COPY INTO snowpipe_demo
    FROM @my_s3_stage/for_snowpipe/
    FILE_FORMAT = (FORMAT_NAME = 'snowpipe_csv_format');
```

The `AUTO_INGEST = TRUE` setting enables automatic loading triggered by S3 event notifications.

---

## Step 4: Get the SQS ARN for Event Notifications

Run the following to retrieve the notification channel ARN:

```sql
SHOW PIPES;
```

Look for the `notification_channel` column in the output. It will look something like:

```
arn:aws:sqs:us-east-1:123456789012:sf-snowpipe-AIDAXXXXXXXXXXXXXXX-...
```

Copy this value — you need it to configure S3 notifications.

---

## Step 5: Configure S3 Event Notifications

In the AWS Console:

1. Navigate to your S3 bucket.
2. Go to **Properties** → **Event notifications** → **Create event notification**.
3. Configure:
   - **Name:** `snowpipe-notification`
   - **Prefix:** `for_snowpipe/`
   - **Event types:** Select `All object create events`
   - **Destination:** Choose **SQS Queue** → **Enter SQS queue ARN**
   - **SQS ARN:** Paste the `notification_channel` value from Step 4.
4. Save the event notification.

---

## Step 6: Test It

Upload a test CSV file to `s3://your-bucket/for_snowpipe/`:

```csv
id,name,amount,created_at
1,Alice,150.00,2025-01-15 10:30:00
2,Bob,275.50,2025-01-15 11:00:00
3,Charlie,89.99,2025-01-15 11:30:00
```

Wait 30–60 seconds, then check your table:

```sql
SELECT * FROM snowpipe_demo;
```

---

## Monitoring Snowpipe

### Check Pipe Status

```sql
SELECT SYSTEM$PIPE_STATUS('my_snowpipe');
```

This returns JSON showing the current state, pending files, and last received message timestamp.

### View Load History

```sql
SELECT *
  FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'SNOWPIPE_DEMO',
    START_TIME => DATEADD('hour', -24, CURRENT_TIMESTAMP())
  ))
  ORDER BY LAST_LOAD_TIME DESC;
```

### Check for Errors

```sql
SELECT *
  FROM TABLE(VALIDATE_PIPE_LOAD(
    PIPE_NAME => 'my_snowpipe',
    START_TIME => DATEADD('hour', -1, CURRENT_TIMESTAMP())
  ));
```

---

## Managing Snowpipe

### Pause a Pipe

```sql
ALTER PIPE my_snowpipe SET PIPE_EXECUTION_PAUSED = TRUE;
```

### Resume a Pipe

```sql
ALTER PIPE my_snowpipe SET PIPE_EXECUTION_PAUSED = FALSE;
```

### Manually Refresh (Load Missed Files)

If files landed before event notifications were configured:

```sql
ALTER PIPE my_snowpipe REFRESH;
```

### Drop a Pipe

```sql
DROP PIPE my_snowpipe;
```

---

## Important Notes

- Snowpipe tracks which files have already been loaded (by file name). Re-uploading a file with the same name will **not** reload it.
- To reload a file, rename it or use a different file name.
- Snowpipe charges are based on serverless compute time, not warehouse credits.
- File load metadata is retained for **14 days**.

---

## Summary

| Step | Action |
|------|--------|
| 1 | Create target table |
| 2 | Create file format |
| 3 | Create pipe with AUTO_INGEST = TRUE |
| 4 | Get SQS ARN from SHOW PIPES |
| 5 | Configure S3 event notification in AWS |
| 6 | Upload a file and verify the data loaded |
