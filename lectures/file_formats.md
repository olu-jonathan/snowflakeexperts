# Snowflake File Formats Tutorial

*Co-authored with CoCo*

## What is a File Format?

A file format in Snowflake is a named object that describes the structure of data files stored in stages. It tells Snowflake how to parse incoming data during loading and how to structure outgoing data during unloading.

---

## Supported File Format Types

| Type | Description |
|------|-------------|
| CSV | Comma-separated or delimited text files |
| JSON | Semi-structured JSON data |
| PARQUET | Columnar storage format (read-only for loading) |
| AVRO | Row-based binary format |
| ORC | Optimized Row Columnar format |
| XML | Extensible Markup Language |

---

## Creating a File Format

### CSV Example

```sql
CREATE OR REPLACE FILE FORMAT my_csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  NULL_IF = ('NULL', 'null', '')
  EMPTY_FIELD_AS_NULL = TRUE;
```

### JSON Example

```sql
CREATE OR REPLACE FILE FORMAT my_json_format
  TYPE = 'JSON'
  STRIP_OUTER_ARRAY = TRUE
  IGNORE_UTF8_ERRORS = TRUE;
```

### Parquet Example

```sql
CREATE OR REPLACE FILE FORMAT my_parquet_format
  TYPE = 'PARQUET'
  SNAPPY_COMPRESSION = TRUE;
```

---

## Common CSV Options

| Option | Default | Description |
|--------|---------|-------------|
| FIELD_DELIMITER | `,` | Character separating fields |
| RECORD_DELIMITER | `\n` | Character separating rows |
| SKIP_HEADER | 0 | Number of header lines to skip |
| FIELD_OPTIONALLY_ENCLOSED_BY | None | Quote character around fields |
| NULL_IF | `\\N` | Strings interpreted as NULL |
| ERROR_ON_COLUMN_COUNT_MISMATCH | TRUE | Fail if column count differs |

---

## Using a File Format

### With COPY INTO (Loading Data)

```sql
COPY INTO my_table
  FROM @my_stage/data/
  FILE_FORMAT = (FORMAT_NAME = 'my_csv_format')
  ON_ERROR = 'CONTINUE';
```

### Inline Format (Without a Named Object)

```sql
COPY INTO my_table
  FROM @my_stage/data.csv
  FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = '|'
    SKIP_HEADER = 1
  );
```

### Querying Staged Files Directly

```sql
SELECT $1, $2, $3
  FROM @my_stage/data.csv
  (FILE_FORMAT => 'my_csv_format');
```

---

## Managing File Formats

```sql
-- List all file formats in the current schema
SHOW FILE FORMATS;

-- Describe a specific file format
DESCRIBE FILE FORMAT my_csv_format;

-- Alter an existing file format
ALTER FILE FORMAT my_csv_format
  SET SKIP_HEADER = 2;

-- Drop a file format
DROP FILE FORMAT my_csv_format;
```

---

## Best Practices

1. **Use named file formats** rather than inline definitions for reusability and consistency.
2. **Set ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE** when source files may have trailing delimiters.
3. **Use FIELD_OPTIONALLY_ENCLOSED_BY** for CSV files that contain the delimiter within field values.
4. **Use STRIP_OUTER_ARRAY = TRUE** for JSON files that wrap records in a top-level array.
5. **Prefer Parquet** for large datasets — it's columnar, compressed, and retains type information.

---

## Quick Reference: Loading a CSV End-to-End

```sql
-- 1. Create a file format
CREATE OR REPLACE FILE FORMAT sales_csv
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"';

-- 2. Create a stage using the format
CREATE OR REPLACE STAGE sales_stage
  FILE_FORMAT = sales_csv;

-- 3. Upload a file (via SnowSQL or Snowsight UI)
-- PUT file://path/to/sales.csv @sales_stage;

-- 4. Load into a table
COPY INTO sales_table
  FROM @sales_stage;
```
