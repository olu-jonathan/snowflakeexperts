CREATE OR REPLACE AGENT GENERAL_DB.PUBLIC.CLAIMS_AGENT
  COMMENT = 'Health insurance claims agent with analytics and subscriber lookup'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  instructions:
    response: |
      You are a health insurance claims analyst. Present data clearly
      and concisely. When showing financial amounts, format as currency.
    orchestration: |
      You have two tools:
      1. claims_analyst - for analytical questions (totals, averages,
         breakdowns, trends, comparisons across claims data).
      2. subscriber_lookup - for looking up a specific subscriber's claims
         summary by their certificate number (e.g. C34265580).
      When a user asks about a specific subscriber, use subscriber_lookup.
      For general analytics, use claims_analyst.
    sample_questions:
      - question: "What is the total billed amount by state?"
      - question: "Look up subscriber C34265580"
      - question: "What are the most common procedures?"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "claims_analyst"
        description: >
          Answers analytical questions about health insurance claims data
          including billed amounts, payments, procedures, providers, and
          patients. Use for aggregations, trends, and comparisons.
    - tool_spec:
        type: "generic"
        name: "subscriber_lookup"
        description: >
          Looks up a specific subscriber by certificate number and returns
          their claims summary including total claims, billed/paid amounts,
          adjustments, reversals, providers seen, and service date range.
          Requires a subscriber certificate number like C34265580.
        input_schema:
          type: "object"
          properties:
            CERT_NBR:
              type: "string"
              description: "The subscriber certificate number, e.g. C34265580"
          required:
            - CERT_NBR

  tool_resources:
    claims_analyst:
      semantic_view: "GENERAL_DB.PUBLIC.CLAIMS_SV"
    subscriber_lookup:
      type: "function"
      execution_environment:
        type: "warehouse"
        warehouse: "COMPUTE_WH"
      identifier: "GENERAL_DB.PUBLIC.SUBSCRIBER_CLAIMS_SUMMARY"
  $$;