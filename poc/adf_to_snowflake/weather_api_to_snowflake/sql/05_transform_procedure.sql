-- Create a stored procedure to transform the weather data from the RAW.WEATHER table into the TRANSFORMED.WEATHER_DATA table. The stored procedure will extract the relevant fields from the JSON response and insert them into the transformed table.
CREATE OR REPLACE PROCEDURE RAW.TRANSFORM_WEATHER()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS 'BEGIN
    INSERT INTO TRANSFORMED.WEATHER_DATA 
    SELECT
        -- Location fields from NEAREST_AREA
        NEAREST_AREA[0]:areaName[0].value::VARCHAR AS AREA_NAME,
        NEAREST_AREA[0]:country[0].value::VARCHAR AS COUNTRY,
        NEAREST_AREA[0]:region[0].value::VARCHAR AS REGION,
        NEAREST_AREA[0]:latitude::VARCHAR AS LATITUDE,
        NEAREST_AREA[0]:longitude::VARCHAR AS LONGITUDE,
        NEAREST_AREA[0]:population::VARCHAR AS POPULATION,

        -- Current weather conditions from CURRENT_CONDITION
        CURRENT_CONDITION[0]:temp_C::NUMBER AS TEMP_C,
        CURRENT_CONDITION[0]:temp_F::NUMBER AS TEMP_F,
        CURRENT_CONDITION[0]:FeelsLikeC::NUMBER AS FEELS_LIKE_C,
        CURRENT_CONDITION[0]:FeelsLikeF::NUMBER AS FEELS_LIKE_F,
        CURRENT_CONDITION[0]:humidity::NUMBER AS HUMIDITY,
        CURRENT_CONDITION[0]:cloudcover::NUMBER AS CLOUDCOVER,
        CURRENT_CONDITION[0]:pressure::NUMBER AS PRESSURE,
        CURRENT_CONDITION[0]:uvIndex::NUMBER AS UV_INDEX,
        CURRENT_CONDITION[0]:visibility::NUMBER AS VISIBILITY,
        CURRENT_CONDITION[0]:weatherCode::VARCHAR AS WEATHER_CODE,
        CURRENT_CONDITION[0]:weatherDesc[0].value::VARCHAR AS WEATHER_DESC,
        CURRENT_CONDITION[0]:observation_time::VARCHAR AS OBSERVATION_TIME,

        -- Wind data from CURRENT_CONDITION
        CURRENT_CONDITION[0]:windspeedKmph::NUMBER AS WINDSPEED_KMPH,
        CURRENT_CONDITION[0]:windspeedMiles::NUMBER AS WINDSPEED_MILES,
        CURRENT_CONDITION[0]:winddir16Point::VARCHAR AS WIND_DIR_16POINT,
        CURRENT_CONDITION[0]:winddirDegree::NUMBER AS WIND_DIR_DEGREE,

        -- Request info from REQUEST
        REQUEST[0]:query::VARCHAR AS REQUEST_QUERY,
        REQUEST[0]:type::VARCHAR AS REQUEST_TYPE,

        -- Astronomy from WEATHER
        WEATHER[0]:astronomy[0].sunrise::VARCHAR AS SUNRISE,
        WEATHER[0]:astronomy[0].sunset::VARCHAR AS SUNSET,
        CURRENT_TIMESTAMP() AS INSERT_AT


    FROM RAW.WEATHER;

    RETURN ''Weather data transformed successfully. Rows inserted: '' || (SELECT COUNT(*) FROM TRANSFORMED.WEATHER_DATA)::VARCHAR;
END';