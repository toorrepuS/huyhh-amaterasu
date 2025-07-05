-- =====================================================
-- HR Data Warehouse - Common Queries
-- =====================================================

-- =====================================================
-- 1. HEADCOUNT & DEMOGRAPHICS QUERIES
-- =====================================================

set search_path = hr_analytics;

-- Current Active Headcount by Department
SELECT
    d.department_name,
    d.division,
    COUNT(*) as current_headcount,
    COUNT(CASE WHEN e.employment_type = 'Full-time' THEN 1 END) as fulltime_count,
    COUNT(CASE WHEN e.employment_type = 'Part-time' THEN 1 END) as parttime_count,
    COUNT(CASE WHEN e.employment_type = 'Contract' THEN 1 END) as contract_count,
    COUNT(CASE WHEN e.is_manager = TRUE THEN 1 END) as manager_count
FROM fact_employee_snapshot f
JOIN dim_employee e ON f.employee_key = e.employee_key
JOIN dim_department d ON f.department_key = d.department_key
JOIN dim_date dt ON f.date_key = dt.date_key
WHERE f.is_active_employee = TRUE
    AND e.is_current = TRUE
GROUP BY d.department_name, d.division
ORDER BY current_headcount DESC;

-- Headcount Trend Over Time (Monthly)
SELECT
    dt.year_number,
    dt.month_number,
    dt.month_name,
    COUNT(*) as total_headcount,
    COUNT(CASE WHEN f.is_new_hire = TRUE THEN 1 END) as new_hires,
    COUNT(CASE WHEN f.is_termination = TRUE THEN 1 END) as terminations,
    COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY dt.year_number, dt.month_number) as net_change
FROM fact_employee_snapshot f
JOIN dim_date dt ON f.date_key = dt.date_key
WHERE f.is_active_employee = TRUE
--     AND dt.day_of_month = 1  -- First day of each month
GROUP BY dt.year_number, dt.month_number, dt.month_name
ORDER BY dt.year_number, dt.month_number;

-- Employee Demographics Summary
SELECT
    e.gender,
    e.ethnicity,
    COUNT(*) as employee_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage,
    ROUND(AVG(DATEDIFF(CURRENT_DATE, e.hire_date) / 365.25), 1) as avg_tenure_years,
    ROUND(AVG(f.base_salary), 0) as avg_salary
FROM fact_employee_snapshot f
JOIN dim_employee e ON f.employee_key = e.employee_key
JOIN dim_date dt ON f.date_key = dt.date_key
WHERE dt.full_date = CURRENT_DATE
    AND f.is_active_employee = TRUE
    AND e.is_current = TRUE
GROUP BY e.gender, e.ethnicity
ORDER BY employee_count DESC;

-- =====================================================
-- 2. TURNOVER & RETENTION QUERIES
-- =====================================================

-- Monthly Turnover Rate by Department
SELECT
    dt.year_number,
    dt.month_number,
    d.department_name,
    COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END) as avg_headcount,
    COUNT(CASE WHEN t.turnover_key IS NOT NULL THEN 1 END) as terminations,
    ROUND(
        COUNT(CASE WHEN t.turnover_key IS NOT NULL THEN 1 END) * 100.0 /
        NULLIF(COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END), 0), 2
    ) as turnover_rate_percent
FROM fact_employee_snapshot f
JOIN dim_date dt ON f.date_key = dt.date_key
JOIN dim_department d ON f.department_key = d.department_key
LEFT JOIN fact_turnover t ON f.employee_key = t.employee_key
    AND t.termination_date_key = dt.date_key
WHERE dt.year_number >= YEAR(CURRENT_DATE) - 1
GROUP BY dt.year_number, dt.month_number, d.department_name
HAVING avg_headcount > 0
ORDER BY dt.year_number, dt.month_number, turnover_rate_percent DESC;

-- Voluntary vs Involuntary Turnover Analysis
SELECT
    dt.year_number,
    dt.quarter_name,
    COUNT(*) as total_terminations,
    COUNT(CASE WHEN t.termination_type = 'Voluntary' THEN 1 END) as voluntary_terminations,
    COUNT(CASE WHEN t.termination_type = 'Involuntary' THEN 1 END) as involuntary_terminations,
    ROUND(COUNT(CASE WHEN t.termination_type = 'Voluntary' THEN 1 END) * 100.0 / COUNT(*), 1) as voluntary_percentage,
    ROUND(AVG(t.tenure_at_termination_years), 1) as avg_tenure_at_termination
FROM fact_turnover t
JOIN dim_date dt ON t.termination_date_key = dt.date_key
WHERE dt.year_number >= YEAR(CURRENT_DATE) - 2
GROUP BY dt.year_number, dt.quarter_name
ORDER BY dt.year_number, dt.quarter_number;

-- High Performer Retention Analysis
SELECT
    d.department_name,
    COUNT(CASE WHEN p.overall_rating >= 4.0 THEN 1 END) as high_performers,
    COUNT(CASE WHEN p.overall_rating >= 4.0 AND t.turnover_key IS NOT NULL THEN 1 END) as high_performer_turnover,
    ROUND(
        (COUNT(CASE WHEN p.overall_rating >= 4.0 THEN 1 END) -
         COUNT(CASE WHEN p.overall_rating >= 4.0 AND t.turnover_key IS NOT NULL THEN 1 END)) * 100.0 /
        NULLIF(COUNT(CASE WHEN p.overall_rating >= 4.0 THEN 1 END), 0), 1
    ) as high_performer_retention_rate
FROM fact_performance p
JOIN dim_employee e ON p.employee_key = e.employee_key
JOIN dim_department d ON e.employee_key = d.department_key
LEFT JOIN fact_turnover t ON p.employee_key = t.employee_key
WHERE p.review_type = 'Annual'
    AND p.review_status = 'Completed'
GROUP BY d.department_name
ORDER BY high_performer_retention_rate DESC;

-- =====================================================
-- 3. RECRUITMENT METRICS QUERIES
-- =====================================================

-- Recruitment Funnel Analysis
SELECT
    p.position_title,
    d.department_name,
    COUNT(*) as total_requisitions,
    AVG(r.days_to_fill) as avg_days_to_fill,
    AVG(r.cost_per_hire) as avg_cost_per_hire,
    AVG(r.number_of_applicants) as avg_applicants,
    AVG(r.number_of_interviews) as avg_interviews,
    AVG(r.offers_accepted * 100.0 / NULLIF(r.number_of_offers, 0)) as offer_acceptance_rate
FROM fact_recruitment r
JOIN dim_position p ON r.position_key = p.position_key
JOIN dim_department d ON r.department_key = d.department_key
WHERE r.requisition_status = 'Filled'
GROUP BY p.position_title, d.department_name
HAVING COUNT(*) >= 3  -- Only positions with multiple hires
ORDER BY avg_days_to_fill DESC;

-- Source of Hire Effectiveness
SELECT
    r.source_of_hire,
    COUNT(*) as total_hires,
    AVG(r.days_to_fill) as avg_days_to_fill,
    AVG(r.cost_per_hire) as avg_cost_per_hire,
    ROUND(AVG(r.cost_per_hire) / AVG(r.days_to_fill), 2) as cost_efficiency_ratio,
    -- Quality metrics (need to join with performance data)
    AVG(perf.overall_rating) as avg_first_year_performance
FROM fact_recruitment r
LEFT JOIN fact_performance perf ON r.hiring_manager_employee_key = perf.employee_key
WHERE r.requisition_status = 'Filled'
GROUP BY r.source_of_hire
ORDER BY total_hires DESC;

-- =====================================================
-- 4. PERFORMANCE METRICS QUERIES
-- =====================================================

-- Performance Distribution by Department
SELECT
    d.department_name,
    COUNT(*) as total_reviews,
    AVG(p.overall_rating) as avg_rating,
    COUNT(CASE WHEN p.overall_rating >= 4.5 THEN 1 END) as excellent_performers,
    COUNT(CASE WHEN p.overall_rating >= 3.5 AND p.overall_rating < 4.5 THEN 1 END) as good_performers,
    COUNT(CASE WHEN p.overall_rating >= 2.5 AND p.overall_rating < 3.5 THEN 1 END) as average_performers,
    COUNT(CASE WHEN p.overall_rating < 2.5 THEN 1 END) as below_average_performers,
    ROUND(COUNT(CASE WHEN p.promotion_recommended = TRUE THEN 1 END) * 100.0 / COUNT(*), 1) as promotion_recommendation_rate
FROM fact_performance p
JOIN dim_employee e ON p.employee_key = e.employee_key
JOIN dim_department d ON e.employee_key = d.department_key
WHERE p.review_type = 'Annual'
    AND p.review_status = 'Completed'
GROUP BY d.department_name
ORDER BY avg_rating DESC;

-- Performance Trend Analysis
SELECT
    e.employee_id,
    e.full_name,
    d.department_name,
    p1.overall_rating as current_year_rating,
    p2.overall_rating as previous_year_rating,
    p1.overall_rating - p2.overall_rating as rating_change,
    CASE
        WHEN p1.overall_rating - p2.overall_rating > 0.5 THEN 'Significant Improvement'
        WHEN p1.overall_rating - p2.overall_rating > 0 THEN 'Improvement'
        WHEN p1.overall_rating - p2.overall_rating = 0 THEN 'Stable'
        WHEN p1.overall_rating - p2.overall_rating > -0.5 THEN 'Slight Decline'
        ELSE 'Significant Decline'
    END as performance_trend
FROM fact_performance p1
JOIN fact_performance p2 ON p1.employee_key = p2.employee_key
JOIN dim_employee e ON p1.employee_key = e.employee_key
JOIN dim_department d ON e.employee_key = d.department_key
JOIN dim_date dt1 ON p1.review_period_end_date_key = dt1.date_key
JOIN dim_date dt2 ON p2.review_period_end_date_key = dt2.date_key
WHERE dt1.year_number = YEAR(CURRENT_DATE) - 1
    AND dt2.year_number = YEAR(CURRENT_DATE) - 2
    AND p1.review_type = 'Annual'
    AND p2.review_type = 'Annual'
ORDER BY rating_change DESC;

-- =====================================================
-- 5. COMPENSATION ANALYSIS QUERIES
-- =====================================================

-- Salary Analysis by Department and Level
SELECT
    d.department_name,
    e.employee_level,
    COUNT(*) as employee_count,
    MIN(f.base_salary) as min_salary,
    AVG(f.base_salary) as avg_salary,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.base_salary) as median_salary,
    MAX(f.base_salary) as max_salary,
    STDDEV(f.base_salary) as salary_stddev
FROM fact_employee_snapshot f
JOIN dim_employee e ON f.employee_key = e.employee_key
JOIN dim_department d ON f.department_key = d.department_key
JOIN dim_date dt ON f.date_key = dt.date_key
WHERE dt.full_date = CURRENT_DATE
    AND f.is_active_employee = TRUE
    AND e.is_current = TRUE
GROUP BY d.department_name, e.employee_level
ORDER BY d.department_name, avg_salary DESC;

-- Pay Equity Analysis (Gender)
SELECT
    d.department_name,
    e.employee_level,
    AVG(CASE WHEN e.gender = 'Male' THEN f.base_salary END) as avg_male_salary,
    AVG(CASE WHEN e.gender = 'Female' THEN f.base_salary END) as avg_female_salary,
    ROUND(
        (AVG(CASE WHEN e.gender = 'Male' THEN f.base_salary END) -
         AVG(CASE WHEN e.gender = 'Female' THEN f.base_salary END)) * 100.0 /
        AVG(CASE WHEN e.gender = 'Male' THEN f.base_salary END), 2
    ) as gender_pay_gap_percent
FROM fact_employee_snapshot f
JOIN dim_employee e ON f.employee_key = e.employee_key
JOIN dim_department d ON f.department_key = d.department_key
JOIN dim_date dt ON f.date_key = dt.date_key
WHERE dt.full_date = CURRENT_DATE
    AND f.is_active_employee = TRUE
    AND e.is_current = TRUE
    AND e.gender IN ('Male', 'Female')
GROUP BY d.department_name, e.employee_level
HAVING COUNT(CASE WHEN e.gender = 'Male' THEN 1 END) >= 3
    AND COUNT(CASE WHEN e.gender = 'Female' THEN 1 END) >= 3
ORDER BY ABS(gender_pay_gap_percent) DESC;

-- Compensation Change History
SELECT
    e.employee_id,
    e.full_name,
    d.department_name,
    ch.change_reason,
    ch.previous_salary,
    ch.base_salary as new_salary,
    ch.change_percentage,
    dt.full_date as effective_date
FROM fact_compensation_history ch
JOIN dim_employee e ON ch.employee_key = e.employee_key
JOIN dim_department d ON e.employee_key = d.department_key
JOIN dim_date dt ON ch.effective_date_key = dt.date_key
WHERE dt.year_number >= YEAR(CURRENT_DATE) - 1
ORDER BY dt.full_date DESC, ch.change_percentage DESC;

-- =====================================================
-- 6. TRAINING & DEVELOPMENT QUERIES
-- =====================================================

-- Training Completion and Effectiveness
SELECT
    t.training_category,
    COUNT(*) as total_enrollments,
    COUNT(CASE WHEN t.completion_status = 'Completed' THEN 1 END) as completed,
    ROUND(COUNT(CASE WHEN t.completion_status = 'Completed' THEN 1 END) * 100.0 / COUNT(*), 1) as completion_rate,
    AVG(t.training_hours) as avg_training_hours,
    AVG(t.training_cost) as avg_cost_per_training,
    AVG(t.satisfaction_rating) as avg_satisfaction,
    AVG(t.assessment_score) as avg_assessment_score
FROM fact_training t
JOIN dim_date dt ON t.training_date_key = dt.date_key
WHERE dt.year_number >= YEAR(CURRENT_DATE) - 1
GROUP BY t.training_category
ORDER BY completion_rate DESC, avg_satisfaction DESC;

-- Employee Training Investment by Department
SELECT
    d.department_name,
    COUNT(DISTINCT t.employee_key) as employees_trained,
    COUNT(*) as total_training_sessions,
    SUM(t.training_hours) as total_training_hours,
    SUM(t.training_cost) as total_training_cost,
    ROUND(AVG(t.training_hours), 1) as avg_hours_per_employee,
    ROUND(AVG(t.training_cost), 0) as avg_cost_per_employee,
    COUNT(CASE WHEN t.certification_earned = TRUE THEN 1 END) as certifications_earned
FROM fact_training t
JOIN dim_employee e ON t.employee_key = e.employee_key
JOIN dim_department d ON e.employee_key = d.department_key
JOIN dim_date dt ON t.training_date_key = dt.date_key
WHERE dt.year_number = YEAR(CURRENT_DATE)
    AND t.completion_status = 'Completed'
GROUP BY d.department_name
ORDER BY total_training_cost DESC;

-- =====================================================
-- 7. DIVERSITY & INCLUSION QUERIES
-- =====================================================

-- Diversity Metrics Dashboard
SELECT
    'Overall' as dimension,
    COUNT(*) as total_employees,
    COUNT(CASE WHEN e.gender = 'Female' THEN 1 END) as female_count,
    ROUND(COUNT(CASE WHEN e.gender = 'Female' THEN 1 END) * 100.0 / COUNT(*), 1) as female_percentage,
    COUNT(CASE WHEN e.ethnicity != 'White' THEN 1 END) as ethnic_minority_count,
    ROUND(COUNT(CASE WHEN e.ethnicity != 'White' THEN 1 END) * 100.0 / COUNT(*), 1) as ethnic_minority_percentage,
    COUNT(CASE WHEN e.is_manager = TRUE AND e.gender = 'Female' THEN 1 END) as female_managers,
    ROUND(COUNT(CASE WHEN e.is_manager = TRUE AND e.gender = 'Female' THEN 1 END) * 100.0 /
          NULLIF(COUNT(CASE WHEN e.is_manager = TRUE THEN 1 END), 0), 1) as female_leadership_percentage
FROM fact_employee_snapshot f
JOIN dim_employee e ON f.employee_key = e.employee_key
JOIN dim_date dt ON f.date_key = dt.date_key
WHERE dt.full_date = CURRENT_DATE
    AND f.is_active_employee = TRUE
    AND e.is_current = TRUE

UNION ALL

SELECT
    d.department_name as dimension,
    COUNT(*) as total_employees,
    COUNT(CASE WHEN e.gender = 'Female' THEN 1 END) as female_count,
    ROUND(COUNT(CASE WHEN e.gender = 'Female' THEN 1 END) * 100.0 / COUNT(*), 1) as female_percentage,
    COUNT(CASE WHEN e.ethnicity != 'White' THEN 1 END) as ethnic_minority_count,
    ROUND(COUNT(CASE WHEN e.ethnicity != 'White' THEN 1 END) * 100.0 / COUNT(*), 1) as ethnic_minority_percentage,
    COUNT(CASE WHEN e.is_manager = TRUE AND e.gender = 'Female' THEN 1 END) as female_managers,
    ROUND(COUNT(CASE WHEN e.is_manager = TRUE AND e.gender = 'Female' THEN 1 END) * 100.0 /
          NULLIF(COUNT(CASE WHEN e.is_manager = TRUE THEN 1 END), 0), 1) as female_leadership_percentage
FROM fact_employee_snapshot f
JOIN dim_employee e ON f.employee_key = e.employee_key
JOIN dim_department d ON f.department_key = d.department_key
JOIN dim_date dt ON f.date_key = dt.date_key
WHERE dt.full_date = CURRENT_DATE
    AND f.is_active_employee = TRUE
    AND e.is_current = TRUE
GROUP BY d.department_name
ORDER BY dimension;

-- =====================================================
-- 8. EXECUTIVE DASHBOARD QUERIES
-- =====================================================

-- Key HR Metrics Summary (Current Month vs Previous Month)
WITH current_month AS (
    SELECT
        COUNT(*) as headcount,
        COUNT(CASE WHEN f.is_new_hire = TRUE THEN 1 END) as new_hires,
        COUNT(CASE WHEN f.is_termination = TRUE THEN 1 END) as terminations
    FROM fact_employee_snapshot f
    JOIN dim_date dt ON f.date_key = dt.date_key
    WHERE dt.year_number = YEAR(CURRENT_DATE)
        AND dt.month_number = MONTH(CURRENT_DATE)
        AND f.is_active_employee = TRUE
),
previous_month AS (
    SELECT
        COUNT(*) as headcount,
        COUNT(CASE WHEN f.is_new_hire = TRUE THEN 1 END) as new_hires,
        COUNT(CASE WHEN f.is_termination = TRUE THEN 1 END) as terminations
    FROM fact_employee_snapshot f
    JOIN dim_date dt ON f.date_key = dt.date_key
    WHERE dt.year_number = CASE WHEN MONTH(CURRENT_DATE) = 1 THEN YEAR(CURRENT_DATE) - 1 ELSE YEAR(CURRENT_DATE) END
        AND dt.month_number = CASE WHEN MONTH(CURRENT_DATE) = 1 THEN 12 ELSE MONTH(CURRENT_DATE) - 1 END
        AND f.is_active_employee = TRUE
)
SELECT
    'Headcount' as metric,
    cm.headcount as current_value,
    pm.headcount as previous_value,
    cm.headcount - pm.headcount as change_value,
    ROUND((cm.headcount - pm.headcount) * 100.0 / pm.headcount, 1) as change_percentage
FROM current_month cm, previous_month pm

UNION ALL

SELECT
    'New Hires' as metric,
    cm.new_hires as current_value,
    pm.new_hires as previous_value,
    cm.new_hires - pm.new_hires as change_value,
    ROUND((cm.new_hires - pm.new_hires) * 100.0 / NULLIF(pm.new_hires, 0), 1) as change_percentage
FROM current_month cm, previous_month pm

UNION ALL

SELECT
    'Terminations' as metric,
    cm.terminations as current_value,
    pm.terminations as previous_value,
    cm.terminations - pm.terminations as change_value,
    ROUND((cm.terminations - pm.terminations) * 100.0 / NULLIF(pm.terminations, 0), 1) as change_percentage
FROM current_month cm, previous_month pm;

-- Top Performers at Risk (High performers with potential flight risk)
SELECT
    e.employee_id,
    e.full_name,
    d.department_name,
    p.position_title,
    l.office_name,
    perf.overall_rating,
    f.tenure_years,
    f.base_salary,
    CASE
        WHEN f.tenure_years < 2 THEN 'High Risk'
        WHEN f.tenure_years < 5 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END as flight_risk_level,
    'High Performer' as performance_category
FROM fact_employee_snapshot f
JOIN dim_employee e ON f.employee_key = e.employee_key
JOIN dim_department d ON f.department_key = d.department_key
JOIN dim_position p ON f.position_key = p.position_key
JOIN dim_location l ON f.location_key = l.location_key
JOIN fact_performance perf ON f.employee_key = perf.employee_key
JOIN dim_date dt ON f.date_key = dt.date_key
WHERE dt.full_date = CURRENT_DATE
    AND f.is_active_employee = TRUE
    AND e.is_current = TRUE
    AND perf.overall_rating >= 4.0
    AND perf.review_type = 'Annual'
ORDER BY perf.overall_rating DESC, f.tenure_years ASC;

-- =====================================================
-- 9. PREDICTIVE ANALYTICS QUERIES
-- =====================================================

-- Employee Flight Risk Scoring
SELECT
    e.employee_id,
    e.full_name,
    d.department_name,
    f.tenure_years,
    perf.overall_rating,
    f.base_salary,
    -- Risk factors scoring
    CASE WHEN f.tenure_years < 1 THEN 3
         WHEN f.tenure_years < 3 THEN 2
         WHEN f.tenure_years < 5 THEN 1
         ELSE 0 END +
    CASE WHEN perf.overall_rating < 3.0 THEN 3
         WHEN perf.overall_rating < 3.5 THEN 1
         ELSE 0 END +
    CASE WHEN comp_change.change_percentage < 3 OR comp_change.change_percentage IS NULL THEN 2
         ELSE 0 END as flight_risk_score,
    CASE
        WHEN (CASE WHEN f.tenure_years < 1 THEN 3 WHEN f.tenure_years < 3 THEN 2 WHEN f.tenure_years < 5 THEN 1 ELSE 0 END +
              CASE WHEN perf.overall_rating < 3.0 THEN 3 WHEN perf.overall_rating < 3.5 THEN 1 ELSE 0 END +
              CASE WHEN comp_change.change_percentage < 3 OR comp_change.change_percentage IS NULL THEN 2 ELSE 0 END) >= 5 THEN 'High Risk'
        WHEN (CASE WHEN f.tenure_years < 1 THEN 3 WHEN f.tenure_years < 3 THEN 2 WHEN f.tenure_years < 5 THEN 1 ELSE 0 END +
              CASE WHEN perf.overall_rating < 3.0 THEN 3 WHEN perf.overall_rating < 3.5 THEN 1 ELSE 0 END +
              CASE WHEN comp_change.change_percentage < 3 OR comp_change.change_percentage IS NULL THEN 2 ELSE 0 END) >= 3 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END as risk_category
FROM fact_employee_snapshot f
JOIN dim_employee e ON f.employee_key = e.employee_key
JOIN dim_department d ON f.department_key = d.department_key
JOIN fact_performance perf ON f.employee_key = perf.employee_key
LEFT JOIN (
    SELECT
        employee_key,
        change_percentage
    FROM fact_compensation_history ch
    JOIN dim_date dt ON ch.effective_date_key = dt.date_key
    WHERE dt.year_number >= YEAR(CURRENT_DATE) - 1
) comp_change ON f.employee_key = comp_change.employee_key
JOIN dim_date dt ON f.date_key = dt.date_key
WHERE dt.full_date = CURRENT_DATE
    AND f.is_active_employee = TRUE
    AND e.is_current = TRUE
    AND perf.review_type = 'Annual'
ORDER BY flight_risk_score DESC, perf.overall_rating DESC;