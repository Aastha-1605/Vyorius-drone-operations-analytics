-- ==========================================================
-- VYORIUS DRONE OPERATIONS ANALYTICS | MySQL 8.0
-- Dataset: 15,000 mission & telemetry records
-- ==========================================================

CREATE DATABASE IF NOT EXISTS vyorius_analytics;
USE vyorius_analytics;

-- Import the CSV into a table named drone_operations.
-- Recommended approach: MySQL Workbench > Table Data Import Wizard.
-- Keep mission_date as DATE and numeric columns as DECIMAL/FLOAT.

-- 01. DATA QUALITY -----------------------------------------------------------
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT mission_id) AS unique_missions,
       SUM(CASE WHEN customer_rating IS NULL THEN 1 ELSE 0 END) AS missing_ratings,
       SUM(CASE WHEN failure_reason IS NULL OR failure_reason='' THEN 1 ELSE 0 END) AS missing_failure_reason
FROM drone_operations;

-- 02. EXECUTIVE KPI SCORECARD ------------------------------------------------
SELECT
    COUNT(*) AS total_missions,
    COUNT(DISTINCT drone_id) AS unique_drones,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(100*AVG(mission_status='Completed'),2) AS mission_success_rate_pct,
    ROUND(100*AVG(mission_status='Failed'),2) AS failure_rate_pct,
    ROUND(100*AVG(mission_status='Delayed'),2) AS delay_rate_pct,
    ROUND(AVG(battery_health_pct),2) AS avg_battery_health_pct,
    ROUND(SUM(revenue_inr),2) AS revenue_inr,
    ROUND(SUM(estimated_operating_cost_inr),2) AS operating_cost_inr,
    ROUND(SUM(gross_margin_inr),2) AS gross_margin_inr,
    ROUND(100*SUM(gross_margin_inr)/NULLIF(SUM(revenue_inr),0),2) AS gross_margin_pct
FROM drone_operations;

-- 03. MONTHLY REVENUE / MRR PROXY -------------------------------------------
-- The source has mission revenue, not subscription invoice MRR.
-- Therefore this is deliberately labelled a recurring-revenue / MRR proxy.
SELECT DATE_FORMAT(mission_date,'%Y-%m') AS month,
       COUNT(*) AS missions,
       COUNT(DISTINCT customer_id) AS active_customers,
       ROUND(SUM(revenue_inr),2) AS mrr_proxy_inr,
       ROUND(100*AVG(mission_status='Completed'),2) AS success_rate_pct
FROM drone_operations
GROUP BY DATE_FORMAT(mission_date,'%Y-%m')
ORDER BY month;

-- 04. YEAR-OVER-YEAR REVENUE -------------------------------------------------
WITH yearly AS (
    SELECT year, SUM(revenue_inr) revenue
    FROM drone_operations GROUP BY year
)
SELECT year, revenue,
       ROUND(100*(revenue-LAG(revenue) OVER(ORDER BY year))/
             NULLIF(LAG(revenue) OVER(ORDER BY year),0),2) AS yoy_growth_pct
FROM yearly;

-- 05. MANUFACTURER RELIABILITY -----------------------------------------------
SELECT manufacturer,
       COUNT(*) missions,
       ROUND(100*AVG(mission_status='Completed'),2) success_rate_pct,
       ROUND(AVG(battery_health_pct),2) avg_battery_health_pct,
       ROUND(SUM(downtime_hours),2) downtime_hours,
       ROUND(SUM(maintenance_cost_inr),2) maintenance_cost_inr
FROM drone_operations
GROUP BY manufacturer
ORDER BY success_rate_pct DESC;

-- 06. DRONE MODEL SCORECARD --------------------------------------------------
SELECT manufacturer, drone_model,
       COUNT(*) missions,
       ROUND(100*AVG(mission_status='Completed'),2) success_rate_pct,
       ROUND(AVG(battery_health_pct),2) battery_health_pct,
       ROUND(SUM(revenue_inr),2) revenue_inr,
       ROUND(SUM(gross_margin_inr),2) margin_inr
FROM drone_operations
GROUP BY manufacturer, drone_model
HAVING COUNT(*) >= 50
ORDER BY success_rate_pct DESC, margin_inr DESC;

-- 07. FAILURE ROOT CAUSES ----------------------------------------------------
SELECT failure_reason, COUNT(*) failed_missions
FROM drone_operations
WHERE mission_status='Failed'
GROUP BY failure_reason
ORDER BY failed_missions DESC;

-- 08. DELAY ROOT CAUSES ------------------------------------------------------
SELECT failure_reason, COUNT(*) delayed_missions,
       ROUND(AVG(delay_minutes),2) avg_delay_minutes
FROM drone_operations
WHERE mission_status='Delayed'
GROUP BY failure_reason
ORDER BY delayed_missions DESC;

-- 09. WEATHER RISK -----------------------------------------------------------
SELECT weather_condition, COUNT(*) missions,
       ROUND(100*AVG(mission_status='Completed'),2) success_rate_pct,
       ROUND(100*AVG(mission_status='Failed'),2) failure_rate_pct,
       ROUND(AVG(delay_minutes),2) avg_delay_min
FROM drone_operations
GROUP BY weather_condition
ORDER BY failure_rate_pct DESC;

-- 10. WIND-SPEED RISK BANDS --------------------------------------------------
SELECT CASE
         WHEN wind_speed_mps < 4 THEN '<4 m/s'
         WHEN wind_speed_mps < 8 THEN '4-8 m/s'
         WHEN wind_speed_mps < 12 THEN '8-12 m/s'
         ELSE '12+ m/s'
       END wind_band,
       COUNT(*) missions,
       ROUND(100*AVG(mission_status='Completed'),2) success_rate_pct,
       ROUND(100*AVG(mission_status='Failed'),2) failure_rate_pct
FROM drone_operations
GROUP BY wind_band
ORDER BY MIN(wind_speed_mps);

-- 11. BATTERY HEALTH RISK BANDS ----------------------------------------------
SELECT CASE
         WHEN battery_health_pct >= 95 THEN '95-100%'
         WHEN battery_health_pct >= 90 THEN '90-95%'
         WHEN battery_health_pct >= 85 THEN '85-90%'
         ELSE '<85%'
       END battery_band,
       COUNT(*) missions,
       ROUND(100*AVG(mission_status='Completed'),2) success_rate_pct,
       ROUND(AVG(downtime_hours),2) avg_downtime_hours,
       ROUND(100*AVG(maintenance_due IN ('Yes','True','1')),2) maintenance_due_pct
FROM drone_operations
GROUP BY battery_band
ORDER BY MIN(battery_health_pct) DESC;

-- 12. MAINTENANCE BURDEN BY MANUFACTURER ------------------------------------
SELECT manufacturer,
       ROUND(100*AVG(maintenance_due IN ('Yes','True','1')),2) maintenance_due_pct,
       ROUND(SUM(maintenance_cost_inr),2) maintenance_cost_inr,
       ROUND(SUM(downtime_hours),2) downtime_hours,
       ROUND(AVG(days_since_last_service),2) avg_days_since_service
FROM drone_operations
GROUP BY manufacturer
ORDER BY maintenance_cost_inr DESC;

-- 13. TOP DRONES BY PROFIT ---------------------------------------------------
SELECT drone_id, manufacturer, drone_model,
       COUNT(*) missions,
       ROUND(SUM(revenue_inr),2) revenue_inr,
       ROUND(SUM(gross_margin_inr),2) gross_margin_inr,
       ROUND(100*SUM(gross_margin_inr)/NULLIF(SUM(revenue_inr),0),2) margin_pct
FROM drone_operations
GROUP BY drone_id,manufacturer,drone_model
ORDER BY gross_margin_inr DESC
LIMIT 20;

-- 14. UNDERUTILIZED DRONES ---------------------------------------------------
WITH fleet AS (
    SELECT drone_id, manufacturer, drone_model,
           COUNT(*) missions,
           SUM(downtime_hours) downtime,
           SUM(gross_margin_inr) margin
    FROM drone_operations
    GROUP BY drone_id,manufacturer,drone_model
)
SELECT * FROM fleet
WHERE missions < (SELECT AVG(missions) FROM fleet)
ORDER BY missions, downtime DESC
LIMIT 50;

-- 15. INDUSTRY REVENUE MIX ---------------------------------------------------
SELECT customer_industry,
       COUNT(*) missions,
       ROUND(SUM(revenue_inr),2) revenue_inr,
       ROUND(SUM(gross_margin_inr),2) gross_margin_inr,
       ROUND(100*SUM(gross_margin_inr)/NULLIF(SUM(revenue_inr),0),2) margin_pct,
       ROUND(AVG(customer_rating),2) avg_rating
FROM drone_operations
GROUP BY customer_industry
ORDER BY revenue_inr DESC;

-- 16. SUBSCRIPTION PLAN ECONOMICS -------------------------------------------
SELECT subscription_plan,
       COUNT(DISTINCT customer_id) customers,
       COUNT(*) missions,
       ROUND(SUM(revenue_inr),2) revenue_inr,
       ROUND(SUM(gross_margin_inr),2) gross_margin_inr,
       ROUND(AVG(customer_rating),2) avg_rating
FROM drone_operations
GROUP BY subscription_plan
ORDER BY revenue_inr DESC;

-- 17. CUSTOMER RETENTION PROXY -----------------------------------------------
-- Retained = customer active in consecutive calendar years.
WITH cy AS (
    SELECT DISTINCT customer_id, year FROM drone_operations
), pairs AS (
    SELECT a.year,
           COUNT(DISTINCT a.customer_id) base_customers,
           COUNT(DISTINCT b.customer_id) retained_customers
    FROM cy a
    LEFT JOIN cy b ON a.customer_id=b.customer_id AND b.year=a.year+1
    GROUP BY a.year
)
SELECT year, base_customers, retained_customers,
       ROUND(100*retained_customers/NULLIF(base_customers,0),2) retention_proxy_pct
FROM pairs ORDER BY year;

-- 18. CUSTOMER VALUE SEGMENTATION -------------------------------------------
WITH c AS (
    SELECT customer_id,
           COUNT(*) missions,
           SUM(revenue_inr) revenue,
           AVG(customer_rating) rating
    FROM drone_operations GROUP BY customer_id
)
SELECT customer_id, missions, ROUND(revenue,2) revenue_inr, ROUND(rating,2) rating,
       CASE
         WHEN NTILE(4) OVER(ORDER BY revenue DESC)=1 THEN 'Platinum'
         WHEN NTILE(4) OVER(ORDER BY revenue DESC)=2 THEN 'Gold'
         WHEN NTILE(4) OVER(ORDER BY revenue DESC)=3 THEN 'Silver'
         ELSE 'Bronze'
       END value_segment
FROM c
ORDER BY revenue DESC;

-- 19. OPERATOR PERFORMANCE ---------------------------------------------------
SELECT operator_id,
       COUNT(*) missions,
       ROUND(100*AVG(mission_status='Completed'),2) success_rate_pct,
       ROUND(AVG(manual_interventions),2) avg_manual_interventions,
       ROUND(AVG(delay_minutes),2) avg_delay_min
FROM drone_operations
GROUP BY operator_id
HAVING COUNT(*) >= 20
ORDER BY success_rate_pct DESC, avg_manual_interventions;

-- 20. RTK EFFECTIVENESS ------------------------------------------------------
SELECT rtk_used, COUNT(*) missions,
       ROUND(AVG(gps_accuracy_m),3) avg_gps_accuracy_m,
       ROUND(100*AVG(mission_status='Completed'),2) success_rate_pct
FROM drone_operations
GROUP BY rtk_used;

-- 21. PAYLOAD UTILIZATION ----------------------------------------------------
SELECT mission_type,
       ROUND(AVG(payload_utilization_pct),2) avg_payload_util_pct,
       ROUND(100*AVG(mission_status='Completed'),2) success_rate_pct,
       ROUND(AVG(revenue_inr),2) revenue_per_mission
FROM drone_operations
GROUP BY mission_type
ORDER BY avg_payload_util_pct DESC;

-- 22. MISSION TYPE PROFITABILITY --------------------------------------------
SELECT mission_type, COUNT(*) missions,
       ROUND(SUM(revenue_inr),2) revenue,
       ROUND(SUM(estimated_operating_cost_inr),2) operating_cost,
       ROUND(SUM(gross_margin_inr),2) gross_margin,
       ROUND(100*SUM(gross_margin_inr)/NULLIF(SUM(revenue_inr),0),2) margin_pct
FROM drone_operations
GROUP BY mission_type
ORDER BY gross_margin DESC;

-- 23. STATE / CITY OPPORTUNITY ------------------------------------------------
SELECT state, city, COUNT(*) missions,
       COUNT(DISTINCT customer_id) customers,
       ROUND(SUM(revenue_inr),2) revenue,
       ROUND(100*AVG(mission_status='Completed'),2) success_rate_pct
FROM drone_operations
GROUP BY state,city
ORDER BY revenue DESC
LIMIT 30;

-- 24. ROLLING 3-MONTH REVENUE ------------------------------------------------
WITH m AS (
 SELECT DATE_FORMAT(mission_date,'%Y-%m-01') month_start,
        SUM(revenue_inr) revenue
 FROM drone_operations
 GROUP BY DATE_FORMAT(mission_date,'%Y-%m-01')
)
SELECT month_start, revenue,
       ROUND(AVG(revenue) OVER(ORDER BY month_start ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2)
       AS rolling_3m_revenue
FROM m ORDER BY month_start;

-- 25. MANAGEMENT EXCEPTION LIST ----------------------------------------------
SELECT mission_id, mission_date, drone_id, manufacturer, mission_type,
       mission_status, failure_reason, battery_health_pct, wind_speed_mps,
       signal_strength_pct, gps_accuracy_m, maintenance_due, downtime_hours
FROM drone_operations
WHERE mission_status IN ('Failed','Delayed')
   OR battery_health_pct < 85
   OR signal_strength_pct < 60
   OR maintenance_due IN ('Yes','True','1')
ORDER BY mission_date DESC, downtime_hours DESC;
