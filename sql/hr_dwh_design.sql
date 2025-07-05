-- =====================================================
-- HR Data Warehouse - Dimensional Model Design
-- PostgreSQL 12 Implementation
-- =====================================================

-- =====================================================
-- DATABASE AND SCHEMA SETUP
-- =====================================================

-- Create database (run as superuser)
-- CREATE DATABASE hr_dwh
--     WITH ENCODING 'UTF8'
--     LC_COLLATE = 'en_US.UTF-8'
--     LC_CTYPE = 'en_US.UTF-8'
--     TEMPLATE = template0;

-- Connect to hr_dwh database before running the rest
-- \c hr_dwh;

-- Create schema
CREATE SCHEMA IF NOT EXISTS hr_analytics;

-- Set search path
SET search_path TO hr_analytics, public;

-- Create extensions
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- =====================================================
-- SEQUENCES FOR PRIMARY KEYS
-- =====================================================

CREATE SEQUENCE seq_employee_key START 1;
CREATE SEQUENCE seq_department_key START 1;
CREATE SEQUENCE seq_position_key START 1;
CREATE SEQUENCE seq_location_key START 1;
CREATE SEQUENCE seq_compensation_key START 1;
CREATE SEQUENCE seq_snapshot_key START 1;
CREATE SEQUENCE seq_recruitment_key START 1;
CREATE SEQUENCE seq_performance_key START 1;
CREATE SEQUENCE seq_training_key START 1;
CREATE SEQUENCE seq_compensation_history_key START 1;
CREATE SEQUENCE seq_turnover_key START 1;
CREATE SEQUENCE seq_summary_key START 1;
CREATE SEQUENCE seq_lifecycle_key START 1;
CREATE SEQUENCE seq_diversity_key START 1;
CREATE SEQUENCE seq_pipeline_key START 1;
CREATE SEQUENCE seq_employee_movement_key START 1;
CREATE SEQUENCE seq_channel_key START 1;
CREATE SEQUENCE seq_product_key START 1;
CREATE SEQUENCE seq_channel_achievement_key START 1;

-- =====================================================
-- DIMENSION TABLES
-- =====================================================

-- dim_employee: Core employee information (SCD Type 2)
CREATE TABLE dim_employee (
    employee_key INT PRIMARY KEY DEFAULT nextval('seq_employee_key'),
    employee_id VARCHAR(20) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    full_name VARCHAR(100) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    email VARCHAR(100),
    phone VARCHAR(20),
    date_of_birth DATE,
    gender VARCHAR(10) CHECK (gender IN ('Male', 'Female', 'Other')),
    ethnicity VARCHAR(50),
    marital_status VARCHAR(20) CHECK (marital_status IN ('Single', 'Married', 'Divorced', 'Widowed')),
    hire_date DATE NOT NULL,
    termination_date DATE,
    employment_status VARCHAR(20) NOT NULL DEFAULT 'Active' CHECK (employment_status IN ('Active', 'Terminated', 'On Leave')),
    employment_type VARCHAR(20) NOT NULL DEFAULT 'Full-time' CHECK (employment_type IN ('Full-time', 'Part-time', 'Contract', 'Intern')),
    employee_level VARCHAR(20) CHECK (employee_level IN ('Junior', 'Senior', 'Lead', 'Manager', 'Director', 'VP', 'C-Level')),
    job_grade VARCHAR(10),
    is_manager BOOLEAN DEFAULT FALSE,
    manager_employee_key INT,
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_employee_hire_date CHECK (hire_date <= CURRENT_DATE),
    CONSTRAINT chk_employee_termination_date CHECK (termination_date IS NULL OR termination_date >= hire_date),
    CONSTRAINT chk_employee_valid_dates CHECK (valid_from <= valid_to),
    CONSTRAINT chk_employee_age CHECK (date_of_birth IS NULL OR date_of_birth <= CURRENT_DATE - INTERVAL '16 years'),

    -- Unique constraint for business key + time
    CONSTRAINT uk_employee_id_valid_from UNIQUE (employee_id, valid_from)
);

-- dim_department: Department hierarchy (SCD Type 2)
CREATE TABLE dim_department (
    department_key INT PRIMARY KEY DEFAULT nextval('seq_department_key'),
    department_id VARCHAR(20) NOT NULL,
    department_name VARCHAR(100) NOT NULL,
    department_code VARCHAR(10),
    division VARCHAR(100),
    business_unit VARCHAR(100),
    cost_center VARCHAR(20),
    parent_department_key INT,
    department_level INT DEFAULT 1 CHECK (department_level BETWEEN 1 AND 5),
    department_head_key INT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_department_valid_dates CHECK (valid_from <= valid_to),
    CONSTRAINT uk_department_id_valid_from UNIQUE (department_id, valid_from)
);

-- dim_position: Job positions and roles (SCD Type 2)
CREATE TABLE dim_position (
    position_key INT PRIMARY KEY DEFAULT nextval('seq_position_key'),
    position_id VARCHAR(20) NOT NULL,
    position_code VARCHAR(20),
    position_title VARCHAR(100) NOT NULL,
    job_family VARCHAR(50),
    job_function VARCHAR(50),
    job_level VARCHAR(20) CHECK (job_level IN ('Junior', 'Senior', 'Lead', 'Manager', 'Director', 'VP', 'C-Level')),
    job_grade VARCHAR(10),
    reports_to_position_key INT,
    is_management_role BOOLEAN DEFAULT FALSE,
    min_salary DECIMAL(12,2),
    max_salary DECIMAL(12,2),
    required_skills TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_position_valid_dates CHECK (valid_from <= valid_to),
    CONSTRAINT chk_position_salary_range CHECK (max_salary IS NULL OR min_salary IS NULL OR max_salary >= min_salary),
    CONSTRAINT uk_position_id_valid_from UNIQUE (position_id, valid_from)
);

-- dim_location: Office locations
CREATE TABLE dim_location (
    location_key INT PRIMARY KEY DEFAULT nextval('seq_location_key'),
    location_id VARCHAR(20) UNIQUE NOT NULL,
    location_name VARCHAR(100) NOT NULL,
    address VARCHAR(200),
    city VARCHAR(50) NOT NULL,
    state_province VARCHAR(50),
    country VARCHAR(50) NOT NULL,
    region VARCHAR(50),
    timezone VARCHAR(50),
    office_type VARCHAR(20) DEFAULT 'Branch'
        CHECK (office_type IN ('HQ', 'Branch', 'Remote')),
    capacity INT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- dim_date: Date dimension for time-based analysis
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY, -- Format: YYYYMMDD
    full_date DATE UNIQUE NOT NULL,
    day_of_week INT CHECK (day_of_week BETWEEN 1 AND 7), -- 1=Monday, 7=Sunday
    day_name VARCHAR(10) NOT NULL,
    day_of_month INT CHECK (day_of_month BETWEEN 1 AND 31),
    day_of_year INT CHECK (day_of_year BETWEEN 1 AND 366),
    week_of_year INT CHECK (week_of_year BETWEEN 1 AND 53),
    month_number INT CHECK (month_number BETWEEN 1 AND 12),
    month_name VARCHAR(10) NOT NULL,
    quarter_number INT CHECK (quarter_number BETWEEN 1 AND 4),
    quarter_name VARCHAR(10) NOT NULL,
    year_number INT CHECK (year_number BETWEEN 1900 AND 2100),
    is_weekend BOOLEAN NOT NULL DEFAULT FALSE,
    is_holiday BOOLEAN NOT NULL DEFAULT FALSE,
    holiday_name VARCHAR(100),
    fiscal_year INT,
    fiscal_quarter INT CHECK (fiscal_quarter BETWEEN 1 AND 4),
    fiscal_month INT CHECK (fiscal_month BETWEEN 1 AND 12)
);

-- dim_compensation: Compensation bands and structures (SCD Type 2)
CREATE TABLE dim_compensation (
    compensation_key INT PRIMARY KEY DEFAULT nextval('seq_compensation_key'),
    compensation_id VARCHAR(20) NOT NULL,
    salary_band VARCHAR(20) NOT NULL,
    pay_grade VARCHAR(10),
    currency VARCHAR(10) NOT NULL DEFAULT 'VND',
    pay_frequency VARCHAR(20) DEFAULT 'Monthly'
        CHECK (pay_frequency IN ('Weekly', 'Bi-weekly', 'Monthly', 'Quarterly', 'Annually')),
    overtime_eligible BOOLEAN DEFAULT FALSE,
    bonus_eligible BOOLEAN DEFAULT FALSE,
    commission_eligible BOOLEAN DEFAULT FALSE,
    stock_option_eligible BOOLEAN DEFAULT FALSE,
    benefits_package VARCHAR(50),
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_compensation_valid_dates CHECK (valid_from <= valid_to),
    CONSTRAINT uk_compensation_id_valid_from UNIQUE (compensation_id, valid_from)
);

-- dim_channel: Distribution channels information (SCD Type 2)
CREATE TABLE dim_channel (
    channel_key INT PRIMARY KEY DEFAULT nextval('seq_channel_key'),
    channel_id VARCHAR(20) NOT NULL,
    channel_name VARCHAR(100) NOT NULL,
    channel_code VARCHAR(10),
    channel_type VARCHAR(30) NOT NULL
        CHECK (channel_type IN ('Branch', 'Agent', 'Bancassurance', 'Online', 'Mobile', 'Call Center', 'Partner')),
    channel_category VARCHAR(20) DEFAULT 'Traditional'
        CHECK (channel_category IN ('Traditional', 'Digital', 'Hybrid')),
    parent_channel_key INT,
    channel_level INT DEFAULT 1 CHECK (channel_level BETWEEN 1 AND 5),
    region VARCHAR(50),
    territory VARCHAR(50),
    channel_manager_key INT,
    commission_structure VARCHAR(50),
    target_customer_segment VARCHAR(50),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    launch_date DATE,
    closure_date DATE,
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to DATE NOT NULL DEFAULT '9999-12-31',
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_channel_valid_dates CHECK (valid_from <= valid_to),
    CONSTRAINT chk_channel_closure_date CHECK (closure_date IS NULL OR closure_date >= launch_date),
    CONSTRAINT uk_channel_id_valid_from UNIQUE (channel_id, valid_from)
);

-- dim_product: Product information for business achievements
CREATE TABLE dim_product (
    product_key INT PRIMARY KEY DEFAULT nextval('seq_product_key'),
    product_id VARCHAR(20) UNIQUE NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    product_code VARCHAR(20),
    product_category VARCHAR(50) NOT NULL,
    product_line VARCHAR(50),
    product_family VARCHAR(50),
    is_core_product BOOLEAN DEFAULT FALSE,
    launch_date DATE,
    discontinue_date DATE,
    target_market VARCHAR(50),
    commission_rate DECIMAL(5,4),
    base_premium_amount DECIMAL(12,2),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_product_discontinue_date CHECK (discontinue_date IS NULL OR discontinue_date >= launch_date),
    CONSTRAINT chk_product_commission_rate CHECK (commission_rate IS NULL OR commission_rate BETWEEN 0 AND 1)
);

-- =====================================================
-- FACT TABLES
-- =====================================================

-- fact_employee_snapshot: Daily snapshot of employee status
CREATE TABLE fact_employee_snapshot (
    snapshot_key BIGINT DEFAULT nextval('seq_snapshot_key'),
    date_key INT NOT NULL,
    employee_key INT NOT NULL,
    department_key INT NOT NULL,
    position_key INT NOT NULL,
    location_key INT NOT NULL,
    compensation_key INT,

    -- Measures
    base_salary DECIMAL(12,2) CHECK (base_salary >= 0),
    total_compensation DECIMAL(12,2) CHECK (total_compensation >= base_salary),
    tenure_days INT CHECK (tenure_days >= 0),
    tenure_years DECIMAL(4,2) GENERATED ALWAYS AS (tenure_days / 365.25) STORED,
    age_years INT CHECK (age_years BETWEEN 16 AND 100),
    is_active_employee BOOLEAN NOT NULL DEFAULT TRUE,
    is_new_hire BOOLEAN NOT NULL DEFAULT FALSE,
    is_termination BOOLEAN NOT NULL DEFAULT FALSE,
    performance_score DECIMAL(4,2),
    engagement_score DECIMAL(4,2),
    flight_risk_score DECIMAL(4,2),

    -- Snapshot metadata
    snapshot_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    PRIMARY KEY (snapshot_key, date_key),
    CONSTRAINT uk_snapshot_date_employee UNIQUE (date_key, employee_key),
    CONSTRAINT chk_snapshot_flags CHECK (NOT (is_new_hire AND is_termination))
) PARTITION BY RANGE (date_key);

-- fact_recruitment: Recruitment process tracking
CREATE TABLE fact_recruitment (
    recruitment_key BIGINT PRIMARY KEY DEFAULT nextval('seq_recruitment_key'),
    requisition_id VARCHAR(20) UNIQUE NOT NULL,
    employee_key INT, -- FK to hired employee (null if not hired)
    position_key INT NOT NULL,
    department_key INT NOT NULL,
    location_key INT NOT NULL,
    posting_date_key INT,
    hire_date_key INT,
    source_channel VARCHAR(50),

    -- Measures
    number_of_applicants INT DEFAULT 0 CHECK (number_of_applicants >= 0),
    number_of_interviews INT DEFAULT 0 CHECK (number_of_interviews >= 0),
    number_of_offers INT DEFAULT 0 CHECK (number_of_offers >= 0),
    offers_accepted INT DEFAULT 0 CHECK (offers_accepted >= 0),
    time_to_fill_days INT CHECK (time_to_fill_days >= 0),
    cost_per_hire DECIMAL(12,2) CHECK (cost_per_hire >= 0),
    recruiter_satisfaction DECIMAL(4,2),
    hiring_manager_satisfaction DECIMAL(4,2),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_recruitment_offers CHECK (offers_accepted <= number_of_offers),
    CONSTRAINT chk_recruitment_interviews CHECK (number_of_interviews <= number_of_applicants)
);

-- fact_performance: Performance review data
CREATE TABLE fact_performance (
    performance_key BIGINT PRIMARY KEY DEFAULT nextval('seq_performance_key'),
    employee_key INT NOT NULL,
    department_key INT NOT NULL,
    review_date_key INT NOT NULL,
    review_period_start_key INT NOT NULL,
    review_period_end_key INT NOT NULL,
    reviewer_employee_key INT,
    review_type VARCHAR(20) DEFAULT 'Annual'
        CHECK (review_type IN ('Annual', 'Mid-year', 'Quarterly')),

    -- Measures
    overall_rating DECIMAL(4,2) CHECK (overall_rating BETWEEN 1.0 AND 5.0),
    goals_achievement_score DECIMAL(4,2),
    competency_score DECIMAL(4,2),
    leadership_score DECIMAL(4,2),
    potential_rating VARCHAR(20) CHECK (potential_rating IN ('High', 'Medium', 'Low')),
    promotion_readiness VARCHAR(20) CHECK (promotion_readiness IN ('Ready', 'Developing', 'Not Ready')),
    development_priority VARCHAR(20) CHECK (development_priority IN ('High', 'Medium', 'Low')),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_performance_period CHECK (review_period_start_key <= review_period_end_key)
);

-- fact_training: Training and development tracking
CREATE TABLE fact_training (
    training_key BIGINT PRIMARY KEY DEFAULT nextval('seq_training_key'),
    employee_key INT NOT NULL,
    training_date_key INT NOT NULL,
    completion_date_key INT,
    training_program_id VARCHAR(20),
    training_category VARCHAR(50),
    training_type VARCHAR(20) DEFAULT 'Online'
        CHECK (training_type IN ('Online', 'Classroom', 'Workshop')),
    training_provider VARCHAR(100),

    -- Measures
    training_hours DECIMAL(6,2) CHECK (training_hours >= 0),
    training_cost DECIMAL(12,2) CHECK (training_cost >= 0),
    completion_status VARCHAR(20) DEFAULT 'In Progress'
        CHECK (completion_status IN ('Completed', 'In Progress', 'Cancelled')),
    assessment_score DECIMAL(4,2),
    satisfaction_score DECIMAL(4,2),
    skill_improvement DECIMAL(4,2),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- fact_compensation_history: Salary and compensation changes
CREATE TABLE fact_compensation_history (
    compensation_history_key BIGINT PRIMARY KEY DEFAULT nextval('seq_compensation_history_key'),
    employee_key INT NOT NULL,
    effective_date_key INT NOT NULL,
    compensation_key INT,
    change_reason VARCHAR(50)
        CHECK (change_reason IN ('Promotion', 'Merit', 'Market Adj')),

    -- Measures
    previous_base_salary DECIMAL(12,2),
    new_base_salary DECIMAL(12,2),
    salary_change_amount DECIMAL(12,2) GENERATED ALWAYS AS (new_base_salary - previous_base_salary) STORED,
    salary_change_percent DECIMAL(6,2) GENERATED ALWAYS AS
        (CASE WHEN previous_base_salary > 0 THEN (new_base_salary / previous_base_salary - 1) * 100 ELSE NULL END) STORED,
    previous_total_comp DECIMAL(12,2),
    new_total_comp DECIMAL(12,2),
    bonus_amount DECIMAL(12,2),
    stock_options_granted INT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- fact_turnover: Employee termination tracking
CREATE TABLE fact_turnover (
    turnover_key BIGINT PRIMARY KEY DEFAULT nextval('seq_turnover_key'),
    employee_key INT NOT NULL,
    termination_date_key INT NOT NULL,
    last_working_date_key INT,
    department_key INT,
    position_key INT,
    location_key INT,
    termination_reason VARCHAR(50),
    termination_type VARCHAR(20) NOT NULL
        CHECK (termination_type IN ('Voluntary', 'Involuntary')),
    exit_interview_completed BOOLEAN DEFAULT FALSE,

    -- Measures
    tenure_at_termination_days INT CHECK (tenure_at_termination_days >= 0),
    tenure_at_termination_years DECIMAL(4,2) GENERATED ALWAYS AS (tenure_at_termination_days / 365.25) STORED,
    age_at_termination INT,
    final_salary DECIMAL(12,2),
    performance_score_last DECIMAL(4,2),
    regrettable_loss BOOLEAN DEFAULT FALSE,
    rehire_eligible BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_turnover_dates CHECK (last_working_date_key IS NULL OR last_working_date_key <= termination_date_key)
);

-- fact_employee_movement: Employee transfers, promotions, and internal movements
CREATE TABLE fact_employee_movement (
    movement_key BIGINT PRIMARY KEY DEFAULT nextval('seq_employee_movement_key'),
    employee_key INT NOT NULL,
    movement_date_key INT NOT NULL,
    effective_date_key INT NOT NULL,

    -- Previous position information
    previous_department_key INT,
    previous_position_key INT,
    previous_location_key INT,
    previous_manager_key INT,
    previous_compensation_key INT,

    -- New position information
    new_department_key INT NOT NULL,
    new_position_key INT NOT NULL,
    new_location_key INT NOT NULL,
    new_manager_key INT,
    new_compensation_key INT,

    -- Movement details
    movement_type VARCHAR(30) NOT NULL
        CHECK (movement_type IN ('Promotion', 'Lateral Transfer', 'Demotion', 'Department Transfer', 'Location Transfer', 'Manager Change')),
    movement_reason VARCHAR(50)
        CHECK (movement_reason IN ('Performance', 'Business Need', 'Employee Request', 'Reorganization', 'Career Development', 'Succession Planning')),
    is_voluntary BOOLEAN DEFAULT TRUE,
    approval_level VARCHAR(20) DEFAULT 'Manager'
        CHECK (approval_level IN ('Manager', 'Director', 'VP', 'CEO')),

    -- Measures
    previous_salary DECIMAL(12,2),
    new_salary DECIMAL(12,2),
    salary_change_amount DECIMAL(12,2) GENERATED ALWAYS AS (new_salary - previous_salary) STORED,
    salary_change_percent DECIMAL(6,2) GENERATED ALWAYS AS
        (CASE WHEN previous_salary > 0 THEN (new_salary / previous_salary - 1) * 100 ELSE NULL END) STORED,
    previous_job_level VARCHAR(20),
    new_job_level VARCHAR(20),
    level_change INT GENERATED ALWAYS AS (
        CASE
            WHEN previous_job_level = 'Junior' AND new_job_level = 'Senior' THEN 1
            WHEN previous_job_level = 'Senior' AND new_job_level = 'Lead' THEN 1
            WHEN previous_job_level = 'Lead' AND new_job_level = 'Manager' THEN 1
            WHEN previous_job_level = 'Manager' AND new_job_level = 'Director' THEN 1
            WHEN previous_job_level = 'Director' AND new_job_level = 'VP' THEN 1
            WHEN previous_job_level = 'VP' AND new_job_level = 'C-Level' THEN 1
            WHEN previous_job_level = new_job_level THEN 0
            ELSE -1
        END
    ) STORED,
    tenure_at_movement_days INT CHECK (tenure_at_movement_days >= 0),
    tenure_at_movement_years DECIMAL(4,2) GENERATED ALWAYS AS (tenure_at_movement_days / 365.25) STORED,
    time_in_previous_role_days INT CHECK (time_in_previous_role_days >= 0),
    performance_score_before DECIMAL(4,2),
    is_high_potential BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_movement_dates CHECK (effective_date_key >= movement_date_key),
    CONSTRAINT chk_movement_salary_positive CHECK (previous_salary IS NULL OR previous_salary >= 0),
    CONSTRAINT chk_movement_new_salary_positive CHECK (new_salary IS NULL OR new_salary >= 0),
    CONSTRAINT chk_movement_different_position CHECK (
        previous_department_key != new_department_key OR
        previous_position_key != new_position_key OR
        previous_location_key != new_location_key OR
        previous_manager_key != new_manager_key
    )
);

-- fact_channel_achievement: Business achievements of distributed channels over time
CREATE TABLE fact_channel_achievement (
    achievement_key BIGINT DEFAULT nextval('seq_channel_achievement_key'),
    date_key INT NOT NULL,
    channel_key INT NOT NULL,
    product_key INT,
    location_key INT,
    channel_manager_key INT,

    -- Period aggregation level
    aggregation_level VARCHAR(10) NOT NULL DEFAULT 'MONTHLY'
        CHECK (aggregation_level IN ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY')),

    -- Sales Performance Measures
    total_sales_amount DECIMAL(15,2) DEFAULT 0 CHECK (total_sales_amount >= 0),
    total_premium_amount DECIMAL(15,2) DEFAULT 0 CHECK (total_premium_amount >= 0),
    number_of_policies_sold INT DEFAULT 0 CHECK (number_of_policies_sold >= 0),
    number_of_new_customers INT DEFAULT 0 CHECK (number_of_new_customers >= 0),
    number_of_renewals INT DEFAULT 0 CHECK (number_of_renewals >= 0),
    average_policy_value DECIMAL(12,2) GENERATED ALWAYS AS
        (CASE WHEN number_of_policies_sold > 0 THEN total_premium_amount / number_of_policies_sold ELSE 0 END) STORED,

    -- Revenue Measures
    commission_earned DECIMAL(12,2) DEFAULT 0 CHECK (commission_earned >= 0),
    bonus_earned DECIMAL(12,2) DEFAULT 0 CHECK (bonus_earned >= 0),
    total_revenue DECIMAL(15,2) GENERATED ALWAYS AS (commission_earned + bonus_earned) STORED,

    -- Target vs Achievement
    sales_target DECIMAL(15,2) CHECK (sales_target >= 0),
    premium_target DECIMAL(15,2) CHECK (premium_target >= 0),
    policy_count_target INT CHECK (policy_count_target >= 0),
    sales_achievement_rate DECIMAL(6,2) GENERATED ALWAYS AS
        (CASE WHEN sales_target > 0 THEN (total_sales_amount / sales_target) * 100 ELSE NULL END) STORED,
    premium_achievement_rate DECIMAL(6,2) GENERATED ALWAYS AS
        (CASE WHEN premium_target > 0 THEN (total_premium_amount / premium_target) * 100 ELSE NULL END) STORED,
    policy_achievement_rate DECIMAL(6,2) GENERATED ALWAYS AS
        (CASE WHEN policy_count_target > 0 THEN (number_of_policies_sold::DECIMAL / policy_count_target) * 100 ELSE NULL END) STORED,

    -- Customer Metrics
    customer_acquisition_cost DECIMAL(10,2) CHECK (customer_acquisition_cost >= 0),
    customer_lifetime_value DECIMAL(12,2) CHECK (customer_lifetime_value >= 0),
    customer_retention_rate DECIMAL(5,2) CHECK (customer_retention_rate BETWEEN 0 AND 100),
    cross_sell_ratio DECIMAL(4,2) CHECK (cross_sell_ratio >= 0),

    -- Operational Metrics
    number_of_active_agents INT DEFAULT 0 CHECK (number_of_active_agents >= 0),
    productivity_per_agent DECIMAL(10,2) GENERATED ALWAYS AS
        (CASE WHEN number_of_active_agents > 0 THEN total_sales_amount / number_of_active_agents ELSE 0 END) STORED,
    conversion_rate DECIMAL(5,2) CHECK (conversion_rate BETWEEN 0 AND 100),
    lead_to_sale_ratio DECIMAL(4,2) CHECK (lead_to_sale_ratio >= 0),

    -- Quality Metrics
    customer_satisfaction_score DECIMAL(4,2) CHECK (customer_satisfaction_score BETWEEN 1 AND 5),
    service_quality_score DECIMAL(4,2) CHECK (service_quality_score BETWEEN 1 AND 5),
    complaint_resolution_rate DECIMAL(5,2) CHECK (complaint_resolution_rate BETWEEN 0 AND 100),
    policy_lapse_rate DECIMAL(5,2) CHECK (policy_lapse_rate BETWEEN 0 AND 100),

    -- Market Share & Competition
    market_share_percentage DECIMAL(5,2) CHECK (market_share_percentage BETWEEN 0 AND 100),
    competitive_win_rate DECIMAL(5,2) CHECK (competitive_win_rate BETWEEN 0 AND 100),

    -- Digital Metrics (for digital channels)
    website_visits INT DEFAULT 0 CHECK (website_visits >= 0),
    online_quote_requests INT DEFAULT 0 CHECK (online_quote_requests >= 0),
    digital_conversion_rate DECIMAL(5,2) CHECK (digital_conversion_rate BETWEEN 0 AND 100),
    mobile_app_downloads INT DEFAULT 0 CHECK (mobile_app_downloads >= 0),

    -- Performance Indicators
    is_target_achieved BOOLEAN GENERATED ALWAYS AS (
        (sales_target > 0 AND total_sales_amount >= sales_target) OR
        (premium_target > 0 AND total_premium_amount >= premium_target) OR
        (policy_count_target > 0 AND number_of_policies_sold >= policy_count_target)
    ) STORED,
    performance_tier VARCHAR(20) CHECK (performance_tier IN ('Excellent', 'Good', 'Fair', 'Below Target')),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    PRIMARY KEY (achievement_key, date_key),
    CONSTRAINT chk_achievement_customer_metrics CHECK (
        (customer_acquisition_cost IS NULL AND number_of_new_customers = 0) OR
        (customer_acquisition_cost IS NOT NULL AND number_of_new_customers > 0) OR
        (customer_acquisition_cost IS NULL AND number_of_new_customers > 0)
    ),
    CONSTRAINT uk_achievement_date_channel_product UNIQUE (date_key, channel_key, product_key, aggregation_level)
) PARTITION BY RANGE (date_key);

-- =====================================================
-- NOTE: REPORTING TABLES MOVED TO hr_dwh_reporting.sql
-- =====================================================
-- All reporting tables, views, and ETL procedures have been moved to:
-- sql/hr_dwh_reporting.sql
--
-- This includes:
-- - rpt_hr_summary (unified reporting table)
-- - rpt_employee_lifecycle
-- - rpt_diversity_dashboard
-- - rpt_talent_pipeline
-- - All related views, indexes, constraints, and ETL procedures
-- =====================================================



-- =====================================================
-- FOREIGN KEY CONSTRAINTS
-- =====================================================

-- Add foreign key constraints for fact_employee_snapshot
ALTER TABLE fact_employee_snapshot
    ADD CONSTRAINT fk_snapshot_date FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_snapshot_employee FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    ADD CONSTRAINT fk_snapshot_department FOREIGN KEY (department_key) REFERENCES dim_department(department_key),
    ADD CONSTRAINT fk_snapshot_position FOREIGN KEY (position_key) REFERENCES dim_position(position_key),
    ADD CONSTRAINT fk_snapshot_location FOREIGN KEY (location_key) REFERENCES dim_location(location_key),
    ADD CONSTRAINT fk_snapshot_compensation FOREIGN KEY (compensation_key) REFERENCES dim_compensation(compensation_key);

-- Add foreign key constraints for fact_recruitment
ALTER TABLE fact_recruitment
    ADD CONSTRAINT fk_recruitment_employee FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    ADD CONSTRAINT fk_recruitment_position FOREIGN KEY (position_key) REFERENCES dim_position(position_key),
    ADD CONSTRAINT fk_recruitment_department FOREIGN KEY (department_key) REFERENCES dim_department(department_key),
    ADD CONSTRAINT fk_recruitment_location FOREIGN KEY (location_key) REFERENCES dim_location(location_key),
    ADD CONSTRAINT fk_recruitment_posting_date FOREIGN KEY (posting_date_key) REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_recruitment_hire_date FOREIGN KEY (hire_date_key) REFERENCES dim_date(date_key);

-- Add foreign key constraints for fact_performance
ALTER TABLE fact_performance
    ADD CONSTRAINT fk_performance_employee FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    ADD CONSTRAINT fk_performance_department FOREIGN KEY (department_key) REFERENCES dim_department(department_key),
    ADD CONSTRAINT fk_performance_review_date FOREIGN KEY (review_date_key) REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_performance_start_date FOREIGN KEY (review_period_start_key) REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_performance_end_date FOREIGN KEY (review_period_end_key) REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_performance_reviewer FOREIGN KEY (reviewer_employee_key) REFERENCES dim_employee(employee_key);

-- Add foreign key constraints for fact_training
ALTER TABLE fact_training
    ADD CONSTRAINT fk_training_employee FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    ADD CONSTRAINT fk_training_date FOREIGN KEY (training_date_key) REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_training_completion_date FOREIGN KEY (completion_date_key) REFERENCES dim_date(date_key);

-- Add foreign key constraints for fact_compensation_history
ALTER TABLE fact_compensation_history
    ADD CONSTRAINT fk_comp_history_employee FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    ADD CONSTRAINT fk_comp_history_effective_date FOREIGN KEY (effective_date_key) REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_comp_history_compensation FOREIGN KEY (compensation_key) REFERENCES dim_compensation(compensation_key);

-- Add foreign key constraints for fact_turnover
ALTER TABLE fact_turnover
    ADD CONSTRAINT fk_turnover_employee FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    ADD CONSTRAINT fk_turnover_termination_date FOREIGN KEY (termination_date_key) REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_turnover_last_working_date FOREIGN KEY (last_working_date_key) REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_turnover_department FOREIGN KEY (department_key) REFERENCES dim_department(department_key),
    ADD CONSTRAINT fk_turnover_position FOREIGN KEY (position_key) REFERENCES dim_position(position_key),
    ADD CONSTRAINT fk_turnover_location FOREIGN KEY (location_key) REFERENCES dim_location(location_key);

-- Add foreign key constraints for fact_employee_movement
ALTER TABLE fact_employee_movement
    ADD CONSTRAINT fk_movement_employee FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key),
    ADD CONSTRAINT fk_movement_date FOREIGN KEY (movement_date_key) REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_movement_effective_date FOREIGN KEY (effective_date_key) REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_movement_prev_department FOREIGN KEY (previous_department_key) REFERENCES dim_department(department_key),
    ADD CONSTRAINT fk_movement_prev_position FOREIGN KEY (previous_position_key) REFERENCES dim_position(position_key),
    ADD CONSTRAINT fk_movement_prev_location FOREIGN KEY (previous_location_key) REFERENCES dim_location(location_key),
    ADD CONSTRAINT fk_movement_prev_manager FOREIGN KEY (previous_manager_key) REFERENCES dim_employee(employee_key),
    ADD CONSTRAINT fk_movement_prev_compensation FOREIGN KEY (previous_compensation_key) REFERENCES dim_compensation(compensation_key),
    ADD CONSTRAINT fk_movement_new_department FOREIGN KEY (new_department_key) REFERENCES dim_department(department_key),
    ADD CONSTRAINT fk_movement_new_position FOREIGN KEY (new_position_key) REFERENCES dim_position(position_key),
    ADD CONSTRAINT fk_movement_new_location FOREIGN KEY (new_location_key) REFERENCES dim_location(location_key),
    ADD CONSTRAINT fk_movement_new_manager FOREIGN KEY (new_manager_key) REFERENCES dim_employee(employee_key),
    ADD CONSTRAINT fk_movement_new_compensation FOREIGN KEY (new_compensation_key) REFERENCES dim_compensation(compensation_key);

-- Add foreign key constraints for fact_channel_achievement
ALTER TABLE fact_channel_achievement
    ADD CONSTRAINT fk_achievement_date FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    ADD CONSTRAINT fk_achievement_channel FOREIGN KEY (channel_key) REFERENCES dim_channel(channel_key),
    ADD CONSTRAINT fk_achievement_product FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    ADD CONSTRAINT fk_achievement_location FOREIGN KEY (location_key) REFERENCES dim_location(location_key),
    ADD CONSTRAINT fk_achievement_channel_manager FOREIGN KEY (channel_manager_key) REFERENCES dim_employee(employee_key);

-- Add self-referencing foreign keys
ALTER TABLE dim_employee
    ADD CONSTRAINT fk_employee_manager FOREIGN KEY (manager_employee_key) REFERENCES dim_employee(employee_key);

ALTER TABLE dim_department
    ADD CONSTRAINT fk_department_parent FOREIGN KEY (parent_department_key) REFERENCES dim_department(department_key),
    ADD CONSTRAINT fk_department_head FOREIGN KEY (department_head_key) REFERENCES dim_employee(employee_key);

ALTER TABLE dim_position
    ADD CONSTRAINT fk_position_reports_to FOREIGN KEY (reports_to_position_key) REFERENCES dim_position(position_key);

ALTER TABLE dim_channel
    ADD CONSTRAINT fk_channel_parent FOREIGN KEY (parent_channel_key) REFERENCES dim_channel(channel_key),
    ADD CONSTRAINT fk_channel_manager FOREIGN KEY (channel_manager_key) REFERENCES dim_employee(employee_key);



-- =====================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- =====================================================

-- Dimension table indexes
CREATE INDEX idx_employee_business_key ON dim_employee(employee_id, valid_from);
CREATE INDEX idx_employee_manager ON dim_employee(manager_employee_key) WHERE manager_employee_key IS NOT NULL;
CREATE INDEX idx_employee_current ON dim_employee(employee_id) WHERE is_current = TRUE;
CREATE INDEX idx_employee_status ON dim_employee(employment_status, is_current);
CREATE INDEX idx_employee_hire_date ON dim_employee(hire_date);

CREATE INDEX idx_department_business_key ON dim_department(department_id, valid_from);
CREATE INDEX idx_department_parent ON dim_department(parent_department_key) WHERE parent_department_key IS NOT NULL;
CREATE INDEX idx_department_current ON dim_department(department_id) WHERE is_current = TRUE;

CREATE INDEX idx_position_business_key ON dim_position(position_id, valid_from);
CREATE INDEX idx_position_reports_to ON dim_position(reports_to_position_key) WHERE reports_to_position_key IS NOT NULL;
CREATE INDEX idx_position_current ON dim_position(position_id) WHERE is_current = TRUE;

CREATE INDEX idx_location_country_city ON dim_location(country, city);
CREATE INDEX idx_location_active ON dim_location(location_id) WHERE is_active = TRUE;

CREATE INDEX idx_date_full_date ON dim_date(full_date);
CREATE INDEX idx_date_year_month ON dim_date(year_number, month_number);
CREATE INDEX idx_date_fiscal ON dim_date(fiscal_year, fiscal_quarter);

CREATE INDEX idx_compensation_business_key ON dim_compensation(compensation_id, valid_from);
CREATE INDEX idx_compensation_current ON dim_compensation(compensation_id) WHERE is_current = TRUE;

CREATE INDEX idx_channel_business_key ON dim_channel(channel_id, valid_from);
CREATE INDEX idx_channel_parent ON dim_channel(parent_channel_key) WHERE parent_channel_key IS NOT NULL;
CREATE INDEX idx_channel_current ON dim_channel(channel_id) WHERE is_current = TRUE;
CREATE INDEX idx_channel_type_region ON dim_channel(channel_type, region);
CREATE INDEX idx_channel_manager ON dim_channel(channel_manager_key) WHERE channel_manager_key IS NOT NULL;

CREATE INDEX idx_product_category ON dim_product(product_category, product_line);
CREATE INDEX idx_product_active ON dim_product(product_id) WHERE is_active = TRUE;
CREATE INDEX idx_product_launch_date ON dim_product(launch_date);

-- Fact table indexes
CREATE INDEX idx_snapshot_date_employee ON fact_employee_snapshot(date_key, employee_key);
CREATE INDEX idx_snapshot_department_date ON fact_employee_snapshot(department_key, date_key);
CREATE INDEX idx_snapshot_active ON fact_employee_snapshot(date_key) WHERE is_active_employee = TRUE;

CREATE INDEX idx_recruitment_dates ON fact_recruitment(posting_date_key, hire_date_key);
CREATE INDEX idx_recruitment_position ON fact_recruitment(position_key, posting_date_key);

CREATE INDEX idx_performance_employee_date ON fact_performance(employee_key, review_period_end_key);
CREATE INDEX idx_performance_department_date ON fact_performance(department_key, review_period_end_key);
CREATE INDEX idx_performance_type_status ON fact_performance(review_type);

CREATE INDEX idx_training_employee_date ON fact_training(employee_key, training_date_key);
CREATE INDEX idx_training_status ON fact_training(completion_status, training_date_key);
CREATE INDEX idx_training_category ON fact_training(training_category, training_date_key);

CREATE INDEX idx_comp_history_employee_date ON fact_compensation_history(employee_key, effective_date_key);
CREATE INDEX idx_comp_history_reason ON fact_compensation_history(change_reason, effective_date_key);

CREATE INDEX idx_turnover_employee_date ON fact_turnover(employee_key, termination_date_key);
CREATE INDEX idx_turnover_type ON fact_turnover(termination_type, termination_date_key);

CREATE INDEX idx_movement_employee_date ON fact_employee_movement(employee_key, movement_date_key);
CREATE INDEX idx_movement_effective_date ON fact_employee_movement(effective_date_key);
CREATE INDEX idx_movement_type ON fact_employee_movement(movement_type, movement_date_key);
CREATE INDEX idx_movement_department_change ON fact_employee_movement(previous_department_key, new_department_key);
CREATE INDEX idx_movement_position_change ON fact_employee_movement(previous_position_key, new_position_key);
CREATE INDEX idx_movement_salary_change ON fact_employee_movement(salary_change_percent) WHERE salary_change_percent IS NOT NULL;

CREATE INDEX idx_achievement_date_channel ON fact_channel_achievement(date_key, channel_key);
CREATE INDEX idx_achievement_channel_product ON fact_channel_achievement(channel_key, product_key);
CREATE INDEX idx_achievement_aggregation_level ON fact_channel_achievement(aggregation_level, date_key);
CREATE INDEX idx_achievement_performance_tier ON fact_channel_achievement(performance_tier, date_key);
CREATE INDEX idx_achievement_target_achieved ON fact_channel_achievement(date_key) WHERE is_target_achieved = TRUE;
CREATE INDEX idx_achievement_sales_amount ON fact_channel_achievement(total_sales_amount) WHERE total_sales_amount > 0;
CREATE INDEX idx_achievement_channel_manager ON fact_channel_achievement(channel_manager_key, date_key) WHERE channel_manager_key IS NOT NULL;

-- =====================================================
-- PARTITIONING SETUP
-- =====================================================

-- Create partitions for fact_employee_snapshot (by year)
CREATE TABLE fact_employee_snapshot_2023 PARTITION OF fact_employee_snapshot
    FOR VALUES FROM (20230101) TO (20240101);

CREATE TABLE fact_employee_snapshot_2024 PARTITION OF fact_employee_snapshot
    FOR VALUES FROM (20240101) TO (20250101);

CREATE TABLE fact_employee_snapshot_2025 PARTITION OF fact_employee_snapshot
    FOR VALUES FROM (20250101) TO (20260101);

CREATE TABLE fact_employee_snapshot_default PARTITION OF fact_employee_snapshot DEFAULT;

-- Create partitions for fact_channel_achievement (by year)
CREATE TABLE fact_channel_achievement_2023 PARTITION OF fact_channel_achievement
    FOR VALUES FROM (20230101) TO (20240101);

CREATE TABLE fact_channel_achievement_2024 PARTITION OF fact_channel_achievement
    FOR VALUES FROM (20240101) TO (20250101);

CREATE TABLE fact_channel_achievement_2025 PARTITION OF fact_channel_achievement
    FOR VALUES FROM (20250101) TO (20260101);

CREATE TABLE fact_channel_achievement_default PARTITION OF fact_channel_achievement DEFAULT;

-- =====================================================
-- TRIGGERS FOR UPDATED_AT TIMESTAMPS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION func_update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add triggers to all tables with updated_at column
CREATE TRIGGER trigger_dim_employee_updated_at
    BEFORE UPDATE ON dim_employee
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();

CREATE TRIGGER trigger_dim_department_updated_at
    BEFORE UPDATE ON dim_department
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();

CREATE TRIGGER trigger_dim_position_updated_at
    BEFORE UPDATE ON dim_position
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();

CREATE TRIGGER trigger_dim_location_updated_at
    BEFORE UPDATE ON dim_location
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();

CREATE TRIGGER trigger_dim_compensation_updated_at
    BEFORE UPDATE ON dim_compensation
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();

CREATE TRIGGER trigger_fact_recruitment_updated_at
    BEFORE UPDATE ON fact_recruitment
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();

CREATE TRIGGER trigger_fact_performance_updated_at
    BEFORE UPDATE ON fact_performance
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();

CREATE TRIGGER trigger_fact_training_updated_at
    BEFORE UPDATE ON fact_training
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();

CREATE TRIGGER trigger_fact_compensation_history_updated_at
    BEFORE UPDATE ON fact_compensation_history
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();

CREATE TRIGGER trigger_fact_turnover_updated_at
    BEFORE UPDATE ON fact_turnover
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();

CREATE TRIGGER trigger_fact_employee_movement_updated_at
    BEFORE UPDATE ON fact_employee_movement
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();

CREATE TRIGGER trigger_dim_channel_updated_at
    BEFORE UPDATE ON dim_channel
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();

CREATE TRIGGER trigger_dim_product_updated_at
    BEFORE UPDATE ON dim_product
    FOR EACH ROW EXECUTE FUNCTION func_update_updated_at_column();



-- =====================================================
-- NOTE: REPORTING VIEWS MOVED TO hr_dwh_reporting.sql
-- =====================================================

-- =====================================================
-- UTILITY VIEWS FOR CURRENT RECORDS
-- =====================================================

-- Current employee view (SCD Type 2)
CREATE VIEW vw_current_employees AS
SELECT
    employee_key,
    employee_id,
    first_name,
    last_name,
    full_name,
    email,
    employment_status,
    employment_type,
    hire_date,
    termination_date,
    manager_employee_key
FROM dim_employee
WHERE is_current = TRUE;

-- Current department view
CREATE VIEW vw_current_departments AS
SELECT
    department_key,
    department_id,
    department_code,
    department_name,
    division,
    parent_department_key,
    department_level
FROM dim_department
WHERE is_active = TRUE
AND valid_to = '9999-12-31';

-- Current position view
CREATE VIEW vw_current_positions AS
SELECT
    position_key,
    position_id,
    position_title,
    job_family,
    job_function,
    is_management_role
FROM dim_position
WHERE is_active = TRUE
AND valid_to = '9999-12-31';

-- Current channel view
CREATE VIEW vw_current_channels AS
SELECT
    channel_key,
    channel_id,
    channel_name,
    channel_type,
    channel_category,
    region,
    territory,
    channel_manager_key,
    target_customer_segment
FROM dim_channel
WHERE is_active = TRUE
AND valid_to = '9999-12-31';

-- Active product view
CREATE VIEW vw_active_products AS
SELECT
    product_key,
    product_id,
    product_name,
    product_category,
    product_line,
    product_family,
    is_core_product,
    target_market,
    commission_rate
FROM dim_product
WHERE is_active = TRUE;

-- =====================================================
-- SAMPLE DATA POPULATION FUNCTIONS
-- =====================================================

-- Function to populate dim_date
CREATE OR REPLACE FUNCTION func_populate_dim_date(start_date DATE, end_date DATE)
RETURNS VOID AS $$
DECLARE
    current_date_val DATE := start_date;
BEGIN
    WHILE current_date_val <= end_date LOOP
        INSERT INTO dim_date (
            date_key,
            full_date,
            day_of_week,
            day_name,
            day_of_month,
            day_of_year,
            week_of_year,
            month_number,
            month_name,
            quarter_number,
            quarter_name,
            year_number,
            is_weekend,
            fiscal_year,
            fiscal_quarter,
            fiscal_month
        ) VALUES (
            TO_CHAR(current_date_val, 'YYYYMMDD')::INT,
            current_date_val,
            EXTRACT(ISODOW FROM current_date_val)::INT,
            TO_CHAR(current_date_val, 'Day'),
            EXTRACT(DAY FROM current_date_val)::INT,
            EXTRACT(DOY FROM current_date_val)::INT,
            EXTRACT(WEEK FROM current_date_val)::INT,
            EXTRACT(MONTH FROM current_date_val)::INT,
            TO_CHAR(current_date_val, 'Month'),
            EXTRACT(QUARTER FROM current_date_val)::INT,
            'Q' || EXTRACT(QUARTER FROM current_date_val)::TEXT,
            EXTRACT(YEAR FROM current_date_val)::INT,
            EXTRACT(ISODOW FROM current_date_val) IN (6, 7),
            EXTRACT(YEAR FROM current_date_val)::INT,
            EXTRACT(QUARTER FROM current_date_val)::INT,
            EXTRACT(MONTH FROM current_date_val)::INT
        );

        current_date_val := current_date_val + INTERVAL '1 day';
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- GRANTS AND PERMISSIONS
-- =====================================================

-- Create roles
CREATE ROLE hr_analytics_read;
CREATE ROLE hr_analytics_write;
CREATE ROLE hr_analytics_admin;

-- Grant permissions to read role
GRANT USAGE ON SCHEMA hr_analytics TO hr_analytics_read;
GRANT SELECT ON ALL TABLES IN SCHEMA hr_analytics TO hr_analytics_read;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA hr_analytics TO hr_analytics_read;

-- Grant permissions to write role
GRANT USAGE ON SCHEMA hr_analytics TO hr_analytics_write;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA hr_analytics TO hr_analytics_write;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA hr_analytics TO hr_analytics_write;

-- Grant permissions to admin role
GRANT ALL PRIVILEGES ON SCHEMA hr_analytics TO hr_analytics_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA hr_analytics TO hr_analytics_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA hr_analytics TO hr_analytics_admin;

-- =====================================================
-- SETUP INSTRUCTIONS
-- =====================================================

/*
SETUP INSTRUCTIONS:

1. Create database as superuser:
   CREATE DATABASE hr_dwh WITH ENCODING 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';

2. Connect to hr_dwh database:
   \c hr_dwh;

3. Run this script to create schema, tables, and constraints

4. Populate date dimension:
   SELECT func_populate_dim_date('2020-01-01', '2030-12-31');

5. Create users and assign roles:
   CREATE USER hr_analyst WITH PASSWORD 'huyhh@2025';
   GRANT hr_analytics_read TO hr_analyst;

6. Configure connection pooling and monitoring

7. Set up ETL processes to populate fact tables

MAINTENANCE:

- Add new partitions annually for fact_employee_snapshot
- Monitor index usage and performance
- Update statistics regularly: ANALYZE;
- Vacuum tables periodically: VACUUM ANALYZE;

*/


-- =====================================================
-- END OF SCRIPT
-- =====================================================