-- Semantic view for Cortex Analyst over the Advantage Voice sample data
-- Prereq: tables from load_to_snowflake.sql exist in ADVANTAGE_VOICE_DEMO.OPS
USE SCHEMA ADVANTAGE_VOICE_DEMO.OPS;

-- Helper view: seat + plan + customer bundle flag, so MRR can be a simple SUM on one table
CREATE OR REPLACE VIEW DIM_SEAT_PRICED AS
SELECT s.SEAT_ID, s.CUSTOMER_ID, s.PLAN_ID, p.PLAN_NAME, s.EXTENSION, s.DEPARTMENT,
       s.PRIMARY_DEVICE_TYPE, s.ACTIVATION_DATE, s.DEACTIVATION_DATE, s.SEAT_STATUS,
       IFF(c.INTERNET_BUNDLE_FLAG, p.INTERNET_BUNDLE_PRICE_CAD, p.LIST_PRICE_CAD) AS SEAT_MONTHLY_PRICE_CAD
FROM DIM_SEAT s
JOIN DIM_PLAN p     ON p.PLAN_ID = s.PLAN_ID
JOIN DIM_CUSTOMER c ON c.CUSTOMER_ID = s.CUSTOMER_ID;

CREATE OR REPLACE SEMANTIC VIEW ADVANTAGE_VOICE_DEMO.OPS.ADVANTAGE_VOICE_SV

  TABLES (
    customers   AS ADVANTAGE_VOICE_DEMO.OPS.DIM_CUSTOMER
      PRIMARY KEY (customer_id)
      WITH SYNONYMS = ('client', 'clients', 'account', 'accounts', 'company', 'business customer')
      COMMENT = 'Business customers subscribed to Rogers Advantage Voice. One row per customer.',
    seats       AS ADVANTAGE_VOICE_DEMO.OPS.DIM_SEAT_PRICED
      PRIMARY KEY (seat_id)
      WITH SYNONYMS = ('lines', 'licenses', 'users', 'subscriptions')
      COMMENT = 'Licensed Advantage Voice seats (one per user line) with plan and monthly price after any Internet bundle discount.',
    call_groups AS ADVANTAGE_VOICE_DEMO.OPS.DIM_CALL_GROUP
      PRIMARY KEY (call_group_id)
      WITH SYNONYMS = ('hunt groups', 'auto attendants', 'call queues', 'routing groups')
      COMMENT = 'Call routing constructs configured by a customer: auto attendants, hunt groups, virtual receptionists.',
    calls       AS ADVANTAGE_VOICE_DEMO.OPS.FACT_CALL_DETAIL
      PRIMARY KEY (call_id)
      WITH SYNONYMS = ('call records', 'CDR', 'call detail', 'call logs')
      COMMENT = 'Call detail records, one row per call, timestamps in the customer local time. Sampled operational data.',
    quality     AS ADVANTAGE_VOICE_DEMO.OPS.FACT_SERVICE_QUALITY_DAILY
      PRIMARY KEY (customer_id, service_date)
      WITH SYNONYMS = ('network quality', 'voice quality', 'service health', 'outages')
      COMMENT = 'Daily voice quality (MOS, jitter, packet loss) and outage minutes per customer.',
    billing     AS ADVANTAGE_VOICE_DEMO.OPS.FACT_MONTHLY_BILLING
      PRIMARY KEY (invoice_id)
      WITH SYNONYMS = ('invoices', 'revenue', 'bills')
      COMMENT = 'Monthly invoice per customer in CAD. billing_month is the first day of the month.',
    tickets     AS ADVANTAGE_VOICE_DEMO.OPS.FACT_SUPPORT_TICKET
      PRIMARY KEY (ticket_id)
      WITH SYNONYMS = ('support tickets', 'cases', 'incidents', 'support requests')
      COMMENT = 'Customer support tickets, one row per ticket.'
  )

  RELATIONSHIPS (
    calls_to_seats       AS calls(seat_id)              REFERENCES seats(seat_id),
    calls_to_groups      AS calls(call_group_id)        REFERENCES call_groups(call_group_id),
    seats_to_customers   AS seats(customer_id)          REFERENCES customers(customer_id),
    quality_to_customers AS quality(customer_id)        REFERENCES customers(customer_id),
    billing_to_customers AS billing(customer_id)        REFERENCES customers(customer_id),
    tickets_to_customers AS tickets(customer_id)        REFERENCES customers(customer_id)
  )

  FACTS (
    seats.seat_monthly_price_cad   AS seat_monthly_price_cad   COMMENT = 'Monthly price per seat in CAD after bundle pricing',
    calls.ring_seconds             AS ring_seconds             COMMENT = 'Seconds the call rang before answer or abandonment',
    calls.talk_seconds             AS talk_seconds             COMMENT = 'Conversation or voicemail duration in seconds; 0 when not connected',
    calls.mos_score                AS mos_score                COMMENT = 'Mean Opinion Score per call, 1 to 5 (4.0+ good, below 3.6 poor); NULL when not connected',
    calls.jitter_ms                AS jitter_ms                COMMENT = 'Jitter in milliseconds',
    calls.packet_loss_pct          AS packet_loss_pct          COMMENT = 'Packet loss percent (0-100 scale)',
    quality.avg_mos                AS avg_mos                  COMMENT = 'Customer daily average MOS',
    quality.avg_jitter_ms          AS avg_jitter_ms            COMMENT = 'Customer daily average jitter in ms',
    quality.avg_packet_loss_pct    AS avg_packet_loss_pct      COMMENT = 'Customer daily average packet loss percent',
    quality.outage_minutes         AS outage_minutes           COMMENT = 'Minutes of service outage that day',
    billing.active_seats           AS active_seats             COMMENT = 'Seats billed on the invoice',
    billing.subscription_charge_cad AS subscription_charge_cad COMMENT = 'Seat subscription charges at list price',
    billing.bundle_discount_cad    AS bundle_discount_cad      COMMENT = 'Internet bundle discount, stored as a negative number',
    billing.international_usage_cad AS international_usage_cad COMMENT = 'International calling usage charges',
    billing.one_time_charges_cad   AS one_time_charges_cad     COMMENT = 'One-time charges such as porting or setup fees',
    billing.subtotal_cad           AS subtotal_cad             COMMENT = 'Invoice amount before tax',
    billing.tax_cad                AS tax_cad                  COMMENT = 'Sales tax (GST/HST/PST/QST) on the invoice',
    billing.total_invoiced_cad     AS total_invoiced_cad       COMMENT = 'Invoice total including tax',
    billing.days_to_pay            AS days_to_pay              COMMENT = 'Days from invoice to payment; NULL if unpaid',
    tickets.first_response_minutes AS first_response_minutes   COMMENT = 'Minutes until first support response',
    tickets.resolution_hours       AS resolution_hours         COMMENT = 'Hours to resolve; NULL while open',
    tickets.csat_score             AS csat_score               COMMENT = 'Customer satisfaction 1 (worst) to 5 (best); NULL if no survey response'
  )

  DIMENSIONS (
    -- customers
    customers.customer_id          AS customer_id,
    customers.company_name         AS company_name         WITH SYNONYMS = ('customer name', 'client name', 'business name') COMMENT = 'Customer company name',
    customers.industry             AS industry             WITH SYNONYMS = ('vertical', 'sector') COMMENT = 'Customer industry: Dental & Medical Clinics, Legal Services, Real Estate, Construction & Trades, Retail, Restaurants & Hospitality, Professional Services, Non-Profit & Education',
    customers.province             AS province             WITH SYNONYMS = ('region', 'state') COMMENT = 'Canadian province code: ON, QC, BC, AB, MB, SK, NS, NB, NL',
    customers.city                 AS city                 COMMENT = 'Customer city',
    customers.time_zone            AS time_zone            COMMENT = 'IANA time zone of the customer',
    customers.customer_segment     AS customer_segment     WITH SYNONYMS = ('size', 'customer size') COMMENT = 'Size band based on initial seat count: Small (<10 seats), Medium (10-24 seats), Large (25+ seats)',
    customers.internet_bundle_flag AS internet_bundle_flag WITH SYNONYMS = ('bundled', 'bundle') COMMENT = 'TRUE if the customer bundles Advantage Voice with Rogers Business Internet',
    customers.contract_start_date  AS contract_start_date  COMMENT = 'Contract start date',
    customers.contract_end_date    AS contract_end_date    WITH SYNONYMS = ('renewal date') COMMENT = 'Contract end / renewal date',
    customers.contract_term_months AS contract_term_months COMMENT = 'Contract term: 12, 24 or 36 months',
    customers.customer_status      AS customer_status      COMMENT = 'Active or Churned',
    customers.churn_date           AS churn_date           WITH SYNONYMS = ('cancellation date') COMMENT = 'Date the customer left; NULL for active customers',
    customers.churn_reason         AS churn_reason         WITH SYNONYMS = ('cancellation reason') COMMENT = 'Reason for leaving; NULL for active customers',

    -- seats
    seats.seat_id                  AS seat_id,
    seats.plan_id                  AS plan_id              COMMENT = 'AV-BASIC, AV-REMOTE or AV-OFFICE',
    seats.plan_name                AS plan_name            WITH SYNONYMS = ('plan', 'product tier') COMMENT = 'Advantage Voice Basic, Advantage Voice Remote or Advantage Voice Office',
    seats.department               AS department           COMMENT = 'Department of the seat user',
    seats.primary_device_type      AS primary_device_type  WITH SYNONYMS = ('seat device') COMMENT = 'Primary device: Desk Phone, Mobile App, Desktop App, Microsoft Teams',
    seats.extension                AS extension            COMMENT = 'Internal extension number',
    seats.activation_date          AS activation_date      COMMENT = 'Date the seat was activated',
    seats.deactivation_date        AS deactivation_date    COMMENT = 'Date the seat was deactivated; NULL if still active',
    seats.seat_status              AS seat_status          COMMENT = 'Active or Deactivated as of 2026-09-30',

    -- call groups
    call_groups.call_group_id      AS call_group_id,
    call_groups.group_name         AS group_name           COMMENT = 'Name of the routing group, e.g. Main Menu, Sales Line, Support Line',
    call_groups.group_type         AS group_type           WITH SYNONYMS = ('routing type') COMMENT = 'Auto Attendant, Hunt Group or Virtual Receptionist. Calls with no group have NULL here.',

    -- calls
    calls.call_id                  AS call_id,
    calls.call_start_ts            AS call_start_ts        COMMENT = 'Call start timestamp, customer local time',
    calls.call_date                AS CAST(call_start_ts AS DATE)                      COMMENT = 'Call date',
    calls.call_month               AS CAST(DATE_TRUNC('MONTH', call_start_ts) AS DATE) COMMENT = 'First day of the month of the call',
    calls.call_hour                AS HOUR(call_start_ts)  WITH SYNONYMS = ('hour of day') COMMENT = 'Hour of day 0-23 in customer local time',
    calls.call_day_of_week         AS DAYNAME(call_start_ts) COMMENT = 'Day name: Mon, Tue, ...',
    calls.day_type                 AS IFF(DAYOFWEEKISO(call_start_ts) >= 6, 'Weekend', 'Weekday') COMMENT = 'Weekday or Weekend',
    calls.direction                AS direction            COMMENT = 'Inbound, Outbound or Internal (extension to extension)',
    calls.call_type                AS call_type            COMMENT = 'Local, Toll-Free, Long Distance - Canada, Long Distance - US, International, Internal',
    calls.remote_country           AS remote_country       WITH SYNONYMS = ('destination country', 'far end country') COMMENT = 'Country of the other party: Canada, USA or an international destination',
    calls.disposition              AS disposition          WITH SYNONYMS = ('call outcome', 'call result') COMMENT = 'Answered, Missed, Voicemail, Abandoned (caller hung up while ringing), No Answer (outbound), Busy',
    calls.device_type              AS device_type          WITH SYNONYMS = ('call device') COMMENT = 'Device the call was handled on',

    -- quality
    quality.service_date           AS service_date         COMMENT = 'Date of the quality measurement',
    quality.service_month          AS CAST(DATE_TRUNC('MONTH', service_date) AS DATE) COMMENT = 'First day of the month',
    quality.degraded_day_flag      AS degraded_day_flag    WITH SYNONYMS = ('bad quality day') COMMENT = 'TRUE if voice quality was degraded or an outage occurred that day',

    -- billing
    billing.invoice_id             AS invoice_id,
    billing.billing_month          AS billing_month        WITH SYNONYMS = ('invoice month', 'month') COMMENT = 'First day of the billing month, 2026-04-01 to 2026-09-01',
    billing.payment_status         AS payment_status       COMMENT = 'Paid, Outstanding or Overdue',

    -- tickets
    tickets.ticket_id              AS ticket_id,
    tickets.category               AS category             WITH SYNONYMS = ('ticket type', 'issue type') COMMENT = 'Call Quality, Provisioning / Seat Changes, Number Porting, Billing Inquiry, Auto Attendant / Hunt Group Config, Voicemail, Teams Integration, Outage, Hardware / Desk Phone',
    tickets.priority               AS priority             COMMENT = 'Low, Medium, High or Critical',
    tickets.channel                AS channel              COMMENT = 'How the ticket was raised: Phone, Portal, Chat, Email',
    tickets.ticket_status          AS ticket_status        COMMENT = 'Open or Resolved',
    tickets.escalated_flag         AS escalated_flag       WITH SYNONYMS = ('escalated') COMMENT = 'TRUE if escalated to a higher support tier',
    tickets.opened_ts              AS opened_ts            COMMENT = 'Ticket opened timestamp',
    tickets.opened_month           AS CAST(DATE_TRUNC('MONTH', opened_ts) AS DATE) COMMENT = 'First day of the month the ticket was opened'
  )

  METRICS (
    -- customers
    customers.customer_count       AS COUNT(customers.customer_id)
      WITH SYNONYMS = ('number of customers') COMMENT = 'Number of customers',
    customers.active_customer_count AS COUNT(CASE WHEN customers.customer_status = 'Active' THEN 1 END)
      COMMENT = 'Customers currently active',
    customers.churned_customer_count AS COUNT(CASE WHEN customers.customer_status = 'Churned' THEN 1 END)
      COMMENT = 'Customers that churned',
    customers.churn_rate           AS COUNT(CASE WHEN customers.customer_status = 'Churned' THEN 1 END) / NULLIF(COUNT(customers.customer_id), 0)
      WITH SYNONYMS = ('customer churn') COMMENT = 'Churned customers divided by all customers, a 0-1 ratio',

    -- seats
    seats.total_seat_count         AS COUNT(seats.seat_id)
      COMMENT = 'All seats ever provisioned, including deactivated',
    seats.active_seat_count        AS COUNT(CASE WHEN seats.seat_status = 'Active' THEN 1 END)
      WITH SYNONYMS = ('active lines', 'active users', 'seats in service') COMMENT = 'Seats active as of 2026-09-30',
    seats.current_mrr_cad          AS SUM(CASE WHEN seats.seat_status = 'Active' THEN seats.seat_monthly_price_cad END)
      WITH SYNONYMS = ('MRR', 'monthly recurring revenue', 'recurring revenue') COMMENT = 'Monthly recurring subscription revenue in CAD from active seats at current plan and bundle pricing, before tax and usage',
    seats.avg_seat_price_cad       AS AVG(CASE WHEN seats.seat_status = 'Active' THEN seats.seat_monthly_price_cad END)
      WITH SYNONYMS = ('ARPU', 'revenue per seat') COMMENT = 'Average monthly price per active seat in CAD',

    -- calls
    calls.total_calls              AS COUNT(calls.call_id)
      WITH SYNONYMS = ('call volume', 'number of calls') COMMENT = 'Total number of calls',
    calls.inbound_calls            AS COUNT(CASE WHEN calls.direction = 'Inbound' THEN 1 END)
      COMMENT = 'Inbound calls',
    calls.outbound_calls           AS COUNT(CASE WHEN calls.direction = 'Outbound' THEN 1 END)
      COMMENT = 'Outbound calls',
    calls.internal_calls           AS COUNT(CASE WHEN calls.direction = 'Internal' THEN 1 END)
      COMMENT = 'Extension to extension calls',
    calls.international_calls      AS COUNT(CASE WHEN calls.call_type = 'International' THEN 1 END)
      COMMENT = 'International calls',
    calls.answered_calls           AS COUNT(CASE WHEN calls.disposition = 'Answered' THEN 1 END)
      COMMENT = 'Calls with disposition Answered',
    calls.missed_calls             AS COUNT(CASE WHEN calls.disposition = 'Missed' THEN 1 END)
      COMMENT = 'Calls with disposition Missed',
    calls.abandoned_calls          AS COUNT(CASE WHEN calls.disposition = 'Abandoned' THEN 1 END)
      COMMENT = 'Inbound calls where the caller hung up while ringing',
    calls.voicemail_calls          AS COUNT(CASE WHEN calls.disposition = 'Voicemail' THEN 1 END)
      COMMENT = 'Calls that went to voicemail',
    calls.answer_rate              AS COUNT(CASE WHEN calls.direction = 'Inbound' AND calls.disposition = 'Answered' THEN 1 END) / NULLIF(COUNT(CASE WHEN calls.direction = 'Inbound' THEN 1 END), 0)
      COMMENT = 'Inbound calls answered divided by inbound calls, a 0-1 ratio',
    calls.missed_call_rate         AS COUNT(CASE WHEN calls.direction = 'Inbound' AND calls.disposition = 'Missed' THEN 1 END) / NULLIF(COUNT(CASE WHEN calls.direction = 'Inbound' THEN 1 END), 0)
      WITH SYNONYMS = ('missed rate', 'miss rate') COMMENT = 'Inbound calls with disposition Missed divided by inbound calls, a 0-1 ratio. Excludes abandoned calls.',
    calls.missed_or_abandoned_rate AS COUNT(CASE WHEN calls.direction = 'Inbound' AND calls.disposition IN ('Missed', 'Abandoned') THEN 1 END) / NULLIF(COUNT(CASE WHEN calls.direction = 'Inbound' THEN 1 END), 0)
      WITH SYNONYMS = ('unanswered rate', 'lost call rate') COMMENT = 'Inbound calls Missed or Abandoned divided by inbound calls, a 0-1 ratio',
    calls.total_talk_minutes       AS SUM(calls.talk_seconds) / 60.0
      COMMENT = 'Total talk time in minutes',
    calls.avg_talk_minutes_per_answered_call AS AVG(CASE WHEN calls.disposition = 'Answered' THEN calls.talk_seconds END) / 60.0
      WITH SYNONYMS = ('average call duration', 'AHT', 'average handle time') COMMENT = 'Average conversation length in minutes for answered calls',
    calls.avg_ring_seconds         AS AVG(calls.ring_seconds)
      COMMENT = 'Average seconds a call rang',
    calls.avg_call_mos             AS AVG(calls.mos_score)
      WITH SYNONYMS = ('average MOS', 'call quality score') COMMENT = 'Average MOS across connected calls, 1 to 5',
    calls.avg_call_jitter_ms       AS AVG(calls.jitter_ms)
      COMMENT = 'Average jitter in ms across connected calls',
    calls.avg_call_packet_loss_pct AS AVG(calls.packet_loss_pct)
      COMMENT = 'Average packet loss percent across connected calls',
    calls.poor_quality_calls       AS COUNT(CASE WHEN calls.mos_score < 3.6 THEN 1 END)
      COMMENT = 'Connected calls with MOS below 3.6',
    calls.poor_quality_call_pct    AS COUNT(CASE WHEN calls.mos_score < 3.6 THEN 1 END) / NULLIF(COUNT(calls.mos_score), 0)
      COMMENT = 'Share of connected calls with MOS below 3.6, a 0-1 ratio',

    -- quality
    quality.avg_daily_mos          AS AVG(quality.avg_mos)
      COMMENT = 'Average of customer daily MOS values',
    quality.avg_daily_jitter_ms    AS AVG(quality.avg_jitter_ms)
      COMMENT = 'Average of daily jitter in ms',
    quality.avg_daily_packet_loss_pct AS AVG(quality.avg_packet_loss_pct)
      COMMENT = 'Average of daily packet loss percent',
    quality.total_outage_minutes   AS SUM(quality.outage_minutes)
      WITH SYNONYMS = ('downtime') COMMENT = 'Total minutes of outage',
    quality.degraded_day_count     AS COUNT(CASE WHEN quality.degraded_day_flag THEN 1 END)
      COMMENT = 'Customer-days flagged as degraded or with an outage',
    quality.outage_day_count       AS COUNT(CASE WHEN quality.outage_minutes > 0 THEN 1 END)
      COMMENT = 'Customer-days with at least one outage minute',

    -- billing
    billing.invoice_count          AS COUNT(billing.invoice_id)
      COMMENT = 'Number of invoices',
    billing.seat_months_billed     AS SUM(billing.active_seats)
      COMMENT = 'Sum of billed seats across invoices (seat-months)',
    billing.total_subscription_charges AS SUM(billing.subscription_charge_cad)
      COMMENT = 'Seat subscription charges at list price in CAD',
    billing.total_bundle_discounts AS SUM(billing.bundle_discount_cad)
      COMMENT = 'Internet bundle discounts in CAD, a negative number',
    billing.total_international_usage AS SUM(billing.international_usage_cad)
      WITH SYNONYMS = ('international charges', 'international revenue') COMMENT = 'Billed international calling charges in CAD',
    billing.total_one_time_charges AS SUM(billing.one_time_charges_cad)
      COMMENT = 'One-time charges in CAD',
    billing.revenue_before_tax     AS SUM(billing.subtotal_cad)
      WITH SYNONYMS = ('billed revenue', 'net revenue') COMMENT = 'Invoiced revenue before tax in CAD',
    billing.total_tax              AS SUM(billing.tax_cad)
      COMMENT = 'Tax billed in CAD',
    billing.total_invoiced         AS SUM(billing.total_invoiced_cad)
      WITH SYNONYMS = ('total billings', 'invoice total') COMMENT = 'Invoiced amount including tax in CAD',
    billing.overdue_invoice_count  AS COUNT(CASE WHEN billing.payment_status = 'Overdue' THEN 1 END)
      COMMENT = 'Invoices with payment status Overdue',
    billing.overdue_amount         AS SUM(CASE WHEN billing.payment_status = 'Overdue' THEN billing.total_invoiced_cad END)
      WITH SYNONYMS = ('past due amount', 'receivables overdue') COMMENT = 'Invoiced amount in CAD that is Overdue',
    billing.outstanding_amount     AS SUM(CASE WHEN billing.payment_status IN ('Outstanding', 'Overdue') THEN billing.total_invoiced_cad END)
      COMMENT = 'Invoiced amount in CAD not yet paid (Outstanding plus Overdue)',
    billing.avg_days_to_pay        AS AVG(billing.days_to_pay)
      COMMENT = 'Average days to pay, paid invoices only',

    -- tickets
    tickets.ticket_count           AS COUNT(tickets.ticket_id)
      WITH SYNONYMS = ('number of tickets', 'ticket volume') COMMENT = 'Number of support tickets',
    tickets.open_ticket_count      AS COUNT(CASE WHEN tickets.ticket_status = 'Open' THEN 1 END)
      COMMENT = 'Tickets still open',
    tickets.escalated_ticket_count AS COUNT(CASE WHEN tickets.escalated_flag THEN 1 END)
      COMMENT = 'Tickets that were escalated',
    tickets.escalation_rate        AS COUNT(CASE WHEN tickets.escalated_flag THEN 1 END) / NULLIF(COUNT(tickets.ticket_id), 0)
      COMMENT = 'Escalated tickets divided by all tickets, a 0-1 ratio',
    tickets.avg_first_response_minutes AS AVG(tickets.first_response_minutes)
      COMMENT = 'Average minutes to first response',
    tickets.avg_resolution_hours   AS AVG(tickets.resolution_hours)
      WITH SYNONYMS = ('time to resolve', 'MTTR') COMMENT = 'Average hours to resolve, resolved tickets only',
    tickets.avg_csat               AS AVG(tickets.csat_score)
      WITH SYNONYMS = ('customer satisfaction', 'CSAT') COMMENT = 'Average CSAT 1 to 5, tickets with a survey response only',
    tickets.low_csat_count         AS COUNT(CASE WHEN tickets.csat_score <= 2 THEN 1 END)
      COMMENT = 'Tickets with CSAT of 1 or 2'
  )

  COMMENT = 'Rogers Advantage Voice operational data: customers, seats and plans, call detail, daily voice quality, billing and support tickets. Data covers 2026-04-01 to 2026-09-30. Synthetic sample data.'

  AI_SQL_GENERATION 'Data covers 2026-04-01 through 2026-09-30; treat the latest date as today, so last month is September 2026 and last quarter is Q3 2026. Currency is CAD. Rate metrics are 0-1 ratios, so show them as percentages rounded to 1 decimal. Missed call rate and answer rate use inbound calls as the denominator. Abandoned calls are tracked separately from Missed; use missed_or_abandoned_rate when the user asks about lost or unanswered calls. Hunt group questions use call_groups.group_type = ''Hunt Group'', and calls not routed through a group have NULL group fields. MRR is recurring subscription revenue from active seats (current_mrr_cad), not billed revenue. billing_month is the first day of the month. Provinces are two-letter codes. For churn questions use customers.customer_status and churn_date. Customers do not link tickets to individual seats. Round money to 2 decimals and durations to 1 decimal.'

  AI_QUESTION_CATEGORIZATION 'Answer questions about Advantage Voice customers, seats, plans, calls, voice quality, billing and support tickets. For questions about other Rogers products, about data outside April to September 2026, or requests to predict future values, explain that this data does not cover them and suggest a related question that it can answer.';

-- Smoke tests -------------------------------------------------------------
SHOW SEMANTIC VIEWS LIKE 'ADVANTAGE_VOICE_SV';

SELECT * FROM SEMANTIC_VIEW(
  ADVANTAGE_VOICE_DEMO.OPS.ADVANTAGE_VOICE_SV
  DIMENSIONS customers.province
  METRICS calls.total_calls, calls.missed_call_rate
) ORDER BY missed_call_rate DESC;

SELECT * FROM SEMANTIC_VIEW(
  ADVANTAGE_VOICE_DEMO.OPS.ADVANTAGE_VOICE_SV
  DIMENSIONS seats.plan_name, customers.internet_bundle_flag
  METRICS seats.active_seat_count, seats.current_mrr_cad
) ORDER BY 1, 2;
