CREATE DATABASE IF NOT EXISTS healthcare_analytics;
USE healthcare_analytics;

DROP TABLE IF EXISTS patient_flow;

CREATE TABLE patient_flow (
    PatientID           VARCHAR(15)    NOT NULL,
    AdmissionDate       DATE           NOT NULL,
    AdmissionTime       TIME,
    PatientName         VARCHAR(60),
    Gender              VARCHAR(10),
    Age                 TINYINT UNSIGNED,
    Race                VARCHAR(50),
    DeptReferral        VARCHAR(60),
    AdmissionFlag       VARCHAR(20),
    SatisfactionScore   DECIMAL(4,1),
    WaitTimeMin         TINYINT UNSIGNED,
    WaitCategory        VARCHAR(10),
    AgeGroup            VARCHAR(10),
    AdmissionStatus     VARCHAR(20),
    LastName            VARCHAR(40),
    Month               VARCHAR(7),
    DayOfWeek           VARCHAR(10),
    PRIMARY KEY (PatientID, AdmissionDate, AdmissionTime)
);

-- NOTE: Import the cleaned CSV from Excel output via:
-- LOAD DATA INFILE '/path/to/Healthcare_Patient_Flow_Cleaned.xlsx (Cleaned Data sheet exported as CSV)'
-- INTO TABLE patient_flow ...
-- Or use MySQL Workbench Table Data Import Wizard on the Cleaned Data sheet.

RENAME TABLE healthcare_patient_flow_cleaned TO patient_flow;

-- ============================================================
-- SECTION A — OVERVIEW & VOLUME
-- ============================================================

-- A1. Total patient visits, admission rate, avg wait & satisfaction
SELECT
    COUNT(*)                                                     AS total_visits,
    SUM(AdmissionFlag = 'Admission')                             AS admitted,
    SUM(AdmissionFlag = 'Not Admission')                         AS not_admitted,
    ROUND(SUM(AdmissionFlag = 'Admission') / COUNT(*) * 100, 1) AS admission_rate_pct,
    ROUND(AVG(WaitTimeMin), 1)                                   AS avg_wait_min,
    ROUND(AVG(SatisfactionScore), 2)                             AS avg_satisfaction
FROM patient_flow;


-- A2. Monthly visit volume with MoM change
SELECT
    Month,
    COUNT(*)                                          AS visits,
    LAG(COUNT(*)) OVER (ORDER BY Month)               AS prev_month,
    COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY Month)   AS mom_change,
    ROUND(
        (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY Month))
        / LAG(COUNT(*)) OVER (ORDER BY Month) * 100, 1
    )                                                  AS mom_pct_change
FROM patient_flow
GROUP BY Month
ORDER BY Month;


-- A3. Day-of-week volume (busiest days)
SELECT
    DayOfWeek,
    COUNT(*)                               AS visits,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS pct_of_total
FROM patient_flow
GROUP BY DayOfWeek
ORDER BY FIELD(DayOfWeek,
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday');


-- ============================================================
-- SECTION B — WAIT TIME ANALYSIS
-- ============================================================

-- B1. Wait time distribution by category
SELECT
    WaitCategory,
    COUNT(*)                               AS visits,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS pct_total,
    ROUND(AVG(WaitTimeMin), 1)             AS avg_wait_min,
    MIN(WaitTimeMin)                       AS min_wait,
    MAX(WaitTimeMin)                       AS max_wait
FROM patient_flow
GROUP BY WaitCategory;


-- B2. Average wait time by department (worst → best)
SELECT
    DeptReferral,
    COUNT(*)                               AS visits,
    ROUND(AVG(WaitTimeMin), 1)             AS avg_wait_min,
    MIN(WaitTimeMin)                       AS min_wait,
    MAX(WaitTimeMin)                       AS max_wait,
    ROUND(SUM(WaitCategory = 'Delayed') / COUNT(*) * 100, 1) AS pct_delayed
FROM patient_flow
GROUP BY DeptReferral
ORDER BY avg_wait_min DESC;


-- B3. Wait time by age group and gender
SELECT
    AgeGroup,
    Gender,
    COUNT(*)                               AS visits,
    ROUND(AVG(WaitTimeMin), 1)             AS avg_wait_min,
    ROUND(SUM(WaitCategory = 'Delayed') / COUNT(*) * 100, 1) AS pct_delayed
FROM patient_flow
GROUP BY AgeGroup, Gender
ORDER BY AgeGroup, Gender;


-- B4. Monthly trend: average wait time over time
SELECT
    Month,
    ROUND(AVG(WaitTimeMin), 1)             AS avg_wait_min,
    ROUND(AVG(WaitTimeMin)
        - LAG(AVG(WaitTimeMin)) OVER (ORDER BY Month), 2) AS change_from_prev
FROM patient_flow
GROUP BY Month
ORDER BY Month;


-- ============================================================
-- SECTION C — PATIENT SATISFACTION
-- ============================================================

-- C1. Satisfaction score distribution
SELECT
    FLOOR(SatisfactionScore)               AS score_bucket,
    COUNT(*)                               AS count,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS pct
FROM patient_flow
WHERE SatisfactionScore IS NOT NULL
GROUP BY score_bucket
ORDER BY score_bucket;


-- C2. Avg satisfaction by department
SELECT
    DeptReferral,
    COUNT(SatisfactionScore)               AS rated_visits,
    ROUND(AVG(SatisfactionScore), 2)       AS avg_satisfaction,
    ROUND(MIN(SatisfactionScore), 1)       AS min_score,
    ROUND(MAX(SatisfactionScore), 1)       AS max_score
FROM patient_flow
WHERE SatisfactionScore IS NOT NULL
GROUP BY DeptReferral
ORDER BY avg_satisfaction DESC;


-- C3. Satisfaction vs wait time buckets (does longer wait hurt scores?)
SELECT
    CASE
        WHEN WaitTimeMin <= 20 THEN '≤20 min'
        WHEN WaitTimeMin <= 30 THEN '21–30 min'
        WHEN WaitTimeMin <= 45 THEN '31–45 min'
        ELSE '46–60 min'
    END                                    AS wait_bucket,
    COUNT(SatisfactionScore)               AS rated_visits,
    ROUND(AVG(SatisfactionScore), 2)       AS avg_satisfaction
FROM patient_flow
WHERE SatisfactionScore IS NOT NULL
GROUP BY wait_bucket
ORDER BY MIN(WaitTimeMin);


-- C4. Satisfaction by age group
SELECT
    AgeGroup,
    COUNT(SatisfactionScore)               AS rated_visits,
    ROUND(AVG(SatisfactionScore), 2)       AS avg_satisfaction
FROM patient_flow
WHERE SatisfactionScore IS NOT NULL
GROUP BY AgeGroup
ORDER BY avg_satisfaction DESC;


-- ============================================================
-- SECTION D — DEMOGRAPHIC ANALYSIS
-- ============================================================

-- D1. Visits and admission rate by race
SELECT
    Race,
    COUNT(*)                               AS visits,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS pct_of_visits,
    SUM(AdmissionFlag = 'Admission')       AS admitted,
    ROUND(SUM(AdmissionFlag = 'Admission') / COUNT(*) * 100, 1) AS admission_rate_pct,
    ROUND(AVG(WaitTimeMin), 1)             AS avg_wait_min
FROM patient_flow
GROUP BY Race
ORDER BY visits DESC;


-- D2. Gender split
SELECT
    Gender,
    COUNT(*)                               AS visits,
    ROUND(AVG(WaitTimeMin), 1)             AS avg_wait_min,
    ROUND(AVG(SatisfactionScore), 2)       AS avg_satisfaction,
    ROUND(SUM(AdmissionFlag = 'Admission') / COUNT(*) * 100, 1) AS admission_rate_pct
FROM patient_flow
GROUP BY Gender;


-- D3. Age group breakdown
SELECT
    AgeGroup,
    COUNT(*)                               AS visits,
    ROUND(AVG(Age), 1)                     AS avg_age,
    ROUND(AVG(WaitTimeMin), 1)             AS avg_wait_min,
    ROUND(AVG(SatisfactionScore), 2)       AS avg_satisfaction,
    ROUND(SUM(AdmissionFlag = 'Admission') / COUNT(*) * 100, 1) AS admission_rate_pct
FROM patient_flow
GROUP BY AgeGroup
ORDER BY FIELD(AgeGroup, 'Child', 'Adult', 'Senior');


-- ============================================================
-- SECTION E — ADVANCED / WINDOW FUNCTION QUERIES
-- ============================================================

-- E1. Rank departments by average wait time (RANK window function)
SELECT
    DeptReferral,
    ROUND(AVG(WaitTimeMin), 1)             AS avg_wait_min,
    RANK() OVER (ORDER BY AVG(WaitTimeMin) DESC) AS wait_rank
FROM patient_flow
GROUP BY DeptReferral;


-- E2. Running total of monthly admissions
SELECT
    Month,
    SUM(AdmissionFlag = 'Admission')       AS monthly_admissions,
    SUM(SUM(AdmissionFlag = 'Admission'))
        OVER (ORDER BY Month ROWS UNBOUNDED PRECEDING) AS running_total_admissions
FROM patient_flow
GROUP BY Month
ORDER BY Month;


-- E3. Flag patients with above-average wait times (CTE + subquery)
WITH dept_avg AS (
    SELECT
        DeptReferral,
        ROUND(AVG(WaitTimeMin), 1) AS dept_avg_wait
    FROM patient_flow
    GROUP BY DeptReferral
)
SELECT
    p.PatientID,
    p.AdmissionDate,
    p.DeptReferral,
    p.WaitTimeMin,
    d.dept_avg_wait,
    p.WaitTimeMin - d.dept_avg_wait AS wait_above_dept_avg
FROM patient_flow p
JOIN dept_avg d ON p.DeptReferral = d.DeptReferral
WHERE p.WaitTimeMin > d.dept_avg_wait
ORDER BY wait_above_dept_avg DESC
LIMIT 100;


-- E4. Patient satisfaction percentile by race (NTILE)
SELECT
    PatientID,
    Race,
    SatisfactionScore,
    NTILE(4) OVER (PARTITION BY Race ORDER BY SatisfactionScore) AS quartile
FROM patient_flow
WHERE SatisfactionScore IS NOT NULL
ORDER BY Race, quartile;


-- E5. Department share of total delayed visits
SELECT
    DeptReferral,
    SUM(WaitCategory = 'Delayed')          AS delayed_visits,
    SUM(SUM(WaitCategory = 'Delayed')) OVER () AS total_delayed,
    ROUND(
        SUM(WaitCategory = 'Delayed')
        / SUM(SUM(WaitCategory = 'Delayed')) OVER () * 100, 1
    )                                       AS share_of_all_delayed_pct
FROM patient_flow
GROUP BY DeptReferral
ORDER BY delayed_visits DESC;


-- ============================================================
-- SECTION F — VIEWS FOR POWER BI
-- ============================================================

-- F1. View: Monthly KPI summary (use as Power BI data source)
CREATE OR REPLACE VIEW vw_monthly_kpi AS
SELECT
    Month,
    COUNT(*)                                                     AS total_visits,
    SUM(AdmissionFlag = 'Admission')                             AS admissions,
    ROUND(SUM(AdmissionFlag = 'Admission') / COUNT(*) * 100, 1) AS admission_rate_pct,
    ROUND(AVG(WaitTimeMin), 1)                                   AS avg_wait_min,
    ROUND(AVG(SatisfactionScore), 2)                             AS avg_satisfaction,
    SUM(WaitCategory = 'Delayed')                                AS delayed_visits,
    ROUND(SUM(WaitCategory = 'Delayed') / COUNT(*) * 100, 1)    AS pct_delayed
FROM patient_flow
GROUP BY Month;

SELECT *
FROM vw_monthly_kpi;


-- F2. View: Department performance (use in Power BI)
CREATE OR REPLACE VIEW vw_dept_performance AS
SELECT
    DeptReferral,
    COUNT(*)                                                     AS total_visits,
    ROUND(AVG(WaitTimeMin), 1)                                   AS avg_wait_min,
    ROUND(AVG(SatisfactionScore), 2)                             AS avg_satisfaction,
    ROUND(SUM(WaitCategory = 'Delayed') / COUNT(*) * 100, 1)    AS pct_delayed,
    ROUND(SUM(AdmissionFlag = 'Admission') / COUNT(*) * 100, 1) AS admission_rate_pct
FROM patient_flow
GROUP BY DeptReferral;

SELECT *
FROM vw_dept_performance;

-- F3. View: Demographic summary for Power BI
CREATE OR REPLACE VIEW vw_demographic_summary AS
SELECT
    Race,
    Gender,
    AgeGroup,
    COUNT(*)                                                     AS visits,
    ROUND(AVG(WaitTimeMin), 1)                                   AS avg_wait_min,
    ROUND(AVG(SatisfactionScore), 2)                             AS avg_satisfaction,
    ROUND(SUM(AdmissionFlag = 'Admission') / COUNT(*) * 100, 1) AS admission_rate_pct
FROM patient_flow
GROUP BY Race, Gender, AgeGroup;

SELECT *
FROM vw_demographic_summary;

-- ============================================================
-- END OF SCRIPT
-- ============================================================