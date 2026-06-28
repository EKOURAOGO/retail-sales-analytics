# Retail Sales Analytics — MySQL

Base de données de vente au détail multi-magasins avec 12 mois de données réalistes (saisonnalité, churn client, marges produit) et 23 requêtes analytiques organisées en trois tableaux de bord métier : KPIs exécutifs, analyse client, performance commerciale. Schéma, données et requêtes sont **exécutables tels quels** sur MySQL 8.0+ ou MariaDB 10.5+, et validés par une suite de tests automatisés.

---

## Pourquoi ce projet

Un schéma de base de données ne suffit pas à démontrer une compétence analytique : ce qui compte, c'est la capacité à en extraire des décisions business. Ce projet simule une chaîne de 5 points de vente (4 magasins physiques + 1 boutique en ligne) sur une année complète, avec des données générées pour reproduire des phénomènes réels — saisonnalité des ventes, clients qui se désengagent, écarts de marge entre catégories — afin que chaque requête produise un résultat interprétable, pas une coquille vide.

---

## Structure du projet

```
retail-analytics/
├── 01_schema.sql                              # 8 tables, contraintes FK, index analytiques
├── 02_seed_data.sql                            # 909 commandes / 2258 lignes / 12 mois / 300 clients
├── generate_seed.py                            # Script de génération des données (reproductible, seed fixe)
├── queries_01_executive_kpis.sql               # 8 requêtes — chiffre d'affaires, marges, tendances
├── queries_02_customer_analytics.sql           # 9 requêtes — segmentation RFM, churn, fidélité
├── queries_03_employee_store_performance.sql   # 6 requêtes — classement vendeurs, comparaison magasins
├── run_tests.sh                                # Suite de 18 tests automatisés avec assertions
└── README.md
```

---

## Schéma de données

8 tables représentant une chaîne de distribution multi-canal :

| Table | Rôle |
|-------|------|
| `stores` | 5 points de vente (4 magasins + boutique en ligne), avec date d'ouverture |
| `employees` | 32 vendeurs répartis par magasin, avec rôle (Vendeur, Manager...) |
| `categories` / `products` | 5 catégories, 25 produits avec coût et prix de vente |
| `customers` | 300 clients avec ville, date d'inscription, statut fidélité |
| `sales_orders` / `sales_order_items` | Commandes et lignes de commande (remise par ligne) |
| `product_returns` | Retours produit avec motif, environ 3% des lignes vendues |

**Caractéristiques volontairement intégrées au jeu de données :**

- Saisonnalité réaliste : pic de ventes en novembre-décembre, creux en août
- 40 clients qui cessent de commander à une date donnée (pour l'analyse de churn)
- Marges variables par produit (de 43% sur l'électronique à 79% sur le textile)
- Remises ponctuelles sur certaines lignes de commande (0 à 15%)
- Retours produit répartis de façon inégale selon la catégorie

---

## Tableaux de bord couverts

### KPIs exécutifs (`queries_01`)
Chiffre d'affaires global et par mois avec taux de croissance, classement des magasins, répartition du revenu par catégorie, top 10 produits, marge brute par produit, taux de retour par catégorie, répartition des moyens de paiement.

### Analyse client (`queries_02`)
Segmentation RFM (Champion / Loyal / Regular / At Risk), détection des clients à risque de churn (>90 jours sans commande), clients jamais convertis, comparaison fidèles vs non-fidèles, top 10 clients par valeur vie, acquisition mensuelle, répartition géographique du revenu.

### Performance commerciale (`queries_03`)
Classement des vendeurs par chiffre d'affaires généré, meilleur vendeur par magasin, performance moyenne par rôle, ratio commandes/jour depuis l'ouverture par magasin, tendance mensuelle par magasin (vue pivotée), vendeurs sous la moyenne de leur magasin.

---

## Installation

```bash
# Créer la base et charger le schéma
mysql -u root < 01_schema.sql

# Charger les données de test (909 commandes, 2258 lignes, 300 clients)
mysql -u root < 02_seed_data.sql

# Exécuter un tableau de bord
mysql -u root retail_analytics < queries_01_executive_kpis.sql
```

Pour régénérer un jeu de données différent (autre seed, autre volume) :

```bash
python3 generate_seed.py
```

---

## Lancer les tests

La suite vérifie l'intégrité référentielle des données et le résultat de requêtes clés contre des valeurs attendues.

```bash
chmod +x run_tests.sh
./run_tests.sh
```

Sortie attendue :

```
RESULTS: 18 passed, 0 failed
```

Exemples d'assertions vérifiées :

| Test | Résultat attendu |
|------|-------------------|
| Catégorie générant le plus de revenu | Electronique |
| Produit le plus vendu en valeur | Laptop Pro 15 |
| Magasin générant le plus de chiffre d'affaires | Online Store |
| Marge la plus élevée (Jean slim) | ~78,8 % |
| Zéro commande orpheline (sans client valide) | 0 |
| Zéro ligne de commande orpheline (sans produit valide) | 0 |

---

## Aperçu des résultats

**Chiffre d'affaires 2024 :** 1 437 349 € sur 909 commandes (panier moyen : 1 581 €)

**Saisonnalité observée :** +46,8 % en novembre, +36,2 % en décembre, -44,4 % en août par rapport au mois précédent

**Répartition par catégorie :** Électronique (31,6 %) > Mobilier (23,3 %) > Maison & Jardin (21,9 %) > Sport (18,2 %) > Vêtements (5,0 %)

**Segmentation client :** sur 300 clients, 102 présentent un risque de désengagement (plus de 90 jours sans commande)

---

## Notes techniques

- Toutes les requêtes utilisent la syntaxe **MySQL 8.0+** (`DATE_FORMAT`, `WITH ... AS`, fenêtrage `RANK`/`LAG`).
- Les dates de référence sont fixées à `'2024-12-31'` pour garantir des résultats reproductibles sur un jeu de données historique figé.
- Le script `generate_seed.py` utilise une seed aléatoire fixe (`random.seed(42)`), garantissant que les données générées sont identiques à chaque exécution.

---

## Stack technique

![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=mysql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Window%20Functions%20·%20CTE%20·%20RFM-blue?style=flat-square)
![Bash](https://img.shields.io/badge/Bash-Tests%20automatisés-4EAA25?style=flat-square&logo=gnubash&logoColor=white)

---

## Auteur

**Emmanuel KOURAOGO**

[GitHub](https://github.com/EKOURAOGO) · [Email](mailto:ekouraogo73@gmail.com)
