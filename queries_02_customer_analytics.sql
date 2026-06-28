-- ============================================================
-- 02 — Customer analytics: segmentation, churn, loyalty
-- ============================================================
USE retail_analytics;

-- C1. RFM-style segmentation: Recency, Frequency, Monetary per customer
WITH customer_stats AS (
    SELECT so.customer_id,
           DATEDIFF('2024-12-31', MAX(so.order_date)) AS recency_days,
           COUNT(DISTINCT so.order_id) AS frequency,
           SUM(soi.quantity * soi.unit_price_paid) AS monetary
    FROM sales_orders so
    JOIN sales_order_items soi ON so.order_id = soi.order_id
    GROUP BY so.customer_id
)
SELECT cu.customer_id, cu.full_name, cs.recency_days, cs.frequency,
       ROUND(cs.monetary, 2) AS monetary,
       CASE
           WHEN cs.recency_days <= 30 AND cs.frequency >= 4 THEN 'Champion'
           WHEN cs.recency_days <= 60 AND cs.frequency >= 2 THEN 'Loyal'
           WHEN cs.recency_days > 120 THEN 'At Risk'
           ELSE 'Regular'
       END AS segment
FROM customer_stats cs
JOIN customers cu ON cu.customer_id = cs.customer_id
ORDER BY cs.monetary DESC;

-- C2. Customers who have not ordered in the last 90 days (churn candidates)
SELECT c.customer_id, c.full_name, c.city,
       MAX(so.order_date) AS last_order_date,
       DATEDIFF('2024-12-31', MAX(so.order_date)) AS days_since_last_order
FROM customers c
JOIN sales_orders so ON c.customer_id = so.customer_id
GROUP BY c.customer_id, c.full_name, c.city
HAVING days_since_last_order > 90
ORDER BY days_since_last_order DESC;

-- C3. Customers who have never placed an order
SELECT c.customer_id, c.full_name, c.signup_date
FROM customers c
LEFT JOIN sales_orders so ON c.customer_id = so.customer_id
WHERE so.order_id IS NULL;

-- C4. Loyalty members vs non-members: average order value comparison
SELECT c.loyalty_member,
       COUNT(DISTINCT so.order_id) AS total_orders,
       ROUND(AVG(order_totals.order_total), 2) AS avg_order_value
FROM customers c
JOIN sales_orders so ON c.customer_id = so.customer_id
JOIN (
    SELECT order_id, SUM(quantity * unit_price_paid) AS order_total
    FROM sales_order_items
    GROUP BY order_id
) order_totals ON so.order_id = order_totals.order_id
GROUP BY c.loyalty_member;

-- C5. Top 10 customers by lifetime value
SELECT c.customer_id, c.full_name, c.city,
       COUNT(DISTINCT so.order_id) AS total_orders,
       ROUND(SUM(soi.quantity * soi.unit_price_paid), 2) AS lifetime_value
FROM customers c
JOIN sales_orders so ON c.customer_id = so.customer_id
JOIN sales_order_items soi ON so.order_id = soi.order_id
GROUP BY c.customer_id, c.full_name, c.city
ORDER BY lifetime_value DESC
LIMIT 10;

-- C6. New customer acquisition by month (based on signup_date)
SELECT DATE_FORMAT(signup_date, '%Y-%m') AS signup_month,
       COUNT(*) AS new_customers
FROM customers
GROUP BY signup_month
ORDER BY signup_month;

-- C7. Customer purchase frequency distribution (how many customers ordered N times)
SELECT order_count, COUNT(*) AS num_customers
FROM (
    SELECT customer_id, COUNT(*) AS order_count
    FROM sales_orders
    GROUP BY customer_id
) freq
GROUP BY order_count
ORDER BY order_count;

-- C8. City-level revenue contribution (top 5 cities by customer revenue)
SELECT c.city,
       COUNT(DISTINCT c.customer_id) AS customers,
       ROUND(SUM(soi.quantity * soi.unit_price_paid), 2) AS revenue
FROM customers c
JOIN sales_orders so ON c.customer_id = so.customer_id
JOIN sales_order_items soi ON so.order_id = soi.order_id
GROUP BY c.city
ORDER BY revenue DESC
LIMIT 5;

-- C9. Customers whose average basket value is above the global average
SELECT c.customer_id, c.full_name,
       ROUND(AVG(order_totals.order_total), 2) AS avg_basket_value
FROM customers c
JOIN sales_orders so ON c.customer_id = so.customer_id
JOIN (
    SELECT order_id, SUM(quantity * unit_price_paid) AS order_total
    FROM sales_order_items
    GROUP BY order_id
) order_totals ON so.order_id = order_totals.order_id
GROUP BY c.customer_id, c.full_name
HAVING avg_basket_value > (
    SELECT AVG(order_total) FROM (
        SELECT SUM(quantity * unit_price_paid) AS order_total
        FROM sales_order_items
        GROUP BY order_id
    ) all_orders
)
ORDER BY avg_basket_value DESC;
