-- ============================================================
-- 01 — Executive KPIs: high-level business overview
-- ============================================================
USE retail_analytics;

-- KPI 1. Overall revenue, net of discounts, for the full year
SELECT
    ROUND(SUM(soi.quantity * soi.unit_price_paid), 2) AS gross_revenue,
    COUNT(DISTINCT so.order_id) AS total_orders,
    COUNT(DISTINCT so.customer_id) AS unique_customers,
    ROUND(SUM(soi.quantity * soi.unit_price_paid) / COUNT(DISTINCT so.order_id), 2) AS avg_order_value
FROM sales_orders so
JOIN sales_order_items soi ON so.order_id = soi.order_id;

-- KPI 2. Monthly revenue trend with month-over-month growth
WITH monthly AS (
    SELECT DATE_FORMAT(so.order_date, '%Y-%m') AS month,
           SUM(soi.quantity * soi.unit_price_paid) AS revenue
    FROM sales_orders so
    JOIN sales_order_items soi ON so.order_id = soi.order_id
    GROUP BY month
)
SELECT month, revenue,
       ROUND(revenue - LAG(revenue) OVER (ORDER BY month), 2) AS revenue_change,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0
             / LAG(revenue) OVER (ORDER BY month), 1) AS pct_change
FROM monthly
ORDER BY month;

-- KPI 3. Revenue and order count by store, ranked
SELECT s.store_name, s.region,
       COUNT(DISTINCT so.order_id) AS total_orders,
       ROUND(SUM(soi.quantity * soi.unit_price_paid), 2) AS revenue,
       RANK() OVER (ORDER BY SUM(soi.quantity * soi.unit_price_paid) DESC) AS revenue_rank
FROM stores s
JOIN sales_orders so ON s.store_id = so.store_id
JOIN sales_order_items soi ON so.order_id = soi.order_id
GROUP BY s.store_id, s.store_name, s.region;

-- KPI 4. Revenue by category, with share of total
WITH category_revenue AS (
    SELECT c.category_name,
           SUM(soi.quantity * soi.unit_price_paid) AS revenue
    FROM categories c
    JOIN products p ON c.category_id = p.category_id
    JOIN sales_order_items soi ON p.product_id = soi.product_id
    GROUP BY c.category_name
)
SELECT category_name, revenue,
       ROUND(revenue * 100.0 / SUM(revenue) OVER (), 1) AS pct_of_total_revenue
FROM category_revenue
ORDER BY revenue DESC;

-- KPI 5. Top 10 best-selling products by revenue
SELECT p.product_name, c.category_name,
       SUM(soi.quantity) AS units_sold,
       ROUND(SUM(soi.quantity * soi.unit_price_paid), 2) AS revenue
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN sales_order_items soi ON p.product_id = soi.product_id
GROUP BY p.product_id, p.product_name, c.category_name
ORDER BY revenue DESC
LIMIT 10;

-- KPI 6. Gross margin by product (price paid vs unit cost, accounting for discounts)
SELECT p.product_name,
       p.unit_cost,
       ROUND(AVG(soi.unit_price_paid), 2) AS avg_price_paid,
       ROUND(AVG(soi.unit_price_paid) - p.unit_cost, 2) AS avg_margin_per_unit,
       ROUND((AVG(soi.unit_price_paid) - p.unit_cost) * 100.0 / AVG(soi.unit_price_paid), 1) AS margin_pct
FROM products p
JOIN sales_order_items soi ON p.product_id = soi.product_id
GROUP BY p.product_id, p.product_name, p.unit_cost
ORDER BY margin_pct DESC;

-- KPI 7. Return rate by category
SELECT c.category_name,
       COUNT(DISTINCT soi.order_item_id) AS items_sold,
       COUNT(DISTINCT pr.return_id) AS items_returned,
       ROUND(COUNT(DISTINCT pr.return_id) * 100.0 / COUNT(DISTINCT soi.order_item_id), 2) AS return_rate_pct
FROM categories c
JOIN products p ON c.category_id = p.category_id
JOIN sales_order_items soi ON p.product_id = soi.product_id
LEFT JOIN product_returns pr ON soi.order_item_id = pr.order_item_id
GROUP BY c.category_name
ORDER BY return_rate_pct DESC;

-- KPI 8. Payment method distribution
SELECT payment_method,
       COUNT(*) AS order_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders
FROM sales_orders
GROUP BY payment_method
ORDER BY order_count DESC;
