USE sql_final_project;

SHOW TABLES;

SELECT *
FROM superstore;

-- 1. Which regions generated the highest revenue


-- QUESTION 1: Which regions generated the highest revenue?

SELECT
    Region,
    ROUND(SUM(Sales), 2) AS total_revenue,
    ROUND(
        SUM(Sales) * 100.0 / SUM(SUM(Sales)) OVER (), 1
    ) AS sales_percentage,
    RANK() OVER (ORDER BY SUM(Sales) DESC) AS revenue_rank
FROM superstore
GROUP BY Region
ORDER BY revenue_rank ASC;


--  The query ranks all regions by total revenue, from highest to lowest, and calculates each region's share of overall sales.

-- The Western Region generated the highest reported revenue of $713,471.34.
 -- However, the Southern Region revenue and the percentages for the top two regions need to be verified against
 -- the query output before the final report is presented




-- 2. Which regions met, exceeded or missed their targets?

WITH regional_year_sales AS (
    SELECT
        YEAR(STR_TO_DATE(`Order Date`, '%m/%d/%Y')) AS order_year,
        `Region` AS region,
        SUM(`Sales`) AS actual_revenue
    FROM superstore
    WHERE STR_TO_DATE(`Order Date`, '%m/%d/%Y') IS NOT NULL
    GROUP BY
        YEAR(STR_TO_DATE(`Order Date`, '%m/%d/%Y')),
        `Region`
),
regional_performance AS (
    SELECT
        current.order_year,
        current.region,
        current.actual_revenue,
        previous.actual_revenue * 1.10 AS revenue_target
    FROM regional_year_sales current
    JOIN regional_year_sales previous
        ON current.region = previous.region
        AND current.order_year = previous.order_year + 1
    WHERE current.order_year BETWEEN 2015 AND 2017
)
SELECT
    order_year,
    region,
    ROUND(actual_revenue, 2) AS actual_revenue,
    ROUND(revenue_target, 2) AS revenue_target,
    ROUND(actual_revenue * 100.0 / NULLIF(revenue_target, 0), 1)
        AS achievement_pct,
    CASE
        WHEN actual_revenue > revenue_target THEN 'Exceeded'
        WHEN actual_revenue = revenue_target THEN 'Met'
        ELSE 'Missed'
    END AS target_status
FROM regional_performance
ORDER BY order_year, achievement_pct DESC;


-- The query compares annual regional revenue for 2015–2017 with an assumed target equal to 110% of the previous year's revenue.
-- It returns the target achievement percentage and classifies each region as Exceeded, Met, or Missed.

-- The results identify which regions achieved their assumed revenue targets in each year. 
-- The annual comparison should be used to identify the most consistent region and any regions requiring further investigation. 
-- The figures currently in the comments are incomplete, so the final regional findings must be taken from the query output.



-- 3 What is the revenue gap, and what percentage of the target was achieved?

WITH regional_year_sales AS (
    SELECT
        YEAR(STR_TO_DATE(`Order Date`, '%m/%d/%Y')) AS order_year,
        `Region` AS region,
        SUM(`Sales`) AS actual_revenue
    FROM superstore
    WHERE STR_TO_DATE(`Order Date`, '%m/%d/%Y') IS NOT NULL
    GROUP BY
        YEAR(STR_TO_DATE(`Order Date`, '%m/%d/%Y')),
        `Region`
),
regional_performance AS (
    SELECT
        current.order_year,
        current.region,
        current.actual_revenue,
        previous.actual_revenue * 1.10 AS revenue_target
    FROM regional_year_sales current
    JOIN regional_year_sales previous
        ON current.region = previous.region
        AND current.order_year = previous.order_year + 1
    WHERE current.order_year BETWEEN 2015 AND 2017
)
SELECT
    order_year,
    region,
    ROUND(actual_revenue, 2) AS actual_revenue,
    ROUND(revenue_target, 2) AS revenue_target,
    ROUND(actual_revenue - revenue_target, 2) AS variance,
    ROUND(
        actual_revenue * 100.0 / NULLIF(revenue_target, 0), 1
    ) AS achievement_pct,
    RANK() OVER (
        PARTITION BY order_year
        ORDER BY actual_revenue / NULLIF(revenue_target, 0) DESC
    ) AS performance_rank
FROM regional_performance
ORDER BY order_year, performance_rank;

-- The query returns actual revenue, the assumed target, revenue variance, achievement percentage,
-- and a performance ranking for each region-year combination.

--  East reportedly exceeded its assumed target in 2015 by $155,185.86, with a reported achievement of 109.9%. 
-- These figures should be checked against the SQL output before publication. 
-- The largest shortfall and the lowest-ranked region should also be identified from the results.



-- 4 Do weaker regions have fewer orders, smaller orders, or heavier discounts?

WITH regional_year_sales AS (
    SELECT
        YEAR(STR_TO_DATE(`Order Date`, '%m/%d/%Y')) AS order_year,
        `Region` AS region,
        SUM(`Sales`) AS actual_revenue,
        SUM(`Profit`) AS total_profit,
        COUNT(DISTINCT `Order ID`) AS orders,
        AVG(`Discount`) AS avg_discount
    FROM superstore
    WHERE STR_TO_DATE(`Order Date`, '%m/%d/%Y') IS NOT NULL
    GROUP BY
        YEAR(STR_TO_DATE(`Order Date`, '%m/%d/%Y')),
        `Region`
),
order_values AS (
    SELECT
        YEAR(STR_TO_DATE(`Order Date`, '%m/%d/%Y')) AS order_year,
        `Region` AS region,
        `Order ID` AS order_id,
        SUM(`Sales`) AS order_sales
    FROM superstore
    WHERE STR_TO_DATE(`Order Date`, '%m/%d/%Y') IS NOT NULL
    GROUP BY
        YEAR(STR_TO_DATE(`Order Date`, '%m/%d/%Y')),
        `Region`,
        `Order ID`
),
average_orders AS (
    SELECT
        order_year,
        region,
        AVG(order_sales) AS avg_order_value
    FROM order_values
    GROUP BY order_year, region
),
regional_performance AS (
    SELECT
        current.*,
        previous.actual_revenue * 1.10 AS revenue_target
    FROM regional_year_sales current
    JOIN regional_year_sales previous
        ON current.region = previous.region
        AND current.order_year = previous.order_year + 1
    WHERE current.order_year BETWEEN 2015 AND 2017
)
SELECT
    p.order_year,
    p.region,
    ROUND(
        p.actual_revenue * 100.0 / NULLIF(p.revenue_target, 0), 1
    ) AS achievement_pct,
    p.orders,
    ROUND(a.avg_order_value, 2) AS avg_order_value,
    ROUND(p.avg_discount * 100, 1) AS avg_discount_pct,
    ROUND(p.total_profit, 2) AS total_profit,
    ROUND(
        p.total_profit * 100.0 / NULLIF(p.actual_revenue, 0), 1
    ) AS profit_margin_pct,
    RANK() OVER (
        PARTITION BY p.order_year
        ORDER BY p.actual_revenue / NULLIF(p.revenue_target, 0) DESC
    ) AS performance_rank
FROM regional_performance p
JOIN average_orders a
    ON p.order_year = a.order_year
    AND p.region = a.region
ORDER BY p.order_year, performance_rank;




-- The query compares target achievement with the number of orders, average order value, average discount, total profit, 
-- and profit margin for each region and year.

-- The analysis helps investigate whether lower-performing regions also have fewer orders, lower average order values, or higher average discounts. 
-- The reported Central Region achievement of 5.6% in 2017 should be verified before it is used.
--  Any relationship between these metrics should be described as an association rather than proof of cause.



-- 5 How does regional performance change by quarter?


WITH quarterly_sales AS (
    SELECT
        YEAR(STR_TO_DATE(`Order Date`, '%m/%d/%Y')) AS order_year,
        QUARTER(STR_TO_DATE(`Order Date`, '%m/%d/%Y')) AS order_quarter,
        `Region` AS region,
        SUM(`Sales`) AS actual_revenue,
        COUNT(DISTINCT `Order ID`) AS orders
    FROM superstore
    WHERE STR_TO_DATE(`Order Date`, '%m/%d/%Y') IS NOT NULL
    GROUP BY
        YEAR(STR_TO_DATE(`Order Date`, '%m/%d/%Y')),
        QUARTER(STR_TO_DATE(`Order Date`, '%m/%d/%Y')),
        `Region`
)
SELECT
    current.order_year,
    current.order_quarter,
    current.region,
    ROUND(current.actual_revenue, 2) AS actual_revenue,
    ROUND(previous.actual_revenue * 1.10, 2) AS revenue_target,
    ROUND(
        current.actual_revenue - previous.actual_revenue * 1.10, 2
    ) AS variance,
    ROUND(
        current.actual_revenue * 100.0 /
        NULLIF(previous.actual_revenue * 1.10, 0), 1
    ) AS achievement_pct,
    current.orders
FROM quarterly_sales current
JOIN quarterly_sales previous
    ON current.region = previous.region
    AND current.order_year = previous.order_year + 1
    AND current.order_quarter = previous.order_quarter
WHERE current.order_year BETWEEN 2015 AND 2017
ORDER BY
    current.order_year,
    current.order_quarter,
    current.region;

-- The query compares quarterly revenue for each region in 2015–2017 with the corresponding quarter in the previous year, increased by 10%.
-- It reports actual revenue, the assumed target, variance, achievement percentage, and order count.

-- The quarterly results can identify the strongest and weakest quarters and show which regions experience the greatest variation in target achievement.
--  The current claims about Quarter 1, Quarter 2, Central, and South must be confirmed using the output. 
-- Refer to the periods as Q1, Q2, Q3, and Q4 in the final report.





