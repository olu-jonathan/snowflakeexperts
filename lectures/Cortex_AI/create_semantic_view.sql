CREATE OR REPLACE SEMANTIC VIEW GENERAL_DB.PUBLIC.CLAIMS_SV

  -- Define the logical table over the physical CLAIMS table
  TABLES (
    claims AS GENERAL_DB.PUBLIC.CLAIMS
      PRIMARY KEY (CLAIM_CONTROL_NBR)
      COMMENT = 'Dental insurance claims at the service-line level'
  )

  -- Facts: numeric columns used in metric calculations (must come before DIMENSIONS)
  FACTS (
    claims.billed_amount AS BILLED_AMOUNT
      COMMENT = 'Amount billed by the provider',
    claims.payment_amount AS PAYMENT_AMOUNT
      COMMENT = 'Amount paid on the claim',
    claims.allowed_amount AS ALLOWED_AMOUNT
      COMMENT = 'Allowed or contracted amount for the service',
    claims.deductible AS DEDUCTIBLE
      COMMENT = 'Deductible amount applied',
    claims.coinsurance AS COINSURANCE
      COMMENT = 'Coinsurance amount applied',
    claims.network_savings AS NETWORK_SAVINGS
      COMMENT = 'Savings from in-network pricing'
  )

  -- Dimensions: categorical attributes (who, what, where, when)
  DIMENSIONS (
    claims.claim_control_nbr AS CLAIM_CONTROL_NBR
      COMMENT = 'Unique claim identifier',
    claims.claim_status AS CLAIM_STATUS
      WITH SYNONYMS = ('status', 'claim state')
      COMMENT = 'Current status of the claim (e.g. Adjustment, Reversal)',
    claims.group_name AS GROUP_NAME
      WITH SYNONYMS = ('employer', 'plan')
      COMMENT = 'Employer group or plan name',
    claims.subscriber_state AS SUBSCRIBER_STATE_OF_RESIDENCE
      WITH SYNONYMS = ('state', 'subscriber state')
      COMMENT = 'US state where the subscriber resides',
    claims.patient_gender AS PATIENT_GENDER
      COMMENT = 'Gender of the patient (M/F)',
    claims.provider_name AS SERVICING_PROVIDER_NAME
      WITH SYNONYMS = ('provider', 'dentist')
      COMMENT = 'Name of the servicing provider or dentist',
    claims.provider_state AS SERVICING_PROVIDER_STATE
      COMMENT = 'State where the provider is located',
    claims.procedure_code AS BILLED_PROC_CODE
      COMMENT = 'Procedure code billed (e.g. D1110, D7210)',
    claims.procedure_desc AS BILLED_PROC_CODE_DESC
      WITH SYNONYMS = ('procedure', 'service description')
      COMMENT = 'Human-readable description of the procedure',
    claims.in_network_ind AS PROVIDER_PARTICIPATION_IND
      COMMENT = 'Whether the provider is in-network (P) or out-of-network',
    claims.service_date AS BEGIN_DATE_OF_SERVICE
      WITH SYNONYMS = ('date of service', 'service date')
      COMMENT = 'Date the service was performed',
    claims.paid_date AS PAID_DATE
      COMMENT = 'Date the claim was paid',
    claims.processed_date AS DATE_CLAIM_PROCESSED
      COMMENT = 'Date the claim was processed or adjudicated'
  )

  -- Metrics: pre-defined aggregations for common questions
  METRICS (
    claims.total_billed AS SUM(claims.billed_amount)
      COMMENT = 'Total billed amount across claims',
    claims.total_paid AS SUM(claims.payment_amount)
      COMMENT = 'Total payment amount across claims',
    claims.total_allowed AS SUM(claims.allowed_amount)
      COMMENT = 'Total allowed amount across claims',
    claims.total_network_savings AS SUM(claims.network_savings)
      COMMENT = 'Total savings from in-network pricing',
    claims.claim_count AS COUNT(claims.claim_control_nbr)
      COMMENT = 'Number of claims',
    claims.avg_billed AS AVG(claims.billed_amount)
      COMMENT = 'Average billed amount per claim',
    claims.avg_paid AS AVG(claims.payment_amount)
      COMMENT = 'Average payment per claim'
  )

  COMMENT = 'Semantic view for health insurance claims analysis';