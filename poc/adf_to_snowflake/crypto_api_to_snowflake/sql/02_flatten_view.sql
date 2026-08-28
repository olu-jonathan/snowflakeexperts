-- Flattens BRONZE.CRYPTO_INGEST into typed columns.
-- TRY_PARSE_JSON returns NULL on malformed rows instead of erroring,
-- so a single bad payload won't break downstream queries.

CREATE SCHEMA IF NOT EXISTS SILVER;

CREATE OR REPLACE VIEW SILVER.CRYPTO_PRICES AS
SELECT
    RUN_ID,
    INGESTED_AT,
    TRY_PARSE_JSON(PAYLOAD):bitcoin.usd::FLOAT   AS BTC_USD,
    TRY_PARSE_JSON(PAYLOAD):ethereum.usd::FLOAT  AS ETH_USD,
    TRY_PARSE_JSON(PAYLOAD):solana.usd::FLOAT    AS SOL_USD
FROM BRONZE.CRYPTO_INGEST;

-- Example usage:
-- SELECT * FROM SILVER.CRYPTO_PRICES ORDER BY INGESTED_AT DESC;
