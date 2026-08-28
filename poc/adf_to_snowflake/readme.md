# ADF → Snowflake: Crypto Price Ingestion (Demo)

A minimal end-to-end example of ingesting data from a public REST API
(CoinGecko) into Snowflake using Azure Data Factory, on a 3-hour schedule.

## Architecture

```
CoinGecko API  --(Web Activity)-->  ADF Pipeline  --(Script Activity)-->  Snowflake BRONZE.CRYPTO_INGEST
                                          ^
                                   Schedule Trigger
                                   (every 30 min)
```

Raw API responses are landed as `VARCHAR` in a bronze table (audit-friendly,
resilient to shape changes), then flattened into typed columns via a
Snowflake view.

## Prerequisites

- Azure Data Factory instance
- Snowflake account + warehouse/database/schema you can write to
- ADF Snowflake linked service (key pair auth recommended for unattended
  scheduled runs — token/OAuth auth can expire and silently break the trigger)
- No API key needed for CoinGecko's public `/simple/price` endpoint

## Setup

### 1. Snowflake — create the landing table

Run [`sql/01_create_table.sql`](sql/01_create_table.sql).

### 2. Snowflake — create the flattened view

Run [`sql/02_flatten_view.sql`](sql/02_flatten_view.sql).

### 3. Azure Data Factory — linked services

Create two linked services in your ADF instance (not included here, since
these contain environment-specific connection details):

- **REST linked service** — base URL `https://api.coingecko.com`, no auth
- **Snowflake linked service** — your account/warehouse/database/schema,
  key pair authentication recommended

### 4. Azure Data Factory — import the pipeline

In ADF Studio: **Author → Pipelines → Import from pipeline template**, or
manually create a pipeline named `pull_crypto_prices` and paste in the
JSON from [`adf/pipeline_crypto_ingest.json`](adf/pipeline_crypto_ingest.json).

You will need to re-point the two activities at your own linked service
names after import, since linked service references aren't portable
across ADF instances.

Pipeline activities:
1. **pull_from_api** (Web Activity) — GETs current BTC/ETH/SOL prices in USD
2. **insert_to_snowflake** (Script Activity) — builds a clean JSON string
   from the response and inserts it as `VARCHAR` into `BRONZE.CRYPTO_INGEST`

### 5. Azure Data Factory — import the trigger

Create a Schedule trigger named `every_30_min` using
[`adf/trigger_every_30_min.json`](adf/trigger_every_30_min.json) as a
reference, or recreate it manually: **Recurrence = Every 30 minutes**.

Attach the trigger to the pipeline, then **Publish all**.

### 6. Test

Run the pipeline manually first via **Trigger now**, then confirm data
landed:

```sql
SELECT * FROM SILVER.CRYPTO_PRICES ORDER BY INGESTED_AT DESC;
```

## Why land as VARCHAR instead of VARIANT?

Landing the raw string first (rather than `PARSE_JSON()`-ing directly in
the pipeline) makes debugging easier — you can inspect exactly what ADF
sent if something breaks, and a malformed row won't fail the whole
pipeline run. Flattening happens downstream in Snowflake via
`TRY_PARSE_JSON()`, which returns `NULL` instead of erroring on bad data.

## Notes / gotchas

- Web Activity's `output` object includes ADF's own response headers and
  execution metadata alongside the actual API body. Don't stringify the
  whole `output` object into Snowflake — reference only the specific
  fields you need (see the Script Activity's dynamic content), or you'll
  hit JSON parsing errors on unescaped characters inside header values.
- The `activity('pull_from_api')` name in expressions must exactly match
  your Web Activity's name on the canvas.
- CoinGecko's public tier has a modest rate limit, but one call per
  3-hour run is well within it.
