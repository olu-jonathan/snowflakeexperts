    -- Create a table to store the weather data. This table will have a single column of type VARIANT to store the JSON response from the weather API.
    create or replace TABLE RAW.WEATHER (
	CURRENT_CONDITION VARIANT,
	NEAREST_AREA VARIANT,
	REQUEST VARIANT,
	WEATHER VARIANT
);