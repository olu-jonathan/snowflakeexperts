# Snowflake Data Engineering: Complete Syllabus

> **From Zero Knowledge to Expert Level**
> 12 Modules | 48 Lessons | 3 Capstone Projects | Hands-on Labs Throughout

### Lab Files

| Lab | Module | File | Topics |
|-----|--------|------|--------|
| 1 | Module 2 | [lab_01_snowflake_basics.sql](lab_01_snowflake_basics.sql) | Databases, schemas, warehouses, tables, queries, VARIANT, views |
| 2 | Module 3 | [lab_02_data_loading.sql](lab_02_data_loading.sql) | File formats, stages, COPY INTO, JSON/Parquet, Snowpipe, unloading |
| 3 | Module 4 | *Coming soon* | Advanced SQL, semi-structured transforms, UDFs |
| 4 | Module 5 | *Coming soon* | Star schema, SCD Type 2, time travel, cloning |
| 5 | Module 6 | *Coming soon* | Streams, tasks, dynamic tables, CDC pipeline |
| 6 | Module 7 | *Coming soon* | Query profiling, clustering, performance tuning |
| 7 | Module 8 | *Coming soon* | RBAC, masking policies, row access policies |
| 8 | Module 9 | *Coming soon* | Snowpark ETL pipeline |
| 9 | Module 10 | *Coming soon* | Replication, Iceberg, Cortex AI |
| 10 | Module 11 | *Coming soon* | dbt project with CI/CD |
| 11 | Module 12 | *Coming soon* | Multi-tenant real-time platform |

---

## Module 1: Foundations — Data & Cloud Concepts

### Lesson 1.1: What is Data Engineering?
- Role of a data engineer in the modern data stack
- Data engineering vs data science vs data analytics
- ETL vs ELT paradigm shift
- Batch vs streaming data processing
- Data pipelines overview

### Lesson 1.2: Relational Database Fundamentals
- Tables, rows, columns
- Primary keys and foreign keys
- Data types (numeric, string, date/time, semi-structured)
- Normalization (1NF, 2NF, 3NF) and denormalization
- ACID properties

### Lesson 1.3: SQL Fundamentals
- `SELECT`, `FROM`, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`
- JOINs: INNER, LEFT, RIGHT, FULL OUTER, CROSS
- Subqueries and CTEs (Common Table Expressions)
- Window functions: `ROW_NUMBER`, `RANK`, `LEAD`, `LAG`, `SUM OVER`
- Set operations: `UNION`, `INTERSECT`, `EXCEPT`

### Lesson 1.4: Cloud Computing Essentials
- IaaS, PaaS, SaaS models
- AWS, Azure, GCP overview
- Object storage (S3, Azure Blob, GCS)
- Virtual networking basics
- Identity and access management (IAM) concepts
- Cost models: on-demand vs reserved vs pay-per-use

---

## Module 2: Introduction to Snowflake

### Lesson 2.1: Snowflake Architecture Deep Dive
- Multi-cluster shared data architecture
- Three layers: **Storage**, **Compute**, **Cloud Services**
- Separation of storage and compute
- How Snowflake differs from traditional data warehouses
- Snowflake editions: Standard, Enterprise, Business Critical, VPS
- Snowflake regions and cloud platform deployment

### Lesson 2.2: Snowflake Objects Hierarchy

| Level | Objects |
|-------|---------|
| Account | Organizations, Accounts |
| Database | Databases, Schemas |
| Schema | Tables, Views, Stages, Pipes, Streams, Tasks, Sequences, Procedures, UDFs |

- Tables: permanent, temporary, transient
- Views: standard, materialized, secure
- Stages: internal (user, table, named) and external
- File formats and sequences

### Lesson 2.3: Getting Started with Snowsight
- Navigating the Snowsight UI
- Worksheets: SQL and Python
- Query history and profiling
- Account administration panel
- Marketplace and data sharing tabs
- Snowflake CLI (SnowSQL) setup and usage

### Lesson 2.4: Virtual Warehouses
- Warehouse sizes (XS through 6XL)
- Multi-cluster warehouses and scaling policies
- Auto-suspend and auto-resume
- Warehouse utilization and monitoring
- Resource monitors and credit controls
- Query acceleration service
- Warehouse types: Standard vs Snowpark-optimized

> **🧪 Lab:** Create your first database, schema, warehouse, and run queries
> 📂 **Lab File:** [lab_01_snowflake_basics.sql](lab_01_snowflake_basics.sql) — 9 parts covering environment setup, warehouses, tables, queries, joins, window functions, VARIANT data, views, and system metadata

---

## Module 3: Data Loading & Unloading

### Lesson 3.1: Staging Data
- Internal stages: user, table, named stages
- External stages: S3, Azure Blob, GCS
- Stage properties and encryption
- `PUT` command for file upload
- `LIST` command for stage inspection
- File format objects (CSV, JSON, Parquet, Avro, ORC, XML)

### Lesson 3.2: COPY INTO — Bulk Data Loading
- `COPY INTO <table>` syntax and options
- Loading from internal and external stages
- Pattern matching and file filtering
- Transformation during load (column reordering, casting, filtering)
- `ON_ERROR` options: CONTINUE, SKIP_FILE, ABORT_STATEMENT
- `VALIDATION_MODE` for dry runs
- Load history and metadata columns (`$1`, `$2`, `METADATA$FILENAME`)

### Lesson 3.3: Continuous Data Loading with Snowpipe
- Snowpipe architecture and auto-ingest
- Creating pipes with `AUTO_INGEST = TRUE`
- Event notifications: S3 SQS, Azure Event Grid, GCS Pub/Sub
- Snowpipe REST API for programmatic loading
- Monitoring: `SYSTEM$PIPE_STATUS`, `COPY_HISTORY`
- **Snowpipe Streaming** (SDK-based low-latency ingestion)
- Error handling and notification integration

### Lesson 3.4: Data Unloading
- `COPY INTO <location>` syntax
- Unloading to internal and external stages
- File format options for export
- Partitioning output files (`MAX_FILE_SIZE`, `PARTITION BY`)
- `GET` command for downloading files

> **🧪 Lab:** Load CSV, JSON, and Parquet files; set up Snowpipe auto-ingest
> 📂 **Lab File:** [lab_02_data_loading.sql](lab_02_data_loading.sql) — 11 parts covering file formats, stages, CSV/JSON/Parquet loading, validation, unloading, Snowpipe setup, and metadata columns

---

## Module 4: Data Transformation in Snowflake

### Lesson 4.1: Advanced SQL Transformations
- Complex CTEs and recursive CTEs
- `PIVOT` and `UNPIVOT` operations
- `LATERAL FLATTEN` for semi-structured data
- `QUALIFY` clause for window function filtering
- `MATCH_RECOGNIZE` for pattern detection
- `CONNECT BY` for hierarchical queries
- Multi-table `INSERT` and `MERGE` statements

### Lesson 4.2: Working with Semi-Structured Data
- `VARIANT`, `OBJECT`, and `ARRAY` data types
- Dot notation and bracket notation for traversal
- `PARSE_JSON`, `TO_JSON`, `TO_VARIANT`
- `OBJECT_CONSTRUCT`, `ARRAY_CONSTRUCT`, `ARRAY_AGG`
- `FLATTEN` function with `LATERAL`
- Handling nested and repeated structures
- Schema detection and evolution

### Lesson 4.3: Stored Procedures
- SQL scripting: `DECLARE`, `LET`, `IF/ELSE`, `FOR`, `WHILE`, `LOOP`
- JavaScript stored procedures
- Python stored procedures (Snowpark)
- Java and Scala stored procedures
- Transaction control within procedures
- Caller's rights vs owner's rights
- Error handling: EXCEPTION blocks

### Lesson 4.4: User-Defined Functions (UDFs) and UDTFs
- SQL UDFs: scalar and tabular
- JavaScript, Python, Java UDFs
- Vectorized UDFs for performance
- UDTFs (User-Defined Table Functions)
- External functions (API integrations)
- Secure UDFs and performance considerations

> **🧪 Lab:** Build transformations on nested JSON data, create reusable UDFs

---

## Module 5: Data Modeling for Snowflake

### Lesson 5.1: Data Modeling Approaches

| Approach | Best For |
|----------|----------|
| Star Schema | BI/reporting workloads |
| Snowflake Schema | Normalized analytical queries |
| Data Vault 2.0 | Auditability, agile warehousing |
| One Big Table (OBT) | Simple, fast analytical queries |

- Slowly Changing Dimensions (SCD Type 1, 2, 3, 6)

### Lesson 5.2: Snowflake-Specific Modeling Considerations
- Micro-partitions and how data is stored
- Clustering keys: natural vs explicit
- Impact of data ordering on query performance
- Column pruning and partition pruning
- When NOT to normalize (Snowflake optimization)

### Lesson 5.3: Time Travel and Fail-Safe
- `DATA_RETENTION_TIME_IN_DAYS` parameter
- `AT` and `BEFORE` clauses for time travel
- `UNDROP` for tables, schemas, databases
- Fail-safe: 7-day Snowflake-managed recovery
- Storage implications and cost management

### Lesson 5.4: Zero-Copy Cloning
- Clone databases, schemas, tables, stages, streams
- Cloning metadata vs data
- Use cases: development, testing, backup
- Storage implications over time
- Transactional consistency during clone

> **🧪 Lab:** Design a star schema, implement SCD Type 2, use time travel and cloning

---

## Module 6: Data Pipelines & Automation

### Lesson 6.1: Streams (Change Data Capture)
- Stream types: Standard, Append-only, Insert-only
- `METADATA$ACTION`, `METADATA$ISUPDATE`, `METADATA$ROW_ID`
- Stream offsets and consumption
- Streams on tables, views, directory tables, external tables
- Stale streams and data retention

### Lesson 6.2: Tasks (Scheduling)
- Creating and scheduling tasks (CRON and interval)
- Task trees / DAGs (Directed Acyclic Graphs)
- Predecessor tasks and task dependencies
- Serverless tasks vs warehouse-bound tasks
- `WHEN` clause with `SYSTEM$STREAM_HAS_DATA()`
- Error handling and `SUSPEND_TASK_AFTER_NUM_FAILURES`

### Lesson 6.3: Dynamic Tables
- Declarative data transformation pipelines
- `TARGET_LAG` specification
- Refresh modes: incremental vs full
- Dynamic table dependencies and DAG visualization
- Monitoring: `DYNAMIC_TABLE_REFRESH_HISTORY`
- When to use dynamic tables vs tasks + streams

### Lesson 6.4: Building End-to-End ELT Pipelines
- **Medallion architecture:** Bronze → Silver → Gold
- Combining Snowpipe + Streams + Tasks
- Combining Snowpipe + Dynamic Tables
- Error handling and dead-letter patterns
- Idempotency and exactly-once processing
- Pipeline versioning and deployment strategies

> **🧪 Lab:** Build a complete CDC pipeline with streams, tasks, and dynamic tables

---

## Module 7: Performance Optimization

### Lesson 7.1: Query Profiling and Optimization
- Query Profile in Snowsight (execution plan)
- Understanding operators: TableScan, Filter, Join, Sort, Aggregate
- Identifying bottlenecks: spilling, exploding joins
- Result caching: metadata cache, result cache, warehouse cache
- Pruning metrics and optimization

### Lesson 7.2: Clustering and Micro-Partitions
- How micro-partitions work (columnar, compressed, 50–500MB)
- Natural clustering vs explicit clustering keys
- `CLUSTER BY` syntax and multi-column clustering
- `SYSTEM$CLUSTERING_INFORMATION` monitoring
- Automatic reclustering and credit consumption

### Lesson 7.3: Search Optimization Service
- Point lookup acceleration
- EQUALITY and SUBSTRING search methods
- GEO search optimization
- Cost vs benefit analysis
- Supported data types and query patterns

### Lesson 7.4: Materialized Views
- Creating and maintaining materialized views
- Automatic refresh and maintenance costs
- Query rewrite and transparent acceleration
- Materialized views vs dynamic tables vs tables with tasks

### Lesson 7.5: Advanced Performance Techniques
- Query acceleration service (QAS)
- Caching strategies and cache invalidation
- Warehouse sizing and scaling strategies
- Multi-cluster warehouse tuning
- `SYSTEM$ESTIMATE_QUERY_ACCELERATION`

> **🧪 Lab:** Profile slow queries, implement clustering, measure improvements

---

## Module 8: Security & Governance

### Lesson 8.1: Authentication and Access Control
- Role-Based Access Control (RBAC)
- System-defined roles: `ACCOUNTADMIN`, `SYSADMIN`, `SECURITYADMIN`, `USERADMIN`, `PUBLIC`
- Custom roles and role hierarchy
- Database roles
- MFA, Key-pair auth, OAuth, SAML/SSO
- Network policies (IP allow/block lists)

### Lesson 8.2: Privileges and Grants
- Object privileges: `USAGE`, `SELECT`, `INSERT`, `CREATE`, etc.
- `GRANT` and `REVOKE` syntax
- Future grants for automated privilege management
- `MANAGED ACCESS` schemas
- Ownership transfer

### Lesson 8.3: Data Protection
- Dynamic data masking policies
- Row access policies
- Tag-based masking
- Column-level security
- External tokenization
- Object tagging and classification
- Aggregation and projection policies

### Lesson 8.4: Governance and Compliance
- Access history tracking (`ACCOUNT_USAGE.ACCESS_HISTORY`)
- Data classification (`SYSTEM$CLASSIFY`)
- Object dependencies and lineage
- HIPAA, PCI-DSS, SOC2 considerations
- Snowflake Trust Center
- Tri-Secret Secure and customer-managed keys

> **🧪 Lab:** Implement RBAC hierarchy, dynamic masking, row access policies

---

## Module 9: Snowpark & Programmatic Access

### Lesson 9.1: Snowpark for Python
- Snowpark Session and connection management
- DataFrames: creation, transformation, actions
- Lazy evaluation and pushdown optimization
- Working with semi-structured data in Snowpark
- Snowpark pandas API (Modin on Snowflake)

### Lesson 9.2: Snowpark for Data Engineering
- Building ETL pipelines with Snowpark
- Stored procedures in Python
- UDFs and UDTFs with Snowpark
- Vectorized UDFs for performance
- Package management and third-party libraries
- Snowpark-optimized warehouses

### Lesson 9.3: Python Connectors and Drivers
- Snowflake Connector for Python
- SQLAlchemy with Snowflake
- Pandas integration (`write_pandas`, `fetch_pandas_all`)
- Asynchronous queries
- Connection pooling and session management

### Lesson 9.4: REST API and Programmatic Interfaces
- Snowflake SQL REST API
- Key-pair authentication for services
- Snowflake CLI (`snow`) and SnowSQL
- Terraform provider for Snowflake
- SDKs: Node.js, Go, .NET, JDBC

> **🧪 Lab:** Build an ETL pipeline entirely in Snowpark Python

---

## Module 10: Advanced Data Engineering Patterns

### Lesson 10.1: Data Sharing and Collaboration
- Secure data sharing (direct shares)
- Reader accounts
- Snowflake Marketplace (consumer and provider)
- Private listings and data exchanges
- Sharing across clouds and regions (replication)

### Lesson 10.2: Data Replication and Failover
- Database replication across regions/clouds
- Replication groups and failover groups
- Client redirect for automatic failover
- DR testing strategies

### Lesson 10.3: External Tables and Data Lake Integration
- External tables on cloud storage
- Directory tables for file metadata
- **Apache Iceberg tables** on Snowflake
- Catalog integrations (AWS Glue, Unity Catalog, Polaris)
- Delta Lake and Hudi interoperability
- External volumes

### Lesson 10.4: Cortex AI and ML in Snowflake
- Cortex LLM functions (`COMPLETE`, `SUMMARIZE`, `TRANSLATE`, etc.)
- Cortex Search for retrieval-augmented generation
- Cortex Analyst for natural language queries
- Snowflake ML: classification, regression, forecasting, anomaly detection
- Model registry and deployment
- Document AI and unstructured data processing

### Lesson 10.5: Snowpark Container Services
- Compute pools and GPU access
- Service specification (YAML)
- Building and deploying containers
- Service functions and ingress
- Image repositories in Snowflake

> **🧪 Lab:** Set up cross-region replication, create Iceberg tables, use Cortex AI

---

## Module 11: Orchestration & Ecosystem Integration

### Lesson 11.1: dbt with Snowflake
- dbt Core vs dbt Cloud
- Project structure: models, sources, seeds, macros
- Materializations: table, view, incremental, ephemeral
- dbt tests: generic and singular
- dbt documentation and lineage
- Jinja templating and custom macros
- dbt Projects on Snowflake (native integration)

### Lesson 11.2: Apache Airflow Integration
- Snowflake operators and hooks in Airflow
- Building DAGs for Snowflake pipelines
- Connection management and secrets
- Error handling and retries
- Airflow vs Snowflake Tasks: when to use which

### Lesson 11.3: CI/CD for Data Engineering
- Git integration with Snowflake
- Schema migration strategies
- Blue/green deployments for data pipelines
- Testing strategies: unit, integration, data quality
- Infrastructure as code (Terraform, Pulumi)
- GitHub Actions / GitLab CI for Snowflake

### Lesson 11.4: Monitoring and Observability
- `ACCOUNT_USAGE` schema views
- `INFORMATION_SCHEMA` for real-time metadata
- Query history analysis and optimization
- Warehouse monitoring and right-sizing
- Alert and notification integrations
- Snowflake event tables and logging

> **🧪 Lab:** Set up a dbt project with CI/CD pipeline and monitoring

---

## Module 12: Expert-Level Topics & Certification Prep

### Lesson 12.1: Cost Optimization Strategies
- Credit consumption analysis by warehouse, query, user
- Warehouse scheduling and auto-suspend tuning
- Storage optimization (transient tables, retention policies)
- Serverless features cost analysis
- Budgets, resource monitors, and chargeback models

### Lesson 12.2: Multi-Tenant Architecture Patterns
- Account-level multi-tenancy
- Schema-level multi-tenancy
- Row-level security for multi-tenancy
- Performance and cost isolation strategies

### Lesson 12.3: Real-Time and Near-Real-Time Patterns
- Snowpipe Streaming for sub-second latency
- Dynamic tables with minimal target lag
- Streams + tasks with 1-minute schedules
- Hybrid architectures (Kafka + Snowflake)
- Event-driven processing patterns

### Lesson 12.4: Data Quality and Testing
- Data quality checks with SQL
- Great Expectations integration
- dbt tests and custom test macros
- Snowflake Data Metric Functions (DMFs)
- Data observability and anomaly detection

### Lesson 12.5: SnowPro Certification Preparation

| Certification | Focus Areas |
|---------------|-------------|
| SnowPro Core | Architecture, SQL, data loading, security fundamentals |
| SnowPro Advanced: Data Engineer | Pipelines, optimization, semi-structured data, Snowpark |

- Key exam domains and weightings
- Practice scenarios and hands-on exercises
- Common pitfalls and exam strategies

> **🧪 Lab:** Design a production-grade multi-tenant real-time analytics platform

---

## Capstone Projects

### Project 1: E-Commerce Analytics Pipeline
- Ingest raw clickstream data (JSON) via Snowpipe
- Transform to star schema using dynamic tables
- Implement SCD Type 2 for customer dimension
- Build real-time inventory tracking with streams + tasks
- Create Cortex AI product recommendations
- Implement row-level security for multi-brand access
- Monitor pipeline health with alerts

### Project 2: IoT Sensor Data Platform
- Stream sensor data via Snowpipe Streaming
- Flatten nested VARIANT payloads
- Aggregate at multiple time granularities
- Anomaly detection with Cortex ML
- Data sharing with external partners
- Optimize with clustering on timestamp + device_id
- Implement data retention lifecycle

### Project 3: Financial Data Warehouse
- Multi-source ingestion (APIs, files, databases)
- Data Vault 2.0 modeling in raw layer
- Business vault transformations
- Dynamic data masking for PII
- Cross-region replication for DR
- Regulatory compliance (audit logging, retention)
- Performance optimization for complex reporting queries

---

## Recommended Learning Path

```
┌─────────────────────────────────────────────────────────────────────┐
│  BEGINNER          INTERMEDIATE        ADVANCED          EXPERT     │
│  Modules 1-3       Modules 4-6         Modules 7-9       Modules 10-12│
│                                                                     │
│  ● SQL fluency     ● Semi-structured   ● Performance     ● Enterprise│
│  ● Snowflake         data handling       optimization      architecture│
│    basics          ● First automated   ● Security best   ● Ecosystem │
│  ● Data loading      pipeline            practices         integration│
│                    ● Data modeling      ● Snowpark        ● Certification│
│                      trade-offs                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Resources
- **Snowflake Documentation:** docs.snowflake.com
- **Snowflake Community:** community.snowflake.com
- **Snowflake University:** learn.snowflake.com
- **Hands-on Labs:** quickstarts.snowflake.com
- **Certifications:** snowflake.com/certifications
