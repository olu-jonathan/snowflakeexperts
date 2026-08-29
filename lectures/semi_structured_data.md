# Semi-Structured Data in Snowflake

Working with JSON, VARIANT columns, dot notation, and LATERAL FLATTEN.

---

## What is VARIANT?

`VARIANT` is Snowflake's flexible data type that can hold any valid JSON, including:
- Objects (`{"key": "value"}`)
- Arrays (`[1, 2, 3]`)
- Nested combinations of both

Snowflake stores VARIANT data in an optimized columnar format — it's not just a blob of text. You can query into it efficiently using dot notation.

---

## Part 1: Practice Table — Simple JSON

Let's start with a small table to build intuition.

```sql
CREATE OR REPLACE TABLE RAW.EMPLOYEES (
    id          INTEGER,
    name        VARCHAR(50),
    details     VARIANT
);

INSERT INTO RAW.EMPLOYEES (id, name, details)
SELECT 1, 'Alice',   PARSE_JSON('{"department": "Engineering", "salary": 95000, "skills": ["Python", "SQL", "Spark"]}')
UNION ALL
SELECT 2, 'Bob',     PARSE_JSON('{"department": "Marketing", "salary": 72000, "skills": ["Excel", "Tableau"]}')
UNION ALL
SELECT 3, 'Charlie', PARSE_JSON('{"department": "Engineering", "salary": 110000, "skills": ["Java", "Kafka", "SQL", "Docker"]}')
UNION ALL
SELECT 4, 'Diana',   PARSE_JSON('{"department": "Sales", "salary": 85000, "skills": ["CRM", "Negotiation"]}')
UNION ALL
SELECT 5, 'Eve',     PARSE_JSON('{"department": "Engineering", "salary": 102000, "skills": ["Python", "ML", "SQL"]}');
```

---

## Part 2: Dot Notation — Accessing Fields

Use `:` (colon) to access top-level keys in a VARIANT column, then `::` to cast to a type.

### Basic extraction

```sql
-- Extract fields from the VARIANT column
SELECT
    id,
    name,
    details:department::VARCHAR AS department,
    details:salary::NUMBER AS salary
FROM RAW.EMPLOYEES;
```

### Filtering on VARIANT fields

```sql
-- Filter by a JSON field
SELECT name, details:department::VARCHAR AS dept, details:salary::NUMBER AS salary
FROM RAW.EMPLOYEES
WHERE details:department::VARCHAR = 'Engineering';
```

### Aggregating on VARIANT fields

```sql
-- Average salary by department
SELECT
    details:department::VARCHAR AS department,
    COUNT(*) AS headcount,
    AVG(details:salary::NUMBER) AS avg_salary
FROM RAW.EMPLOYEES
GROUP BY department
ORDER BY avg_salary DESC;
```

### Accessing arrays by index

```sql
-- Get the first skill for each employee
SELECT
    name,
    details:skills[0]::VARCHAR AS primary_skill
FROM RAW.EMPLOYEES;
```

---

## Part 3: LATERAL FLATTEN — Expanding Arrays

When a VARIANT field contains an **array**, you use `LATERAL FLATTEN` to turn each array element into its own row.

### Flatten the skills array

```sql
-- One row per skill per employee
SELECT
    e.name,
    f.value::VARCHAR AS skill
FROM RAW.EMPLOYEES e,
LATERAL FLATTEN(input => e.details:skills) f;
```

**What's happening:**
- `FLATTEN(input => e.details:skills)` expands the array
- Each element becomes a row in alias `f`
- `f.value` holds the current element

### Useful FLATTEN output columns

| Column | Description |
|--------|-------------|
| `f.value` | The current array element |
| `f.index` | Position in the array (0-based) |
| `f.key` | Key name (for objects) |
| `f.path` | Path to the element |
| `f.this` | The entire array/object being flattened |

### Counting skills per employee

```sql
SELECT
    e.name,
    COUNT(f.value) AS skill_count
FROM RAW.EMPLOYEES e,
LATERAL FLATTEN(input => e.details:skills) f
GROUP BY e.name
ORDER BY skill_count DESC;
```

### Finding employees with a specific skill

```sql
SELECT DISTINCT e.name, e.details:department::VARCHAR AS department
FROM RAW.EMPLOYEES e,
LATERAL FLATTEN(input => e.details:skills) f
WHERE f.value::VARCHAR = 'SQL';
```

---

## Part 4: Nested Objects

Let's add complexity with nested JSON.

```sql
CREATE OR REPLACE TABLE RAW.ORDERS_JSON (
    id      INTEGER,
    name    VARCHAR(50),
    payload VARIANT
);

INSERT INTO RAW.ORDERS_JSON (id, name, payload)
SELECT 1, 'Order A', PARSE_JSON('{
    "customer": {"name": "Alice", "tier": "gold"},
    "items": [
        {"sku": "X100", "qty": 2, "price": 25.00},
        {"sku": "Y200", "qty": 1, "price": 50.00}
    ],
    "total": 100.00
}')
UNION ALL
SELECT 2, 'Order B', PARSE_JSON('{
    "customer": {"name": "Bob", "tier": "silver"},
    "items": [
        {"sku": "Z300", "qty": 5, "price": 10.00}
    ],
    "total": 50.00
}')
UNION ALL
SELECT 3, 'Order C', PARSE_JSON('{
    "customer": {"name": "Charlie", "tier": "gold"},
    "items": [
        {"sku": "X100", "qty": 1, "price": 25.00},
        {"sku": "Z300", "qty": 3, "price": 10.00},
        {"sku": "W400", "qty": 2, "price": 75.00}
    ],
    "total": 205.00
}');
```

### Accessing nested objects (dot notation chains)

```sql
SELECT
    id,
    payload:customer.name::VARCHAR AS customer_name,
    payload:customer.tier::VARCHAR AS customer_tier,
    payload:total::NUMBER(10,2) AS order_total
FROM RAW.ORDERS_JSON;
```

### Flattening arrays of objects

```sql
-- Expand line items, extracting fields from each object
SELECT
    o.id,
    o.payload:customer.name::VARCHAR AS customer,
    items.value:sku::VARCHAR AS sku,
    items.value:qty::INTEGER AS quantity,
    items.value:price::NUMBER(10,2) AS unit_price,
    items.value:qty::INTEGER * items.value:price::NUMBER(10,2) AS line_total
FROM RAW.ORDERS_JSON o,
LATERAL FLATTEN(input => o.payload:items) items;
```

---

## Part 5: Real-World Practice — RAW.MENU

Now apply everything you've learned to the actual `MENU` table.

The `menu_item_health_metrics_obj` column contains JSON like this:

```json
{
  "menu_item_id": 10,
  "menu_item_health_metrics": [
    {
      "ingredients": ["Lemons", "Sugar", "Water"],
      "is_dairy_free_flag": "Y",
      "is_gluten_free_flag": "Y",
      "is_healthy_flag": "N",
      "is_nut_free_flag": "Y"
    }
  ]
}
```

**Note:** This column was loaded as a string, so you need `PARSE_JSON()` first.

### Step 1: Explore the raw data

```sql
SELECT menu_item_name, menu_item_health_metrics_obj
FROM RAW.MENU
LIMIT 5;
```

### Step 2: Extract with dot notation

```sql
SELECT
    menu_item_name,
    PARSE_JSON(menu_item_health_metrics_obj):menu_item_id::INTEGER AS health_metric_id,
    PARSE_JSON(menu_item_health_metrics_obj):menu_item_health_metrics[0]:is_healthy_flag::VARCHAR AS is_healthy
FROM RAW.MENU
LIMIT 10;
```

### Step 3: Full LATERAL FLATTEN

```sql
SELECT
    m.menu_id,
    m.menu_item_name,
    m.item_category,
    m.cost_of_goods_usd,
    m.sale_price_usd,
    metrics.value:is_dairy_free_flag::VARCHAR AS is_dairy_free,
    metrics.value:is_gluten_free_flag::VARCHAR AS is_gluten_free,
    metrics.value:is_healthy_flag::VARCHAR AS is_healthy,
    metrics.value:is_nut_free_flag::VARCHAR AS is_nut_free,
    metrics.value:ingredients AS ingredients_array
FROM RAW.MENU m,
LATERAL FLATTEN(
    input => PARSE_JSON(m.menu_item_health_metrics_obj):menu_item_health_metrics
) metrics;
```

### Step 4: Double flatten — expand ingredients too

```sql
SELECT
    m.menu_item_name,
    ing.value::VARCHAR AS ingredient
FROM RAW.MENU m,
LATERAL FLATTEN(
    input => PARSE_JSON(m.menu_item_health_metrics_obj):menu_item_health_metrics
) metrics,
LATERAL FLATTEN(
    input => metrics.value:ingredients
) ing
ORDER BY m.menu_item_name;
```

### Step 5: Save as a structured table

```sql
CREATE OR REPLACE TABLE RAW.MENU_FLATTENED AS
SELECT
    m.menu_id,
    m.menu_type,
    m.truck_brand_name,
    m.menu_item_id,
    m.menu_item_name,
    m.item_category,
    m.item_subcategory,
    m.cost_of_goods_usd,
    m.sale_price_usd,
    metrics.value:is_dairy_free_flag::VARCHAR AS is_dairy_free_flag,
    metrics.value:is_gluten_free_flag::VARCHAR AS is_gluten_free_flag,
    metrics.value:is_healthy_flag::VARCHAR AS is_healthy_flag,
    metrics.value:is_nut_free_flag::VARCHAR AS is_nut_free_flag,
    ARRAY_TO_STRING(metrics.value:ingredients::ARRAY, ', ') AS ingredients
FROM RAW.MENU m,
LATERAL FLATTEN(
    input => PARSE_JSON(m.menu_item_health_metrics_obj):menu_item_health_metrics
) metrics;
```

---

## Quick Reference

| Task | Syntax |
|------|--------|
| Access a key | `col:key::TYPE` |
| Access nested key | `col:key1.key2::TYPE` |
| Access array element | `col:array_name[0]::TYPE` |
| Flatten an array | `LATERAL FLATTEN(input => col:array_field)` |
| Get element value | `f.value::TYPE` |
| Get element index | `f.index` |
| Parse string to JSON | `PARSE_JSON(col)` |
| Array to string | `ARRAY_TO_STRING(col:arr::ARRAY, ', ')` |

---

## Exercises

1. Using `RAW.EMPLOYEES`: Find all employees who have more than 3 skills.
2. Using `RAW.ORDERS_JSON`: Calculate total revenue per customer tier.
3. Using `RAW.MENU`: Find all menu items that contain "Sugar" as an ingredient.
4. Using `RAW.MENU`: Which `item_category` has the most healthy items (`is_healthy_flag = 'Y'`)?
5. Using `RAW.MENU`: What is the average `sale_price_usd` for dairy-free vs non-dairy-free items?
