-- Cortex Agent over ADVANTAGE_VOICE_SV
-- Edit before running: warehouse name (COMPUTE_WH) in the spec below

USE SCHEMA ADVANTAGE_VOICE_DEMO.OPS;

CREATE OR REPLACE AGENT ADVANTAGE_VOICE_DEMO.OPS.ADVANTAGE_VOICE_AGENT
  COMMENT = 'Conversational analyst for Rogers Advantage Voice operations (synthetic sample data)'
  PROFILE = '{"display_name": "Advantage Voice Analyst"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    budget:
      seconds: 60
      tokens: 16000

  instructions:
    response: >
      Be concise and lead with the answer. Show money in CAD with 2 decimals and
      rates as percentages with 1 decimal. When the result has several rows,
      present a short table. State the time period used. If the question is
      ambiguous (for example "missed calls" could mean Missed only or Missed plus
      Abandoned), say which definition you used.
    orchestration: >
      Use the advantage_voice_analyst tool for every question about customers,
      seats, plans, calls, voice quality, billing, or support tickets. The data
      covers 2026-04-01 to 2026-09-30 only. For questions outside that scope,
      say so and suggest a related question the data can answer.
    sample_questions:
      - question: "Which provinces have the highest missed-call rate on hunt groups?"
      - question: "Show monthly recurring revenue by plan, split by bundled vs standalone customers."
      - question: "What is the average resolution time for escalated tickets by category?"
      - question: "Which industries generate the most international usage charges?"
      - question: "How did call quality and outage minutes trend by month?"
      - question: "Which customers churned and what reasons did they give?"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "advantage_voice_analyst"
        description: >
          Answers questions about Rogers Advantage Voice business phone operations
          using SQL over a semantic view: customers and churn, seats and plans,
          MRR, call detail (volumes, missed and abandoned rates, talk time, MOS),
          daily voice quality and outages, monthly billing, and support tickets.

  tool_resources:
    advantage_voice_analyst:
      semantic_view: "ADVANTAGE_VOICE_DEMO.OPS.ADVANTAGE_VOICE_SV"
      execution_environment:
        type: "warehouse"
        warehouse: "COMPUTE_WH"
      query_timeout: 60
  $$;

-- Access: run as ACCOUNTADMIN or grant the equivalents to your role
-- GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE <role>;
-- GRANT USAGE  ON DATABASE ADVANTAGE_VOICE_DEMO TO ROLE <role>;
-- GRANT USAGE  ON SCHEMA   ADVANTAGE_VOICE_DEMO.OPS TO ROLE <role>;
-- GRANT SELECT ON SEMANTIC VIEW ADVANTAGE_VOICE_DEMO.OPS.ADVANTAGE_VOICE_SV TO ROLE <role>;
-- GRANT USAGE  ON AGENT    ADVANTAGE_VOICE_DEMO.OPS.ADVANTAGE_VOICE_AGENT TO ROLE <role>;
-- GRANT USAGE  ON WAREHOUSE COMPUTE_WH TO ROLE <role>;

SHOW AGENTS IN SCHEMA ADVANTAGE_VOICE_DEMO.OPS;
DESCRIBE AGENT ADVANTAGE_VOICE_DEMO.OPS.ADVANTAGE_VOICE_AGENT;

-- Smoke test from SQL (the agent is also available in Snowsight under AI & ML > Agents)
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'ADVANTAGE_VOICE_DEMO.OPS.ADVANTAGE_VOICE_AGENT',
  $${"messages":[{"role":"user","content":[{"type":"text","text":"Which provinces have the highest missed-call rate on hunt groups?"}]}]}$$
) AS response;
