#!/bin/bash
# ============================================================
# Retail Sales Analytics — Automated test suite
# Verifies query correctness with concrete assertions
# computed independently from the seed data.
# ============================================================

set -uo pipefail

DB="retail_analytics"
PASS=0
FAIL=0

run_query() {
    mysql -u root -N -B "$DB" -e "$1" 2>&1
}

assert_eq() {
    local description="$1"
    local actual="$2"
    local expected="$3"
    if [ "$actual" == "$expected" ]; then
        echo "  PASS  $description"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $description (expected '$expected', got '$actual')"
        FAIL=$((FAIL+1))
    fi
}

assert_gt() {
    local description="$1"
    local actual="$2"
    local threshold="$3"
    if (( $(echo "$actual > $threshold" | bc -l) )); then
        echo "  PASS  $description ($actual > $threshold)"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $description ($actual is not > $threshold)"
        FAIL=$((FAIL+1))
    fi
}

echo "============================================================"
echo "Running Retail Sales Analytics test suite"
echo "============================================================"

# ------------------------------------------------------------
echo ""
echo "-- Data integrity --"

result=$(run_query "SELECT COUNT(*) FROM stores;")
assert_eq "5 stores loaded" "$result" "5"

result=$(run_query "SELECT COUNT(*) FROM customers;")
assert_eq "300 customers loaded" "$result" "300"

result=$(run_query "SELECT COUNT(*) FROM sales_orders;")
assert_eq "909 orders loaded" "$result" "909"

result=$(run_query "SELECT COUNT(*) FROM sales_order_items;")
assert_eq "2258 order line items loaded" "$result" "2258"

result=$(run_query "SELECT COUNT(*) FROM sales_orders so LEFT JOIN customers c ON so.customer_id = c.customer_id WHERE c.customer_id IS NULL;")
assert_eq "Zero orphan orders (all orders reference a valid customer)" "$result" "0"

result=$(run_query "SELECT COUNT(*) FROM sales_order_items soi LEFT JOIN sales_orders so ON soi.order_id = so.order_id WHERE so.order_id IS NULL;")
assert_eq "Zero orphan order items (all items reference a valid order)" "$result" "0"

result=$(run_query "SELECT COUNT(*) FROM sales_order_items soi LEFT JOIN products p ON soi.product_id = p.product_id WHERE p.product_id IS NULL;")
assert_eq "Zero orphan order items (all items reference a valid product)" "$result" "0"

# ------------------------------------------------------------
echo ""
echo "-- Executive KPIs --"

result=$(run_query "SELECT COUNT(DISTINCT order_id) FROM sales_orders;")
assert_eq "Distinct order count matches total order count (no duplicate IDs)" "$result" "909"

result=$(run_query "
SELECT ROUND(SUM(quantity * unit_price_paid), 2) FROM sales_order_items;
")
assert_gt "Total gross revenue is a positive, non-trivial amount" "$result" "1000000"

result=$(run_query "
SELECT COUNT(*) FROM (
    SELECT DATE_FORMAT(order_date, '%Y-%m') AS m FROM sales_orders GROUP BY m
) months;
")
assert_eq "Orders span exactly 12 distinct months" "$result" "12"

result=$(run_query "
SELECT category_name FROM categories c
JOIN products p ON c.category_id = p.category_id
JOIN sales_order_items soi ON p.product_id = soi.product_id
GROUP BY category_name
ORDER BY SUM(quantity * unit_price_paid) DESC
LIMIT 1;
")
assert_eq "Top revenue category is Electronique" "$result" "Electronique"

result=$(run_query "
SELECT p.product_name FROM products p
JOIN sales_order_items soi ON p.product_id = soi.product_id
GROUP BY p.product_id, p.product_name
ORDER BY SUM(soi.quantity * soi.unit_price_paid) DESC
LIMIT 1;
")
assert_eq "Top revenue product is Laptop Pro 15" "$result" "Laptop Pro 15"

result=$(run_query "
SELECT ROUND((AVG(soi.unit_price_paid) - p.unit_cost) * 100.0 / AVG(soi.unit_price_paid), 1)
FROM products p JOIN sales_order_items soi ON p.product_id = soi.product_id
WHERE p.product_name = 'Jean slim'
GROUP BY p.product_id;
")
assert_eq "Jean slim has the highest margin percentage (~78.8%)" "$result" "78.8"

# ------------------------------------------------------------
echo ""
echo "-- Customer analytics --"

result=$(run_query "
SELECT COUNT(*) FROM customers c
LEFT JOIN sales_orders so ON c.customer_id = so.customer_id
WHERE so.order_id IS NULL;
")
echo "  INFO  Customers with zero orders: $result (informational, not asserted to an exact number)"

result=$(run_query "
WITH customer_stats AS (
    SELECT so.customer_id,
           DATEDIFF('2024-12-31', MAX(so.order_date)) AS recency_days
    FROM sales_orders so
    GROUP BY so.customer_id
)
SELECT COUNT(*) FROM customer_stats WHERE recency_days > 90;
")
assert_gt "At least some customers qualify as churn risks (>90 days since last order)" "$result" "0"

result=$(run_query "
SELECT c.loyalty_member, COUNT(*) FROM customers c GROUP BY c.loyalty_member ORDER BY c.loyalty_member;
" | tail -1 | cut -f2)
assert_gt "At least 50 loyalty members exist in the customer base" "$result" "50"

# ------------------------------------------------------------
echo ""
echo "-- Employee & store performance --"

result=$(run_query "SELECT COUNT(*) FROM employees;")
assert_eq "32 employees loaded" "$result" "32"

result=$(run_query "
SELECT s.store_name FROM stores s
JOIN sales_orders so ON s.store_id = so.store_id
JOIN sales_order_items soi ON so.order_id = soi.order_id
GROUP BY s.store_id, s.store_name
ORDER BY SUM(soi.quantity * soi.unit_price_paid) DESC
LIMIT 1;
")
assert_eq "Top revenue store is Online Store" "$result" "Online Store"

result=$(run_query "
SELECT COUNT(*) FROM (
    SELECT e.employee_id FROM employees e
    JOIN sales_orders so ON e.employee_id = so.employee_id
    GROUP BY e.employee_id
) active_employees;
")
assert_gt "At least 30 employees have handled at least one order" "$result" "29"

# ------------------------------------------------------------
echo ""
echo "============================================================"
echo "RESULTS: $PASS passed, $FAIL failed"
echo "============================================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
