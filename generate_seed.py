import random
from datetime import date, timedelta

random.seed(42)

lines = []
lines.append("-- ============================================================")
lines.append("-- Retail Sales Analytics — Seed data (generated)")
lines.append("-- ============================================================")
lines.append("USE retail_analytics;\n")

# ------------------------------------------------------------
# stores
# ------------------------------------------------------------
stores = [
    (1, "Paris Centre",   "Paris",     "Ile-de-France", "2019-01-15"),
    (2, "Lyon Part-Dieu", "Lyon",      "Auvergne-Rhone-Alpes", "2019-06-01"),
    (3, "Marseille Sud",  "Marseille", "PACA",          "2020-03-10"),
    (4, "Lille Centre",   "Lille",     "Hauts-de-France","2021-09-01"),
    (5, "Online Store",   "National",  "National",      "2018-01-01"),
]
lines.append("-- stores")
lines.append("INSERT INTO stores (store_id, store_name, city, region, opening_date) VALUES")
lines.append(",\n".join(f"({i},'{n}','{c}','{r}','{d}')" for i,n,c,r,d in stores) + ";\n")

# ------------------------------------------------------------
# employees (5-8 per store)
# ------------------------------------------------------------
first_names = ["Lucas","Emma","Hugo","Lea","Louis","Chloe","Jules","Manon","Adam","Camille",
               "Nathan","Sarah","Theo","Ines","Mathis","Zoe","Noah","Lola","Ethan","Eva"]
last_names = ["Martin","Bernard","Dubois","Thomas","Robert","Petit","Durand","Leroy","Moreau","Simon"]
roles = ["Vendeur", "Vendeur Senior", "Responsable Rayon", "Manager Magasin"]

employees = []
emp_id = 1
for store_id, *_ in stores:
    n_emp = random.randint(5, 8)
    for _ in range(n_emp):
        name = f"{random.choice(first_names)} {random.choice(last_names)}"
        hire = date(2019,1,1) + timedelta(days=random.randint(0, 1800))
        role = random.choice(roles) if emp_id % 7 != 0 else "Manager Magasin"
        employees.append((emp_id, name, store_id, hire.isoformat(), role))
        emp_id += 1

lines.append("-- employees")
lines.append("INSERT INTO employees (employee_id, full_name, store_id, hire_date, role) VALUES")
lines.append(",\n".join(f"({i},'{n}',{s},'{h}','{r}')" for i,n,s,h,r in employees) + ";\n")

# ------------------------------------------------------------
# categories
# ------------------------------------------------------------
categories = [(1,"Electronique"),(2,"Mobilier"),(3,"Vetements"),(4,"Sport"),(5,"Maison & Jardin")]
lines.append("-- categories")
lines.append("INSERT INTO categories (category_id, category_name) VALUES")
lines.append(",\n".join(f"({i},'{n}')" for i,n in categories) + ";\n")

# ------------------------------------------------------------
# products
# ------------------------------------------------------------
products_raw = [
    ("Laptop Pro 15",1,650,1199),("Smartphone X12",1,380,799),("Ecouteurs sans fil",1,25,79),
    ("Tablette 10in",1,180,349),("Montre connectee",1,60,199),
    ("Canape 3 places",2,320,899),("Table a manger",2,150,449),("Chaise bureau ergo",2,80,249),
    ("Bureau debout",2,140,399),("Etagere modulable",2,45,129),
    ("T-shirt coton bio",3,4,19),("Jean slim",3,12,59),("Veste hiver",3,35,149),
    ("Baskets running",3,28,99),("Pull laine",3,18,79),
    ("Velo ville",4,180,449),("Tapis de course",4,250,699),("Haltere set 20kg",4,30,89),
    ("Sac de sport",4,8,39),("Montre sport GPS",4,55,179),
    ("Robot tondeuse",5,290,799),("Aspirateur robot",5,160,449),("Barbecue gaz",5,120,349),
    ("Set jardinage",5,15,49),("Lampe exterieur solaire",5,9,29),
]
products = [(i+1, *p) for i, p in enumerate(products_raw)]
lines.append("-- products")
lines.append("INSERT INTO products (product_id, product_name, category_id, unit_cost, unit_price) VALUES")
lines.append(",\n".join(f"({i},'{n}',{c},{cost},{price})" for i,n,c,cost,price in products) + ";\n")

# ------------------------------------------------------------
# customers (300 customers, signed up over 2 years)
# ------------------------------------------------------------
cities = ["Paris","Lyon","Marseille","Lille","Toulouse","Nantes","Bordeaux","Strasbourg","Nice","Rennes"]
customers = []
for cid in range(1, 301):
    name = f"{random.choice(first_names)} {random.choice(last_names)}"
    city = random.choice(cities)
    signup = date(2022,1,1) + timedelta(days=random.randint(0, 1000))
    loyalty = 1 if random.random() < 0.35 else 0
    customers.append((cid, name, city, signup.isoformat(), loyalty))

lines.append("-- customers")
lines.append("INSERT INTO customers (customer_id, full_name, city, signup_date, loyalty_member) VALUES")
batch = []
for c in customers:
    batch.append(f"({c[0]},'{c[1]}','{c[2]}','{c[3]}',{c[4]})")
lines.append(",\n".join(batch) + ";\n")

# ------------------------------------------------------------
# sales_orders + sales_order_items
# Period: 2024-01-01 to 2024-12-31, with seasonality
# (more sales in March, June-July, November-December)
# ------------------------------------------------------------
payment_methods = ["Carte bancaire", "PayPal", "Especes", "Cheque"]

def seasonality_weight(d):
    month = d.month
    weights = {1:0.8, 2:0.8, 3:1.3, 4:1.0, 5:1.0, 6:1.2, 7:1.2, 8:0.7,
               9:0.9, 10:1.0, 11:1.4, 12:1.6}
    return weights.get(month, 1.0)

orders = []
order_items = []
order_id = 1
item_id = 1

# Some customers churn (stop ordering after a certain date) -- for churn analysis
churned_customers = set(random.sample(range(1, 301), 40))
churn_date_map = {cid: date(2024, random.randint(3,8), random.randint(1,28)) for cid in churned_customers}

current = date(2024,1,1)
end = date(2024,12,31)
while current <= end:
    weight = seasonality_weight(current)
    n_orders_today = max(0, int(random.gauss(3 * weight, 1.5)))
    for _ in range(n_orders_today):
        cid = random.randint(1, 300)
        # respect churn: skip if customer churned before this date
        if cid in churned_customers and current > churn_date_map[cid]:
            continue
        if cid in customers[0][0:1]:
            pass
        store_id = random.choices([1,2,3,4,5], weights=[25,20,15,15,25])[0]
        # pick an employee belonging to that store
        store_employees = [e for e in employees if e[2] == store_id]
        employee_id = random.choice(store_employees)[0]
        payment = random.choice(payment_methods)
        orders.append((order_id, cid, store_id, employee_id, current.isoformat(), payment))

        n_items = random.randint(1, 4)
        chosen_products = random.sample(products, n_items)
        for p in chosen_products:
            pid, pname, cat, cost, price = p
            qty = random.randint(1, 3)
            discount = random.choice([0,0,0,5,10,15]) # mostly no discount
            price_paid = round(float(price) * (1 - discount/100), 2)
            order_items.append((item_id, order_id, pid, qty, price_paid, discount))
            item_id += 1

        order_id += 1
    current += timedelta(days=1)

lines.append("-- sales_orders")
chunks = []
batch = []
for i, o in enumerate(orders):
    batch.append(f"({o[0]},{o[1]},{o[2]},{o[3]},'{o[4]}','{o[5]}')")
    if len(batch) >= 500:
        chunks.append("INSERT INTO sales_orders (order_id, customer_id, store_id, employee_id, order_date, payment_method) VALUES\n" + ",\n".join(batch) + ";")
        batch = []
if batch:
    chunks.append("INSERT INTO sales_orders (order_id, customer_id, store_id, employee_id, order_date, payment_method) VALUES\n" + ",\n".join(batch) + ";")
lines.append("\n\n".join(chunks) + "\n")

lines.append("-- sales_order_items")
batch = []
out_lines = []
for it in order_items:
    batch.append(f"({it[0]},{it[1]},{it[2]},{it[3]},{it[4]},{it[5]})")
    if len(batch) >= 500:
        out_lines.append("INSERT INTO sales_order_items (order_item_id, order_id, product_id, quantity, unit_price_paid, discount_pct) VALUES\n" + ",\n".join(batch) + ";")
        batch = []
if batch:
    out_lines.append("INSERT INTO sales_order_items (order_item_id, order_id, product_id, quantity, unit_price_paid, discount_pct) VALUES\n" + ",\n".join(batch) + ";")
lines.append("\n".join(out_lines) + "\n")

# ------------------------------------------------------------
# product_returns (about 3% of order items get returned)
# ------------------------------------------------------------
returns = []
return_id = 1
return_reasons = ["Defectueux", "Ne convient pas", "Erreur de commande", "Change d''avis"]
sample_items = random.sample(order_items, int(len(order_items) * 0.03))
for it in sample_items:
    item_id_ref = it[0]
    order_id_ref = it[1]
    order_date = next(o[4] for o in orders if o[0] == order_id_ref)
    y,m,d = map(int, order_date.split('-'))
    return_date = date(y,m,d) + timedelta(days=random.randint(1, 20))
    if return_date > date(2024,12,31):
        return_date = date(2024,12,31)
    reason = random.choice(return_reasons)
    returns.append((return_id, item_id_ref, return_date.isoformat(), reason))
    return_id += 1

lines.append("-- product_returns")
lines.append("INSERT INTO product_returns (return_id, order_item_id, return_date, reason) VALUES")
lines.append(",\n".join(f"({r[0]},{r[1]},'{r[2]}','{r[3]}')" for r in returns) + ";\n")

with open("/home/claude/retail-analytics-project/02_seed_data.sql", "w") as f:
    f.write("\n".join(lines))

print(f"Generated: {len(stores)} stores, {len(employees)} employees, {len(products)} products,")
print(f"{len(customers)} customers, {len(orders)} orders, {len(order_items)} order items, {len(returns)} returns")
