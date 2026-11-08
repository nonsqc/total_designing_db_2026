-- FOOD-107 Зарплата курьеров

SET search_path TO chaplygin_food, exts, public

CREATE OR REPLACE PROCEDURE courier_salary()
LANGUAGE plpgsql AS $$
DECLARE
    v_year  INT := EXTRACT(year  from current_date)::int;
    v_month INT := EXTRACT(month from current_date)::int;
    v_month_start DATE := date_trunc('month', current_date)::date;
    v_month_end   DATE := (date_trunc('month', current_date) + interval '1 month')::date;

    v_courier_id     UUID;
    v_curr_coeff     NUMERIC(2,1);
    v_deliveries     INT;
    v_commissions    NUMERIC(12,2);
    v_amount         NUMERIC(12,2);
    v_new_coeff      NUMERIC(2,1);
BEGIN
    FOR v_courier_id IN (SELECT courier_id FROM courier) LOOP

        -- текущий коэффициент (для этого месяца)
        SELECT coefficient INTO v_curr_coeff
        FROM courier 
        WHERE courier_id = v_courier_id;

        -- доставки и сумма комиссий за текущий месяц
        SELECT
            count(*),
            COALESCE(sum(commission), 0)
        INTO v_deliveries, v_commissions
        FROM pidido
        WHERE courier_id = v_courier_id
          AND status = 'доставлен'
          AND order_timestamp >= v_month_start
          AND order_timestamp <  v_month_end;

        -- зарплата за текущий месяц
        v_amount := round(v_curr_coeff * v_commissions, 2);

        -- запись в courier_pay (ON CONFLICT — повторный вызов обновляет)
        INSERT INTO courier_pay (year, month, courier_id, amount, coefficient_used)
        VALUES (v_year, v_month, v_courier_id, v_amount, v_curr_coeff)
        ON CONFLICT (year, month, courier_id) DO UPDATE
        SET amount = EXCLUDED.amount,
            coefficient_used = EXCLUDED.coefficient_used;

        -- коэффициент на следующий месяц (BR-10.2)
        v_new_coeff := CASE
            WHEN v_deliveries <= 150 THEN 0.1
            WHEN v_deliveries <= 250 THEN 0.2
            WHEN v_deliveries <= 500 THEN 0.3
            ELSE 0.5
        END;

        -- обновить только для работающих (BR-10.6)
        UPDATE courier
        SET coefficient = v_new_coeff
        WHERE courier_id = v_courier_id
          AND status <> 'уволен';
    END LOOP;
END;
$$;