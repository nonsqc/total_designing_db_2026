-- FOOD-107 Зарплата курьеров

SET search_path TO chaplygin_food, exts, public

CREATE OR REPLACE PROCEDURE chaplygin_food.courier_salary()
LANGUAGE plpgsql AS $$
DECLARE
    v_year          INT := extract(year  FROM current_date)::int;
    v_month         INT := extract(month FROM current_date)::int;
    v_month_start   DATE := date_trunc('month', current_date)::date;
    v_month_end     DATE := (date_trunc('month', current_date) + interval '1 month')::date;

    v_courier_id    UUID;
    v_curr_coeff    NUMERIC(2,1);
    v_deliveries    INT;
    v_commissions   NUMERIC(12,2);
    v_amount        NUMERIC(12,2);
    v_new_coeff     NUMERIC(2,1);
BEGIN
    -- один SELECT: courier_id + coefficient (без второго SELECT)
    FOR v_courier_id, v_curr_coeff IN
        SELECT courier_id, coefficient FROM chaplygin_food.courier
    LOOP
        -- доставки и сумма комиссий за текущий месяц
        SELECT count(*), COALESCE(sum(commission), 0)
        INTO v_deliveries, v_commissions
        FROM chaplygin_food."order"
        WHERE courier_id = v_courier_id
          AND status = 'доставлен'
          AND order_timestamp >= v_month_start
          AND order_timestamp <  v_month_end;

        v_amount := round(v_curr_coeff * v_commissions, 2);

        -- повторный вызов обновляет (BR-10.2: расчёт за месяц — один раз)
        INSERT INTO chaplygin_food.courier_pay (year, month, courier_id, amount, coefficient_used)
        VALUES (v_year, v_month, v_courier_id, v_amount, v_curr_coeff)
        ON CONFLICT (year, month, courier_id) DO UPDATE
        SET amount = EXCLUDED.amount,
            coefficient_used = EXCLUDED.coefficient_used;

        -- новый коэффициент на следующий месяц
        v_new_coeff := CASE
            WHEN v_deliveries <= 150 THEN 0.1
            WHEN v_deliveries <= 250 THEN 0.2
            WHEN v_deliveries <= 500 THEN 0.3
            ELSE 0.5
        END;

        -- обновляем только для работающих (BR-10.6)
        UPDATE chaplygin_food.courier
        SET coefficient = v_new_coeff
        WHERE courier_id = v_courier_id
          AND status <> 'уволен';
    END LOOP;
END;
$$;