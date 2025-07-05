INSERT INTO fact_performance (
    employee_key,
    review_date_key,
    review_period_start_key,
    review_period_end_key,
    reviewer_employee_key,
    review_type,
    overall_rating,
    goals_achievement_score,
    competency_score,
    leadership_score,
    potential_rating,
    promotion_readiness,
    development_priority,
    created_at,
    updated_at
)
SELECT
    (i % 20 + 1),                             -- employee_key: 1–20
    20250700 + (i % 28 + 1),                  -- review_date_key: 2025-07-01 → 2025-07-28
    20250100 + (i % 28 + 1),                  -- review_period_start_key: 2025-01-01 →
    20250600 + (i % 28 + 1),                  -- review_period_end_key: 2025-06-01 →
    (floor(random() * 20 + 1))::INT,          -- reviewer_employee_key: 1–20
    (ARRAY['Annual', 'Mid-year', 'Quarterly'])[floor(random()*3 + 1)::INT],
    round((random() * 4 + 1)::numeric, 2),    -- overall_rating: 1.00–5.00
    round((random() * 5)::numeric, 2),        -- goals_achievement_score
    round((random() * 5)::numeric, 2),        -- competency_score
    round((random() * 5)::numeric, 2),        -- leadership_score
    (ARRAY['High', 'Medium', 'Low'])[floor(random()*3 + 1)::INT],
    (ARRAY['Ready', 'Developing', 'Not Ready'])[floor(random()*3 + 1)::INT],
    (ARRAY['High', 'Medium', 'Low'])[floor(random()*3 + 1)::INT],
    now() - (i || ' days')::INTERVAL,
    now()
FROM generate_series(1, 100) AS s(i);

INSERT INTO dim_date (date_key, full_date, day_of_week, day_name, day_of_month, day_of_year, week_of_year, month_number, month_name, quarter_number, quarter_name, year_number, is_weekend, is_holiday, fiscal_year, fiscal_quarter)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT as date_key,
    d as full_date,
    EXTRACT(ISODOW FROM d) as day_of_week,
    TRIM(TO_CHAR(d, 'Day')) as day_name,
    EXTRACT(DAY FROM d) as day_of_month,
    EXTRACT(DOY FROM d) as day_of_year,
    EXTRACT(WEEK FROM d) as week_of_year,
    EXTRACT(MONTH FROM d) as month_number,
    TRIM(TO_CHAR(d, 'Month')) as month_name,
    EXTRACT(QUARTER FROM d) as quarter_number,
    'Q' || EXTRACT(QUARTER FROM d) as quarter_name,
    EXTRACT(YEAR FROM d) as year_number,
    CASE WHEN EXTRACT(ISODOW FROM d) IN (6,7) THEN TRUE ELSE FALSE END as is_weekend,
    FALSE as is_holiday,
    EXTRACT(YEAR FROM d) as fiscal_year,
    EXTRACT(QUARTER FROM d) as fiscal_quarter
FROM generate_series('2025-01-01'::date, '2025-12-31'::date, '1 day'::interval) d
ON CONFLICT (date_key) DO NOTHING;


INSERT INTO fact_training (
    employee_key,
    training_date_key,
    completion_date_key,
    training_program_id,
    training_category,
    training_type,
    training_provider,
    training_hours,
    training_cost,
    completion_status,
    assessment_score,
    satisfaction_score,
    skill_improvement,
    created_at,
    updated_at
)
SELECT
    (i % 20 + 1),                                -- employee_key: 1–20
    20250500 + (i % 28 + 1),                     -- training_date_key: 2025-05-01 → 2025-05-28
    CASE WHEN i % 4 = 0 THEN NULL                -- 25% không có completion_date_key (In Progress)
         ELSE 20250600 + (i % 28 + 1)            -- completion_date_key: 2025-06-01 →
    END,
    'TP-' || lpad(i::TEXT, 4, '0'),              -- training_program_id: TP-0001 → TP-0100
    (ARRAY['Leadership', 'Technical', 'Soft Skills', 'Compliance'])[floor(random()*4 + 1)::INT],
    (ARRAY['Online', 'Classroom', 'Workshop'])[floor(random()*3 + 1)::INT],
    (ARRAY['Coursera', 'Udemy', 'Internal', 'External Vendor'])[floor(random()*4 + 1)::INT],
    round((random() * 40)::numeric, 2),          -- training_hours: 0–40
    round((random() * 1000)::numeric, 2),        -- training_cost: 0–1000
    (ARRAY['Completed', 'In Progress', 'Cancelled'])[floor(random()*3 + 1)::INT],
    round((random() * 10)::numeric, 2),          -- assessment_score: 0–10
    round((random() * 10)::numeric, 2),          -- satisfaction_score: 0–10
    round((random() * 10)::numeric, 2),          -- skill_improvement: 0–10
    now() - (i || ' days')::interval,            -- created_at
    now()                                        -- updated_at
FROM generate_series(1, 100) AS s(i);

INSERT INTO fact_compensation_history (
    employee_key,
    effective_date_key,
    compensation_key,
    change_reason,
    previous_base_salary,
    new_base_salary,
    previous_total_comp,
    new_total_comp,
    bonus_amount,
    stock_options_granted,
    created_at,
    updated_at
)
SELECT
    (i % 20 + 1),                                     -- employee_key: 1–20
    20250400 + (i % 28 + 1),                          -- effective_date_key: 2025-04-01 → 2025-04-28
    (i % 4 + 1),                                      -- compensation_key: 1–4
    (ARRAY['Promotion', 'Merit', 'Market Adj'])[floor(random()*3 + 1)::INT],
    base_salary,                                      -- previous_base_salary
    base_salary + raise_amount,                       -- new_base_salary
    base_salary + round(random() * 20000)::numeric,   -- previous_total_comp
    base_salary + raise_amount + round(random() * 30000)::numeric, -- new_total_comp
    round(random() * 10000)::numeric,                 -- bonus_amount
    (random() * 100)::INT,                            -- stock_options_granted
    now() - (i || ' days')::INTERVAL,                 -- created_at
    now()                                             -- updated_at
FROM generate_series(1, 100) AS s(i),
LATERAL (
    SELECT round((random() * 50000 + 30000)::numeric, 2) AS base_salary,  -- Base: 30k–80k
           round((random() * 10000)::numeric, 2) AS raise_amount          -- Raise: 0–10k
) AS salary;

INSERT INTO fact_turnover (
    employee_key,
    termination_date_key,
    last_working_date_key,
    department_key,
    position_key,
    location_key,
    termination_reason,
    termination_type,
    exit_interview_completed,
    tenure_at_termination_days,
    age_at_termination,
    final_salary,
    performance_score_last,
    regrettable_loss,
    rehire_eligible,
    created_at,
    updated_at
)
SELECT
    (i % 20 + 1),                                    -- employee_key: 1–20
    20250500 + (i % 28 + 1),                         -- termination_date_key: 2025-05-01 → 2025-05-28
    CASE WHEN i % 5 = 0 THEN NULL                    -- 20% không có last_working_date_key
         ELSE 20250400 + (i % 28 + 1)
    END,
    (i % 5 + 1),                                     -- department_key: 1–5
    (i % 10 + 1),                                    -- position_key: 1–10
    (i % 3 + 1),                                     -- location_key: 1–3
    (ARRAY['Personal', 'Performance', 'Retirement', 'Career Change'])[floor(random()*4 + 1)::INT],
    (ARRAY['Voluntary', 'Involuntary'])[floor(random()*2 + 1)::INT],
    (random() > 0.3),                                -- exit_interview_completed: 70% TRUE
    tenure_days,                                     -- tenure_at_termination_days: 0–10 năm
    (18 + floor(random()*42))::INT,                 -- age_at_termination: 18–60
    round((random()*50000 + 30000)::numeric, 2),     -- final_salary: 30k–80k
    round((random()*4 + 1)::numeric, 2),             -- performance_score_last: 1.00–5.00
    (random() < 0.25),                               -- regrettable_loss: ~25%
    (random() > 0.1),                                -- rehire_eligible: 90%
    now() - (i || ' days')::INTERVAL,                -- created_at
    now()                                            -- updated_at
FROM generate_series(1, 100) AS s(i),
LATERAL (
    SELECT (floor(random() * 3652))::INT AS tenure_days -- tenure_at_termination_days: 0–10 năm
) AS t;
