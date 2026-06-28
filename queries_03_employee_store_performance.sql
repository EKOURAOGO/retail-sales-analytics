-- ============================================================
-- 03 — Employee & store performance
-- ============================================================
USE retail_analytics;

-- E1. Sales performance ranking per employee
SELECT e.full_name, s.store_name,
       COUNT(DISTINCT so.order_id) AS orders_handled,
       ROUND(SUM(soi.quantity * soi.unit_price_paid), 2) AS total_sales,
       RANK() OVER (ORDER BY SUM(soi.quantity * soi.unit_price_paid) DESC) AS sales_rank
FROM employees e
JOIN stores s ON e.store_id = s.store_id
JOIN sales_orders so ON e.employee_id = so.employee_id
JOIN sales_order_items soi ON so.order_id = soi.order_id
GROUP BY e.employee_id, e.full_name, s.store_name
ORDER BY total_sales DESC;

-- E2. Top performing employee per store
WITH employee_sales AS (
    SELECT e.employee_id, e.full_name, e.store_id,
           SUM(soi.quantity * soi.unit_price_paid) AS total_sales,
           RANK() OVER (PARTITION BY e.store_id ORDER BY SUM(soi.quantity * soi.unit_price_paid) DESC) AS rnk
    FROM employees e
    JOIN sales_orders so ON e.employee_id = so.employee_id
    JOIN sales_order_items soi ON so.order_id = soi.order_id
    GROUP BY e.employee_id, e.full_name, e.store_id
)
SELECT s.store_name, es.full_name AS top_employee, ROUND(es.total_sales, 2) AS total_sales
FROM employee_sales es
JOIN stores s ON es.store_id = s.store_id
WHERE es.rnk = 1;

-- E3. Average sales per employee, grouped by role
SELECT e.role,
       COUNT(DISTINCT e.employee_id) AS num_employees,
       ROUND(SUM(soi.quantity * soi.unit_price_paid) / COUNT(DISTINCT e.employee_id), 2) AS avg_sales_per_employee
FROM employees e
JOIN sales_orders so ON e.employee_id = so.employee_id
JOIN sales_order_items soi ON so.order_id = soi.order_id
GROUP BY e.role
ORDER BY avg_sales_per_employee DESC;

-- E4. Store performance: revenue per square indicator proxy (orders per day since opening)
SELECT s.store_name, s.opening_date,
       DATEDIFF('2024-12-31', s.opening_date) AS days_open,
       COUNT(DISTINCT so.order_id) AS total_orders_2024,
       ROUND(COUNT(DISTINCT so.order_id) * 1.0 / 365, 2) AS avg_orders_per_day_2024
FROM stores s
LEFT JOIN sales_orders so ON s.store_id = so.store_id AND YEAR(so.order_date) = 2024
GROUP BY s.store_id, s.store_name, s.opening_date
ORDER BY avg_orders_per_day_2024 DESC;

-- E5. Monthly revenue trend per store (pivoted view via conditional aggregation)
SELECT DATE_FORMAT(so.order_date, '%Y-%m') AS month,
       SUM(CASE WHEN s.store_name = 'Paris Centre' THEN soi.quantity * soi.unit_price_paid ELSE 0 END) AS paris_centre,
       SUM(CASE WHEN s.store_name = 'Lyon Part-Dieu' THEN soi.quantity * soi.unit_price_paid ELSE 0 END) AS lyon,
       SUM(CASE WHEN s.store_name = 'Marseille Sud' THEN soi.quantity * soi.unit_price_paid ELSE 0 END) AS marseille,
       SUM(CASE WHEN s.store_name = 'Lille Centre' THEN soi.quantity * soi.unit_price_paid ELSE 0 END) AS lille,
       SUM(CASE WHEN s.store_name = 'Online Store' THEN soi.quantity * soi.unit_price_paid ELSE 0 END) AS online
FROM sales_orders so
JOIN stores s ON so.store_id = s.store_id
JOIN sales_order_items soi ON so.order_id = soi.order_id
GROUP BY month
ORDER BY month;

-- E6. Employees with sales below their store's average (potential coaching candidates)
WITH employee_sales AS (
    SELECT e.employee_id, e.full_name, e.store_id,
           SUM(soi.quantity * soi.unit_price_paid) AS total_sales
    FROM employees e
    JOIN sales_orders so ON e.employee_id = so.employee_id
    JOIN sales_order_items soi ON so.order_id = soi.order_id
    GROUP BY e.employee_id, e.full_name, e.store_id
)
SELECT es.full_name, s.store_name, ROUND(es.total_sales, 2) AS total_sales,
       ROUND(store_avg.avg_sales, 2) AS store_avg_sales
FROM employee_sales es
JOIN stores s ON es.store_id = s.store_id
JOIN (
    SELECT store_id, AVG(total_sales) AS avg_sales
    FROM employee_sales
    GROUP BY store_id
) store_avg ON es.store_id = store_avg.store_id
WHERE es.total_sales < store_avg.avg_sales
ORDER BY s.store_name, es.total_sales;
