-- =====================================================
-- HR DATA WAREHOUSE - REPORTING TABLES & ETL
-- PostgreSQL 12 Implementation
-- =====================================================

-- This file contains all reporting tables, views, and ETL procedures
-- for the HR Data Warehouse

-- =====================================================
-- REPORTING TABLES (Flat Summary Tables)
-- =====================================================

set search_path = hr_analytics;

-- rpt_hr_summary: Unified HR metrics summary for all periods (Monthly/Quarterly/Yearly)
CREATE TABLE rpt_hr_summary (
    summary_key BIGINT DEFAULT nextval('seq_summary_key'),
    
    -- Period Identification
    period_type VARCHAR(10) NOT NULL CHECK (period_type IN ('MONTHLY', 'QUARTERLY', 'YEARLY')),
    year_number INT NOT NULL,
    period_number INT, -- Month (1-12), Quarter (1-4), or NULL for yearly
    period_name VARCHAR(20), -- 'January', 'Q1', '2024', etc.
    period_start_date DATE NOT NULL,
    period_end_date DATE NOT NULL,
    
    -- Dimensional Context
    department_key INT,
    location_key INT,

    -- Employee Metrics
    total_employees INT DEFAULT 0 CHECK (total_employees >= 0),
    active_employees INT DEFAULT 0 CHECK (active_employees >= 0),
    new_hires INT DEFAULT 0 CHECK (new_hires >= 0),
    terminations INT DEFAULT 0 CHECK (terminations >= 0),
    net_change INT GENERATED ALWAYS AS (new_hires - terminations) STORED,

    -- Headcount by Type
    fulltime_headcount INT DEFAULT 0 CHECK (fulltime_headcount >= 0),
    parttime_headcount INT DEFAULT 0 CHECK (parttime_headcount >= 0),
    contract_headcount INT DEFAULT 0 CHECK (contract_headcount >= 0),
    manager_headcount INT DEFAULT 0 CHECK (manager_headcount >= 0),

    -- Turnover Metrics
    voluntary_turnover INT DEFAULT 0 CHECK (voluntary_turnover >= 0),
    involuntary_turnover INT DEFAULT 0 CHECK (involuntary_turnover >= 0),
    turnover_rate DECIMAL(5,2) CHECK (turnover_rate BETWEEN 0 AND 100),
    voluntary_turnover_rate DECIMAL(5,2) CHECK (voluntary_turnover_rate BETWEEN 0 AND 100),
    retention_rate DECIMAL(5,2) GENERATED ALWAYS AS (100 - turnover_rate) STORED,

    -- Tenure Metrics
    avg_tenure_years DECIMAL(4,2) CHECK (avg_tenure_years >= 0),
    median_tenure_years DECIMAL(4,2) CHECK (median_tenure_years >= 0),

    -- Recruitment Metrics
    open_positions INT DEFAULT 0 CHECK (open_positions >= 0),
    filled_positions INT DEFAULT 0 CHECK (filled_positions >= 0),
    avg_days_to_fill DECIMAL(5,1) CHECK (avg_days_to_fill >= 0),
    avg_cost_per_hire DECIMAL(10,2) CHECK (avg_cost_per_hire >= 0),
    total_recruitment_cost DECIMAL(12,2) CHECK (total_recruitment_cost >= 0),
    offer_acceptance_rate DECIMAL(5,2) CHECK (offer_acceptance_rate BETWEEN 0 AND 100),

    -- Compensation Metrics
    avg_base_salary DECIMAL(12,2) CHECK (avg_base_salary >= 0),
    median_base_salary DECIMAL(12,2) CHECK (median_base_salary >= 0),
    total_compensation_cost DECIMAL(15,2) CHECK (total_compensation_cost >= 0),
    avg_total_compensation DECIMAL(12,2) CHECK (avg_total_compensation >= 0),
    salary_budget_variance DECIMAL(5,2),
    pay_equity_score DECIMAL(3,2) CHECK (pay_equity_score BETWEEN 0 AND 1.0),

    -- Performance Metrics
    performance_reviews_completed INT DEFAULT 0 CHECK (performance_reviews_completed >= 0),
    performance_review_completion_rate DECIMAL(5,2) CHECK (performance_review_completion_rate BETWEEN 0 AND 100),
    avg_performance_rating DECIMAL(3,2) CHECK (avg_performance_rating BETWEEN 1.0 AND 5.0),
    high_performers_count INT DEFAULT 0 CHECK (high_performers_count >= 0),
    low_performers_count INT DEFAULT 0 CHECK (low_performers_count >= 0),
    promotion_recommendations INT DEFAULT 0 CHECK (promotion_recommendations >= 0),

    -- Training Metrics
    training_sessions_completed INT DEFAULT 0 CHECK (training_sessions_completed >= 0),
    total_training_hours DECIMAL(8,1) CHECK (total_training_hours >= 0),
    total_training_cost DECIMAL(12,2) CHECK (total_training_cost >= 0),
    avg_training_hours_per_employee DECIMAL(5,1) CHECK (avg_training_hours_per_employee >= 0),
    training_completion_rate DECIMAL(5,2) CHECK (training_completion_rate BETWEEN 0 AND 100),
    certifications_earned INT DEFAULT 0 CHECK (certifications_earned >= 0),

    -- Career Development
    internal_promotions INT DEFAULT 0 CHECK (internal_promotions >= 0),
    internal_transfers INT DEFAULT 0 CHECK (internal_transfers >= 0),
    internal_mobility_rate DECIMAL(5,2) CHECK (internal_mobility_rate BETWEEN 0 AND 100),
    succession_planning_coverage DECIMAL(5,2) CHECK (succession_planning_coverage BETWEEN 0 AND 100),

    -- Diversity & Inclusion
    gender_diversity_ratio DECIMAL(3,2) CHECK (gender_diversity_ratio BETWEEN 0 AND 1.0),
    ethnic_diversity_count INT DEFAULT 0 CHECK (ethnic_diversity_count >= 0),
    leadership_diversity_ratio DECIMAL(3,2) CHECK (leadership_diversity_ratio BETWEEN 0 AND 1.0),

    -- Engagement Metrics
    engagement_survey_responses INT DEFAULT 0 CHECK (engagement_survey_responses >= 0),
    engagement_survey_participation_rate DECIMAL(5,2) CHECK (engagement_survey_participation_rate BETWEEN 0 AND 100),
    avg_engagement_score DECIMAL(3,2) CHECK (avg_engagement_score BETWEEN 1.0 AND 5.0),
    employee_satisfaction_index DECIMAL(3,2) CHECK (employee_satisfaction_index BETWEEN 1.0 AND 5.0),
    enps_score DECIMAL(4,1) CHECK (enps_score BETWEEN -100 AND 100),

    -- Business Impact (for yearly reports)
    revenue_per_employee DECIMAL(12,2) CHECK (revenue_per_employee >= 0),
    profit_per_employee DECIMAL(12,2),
    hr_cost_per_employee DECIMAL(8,2) CHECK (hr_cost_per_employee >= 0),
    employee_productivity_index DECIMAL(3,2) CHECK (employee_productivity_index BETWEEN 0 AND 5.0),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    PRIMARY KEY (summary_key, period_type),
    CONSTRAINT uk_hr_summary_period UNIQUE (period_type, year_number, period_number, department_key, location_key),
    CONSTRAINT chk_period_number CHECK (
        (period_type = 'MONTHLY' AND period_number BETWEEN 1 AND 12) OR
        (period_type = 'QUARTERLY' AND period_number BETWEEN 1 AND 4) OR
        (period_type = 'YEARLY' AND period_number IS NULL)
    ),
    CONSTRAINT chk_period_dates CHECK (period_start_date <= period_end_date)
) PARTITION BY LIST (period_type);

-- Create partitions for each period type
CREATE TABLE rpt_hr_summary_monthly_part PARTITION OF rpt_hr_summary
    FOR VALUES IN ('MONTHLY');

CREATE TABLE rpt_hr_summary_quarterly_part PARTITION OF rpt_hr_summary
    FOR VALUES IN ('QUARTERLY');

CREATE TABLE rpt_hr_summary_yearly_part PARTITION OF rpt_hr_summary
    FOR VALUES IN ('YEARLY');

-- rpt_employee_lifecycle: Employee journey tracking
CREATE TABLE rpt_employee_lifecycle (
    lifecycle_key BIGINT PRIMARY KEY DEFAULT nextval('seq_lifecycle_key'),
    employee_key INT NOT NULL,

    -- Employee Information
    employee_id VARCHAR(20),
    full_name VARCHAR(200),
    hire_date DATE,
    termination_date DATE,
    total_tenure_days INT,

    -- Current Status
    current_position VARCHAR(100),
    current_department VARCHAR(100),
    current_salary DECIMAL(12,2),

    -- Career Progression
    total_positions_held INT,
    total_departments INT,
    promotion_count INT,

    -- Performance & Development
    last_performance_rating DECIMAL(3,2),
    total_training_hours DECIMAL(8,1),
    last_training_date DATE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- rpt_diversity_dashboard: Diversity metrics by various dimensions
CREATE TABLE rpt_diversity_dashboard (
    diversity_key BIGINT PRIMARY KEY DEFAULT nextval('seq_diversity_key'),
    report_date DATE NOT NULL,
    dimension_type VARCHAR(20), -- Department, Level, Location, etc.
    dimension_value VARCHAR(100),

    -- Headcount Metrics
    total_headcount INT,
    diverse_headcount INT,
    diversity_percentage DECIMAL(5,2),

    -- Gender Diversity
    male_count INT,
    female_count INT,
    other_gender_count INT,
    gender_diversity_ratio DECIMAL(3,2),

    -- Leadership Representation
    leadership_positions INT,
    diverse_leaders INT,
    leadership_diversity_ratio DECIMAL(3,2),

    -- Pay Equity
    avg_salary_male DECIMAL(12,2),
    avg_salary_female DECIMAL(12,2),
    pay_gap_percentage DECIMAL(5,2),
    pay_equity_score DECIMAL(3,2),

    -- Hiring & Promotion
    new_hires_diverse INT,
    promotions_diverse INT,
    diverse_hiring_rate DECIMAL(5,2),
    diverse_promotion_rate DECIMAL(5,2),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- rpt_talent_pipeline: Succession planning and talent pipeline
CREATE TABLE rpt_talent_pipeline (
    pipeline_key BIGINT PRIMARY KEY DEFAULT nextval('seq_pipeline_key'),
    report_date DATE NOT NULL,
    position_key INT,
    department_key INT,

    -- Position Information
    position_title VARCHAR(100),
    department_name VARCHAR(100),
    seniority_level VARCHAR(20),
    is_critical_role BOOLEAN DEFAULT FALSE,

    -- Current Incumbent
    current_employee_key INT,
    incumbent_tenure_years DECIMAL(4,2) CHECK (incumbent_tenure_years >= 0),
    incumbent_performance_rating DECIMAL(3,2) CHECK (incumbent_performance_rating BETWEEN 1.0 AND 5.0),
    retirement_risk_score DECIMAL(3,2) CHECK (retirement_risk_score BETWEEN 0 AND 1.0),

    -- Succession Planning
    ready_now_successors INT DEFAULT 0 CHECK (ready_now_successors >= 0),
    ready_1_year_successors INT DEFAULT 0 CHECK (ready_1_year_successors >= 0),
    ready_2_year_successors INT DEFAULT 0 CHECK (ready_2_year_successors >= 0),
    total_successors INT GENERATED ALWAYS AS (ready_now_successors + ready_1_year_successors + ready_2_year_successors) STORED,
    succession_depth_score DECIMAL(3,2) CHECK (succession_depth_score BETWEEN 0 AND 1.0),

    -- Talent Pool Quality
    avg_successor_performance DECIMAL(3,2) CHECK (avg_successor_performance BETWEEN 1.0 AND 5.0),
    avg_successor_potential DECIMAL(3,2) CHECK (avg_successor_potential BETWEEN 1.0 AND 5.0),
    internal_candidates INT DEFAULT 0 CHECK (internal_candidates >= 0),
    external_candidates_needed INT DEFAULT 0 CHECK (external_candidates_needed >= 0),

    -- Development Needs
    skill_gaps_identified INT DEFAULT 0 CHECK (skill_gaps_identified >= 0),
    development_plans_active INT DEFAULT 0 CHECK (development_plans_active >= 0),
    mentoring_relationships INT DEFAULT 0 CHECK (mentoring_relationships >= 0),

    -- Risk Assessment
    succession_risk_level VARCHAR(10) DEFAULT 'Medium'
        CHECK (succession_risk_level IN ('Low', 'Medium', 'High', 'Critical')),
    business_impact_score DECIMAL(3,2) CHECK (business_impact_score BETWEEN 0 AND 1.0),
    replacement_difficulty_score DECIMAL(3,2) CHECK (replacement_difficulty_score BETWEEN 0 AND 1.0),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- FOREIGN KEY CONSTRAINTS FOR REPORTING TABLES
-- =====================================================

-- Add foreign key constraints for reporting tables
ALTER TABLE rpt_talent_pipeline
    ADD CONSTRAINT fk_pipeline_position FOREIGN KEY (position_key) REFERENCES dim_position(position_key),
    ADD CONSTRAINT fk_pipeline_department FOREIGN KEY (department_key) REFERENCES dim_department(department_key),
    ADD CONSTRAINT fk_pipeline_current_employee FOREIGN KEY (current_employee_key) REFERENCES dim_employee(employee_key);

-- =====================================================
-- INDEXES FOR REPORTING TABLES
-- =====================================================

-- Indexes for rpt_hr_summary
CREATE INDEX idx_rpt_hr_summary_period ON rpt_hr_summary (period_type, year_number, period_number);
CREATE INDEX idx_rpt_hr_summary_department ON rpt_hr_summary (department_key);
CREATE INDEX idx_rpt_hr_summary_location ON rpt_hr_summary (location_key);
CREATE INDEX idx_rpt_hr_summary_dates ON rpt_hr_summary (period_start_date, period_end_date);

-- Indexes for rpt_employee_lifecycle
CREATE INDEX idx_rpt_lifecycle_employee ON rpt_employee_lifecycle (employee_key);
CREATE INDEX idx_rpt_lifecycle_hire_date ON rpt_employee_lifecycle (hire_date);
CREATE INDEX idx_rpt_lifecycle_termination_date ON rpt_employee_lifecycle (termination_date);

-- Indexes for rpt_diversity_dashboard
CREATE INDEX idx_rpt_diversity_date ON rpt_diversity_dashboard (report_date);
CREATE INDEX idx_rpt_diversity_dimension ON rpt_diversity_dashboard (dimension_type, dimension_value);

-- Indexes for rpt_talent_pipeline
CREATE INDEX idx_rpt_pipeline_date ON rpt_talent_pipeline (report_date);
CREATE INDEX idx_rpt_pipeline_position ON rpt_talent_pipeline (position_key);
CREATE INDEX idx_rpt_pipeline_department ON rpt_talent_pipeline (department_key);
CREATE INDEX idx_rpt_pipeline_risk ON rpt_talent_pipeline (succession_risk_level);

-- =====================================================
-- TRIGGERS FOR AUTOMATIC TIMESTAMP UPDATES
-- =====================================================

-- Triggers for rpt_hr_summary
CREATE TRIGGER trigger_rpt_hr_summary_updated_at
    BEFORE UPDATE ON rpt_hr_summary
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Triggers for rpt_employee_lifecycle
CREATE TRIGGER trigger_rpt_employee_lifecycle_updated_at
    BEFORE UPDATE ON rpt_employee_lifecycle
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Triggers for rpt_diversity_dashboard
CREATE TRIGGER trigger_rpt_diversity_dashboard_updated_at
    BEFORE UPDATE ON rpt_diversity_dashboard
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Triggers for rpt_talent_pipeline
CREATE TRIGGER trigger_rpt_talent_pipeline_updated_at
    BEFORE UPDATE ON rpt_talent_pipeline
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- UTILITY VIEWS FOR REPORTING
-- =====================================================

-- View for monthly HR summary
CREATE VIEW vw_monthly_hr_summary AS
SELECT * FROM rpt_hr_summary
WHERE period_type = 'MONTHLY'
ORDER BY year_number DESC, period_number DESC;

-- View for quarterly HR summary
CREATE VIEW vw_quarterly_hr_summary AS
SELECT * FROM rpt_hr_summary
WHERE period_type = 'QUARTERLY'
ORDER BY year_number DESC, period_number DESC;

-- View for yearly HR summary
CREATE VIEW vw_yearly_hr_summary AS
SELECT * FROM rpt_hr_summary
WHERE period_type = 'YEARLY'
ORDER BY year_number DESC;

-- View for latest period summary by department
CREATE VIEW vw_latest_hr_metrics AS
WITH latest_periods AS (
    SELECT
        period_type,
        department_key,
        MAX(year_number * 100 + COALESCE(period_number, 0)) as latest_period
    FROM rpt_hr_summary
    GROUP BY period_type, department_key
)
SELECT
    r.*,
    d.department_name,
    l.location_name
FROM rpt_hr_summary r
JOIN latest_periods lp ON r.period_type = lp.period_type
    AND r.department_key = lp.department_key
    AND (r.year_number * 100 + COALESCE(r.period_number, 0)) = lp.latest_period
LEFT JOIN dim_department d ON r.department_key = d.department_key AND d.is_active = TRUE
LEFT JOIN dim_location l ON r.location_key = l.location_key AND l.is_active = TRUE;

-- =====================================================
-- ETL PROCEDURES FOR REPORTING TABLES
-- =====================================================

-- ETL for rpt_hr_summary (Unified table for all periods)
CREATE OR REPLACE FUNCTION etl_hr_summary(
    p_period_type VARCHAR(10),
    p_year INT,
    p_period_number INT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_period_start_date DATE;
    v_period_end_date DATE;
    v_period_name VARCHAR(20);
BEGIN
    -- Calculate period dates and name based on period type
    IF p_period_type = 'MONTHLY' THEN
        v_period_start_date := DATE(p_year || '-' || LPAD(p_period_number::TEXT, 2, '0') || '-01');
        v_period_end_date := (v_period_start_date + INTERVAL '1 month - 1 day')::DATE;
        v_period_name := TO_CHAR(v_period_start_date, 'Month');
    ELSIF p_period_type = 'QUARTERLY' THEN
        v_period_start_date := DATE(p_year || '-' || LPAD(((p_period_number-1)*3+1)::TEXT, 2, '0') || '-01');
        v_period_end_date := (v_period_start_date + INTERVAL '3 months - 1 day')::DATE;
        v_period_name := 'Q' || p_period_number;
    ELSIF p_period_type = 'YEARLY' THEN
        v_period_start_date := DATE(p_year || '-01-01');
        v_period_end_date := DATE(p_year || '-12-31');
        v_period_name := p_year::TEXT;
        p_period_number := NULL;
    ELSE
        RAISE EXCEPTION 'Invalid period_type: %', p_period_type;
    END IF;

    -- Delete existing data for the period
    DELETE FROM rpt_hr_summary
    WHERE period_type = p_period_type
    AND year_number = p_year
    AND (p_period_number IS NULL OR period_number = p_period_number);

    -- Insert aggregated data
    INSERT INTO rpt_hr_summary (
        period_type, year_number, period_number, period_name,
        period_start_date, period_end_date, department_key, location_key,
        total_employees, active_employees, new_hires, terminations,
        fulltime_headcount, parttime_headcount, contract_headcount, manager_headcount,
        voluntary_turnover, involuntary_turnover, turnover_rate, voluntary_turnover_rate,
        avg_tenure_years, median_tenure_years,
        open_positions, filled_positions, avg_days_to_fill, avg_cost_per_hire,
        avg_base_salary, median_base_salary, total_compensation_cost,
        performance_reviews_completed, avg_performance_rating,
        total_training_hours, training_sessions_completed, certifications_earned,
        internal_promotions, internal_transfers,
        gender_diversity_ratio, leadership_diversity_ratio,
        created_at, updated_at
    )
    SELECT
        p_period_type,
        p_year,
        p_period_number,
        v_period_name,
        v_period_start_date,
        v_period_end_date,
        s.department_key,
        s.location_key,

        -- Employee Metrics
        COUNT(DISTINCT s.employee_key) as total_employees,
        COUNT(DISTINCT CASE WHEN s.is_active_employee THEN s.employee_key END) as active_employees,
        COUNT(DISTINCT CASE WHEN s.is_new_hire THEN s.employee_key END) as new_hires,
        COUNT(DISTINCT CASE WHEN s.is_termination THEN s.employee_key END) as terminations,

        -- Headcount by Type (from dim_employee)
        COUNT(DISTINCT CASE WHEN e.employment_type = 'Full-time' AND s.is_active_employee THEN s.employee_key END) as fulltime_headcount,
        COUNT(DISTINCT CASE WHEN e.employment_type = 'Part-time' AND s.is_active_employee THEN s.employee_key END) as parttime_headcount,
        COUNT(DISTINCT CASE WHEN e.employment_type = 'Contract' AND s.is_active_employee THEN s.employee_key END) as contract_headcount,
        COUNT(DISTINCT CASE WHEN p.is_leadership_role = TRUE AND s.is_active_employee THEN s.employee_key END) as manager_headcount,

        -- Turnover Metrics (from fact_turnover)
        COALESCE(turn.voluntary_turnover, 0) as voluntary_turnover,
        COALESCE(turn.involuntary_turnover, 0) as involuntary_turnover,
        CASE
            WHEN COUNT(DISTINCT CASE WHEN s.is_active_employee THEN s.employee_key END) > 0
            THEN (COUNT(DISTINCT CASE WHEN s.is_termination THEN s.employee_key END) * 100.0 /
                  COUNT(DISTINCT CASE WHEN s.is_active_employee THEN s.employee_key END))
            ELSE 0
        END as turnover_rate,
        CASE
            WHEN COUNT(DISTINCT CASE WHEN s.is_active_employee THEN s.employee_key END) > 0
            THEN (COALESCE(turn.voluntary_turnover, 0) * 100.0 /
                  COUNT(DISTINCT CASE WHEN s.is_active_employee THEN s.employee_key END))
            ELSE 0
        END as voluntary_turnover_rate,

        -- Tenure Metrics
        AVG(s.tenure_years) as avg_tenure_years,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.tenure_years) as median_tenure_years,

        -- Recruitment Metrics (from fact_recruitment)
        COALESCE(rec.open_positions, 0) as open_positions,
        COALESCE(rec.filled_positions, 0) as filled_positions,
        COALESCE(rec.avg_days_to_fill, 0) as avg_days_to_fill,
        COALESCE(rec.avg_cost_per_hire, 0) as avg_cost_per_hire,

        -- Compensation Metrics
        AVG(s.base_salary) as avg_base_salary,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.base_salary) as median_base_salary,
        SUM(s.total_compensation) as total_compensation_cost,

        -- Performance Metrics (from fact_performance)
        COALESCE(perf.reviews_completed, 0) as performance_reviews_completed,
        COALESCE(perf.avg_rating, 0) as avg_performance_rating,

        -- Training Metrics (from fact_training)
        COALESCE(train.total_hours, 0) as total_training_hours,
        COALESCE(train.sessions_completed, 0) as training_sessions_completed,
        COALESCE(train.certifications, 0) as certifications_earned,

        -- Career Development (from fact_compensation_history)
        COALESCE(career.promotions, 0) as internal_promotions,
        COALESCE(career.transfers, 0) as internal_transfers,

        -- Diversity Metrics (calculated from employee demographics)
        CASE
            WHEN COUNT(DISTINCT CASE WHEN s.is_active_employee THEN s.employee_key END) > 0
            THEN COUNT(DISTINCT CASE WHEN e.gender = 'Female' AND s.is_active_employee THEN s.employee_key END)::DECIMAL /
                 COUNT(DISTINCT CASE WHEN s.is_active_employee THEN s.employee_key END)
            ELSE 0
        END as gender_diversity_ratio,
        CASE
            WHEN COUNT(DISTINCT CASE WHEN p.is_leadership_role = TRUE AND s.is_active_employee THEN s.employee_key END) > 0
            THEN COUNT(DISTINCT CASE WHEN e.gender = 'Female' AND p.is_leadership_role = TRUE AND s.is_active_employee THEN s.employee_key END)::DECIMAL /
                 COUNT(DISTINCT CASE WHEN p.is_leadership_role = TRUE AND s.is_active_employee THEN s.employee_key END)
            ELSE 0
        END as leadership_diversity_ratio,

        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP

    FROM fact_employee_snapshot s
    JOIN dim_date d ON s.date_key = d.date_key
    LEFT JOIN dim_employee e ON s.employee_key = e.employee_key AND e.is_current = TRUE
    LEFT JOIN dim_position p ON s.position_key = p.position_key AND p.is_active = TRUE
    LEFT JOIN (
        -- Turnover aggregation
        SELECT
            s2.department_key,
            s2.location_key,
            COUNT(CASE WHEN ft.termination_type = 'Voluntary' THEN 1 END) as voluntary_turnover,
            COUNT(CASE WHEN ft.termination_type = 'Involuntary' THEN 1 END) as involuntary_turnover
        FROM fact_turnover ft
        JOIN dim_date td ON ft.termination_date_key = td.date_key
        JOIN fact_employee_snapshot s2 ON ft.employee_key = s2.employee_key
        WHERE td.full_date BETWEEN v_period_start_date AND v_period_end_date
        GROUP BY s2.department_key, s2.location_key
    ) turn ON s.department_key = turn.department_key AND s.location_key = turn.location_key
    LEFT JOIN (
        -- Recruitment aggregation
        SELECT
            fr.department_key,
            fr.location_key,
            COUNT(CASE WHEN fr.requisition_status = 'Open' THEN 1 END) as open_positions,
            COUNT(CASE WHEN fr.requisition_status = 'Filled' THEN 1 END) as filled_positions,
            AVG(fr.days_to_fill) as avg_days_to_fill,
            AVG(fr.cost_per_hire) as avg_cost_per_hire
        FROM fact_recruitment fr
        LEFT JOIN dim_date pd ON fr.posting_date_key = pd.date_key
        WHERE pd.full_date BETWEEN v_period_start_date AND v_period_end_date
        GROUP BY fr.department_key, fr.location_key
    ) rec ON s.department_key = rec.department_key AND s.location_key = rec.location_key
    LEFT JOIN (
        -- Performance aggregation
        SELECT
            s3.department_key,
            s3.location_key,
            COUNT(*) as reviews_completed,
            AVG(fp.overall_rating) as avg_rating
        FROM fact_performance fp
        JOIN dim_date pd ON fp.review_completion_date_key = pd.date_key
        JOIN fact_employee_snapshot s3 ON fp.employee_key = s3.employee_key
        WHERE pd.full_date BETWEEN v_period_start_date AND v_period_end_date
        AND fp.review_status = 'Completed'
        GROUP BY s3.department_key, s3.location_key
    ) perf ON s.department_key = perf.department_key AND s.location_key = perf.location_key
    LEFT JOIN (
        -- Training aggregation
        SELECT
            s4.department_key,
            s4.location_key,
            SUM(ft.training_hours) as total_hours,
            COUNT(*) as sessions_completed,
            COUNT(CASE WHEN ft.certification_earned THEN 1 END) as certifications
        FROM fact_training ft
        JOIN dim_date td ON ft.training_date_key = td.date_key
        JOIN fact_employee_snapshot s4 ON ft.employee_key = s4.employee_key
        WHERE td.full_date BETWEEN v_period_start_date AND v_period_end_date
        AND ft.completion_status = 'Completed'
        GROUP BY s4.department_key, s4.location_key
    ) train ON s.department_key = train.department_key AND s.location_key = train.location_key
    LEFT JOIN (
        -- Career development aggregation
        SELECT
            s5.department_key,
            s5.location_key,
            COUNT(CASE WHEN fch.change_reason = 'Promotion' THEN 1 END) as promotions,
            COUNT(CASE WHEN fch.change_reason = 'Role Change' THEN 1 END) as transfers
        FROM fact_compensation_history fch
        JOIN dim_date ed ON fch.effective_date_key = ed.date_key
        JOIN fact_employee_snapshot s5 ON fch.employee_key = s5.employee_key
        WHERE ed.full_date BETWEEN v_period_start_date AND v_period_end_date
        GROUP BY s5.department_key, s5.location_key
    ) career ON s.department_key = career.department_key AND s.location_key = career.location_key

    WHERE d.full_date BETWEEN v_period_start_date AND v_period_end_date

    GROUP BY p_period_type, p_year, p_period_number, v_period_name,
             v_period_start_date, v_period_end_date,
             s.department_key, s.location_key,
             turn.voluntary_turnover, turn.involuntary_turnover,
             rec.open_positions, rec.filled_positions, rec.avg_days_to_fill, rec.avg_cost_per_hire,
             perf.reviews_completed, perf.avg_rating,
             train.total_hours, train.sessions_completed, train.certifications,
             career.promotions, career.transfers;

    RAISE NOTICE '% HR Summary ETL completed for % period %', p_period_type, p_year, COALESCE(p_period_number::TEXT, 'YEARLY');
END;
$$ LANGUAGE plpgsql;

-- ETL for rpt_employee_lifecycle (Full Refresh)
CREATE OR REPLACE FUNCTION etl_employee_lifecycle()
RETURNS VOID AS $$
BEGIN
    -- Truncate and reload (Full Refresh pattern)
    TRUNCATE TABLE rpt_employee_lifecycle;

    INSERT INTO rpt_employee_lifecycle (
        employee_key, employee_id, full_name, hire_date, termination_date,
        total_tenure_days, current_position, current_department, current_salary,
        total_positions_held, total_departments, promotion_count,
        last_performance_rating, total_training_hours, last_training_date,
        created_at, updated_at
    )
    SELECT
        e.employee_key,
        e.employee_id,
        e.full_name,
        e.hire_date,
        e.termination_date,

        -- Tenure calculation
        CASE
            WHEN e.termination_date IS NOT NULL
            THEN e.termination_date - e.hire_date
            ELSE CURRENT_DATE - e.hire_date
        END as total_tenure_days,

        -- Current position info
        p.position_title as current_position,
        d.department_name as current_department,
        c.base_salary as current_salary,

        -- Career progression metrics
        COALESCE(career.positions_held, 1) as total_positions_held,
        COALESCE(career.departments_count, 1) as total_departments,
        COALESCE(career.promotions, 0) as promotion_count,

        -- Performance & Training
        perf.last_rating as last_performance_rating,
        COALESCE(training.total_hours, 0) as total_training_hours,
        training.last_training_date,

        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP

    FROM vw_current_employees e
    LEFT JOIN dim_position p ON e.employee_key = p.position_key -- This needs proper join logic
    LEFT JOIN dim_department d ON e.employee_key = d.department_key -- This needs proper join logic
    LEFT JOIN dim_compensation c ON e.employee_key = c.compensation_key -- This needs proper join logic
    LEFT JOIN (
        -- Career progression analysis
        SELECT
            employee_key,
            COUNT(DISTINCT position_key) as positions_held,
            COUNT(DISTINCT department_key) as departments_count,
            COUNT(CASE WHEN change_reason = 'Promotion' THEN 1 END) as promotions
        FROM fact_compensation_history
        GROUP BY employee_key
    ) career ON e.employee_key = career.employee_key
    LEFT JOIN (
        -- Latest performance rating
        SELECT DISTINCT
            employee_key,
            FIRST_VALUE(overall_rating) OVER (
                PARTITION BY employee_key
                ORDER BY review_completion_date_key DESC
            ) as last_rating
        FROM fact_performance
        WHERE review_status = 'Completed'
    ) perf ON e.employee_key = perf.employee_key
    LEFT JOIN (
        -- Training summary
        SELECT
            employee_key,
            SUM(training_hours) as total_hours,
            MAX(td.full_date) as last_training_date
        FROM fact_training ft
        JOIN dim_date td ON ft.completion_date_key = td.date_key
        WHERE ft.completion_status = 'Completed'
        GROUP BY employee_key
    ) training ON e.employee_key = training.employee_key;

    RAISE NOTICE 'Employee Lifecycle ETL completed for % employees',
                 (SELECT COUNT(*) FROM rpt_employee_lifecycle);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- ETL SCHEDULING PROCEDURES
-- =====================================================

-- Convenience functions for specific period types
CREATE OR REPLACE FUNCTION etl_monthly_hr_summary(p_year INT, p_month INT)
RETURNS VOID AS $$
BEGIN
    PERFORM etl_hr_summary('MONTHLY', p_year, p_month);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION etl_quarterly_hr_summary(p_year INT, p_quarter INT)
RETURNS VOID AS $$
BEGIN
    PERFORM etl_hr_summary('QUARTERLY', p_year, p_quarter);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION etl_yearly_hr_summary(p_year INT)
RETURNS VOID AS $$
BEGIN
    PERFORM etl_hr_summary('YEARLY', p_year);
END;
$$ LANGUAGE plpgsql;

-- Daily ETL orchestration
CREATE OR REPLACE FUNCTION daily_etl_process()
RETURNS VOID AS $$
DECLARE
    current_year INT := EXTRACT(YEAR FROM CURRENT_DATE);
    current_month INT := EXTRACT(MONTH FROM CURRENT_DATE);
    current_quarter INT := EXTRACT(QUARTER FROM CURRENT_DATE);
    prev_month INT;
    prev_year INT;
    prev_quarter INT;
    prev_quarter_year INT;
BEGIN
    -- Calculate previous month
    IF current_month = 1 THEN
        prev_month := 12;
        prev_year := current_year - 1;
    ELSE
        prev_month := current_month - 1;
        prev_year := current_year;
    END IF;

    -- Calculate previous quarter
    IF current_quarter = 1 THEN
        prev_quarter := 4;
        prev_quarter_year := current_year - 1;
    ELSE
        prev_quarter := current_quarter - 1;
        prev_quarter_year := current_year;
    END IF;

    -- Run monthly summary for current and previous month
    PERFORM etl_monthly_hr_summary(current_year, current_month);
    PERFORM etl_monthly_hr_summary(prev_year, prev_month);

    -- Run quarterly summary (on last day of quarter)
    IF current_month IN (3, 6, 9, 12) AND EXTRACT(DAY FROM CURRENT_DATE + INTERVAL '1 day') = 1 THEN
        PERFORM etl_quarterly_hr_summary(current_year, current_quarter);
        PERFORM etl_quarterly_hr_summary(prev_quarter_year, prev_quarter);
    END IF;

    -- Run yearly summary (on January 1st)
    IF current_month = 1 AND EXTRACT(DAY FROM CURRENT_DATE) = 1 THEN
        PERFORM etl_yearly_hr_summary(current_year - 1);
    END IF;

    -- Run employee lifecycle (weekly on Sundays)
    IF EXTRACT(DOW FROM CURRENT_DATE) = 0 THEN
        PERFORM etl_employee_lifecycle();
    END IF;

    RAISE NOTICE 'Daily ETL process completed at %', CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- END OF REPORTING SCRIPT
-- =====================================================
