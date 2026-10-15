-- =====================================================================
-- LEVEL 3: PROFESSIONAL  (Q21-Q30)
-- Subquery, CTE, window functions, RFM segments, view, stored procedures
-- Run schema/01_create_tables.sql and schema/02_load_and_clean.sql first.
-- Tip: in MySQL Workbench select ONE query and press Ctrl+Enter to run it.
-- =====================================================================
USE retail_project;

-- A CTE (WITH ... AS) is just a named temporary result: easier to read than a query inside a query.

-- Q21. Which customers spent more than the average customer? (subquery)
SELECT customer_id, ROUND(SUM(line_total), 2) AS total_spent
FROM v_sales
WHERE customer_id IS NOT NULL
GROUP BY customer_id
HAVING SUM(line_total) > (SELECT AVG(spent)
                          FROM (SELECT SUM(line_total) AS spent
                                FROM v_sales
                                WHERE customer_id IS NOT NULL
                                GROUP BY customer_id) AS t)
ORDER BY total_spent DESC
LIMIT 10;

-- Q22. Top 3 products in each year (CTE + DENSE_RANK window function).
-- DATA NOTE: PAPER CRAFT LITTLE BIRDIE in 2011 is ONE order of 80,995 units that was
-- cancelled the same day. v_sales ignores cancellations, so it still counts. Q19 shows it.
WITH product_revenue AS (
    SELECT YEAR(s.order_date) AS year, p.description, SUM(s.line_total) AS revenue
    FROM v_sales s
    JOIN products p ON p.stock_code = s.stock_code
    GROUP BY YEAR(s.order_date), p.stock_code, p.description
),
ranked AS (
    SELECT *, DENSE_RANK() OVER (PARTITION BY year ORDER BY revenue DESC) AS rnk
    FROM product_revenue
)
SELECT year, rnk, description, ROUND(revenue, 2) AS revenue
FROM ranked
WHERE rnk <= 3
ORDER BY year, rnk;

-- Q23. Month-over-month revenue growth % (LAG looks at the previous row).
-- Note: Dec 2011 only has data until the 9th, so its drop is not real.
WITH monthly AS (
    SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, SUM(line_total) AS revenue
    FROM v_sales
    GROUP BY month
)
SELECT month,
       ROUND(revenue, 2) AS revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month))
                 / LAG(revenue) OVER (ORDER BY month), 1) AS growth_pct
FROM monthly
ORDER BY month;

-- Q24. Running (cumulative) revenue over time.
WITH monthly AS (
    SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, SUM(line_total) AS revenue
    FROM v_sales
    GROUP BY month
)
SELECT month,
       ROUND(revenue, 2) AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY month), 2) AS running_total
FROM monthly
ORDER BY month;

-- Q25. Do a few customers bring most of the money? (NTILE splits customers into 5 equal groups)
WITH customer_spend AS (
    SELECT customer_id, SUM(line_total) AS spent
    FROM v_sales
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),
spend_groups AS (
    SELECT spent, NTILE(5) OVER (ORDER BY spent DESC) AS group_no   -- 1 = biggest spenders
    FROM customer_spend
)
SELECT group_no,
       COUNT(*) AS customers,
       ROUND(SUM(spent), 2) AS revenue,
       ROUND(100 * SUM(spent) / SUM(SUM(spent)) OVER (), 1) AS pct_of_revenue
FROM spend_groups
GROUP BY group_no
ORDER BY group_no;

-- Q26. Customer segments using RFM:
--   Recency   = days since the last order     (lower is better)
--   Frequency = number of orders              (higher is better)
--   Monetary  = total money spent             (higher is better)
WITH rfm AS (
    SELECT customer_id,
           DATEDIFF((SELECT MAX(order_date) FROM orders), MAX(order_date)) AS recency_days,
           COUNT(DISTINCT order_id) AS frequency,
           SUM(line_total)          AS monetary
    FROM v_sales
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),
scored AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,   -- 4 = bought recently
           NTILE(4) OVER (ORDER BY frequency)         AS f_score    -- 4 = orders often
    FROM rfm
)
SELECT CASE WHEN r_score >= 3 AND f_score >= 3 THEN 'Best customers'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At risk (used to buy a lot)'
            WHEN r_score >= 3 AND f_score <= 2 THEN 'New / occasional'
            ELSE 'Lost / low value' END AS segment,
       COUNT(*)                     AS customers,
       ROUND(AVG(recency_days))     AS avg_days_since_last_order,
       ROUND(AVG(frequency), 1)     AS avg_orders,
       ROUND(SUM(monetary), 2)      AS revenue
FROM scored
GROUP BY segment
ORDER BY revenue DESC;

-- Q27. Best-selling product in each of the top 5 countries (window function RANK).
WITH country_totals AS (
    SELECT country, SUM(line_total) AS country_revenue
    FROM v_sales GROUP BY country ORDER BY country_revenue DESC LIMIT 5
),
product_by_country AS (
    SELECT s.country, p.description, SUM(s.line_total) AS revenue,
           RANK() OVER (PARTITION BY s.country ORDER BY SUM(s.line_total) DESC) AS rnk
    FROM v_sales s
    JOIN products p ON p.stock_code = s.stock_code
    WHERE s.country IN (SELECT country FROM country_totals)
    GROUP BY s.country, p.stock_code, p.description
)
SELECT country, description, ROUND(revenue, 2) AS revenue
FROM product_by_country
WHERE rnk = 1
ORDER BY revenue DESC;

-- Q28. What do people buy together with WHITE HANGING HEART T-LIGHT HOLDER (85123A)?
-- (self join: match every line with the other lines of the same order)
SELECT p.description, COUNT(DISTINCT b.order_id) AS orders_together
FROM v_sales a
JOIN v_sales b ON b.order_id = a.order_id AND b.stock_code <> a.stock_code
JOIN products p ON p.stock_code = b.stock_code
WHERE a.stock_code = '85123A'
GROUP BY p.stock_code, p.description
ORDER BY orders_together DESC
LIMIT 10;

-- Q29. Create a VIEW for monthly sales (Excel / Power BI can read it directly).
CREATE OR REPLACE VIEW monthly_sales_summary AS
SELECT DATE_FORMAT(order_date, '%Y-%m')  AS month,
       COUNT(DISTINCT order_id)          AS orders,
       COUNT(DISTINCT customer_id)       AS customers,
       ROUND(SUM(line_total), 2)         AS revenue
FROM v_sales
GROUP BY month;

SELECT * FROM monthly_sales_summary ORDER BY month LIMIT 6;

-- Q30. Stored procedures = saved queries you can run with CALL.
-- (a) All orders of one customer
DROP PROCEDURE IF EXISTS get_customer_history;
DELIMITER //
CREATE PROCEDURE get_customer_history(IN p_customer_id INT)
BEGIN
    SELECT order_id, order_date, status
    FROM orders
    WHERE customer_id = p_customer_id
    ORDER BY order_date;
END //
DELIMITER ;

-- (b) Top N products for a given year
DROP PROCEDURE IF EXISTS get_top_products;
DELIMITER //
CREATE PROCEDURE get_top_products(IN p_year INT, IN p_limit INT)
BEGIN
    SELECT p.description, ROUND(SUM(s.line_total), 2) AS revenue
    FROM v_sales s
    JOIN products p ON p.stock_code = s.stock_code
    WHERE YEAR(s.order_date) = p_year
    GROUP BY p.stock_code, p.description
    ORDER BY revenue DESC
    LIMIT p_limit;
END //
DELIMITER ;

CALL get_customer_history(12347);
CALL get_top_products(2011, 5);
