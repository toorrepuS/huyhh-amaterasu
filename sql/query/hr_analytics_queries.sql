-- =====================================================
-- HR ANALYTICS QUERIES
-- Trả lời các câu hỏi phân tích nhân sự cụ thể
-- =====================================================

-- =====================================================
-- 1. HEADCOUNT BY DEPARTMENT, ROLE, LOCATION, TIME
-- =====================================================

set search_path = hr_analytics;

-- 1.1 Headcount by Department and Time (Year, Month, Day)
SELECT
    dt.year_number,
    dt.month_number,
    dt.full_date,
    d.department_name,
    d.division,
    COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END) as active_headcount,
    COUNT(CASE WHEN f.is_new_hire = TRUE THEN 1 END) as new_hires,
    COUNT(CASE WHEN f.is_termination = TRUE THEN 1 END) as terminations
FROM fact_employee_snapshot f
JOIN dim_date dt ON f.date_key = dt.date_key
JOIN dim_department d ON f.department_key = d.department_key
WHERE dt.full_date >= '2024-01-01'
GROUP BY dt.year_number, dt.month_number, dt.full_date, d.department_name, d.division
ORDER BY dt.full_date DESC, d.department_name;

-- 1.2 Headcount by Role/Position and Time
SELECT 
    dt.year_number,
    dt.month_number,
    p.position_title,
    p.job_family,
    p.job_level,
    COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END) as headcount,
    AVG(f.base_salary) as avg_salary,
    AVG(f.tenure_years) as avg_tenure
FROM fact_employee_snapshot f
JOIN dim_date dt ON f.date_key = dt.date_key
JOIN dim_position p ON f.position_key = p.position_key
WHERE f.is_active_employee = TRUE
GROUP BY dt.year_number, dt.month_number, p.position_title, p.job_family, p.job_level
ORDER BY dt.year_number DESC, dt.month_number DESC, headcount DESC;

-- 1.3 Headcount by Location and Time
SELECT 
    dt.year_number,
    dt.month_number,
    l.location_name,
    l.city,
    l.country,
    l.region,
    COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END) as headcount,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND p.is_management_role = TRUE THEN 1 END) as management_count,
    ROUND(
        COUNT(CASE WHEN f.is_active_employee = TRUE AND p.is_management_role = TRUE THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END), 0), 2
    ) as management_ratio_percent
FROM fact_employee_snapshot f
JOIN dim_date dt ON f.date_key = dt.date_key
JOIN dim_location l ON f.location_key = l.location_key
JOIN dim_position p ON f.position_key = p.position_key
-- WHERE dt.full_date >= '2024-01-01'
GROUP BY dt.year_number, dt.month_number, l.location_name, l.city, l.country, l.region
ORDER BY dt.year_number DESC, dt.month_number DESC, headcount DESC;

-- 1.4 Multi-dimensional Headcount Analysis
SELECT 
    dt.year_number,
    dt.month_number,
    d.department_name,
    p.job_family,
    p.job_level,
    l.region,
    COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END) as headcount,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND e.gender = 'Female' THEN 1 END) as female_count,
    ROUND(
        COUNT(CASE WHEN f.is_active_employee = TRUE AND e.gender = 'Female' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END), 0), 2
    ) as female_ratio_percent,
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.age_years END) as avg_age,
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.tenure_years END) as avg_tenure
FROM fact_employee_snapshot f
JOIN dim_date dt ON f.date_key = dt.date_key
JOIN dim_employee e ON f.employee_key = e.employee_key AND e.is_current = TRUE
JOIN dim_department d ON f.department_key = d.department_key
JOIN dim_position p ON f.position_key = p.position_key
JOIN dim_location l ON f.location_key = l.location_key
-- WHERE dt.full_date >= '2024-01-01'
GROUP BY dt.year_number, dt.month_number, d.department_name, p.job_family, p.job_level, l.region
HAVING COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END) > 0
ORDER BY dt.year_number DESC, dt.month_number DESC, headcount DESC;

-- =====================================================
-- 2. JOINERS AND LEAVERS PER MONTH
-- =====================================================

-- 2.1 Monthly Joiners and Leavers Summary
SELECT 
    dt.year_number,
    dt.month_number,
    dt.month_name,
    -- Joiners (New Hires)
    COUNT(r.employee_key) as total_joiners,
    AVG(r.time_to_fill_days) as avg_time_to_fill,
    AVG(r.cost_per_hire) as avg_cost_per_hire,
    -- Leavers (Terminations)
    COUNT(t.employee_key) as total_leavers,
    COUNT(CASE WHEN t.termination_type = 'Voluntary' THEN 1 END) as voluntary_leavers,
    COUNT(CASE WHEN t.termination_type = 'Involuntary' THEN 1 END) as involuntary_leavers,
    AVG(t.tenure_at_termination_years) as avg_tenure_at_exit,
    -- Net Change
    COUNT(r.employee_key) - COUNT(t.employee_key) as net_headcount_change
FROM dim_date dt
LEFT JOIN fact_recruitment r ON dt.date_key = r.hire_date_key
LEFT JOIN fact_turnover t ON dt.date_key = t.termination_date_key
-- WHERE dt.year_number >= 2024
GROUP BY dt.year_number, dt.month_number, dt.month_name
ORDER BY dt.year_number DESC, dt.month_number DESC;

-- 2.2 Joiners and Leavers by Department
SELECT 
    dt.year_number,
    dt.month_number,
    d.department_name,
    d.division,
    -- Joiners
    COUNT(r.employee_key) as joiners,
    -- Leavers
    COUNT(t.employee_key) as leavers,
    COUNT(CASE WHEN t.regrettable_loss = TRUE THEN 1 END) as regrettable_losses,
    -- Turnover Rate Calculation
    ROUND(
        COUNT(t.employee_key) * 100.0 / 
        NULLIF(AVG(monthly_headcount.headcount), 0), 2
    ) as monthly_turnover_rate_percent
FROM dim_date dt
LEFT JOIN fact_recruitment r ON dt.date_key = r.hire_date_key
LEFT JOIN fact_turnover t ON dt.date_key = t.termination_date_key
LEFT JOIN dim_department d ON COALESCE(r.department_key, t.department_key) = d.department_key
LEFT JOIN (
    SELECT 
        date_key,
        department_key,
        COUNT(*) as headcount
    FROM fact_employee_snapshot
    WHERE is_active_employee = TRUE
    GROUP BY date_key, department_key
) monthly_headcount ON dt.date_key = monthly_headcount.date_key 
    AND d.department_key = monthly_headcount.department_key
WHERE d.department_name IS NOT NULL
GROUP BY dt.year_number, dt.month_number, d.department_name, d.division
-- ORDER BY dt.year_number DESC, dt.month_number DESC, (joiners + leavers) DESC;

-- 2.3 Joiners and Leavers Trend Analysis
WITH monthly_trends AS (
    SELECT 
        dt.year_number,
        dt.month_number,
        COUNT(r.employee_key) as joiners,
        COUNT(t.employee_key) as leavers,
        COUNT(r.employee_key) - COUNT(t.employee_key) as net_change
    FROM dim_date dt
    LEFT JOIN fact_recruitment r ON dt.date_key = r.hire_date_key
    LEFT JOIN fact_turnover t ON dt.date_key = t.termination_date_key
--     WHERE dt.year_number >= 2023
    GROUP BY dt.year_number, dt.month_number
)
SELECT 
    year_number,
    month_number,
    joiners,
    leavers,
    net_change,
    -- Moving averages
    AVG(joiners) OVER (ORDER BY year_number, month_number ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as joiners_3month_avg,
    AVG(leavers) OVER (ORDER BY year_number, month_number ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as leavers_3month_avg,
    -- Year-over-year comparison
    LAG(joiners, 12) OVER (ORDER BY year_number, month_number) as joiners_same_month_last_year,
    LAG(leavers, 12) OVER (ORDER BY year_number, month_number) as leavers_same_month_last_year
FROM monthly_trends
ORDER BY year_number DESC, month_number DESC;

-- 3.1 Employee Transfers (Department Changes)
SELECT
    dt.year_number,
    dt.month_number,
    dt.full_date as movement_date,
    e.employee_id,
    e.full_name,
    m.movement_type,
    m.movement_reason,
    m.is_voluntary,
    m.approval_level,
    -- Previous position details
    prev_dept.department_name as previous_department,
    prev_dept.division as previous_division,
    prev_pos.position_title as previous_position,
    prev_pos.job_level as previous_job_level,
    prev_pos.job_family as previous_job_family,
    prev_loc.location_name as previous_location,
    prev_loc.city as previous_city,
    prev_loc.country as previous_country,
    -- New position details
    new_dept.department_name as new_department,
    new_dept.division as new_division,
    new_pos.position_title as new_position,
    new_pos.job_level as new_job_level,
    new_pos.job_family as new_job_family,
    new_loc.location_name as new_location,
    new_loc.city as new_city,
    new_loc.country as new_country,
    -- Salary impact
    m.salary_change_amount,
    m.salary_change_percent
--     m.total_compensation_change_amount,
--     m.total_compensation_change_percent
FROM fact_employee_movement m
JOIN dim_date dt ON m.movement_date_key = dt.date_key
JOIN dim_employee e ON m.employee_key = e.employee_key AND e.is_current = TRUE
-- Previous position information
LEFT JOIN dim_department prev_dept ON m.previous_department_key = prev_dept.department_key
LEFT JOIN dim_position prev_pos ON m.previous_position_key = prev_pos.position_key
LEFT JOIN dim_location prev_loc ON m.previous_location_key = prev_loc.location_key
-- New position information
JOIN dim_department new_dept ON m.new_department_key = new_dept.department_key
JOIN dim_position new_pos ON m.new_position_key = new_pos.position_key
JOIN dim_location new_loc ON m.new_location_key = new_loc.location_key
-- WHERE dt.year_number >= 2024
--     AND m.movement_type IN ('Department Transfer', 'Location Transfer')
ORDER BY dt.year_number DESC, dt.month_number DESC, dt.full_date DESC;

-- 3.2 Employee Promotions (Position Level Changes)
SELECT
    dt.year_number,
    dt.month_number,
    dt.full_date as movement_date,
    e.employee_id,
    e.full_name,
    new_dept.department_name,
    new_dept.division,
    m.movement_type,
    m.movement_reason,
    m.is_voluntary,
    m.approval_level,
    -- Position progression details
    prev_pos.position_title as previous_position,
    new_pos.position_title as new_position,
    prev_pos.job_level as previous_level,
    new_pos.job_level as new_level,
    prev_pos.job_family as previous_job_family,
    new_pos.job_family as new_job_family,
    prev_pos.is_management_role as was_management,
    new_pos.is_management_role as is_management,
    -- Salary and compensation impact
    m.salary_change_amount,
    m.salary_change_percent,
--     m.total_compensation_change_amount,
--     m.total_compensation_change_percent,
    -- Career progression indicators
    CASE
        WHEN m.movement_type = 'Promotion' AND m.salary_change_percent > 15 THEN 'Significant Promotion'
        WHEN m.movement_type = 'Promotion' AND m.salary_change_percent > 5 THEN 'Standard Promotion'
        WHEN m.movement_type = 'Lateral Transfer' AND prev_pos.job_family != new_pos.job_family THEN 'Cross-Functional Move'
        WHEN m.movement_type = 'Lateral Transfer' THEN 'Same-Function Lateral'
        ELSE m.movement_type
    END as promotion_category,
    -- Management progression
    CASE
        WHEN NOT prev_pos.is_management_role AND new_pos.is_management_role THEN 'New Manager'
        WHEN prev_pos.is_management_role AND new_pos.is_management_role THEN 'Management Progression'
        ELSE 'Individual Contributor'
    END as management_track
FROM fact_employee_movement m
JOIN dim_date dt ON m.movement_date_key = dt.date_key
JOIN dim_employee e ON m.employee_key = e.employee_key AND e.is_current = TRUE
-- Previous position information
LEFT JOIN dim_position prev_pos ON m.previous_position_key = prev_pos.position_key
-- New position information
JOIN dim_department new_dept ON m.new_department_key = new_dept.department_key
JOIN dim_position new_pos ON m.new_position_key = new_pos.position_key
-- WHERE dt.year_number >= 2024
--     AND m.movement_type IN ('Promotion', 'Lateral Transfer', 'Demotion')
ORDER BY dt.year_number DESC, dt.month_number DESC, m.salary_change_percent DESC;

-- 3.3 Internal Mobility Summary
SELECT
    dt.year_number,
    dt.month_number,
    d.department_name,
    d.division,
    -- Movement type breakdown
    COUNT(CASE WHEN m.movement_type = 'Promotion' THEN 1 END) as promotions,
    COUNT(CASE WHEN m.movement_type = 'Department Transfer' THEN 1 END) as department_transfers,
    COUNT(CASE WHEN m.movement_type = 'Location Transfer' THEN 1 END) as location_transfers,
    COUNT(CASE WHEN m.movement_type = 'Lateral Transfer' THEN 1 END) as lateral_moves,
    COUNT(CASE WHEN m.movement_type = 'Manager Change' THEN 1 END) as manager_changes,
    COUNT(CASE WHEN m.movement_type = 'Demotion' THEN 1 END) as demotions,
    COUNT(*) as total_movements,
    -- Voluntary vs involuntary
    COUNT(CASE WHEN m.is_voluntary = TRUE THEN 1 END) as voluntary_movements,
    COUNT(CASE WHEN m.is_voluntary = FALSE THEN 1 END) as involuntary_movements,
    ROUND(COUNT(CASE WHEN m.is_voluntary = TRUE THEN 1 END) * 100.0 / COUNT(*), 2) as voluntary_movement_percent,
    -- Salary impact analysis
    AVG(CASE WHEN m.movement_type = 'Promotion' THEN m.salary_change_percent END) as avg_promotion_salary_increase,
    AVG(CASE WHEN m.movement_type = 'Department Transfer' THEN m.salary_change_percent END) as avg_transfer_salary_change,
    AVG(CASE WHEN m.movement_type = 'Lateral Transfer' THEN m.salary_change_percent END) as avg_lateral_salary_change,
    -- Movement reasons
    COUNT(CASE WHEN m.movement_reason = 'Career Development' THEN 1 END) as career_development_moves,
    COUNT(CASE WHEN m.movement_reason = 'Business Need' THEN 1 END) as business_need_moves,
    COUNT(CASE WHEN m.movement_reason = 'Employee Request' THEN 1 END) as employee_request_moves,
    COUNT(CASE WHEN m.movement_reason = 'Performance' THEN 1 END) as performance_related_moves,
    -- Gender diversity in movements
    COUNT(CASE WHEN m.movement_type = 'Promotion' AND e.gender = 'Female' THEN 1 END) as female_promotions,
    ROUND(
        COUNT(CASE WHEN m.movement_type = 'Promotion' AND e.gender = 'Female' THEN 1 END) * 100.0 /
        NULLIF(COUNT(CASE WHEN m.movement_type = 'Promotion' THEN 1 END), 0), 2
    ) as female_promotion_percent
FROM fact_employee_movement m
JOIN dim_date dt ON m.movement_date_key = dt.date_key
JOIN dim_employee e ON m.employee_key = e.employee_key AND e.is_current = TRUE
JOIN dim_department d ON m.new_department_key = d.department_key
-- WHERE dt.year_number >= 2024
GROUP BY dt.year_number, dt.month_number, d.department_name, d.division
HAVING COUNT(*) > 0
ORDER BY dt.year_number DESC, dt.month_number DESC, total_movements DESC;

-- 3.5 Movement Approval Analysis
SELECT
    dt.year_number,
    dt.quarter_number,
    m.approval_level,
    m.movement_type,
    COUNT(*) as movement_count,
    AVG(m.salary_change_percent) as avg_salary_change_percent,
    -- Time to approval (if we had approval date)
    COUNT(CASE WHEN m.is_voluntary = TRUE THEN 1 END) as voluntary_count,
    COUNT(CASE WHEN m.is_voluntary = FALSE THEN 1 END) as involuntary_count,
    ROUND(COUNT(CASE WHEN m.is_voluntary = TRUE THEN 1 END) * 100.0 / COUNT(*), 2) as voluntary_percent,
    -- Movement reasons breakdown
    COUNT(CASE WHEN m.movement_reason = 'Career Development' THEN 1 END) as career_development,
    COUNT(CASE WHEN m.movement_reason = 'Business Need' THEN 1 END) as business_need,
    COUNT(CASE WHEN m.movement_reason = 'Employee Request' THEN 1 END) as employee_request,
    COUNT(CASE WHEN m.movement_reason = 'Performance' THEN 1 END) as performance_related,
    COUNT(CASE WHEN m.movement_reason = 'Succession Planning' THEN 1 END) as succession_planning
FROM fact_employee_movement m
JOIN dim_date dt ON m.movement_date_key = dt.date_key
-- WHERE dt.year_number >= 2024
GROUP BY dt.year_number, dt.quarter_number, m.approval_level, m.movement_type
ORDER BY dt.year_number DESC, dt.quarter_number DESC, movement_count DESC;

-- =====================================================
-- 4. EMPLOYEE PERFORMANCE OVER TIME
-- =====================================================

-- 4.1 Performance Trends by Month, Quarter, Year
SELECT
    dt.year_number,
    dt.quarter_number,
    dt.month_number,
    COUNT(*) as total_reviews,
    AVG(p.overall_rating) as avg_overall_rating,
    AVG(p.goals_achievement_score) as avg_goals_achievement,
    AVG(p.competency_score) as avg_competency_score,
    -- Performance distribution
    COUNT(CASE WHEN p.overall_rating >= 4.5 THEN 1 END) as excellent_performers,
    COUNT(CASE WHEN p.overall_rating >= 3.5 AND p.overall_rating < 4.5 THEN 1 END) as good_performers,
    COUNT(CASE WHEN p.overall_rating >= 2.5 AND p.overall_rating < 3.5 THEN 1 END) as average_performers,
    COUNT(CASE WHEN p.overall_rating < 2.5 THEN 1 END) as below_average_performers,
    -- Performance percentages
    ROUND(COUNT(CASE WHEN p.overall_rating >= 4.5 THEN 1 END) * 100.0 / COUNT(*), 2) as excellent_percent,
    ROUND(COUNT(CASE WHEN p.overall_rating < 2.5 THEN 1 END) * 100.0 / COUNT(*), 2) as below_average_percent
FROM fact_performance p
JOIN dim_date dt ON p.review_date_key = dt.date_key
-- WHERE dt.year_number >= 2023
GROUP BY dt.year_number, dt.quarter_number, dt.month_number
ORDER BY dt.year_number DESC, dt.quarter_number DESC, dt.month_number DESC;

-- 4.2 Performance by Department and Time
SELECT
    dt.year_number,
    dt.quarter_number,
    d.department_name,
    d.division,
    COUNT(*) as reviews_completed,
    AVG(p.overall_rating) as avg_rating,
    STDDEV(p.overall_rating) as rating_std_dev,
    -- Top and bottom performers
    COUNT(CASE WHEN p.overall_rating >= 4.5 THEN 1 END) as top_performers,
    COUNT(CASE WHEN p.overall_rating < 2.5 THEN 1 END) as underperformers,
    -- Potential and promotion readiness
    COUNT(CASE WHEN p.potential_rating = 'High' THEN 1 END) as high_potential_count,
    COUNT(CASE WHEN p.promotion_readiness = 'Ready' THEN 1 END) as promotion_ready_count
FROM fact_performance p
JOIN dim_date dt ON p.review_date_key = dt.date_key
JOIN dim_department d ON p.department_key = d.department_key
-- WHERE dt.year_number >= 2023
GROUP BY dt.year_number, dt.quarter_number, d.department_name, d.division
ORDER BY dt.year_number DESC, dt.quarter_number DESC, avg_rating DESC;

-- 4.3 Individual Performance Tracking Over Time
SELECT
    e.employee_id,
    e.full_name,
    d.department_name,
    dt.year_number,
    dt.quarter_number,
    p.review_type,
    p.overall_rating,
    p.goals_achievement_score,
    p.potential_rating,
    p.promotion_readiness,
    -- Performance trend
    LAG(p.overall_rating) OVER (PARTITION BY e.employee_id ORDER BY dt.full_date) as previous_rating,
    p.overall_rating - LAG(p.overall_rating) OVER (PARTITION BY e.employee_id ORDER BY dt.full_date) as rating_change,
    -- Ranking within department
    RANK() OVER (PARTITION BY d.department_key, dt.year_number, dt.quarter_number ORDER BY p.overall_rating DESC) as dept_performance_rank
FROM fact_performance p
JOIN dim_employee e ON p.employee_key = e.employee_key AND e.is_current = TRUE
JOIN dim_date dt ON p.review_date_key = dt.date_key
JOIN dim_department d ON d.department_key = d.department_key
-- WHERE dt.year_number >= 2023
ORDER BY e.employee_id, dt.year_number DESC, dt.quarter_number DESC;

-- 4.4 Performance Improvement Analysis
WITH performance_trends AS (
    SELECT
        e.employee_id,
        e.full_name,
        dt.year_number,
        dt.quarter_number,
        p.overall_rating,
        LAG(p.overall_rating, 1) OVER (PARTITION BY e.employee_id ORDER BY dt.year_number, dt.quarter_number) as prev_rating_1q,
        LAG(p.overall_rating, 4) OVER (PARTITION BY e.employee_id ORDER BY dt.year_number, dt.quarter_number) as prev_rating_1y,
        d.department_name
    FROM fact_performance p
    JOIN dim_employee e ON p.employee_key = e.employee_key AND e.is_current = TRUE
    JOIN dim_date dt ON p.review_date_key = dt.date_key
    JOIN dim_department d ON d.department_key = d.department_key
    WHERE dt.year_number >= 2022
)
SELECT
    year_number,
    quarter_number,
    department_name,
    COUNT(*) as total_employees,
    -- Quarter-over-quarter improvement
    COUNT(CASE WHEN overall_rating > prev_rating_1q THEN 1 END) as improved_qoq,
    COUNT(CASE WHEN overall_rating < prev_rating_1q THEN 1 END) as declined_qoq,
    ROUND(COUNT(CASE WHEN overall_rating > prev_rating_1q THEN 1 END) * 100.0 / COUNT(*), 2) as improvement_rate_qoq,
    -- Year-over-year improvement
    COUNT(CASE WHEN overall_rating > prev_rating_1y THEN 1 END) as improved_yoy,
    COUNT(CASE WHEN overall_rating < prev_rating_1y THEN 1 END) as declined_yoy,
    ROUND(COUNT(CASE WHEN overall_rating > prev_rating_1y THEN 1 END) * 100.0 /
          NULLIF(COUNT(CASE WHEN prev_rating_1y IS NOT NULL THEN 1 END), 0), 2) as improvement_rate_yoy
FROM performance_trends
WHERE year_number >= 2024
GROUP BY year_number, quarter_number, department_name
ORDER BY year_number DESC, quarter_number DESC, improvement_rate_qoq DESC;

-- =====================================================
-- 5. BUSINESS ACHIEVEMENTS OF DISTRIBUTED CHANNELS OVER TIME - UPDATED
-- =====================================================
-- UPDATED: Now uses the dedicated fact_channel_achievement table instead of
-- deriving business metrics from employee data. This provides:
-- - Direct access to actual business performance metrics (sales, premiums, policies)
-- - Target vs achievement analysis with calculated achievement rates
-- - Channel-specific KPIs (conversion rates, customer acquisition, digital metrics)
-- - Product-level performance breakdown by channel
-- - Comprehensive business health indicators
-- =====================================================

-- 5.1 Distributed Channels Performance by Month, Quarter, Year
SELECT
    dt.year_number,
    dt.quarter_number,
    dt.month_number,
    dt.month_name,
    c.channel_name,
    c.channel_type,
    c.channel_category,
    c.region,
    c.territory,
    ca.aggregation_level,
    -- Sales Performance
    SUM(ca.total_sales_amount) as total_sales_amount,
    SUM(ca.total_premium_amount) as total_premium_amount,
    SUM(ca.number_of_policies_sold) as total_policies_sold,
    SUM(ca.commission_earned) as total_commission_earned,
    -- Target Achievement Analysis
    AVG(ca.sales_achievement_rate) as avg_sales_achievement_rate,
    AVG(ca.premium_achievement_rate) as avg_premium_achievement_rate,
    AVG(ca.policy_achievement_rate) as avg_policy_achievement_rate,
    COUNT(CASE WHEN ca.is_target_achieved = TRUE THEN 1 END) as periods_target_achieved,
    COUNT(*) as total_periods,
    ROUND(COUNT(CASE WHEN ca.is_target_achieved = TRUE THEN 1 END) * 100.0 / COUNT(*), 2) as target_achievement_percentage,
    -- Customer Metrics
    SUM(ca.number_of_new_customers) as total_new_customers,
    AVG(ca.customer_acquisition_cost) as avg_customer_acquisition_cost,
    AVG(ca.customer_satisfaction_score) as avg_customer_satisfaction,
    AVG(ca.customer_retention_rate) as avg_customer_retention_rate,
    -- Operational Efficiency
    AVG(ca.conversion_rate) as avg_conversion_rate,
    AVG(ca.average_policy_value) as avg_policy_value,
--     AVG(ca.claims_ratio) as avg_claims_ratio,
    -- Performance Tier Distribution
    COUNT(CASE WHEN ca.performance_tier = 'Excellent' THEN 1 END) as excellent_periods,
    COUNT(CASE WHEN ca.performance_tier = 'Good' THEN 1 END) as good_periods,
    COUNT(CASE WHEN ca.performance_tier = 'Fair' THEN 1 END) as fair_periods,
    COUNT(CASE WHEN ca.performance_tier = 'Below Target' THEN 1 END) as below_target_periods,
    -- Digital Metrics (for applicable channels)
    AVG(ca.digital_conversion_rate) as avg_digital_conversion_rate,
    SUM(ca.website_visits) as total_website_visits,
    SUM(ca.online_quote_requests) as total_online_quotes,
    SUM(ca.mobile_app_downloads) as total_app_downloads
FROM fact_channel_achievement ca
JOIN dim_date dt ON ca.date_key = dt.date_key
JOIN dim_channel c ON ca.channel_key = c.channel_key
WHERE dt.year_number >= 2024
    AND ca.aggregation_level = 'MONTHLY'
GROUP BY dt.year_number, dt.quarter_number, dt.month_number, dt.month_name,
         c.channel_name, c.channel_type, c.channel_category, c.region, c.territory, ca.aggregation_level
ORDER BY dt.year_number DESC, dt.quarter_number DESC, dt.month_number DESC, total_sales_amount DESC;

-- 5.2 Distributed Channels - Key Business Metrics Trends (Using fact_channel_achievement)
WITH channel_trends AS (
    SELECT
        dt.year_number,
        dt.quarter_number,
        dt.month_number,
        c.channel_name,
        c.channel_type,
        c.channel_category,
        c.region,
        -- Core business metrics
        SUM(ca.total_sales_amount) as total_sales,
        SUM(ca.total_premium_amount) as total_premium,
        SUM(ca.number_of_policies_sold) as total_policies,
        SUM(ca.commission_earned) as total_commission,
        -- Achievement rates
        AVG(ca.sales_achievement_rate) as avg_sales_achievement_rate,
        AVG(ca.premium_achievement_rate) as avg_premium_achievement_rate,
        AVG(ca.policy_achievement_rate) as avg_policy_achievement_rate,
        -- Customer metrics
        SUM(ca.number_of_new_customers) as new_customers,
        AVG(ca.customer_acquisition_cost) as avg_acquisition_cost,
        AVG(ca.customer_satisfaction_score) as avg_satisfaction,
        AVG(ca.customer_retention_rate) as avg_retention_rate,
        -- Operational efficiency
        AVG(ca.conversion_rate) as avg_conversion_rate,
        AVG(ca.average_policy_value) as avg_policy_value,
--         AVG(ca.claims_ratio) as avg_claims_ratio,
        -- Digital performance (where applicable)
        AVG(ca.digital_conversion_rate) as avg_digital_conversion,
        SUM(ca.website_visits) as total_website_visits,
        SUM(ca.online_quote_requests) as total_online_quotes,
        -- Performance indicators
        COUNT(CASE WHEN ca.is_target_achieved = TRUE THEN 1 END) as target_achieved_count,
        COUNT(*) as total_periods,
        AVG(CASE WHEN ca.performance_tier = 'Excellent' THEN 4
                 WHEN ca.performance_tier = 'Good' THEN 3
                 WHEN ca.performance_tier = 'Fair' THEN 2
                 WHEN ca.performance_tier = 'Below Target' THEN 1
                 ELSE 0 END) as avg_performance_tier_score
    FROM fact_channel_achievement ca
    JOIN dim_date dt ON ca.date_key = dt.date_key
    JOIN dim_channel c ON ca.channel_key = c.channel_key
    WHERE dt.year_number >= 2024
        AND ca.aggregation_level = 'MONTHLY'
    GROUP BY dt.year_number, dt.quarter_number, dt.month_number,
             c.channel_name, c.channel_type, c.channel_category, c.region
)
SELECT
    year_number,
    quarter_number,
    month_number,
    channel_name,
    channel_type,
    channel_category,
    region,
    total_sales,
    total_premium,
    total_policies,
    total_commission,
    avg_sales_achievement_rate,
    avg_premium_achievement_rate,
    avg_policy_achievement_rate,
    new_customers,
    avg_acquisition_cost,
    avg_satisfaction,
    avg_retention_rate,
    avg_conversion_rate,
    avg_policy_value,
--     avg_claims_ratio,
    avg_digital_conversion,
    target_achieved_count,
    total_periods,
    ROUND(target_achieved_count * 100.0 / total_periods, 2) as target_achievement_percentage,
    avg_performance_tier_score,
    -- Trend analysis using LAG functions
    LAG(total_sales) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number, month_number) as prev_sales,
    LAG(avg_sales_achievement_rate) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number, month_number) as prev_achievement_rate,
    LAG(avg_conversion_rate) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number, month_number) as prev_conversion_rate,
    LAG(new_customers) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number, month_number) as prev_new_customers,
    -- Performance trend indicators
    CASE
        WHEN avg_sales_achievement_rate > LAG(avg_sales_achievement_rate) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number, month_number)
        THEN 'Improving'
        WHEN avg_sales_achievement_rate < LAG(avg_sales_achievement_rate) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number, month_number)
        THEN 'Declining'
        ELSE 'Stable'
    END as achievement_trend,
    -- Sales growth calculation
    ROUND(
        (total_sales - LAG(total_sales) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number, month_number)) * 100.0 /
        NULLIF(LAG(total_sales) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number, month_number), 0), 2
    ) as sales_growth_percent,
    -- Customer acquisition trend
    ROUND(
        (new_customers - LAG(new_customers) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number, month_number)) * 100.0 /
        NULLIF(LAG(new_customers) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number, month_number), 0), 2
    ) as customer_growth_percent
FROM channel_trends
ORDER BY year_number DESC, quarter_number DESC, month_number DESC, total_sales DESC;

-- 5.3 Distributed Channels - Product Performance Analysis (Using fact_channel_achievement)
SELECT
    dt.year_number,
    dt.quarter_number,
    c.channel_name,
    c.channel_type,
    c.channel_category,
    p.product_name,
    p.product_category,
    p.product_type,
    -- Sales performance by product
    SUM(ca.total_sales_amount) as total_sales_amount,
    SUM(ca.total_premium_amount) as total_premium_amount,
    SUM(ca.number_of_policies_sold) as total_policies_sold,
    SUM(ca.commission_earned) as total_commission_earned,
    -- Product-specific metrics
    AVG(ca.average_policy_value) as avg_policy_value,
    AVG(ca.conversion_rate) as avg_conversion_rate,
    AVG(ca.claims_ratio) as avg_claims_ratio,
    -- Customer metrics by product
    SUM(ca.number_of_new_customers) as new_customers,
    AVG(ca.customer_acquisition_cost) as avg_acquisition_cost,
    AVG(ca.customer_satisfaction_score) as avg_satisfaction,
    AVG(ca.customer_retention_rate) as avg_retention_rate,
    -- Target achievement by product
    AVG(ca.sales_achievement_rate) as avg_sales_achievement_rate,
    AVG(ca.premium_achievement_rate) as avg_premium_achievement_rate,
    AVG(ca.policy_achievement_rate) as avg_policy_achievement_rate,
    COUNT(CASE WHEN ca.is_target_achieved = TRUE THEN 1 END) as periods_target_achieved,
    COUNT(*) as total_periods,
    ROUND(COUNT(CASE WHEN ca.is_target_achieved = TRUE THEN 1 END) * 100.0 / COUNT(*), 2) as target_achievement_percentage,
    -- Performance tier distribution
    COUNT(CASE WHEN ca.performance_tier = 'Excellent' THEN 1 END) as excellent_periods,
    COUNT(CASE WHEN ca.performance_tier = 'Good' THEN 1 END) as good_periods,
    COUNT(CASE WHEN ca.performance_tier = 'Fair' THEN 1 END) as fair_periods,
    COUNT(CASE WHEN ca.performance_tier = 'Below Target' THEN 1 END) as below_target_periods,
    -- Market share and competitive metrics
    AVG(ca.market_share_percent) as avg_market_share,
    AVG(ca.competitive_win_rate) as avg_competitive_win_rate,
    -- Digital engagement (for applicable products/channels)
    AVG(ca.digital_conversion_rate) as avg_digital_conversion_rate,
    SUM(ca.online_quote_requests) as total_online_quotes,
    -- Product profitability indicators
    ROUND(SUM(ca.commission_earned) / NULLIF(SUM(ca.total_sales_amount), 0) * 100, 2) as commission_rate_percent,
    ROUND(SUM(ca.total_premium_amount) / NULLIF(SUM(ca.number_of_policies_sold), 0), 2) as avg_premium_per_policy
FROM fact_channel_achievement ca
JOIN dim_date dt ON ca.date_key = dt.date_key
JOIN dim_channel c ON ca.channel_key = c.channel_key
JOIN dim_product p ON ca.product_key = p.product_key
WHERE dt.year_number >= 2024
    AND ca.aggregation_level = 'QUARTERLY'
GROUP BY dt.year_number, dt.quarter_number, c.channel_name, c.channel_type, c.channel_category,
         p.product_name, p.product_category, p.product_type
HAVING SUM(ca.total_sales_amount) > 0
ORDER BY dt.year_number DESC, dt.quarter_number DESC, total_sales_amount DESC;

-- 5.4 Distributed Channels - Quarterly Business Review Summary (Using fact_channel_achievement)
WITH quarterly_summary AS (
    SELECT
        dt.year_number,
        dt.quarter_number,
        c.channel_name,
        c.channel_type,
        c.channel_category,
        c.region,
        -- Core business metrics
        SUM(ca.total_sales_amount) as quarterly_sales,
        SUM(ca.total_premium_amount) as quarterly_premium,
        SUM(ca.number_of_policies_sold) as quarterly_policies,
        SUM(ca.commission_earned) as quarterly_commission,
        -- Customer metrics
        SUM(ca.number_of_new_customers) as quarterly_new_customers,
        AVG(ca.customer_acquisition_cost) as avg_acquisition_cost,
        AVG(ca.customer_satisfaction_score) as avg_satisfaction,
        AVG(ca.customer_retention_rate) as avg_retention_rate,
        -- Performance metrics
        AVG(ca.sales_achievement_rate) as avg_sales_achievement_rate,
        AVG(ca.premium_achievement_rate) as avg_premium_achievement_rate,
        AVG(ca.policy_achievement_rate) as avg_policy_achievement_rate,
        COUNT(CASE WHEN ca.is_target_achieved = TRUE THEN 1 END) as months_target_achieved,
        COUNT(*) as total_months,
        -- Operational efficiency
        AVG(ca.conversion_rate) as avg_conversion_rate,
        AVG(ca.average_policy_value) as avg_policy_value,
        AVG(ca.claims_ratio) as avg_claims_ratio,
        -- Digital performance
        AVG(ca.digital_conversion_rate) as avg_digital_conversion_rate,
        SUM(ca.website_visits) as quarterly_website_visits,
        SUM(ca.online_quote_requests) as quarterly_online_quotes,
        SUM(ca.mobile_app_downloads) as quarterly_app_downloads,
        -- Market position
        AVG(ca.market_share_percent) as avg_market_share,
        AVG(ca.competitive_win_rate) as avg_competitive_win_rate
    FROM fact_channel_achievement ca
    JOIN dim_date dt ON ca.date_key = dt.date_key
    JOIN dim_channel c ON ca.channel_key = c.channel_key
    WHERE dt.year_number >= 2024
        AND ca.aggregation_level = 'MONTHLY'
    GROUP BY dt.year_number, dt.quarter_number, c.channel_name, c.channel_type, c.channel_category, c.region
)
SELECT
    year_number,
    quarter_number,
    channel_name,
    channel_type,
    channel_category,
    region,
    quarterly_sales,
    quarterly_premium,
    quarterly_policies,
    quarterly_commission,
    quarterly_new_customers,
    avg_acquisition_cost,
    avg_satisfaction,
    avg_retention_rate,
    avg_sales_achievement_rate,
    avg_premium_achievement_rate,
    avg_policy_achievement_rate,
    months_target_achieved,
    total_months,
    ROUND(months_target_achieved * 100.0 / total_months, 2) as target_achievement_percentage,
    avg_conversion_rate,
    avg_policy_value,
    avg_claims_ratio,
    avg_digital_conversion_rate,
    quarterly_website_visits,
    quarterly_online_quotes,
    quarterly_app_downloads,
    avg_market_share,
    avg_competitive_win_rate,
    -- Year-over-year comparison
    LAG(quarterly_sales, 4) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number) as sales_same_quarter_last_year,
    LAG(quarterly_new_customers, 4) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number) as customers_same_quarter_last_year,
    LAG(avg_sales_achievement_rate, 4) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number) as achievement_rate_same_quarter_last_year,
    -- Growth calculations
    ROUND(
        (quarterly_sales - LAG(quarterly_sales, 4) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number)) * 100.0 /
        NULLIF(LAG(quarterly_sales, 4) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number), 0), 2
    ) as sales_growth_yoy_percent,
    ROUND(
        (quarterly_new_customers - LAG(quarterly_new_customers, 4) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number)) * 100.0 /
        NULLIF(LAG(quarterly_new_customers, 4) OVER (PARTITION BY channel_name ORDER BY year_number, quarter_number), 0), 2
    ) as customer_growth_yoy_percent,
    -- Performance indicators
    CASE
        WHEN avg_sales_achievement_rate >= 100 THEN 'Exceeding Target'
        WHEN avg_sales_achievement_rate >= 90 THEN 'Meeting Target'
        WHEN avg_sales_achievement_rate >= 75 THEN 'Below Target'
        ELSE 'Significantly Below Target'
    END as performance_status
FROM quarterly_summary
ORDER BY year_number DESC, quarter_number DESC, quarterly_sales DESC;

-- 5.5 Distributed Channels - Performance Ranking and Comparison Analysis
WITH channel_rankings AS (
    SELECT
        dt.year_number,
        dt.month_number,
        c.channel_name,
        c.channel_type,
        c.channel_category,
        c.region,
        -- Core metrics
        SUM(ca.total_sales_amount) as monthly_sales,
        SUM(ca.total_premium_amount) as monthly_premium,
        SUM(ca.number_of_policies_sold) as monthly_policies,
        AVG(ca.sales_achievement_rate) as achievement_rate,
        AVG(ca.customer_satisfaction_score) as satisfaction_score,
        AVG(ca.conversion_rate) as conversion_rate,
        -- Rankings within channel type
        ROW_NUMBER() OVER (PARTITION BY dt.year_number, dt.month_number, c.channel_type ORDER BY SUM(ca.total_sales_amount) DESC) as sales_rank_in_type,
        ROW_NUMBER() OVER (PARTITION BY dt.year_number, dt.month_number, c.channel_type ORDER BY AVG(ca.sales_achievement_rate) DESC) as achievement_rank_in_type,
        ROW_NUMBER() OVER (PARTITION BY dt.year_number, dt.month_number, c.channel_type ORDER BY AVG(ca.customer_satisfaction_score) DESC) as satisfaction_rank_in_type,
        -- Overall rankings
        ROW_NUMBER() OVER (PARTITION BY dt.year_number, dt.month_number ORDER BY SUM(ca.total_sales_amount) DESC) as overall_sales_rank,
        ROW_NUMBER() OVER (PARTITION BY dt.year_number, dt.month_number ORDER BY AVG(ca.sales_achievement_rate) DESC) as overall_achievement_rank,
        -- Performance percentiles
        PERCENT_RANK() OVER (PARTITION BY dt.year_number, dt.month_number ORDER BY SUM(ca.total_sales_amount)) as sales_percentile,
        PERCENT_RANK() OVER (PARTITION BY dt.year_number, dt.month_number ORDER BY AVG(ca.sales_achievement_rate)) as achievement_percentile,
        -- Channel type totals for market share calculation
        SUM(SUM(ca.total_sales_amount)) OVER (PARTITION BY dt.year_number, dt.month_number, c.channel_type) as channel_type_total_sales,
        SUM(SUM(ca.total_sales_amount)) OVER (PARTITION BY dt.year_number, dt.month_number) as overall_total_sales
    FROM fact_channel_achievement ca
    JOIN dim_date dt ON ca.date_key = dt.date_key
    JOIN dim_channel c ON ca.channel_key = c.channel_key
    WHERE dt.year_number >= 2024
        AND ca.aggregation_level = 'MONTHLY'
    GROUP BY dt.year_number, dt.month_number, c.channel_name, c.channel_type, c.channel_category, c.region
)
SELECT
    year_number,
    month_number,
    channel_name,
    channel_type,
    channel_category,
    region,
    monthly_sales,
    monthly_premium,
    monthly_policies,
    achievement_rate,
    satisfaction_score,
    conversion_rate,
    -- Rankings
    sales_rank_in_type,
    achievement_rank_in_type,
    satisfaction_rank_in_type,
    overall_sales_rank,
    overall_achievement_rank,
    -- Performance percentiles (0-1 scale, 1 = best)
    ROUND(sales_percentile * 100, 1) as sales_percentile_score,
    ROUND(achievement_percentile * 100, 1) as achievement_percentile_score,
    -- Market share calculations
    ROUND(monthly_sales * 100.0 / channel_type_total_sales, 2) as market_share_within_channel_type,
    ROUND(monthly_sales * 100.0 / overall_total_sales, 2) as overall_market_share,
    -- Performance tier classification
    CASE
        WHEN sales_percentile >= 0.9 AND achievement_percentile >= 0.9 THEN 'Top Performer'
        WHEN sales_percentile >= 0.75 AND achievement_percentile >= 0.75 THEN 'High Performer'
        WHEN sales_percentile >= 0.5 AND achievement_percentile >= 0.5 THEN 'Average Performer'
        WHEN sales_percentile >= 0.25 OR achievement_percentile >= 0.25 THEN 'Below Average'
        ELSE 'Underperformer'
    END as performance_classification,
    -- Improvement opportunities
    CASE
        WHEN sales_rank_in_type = 1 AND achievement_rank_in_type > 3 THEN 'Focus on Target Achievement'
        WHEN achievement_rank_in_type = 1 AND sales_rank_in_type > 3 THEN 'Scale Up Sales Volume'
        WHEN satisfaction_rank_in_type > 5 THEN 'Improve Customer Experience'
        WHEN sales_percentile < 0.25 THEN 'Comprehensive Performance Review Needed'
        ELSE 'Maintain Current Performance'
    END as improvement_focus
FROM channel_rankings
WHERE monthly_sales > 0
ORDER BY year_number DESC, month_number DESC, overall_sales_rank;

-- =====================================================
-- ADDITIONAL ENHANCED ANALYTICS QUERIES
-- =====================================================

-- =====================================================
-- 6. ENHANCED HEADCOUNT ANALYTICS WITH DRILL-DOWN CAPABILITIES
-- =====================================================

-- 6.1 Real-time Headcount Dashboard (Current Day)
SELECT
    CURRENT_DATE as report_date,
    d.department_name,
    d.division,
    p.job_family,
    p.job_level,
    l.region,
    l.country,
    COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END) as current_headcount,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND e.gender = 'Female' THEN 1 END) as female_count,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND p.is_management_role = TRUE THEN 1 END) as management_count,
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.base_salary END) as avg_base_salary,
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.tenure_years END) as avg_tenure_years,
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.age_years END) as avg_age,
    -- Diversity metrics
    ROUND(
        COUNT(CASE WHEN f.is_active_employee = TRUE AND e.gender = 'Female' THEN 1 END) * 100.0 /
        NULLIF(COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END), 0), 2
    ) as female_percentage,
    -- Management ratio
    ROUND(
        COUNT(CASE WHEN f.is_active_employee = TRUE AND p.is_management_role = TRUE THEN 1 END) * 100.0 /
        NULLIF(COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END), 0), 2
    ) as management_percentage
FROM fact_employee_snapshot f
JOIN dim_date dt ON f.date_key = dt.date_key
JOIN dim_employee e ON f.employee_key = e.employee_key AND e.is_current = TRUE
JOIN dim_department d ON f.department_key = d.department_key
JOIN dim_position p ON f.position_key = p.position_key
JOIN dim_location l ON f.location_key = l.location_key
WHERE dt.full_date = CURRENT_DATE
GROUP BY d.department_name, d.division, p.job_family, p.job_level, l.region, l.country
HAVING COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END) > 0
ORDER BY current_headcount DESC;

-- 6.2 Headcount Trend Analysis with Forecasting Data Points
WITH monthly_headcount AS (
    SELECT
        dt.year_number,
        dt.month_number,
        dt.full_date,
        d.department_name,
        COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END) as headcount,
        COUNT(CASE WHEN f.is_new_hire = TRUE THEN 1 END) as new_hires,
        COUNT(CASE WHEN f.is_termination = TRUE THEN 1 END) as terminations
    FROM fact_employee_snapshot f
    JOIN dim_date dt ON f.date_key = dt.date_key
    JOIN dim_department d ON f.department_key = d.department_key
    WHERE dt.day_of_month = 1  -- First day of each month for consistency
        AND dt.year_number >= 2023
    GROUP BY dt.year_number, dt.month_number, dt.full_date, d.department_name
)
SELECT
    year_number,
    month_number,
    department_name,
    headcount,
    new_hires,
    terminations,
    headcount - LAG(headcount) OVER (PARTITION BY department_name ORDER BY year_number, month_number) as net_change,
    -- 3-month moving average
    AVG(headcount) OVER (
        PARTITION BY department_name
        ORDER BY year_number, month_number
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as headcount_3month_avg,
    -- Year-over-year growth
    LAG(headcount, 12) OVER (PARTITION BY department_name ORDER BY year_number, month_number) as headcount_same_month_last_year,
    ROUND(
        (headcount - LAG(headcount, 12) OVER (PARTITION BY department_name ORDER BY year_number, month_number)) * 100.0 /
        NULLIF(LAG(headcount, 12) OVER (PARTITION BY department_name ORDER BY year_number, month_number), 0), 2
    ) as yoy_growth_percent,
    -- Growth rate calculation for forecasting
    ROUND(
        (headcount - LAG(headcount) OVER (PARTITION BY department_name ORDER BY year_number, month_number)) * 100.0 /
        NULLIF(LAG(headcount) OVER (PARTITION BY department_name ORDER BY year_number, month_number), 0), 2
    ) as monthly_growth_rate
FROM monthly_headcount
ORDER BY department_name, year_number DESC, month_number DESC;

-- =====================================================
-- 7. ADVANCED JOINERS AND LEAVERS ANALYTICS
-- =====================================================

-- 7.1 Comprehensive Turnover Analysis with Predictive Indicators
WITH turnover_analysis AS (
    SELECT
        dt.year_number,
        dt.month_number,
        d.department_name,
        d.division,
        p.job_family,
        p.job_level,
        l.region,
        -- Turnover metrics
        COUNT(t.employee_key) as total_leavers,
        COUNT(CASE WHEN t.termination_type = 'Voluntary' THEN 1 END) as voluntary_leavers,
        COUNT(CASE WHEN t.termination_type = 'Involuntary' THEN 1 END) as involuntary_leavers,
        COUNT(CASE WHEN t.regrettable_loss = TRUE THEN 1 END) as regrettable_losses,
        AVG(t.tenure_at_termination_years) as avg_tenure_at_exit,
        AVG(t.performance_score_last) as avg_last_performance,
        -- Headcount for rate calculation
        AVG(monthly_headcount.headcount) as avg_monthly_headcount
    FROM fact_turnover t
    JOIN dim_date dt ON t.termination_date_key = dt.date_key
    JOIN dim_department d ON t.department_key = d.department_key
    JOIN dim_position p ON t.position_key = p.position_key
    JOIN dim_location l ON t.location_key = l.location_key
    LEFT JOIN (
        SELECT
            date_key,
            department_key,
            COUNT(*) as headcount
        FROM fact_employee_snapshot
        WHERE is_active_employee = TRUE
        GROUP BY date_key, department_key
    ) monthly_headcount ON dt.date_key = monthly_headcount.date_key
        AND d.department_key = monthly_headcount.department_key
    WHERE dt.year_number >= 2023
    GROUP BY dt.year_number, dt.month_number, d.department_name, d.division,
             p.job_family, p.job_level, l.region
)
SELECT
    year_number,
    month_number,
    department_name,
    division,
    job_family,
    job_level,
    region,
    total_leavers,
    voluntary_leavers,
    involuntary_leavers,
    regrettable_losses,
    avg_tenure_at_exit,
    avg_last_performance,
    -- Turnover rates
    ROUND(total_leavers * 100.0 / NULLIF(avg_monthly_headcount, 0), 2) as monthly_turnover_rate,
    ROUND(voluntary_leavers * 100.0 / NULLIF(total_leavers, 0), 2) as voluntary_turnover_percent,
    ROUND(regrettable_losses * 100.0 / NULLIF(total_leavers, 0), 2) as regrettable_loss_percent,
    -- Risk indicators
    CASE
        WHEN avg_last_performance < 3.0 THEN 'Performance-Related'
        WHEN avg_tenure_at_exit < 2.0 THEN 'Early-Career Turnover'
        WHEN avg_tenure_at_exit > 10.0 THEN 'Senior Talent Loss'
        ELSE 'Normal Turnover'
    END as turnover_category
FROM turnover_analysis
WHERE total_leavers > 0
ORDER BY year_number DESC, month_number DESC, monthly_turnover_rate DESC;

-- 7.2 Recruitment Effectiveness and Time-to-Fill Analysis
SELECT
    dt.year_number,
    dt.quarter_number,
    dt.month_number,
    d.department_name,
    p.job_family,
    p.job_level,
    l.region,
    -- Recruitment volume
    COUNT(r.recruitment_key) as total_requisitions,
    COUNT(CASE WHEN r.employee_key IS NOT NULL THEN 1 END) as successful_hires,
    -- Efficiency metrics
    AVG(r.time_to_fill_days) as avg_time_to_fill,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY r.time_to_fill_days) as median_time_to_fill,
    AVG(r.cost_per_hire) as avg_cost_per_hire,
    -- Quality metrics
    AVG(r.number_of_applicants) as avg_applicants_per_role,
    AVG(r.number_of_interviews) as avg_interviews_per_role,
    ROUND(AVG(r.offers_accepted * 100.0 / NULLIF(r.number_of_offers, 0)), 2) as offer_acceptance_rate,
    -- Success rate
    ROUND(COUNT(CASE WHEN r.employee_key IS NOT NULL THEN 1 END) * 100.0 / COUNT(r.recruitment_key), 2) as fill_rate,
    -- Satisfaction scores
    AVG(r.recruiter_satisfaction) as avg_recruiter_satisfaction,
    AVG(r.hiring_manager_satisfaction) as avg_hiring_manager_satisfaction
FROM fact_recruitment r
JOIN dim_date dt ON r.posting_date_key = dt.date_key
JOIN dim_department d ON r.department_key = d.department_key
JOIN dim_position p ON r.position_key = p.position_key
JOIN dim_location l ON r.location_key = l.location_key
WHERE dt.year_number >= 2023
GROUP BY dt.year_number, dt.quarter_number, dt.month_number,
         d.department_name, p.job_family, p.job_level, l.region
ORDER BY dt.year_number DESC, dt.quarter_number DESC, dt.month_number DESC;

-- =====================================================
-- 8. DETAILED EMPLOYEE MOVEMENT AND CAREER PROGRESSION
-- =====================================================

-- 8.1 Career Progression Tracking with Salary Impact (Updated to use fact_employee_movement)
SELECT
    dt.year_number,
    dt.quarter_number,
    dt.month_number,
    dt.full_date as movement_date,
    e.employee_id,
    e.full_name,
    e.hire_date,
    ROUND((dt.full_date - e.hire_date) / 365.25, 1) as tenure_at_movement_years,
    -- Movement details
    m.movement_type,
    m.movement_reason,
    m.is_voluntary,
    m.approval_level,
    -- Position progression
    prev_dept.department_name as previous_department,
    new_dept.department_name as new_department,
    prev_pos.position_title as previous_position,
    new_pos.position_title as new_position,
    prev_pos.job_level as previous_job_level,
    new_pos.job_level as new_job_level,
    prev_pos.job_family as previous_job_family,
    new_pos.job_family as new_job_family,
    -- Location changes
    prev_loc.location_name as previous_location,
    new_loc.location_name as new_location,
    prev_loc.country as previous_country,
    new_loc.country as new_country,
    -- Compensation impact
    m.salary_change_amount,
    m.salary_change_percent,
    m.total_compensation_change_amount,
    m.total_compensation_change_percent,
    -- Career progression indicators
    CASE
        WHEN m.movement_type = 'Promotion' AND m.salary_change_percent > 15 THEN 'Significant Promotion'
        WHEN m.movement_type = 'Promotion' AND m.salary_change_percent > 5 THEN 'Standard Promotion'
        WHEN m.movement_type = 'Promotion' AND m.salary_change_percent <= 5 THEN 'Title Promotion'
        WHEN m.movement_type = 'Lateral Transfer' AND prev_pos.job_family != new_pos.job_family THEN 'Cross-Functional Move'
        WHEN m.movement_type = 'Department Transfer' THEN 'Organizational Move'
        WHEN m.movement_type = 'Location Transfer' THEN 'Geographic Move'
        ELSE m.movement_type
    END as movement_category,
    -- Management track progression
    CASE
        WHEN NOT prev_pos.is_management_role AND new_pos.is_management_role THEN 'Promoted to Management'
        WHEN prev_pos.is_management_role AND new_pos.is_management_role THEN 'Management Level Change'
        WHEN prev_pos.is_management_role AND NOT new_pos.is_management_role THEN 'Moved from Management'
        ELSE 'Individual Contributor'
    END as management_progression,
    -- Time since last movement
    LAG(dt.full_date) OVER (PARTITION BY e.employee_id ORDER BY dt.full_date) as previous_movement_date,
    dt.full_date - LAG(dt.full_date) OVER (PARTITION BY e.employee_id ORDER BY dt.full_date) as days_since_last_movement,
    -- Movement sequence number for this employee
    ROW_NUMBER() OVER (PARTITION BY e.employee_id ORDER BY dt.full_date) as movement_sequence_number
FROM fact_employee_movement m
JOIN dim_date dt ON m.movement_date_key = dt.date_key
JOIN dim_employee e ON m.employee_key = e.employee_key AND e.is_current = TRUE
-- Previous position information
LEFT JOIN dim_department prev_dept ON m.previous_department_key = prev_dept.department_key
LEFT JOIN dim_position prev_pos ON m.previous_position_key = prev_pos.position_key
LEFT JOIN dim_location prev_loc ON m.previous_location_key = prev_loc.location_key
-- New position information
JOIN dim_department new_dept ON m.new_department_key = new_dept.department_key
JOIN dim_position new_pos ON m.new_position_key = new_pos.position_key
JOIN dim_location new_loc ON m.new_location_key = new_loc.location_key
WHERE dt.year_number >= 2023
ORDER BY e.employee_id, dt.full_date DESC;

-- =====================================================
-- 9. ENHANCED DAILY/WEEKLY/MONTHLY HEADCOUNT TRACKING
-- =====================================================

-- 9.1 Daily Headcount Snapshot (for real-time monitoring)
SELECT
    dt.full_date,
    dt.day_name,
    dt.year_number,
    dt.month_number,
    dt.day_of_month,
    d.department_name,
    d.division,
    p.job_family,
    p.job_level,
    l.location_name,
    l.city,
    l.country,
    COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END) as daily_headcount,
    COUNT(CASE WHEN f.is_new_hire = TRUE THEN 1 END) as new_hires_today,
    COUNT(CASE WHEN f.is_termination = TRUE THEN 1 END) as terminations_today,
    -- Gender diversity
    COUNT(CASE WHEN f.is_active_employee = TRUE AND e.gender = 'Female' THEN 1 END) as female_count,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND e.gender = 'Male' THEN 1 END) as male_count,
    -- Age demographics
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.age_years END) as avg_age,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND f.age_years < 30 THEN 1 END) as under_30,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND f.age_years BETWEEN 30 AND 50 THEN 1 END) as age_30_50,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND f.age_years > 50 THEN 1 END) as over_50,
    -- Tenure analysis
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.tenure_years END) as avg_tenure,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND f.tenure_years < 1 THEN 1 END) as tenure_under_1yr,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND f.tenure_years BETWEEN 1 AND 5 THEN 1 END) as tenure_1_5yrs,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND f.tenure_years > 5 THEN 1 END) as tenure_over_5yrs,
    -- Compensation metrics
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.base_salary END) as avg_base_salary,
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.total_compensation END) as avg_total_compensation
FROM fact_employee_snapshot f
JOIN dim_date dt ON f.date_key = dt.date_key
JOIN dim_employee e ON f.employee_key = e.employee_key AND e.is_current = TRUE
JOIN dim_department d ON f.department_key = d.department_key
JOIN dim_position p ON f.position_key = p.position_key
JOIN dim_location l ON f.location_key = l.location_key
WHERE dt.full_date >= CURRENT_DATE - INTERVAL '30 days'  -- Last 30 days
GROUP BY dt.full_date, dt.day_name, dt.year_number, dt.month_number, dt.day_of_month,
         d.department_name, d.division, p.job_family, p.job_level,
         l.location_name, l.city, l.country
ORDER BY dt.full_date DESC, daily_headcount DESC;

-- 9.2 Weekly Headcount Aggregation with Trends
WITH weekly_headcount AS (
    SELECT
        dt.year_number,
        dt.week_of_year,
        MIN(dt.full_date) as week_start_date,
        MAX(dt.full_date) as week_end_date,
        d.department_name,
        d.division,
        l.region,
        l.country,
        -- Weekly averages
        AVG(CASE WHEN f.is_active_employee = TRUE THEN 1 ELSE 0 END) as avg_weekly_headcount,
        SUM(CASE WHEN f.is_new_hire = TRUE THEN 1 ELSE 0 END) as weekly_new_hires,
        SUM(CASE WHEN f.is_termination = TRUE THEN 1 ELSE 0 END) as weekly_terminations,
        -- Performance metrics
        AVG(CASE WHEN f.is_active_employee = TRUE THEN f.performance_score END) as avg_performance,
        AVG(CASE WHEN f.is_active_employee = TRUE THEN f.engagement_score END) as avg_engagement,
        -- Compensation
        AVG(CASE WHEN f.is_active_employee = TRUE THEN f.total_compensation END) as avg_compensation
    FROM fact_employee_snapshot f
    JOIN dim_date dt ON f.date_key = dt.date_key
    JOIN dim_department d ON f.department_key = d.department_key
    JOIN dim_location l ON f.location_key = l.location_key
    WHERE dt.year_number >= 2024
    GROUP BY dt.year_number, dt.week_of_year, d.department_name, d.division, l.region, l.country
)
SELECT
    year_number,
    week_of_year,
    week_start_date,
    week_end_date,
    department_name,
    division,
    region,
    country,
    ROUND(avg_weekly_headcount, 0) as avg_headcount,
    weekly_new_hires,
    weekly_terminations,
    weekly_new_hires - weekly_terminations as net_change,
    ROUND(avg_performance, 2) as avg_performance,
    ROUND(avg_engagement, 2) as avg_engagement,
    ROUND(avg_compensation, 0) as avg_compensation,
    -- Week-over-week comparison
    LAG(ROUND(avg_weekly_headcount, 0)) OVER (
        PARTITION BY department_name, region
        ORDER BY year_number, week_of_year
    ) as previous_week_headcount,
    ROUND(avg_weekly_headcount, 0) - LAG(ROUND(avg_weekly_headcount, 0)) OVER (
        PARTITION BY department_name, region
        ORDER BY year_number, week_of_year
    ) as wow_headcount_change
FROM weekly_headcount
WHERE avg_weekly_headcount > 0
ORDER BY year_number DESC, week_of_year DESC, avg_headcount DESC;

-- =====================================================
-- 10. COMPREHENSIVE JOINERS AND LEAVERS MONTHLY ANALYSIS
-- =====================================================

-- 10.1 Monthly Joiners Analysis with Source and Quality Metrics
SELECT
    dt.year_number,
    dt.month_number,
    dt.month_name,
    d.department_name,
    d.division,
    p.job_family,
    p.job_level,
    l.region,
    l.country,
    -- Joiner volume metrics
    COUNT(r.employee_key) as total_joiners,
    COUNT(CASE WHEN r.source_channel = 'Internal Referral' THEN 1 END) as referral_hires,
    COUNT(CASE WHEN r.source_channel = 'Job Board' THEN 1 END) as job_board_hires,
    COUNT(CASE WHEN r.source_channel = 'Recruitment Agency' THEN 1 END) as agency_hires,
    COUNT(CASE WHEN r.source_channel = 'University' THEN 1 END) as university_hires,
    -- Quality and efficiency metrics
    AVG(r.time_to_fill_days) as avg_time_to_fill,
    AVG(r.cost_per_hire) as avg_cost_per_hire,
    AVG(r.number_of_applicants) as avg_applicants_per_role,
    ROUND(AVG(r.offers_accepted * 100.0 / NULLIF(r.number_of_offers, 0)), 2) as offer_acceptance_rate,
    -- Satisfaction metrics
    AVG(r.recruiter_satisfaction) as avg_recruiter_satisfaction,
    AVG(r.hiring_manager_satisfaction) as avg_hiring_manager_satisfaction,
    -- New hire demographics (from employee snapshot)
    AVG(CASE WHEN f.is_new_hire = TRUE THEN f.age_years END) as avg_new_hire_age,
    COUNT(CASE WHEN f.is_new_hire = TRUE AND e.gender = 'Female' THEN 1 END) as female_new_hires,
    ROUND(
        COUNT(CASE WHEN f.is_new_hire = TRUE AND e.gender = 'Female' THEN 1 END) * 100.0 /
        NULLIF(COUNT(CASE WHEN f.is_new_hire = TRUE THEN 1 END), 0), 2
    ) as female_new_hire_percent
FROM fact_recruitment r
JOIN dim_date dt ON r.hire_date_key = dt.date_key
JOIN dim_department d ON r.department_key = d.department_key
JOIN dim_position p ON r.position_key = p.position_key
JOIN dim_location l ON r.location_key = l.location_key
LEFT JOIN fact_employee_snapshot f ON r.employee_key = f.employee_key
    AND f.date_key = r.hire_date_key AND f.is_new_hire = TRUE
LEFT JOIN dim_employee e ON r.employee_key = e.employee_key AND e.is_current = TRUE
WHERE dt.year_number >= 2023
    AND r.employee_key IS NOT NULL  -- Only successful hires
GROUP BY dt.year_number, dt.month_number, dt.month_name,
         d.department_name, d.division, p.job_family, p.job_level, l.region, l.country
ORDER BY dt.year_number DESC, dt.month_number DESC, total_joiners DESC;

-- 10.2 Monthly Leavers Analysis with Exit Reasons and Risk Factors
SELECT
    dt.year_number,
    dt.month_number,
    dt.month_name,
    d.department_name,
    d.division,
    p.job_family,
    p.job_level,
    l.region,
    l.country,
    -- Leaver volume and types
    COUNT(t.employee_key) as total_leavers,
    COUNT(CASE WHEN t.termination_type = 'Voluntary' THEN 1 END) as voluntary_leavers,
    COUNT(CASE WHEN t.termination_type = 'Involuntary' THEN 1 END) as involuntary_leavers,
    COUNT(CASE WHEN t.regrettable_loss = TRUE THEN 1 END) as regrettable_losses,
    COUNT(CASE WHEN t.exit_interview_completed = TRUE THEN 1 END) as exit_interviews_completed,
    -- Exit reasons breakdown
    COUNT(CASE WHEN t.termination_reason = 'Better Opportunity' THEN 1 END) as better_opportunity,
    COUNT(CASE WHEN t.termination_reason = 'Career Growth' THEN 1 END) as career_growth,
    COUNT(CASE WHEN t.termination_reason = 'Compensation' THEN 1 END) as compensation_related,
    COUNT(CASE WHEN t.termination_reason = 'Work-Life Balance' THEN 1 END) as work_life_balance,
    COUNT(CASE WHEN t.termination_reason = 'Management Issues' THEN 1 END) as management_issues,
    COUNT(CASE WHEN t.termination_reason = 'Performance' THEN 1 END) as performance_related,
    -- Risk analysis metrics
    AVG(t.tenure_at_termination_years) as avg_tenure_at_exit,
    AVG(t.age_at_termination) as avg_age_at_exit,
    AVG(t.performance_score_last) as avg_last_performance_score,
    AVG(t.final_salary) as avg_final_salary,
    -- Early turnover analysis
    COUNT(CASE WHEN t.tenure_at_termination_years < 1 THEN 1 END) as early_turnover_under_1yr,
    COUNT(CASE WHEN t.tenure_at_termination_years BETWEEN 1 AND 2 THEN 1 END) as turnover_1_2yrs,
    COUNT(CASE WHEN t.tenure_at_termination_years > 5 THEN 1 END) as senior_talent_loss,
    -- Demographics of leavers
    COUNT(CASE WHEN e.gender = 'Female' THEN 1 END) as female_leavers,
    ROUND(
        COUNT(CASE WHEN e.gender = 'Female' THEN 1 END) * 100.0 /
        NULLIF(COUNT(t.employee_key), 0), 2
    ) as female_leaver_percent
FROM fact_turnover t
JOIN dim_date dt ON t.termination_date_key = dt.date_key
JOIN dim_employee e ON t.employee_key = e.employee_key AND e.is_current = TRUE
JOIN dim_department d ON t.department_key = d.department_key
JOIN dim_position p ON t.position_key = p.position_key
JOIN dim_location l ON t.location_key = l.location_key
WHERE dt.year_number >= 2023
GROUP BY dt.year_number, dt.month_number, dt.month_name,
         d.department_name, d.division, p.job_family, p.job_level, l.region, l.country
ORDER BY dt.year_number DESC, dt.month_number DESC, total_leavers DESC;

-- 10.3 Monthly Net Movement and Turnover Rate Analysis
WITH monthly_movements AS (
    SELECT
        dt.year_number,
        dt.month_number,
        dt.month_name,
        d.department_name,
        d.division,
        -- Joiners
        COUNT(r.employee_key) as joiners,
        -- Leavers
        COUNT(t.employee_key) as leavers,
        COUNT(CASE WHEN t.regrettable_loss = TRUE THEN 1 END) as regrettable_losses,
        -- Average headcount for the month
        AVG(monthly_headcount.headcount) as avg_monthly_headcount
    FROM dim_date dt
    LEFT JOIN fact_recruitment r ON dt.date_key = r.hire_date_key
        AND r.employee_key IS NOT NULL
    LEFT JOIN fact_turnover t ON dt.date_key = t.termination_date_key
    LEFT JOIN dim_department d ON COALESCE(r.department_key, t.department_key) = d.department_key
    LEFT JOIN (
        SELECT
            date_key,
            department_key,
            COUNT(*) as headcount
        FROM fact_employee_snapshot
        WHERE is_active_employee = TRUE
        GROUP BY date_key, department_key
    ) monthly_headcount ON dt.date_key = monthly_headcount.date_key
        AND d.department_key = monthly_headcount.department_key
    WHERE dt.year_number >= 2023
        AND d.department_name IS NOT NULL
        AND dt.day_of_month = 1  -- First day of month for consistency
    GROUP BY dt.year_number, dt.month_number, dt.month_name, d.department_name, d.division
)
SELECT
    year_number,
    month_number,
    month_name,
    department_name,
    division,
    joiners,
    leavers,
    regrettable_losses,
    joiners - leavers as net_movement,
    ROUND(avg_monthly_headcount, 0) as avg_headcount,
    -- Turnover rates
    ROUND(leavers * 100.0 / NULLIF(avg_monthly_headcount, 0), 2) as monthly_turnover_rate,
    ROUND(regrettable_losses * 100.0 / NULLIF(avg_monthly_headcount, 0), 2) as regrettable_loss_rate,
    ROUND(leavers * 12 * 100.0 / NULLIF(avg_monthly_headcount, 0), 2) as annualized_turnover_rate,
    -- Growth metrics
    ROUND((joiners - leavers) * 100.0 / NULLIF(avg_monthly_headcount, 0), 2) as monthly_growth_rate,
    -- Efficiency ratios
    ROUND(joiners * 100.0 / NULLIF(leavers, 0), 2) as replacement_ratio,
    CASE
        WHEN leavers = 0 THEN 'No Turnover'
        WHEN joiners > leavers THEN 'Net Growth'
        WHEN joiners = leavers THEN 'Stable'
        ELSE 'Net Decline'
    END as movement_status
FROM monthly_movements
WHERE avg_monthly_headcount > 0
ORDER BY year_number DESC, month_number DESC, monthly_turnover_rate DESC;

-- =====================================================
-- 11. DETAILED EMPLOYEE MOVEMENTS (TRANSFERS, PROMOTIONS)
-- =====================================================

-- 11.1 Comprehensive Internal Mobility Tracking (Using fact_employee_movement)
SELECT
    dt.year_number,
    dt.month_number,
    dt.full_date as movement_date,
    e.employee_id,
    e.full_name,
    e.hire_date,
    ROUND((dt.full_date - e.hire_date) / 365.25, 1) as tenure_at_movement_years,
    -- Movement details
    m.movement_type,
    m.movement_reason,
    m.is_voluntary,
    m.approval_level,
    -- Previous position
    prev_dept.department_name as prev_department,
    prev_dept.division as prev_division,
    prev_pos.position_title as prev_position,
    prev_pos.job_level as prev_job_level,
    prev_pos.job_family as prev_job_family,
    prev_loc.location_name as prev_location,
    prev_loc.city as prev_city,
    prev_loc.country as prev_country,
    -- New position
    new_dept.department_name as new_department,
    new_dept.division as new_division,
    new_pos.position_title as new_position,
    new_pos.job_level as new_job_level,
    new_pos.job_family as new_job_family,
    new_loc.location_name as new_location,
    new_loc.city as new_city,
    new_loc.country as new_country,
    -- Compensation impact
    m.salary_change_amount,
    m.salary_change_percent,
    m.total_compensation_change_amount,
    m.total_compensation_change_percent,
    -- Movement quality indicators
    CASE
        WHEN m.movement_type = 'Promotion' AND m.salary_change_percent > 15 THEN 'High-Impact Promotion'
        WHEN m.movement_type = 'Promotion' AND m.salary_change_percent > 5 THEN 'Standard Promotion'
        WHEN m.movement_type = 'Promotion' AND m.salary_change_percent <= 5 THEN 'Title Promotion'
        WHEN m.movement_type = 'Department Transfer' AND m.salary_change_percent > 0 THEN 'Positive Transfer'
        WHEN m.movement_type = 'Location Transfer' THEN 'Geographic Move'
        WHEN m.movement_type = 'Lateral Transfer' THEN 'Skill Development'
        ELSE m.movement_type
    END as movement_category,
    -- Management progression
    CASE
        WHEN NOT prev_pos.is_management_role AND new_pos.is_management_role THEN 'Promoted to Management'
        WHEN prev_pos.is_management_role AND new_pos.is_management_role THEN 'Management Level Change'
        WHEN prev_pos.is_management_role AND NOT new_pos.is_management_role THEN 'Moved from Management'
        ELSE 'Individual Contributor'
    END as management_progression,
    -- Time since last movement
    LAG(dt.full_date) OVER (PARTITION BY e.employee_id ORDER BY dt.full_date) as previous_movement_date,
    dt.full_date - LAG(dt.full_date) OVER (PARTITION BY e.employee_id ORDER BY dt.full_date) as days_since_last_movement,
    -- Movement sequence for this employee
    ROW_NUMBER() OVER (PARTITION BY e.employee_id ORDER BY dt.full_date) as movement_sequence_number
FROM fact_employee_movement m
JOIN dim_date dt ON m.movement_date_key = dt.date_key
JOIN dim_employee e ON m.employee_key = e.employee_key AND e.is_current = TRUE
-- Previous position information
LEFT JOIN dim_department prev_dept ON m.previous_department_key = prev_dept.department_key
LEFT JOIN dim_position prev_pos ON m.previous_position_key = prev_pos.position_key
LEFT JOIN dim_location prev_loc ON m.previous_location_key = prev_loc.location_key
-- New position information
JOIN dim_department new_dept ON m.new_department_key = new_dept.department_key
JOIN dim_position new_pos ON m.new_position_key = new_pos.position_key
JOIN dim_location new_loc ON m.new_location_key = new_loc.location_key
WHERE dt.year_number >= 2024
ORDER BY dt.year_number DESC, dt.month_number DESC, m.salary_change_percent DESC NULLS LAST;

-- 11.2 Monthly Internal Mobility Summary (Using fact_employee_movement)
SELECT
    dt.year_number,
    dt.month_number,
    dt.month_name,
    d.department_name as destination_department,
    d.division as destination_division,
    -- Movement counts by type
    COUNT(CASE WHEN m.movement_type = 'Department Transfer' THEN 1 END) as department_transfers,
    COUNT(CASE WHEN m.movement_type = 'Promotion' THEN 1 END) as promotions,
    COUNT(CASE WHEN m.movement_type = 'Lateral Transfer' THEN 1 END) as lateral_moves,
    COUNT(CASE WHEN m.movement_type = 'Location Transfer' THEN 1 END) as location_transfers,
    COUNT(CASE WHEN m.movement_type = 'Manager Change' THEN 1 END) as manager_changes,
    COUNT(CASE WHEN m.movement_type = 'Demotion' THEN 1 END) as demotions,
    COUNT(*) as total_movements,
    -- Voluntary vs involuntary movements
    COUNT(CASE WHEN m.is_voluntary = TRUE THEN 1 END) as voluntary_movements,
    COUNT(CASE WHEN m.is_voluntary = FALSE THEN 1 END) as involuntary_movements,
    ROUND(COUNT(CASE WHEN m.is_voluntary = TRUE THEN 1 END) * 100.0 / COUNT(*), 2) as voluntary_movement_percent,
    -- Average salary impact
    AVG(CASE WHEN m.movement_type = 'Promotion' THEN m.salary_change_percent END) as avg_promotion_salary_increase,
    AVG(CASE WHEN m.movement_type = 'Department Transfer' THEN m.salary_change_percent END) as avg_transfer_salary_change,
    AVG(CASE WHEN m.movement_type = 'Lateral Transfer' THEN m.salary_change_percent END) as avg_lateral_salary_change,
    -- Movement reasons breakdown
    COUNT(CASE WHEN m.movement_reason = 'Career Development' THEN 1 END) as career_development_moves,
    COUNT(CASE WHEN m.movement_reason = 'Business Need' THEN 1 END) as business_need_moves,
    COUNT(CASE WHEN m.movement_reason = 'Employee Request' THEN 1 END) as employee_request_moves,
    COUNT(CASE WHEN m.movement_reason = 'Performance' THEN 1 END) as performance_related_moves,
    COUNT(CASE WHEN m.movement_reason = 'Succession Planning' THEN 1 END) as succession_planning_moves,
    -- Gender analysis
    COUNT(CASE WHEN m.movement_type = 'Promotion' AND e.gender = 'Female' THEN 1 END) as female_promotions,
    ROUND(
        COUNT(CASE WHEN m.movement_type = 'Promotion' AND e.gender = 'Female' THEN 1 END) * 100.0 /
        NULLIF(COUNT(CASE WHEN m.movement_type = 'Promotion' THEN 1 END), 0), 2
    ) as female_promotion_percent,
    -- Approval level analysis
    COUNT(CASE WHEN m.approval_level = 'Manager' THEN 1 END) as manager_approved,
    COUNT(CASE WHEN m.approval_level = 'Director' THEN 1 END) as director_approved,
    COUNT(CASE WHEN m.approval_level = 'VP' THEN 1 END) as vp_approved,
    COUNT(CASE WHEN m.approval_level = 'CEO' THEN 1 END) as ceo_approved
FROM fact_employee_movement m
JOIN dim_date dt ON m.movement_date_key = dt.date_key
JOIN dim_employee e ON m.employee_key = e.employee_key AND e.is_current = TRUE
JOIN dim_department d ON m.new_department_key = d.department_key
WHERE dt.year_number >= 2024
GROUP BY dt.year_number, dt.month_number, dt.month_name, d.department_name, d.division
HAVING COUNT(*) > 0
ORDER BY dt.year_number DESC, dt.month_number DESC, total_movements DESC;

-- 11.3 Career Progression Pathways Analysis (Using fact_employee_movement)
WITH career_paths AS (
    SELECT
        e.employee_id,
        e.full_name,
        e.hire_date,
        ROUND((CURRENT_DATE - e.hire_date) / 365.25, 1) as total_tenure_years,
        -- Career path construction
        STRING_AGG(
            new_pos.position_title || ' (' || new_dept.department_name || ')',
            ' → ' ORDER BY dt.full_date
        ) as career_path,
        -- Movement counts
        COUNT(CASE WHEN m.movement_type = 'Promotion' THEN 1 END) as total_promotions,
        COUNT(CASE WHEN m.movement_type = 'Department Transfer' THEN 1 END) as total_transfers,
        COUNT(CASE WHEN m.movement_type = 'Location Transfer' THEN 1 END) as total_relocations,
        COUNT(CASE WHEN m.movement_type = 'Lateral Transfer' THEN 1 END) as total_lateral_moves,
        COUNT(*) as total_movements,
        -- Unique experiences
        COUNT(DISTINCT new_dept.department_name) as departments_worked,
        COUNT(DISTINCT new_loc.location_name) as locations_worked,
        COUNT(DISTINCT new_pos.job_family) as job_families_worked,
        -- Salary progression from movements
        SUM(CASE WHEN m.movement_type = 'Promotion' THEN m.salary_change_amount ELSE 0 END) as total_promotion_salary_increase,
        SUM(m.salary_change_amount) as total_salary_change_from_movements,
        AVG(CASE WHEN m.movement_type = 'Promotion' THEN m.salary_change_percent END) as avg_promotion_increase_percent,
        -- Time metrics
        MIN(dt.full_date) as first_movement_date,
        MAX(dt.full_date) as last_movement_date,
        MAX(dt.full_date) - MIN(dt.full_date) as movement_span_days,
        -- Management progression
        COUNT(CASE WHEN NOT prev_pos.is_management_role AND new_pos.is_management_role THEN 1 END) as times_promoted_to_management,
        -- Voluntary vs involuntary movements
        COUNT(CASE WHEN m.is_voluntary = TRUE THEN 1 END) as voluntary_movements,
        COUNT(CASE WHEN m.is_voluntary = FALSE THEN 1 END) as involuntary_movements
    FROM dim_employee e
    LEFT JOIN fact_employee_movement m ON e.employee_key = m.employee_key
    LEFT JOIN dim_date dt ON m.movement_date_key = dt.date_key
    LEFT JOIN dim_department new_dept ON m.new_department_key = new_dept.department_key
    LEFT JOIN dim_position new_pos ON m.new_position_key = new_pos.position_key
    LEFT JOIN dim_location new_loc ON m.new_location_key = new_loc.location_key
    LEFT JOIN dim_position prev_pos ON m.previous_position_key = prev_pos.position_key
    WHERE e.is_current = TRUE
        AND e.employment_status = 'Active'
        AND (dt.year_number >= 2023 OR dt.year_number IS NULL)  -- Include employees with no movements
    GROUP BY e.employee_id, e.full_name, e.hire_date
)
SELECT
    employee_id,
    full_name,
    hire_date,
    total_tenure_years,
    career_path,
    total_movements,
    total_promotions,
    total_transfers,
    total_relocations,
    total_lateral_moves,
    departments_worked,
    locations_worked,
    job_families_worked,
    total_promotion_salary_increase,
    total_salary_change_from_movements,
    avg_promotion_increase_percent,
    times_promoted_to_management,
    voluntary_movements,
    involuntary_movements,
    -- Career progression metrics
    ROUND(total_promotions / NULLIF(total_tenure_years, 0), 2) as promotions_per_year,
    ROUND(total_movements / NULLIF(total_tenure_years, 0), 2) as movements_per_year,
    -- Career mobility classification
    CASE
        WHEN total_promotions >= 3 AND departments_worked >= 2 THEN 'High Mobility - Cross-Functional'
        WHEN total_promotions >= 3 THEN 'High Mobility - Vertical'
        WHEN departments_worked >= 3 THEN 'High Mobility - Horizontal'
        WHEN total_promotions >= 1 OR departments_worked >= 2 THEN 'Moderate Mobility'
        WHEN total_movements = 0 THEN 'No Recorded Movements'
        ELSE 'Low Mobility'
    END as mobility_profile,
    -- Movement pattern analysis
    CASE
        WHEN voluntary_movements > involuntary_movements THEN 'Employee-Driven Career'
        WHEN involuntary_movements > voluntary_movements THEN 'Organization-Driven Career'
        WHEN total_movements = 0 THEN 'Stable Position'
        ELSE 'Balanced Movement Pattern'
    END as movement_pattern
FROM career_paths
WHERE total_tenure_years >= 1  -- At least 1 year tenure
ORDER BY total_promotions DESC, total_movements DESC, total_tenure_years DESC;

-- =====================================================
-- 12. ENHANCED PERFORMANCE TRACKING (MONTH, QUARTER, YEAR)
-- =====================================================

-- 12.1 Comprehensive Performance Analytics by Time Period
SELECT
    dt.year_number,
    dt.quarter_number,
    dt.month_number,
    dt.month_name,
    d.department_name,
    d.division,
    p.job_family,
    p.job_level,
    l.region,
    -- Performance review metrics
    COUNT(perf.performance_key) as total_reviews,
    AVG(perf.overall_rating) as avg_overall_rating,
    AVG(perf.goals_achievement_score) as avg_goals_achievement,
    AVG(perf.competency_score) as avg_competency_score,
    AVG(perf.leadership_score) as avg_leadership_score,
    -- Performance distribution
    COUNT(CASE WHEN perf.overall_rating >= 4.5 THEN 1 END) as excellent_performers,
    COUNT(CASE WHEN perf.overall_rating >= 3.5 AND perf.overall_rating < 4.5 THEN 1 END) as good_performers,
    COUNT(CASE WHEN perf.overall_rating >= 2.5 AND perf.overall_rating < 3.5 THEN 1 END) as average_performers,
    COUNT(CASE WHEN perf.overall_rating < 2.5 THEN 1 END) as below_average_performers,
    -- Performance percentages
    ROUND(COUNT(CASE WHEN perf.overall_rating >= 4.5 THEN 1 END) * 100.0 / COUNT(*), 2) as excellent_percent,
    ROUND(COUNT(CASE WHEN perf.overall_rating >= 3.5 THEN 1 END) * 100.0 / COUNT(*), 2) as good_plus_percent,
    ROUND(COUNT(CASE WHEN perf.overall_rating < 2.5 THEN 1 END) * 100.0 / COUNT(*), 2) as below_average_percent,
    -- Potential and readiness metrics
    COUNT(CASE WHEN perf.potential_rating = 'High' THEN 1 END) as high_potential_count,
    COUNT(CASE WHEN perf.promotion_readiness = 'Ready' THEN 1 END) as promotion_ready_count,
    ROUND(COUNT(CASE WHEN perf.potential_rating = 'High' THEN 1 END) * 100.0 / COUNT(*), 2) as high_potential_percent,
    ROUND(COUNT(CASE WHEN perf.promotion_readiness = 'Ready' THEN 1 END) * 100.0 / COUNT(*), 2) as promotion_ready_percent,
    -- Performance variability
    STDDEV(perf.overall_rating) as performance_std_dev,
    MAX(perf.overall_rating) - MIN(perf.overall_rating) as performance_range
FROM fact_performance perf
JOIN dim_date dt ON perf.review_date_key = dt.date_key
JOIN dim_employee e ON perf.employee_key = e.employee_key AND e.is_current = TRUE
JOIN dim_department d ON perf.department_key = d.department_key
JOIN dim_position p ON e.employee_key = (
    SELECT f.employee_key
    FROM fact_employee_snapshot f
    WHERE f.employee_key = e.employee_key
        AND f.date_key = perf.review_date_key
        AND f.is_active_employee = TRUE
    LIMIT 1
) AND p.position_key = (
    SELECT f.position_key
    FROM fact_employee_snapshot f
    WHERE f.employee_key = e.employee_key
        AND f.date_key = perf.review_date_key
        AND f.is_active_employee = TRUE
    LIMIT 1
)
JOIN dim_location l ON l.location_key = (
    SELECT f.location_key
    FROM fact_employee_snapshot f
    WHERE f.employee_key = e.employee_key
        AND f.date_key = perf.review_date_key
        AND f.is_active_employee = TRUE
    LIMIT 1
)
WHERE dt.year_number >= 2023
GROUP BY dt.year_number, dt.quarter_number, dt.month_number, dt.month_name,
         d.department_name, d.division, p.job_family, p.job_level, l.region
ORDER BY dt.year_number DESC, dt.quarter_number DESC, dt.month_number DESC, avg_overall_rating DESC;

-- 12.2 Individual Performance Trends Over Time
WITH performance_trends AS (
    SELECT
        e.employee_id,
        e.full_name,
        dt.year_number,
        dt.quarter_number,
        dt.month_number,
        d.department_name,
        p.position_title,
        p.job_level,
        perf.overall_rating,
        perf.goals_achievement_score,
        perf.potential_rating,
        perf.promotion_readiness,
        perf.review_type,
        -- Performance trends
        LAG(perf.overall_rating, 1) OVER (PARTITION BY e.employee_id ORDER BY dt.year_number, dt.quarter_number) as prev_quarter_rating,
        LAG(perf.overall_rating, 4) OVER (PARTITION BY e.employee_id ORDER BY dt.year_number, dt.quarter_number) as prev_year_rating,
        -- Ranking within department and level
        RANK() OVER (PARTITION BY d.department_key, p.job_level, dt.year_number, dt.quarter_number ORDER BY perf.overall_rating DESC) as dept_level_rank,
        COUNT(*) OVER (PARTITION BY d.department_key, p.job_level, dt.year_number, dt.quarter_number) as dept_level_total
    FROM fact_performance perf
    JOIN dim_employee e ON perf.employee_key = e.employee_key AND e.is_current = TRUE
    JOIN dim_date dt ON perf.review_date_key = dt.date_key
    JOIN dim_department d ON perf.department_key = d.department_key
    JOIN fact_employee_snapshot f ON perf.employee_key = f.employee_key
        AND f.date_key = perf.review_date_key AND f.is_active_employee = TRUE
    JOIN dim_position p ON f.position_key = p.position_key
    WHERE dt.year_number >= 2022
)
SELECT
    employee_id,
    full_name,
    year_number,
    quarter_number,
    month_number,
    department_name,
    position_title,
    job_level,
    overall_rating,
    goals_achievement_score,
    potential_rating,
    promotion_readiness,
    review_type,
    prev_quarter_rating,
    prev_year_rating,
    -- Performance change indicators
    CASE
        WHEN prev_quarter_rating IS NOT NULL THEN
            ROUND(overall_rating - prev_quarter_rating, 2)
        ELSE NULL
    END as qoq_rating_change,
    CASE
        WHEN prev_year_rating IS NOT NULL THEN
            ROUND(overall_rating - prev_year_rating, 2)
        ELSE NULL
    END as yoy_rating_change,
    -- Performance trend classification
    CASE
        WHEN prev_quarter_rating IS NOT NULL AND overall_rating > prev_quarter_rating + 0.5 THEN 'Improving'
        WHEN prev_quarter_rating IS NOT NULL AND overall_rating < prev_quarter_rating - 0.5 THEN 'Declining'
        WHEN prev_quarter_rating IS NOT NULL THEN 'Stable'
        ELSE 'New Review'
    END as performance_trend,
    -- Relative performance
    dept_level_rank,
    dept_level_total,
    ROUND(dept_level_rank * 100.0 / dept_level_total, 0) as percentile_rank
FROM performance_trends
WHERE year_number >= 2023
ORDER BY employee_id, year_number DESC, quarter_number DESC;

-- 12.3 Performance Improvement and Development Tracking
SELECT
    dt.year_number,
    dt.quarter_number,
    d.department_name,
    d.division,
    p.job_level,
    -- Performance improvement metrics
    COUNT(*) as total_employees_reviewed,
    COUNT(CASE WHEN qoq_rating_change > 0 THEN 1 END) as improved_qoq,
    COUNT(CASE WHEN qoq_rating_change < 0 THEN 1 END) as declined_qoq,
    COUNT(CASE WHEN yoy_rating_change > 0 THEN 1 END) as improved_yoy,
    COUNT(CASE WHEN yoy_rating_change < 0 THEN 1 END) as declined_yoy,
    -- Improvement rates
    ROUND(COUNT(CASE WHEN qoq_rating_change > 0 THEN 1 END) * 100.0 / COUNT(*), 2) as improvement_rate_qoq,
    ROUND(COUNT(CASE WHEN yoy_rating_change > 0 THEN 1 END) * 100.0 /
          NULLIF(COUNT(CASE WHEN yoy_rating_change IS NOT NULL THEN 1 END), 0), 2) as improvement_rate_yoy,
    -- High performer development
    COUNT(CASE WHEN overall_rating >= 4.5 AND potential_rating = 'High' THEN 1 END) as high_performer_high_potential,
    COUNT(CASE WHEN overall_rating >= 4.5 AND promotion_readiness = 'Ready' THEN 1 END) as top_performers_ready_promotion,
    -- Development needs
    COUNT(CASE WHEN overall_rating < 3.0 THEN 1 END) as needs_improvement,
    COUNT(CASE WHEN overall_rating < 3.0 AND qoq_rating_change <= 0 THEN 1 END) as declining_low_performers,
    -- Training correlation (if available)
    AVG(training_data.training_hours) as avg_training_hours,
    CORR(overall_rating, training_data.training_hours) as performance_training_correlation
FROM performance_trends pt
JOIN dim_date dt ON pt.year_number = dt.year_number AND pt.quarter_number = dt.quarter_number
JOIN dim_department d ON pt.department_name = d.department_name
JOIN dim_position p ON pt.job_level = p.job_level
LEFT JOIN (
    SELECT
        t.employee_key,
        SUM(t.training_hours) as training_hours
    FROM fact_training t
    WHERE t.completion_status = 'Completed'
    GROUP BY t.employee_key
) training_data ON pt.employee_id = (
    SELECT e.employee_id
    FROM dim_employee e
    WHERE e.employee_key = training_data.employee_key
        AND e.is_current = TRUE
)
WHERE dt.year_number >= 2023
    AND dt.day_of_month = 1  -- First day of quarter
GROUP BY dt.year_number, dt.quarter_number, d.department_name, d.division, p.job_level
ORDER BY dt.year_number DESC, dt.quarter_number DESC, improvement_rate_qoq DESC;

-- =====================================================
-- 13. DISTRIBUTED CHANNELS BUSINESS ACHIEVEMENTS (ENHANCED)
-- =====================================================

-- 13.1 Distributed Channels - Comprehensive Business Performance Dashboard
SELECT
    dt.year_number,
    dt.quarter_number,
    dt.month_number,
    dt.month_name,
    d.department_name,
    d.division,
    -- Workforce Metrics
    ROUND(AVG(CASE WHEN f.is_active_employee = TRUE THEN 1 ELSE 0 END), 0) as avg_headcount,
    COUNT(CASE WHEN f.is_new_hire = TRUE THEN 1 END) as new_hires,
    COUNT(CASE WHEN f.is_termination = TRUE THEN 1 END) as terminations,
    COUNT(CASE WHEN f.is_new_hire = TRUE THEN 1 END) - COUNT(CASE WHEN f.is_termination = TRUE THEN 1 END) as net_headcount_change,
    -- Performance Excellence
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.performance_score END) as avg_performance_score,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND f.performance_score >= 4.5 THEN 1 END) as top_performers,
    ROUND(COUNT(CASE WHEN f.is_active_employee = TRUE AND f.performance_score >= 4.5 THEN 1 END) * 100.0 /
          NULLIF(COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END), 0), 2) as top_performer_percent,
    -- Employee Engagement & Satisfaction
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.engagement_score END) as avg_engagement_score,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND f.engagement_score >= 4.0 THEN 1 END) as highly_engaged,
    ROUND(COUNT(CASE WHEN f.is_active_employee = TRUE AND f.engagement_score >= 4.0 THEN 1 END) * 100.0 /
          NULLIF(COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END), 0), 2) as engagement_rate,
    -- Talent Quality & Experience
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.tenure_years END) as avg_tenure_years,
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.age_years END) as avg_age,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND f.tenure_years >= 5 THEN 1 END) as experienced_employees,
    -- Compensation & Investment
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.base_salary END) as avg_base_salary,
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.total_compensation END) as avg_total_compensation,
    SUM(CASE WHEN f.is_active_employee = TRUE THEN f.total_compensation END) as total_compensation_investment,
    -- Productivity Indicators (Performance per compensation cost)
    ROUND(AVG(CASE WHEN f.is_active_employee = TRUE AND f.total_compensation > 0
              THEN f.performance_score / f.total_compensation * 1000000 END), 2) as productivity_index,
    -- Risk Management
    AVG(CASE WHEN f.is_active_employee = TRUE THEN f.flight_risk_score END) as avg_flight_risk,
    COUNT(CASE WHEN f.is_active_employee = TRUE AND f.flight_risk_score >= 4.0 THEN 1 END) as high_flight_risk_employees,
    -- Leadership Pipeline
    COUNT(CASE WHEN f.is_active_employee = TRUE AND p.is_management_role = TRUE THEN 1 END) as management_count,
    ROUND(COUNT(CASE WHEN f.is_active_employee = TRUE AND p.is_management_role = TRUE THEN 1 END) * 100.0 /
          NULLIF(COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END), 0), 2) as management_ratio
FROM fact_employee_snapshot f
JOIN dim_date dt ON f.date_key = dt.date_key
JOIN dim_department d ON f.department_key = d.department_key
JOIN dim_position p ON f.position_key = p.position_key
WHERE (d.department_name ILIKE '%distributed%'
    OR d.department_name ILIKE '%channel%'
    OR d.division ILIKE '%distributed%'
    OR d.division ILIKE '%channel%')
    AND dt.year_number >= 2023
GROUP BY dt.year_number, dt.quarter_number, dt.month_number, dt.month_name, d.department_name, d.division
ORDER BY dt.year_number DESC, dt.quarter_number DESC, dt.month_number DESC;

-- 13.2 Distributed Channels - Business Achievement Trends & KPIs
WITH channel_kpis AS (
    SELECT
        dt.year_number,
        dt.quarter_number,
        dt.month_number,
        d.department_name,
        -- Core business metrics
        COUNT(CASE WHEN f.is_active_employee = TRUE THEN 1 END) as headcount,
        AVG(f.performance_score) as avg_performance,
        AVG(f.engagement_score) as avg_engagement,
        AVG(f.total_compensation) as avg_compensation,
        SUM(f.total_compensation) as total_compensation_cost,
        -- Efficiency metrics
        AVG(f.performance_score / NULLIF(f.total_compensation, 0) * 1000000) as efficiency_ratio,
        -- Quality metrics
        COUNT(CASE WHEN f.performance_score >= 4.5 THEN 1 END) as excellence_count,
        COUNT(CASE WHEN f.engagement_score >= 4.0 THEN 1 END) as engagement_count,
        -- Stability metrics
        AVG(f.tenure_years) as avg_tenure,
        COUNT(CASE WHEN turnover.employee_key IS NOT NULL THEN 1 END) as departures,
        -- Development metrics
        COUNT(CASE WHEN training.training_completed > 0 THEN 1 END) as employees_trained,
        AVG(training.training_hours) as avg_training_hours
    FROM fact_employee_snapshot f
    JOIN dim_date dt ON f.date_key = dt.date_key
    JOIN dim_department d ON f.department_key = d.department_key
    LEFT JOIN fact_turnover turnover ON f.employee_key = turnover.employee_key
        AND dt.date_key = turnover.termination_date_key
    LEFT JOIN (
        SELECT
            t.employee_key,
            t.training_date_key,
            COUNT(*) as training_completed,
            SUM(t.training_hours) as training_hours
        FROM fact_training t
        WHERE t.completion_status = 'Completed'
        GROUP BY t.employee_key, t.training_date_key
    ) training ON f.employee_key = training.employee_key AND f.date_key = training.training_date_key
    WHERE (d.department_name ILIKE '%distributed%'
        OR d.department_name ILIKE '%channel%'
        OR d.division ILIKE '%distributed%'
        OR d.division ILIKE '%channel%')
        AND f.is_active_employee = TRUE
        AND dt.year_number >= 2022
    GROUP BY dt.year_number, dt.quarter_number, dt.month_number, d.department_name
)
SELECT
    year_number,
    quarter_number,
    month_number,
    department_name,
    headcount,
    ROUND(avg_performance, 2) as avg_performance,
    ROUND(avg_engagement, 2) as avg_engagement,
    ROUND(avg_compensation, 0) as avg_compensation,
    ROUND(total_compensation_cost, 0) as total_investment,
    ROUND(efficiency_ratio, 2) as efficiency_ratio,
    excellence_count,
    engagement_count,
    ROUND(avg_tenure, 1) as avg_tenure,
    departures,
    employees_trained,
    ROUND(avg_training_hours, 1) as avg_training_hours,
    -- Trend analysis
    LAG(avg_performance) OVER (PARTITION BY department_name ORDER BY year_number, quarter_number, month_number) as prev_performance,
    LAG(headcount) OVER (PARTITION BY department_name ORDER BY year_number, quarter_number, month_number) as prev_headcount,
    LAG(efficiency_ratio) OVER (PARTITION BY department_name ORDER BY year_number, quarter_number, month_number) as prev_efficiency,
    -- Performance indicators
    CASE
        WHEN avg_performance > LAG(avg_performance) OVER (PARTITION BY department_name ORDER BY year_number, quarter_number, month_number)
        THEN 'Improving'
        WHEN avg_performance < LAG(avg_performance) OVER (PARTITION BY department_name ORDER BY year_number, quarter_number, month_number)
        THEN 'Declining'
        ELSE 'Stable'
    END as performance_trend,
    -- Business health score (composite metric)
    ROUND((avg_performance * 0.3 + avg_engagement * 0.3 + (5 - LEAST(departures * 100.0 / NULLIF(headcount, 0), 5)) * 0.2 +
           LEAST(avg_tenure, 5) * 0.2) * 20, 1) as business_health_score
FROM channel_kpis
ORDER BY year_number DESC, quarter_number DESC, month_number DESC, business_health_score DESC;

-- =====================================================
-- END OF HR ANALYTICS QUERIES
-- =====================================================
