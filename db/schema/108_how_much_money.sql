-- FOOD-108 Отчёт «сколько денег» (how_much_money)

SET search_path TO chaplygin_food, exts, public

CREATE OR REPLACE VIEW how_much_money AS
WITH RECURSIVE first_last AS (
    SELECT
        date_trunc('month', min(order_timestamp))::date AS first_month,
        date_trunc('month', max(order_timestamp))::date AS last_month
    FROM pidido
    WHERE status = 'доставлен'
),
months AS (
    -- рекурсивный CTE: непрерывная серия месяцев
    SELECT first_month AS month_start
    FROM first_last
    WHERE first_month IS NOT NULL

    UNION ALL

    SELECT (m.month_start + interval '1 month')::date
    FROM months m
    JOIN first_last fl ON true
    WHERE (m.month_start + interval '1 month')::date <= fl.last_month
),
orders_agg AS (
    -- агрегат по доставленным заказам
    SELECT
        date_trunc('month', order_timestamp)::date AS month_start,
        coalesce(sum(order_amount), 0)  AS sum_no_commission,
        coalesce(sum(total_amount), 0)  AS sum_with_commission
    FROM pidido
    WHERE status = 'доставлен'
    GROUP BY date_trunc('month', order_timestamp)::date
),
courier_agg AS (
    -- агрегат по courier_pay
    SELECT
        make_date(year, month, 1) AS month_start,
        coalesce(sum(amount), 0)  AS courier_pay
    FROM courier_pay
    GROUP BY make_date(year, month, 1)
),
combined AS (
    SELECT
        to_char(m.month_start, 'YYYY-MM') AS year_month,
        coalesce(oa.sum_no_commission, 0)   AS sum_no_commission,
        coalesce(oa.sum_with_commission, 0) AS sum_with_commission,
        coalesce(oa.sum_with_commission, 0) - coalesce(oa.sum_no_commission, 0) AS commission,
        coalesce(ca.courier_pay, 0)         AS courier_pay
    FROM months m
    LEFT JOIN orders_agg  oa ON oa.month_start = m.month_start
    LEFT JOIN courier_agg ca ON ca.month_start = m.month_start
),
with_prev AS (
    SELECT
        year_month,
        sum_no_commission,
        sum_with_commission,
        commission,
        lag(commission) OVER (ORDER BY year_month) AS prev_commission,
        courier_pay
    FROM combined
)
SELECT
    year_month,
    sum_no_commission,
    sum_with_commission,
    commission,
    prev_commission,
    commission - prev_commission  AS commission_diff,
    courier_pay,
    commission - courier_pay      AS net_profit
FROM with_prev;