-- =====================================================================
-- LEVEL 1: BEGINNER  (Q1-Q6)
-- SELECT, WHERE, ORDER BY, LIMIT, COUNT
-- Run schema/01_create_tables.sql and schema/02_load_and_clean.sql first.
-- Tip: in MySQL Workbench select ONE query and press Ctrl+Enter to run it.
-- =====================================================================
USE retail_project;

-- Q1. Which customers are from Germany?
SELECT customer_id, country
FROM customers
WHERE country = 'Germany'
LIMIT 20;

-- Q2. Which orders were placed on 1 December 2010?
SELECT order_id, customer_id, order_date
FROM orders
WHERE DATE(order_date) = '2010-12-01'
LIMIT 20;

-- Q3. What are the 10 most expensive products? (JOIN products to get the name)
SELECT p.stock_code, p.description, MAX(s.unit_price) AS highest_price
FROM v_sales s
JOIN products p ON p.stock_code = s.stock_code
GROUP BY p.stock_code, p.description
ORDER BY highest_price DESC
LIMIT 10;

-- Q4. Show the 10 most recent cancelled orders.
SELECT order_id, customer_id, order_date, country
FROM orders
WHERE status = 'Cancelled'
ORDER BY order_date DESC
LIMIT 10;

-- Q5. How many customers, products and orders do we have?
SELECT (SELECT COUNT(*) FROM customers) AS customers,
       (SELECT COUNT(*) FROM products)  AS products,
       (SELECT COUNT(*) FROM orders)    AS orders;

-- Q6. How many orders were guest orders (no customer ID)?
SELECT COUNT(*) AS guest_orders
FROM orders
WHERE customer_id IS NULL;

