-- =====================================================
-- FAKE DATA FOR fact_employee_snapshot TABLE
-- =====================================================
-- This script generates sample data for the fact_employee_snapshot table
-- Based on the updated DDL structure from hr_dwh_design.sql

SET search_path = hr_analytics;

-- Insert sample date dimension data for 2024
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
FROM generate_series('2024-01-01'::date, '2024-12-31'::date, '1 day'::interval) d
ON CONFLICT (date_key) DO NOTHING;

-- Insert sample employees
INSERT INTO dim_employee (employee_id, first_name, last_name, email, phone, date_of_birth, gender, hire_date, employment_status, is_current)
VALUES 
    ('EMP001', 'Nguyen', 'Van A', 'nguyen.vana@company.com', '+84901234567', '1990-05-15', 'Male', '2020-01-15', 'Active', TRUE),
    ('EMP002', 'Tran', 'Thi B', 'tran.thib@company.com', '+84901234568', '1992-08-22', 'Female', '2021-03-10', 'Active', TRUE),
    ('EMP003', 'Le', 'Van C', 'le.vanc@company.com', '+84901234569', '1988-12-03', 'Male', '2019-06-01', 'Active', TRUE),
    ('EMP004', 'Pham', 'Thi D', 'pham.thid@company.com', '+84901234570', '1995-02-14', 'Female', '2022-09-15', 'Active', TRUE),
    ('EMP005', 'Hoang', 'Van E', 'hoang.vane@company.com', '+84901234571', '1987-11-30', 'Male', '2018-04-20', 'Active', TRUE)
    ('EMP006', 'Vo', 'Thi F', 'vo.thif@company.com', '+84901234572', '1991-03-18', 'Female', 'Vietnamese', 'Single', '2023-01-15', 'Active', 'Full-time', 'Junior', 'G3', FALSE, TRUE),
    ('EMP007', 'Dang', 'Van G', 'dang.vang@company.com', '+84901234573', '1989-07-25', 'Male', 'Vietnamese', 'Married', '2020-05-20', 'Active', 'Full-time', 'Senior', 'G5', FALSE, TRUE),
    ('EMP008', 'Bui', 'Thi H', 'bui.thih@company.com', '+84901234574', '1993-09-12', 'Female', 'Vietnamese', 'Single', '2022-02-10', 'Active', 'Full-time', 'Senior', 'G5', FALSE, TRUE),
    ('EMP009', 'Do', 'Van I', 'do.vani@company.com', '+84901234575', '1986-04-08', 'Male', 'Vietnamese', 'Married', '2019-08-15', 'Active', 'Full-time', 'Lead', 'G6', TRUE, TRUE),
    ('EMP010', 'Ngo', 'Thi J', 'ngo.thij@company.com', '+84901234576', '1994-12-01', 'Female', 'Vietnamese', 'Single', '2023-06-01', 'Active', 'Full-time', 'Junior', 'G3', FALSE, TRUE),
    ('EMP011', 'Ly', 'Van K', 'ly.vank@company.com', '+84901234577', '1985-01-20', 'Male', 'Vietnamese', 'Married', '2018-03-10', 'Active', 'Full-time', 'Manager', 'G7', TRUE, TRUE),
    ('EMP012', 'Truong', 'Thi L', 'truong.thil@company.com', '+84901234578', '1992-06-15', 'Female', 'Vietnamese', 'Married', '2021-09-05', 'Active', 'Full-time', 'Senior', 'G5', FALSE, TRUE),
    ('EMP013', 'Vu', 'Van M', 'vu.vanm@company.com', '+84901234579', '1990-10-30', 'Male', 'Vietnamese', 'Single', '2020-11-20', 'Active', 'Full-time', 'Senior', 'G5', FALSE, TRUE),
    ('EMP014', 'Mai', 'Thi N', 'mai.thin@company.com', '+84901234580', '1988-02-28', 'Female', 'Vietnamese', 'Married', '2019-01-15', 'Active', 'Full-time', 'Lead', 'G6', TRUE, TRUE),
    ('EMP015', 'Cao', 'Van O', 'cao.vano@company.com', '+84901234581', '1987-08-14', 'Male', 'Vietnamese', 'Married', '2017-12-01', 'Active', 'Full-time', 'Manager', 'G7', TRUE, TRUE),
    ('EMP016', 'Dinh', 'Thi P', 'dinh.thip@company.com', '+84901234582', '1995-05-22', 'Female', 'Vietnamese', 'Single', '2023-03-15', 'Active', 'Full-time', 'Junior', 'G3', FALSE, TRUE),
    ('EMP017', 'Ta', 'Van Q', 'ta.vanq@company.com', '+84901234583', '1991-11-07', 'Male', 'Vietnamese', 'Single', '2022-07-10', 'Active', 'Full-time', 'Senior', 'G5', FALSE, TRUE),
    ('EMP018', 'Lam', 'Thi R', 'lam.thir@company.com', '+84901234584', '1989-09-03', 'Female', 'Vietnamese', 'Married', '2020-04-25', 'Active', 'Full-time', 'Senior', 'G5', FALSE, TRUE),
    ('EMP019', 'Duong', 'Van S', 'duong.vans@company.com', '+84901234585', '1984-12-18', 'Male', 'Vietnamese', 'Married', '2016-08-30', 'Active', 'Full-time', 'Director', 'G8', TRUE, TRUE),
    ('EMP020', 'Tong', 'Thi T', 'tong.thit@company.com', '+84901234586', '1993-03-25', 'Female', 'Vietnamese', 'Single', '2022-10-15', 'Active', 'Full-time', 'Senior', 'G5', FALSE, TRUE)
ON CONFLICT (employee_id, valid_from) DO NOTHING;

-- Insert sample departments
INSERT INTO dim_department (department_id, department_name, department_code, division, business_unit, cost_center, department_level, is_current)
VALUES 
    ('DEPT001', 'Information Technology', 'IT', 'Technology', 'Engineering', 'CC001', 1, TRUE),
    ('DEPT002', 'Human Resources', 'HR', 'Corporate', 'Support', 'CC002', 1, TRUE),
    ('DEPT003', 'Finance', 'FIN', 'Corporate', 'Finance', 'CC003', 1, TRUE),
    ('DEPT004', 'Marketing', 'MKT', 'Business', 'Sales & Marketing', 'CC004', 1, TRUE),
    ('DEPT005', 'Operations', 'OPS', 'Business', 'Operations', 'CC005', 1, TRUE)
    ('POS006', 'Junior Developer', 'JD', 'Engineering', 'Development', 'Junior', 'G3', FALSE, TRUE),
    ('POS007', 'Senior Developer', 'SD', 'Engineering', 'Development', 'Senior', 'G5', FALSE, TRUE),
    ('POS008', 'Team Lead', 'TL', 'Engineering', 'Leadership', 'Lead', 'G6', TRUE, TRUE),
    ('POS009', 'Business Analyst', 'BA', 'Business', 'Analysis', 'Senior', 'G5', FALSE, TRUE),
    ('POS010', 'Project Manager', 'PM', 'Management', 'Project Management', 'Manager', 'G7', TRUE, TRUE)
ON CONFLICT (department_id, valid_from) DO NOTHING;

-- Insert sample positions
INSERT INTO dim_position (position_id, position_title, position_code, job_family, job_function, job_level, is_management_role, is_current)
VALUES
    ('POS001', 'Software Engineer', 'SE', 'Engineering', 'Development', 'Senior', FALSE, TRUE),
    ('POS002', 'HR Manager', 'HRM', 'Human Resources', 'Management', 'Manager', TRUE, TRUE),
    ('POS003', 'Financial Analyst', 'FA', 'Finance', 'Analysis', 'Junior', FALSE, TRUE),
    ('POS004', 'Marketing Specialist', 'MS', 'Marketing', 'Marketing', 'Senior', FALSE, TRUE),
    ('POS005', 'Operations Director', 'OD', 'Operations', 'Management', 'Director', TRUE, TRUE),
    ('POS006', 'Junior Developer', 'JD', 'Engineering', 'Development', 'Junior', FALSE, TRUE),
    ('POS007', 'Senior Developer', 'SD', 'Engineering', 'Development', 'Senior', FALSE, TRUE),
    ('POS008', 'Team Lead', 'TL', 'Engineering', 'Leadership', 'Lead', TRUE, TRUE),
    ('POS009', 'Business Analyst', 'BA', 'Business', 'Analysis', 'Senior', FALSE, TRUE),
    ('POS010', 'Project Manager', 'PM', 'Management', 'Project Management', 'Manager', TRUE, TRUE)
ON CONFLICT (position_id, valid_from) DO NOTHING;

-- Insert sample locations
INSERT INTO dim_location (location_id, location_name, city, country, region, is_active)
VALUES 
    ('LOC001', 'Ho Chi Minh Office', 'Ho Chi Minh City', 'Vietnam', 'Southeast Asia', TRUE),
    ('LOC002', 'Hanoi Office', 'Hanoi', 'Vietnam', 'Southeast Asia', TRUE),
    ('LOC003', 'Da Nang Office', 'Da Nang', 'Vietnam', 'Southeast Asia', TRUE)
ON CONFLICT (location_id) DO NOTHING;

-- Insert sample compensation bands
INSERT INTO dim_compensation (compensation_id, salary_band, pay_grade, currency, pay_frequency, is_current)
VALUES 
    ('COMP001', 'Band 3', 'G3', 'VND', 'Monthly', TRUE),
    ('COMP002', 'Band 5', 'G5', 'VND', 'Monthly', TRUE),
    ('COMP003', 'Band 7', 'G7', 'VND', 'Monthly', TRUE),
    ('COMP004', 'Band 9', 'G9', 'VND', 'Monthly', TRUE)
ON CONFLICT (compensation_id, valid_from) DO NOTHING;

COMMIT;