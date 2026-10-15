-- =====================================================================
-- LEVEL 2: INTERMEDIATE  (Q7-Q20)
-- JOIN, GROUP BY, HAVING, CASE, date functions
-- Run schema/01_create_tables.sql and schema/02_load_and_clean.sql first.
-- Tip: in MySQL Workbench select ONE query and press Ctrl+Enter to run it.
-- =====================================================================
USE retail_project;

-- Q7. Total revenue, number of orders and average order value.
SELECT ROUND(SUM(line_total), 2)                        AS total_revenue,
       COUNT(DISTINCT order_id)                         AS total_orders,
       ROUND(SUM(line_total) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM v_sales;

-- Q8. Revenue for each month.
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
       ROUND(SUM(line_total), 2)        AS revenue,
       COUNT(DISTINCT order_id)         AS orders
FROM v_sales
GROUP BY month
ORDER BY month;

-- Q9. Top 10 products by units sold.
SELECT p.description, SUM(s.quantity) AS units_sold
FROM v_sales s
JOIN products p ON p.stock_code = s.stock_code
GROUP BY p.stock_code, p.description
ORDER BY units_sold DESC
LIMIT 10;

-- Q10. Top 10 products by revenue.
SELECT p.description, ROUND(SUM(s.line_total), 2) AS revenue
FROM v_sales s
JOIN products p ON p.stock_code = s.stock_code
GROUP BY p.stock_code, p.description
ORDER BY revenue DESC
LIMIT 10;

-- Q11. Top 10 customers by money spent (JOIN customers to get their country).
SELECT c.customer_id, c.country,
       COUNT(DISTINCT s.order_id)  AS orders,
       ROUND(SUM(s.line_total), 2) AS total_spent
FROM v_sales s
JOIN customers c ON c.customer_id = s.customer_id
GROUP BY c.customer_id, c.country
ORDER BY total_spent DESC
LIMIT 10;

-- Q12. Revenue per country (top 10).
SELECT country, ROUND(SUM(line_total), 2) AS revenue
FROM v_sales
GROUP BY country
ORDER BY revenue DESC
LIMIT 10;

-- Q13. Which countries earned more than 100,000? (HAVING filters groups)
SELECT country, ROUND(SUM(line_total), 2) AS revenue
FROM v_sales
GROUP BY country
HAVING SUM(line_total) > 100000
ORDER BY revenue DESC;

-- Q14. Average order value per country (only countries with 20+ orders).
SELECT country,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(SUM(line_total) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM v_sales
GROUP BY country
HAVING COUNT(DISTINCT order_id) >= 20
ORDER BY avg_order_value DESC
LIMIT 10;

-- Q15. United Kingdom vs the rest of the world (CASE WHEN).
SELECT CASE WHEN country = 'United Kingdom' THEN 'United Kingdom'
            ELSE 'Rest of world' END AS market,
       ROUND(SUM(line_total), 2)    AS revenue
FROM v_sales
GROUP BY market;

-- Q16. Which day of the week earns the most?
SELECT DAYNAME(order_date) AS weekday,
       ROUND(SUM(line_total), 2) AS revenue
FROM v_sales
GROUP BY DAYNAME(order_date), DAYOFWEEK(order_date)
ORDER BY DAYOFWEEK(order_date);

-- Q17. Which hour of the day is the busiest?
SELECT HOUR(order_date) AS hour_of_day,
       COUNT(DISTINCT order_id) AS orders
FROM v_sales
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- Q18. What percentage of orders were cancelled each year?
SELECT YEAR(order_date) AS year,
       COUNT(*) AS orders,
       SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
       ROUND(100 * SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 1) AS cancelled_pct
FROM orders
GROUP BY YEAR(order_date)
ORDER BY year;

-- Q19. Which products are returned the most? (cancelled orders joined to products)
SELECT p.description,
       SUM(-oi.quantity)   AS units_returned,
       ROUND(SUM(-oi.line_total), 2) AS value_returned
FROM order_items oi
JOIN orders   o ON o.order_id   = oi.order_id
JOIN products p ON p.stock_code = oi.stock_code
WHERE o.status = 'Cancelled'
  AND oi.stock_code REGEXP '^[0-9]{5}'
GROUP BY p.stock_code, p.description
ORDER BY value_returned DESC
LIMIT 10;

-- Q20. How many customers bought only once vs more than once?
SELECT CASE WHEN orders = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
       COUNT(*) AS customers
FROM (SELECT customer_id, COUNT(DISTINCT order_id) AS orders
      FROM v_sales
      WHERE customer_id IS NOT NULL
      GROUP BY customer_id) AS per_customer
GROUP BY customer_type;

