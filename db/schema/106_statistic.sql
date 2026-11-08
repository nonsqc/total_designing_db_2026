-- FOOD-106 Статистика по ресторанам

SET search_path TO chaplygin_food, exts, public

CREATE OR REPLACE FUNCTION get_statistic()
RETURNS TABLE (
    restaurant_name   VARCHAR(100),
    best_product_name VARCHAR(100),
    total_amount      NUMERIC,
    avg_amount        NUMERIC,
    best_user         VARCHAR(50)
)
LANGUAGE sql
STABLE
SET search_path = chaplygin_food, exts, public
AS $$
WITH delivered AS (
    SELECT o.order_id, o.restaurant_id, o.client_id, o.total_amount
    FROM pidido o
    WHERE o.status = 'доставлен'
),
rest_stats AS (
    SELECT restaurant_id,
           sum(total_amount) AS total_amount,
           avg(total_amount) AS avg_amount
    FROM delivered
    GROUP BY restaurant_id
),
product_stats AS (
    SELECT
        d.restaurant_id,
        p.product_name,
        sum(os.quantity) AS qty,
        row_number() OVER (
            PARTITION BY d.restaurant_id
            ORDER BY sum(os.quantity) DESC, random()
        ) AS rn
    FROM delivered d
    JOIN order_structure os ON os.order_id = d.order_id
    JOIN product p ON p.product_id = os.product_id
    GROUP BY d.restaurant_id, p.product_id, p.product_name
),
best_product AS (
    SELECT restaurant_id, product_name FROM product_stats WHERE rn = 1
),
user_stats AS (
    SELECT
        d.restaurant_id,
        c.login,
        count(*) AS cnt,
        row_number() OVER (
            PARTITION BY d.restaurant_id
            ORDER BY count(*) DESC, random()
        ) AS rn
    FROM delivered d
    JOIN client c ON c.client_id = d.client_id
    GROUP BY d.restaurant_id, c.client_id, c.login
),
best_user AS (
    SELECT restaurant_id, login FROM user_stats WHERE rn = 1
)
SELECT
    r.restaurant_name,
    bp.product_name AS best_product_name,
    rs.total_amount,
    rs.avg_amount,
    bu.login AS best_user
FROM restaurant r
LEFT JOIN rest_stats   rs ON rs.restaurant_id = r.restaurant_id
LEFT JOIN best_product bp ON bp.restaurant_id = r.restaurant_id
LEFT JOIN best_user    bu ON bu.restaurant_id = r.restaurant_id;
$$;