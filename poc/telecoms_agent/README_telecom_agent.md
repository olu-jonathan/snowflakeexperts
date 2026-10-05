# Telecom Business Voice: Snowflake Cortex Analyst Demo

A self-contained demo that builds a conversational analytics agent on top of synthetic operational data for a telecom company's hosted business phone service (cloud PBX / unified communications). It includes sample data, Snowflake DDL, a semantic view for Cortex Analyst text-to-SQL, and a Cortex Agent that uses it.

All data is synthetic. Company names, volumes, prices and outcomes are invented for demonstration only.

## What you get

| Path | Purpose |
|---|---|
| `data/*.csv` | Eight CSV files forming a small star schema (Apr to Sep 2026) |
| `sql/load_to_snowflake.sql` | Database, schema, file format, stage, table DDL and `COPY INTO` |
| `sql/create_semantic_view.sql` | Helper view plus `CREATE SEMANTIC VIEW` with facts, dimensions, metrics and AI instructions |
| `sql/create_agent.sql` | `CREATE AGENT` using the semantic view as a Cortex Analyst tool |
| `scripts/generate_data.py` | Seeded generator that reproduces the CSVs (numpy and pandas) |

## Data model

The service has three plan tiers (Basic, Remote, Office), optionally bundled with an Internet product at a per-seat discount. Customers license seats, route inbound calls through auto attendants and hunt groups, receive monthly invoices, and raise support tickets.

| Table | Rows | Grain |
|---|---|---|
| `dim_plan` | 3 | Plan tier and pricing |
| `dim_customer` | 55 | Business customer: industry, province, segment, bundle flag, contract and churn details |
| `dim_seat` | 637 | Licensed user line with plan, department, device, activation and deactivation dates |
| `dim_call_group` | 138 | Auto attendant, hunt group or virtual receptionist |
| `fact_call_detail` | 47,225 | One row per call: direction, type, disposition, ring and talk seconds, MOS, jitter, packet loss |
| `fact_service_quality_daily` | 9,444 | Daily voice quality and outage minutes per customer |
| `fact_monthly_billing` | 316 | One invoice per customer per month in CAD |
| `fact_support_ticket` | 453 | Support ticket with category, priority, response and resolution times, escalation and CSAT |

Relationships in the semantic view: calls to seats and call groups; seats, daily quality, billing and tickets to customers. `sql/create_semantic_view.sql` also creates a helper view, `DIM_SEAT_PRICED`, which joins seats to plan and bundle pricing so MRR is a simple sum.

Patterns built into the data, so there are interesting answers to find:

- Degraded-quality days lower MOS, raise missed and abandoned rates, and generate Call Quality and Outage tickets.
- Bundled customers get a per-seat discount shown as a negative line on invoices.
- International calls are rated per minute by destination and flow into monthly invoices.
- Five customers churn during the period, with their seats deactivated on the churn date.
- Call volume peaks on weekdays during business hours, with front desk seats the busiest.

## Setup

Prerequisites: a Snowflake account with Cortex Analyst and Cortex Agents available in your region, a role that can create databases, and a warehouse.

1. **Load the data.** Run `sql/load_to_snowflake.sql` to create `ADVANTAGE_VOICE_DEMO.OPS`, the stage and the tables. Upload everything in `data/` to the `AV_STAGE` stage (Snowsight: Data > Add Data, or `PUT`), then run the `COPY INTO` statements at the end of the script.
2. **Create the semantic view.** Run `sql/create_semantic_view.sql`. The two queries at the bottom confirm it works.
3. **Create the agent.** Edit the warehouse name in `sql/create_agent.sql` (`COMPUTE_WH` by default), then run it. Uncomment the grants if other roles need access.
4. **Chat.** Open the agent in Snowsight under AI & ML > Agents, or call it from SQL with `SNOWFLAKE.CORTEX.DATA_AGENT_RUN` (example at the bottom of the script).

To regenerate the data: `pip install numpy pandas` then `python scripts/generate_data.py`. The generator is seeded, so it reproduces the same files.

## Example questions

- Which provinces have the highest missed-call rate on hunt groups?
- Show monthly recurring revenue by plan, split by bundled vs standalone customers.
- Which industries generate the most international usage charges?
- What is the average resolution time for escalated tickets by category?
- How did call quality and outage minutes trend by month?
- Which customers churned, and what reasons did they give?

## Metric definitions

| Metric | Definition |
|---|---|
| Missed call rate | Inbound calls with disposition Missed divided by all inbound calls. Excludes Abandoned. |
| Missed or abandoned rate | Inbound calls Missed or Abandoned divided by all inbound calls |
| MRR (`current_mrr_cad`) | Subscription revenue from seats active at 2026-09-30, at current plan and bundle pricing, before tax and usage |
| Poor quality call | Connected call with MOS below 3.6 |
| Churn rate | Churned customers divided by all customers |

Rates are stored as 0 to 1 ratios; the agent is instructed to present them as percentages.

## Known limitations

- Questions that need a date-window join across tables, such as "which churned customers raised quality tickets in the 60 days before leaving", are not expressible in a semantic view. Handle these with a dedicated view or a verified query.
- Tickets are linked to customers, not to individual seats.
- The data covers 2026-04-01 to 2026-09-30 only. The agent is instructed to treat 2026-09-30 as the current date.
- Plan prices are illustrative.

## Next steps

- Add `AI_VERIFIED_QUERIES` to the semantic view for your most important questions.
- Add a Cortex Search tool over support articles or runbooks so the agent can combine metrics with documentation.
- Replace the synthetic tables with your own pipelines while keeping the semantic view contract.
