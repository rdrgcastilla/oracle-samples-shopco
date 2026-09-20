rem
rem shopco_example_queries.sql - A curated set of example queries against
rem the SHOPCO practice schema, organized from basic to advanced.
rem Run these connected as the SHOPCO user (or with CURRENT_SCHEMA=SHOPCO).
rem --------------------------------------------------------------------------

rem =====================================================================
rem 1. BASIC SELECT / FILTER / SORT
rem =====================================================================

-- All customers
SELECT customer_id, full_name, email_address, signup_date FROM customers;

-- Products ordered by price, most expensive first
SELECT product_name, unit_price FROM products ORDER BY unit_price DESC;

-- Orders currently open
SELECT order_id, order_tms, customer_id FROM orders WHERE order_status = 'OPEN';

-- Employees who are Sales Associates
SELECT full_name, email_address, store_id FROM employees WHERE job_title = 'Sales Associate';


rem =====================================================================
rem 2. JOINS
rem =====================================================================

-- What each customer bought, with product names
SELECT c.full_name, p.product_name, oi.quantity, oi.unit_price
FROM   customers c
JOIN   orders o        ON o.customer_id = c.customer_id
JOIN   order_items oi  ON oi.order_id = o.order_id
JOIN   products p      ON p.product_id = oi.product_id
ORDER  BY c.full_name;

-- Orders with their store and shipment status
SELECT o.order_id, s.store_name, o.order_status, sh.shipment_status
FROM   orders o
JOIN   stores s        ON s.store_id = o.store_id
LEFT   JOIN order_items oi ON oi.order_id = o.order_id
LEFT   JOIN shipments sh   ON sh.shipment_id = oi.shipment_id;

-- Which employee processed each order, and their manager
SELECT o.order_id, e.full_name AS sold_by, m.full_name AS store_manager
FROM   orders o
JOIN   employees e ON e.employee_id = o.employee_id
LEFT   JOIN employees m ON m.employee_id = e.manager_id;

-- Products with their category and suppliers (many-to-many)
SELECT p.product_name, c.category_name, s.supplier_name, ps.supply_price
FROM   products p
JOIN   categories c        ON c.category_id = p.category_id
JOIN   product_suppliers ps ON ps.product_id = p.product_id
JOIN   suppliers s          ON s.supplier_id = ps.supplier_id
ORDER  BY p.product_name;


rem =====================================================================
rem 3. AGGREGATIONS
rem =====================================================================

-- Total sales per store
SELECT s.store_name, SUM(oi.quantity * oi.unit_price) AS total_sales
FROM   stores s
JOIN   orders o       ON o.store_id = s.store_id
JOIN   order_items oi ON oi.order_id = o.order_id
GROUP  BY s.store_name
ORDER  BY total_sales DESC;

-- Top 5 best-selling products by quantity
SELECT p.product_name, SUM(oi.quantity) AS units_sold
FROM   products p
JOIN   order_items oi ON oi.product_id = p.product_id
GROUP  BY p.product_name
ORDER  BY units_sold DESC
FETCH FIRST 5 ROWS ONLY;

-- Orders by status
SELECT order_status, COUNT(*) AS total_orders
FROM   orders
GROUP  BY order_status
ORDER  BY total_orders DESC;

-- Average product rating by category
SELECT c.category_name, ROUND(AVG(r.rating), 2) AS avg_rating
FROM   categories c
JOIN   products p  ON p.category_id = c.category_id
JOIN   reviews r   ON r.product_id = p.product_id
GROUP  BY c.category_name
ORDER  BY avg_rating DESC;

-- Which products are below their reorder level, per store
SELECT s.store_name, p.product_name, i.product_inventory, i.reorder_level
FROM   inventory i
JOIN   stores s   ON s.store_id = i.store_id
JOIN   products p ON p.product_id = i.product_id
WHERE  i.product_inventory < i.reorder_level
ORDER  BY s.store_name, p.product_name;


rem =====================================================================
rem 4. ANALYTIC / WINDOW FUNCTIONS
rem =====================================================================

-- Rank customers by total amount spent
SELECT c.full_name,
       SUM(oi.quantity * oi.unit_price) AS total_spent,
       RANK() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS spend_rank
FROM   customers c
JOIN   orders o       ON o.customer_id = c.customer_id
JOIN   order_items oi ON oi.order_id = o.order_id
GROUP  BY c.full_name;

-- Running total of sales per store over time
SELECT s.store_name, o.order_tms,
       SUM(oi.quantity * oi.unit_price)
         OVER (PARTITION BY s.store_id ORDER BY o.order_tms) AS running_total
FROM   stores s
JOIN   orders o       ON o.store_id = s.store_id
JOIN   order_items oi ON oi.order_id = o.order_id
ORDER  BY s.store_name, o.order_tms;

-- Each employee's sales compared to their store's average
SELECT e.full_name, o.store_id,
       SUM(oi.quantity * oi.unit_price) AS employee_sales,
       ROUND(AVG(SUM(oi.quantity * oi.unit_price)) OVER (PARTITION BY o.store_id), 2) AS store_avg
FROM   employees e
JOIN   orders o       ON o.employee_id = e.employee_id
JOIN   order_items oi ON oi.order_id = o.order_id
GROUP  BY e.full_name, o.store_id
ORDER  BY o.store_id, employee_sales DESC;


rem =====================================================================
rem 5. HIERARCHICAL QUERIES (CONNECT BY)
rem =====================================================================

-- Full reporting hierarchy, indented
SELECT LPAD(' ', 2*(LEVEL-1)) || full_name AS org_chart, job_title
FROM   employees
START WITH manager_id IS NULL
CONNECT BY PRIOR employee_id = manager_id;

-- Same thing, using the pre-built view
SELECT org_chart, job_title, emp_level FROM employee_hierarchy ORDER BY emp_level, full_name;

-- Everyone who (directly or indirectly) reports to a given store manager (id 2)
SELECT full_name, job_title
FROM   employees
START WITH employee_id = 2
CONNECT BY PRIOR employee_id = manager_id;


rem =====================================================================
rem 6. REVIEWS
rem =====================================================================

-- Reviews with rating 8 or higher, with reviewer and product names
SELECT p.product_name, c.full_name AS reviewer, r.rating, r.review_text
FROM   reviews r
JOIN   products p  ON p.product_id = r.product_id
JOIN   customers c ON c.customer_id = r.customer_id
WHERE  r.rating >= 8
ORDER  BY r.rating DESC;

-- Average rating and review count per product, using the pre-built view
SELECT * FROM product_ratings ORDER BY avg_rating DESC;

-- Products with fewer than 3 reviews (candidates to feature for more feedback)
SELECT p.product_name, COUNT(r.review_id) AS review_count
FROM   products p
LEFT   JOIN reviews r ON r.product_id = p.product_id
GROUP  BY p.product_name
HAVING COUNT(r.review_id) < 3
ORDER  BY review_count;

-- Customers who leave the most reviews
SELECT c.full_name, COUNT(*) AS reviews_written
FROM   customers c
JOIN   reviews r ON r.customer_id = c.customer_id
GROUP  BY c.full_name
ORDER  BY reviews_written DESC
FETCH FIRST 5 ROWS ONLY;


rem =====================================================================
rem 7. VIEWS ALREADY INCLUDED IN THE SCHEMA
rem =====================================================================

SELECT * FROM customer_order_summary WHERE order_status = 'COMPLETE';
SELECT * FROM store_sales_summary WHERE total = 'GRAND TOTAL';
SELECT * FROM store_sales_summary WHERE total = 'STORE TOTAL' ORDER BY total_sales DESC;


rem =====================================================================
rem 8. SUBQUERIES
rem =====================================================================

-- Customers who have never placed an order
SELECT full_name, email_address
FROM   customers c
WHERE  NOT EXISTS (
  SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
);

-- Products that have never been ordered
SELECT product_name
FROM   products p
WHERE  p.product_id NOT IN (SELECT product_id FROM order_items);

-- Customers whose total spend is above the overall average
SELECT full_name, total_spent FROM (
  SELECT c.full_name, SUM(oi.quantity * oi.unit_price) AS total_spent
  FROM   customers c
  JOIN   orders o       ON o.customer_id = c.customer_id
  JOIN   order_items oi ON oi.order_id = o.order_id
  GROUP  BY c.full_name
)
WHERE total_spent > (
  SELECT AVG(order_total) FROM customer_order_summary
);
