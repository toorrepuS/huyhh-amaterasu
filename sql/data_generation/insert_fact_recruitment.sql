-- =====================================================
-- ENHANCED FAKE DATA FOR fact_recruitment TABLE
-- =====================================================
-- This script generates comprehensive sample data for the fact_recruitment table
-- with realistic recruitment scenarios and proper foreign key relationships

SET search_path = hr_analytics;

-- Clear existing data first
truncate table fact_recruitment;

-- Generate comprehensive fact_recruitment data
-- Create recruitment records for the last 12 months (2024)
INSERT INTO fact_recruitment (
    requisition_id,
    employee_key,
    position_key,
    department_key,
    location_key,
    posting_date_key,
    hire_date_key,
    source_channel,
    number_of_applicants,
    number_of_interviews,
    number_of_offers,
    offers_accepted,
    time_to_fill_days,
    cost_per_hire,
    recruiter_satisfaction,
    hiring_manager_satisfaction,
    created_at,
    updated_at
)
SELECT
    -- Generate unique requisition IDs
    'REQ-' || LPAD(ROW_NUMBER() OVER (ORDER BY d.date_key, p.position_key)::TEXT, 6, '0') as requisition_id,

    -- Employee key (null for unfilled positions, filled for successful hires)
    CASE
        WHEN is_filled = 1 THEN
            -- Map to existing employees based on position and department
            (SELECT e.employee_key
             FROM dim_employee e
             WHERE e.is_current = TRUE
             AND e.hire_date BETWEEN d.full_date AND d.full_date + INTERVAL '90 days'
             ORDER BY RANDOM()
             LIMIT 1)
        ELSE NULL
    END as employee_key,

    p.position_key,
    dept.department_key,
    loc.location_key,
    d.date_key as posting_date_key,

    -- Hire date (only for filled positions)
    CASE
        WHEN is_filled = 1 THEN
            (SELECT dd.date_key
             FROM dim_date dd
             WHERE dd.full_date BETWEEN d.full_date + INTERVAL '15 days'
                                   AND d.full_date + INTERVAL '90 days'
             ORDER BY RANDOM()
             LIMIT 1)
        ELSE NULL
    END as hire_date_key,
    
    -- Source channels with realistic distribution
    CASE (ROW_NUMBER() OVER (ORDER BY d.date_key, p.position_key)) % 10
        WHEN 0 THEN 'LinkedIn'
        WHEN 1 THEN 'Company Website'
        WHEN 2 THEN 'Employee Referral'
        WHEN 3 THEN 'Job Boards'
        WHEN 4 THEN 'Recruitment Agency'
        WHEN 5 THEN 'University Partnership'
        WHEN 6 THEN 'Social Media'
        WHEN 7 THEN 'Professional Networks'
        WHEN 8 THEN 'Internal Posting'
        ELSE 'Walk-in'
    END as source_channel,

    -- Number of applicants (varies by position level and source)
    applicants_base as number_of_applicants,

    -- Number of interviews (typically 20-40% of applicants, ensuring constraint compliance)
    LEAST(
        applicants_base,
        GREATEST(1, (applicants_base * interview_ratio)::INT)
    ) as number_of_interviews,
    
    -- Number of offers (typically 1-3 for most positions, but not more than interviews)
    LEAST(
        LEAST(
            applicants_base,
            GREATEST(1, (applicants_base * interview_ratio)::INT)
        ),
        CASE
            WHEN is_filled = 1 THEN 1 + (RANDOM() * 2)::INT
            ELSE GREATEST(0, (RANDOM() * 3)::INT)
        END
    ) as number_of_offers,

    -- Offers accepted (1 for filled positions, 0 for others)
    CASE
        WHEN is_filled = 1 THEN 1
        ELSE 0
    END as offers_accepted,

    -- Time to fill (only for filled positions)
    CASE
        WHEN is_filled = 1 THEN
            CASE
                WHEN p.job_level IN ('Junior') THEN 20 + (RANDOM() * 25)::INT
                WHEN p.job_level IN ('Senior', 'Lead') THEN 30 + (RANDOM() * 35)::INT
                WHEN p.job_level IN ('Manager') THEN 45 + (RANDOM() * 45)::INT
                WHEN p.job_level IN ('Director', 'VP') THEN 60 + (RANDOM() * 60)::INT
                ELSE 25 + (RANDOM() * 35)::INT
            END
        ELSE NULL
    END as time_to_fill_days,

    -- Cost per hire (varies by level and source)
    CASE
        WHEN is_filled = 1 THEN
            CASE
                WHEN p.job_level IN ('Junior') THEN 2000000 + (RANDOM() * 3000000)::DECIMAL(12,2)
                WHEN p.job_level IN ('Senior', 'Lead') THEN 4000000 + (RANDOM() * 6000000)::DECIMAL(12,2)
                WHEN p.job_level IN ('Manager') THEN 8000000 + (RANDOM() * 12000000)::DECIMAL(12,2)
                WHEN p.job_level IN ('Director', 'VP') THEN 15000000 + (RANDOM() * 25000000)::DECIMAL(12,2)
                ELSE 3000000 + (RANDOM() * 5000000)::DECIMAL(12,2)
            END
        ELSE NULL
    END as cost_per_hire,

    -- Recruiter satisfaction (1-5 scale, only for completed recruitments)
    CASE
        WHEN is_filled = 1 THEN (3.5 + RANDOM() * 1.5)::DECIMAL(4,2)
        ELSE NULL
    END as recruiter_satisfaction,

    -- Hiring manager satisfaction (1-5 scale, only for completed recruitments)
    CASE
        WHEN is_filled = 1 THEN (3.8 + RANDOM() * 1.2)::DECIMAL(4,2)
        ELSE NULL
    END as hiring_manager_satisfaction,
    
    d.full_date as created_at,
    d.full_date + INTERVAL '1 day' as updated_at

FROM
    -- Generate posting dates for the last 12 months (2024)
    (SELECT * FROM dim_date
     WHERE full_date BETWEEN '2024-01-01' AND '2024-12-31'
     AND EXTRACT(DOW FROM full_date) IN (1, 3, 5)  -- Monday, Wednesday, Friday postings
    ) d
    CROSS JOIN
    -- All current positions with applicant calculations
    (SELECT *,
        CASE
            WHEN job_level IN ('Junior') THEN 15 + (RANDOM() * 35)::INT
            WHEN job_level IN ('Senior', 'Lead') THEN 8 + (RANDOM() * 22)::INT
            WHEN job_level IN ('Manager') THEN 5 + (RANDOM() * 15)::INT
            WHEN job_level IN ('Director', 'VP') THEN 3 + (RANDOM() * 7)::INT
            ELSE 10 + (RANDOM() * 20)::INT
        END as applicants_base,
        CASE
            WHEN job_level IN ('Junior') THEN 0.2 + RANDOM() * 0.2
            WHEN job_level IN ('Senior', 'Lead') THEN 0.25 + RANDOM() * 0.25
            WHEN job_level IN ('Manager') THEN 0.3 + RANDOM() * 0.3
            WHEN job_level IN ('Director', 'VP') THEN 0.4 + RANDOM() * 0.4
            ELSE 0.25 + RANDOM() * 0.25
        END as interview_ratio
     FROM dim_position WHERE is_current = TRUE) p
    CROSS JOIN
    -- All current departments
    (SELECT * FROM dim_department WHERE is_current = TRUE) dept
    CROSS JOIN
    -- All active locations
    (SELECT * FROM dim_location WHERE is_active = TRUE) loc
    CROSS JOIN
    -- Generate filled/unfilled status (70% filled, 30% unfilled)
    (SELECT is_filled
     FROM (VALUES (1), (1), (1), (1), (1), (1), (1), (0), (0), (0)) AS status_dist(is_filled)
    ) status_gen
WHERE
    -- Realistic filtering: not every position needs recruitment every day
    -- Create recruitment needs based on business logic
    (
        -- Higher recruitment for junior positions
        (p.job_level = 'Junior' AND (d.date_key % 15) = 0) OR
        -- Medium recruitment for senior positions
        (p.job_level IN ('Senior', 'Lead') AND (d.date_key % 25) = 0) OR
        -- Lower recruitment for management positions
        (p.job_level IN ('Manager', 'Director') AND (d.date_key % 45) = 0) OR
        -- Occasional C-level recruitment
        (p.job_level IN ('VP', 'C-Level') AND (d.date_key % 90) = 0)
    )
    -- Match department and position logically
    AND (
        (dept.department_name = 'Information Technology' AND p.job_family IN ('Engineering', 'Technology')) OR
        (dept.department_name = 'Human Resources' AND p.job_family IN ('Human Resources')) OR
        (dept.department_name = 'Finance' AND p.job_family IN ('Finance')) OR
        (dept.department_name = 'Marketing' AND p.job_family IN ('Marketing')) OR
        (dept.department_name = 'Operations' AND p.job_family IN ('Operations', 'Management', 'Business'))
    )
    -- Random sampling to control volume (reduce data size)
    AND RANDOM() < 0.1

-- Limit total records to keep it manageable
ORDER BY d.date_key, p.position_key, dept.department_key
LIMIT 500;

COMMIT;

-- Display summary statistics
SELECT
    'fact_recruitment' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN employee_key IS NOT NULL THEN 1 END) as filled_positions,
    COUNT(CASE WHEN employee_key IS NULL THEN 1 END) as unfilled_positions,
    ROUND(AVG(time_to_fill_days), 1) as avg_time_to_fill_days,
    ROUND(AVG(cost_per_hire), 0) as avg_cost_per_hire_vnd,
    ROUND(AVG(number_of_applicants), 1) as avg_applicants,
    ROUND(AVG(recruiter_satisfaction), 2) as avg_recruiter_satisfaction
FROM fact_recruitment;

-- Display sample records
SELECT
    requisition_id,
    CASE WHEN employee_key IS NOT NULL THEN 'Filled' ELSE 'Open' END as status,
    source_channel,
    number_of_applicants,
    number_of_interviews,
    number_of_offers,
    offers_accepted,
    time_to_fill_days,
    cost_per_hire
FROM fact_recruitment
ORDER BY recruitment_key
LIMIT 10;
