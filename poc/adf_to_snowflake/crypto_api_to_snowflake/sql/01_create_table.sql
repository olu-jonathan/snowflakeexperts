-- Bronze landing table for raw API responses.
-- PAYLOAD is stored as VARCHAR (not VARIANT) so that malformed or
-- unexpected responses can still land without failing the pipeline.
-- Parsing/validation happens downstream via TRY_PARSE_JSON().

CREATE SCHEMA IF NOT EXISTS BRONZE;

CREATE TABLE IF NOT EXISTS BRONZE.CRYPTO_INGEST (
    RUN_ID       STRING,
    INGESTED_AT  TIMESTAMP_NTZ,
    PAYLOAD      VARCHAR
);
