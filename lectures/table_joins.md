# SQL Table Joins


A practical guide to combining data from multiple tables using JOIN operations — the most essential skill for working with relational databases.

---

## Pre-Requisite: Keys in Relational Databases

Before understanding joins, you need to understand **keys** — they are what make joins possible.

### Primary Key (PK)

A primary key is a column (or combination of columns) that **uniquely identifies** every row in a table. No two rows can share the same primary key value, and it can never be NULL.

```
CUSTOMERS table
┌─────────────┬──────────┬─────────────┐
│ customer_id │ name     │ email       │   ← customer_id is the Primary Key
├─────────────┼──────────┼─────────────┤      Every value is unique:
│ 101         │ Alice    │ a@email.com │      101, 102, 103 — no duplicates
│ 102         │ Bob      │ b@email.com │
│ 103         │ Charlie  │ c@email.com │
└─────────────┴──────────┴─────────────┘
```

```sql
-- Declaring a primary key in Snowflake
CREATE TABLE CUSTOMERS (
    customer_id  INTEGER PRIMARY KEY,   -- PK: unique, not null
    name         VARCHAR(50),
    email        VARCHAR(100)
);
```

### Unique Key

A unique key also enforces that all values in a column are distinct, but unlike a primary key:
- A table can have **multiple** unique keys
- Unique keys **can** allow NULL (though only one NULL in most databases)

```sql
CREATE TABLE CUSTOMERS (
    customer_id  INTEGER PRIMARY KEY,        -- PK
    email        VARCHAR(100) UNIQUE,        -- Unique key: no duplicate emails
    phone        VARCHAR(20) UNIQUE          -- Another unique key
);
```

### Foreign Key (FK)

A foreign key is a column in one table that **references the primary key** of another table. It creates a link between the two tables — this is what makes joins meaningful.

```
ORDERS table                         CUSTOMERS table
┌──────────┬─────────────┐          ┌─────────────┬─────────┐
│ order_id │ customer_id │          │ customer_id │ name    │
│   (PK)   │    (FK)     │───────►  │    (PK)     │         │
├──────────┼─────────────┤          ├─────────────┼─────────┤
│ 1        │ 101         │──────┐   │ 101         │ Alice   │
│ 2        │ 102         │───┐  └──►│ 101         │ Alice   │
│ 3        │ 101         │─┐ └────►│ 102         │ Bob     │
└──────────┴─────────────┘ └──────►│ 101         │ Alice   │
                                    └─────────────┴─────────┘
```

```sql
-- Declaring a foreign key in Snowflake
CREATE TABLE ORDERS (
    order_id     INTEGER PRIMARY KEY,
    customer_id  INTEGER REFERENCES CUSTOMERS(customer_id),  -- FK
    order_date   DATE,
    amount       DECIMAL(10,2)
);
```

### Composite Keys

Sometimes a single column isn't enough to uniquely identify a row. A **composite key** uses two or more columns together.

```sql
-- A student can enroll in many courses, a course has many students
-- The combination of (student_id, course_id) is unique
CREATE TABLE ENROLLMENTS (
    student_id   INTEGER,
    course_id    INTEGER,
    grade        VARCHAR(2),
    PRIMARY KEY (student_id, course_id)   -- Composite PK
);
```

### Natural Key vs Surrogate Key

| Type | Definition | Example |
|------|-----------|---------|
| **Natural Key** | A real-world value that is naturally unique | Email, SSN, ISBN |
| **Surrogate Key** | An artificial value created just to be a key | Auto-increment ID, UUID |

```sql
-- Natural key (email is unique in the real world)
CREATE TABLE USERS (
    email    VARCHAR(100) PRIMARY KEY,
    name     VARCHAR(50)
);

-- Surrogate key (system-generated, no business meaning)
CREATE TABLE USERS (
    user_id  INTEGER PRIMARY KEY AUTOINCREMENT,
    email    VARCHAR(100) UNIQUE,
    name     VARCHAR(50)
);
```

Surrogate keys are preferred in data warehousing because they're:
- Compact (small integers join faster)
- Stable (won't change if email changes)
- Consistent (every table follows the same pattern)

### How Keys Enable Joins

```
         PK                    FK → PK
    ┌──────────┐          ┌──────────────────┐
    │DEPARTMENTS│          │    EMPLOYEES     │
    │──────────│          │──────────────────│
    │dept_id ◄─┼──────────┼── dept_id        │
    │dept_name │          │ emp_id (PK)      │
    └──────────┘          │ name             │
                          └──────────────────┘

    JOIN condition: employees.dept_id = departments.dept_id
    This works BECAUSE dept_id is a PK in departments — guaranteed unique match.
```

### Key Constraints in Snowflake

Snowflake supports PK, UNIQUE, and FK syntax but does **not enforce** them at write time (for performance reasons). They serve as:
- **Documentation** — tells other developers the intended relationships
- **Query optimization** — the optimizer uses key info for better plans
- **Schema clarity** — tools and BI platforms read these constraints

```sql
-- Snowflake won't block a duplicate PK insert, but declares the intent
ALTER TABLE PRACTICE.EMPLOYEES ADD PRIMARY KEY (emp_id);
ALTER TABLE PRACTICE.EMPLOYEES ADD FOREIGN KEY (dept_id)
    REFERENCES PRACTICE.DEPARTMENTS(dept_id);
```

---

## Why Do We Need Joins?

In relational databases, data is split across multiple tables to avoid duplication. Joins let you **recombine** that data when querying.

Example: Instead of storing the customer's full name on every order row, we store a `customer_id` and look up the name from a separate `customers` table.

```
ORDERS table                    CUSTOMERS table
┌──────────┬─────────────┐     ┌─────────────┬──────────┐
│ order_id │ customer_id │     │ customer_id │ name     │
├──────────┼─────────────┤     ├─────────────┼──────────┤
│ 1        │ 101         │────►│ 101         │ Alice    │
│ 2        │ 102         │────►│ 102         │ Bob      │
│ 3        │ 101         │────►│ 101         │ Alice    │
└──────────┴─────────────┘     └─────────────┴──────────┘
```

---

## Setup: Practice Tables

Run this SQL to create tables we'll use throughout this tutorial.

```sql
-- Employees table
CREATE OR REPLACE TABLE PRACTICE.EMPLOYEES (
    emp_id      INTEGER PRIMARY KEY,
    name        VARCHAR(30),
    dept_id     INTEGER,
    salary      DECIMAL(10,2)
);

INSERT INTO PRACTICE.EMPLOYEES VALUES
(1, 'Alice',   10, 75000),
(2, 'Bob',     20, 82000),
(3, 'Charlie', 10, 69000),
(4, 'Diana',   30, 91000),
(5, 'Eve',     20, 77000),
(6, 'Frank',   NULL, 65000);  -- No department assigned

-- Departments table
CREATE OR REPLACE TABLE PRACTICE.DEPARTMENTS (
    dept_id     INTEGER PRIMARY KEY,
    dept_name   VARCHAR(30),
    location    VARCHAR(30)
);

INSERT INTO PRACTICE.DEPARTMENTS VALUES
(10, 'Engineering', 'New York'),
(20, 'Marketing',   'Chicago'),
(30, 'Finance',     'Houston'),
(40, 'HR',          'Atlanta');  -- No employees yet

-- Projects table
CREATE OR REPLACE TABLE PRACTICE.PROJECTS (
    project_id   INTEGER PRIMARY KEY,
    project_name VARCHAR(40),
    dept_id      INTEGER,
    budget       DECIMAL(12,2)
);

INSERT INTO PRACTICE.PROJECTS VALUES
(100, 'Website Redesign',    10, 150000),
(101, 'Brand Campaign',      20, 200000),
(102, 'Data Migration',      10, 300000),
(103, 'Annual Audit',        30, 50000),
(104, 'Recruitment Portal',  40, 80000);
```

---

## JOIN Types at a Glance

```
┌─────────────────────────────────────────────────────────────────────┐
│                        JOIN Types Summary                            │
├──────────────────┬──────────────────────────────────────────────────┤
│ INNER JOIN       │ Only rows that match in BOTH tables              │
│ LEFT JOIN        │ All rows from LEFT table + matches from right    │
│ RIGHT JOIN       │ All rows from RIGHT table + matches from left    │
│ FULL OUTER JOIN  │ All rows from BOTH tables, matched where possible│
│ CROSS JOIN       │ Every row from A paired with every row from B    │
└──────────────────┴──────────────────────────────────────────────────┘
```

---

## INNER JOIN

Returns only rows where the join condition matches in **both** tables.

```
   Table A          Table B          INNER JOIN Result
┌───┬─────┐     ┌───┬─────┐       ┌───┬─────┬─────┐
│ 1 │ a   │     │ 1 │ x   │       │ 1 │ a   │ x   │  ← match
│ 2 │ b   │     │ 2 │ y   │       │ 2 │ b   │ y   │  ← match
│ 3 │ c   │     │ 4 │ z   │       └───┴─────┴─────┘
└───┴─────┘     └───┴─────┘         (3 and 4 excluded — no match)
```

### Example

```sql
-- Show employees with their department names
SELECT
    e.name,
    e.salary,
    d.dept_name,
    d.location
FROM PRACTICE.EMPLOYEES e
INNER JOIN PRACTICE.DEPARTMENTS d ON e.dept_id = d.dept_id;
```

**Result:**

| name    | salary | dept_name   | location |
|---------|--------|-------------|----------|
| Alice   | 75000  | Engineering | New York |
| Bob     | 82000  | Marketing   | Chicago  |
| Charlie | 69000  | Engineering | New York |
| Diana   | 91000  | Finance     | Houston  |
| Eve     | 77000  | Marketing   | Chicago  |

Notice: **Frank** (no department) and **HR** (no employees) are both excluded.

---

## LEFT JOIN (LEFT OUTER JOIN)

Returns **all rows from the left table**, plus matching rows from the right. Non-matching right-side columns show `NULL`.

```
   Table A          Table B          LEFT JOIN Result
┌───┬─────┐     ┌───┬─────┐       ┌───┬─────┬──────┐
│ 1 │ a   │     │ 1 │ x   │       │ 1 │ a   │ x    │  ← match
│ 2 │ b   │     │ 2 │ y   │       │ 2 │ b   │ y    │  ← match
│ 3 │ c   │     │ 4 │ z   │       │ 3 │ c   │ NULL │  ← no match, kept
└───┴─────┘     └───┴─────┘       └───┴─────┴──────┘
```

### Example

```sql
-- All employees, even those without a department
SELECT
    e.name,
    e.salary,
    d.dept_name
FROM PRACTICE.EMPLOYEES e
LEFT JOIN PRACTICE.DEPARTMENTS d ON e.dept_id = d.dept_id;
```

**Result:**

| name    | salary | dept_name   |
|---------|--------|-------------|
| Alice   | 75000  | Engineering |
| Bob     | 82000  | Marketing   |
| Charlie | 69000  | Engineering |
| Diana   | 91000  | Finance     |
| Eve     | 77000  | Marketing   |
| Frank   | 65000  | NULL        |

Frank now appears with `NULL` for department — LEFT JOIN keeps all left-side rows.

### Finding Unmatched Rows

A common pattern: use LEFT JOIN + WHERE IS NULL to find orphaned records.

```sql
-- Employees not assigned to any department
SELECT e.name, e.salary
FROM PRACTICE.EMPLOYEES e
LEFT JOIN PRACTICE.DEPARTMENTS d ON e.dept_id = d.dept_id
WHERE d.dept_id IS NULL;
```

| name  | salary |
|-------|--------|
| Frank | 65000  |

---

## RIGHT JOIN (RIGHT OUTER JOIN)

Returns **all rows from the right table**, plus matching rows from the left. The mirror image of LEFT JOIN.

```
   Table A          Table B          RIGHT JOIN Result
┌───┬─────┐     ┌───┬─────┐       ┌──────┬─────┬───┐
│ 1 │ a   │     │ 1 │ x   │       │ a    │ x   │ 1 │  ← match
│ 2 │ b   │     │ 2 │ y   │       │ b    │ y   │ 2 │  ← match
│ 3 │ c   │     │ 4 │ z   │       │ NULL │ z   │ 4 │  ← no match, kept
└───┴─────┘     └───┴─────┘       └──────┴─────┴───┘
```

### Example

```sql
-- All departments, even those with no employees
SELECT
    d.dept_name,
    d.location,
    e.name
FROM PRACTICE.EMPLOYEES e
RIGHT JOIN PRACTICE.DEPARTMENTS d ON e.dept_id = d.dept_id;
```

**Result:**

| dept_name   | location | name    |
|-------------|----------|---------|
| Engineering | New York | Alice   |
| Engineering | New York | Charlie |
| Marketing   | Chicago  | Bob     |
| Marketing   | Chicago  | Eve     |
| Finance     | Houston  | Diana   |
| HR          | Atlanta  | NULL    |

HR appears with `NULL` for the employee name.

> **Tip:** In practice, most people prefer LEFT JOIN and reorder the tables rather than using RIGHT JOIN. Both achieve the same result.

---

## FULL OUTER JOIN

Returns **all rows from both tables**. Rows without a match on either side get `NULL` in the missing columns.

```
   Table A          Table B          FULL OUTER JOIN Result
┌───┬─────┐     ┌───┬─────┐       ┌──────┬─────┬──────┐
│ 1 │ a   │     │ 1 │ x   │       │ a    │  1  │ x    │  ← match
│ 2 │ b   │     │ 2 │ y   │       │ b    │  2  │ y    │  ← match
│ 3 │ c   │     │ 4 │ z   │       │ c    │  3  │ NULL │  ← left only
└───┴─────┘     └───┴─────┘       │ NULL │  4  │ z    │  ← right only
                                   └──────┴─────┴──────┘
```

### Example

```sql
-- All employees and all departments, matched where possible
SELECT
    e.name,
    d.dept_name
FROM PRACTICE.EMPLOYEES e
FULL OUTER JOIN PRACTICE.DEPARTMENTS d ON e.dept_id = d.dept_id;
```

**Result:**

| name    | dept_name   |
|---------|-------------|
| Alice   | Engineering |
| Bob     | Marketing   |
| Charlie | Engineering |
| Diana   | Finance     |
| Eve     | Marketing   |
| Frank   | NULL        |
| NULL    | HR          |

Both Frank (no dept) and HR (no employees) appear.

---

## CROSS JOIN

Produces the **Cartesian product** — every row from A combined with every row from B. No join condition needed.

```sql
-- Every employee paired with every department (5 employees × 4 departments = 20 rows)
SELECT
    e.name,
    d.dept_name
FROM PRACTICE.EMPLOYEES e
CROSS JOIN PRACTICE.DEPARTMENTS d
ORDER BY e.name, d.dept_name;
```

Use cases: generating date scaffolds, creating all possible combinations for reporting, or pairing items for comparison.

> **Warning:** Cross joins can produce very large results. 1,000 rows × 1,000 rows = 1,000,000 rows.

---

## Joining Multiple Tables

You can chain multiple JOINs in a single query. Each JOIN adds another table.

```sql
-- Employees with their department AND that department's projects
SELECT
    e.name AS employee,
    d.dept_name,
    p.project_name,
    p.budget
FROM PRACTICE.EMPLOYEES e
INNER JOIN PRACTICE.DEPARTMENTS d ON e.dept_id = d.dept_id
INNER JOIN PRACTICE.PROJECTS p ON d.dept_id = p.dept_id
ORDER BY e.name, p.project_name;
```

**Result:**

| employee | dept_name   | project_name     | budget  |
|----------|-------------|------------------|---------|
| Alice    | Engineering | Data Migration   | 300000  |
| Alice    | Engineering | Website Redesign | 150000  |
| Bob      | Marketing   | Brand Campaign   | 200000  |
| Charlie  | Engineering | Data Migration   | 300000  |
| Charlie  | Engineering | Website Redesign | 150000  |
| Diana    | Finance     | Annual Audit     | 50000   |
| Eve      | Marketing   | Brand Campaign   | 200000  |

Notice Alice and Charlie each appear twice because Engineering has 2 projects — this is expected behavior when joining to a table with multiple matching rows.

---

## Self Join

A table joined to **itself**. Useful for hierarchical data or comparing rows within the same table.

```sql
-- Find employees who earn more than others in the same department
SELECT
    a.name AS higher_earner,
    b.name AS lower_earner,
    a.salary - b.salary AS salary_difference
FROM PRACTICE.EMPLOYEES a
INNER JOIN PRACTICE.EMPLOYEES b
    ON a.dept_id = b.dept_id
    AND a.salary > b.salary
ORDER BY a.dept_id, salary_difference DESC;
```

| higher_earner | lower_earner | salary_difference |
|---------------|--------------|-------------------|
| Alice         | Charlie      | 6000              |
| Bob           | Eve          | 5000              |

---

## Join Conditions: ON vs USING

Two ways to specify the join column:

```sql
-- Using ON (explicit — works with any column names)
SELECT *
FROM PRACTICE.EMPLOYEES e
JOIN PRACTICE.DEPARTMENTS d ON e.dept_id = d.dept_id;

-- Using USING (shorter — only when column names are identical in both tables)
SELECT *
FROM PRACTICE.EMPLOYEES e
JOIN PRACTICE.DEPARTMENTS d USING (dept_id);
```

Both produce the same result. `ON` is more flexible; `USING` is more concise.

---

## Common Mistakes

### 1. Missing JOIN condition (accidental cross join)

```sql
-- BAD: This creates a cross join (every row × every row)
SELECT e.name, d.dept_name
FROM PRACTICE.EMPLOYEES e, PRACTICE.DEPARTMENTS d;

-- GOOD: Always specify the join condition
SELECT e.name, d.dept_name
FROM PRACTICE.EMPLOYEES e
JOIN PRACTICE.DEPARTMENTS d ON e.dept_id = d.dept_id;
```

### 2. Ambiguous column names

```sql
-- BAD: dept_id exists in both tables — which one?
SELECT dept_id, name, dept_name
FROM PRACTICE.EMPLOYEES e
JOIN PRACTICE.DEPARTMENTS d ON e.dept_id = d.dept_id;

-- GOOD: Use table aliases to be explicit
SELECT e.dept_id, e.name, d.dept_name
FROM PRACTICE.EMPLOYEES e
JOIN PRACTICE.DEPARTMENTS d ON e.dept_id = d.dept_id;
```

### 3. Unexpected row multiplication

If a join produces more rows than expected, check if there are multiple matching rows in the joined table. Use `COUNT(*)` and `GROUP BY` to investigate.

```sql
-- Check: how many projects per department?
SELECT dept_id, COUNT(*) AS project_count
FROM PRACTICE.PROJECTS
GROUP BY dept_id;
```

---

## Quick Reference

| Join Type | Keeps from Left | Keeps from Right | Use When |
|-----------|----------------|-----------------|----------|
| INNER     | Only matched   | Only matched    | You only want rows with data in both tables |
| LEFT      | All            | Only matched    | You need every row from the "main" table |
| RIGHT     | Only matched   | All             | Same as LEFT, but tables are swapped |
| FULL OUTER| All            | All             | You want to see everything, matched or not |
| CROSS     | All × All      | All × All       | You need every possible combination |

---

## Practice Exercises

1. Write a query to show all departments and their total salary cost (sum of employee salaries). Include departments with no employees (show 0).

2. Find all projects whose department has no employees assigned.

3. List employees who work in the same city as the department location (hint: you need to add a `city` column to employees, or use the existing data creatively).

4. Write a query that shows each department's name, number of employees, and number of projects — all in one result set. Use LEFT JOINs to include departments with zeros.

5. Using a self-join, find pairs of employees in different departments who have the same salary range (within $5,000 of each other).

---

## Key Takeaways

| Concept | What You Learned |
|---------|-----------------|
| JOIN purpose | Combine related data from multiple tables |
| INNER JOIN | Only matching rows from both sides |
| LEFT JOIN | All from left + matches from right (NULL if no match) |
| RIGHT JOIN | All from right + matches from left |
| FULL OUTER | Everything from both sides |
| CROSS JOIN | Cartesian product — every combination |
| Multiple JOINs | Chain joins to bring in data from 3+ tables |
| Self Join | A table joined to itself for row comparisons |
| IS NULL pattern | LEFT JOIN + WHERE NULL finds orphan records |
| Aliases | Always use table aliases for readability |
