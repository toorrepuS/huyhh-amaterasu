-- =====================================================
-- ENHANCED FAKE DATA FOR fact_employee_snapshot TABLE
-- =====================================================
-- This script generates comprehensive sample data for the fact_employee_snapshot table
-- with better distribution across all dimensions and more realistic employee scenarios

SET search_path = hr_analytics;

-- Clear existing data first
DELETE FROM fact_employee_snapshot;

-- Generate comprehensive fact_employee_snapshot data with better dimension distribution
-- Create snapshots for the last 3 months of 2024 (October, November, December)
INSERT INTO fact_employee_snapshot (
    date_key,
    employee_key,
    department_key,
    position_key,
    location_key,
    compensation_key,
    base_salary,
    total_compensation,
    tenure_days,
    age_years,
    is_active_employee,
    is_new_hire,
    is_termination,
    performance_score,
    engagement_score,
    flight_risk_score,
    snapshot_date
)
SELECT
    d.date_key,
    e.employee_key,
    -- Better distribution across departments (5 departments)
    CASE
        WHEN e.employee_key % 5 = 1 THEN 1  -- IT
        WHEN e.employee_key % 5 = 2 THEN 2  -- HR
        WHEN e.employee_key % 5 = 3 THEN 3  -- Finance
        WHEN e.employee_key % 5 = 4 THEN 4  -- Marketing
        ELSE 5                              -- Operations
    END as department_key,

    -- Better distribution across positions (10 positions now)
    CASE
        WHEN e.employee_key <= 4 THEN ((e.employee_key - 1) % 4) + 6  -- Junior positions (POS006-POS009)
        WHEN e.employee_key <= 12 THEN ((e.employee_key - 5) % 5) + 1  -- Mid-level positions (POS001-POS005)
        ELSE ((e.employee_key - 13) % 5) + 6                          -- Senior positions (POS006-POS010)
    END as position_key,

    -- Distribute across locations (3 locations)
    ((e.employee_key - 1) % 3) + 1 as location_key,

    -- Compensation based on employee level and position
    CASE
        WHEN e.employee_level IN ('Junior') THEN 1      -- Band 3
        WHEN e.employee_level IN ('Senior') THEN 2      -- Band 5
        WHEN e.employee_level IN ('Lead', 'Manager') THEN 3  -- Band 7
        ELSE 4                                           -- Band 9 (Director+)
    END as compensation_key,

    -- Base salary based on level and some variation
    CASE
        WHEN e.employee_level = 'Junior' THEN 18000000 + (e.employee_key % 3) * 2000000
        WHEN e.employee_level = 'Senior' THEN 28000000 + (e.employee_key % 4) * 3000000
        WHEN e.employee_level = 'Lead' THEN 45000000 + (e.employee_key % 3) * 5000000
        WHEN e.employee_level = 'Manager' THEN 65000000 + (e.employee_key % 3) * 8000000
        WHEN e.employee_level = 'Director' THEN 90000000 + (e.employee_key % 2) * 10000000
        ELSE 25000000  -- Default
    END as base_salary,

    -- Total compensation (base + bonus + benefits)
    CASE
        WHEN e.employee_level = 'Junior' THEN (18000000 + (e.employee_key % 3) * 2000000) * 1.15
        WHEN e.employee_level = 'Senior' THEN (28000000 + (e.employee_key % 4) * 3000000) * 1.25
        WHEN e.employee_level = 'Lead' THEN (45000000 + (e.employee_key % 3) * 5000000) * 1.35
        WHEN e.employee_level = 'Manager' THEN (65000000 + (e.employee_key % 3) * 8000000) * 1.45
        WHEN e.employee_level = 'Director' THEN (90000000 + (e.employee_key % 2) * 10000000) * 1.55
        ELSE 30000000  -- Default
    END as total_compensation,

    -- Calculate tenure days from hire date to snapshot date
    (d.full_date - e.hire_date)::INT as tenure_days,

    -- Calculate age from birth date to snapshot date
    EXTRACT(YEAR FROM AGE(d.full_date, e.date_of_birth))::INT as age_years,

    -- Active status (add some variation - 95% active)
    CASE WHEN e.employee_key % 20 = 0 THEN FALSE ELSE TRUE END as is_active_employee,

    -- Mark as new hire if hired within last 90 days
    CASE WHEN (d.full_date - e.hire_date) <= 90 THEN TRUE ELSE FALSE END as is_new_hire,

    -- Mark termination for inactive employees
    CASE WHEN e.employee_key % 20 = 0 THEN TRUE ELSE FALSE END as is_termination,

    -- Performance scores with some realistic distribution
    CASE
        WHEN e.employee_key % 10 = 0 THEN 4.8 + (RANDOM() * 0.4)  -- Top performers
        WHEN e.employee_key % 5 = 0 THEN 4.2 + (RANDOM() * 0.6)   -- High performers
        WHEN e.employee_key % 3 = 0 THEN 3.5 + (RANDOM() * 0.7)   -- Average performers
        ELSE 3.0 + (RANDOM() * 1.0)                               -- Mixed performers
    END::DECIMAL(4,2) as performance_score,

    -- Engagement scores
    (3.2 + RANDOM() * 1.8)::DECIMAL(4,2) as engagement_score,

    -- Flight risk scores (lower for senior employees)
    CASE
        WHEN e.employee_level IN ('Manager', 'Director') THEN (RANDOM() * 2.0)
        WHEN e.employee_level IN ('Lead', 'Senior') THEN (RANDOM() * 3.0)
        ELSE (RANDOM() * 4.0)
    END::DECIMAL(4,2) as flight_risk_score,

    d.full_date as snapshot_date
FROM
    -- Generate snapshots for last 3 months (weekly snapshots to reduce volume)
    (SELECT * FROM dim_date
     WHERE full_date BETWEEN '2024-10-01' AND '2024-12-31'
     AND EXTRACT(DOW FROM full_date) = 1  -- Monday snapshots only
    ) d
    CROSS JOIN
    (SELECT * FROM dim_employee WHERE is_current = TRUE) e
ON CONFLICT (date_key, employee_key) DO NOTHING;

COMMIT;
