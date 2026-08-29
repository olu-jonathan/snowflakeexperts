# Quiz: Data Loading & Semi-Structured Data

---

## Questions

**1.** Fix the problem from yesterday's `COPY` command. The solution was in the chat.

**2.** This public S3 bucket contains data:

> `s3://sfquickstarts/tastybytes/`

Navigate into the `raw_pos/menu/` subfolder and copy into the table below. **Please do this without AI assistance.**

**3.** What is your observation about the last column?

**4.** Attempt to make the last column structured. You can use AI assistance here.

---

## Setup: Create the Target Table

Create this table in the `RAW` schema of your database:

```sql
CREATE OR REPLACE TABLE MENU
(
    menu_id                       NUMBER(19,0),
    menu_type_id                  NUMBER(38,0),
    menu_type                     VARCHAR(16777216),
    truck_brand_name              VARCHAR(16777216),
    menu_item_id                  NUMBER(38,0),
    menu_item_name                VARCHAR(16777216),
    item_category                 VARCHAR(16777216),
    item_subcategory              VARCHAR(16777216),
    cost_of_goods_usd             NUMBER(38,4),
    sale_price_usd                NUMBER(38,4),
    menu_item_health_metrics_obj  VARIANT
);
```

---
