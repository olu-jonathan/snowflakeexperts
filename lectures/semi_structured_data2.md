# Semi-Structured Data Tutorial 2: Real Weather API Data

Hands-on exercise loading real JSON from the wttr.in weather API into Snowflake.

---

## Objective

Load real-world JSON data from a public weather API, store it as native VARIANT columns, query it with dot notation, create a view, then observe how the view automatically reflects new data loads.

---

## Step 1: Query Weather Data for 3 Cities

Open your browser and visit the following URL format to get weather JSON for any city:

```
https://wttr.in/<city_name>?format=j1
```

**Do this for 3 cities of your choice.** For example:
- https://wttr.in/kansas?format=j1
- https://wttr.in/lagos?format=j1
- https://wttr.in/london?format=j1

Each response is a JSON object with `current_condition`, `nearest_area`, `request`, and `weather` arrays.

---

## Step 2: Combine Responses into a JSON File

1. Open a text editor (Notepad, VS Code, etc.)
2. Create a JSON array by wrapping all 3 responses in square brackets, separated by commas:

```json

  { <paste full response for city 1> },
  { <paste full response for city 2> },
  { <paste full response for city 3> }

```

3. Save the file as `weather.json`

---

## Step 3: Load into Snowflake via the UI

1. Navigate to your database → `RAW` schema
2. Click **Create** → **Table** → **From File**
3. Upload your `weather.json` file
4. Name the table: `WEATHER`
5. **IMPORTANT settings:**
   - **Uncheck** "Load as a single variant" — this splits the top-level keys into separate columns
   - **Ensure** each resulting column (`CURRENT_CONDITION`, `NEAREST_AREA`, `REQUEST`, `WEATHER`) is type **VARIANT**, not VARCHAR
6. Click **Load**

If the columns come through as VARCHAR instead of VARIANT, the dot notation queries won't work without `PARSE_JSON()`. Double-check the column types:

```sql
DESCRIBE TABLE RAW.WEATHER;
```

All columns except any auto-generated row ID should show `VARIANT` as the data type.

---

## Step 4: Verify Your Data

```sql
SELECT * FROM RAW.WEATHER;
```

You should see 3 rows (one per city), with each column containing a JSON array.

---

## Step 5: Query with Dot Notation

Since the columns are native VARIANT, no `PARSE_JSON()` is needed. Use `[0]` to access the first element of each array, then `:key` to access fields:

```sql
SELECT
    -- All fields from current_condition
    current_condition[0]:FeelsLikeC::VARCHAR AS feels_like_c,
    current_condition[0]:FeelsLikeF::VARCHAR AS feels_like_f,
    current_condition[0]:cloudcover::VARCHAR AS cloudcover,
    current_condition[0]:humidity::VARCHAR AS humidity,
    current_condition[0]:observation_time::VARCHAR AS observation_time,
    current_condition[0]:precipInches::VARCHAR AS precip_inches,
    current_condition[0]:precipMM::VARCHAR AS precip_mm,
    current_condition[0]:pressure::VARCHAR AS pressure,
    current_condition[0]:pressureInches::VARCHAR AS pressure_inches,
    current_condition[0]:temp_C::VARCHAR AS temp_c,
    current_condition[0]:temp_F::VARCHAR AS temp_f,
    current_condition[0]:uvIndex::VARCHAR AS uv_index,
    current_condition[0]:visibility::VARCHAR AS visibility,
    current_condition[0]:visibilityMiles::VARCHAR AS visibility_miles,
    current_condition[0]:weatherCode::VARCHAR AS weather_code,
    current_condition[0]:weatherDesc[0].value::VARCHAR AS weather_desc,
    current_condition[0]:winddir16Point::VARCHAR AS wind_dir_16point,
    current_condition[0]:winddirDegree::VARCHAR AS wind_dir_degree,
    current_condition[0]:windspeedKmph::VARCHAR AS windspeed_kmph,
    current_condition[0]:windspeedMiles::VARCHAR AS windspeed_miles,

    -- All fields from nearest_area EXCEPT weatherUrl
    nearest_area[0]:areaName[0].value::VARCHAR AS area_name,
    nearest_area[0]:country[0].value::VARCHAR AS country,
    nearest_area[0]:latitude::VARCHAR AS latitude,
    nearest_area[0]:longitude::VARCHAR AS longitude,
    nearest_area[0]:population::VARCHAR AS population,
    nearest_area[0]:region[0].value::VARCHAR AS region,

    -- Sunrise and sunset from weather
    weather[0]:astronomy[0].sunrise::VARCHAR AS sunrise,
    weather[0]:astronomy[0].sunset::VARCHAR AS sunset

FROM RAW.WEATHER;
```

You should see 3 rows with all fields neatly extracted.

---

## Step 6: Create a View to Persist the Query

```sql
CREATE OR REPLACE VIEW RAW.WEATHER_VW AS
SELECT
    -- current_condition fields
    current_condition[0]:FeelsLikeC::VARCHAR AS feels_like_c,
    current_condition[0]:FeelsLikeF::VARCHAR AS feels_like_f,
    current_condition[0]:cloudcover::VARCHAR AS cloudcover,
    current_condition[0]:humidity::VARCHAR AS humidity,
    current_condition[0]:observation_time::VARCHAR AS observation_time,
    current_condition[0]:precipInches::VARCHAR AS precip_inches,
    current_condition[0]:precipMM::VARCHAR AS precip_mm,
    current_condition[0]:pressure::VARCHAR AS pressure,
    current_condition[0]:pressureInches::VARCHAR AS pressure_inches,
    current_condition[0]:temp_C::VARCHAR AS temp_c,
    current_condition[0]:temp_F::VARCHAR AS temp_f,
    current_condition[0]:uvIndex::VARCHAR AS uv_index,
    current_condition[0]:visibility::VARCHAR AS visibility,
    current_condition[0]:visibilityMiles::VARCHAR AS visibility_miles,
    current_condition[0]:weatherCode::VARCHAR AS weather_code,
    current_condition[0]:weatherDesc[0].value::VARCHAR AS weather_desc,
    current_condition[0]:winddir16Point::VARCHAR AS wind_dir_16point,
    current_condition[0]:winddirDegree::VARCHAR AS wind_dir_degree,
    current_condition[0]:windspeedKmph::VARCHAR AS windspeed_kmph,
    current_condition[0]:windspeedMiles::VARCHAR AS windspeed_miles,

    -- nearest_area fields (excluding weatherUrl)
    nearest_area[0]:areaName[0].value::VARCHAR AS area_name,
    nearest_area[0]:country[0].value::VARCHAR AS country,
    nearest_area[0]:latitude::VARCHAR AS latitude,
    nearest_area[0]:longitude::VARCHAR AS longitude,
    nearest_area[0]:population::VARCHAR AS population,
    nearest_area[0]:region[0].value::VARCHAR AS region,

    -- weather astronomy fields
    weather[0]:astronomy[0].sunrise::VARCHAR AS sunrise,
    weather[0]:astronomy[0].sunset::VARCHAR AS sunset

FROM RAW.WEATHER;
```

Verify it works:

```sql
SELECT * FROM RAW.WEATHER_VW;
```

---

## Step 7: Query 5 New Cities

Go back to your browser and query 5 **different** cities:

```
https://wttr.in/tokyo?format=j1
https://wttr.in/paris?format=j1
https://wttr.in/dubai?format=j1
https://wttr.in/sydney?format=j1
https://wttr.in/nairobi?format=j1
```

Combine all 5 into a new `weather2.json` file using the same format:

```json

  { <city 1 response> },
  { <city 2 response> },
  { <city 3 response> },
  { <city 4 response> },
  { <city 5 response> }

```

---

## Step 8: Load into the EXISTING Weather Table

1. Navigate to your `RAW.WEATHER` table
2. Click **Load Data** (not "Create Table From File")
3. Upload `weather2.json`
4. Use the same settings as before (uncheck "Load as single variant", ensure VARIANT types)
5. Load the data

---

## Step 9: Observe the View

```sql
SELECT * FROM RAW.WEATHER_VW;
```

**What you should see:** The view now returns **8 rows** (3 original + 5 new) without any changes to the view definition.

This demonstrates a key concept: **views are live queries** — they always reflect the current state of the underlying table. When you add data to the base table, the view automatically includes it.

---

## Key Takeaways

| Concept | What You Learned |
|---------|-----------------|
| VARIANT type | Stores JSON natively — no `PARSE_JSON()` needed for queries |
| VARCHAR type | Stores JSON as text — requires `PARSE_JSON()` before traversal |
| `[0]` indexing | Accesses elements within a JSON array |
| `:key` notation | Accesses fields within a JSON object |
| `::TYPE` casting | Converts VARIANT values to SQL types (VARCHAR, NUMBER, etc.) |
| Views | Live queries that automatically reflect table changes |
| Loading settings | "Load as single variant" = one column; unchecked = split into columns |

---

## Bonus Challenge

1. Modify the view to also include `weather[0]:maxtempC` and `weather[0]:mintempC` for the day's temperature range.
2. Write a query that uses `LATERAL FLATTEN(input => weather)` to get sunrise/sunset for ALL forecast days (not just `[0]`).
3. Compare the result of loading with columns as VARCHAR vs VARIANT — what breaks?
