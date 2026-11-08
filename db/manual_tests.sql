-- A.2. Переключение на inspector
SET ROLE inspector;
SET search_path TO chaplygin_food, exts;
SELECT current_user;
-- Ожидается: current_user = inspector

-- B. FOOD-101: Структура схемы
-- B.1. Схема существует
SELECT schema_name FROM information_schema.schemata
WHERE schema_name LIKE '%_food';
-- Ожидается: chaplygin_food

-- B.2. Схема `exts` с `uuid-ossp`
SELECT extname, extnamespace::regnamespace AS schema
FROM pg_extension WHERE extname = 'uuid-ossp';
-- Ожидается: uuid-ossp, схема exts

-- B.3. Все 12 исходных таблиц + N после нормализации
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'chaplygin_food'
ORDER BY table_name;
-- Ожидается: address, client, client_address, courier, courier_pay,
-- pidido, order_structure, payment, product, product_category,
-- restaurant, review, review_product, review_restaurant, review_order
-- (15 таблиц)

-- B.4. Все PK — `uuid`
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'chaplygin_food'
  AND column_name LIKE '%_id'
  AND data_type != 'uuid';
-- Ожидается: пусто (все PK — uuid; payment.transaction_id — внешний
-- идентификатор, VARCHAR(255), не UUID, BR-8.3)

-- B.5. Enum-типы
SELECT t.typname, array_agg(e.enumlabel ORDER BY e.enumsortorder) AS values
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'chaplygin_food'
GROUP BY t.typname
ORDER BY t.typname;
-- Ожидается: 8 типов со значениями из constraints.md:
-- restaurant_status, product_status, courier_status, order_status,
-- order_pay_status, payment_type, payment_status, review_entity_type

-- B.6. FK-ограничения
SELECT conname, conrelid::regclass AS tbl, confrelid::regclass AS ref
FROM pg_constraint
WHERE contype = 'f'
  AND connamespace = 'chaplygin_food'::regnamespace
ORDER BY tbl, conname;
-- Ожидается: не менее 12 FK

-- B.7. Пароль — MD5
SELECT length(password) AS len, password
FROM client LIMIT 5;
-- Ожидается: len = 32, hex-строка

-- C. FOOD-102: `insert_test_data(value)`
-- C.1. Чистая схема
CALL erase_test_data();
-- Ожидается: без ошибок

-- C.2. Первый запуск
CALL insert_test_data(10);
-- Ожидается: без ошибок

-- C.3. Распределение строк (BR-11.7)
SELECT 'client' AS tbl, count(*) FROM client
UNION ALL SELECT 'courier', count(*) FROM courier
UNION ALL SELECT 'product_category', count(*) FROM product_category
UNION ALL SELECT 'restaurant', count(*) FROM restaurant
UNION ALL SELECT 'address', count(*) FROM address
UNION ALL SELECT 'product', count(*) FROM product
UNION ALL SELECT 'order', count(*) FROM pidido
UNION ALL SELECT 'review', count(*) FROM review
UNION ALL SELECT 'payment', count(*) FROM payment
ORDER BY tbl;
-- Ожидается: 10, 10, 10, 10, 50, 50, 50, 50, 50

-- C.4. Адреса ресторанов vs клиентов (BR-11.7)
SELECT 'restaurant addresses' AS cat, count(*) FROM restaurant WHERE address_id IS NOT NULL
UNION ALL
SELECT 'total addresses', count(*) FROM address;
-- Ожидается: 10 ресторанных адресов, 50 всего → 40 клиентских

-- C.5. Нет пустых строк (BR-11.3)
SELECT count(*) FROM client WHERE login = '' OR password = '' OR phone_number = '';
-- Ожидается: 0

-- C.6. Нет NULL там, где запрещено (BR-11.3)
SELECT count(*) FROM pidido WHERE client_id IS NULL OR restaurant_id IS NULL
  OR courier_id IS NULL OR address_id IS NULL OR total_amount IS NULL;
-- Ожидается: 0

-- C.7. Минимум один активный курьер (BR-6.6)
SELECT count(*) FROM courier WHERE status != 'уволен';
-- Ожидается: >= 1

-- C.8. `courier_pay` консистентен с правилами (BR-10.2)
SELECT cp.year, cp.month, cp.courier_id, cp.amount, cp.coefficient_used,
       round(coalesce((
           SELECT sum(o.commission)
           FROM pidido o
           WHERE o.courier_id = cp.courier_id
             AND o.status = 'доставлен'
             AND extract(year  from o.order_timestamp) = cp.year
             AND extract(month from o.order_timestamp) = cp.month
       ), 0) * cp.coefficient_used, 2) AS expected_amount
FROM courier_pay cp
LIMIT 20;
-- Ожидается: amount = expected_amount в каждой строке

-- C.9. Повторный вызов не ломает
DO $$
BEGIN
    FOR i IN 1..10 LOOP
        CALL insert_test_data(10);
    END LOOP;
END $$;
-- Ожидается: без ошибок, данные добавляются или заменяются
-- (по решению студента, задокументированному в constraints.md).

-- D.1. Все FK валидны (нет orphans)
SELECT 'order_structure → order' AS fk, count(*) AS orphans
FROM order_structure os
LEFT JOIN pidido o ON os.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_structure → product', count(*)
FROM order_structure os
LEFT JOIN product p ON os.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'payment → order', count(*)
FROM payment pmt
LEFT JOIN pidido o ON pmt.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'review → order', count(*)
FROM review r
LEFT JOIN pidido o ON r.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'courier_pay → courier', count(*)
FROM courier_pay cp
LEFT JOIN courier c ON cp.courier_id = c.courier_id
WHERE c.courier_id IS NULL
UNION ALL
SELECT 'client_address → client', count(*)
FROM client_address ca
LEFT JOIN client c ON ca.client_id = c.client_id
WHERE c.client_id IS NULL
UNION ALL
SELECT 'client_address → address', count(*)
FROM client_address ca
LEFT JOIN address a ON ca.address_id = a.address_id
WHERE a.address_id IS NULL;
-- Ожидается: все 0

-- D.2. Минимальная сумма заказа (BR-1.8)
SELECT count(*) FROM pidido WHERE total_amount < 1000;
-- Ожидается: 0

-- D.3. Комиссия = 10% (BR-1.4)
SELECT count(*) FROM pidido WHERE round(order_amount * 0.10, 2) != commission;
-- Ожидается: 0

-- D.4. `total_amount = order_amount + commission`
SELECT count(*) FROM pidido
WHERE round(order_amount + commission, 2) != total_amount;
-- Ожидается: 0

-- D.5. Дата доставки не раньше создания (BR-7.13)
SELECT count(*) FROM pidido
WHERE delivery_timestamp IS NOT NULL AND delivery_timestamp < order_timestamp;
-- Ожидается: 0

-- D.6. Адрес доставки принадлежит клиенту (BR-7.4)
SELECT count(*) FROM pidido o
LEFT JOIN client_address ca
  ON ca.client_id = o.client_id AND ca.address_id = o.address_id
WHERE ca.client_id IS NULL;
-- Ожидается: 0

-- D.7. Все блюда в заказе из одного ресторана (BR-7.3)
SELECT count(DISTINCT os.order_id)
FROM order_structure os
JOIN pidido o ON os.order_id = o.order_id
JOIN product p ON os.product_id = p.product_id
WHERE p.restaurant_id != o.restaurant_id;
-- Ожидается: 0

-- D.8. Ровно одна успешная оплата на заказ (BR-8.1)
SELECT order_id, count(*) AS cnt
FROM payment
WHERE status = 'успех'
GROUP BY order_id
HAVING count(*) != 1;
-- Ожидается: пусто

-- D.9. Сумма оплаты = total_amount заказа (BR-8.4)
SELECT count(*) FROM payment p
JOIN pidido o ON p.order_id = o.order_id
WHERE p.amount != o.total_amount;
-- Ожидается: 0

-- D.10. Нет дубликатов в client_address (BR-2.5)
SELECT client_id, address_id, count(*)
FROM client_address
GROUP BY client_id, address_id
HAVING count(*) > 1;
-- Ожидается: пусто

-- D.11. Нет дубликатов в order_structure (BR-7.16)
SELECT order_id, product_id, count(*)
FROM order_structure
GROUP BY order_id, product_id
HAVING count(*) > 1;
-- Ожидается: пусто

-- D.12. work_end > work_start (BR-4.4)
SELECT count(*) FROM restaurant WHERE work_end <= work_start;
-- Ожидается: 0

-- D.13. dismissal_date >= hire_date (BR-6.3)
SELECT count(*) FROM courier
WHERE dismissal_date IS NOT NULL AND dismissal_date < hire_date;
-- Ожидается: 0

-- D.14. Рейтинг блюд/ресторанов соответствует отзывам (BR-9.6)
-- Адаптировано под нормализацию (entity_type → review_product / review_restaurant)

-- D.14.1 product.rating
SELECT p.product_id, p.rating,
       (SELECT round(avg(r.rating), 2)
        FROM review_product rp
        JOIN review r ON r.review_id = rp.review_id
        WHERE rp.product_id = p.product_id) AS expected
FROM product p
WHERE p.rating IS NOT NULL
ORDER BY p.product_id
LIMIT 20;
-- Ожидается: rating = expected

-- D.14.2 restaurant.rating
SELECT r.restaurant_id, r.rating,
       (SELECT round(avg(rv.rating), 2)
        FROM review_restaurant rr
        JOIN review rv ON rv.review_id = rr.review_id
        WHERE rr.restaurant_id = r.restaurant_id) AS expected
FROM restaurant r
WHERE r.rating IS NOT NULL
ORDER BY r.restaurant_id
LIMIT 20;

-- E. Функции и процедуры
-- E.1. add_product — успешный вызов
SELECT count(*) AS before FROM product;

DO $$
DECLARE
    v_rest_id UUID;
    v_cat_id  UUID;
BEGIN
    SELECT restaurant_id INTO v_rest_id FROM restaurant LIMIT 1;
    SELECT product_category_id INTO v_cat_id FROM product_category LIMIT 1;
    CALL add_product(
        p_restaurant_id       => v_rest_id,
        p_product_category_id => v_cat_id,
        p_product_name        => 'Тестовое блюдо',
        p_price               => 250,
        p_rating              => 4.5,
        p_status              => 'доступно',
        p_description         => 'Описание'
    );
END;
$$;

SELECT count(*) AS after FROM product;
-- Ожидается: after = before + 1

-- E.2. add_product — падает на несуществующий ресторан
DO $$
DECLARE
    v_cat_id UUID;
BEGIN
    SELECT product_category_id INTO v_cat_id FROM product_category LIMIT 1;

    CALL add_product(
        p_restaurant_id       => '00000000-0000-0000-0000-000000000000'::UUID,
        p_product_category_id => v_cat_id,
        p_product_name        => 'Блюдо',
        p_price               => 100,
        p_status              => 'доступно',
        p_description         => 'Описание'
    );
END;
$$;
-- Ожидается: ERROR "Ресторан с id ... не существует (BR-5.1)"

-- E.3. rating_change — пересчитывает рейтинг (вставка)
-- Выбрать заказ, блюдо и клиента
SELECT p.product_id, p.rating
FROM product p
WHERE p.rating IS NOT NULL
LIMIT 1; -- product_id					|	rating
-- d5b299f2-d1c5-4f6c-9040-ad7eb92211e5	|   3.33

-- Все отзывы по product_id
SELECT r.review_id, r.rating
FROM review_product rp
JOIN review r ON r.review_id = rp.review_id
WHERE rp.product_id = 'd5b299f2-d1c5-4f6c-9040-ad7eb92211e5';
-- Среднее = (1+4+5) / 3 = 3.33

SELECT o.order_id, o.client_id
FROM pidido o
LIMIT 1; -- order_id					|	client_id
-- e771cbc5-bb90-4ecb-85ee-70cecc30530c	| 32313f2d-efa0-492f-a279-03f981767119

-- Вставить отзыв на это блюдо
INSERT INTO review (review_id, client_id, order_id, review_timestamp,
                    description, photo_url, rating)
VALUES (
	    exts.uuid_generate_v4(),
	    '32313f2d-efa0-492f-a279-03f981767119',
	    'e771cbc5-bb90-4ecb-85ee-70cecc30530c',
	    localtimestamp,
	    'Тестовый отзыв',
	    NULL,
	    5
)
RETURNING review_id; -- review_id 4e6ab6e0-404e-40ad-8197-55ef32a2c72d

-- Вставить review_product
INSERT INTO review_product (review_id, order_id, product_id)
VALUES (
    '4e6ab6e0-404e-40ad-8197-55ef32a2c72d',
    'e771cbc5-bb90-4ecb-85ee-70cecc30530c',
    'd5b299f2-d1c5-4f6c-9040-ad7eb92211e5'
);

-- Проверить рейтинг
SELECT rating FROM product WHERE product_id = 'd5b299f2-d1c5-4f6c-9040-ad7eb92211e5'; 
-- Среднее = (1+4+5+5) / 4 = 3.75
-- Ожидается: rating = expected

-- E.4. rating_change — удаление отзыва
-- Удалить review_product
DELETE FROM review_product 
WHERE review_id = '00e6464a-f6bd-4dd2-84cd-1c2b6d96bf33';
-- Удалить review
DELETE FROM review 
WHERE review_id = '00e6464a-f6bd-4dd2-84cd-1c2b6d96bf33';

-- Проверить рейтинг после удаления
SELECT rating FROM product
WHERE product_id = 'd5b299f2-d1c5-4f6c-9040-ad7eb92211e5';
-- Ожидается: 4.5 = (4+5) / 2
-- Ожидается: rating = expected (или NULL, если отзывов не осталось)

-- E.5. get_statistic()
SELECT * FROM get_statistic();
-- Ожидается: колонки restaurant_name, best_product_name,
-- total_amount, avg_amount, best_user;
-- по одной строке на ресторан; best_user не NULL при наличии заказов

-- E.6. courier_salary()
SELECT courier_id, status, coefficient FROM courier ORDER BY courier_id;

-- Добавляем 501 заказ для 2 курьеров (уволенного и работающего)
DO $$
DECLARE
    v_courier_id UUID := '<courier_id>';
    v_month_start DATE := date_trunc('month', current_date)::date;
    v_month_end   DATE := (date_trunc('month', current_date) + interval '1 month')::date;
    v_client_id   UUID;
    v_address_id  UUID;
    v_rest_id     UUID;
    v_order_amt   NUMERIC(12,2);
    v_comm        NUMERIC(12,2);
BEGIN
    -- проверка, что курьер существует и работает (закомментировано для добавления заказов уволенному)
    IF NOT EXISTS (SELECT 1 FROM courier WHERE courier_id = v_courier_id /*AND status <> 'уволен'*/) THEN
        RAISE EXCEPTION 'Курьер % не найден или уволен', v_courier_id;
    END IF;
    -- любые client_id + address_id (пара из client_address)
    SELECT client_id, address_id INTO v_client_id, v_address_id
    FROM client_address LIMIT 1;
    -- любой ресторан
    SELECT restaurant_id INTO v_rest_id FROM restaurant LIMIT 1;
    -- 501 заказ
    INSERT INTO pidido (
        order_id, courier_id, client_id, address_id, restaurant_id,
        order_timestamp, delivery_timestamp,
        order_amount, commission, total_amount,
        status, pay_status, description
    )
    SELECT
        exts.uuid_generate_v4(),
        v_courier_id,
        v_client_id,
        v_address_id,
        v_rest_id,
        -- order_timestamp — в текущем месяце
        v_month_start + (random() * (v_month_end - v_month_start)) * interval '1 day',
        -- delivery_timestamp — +1..3 часа (для доставленных)
        v_month_start + (random() * (v_month_end - v_month_start)) * interval '1 day'
            + (1 + random() * 2) * interval '1 hour',
        round((909.09 + random() * 4000)::numeric, 2),
        round(round((909.09 + random() * 4000)::numeric, 2) * 0.10, 2),
        round((909.09 + random() * 4000)::numeric, 2)
            + round(round((909.09 + random() * 4000)::numeric, 2) * 0.10, 2),
        'доставлен'::order_status,
        'оплачен'::order_pay_status,
        NULL
    FROM generate_series(1, 501);

    RAISE NOTICE '501 заказ для курьера % созданы', v_courier_id;
END;
$$;

CALL courier_salary();

SELECT year, month, courier_id, amount, coefficient_used
FROM courier_pay
ORDER BY year DESC, month DESC, courier_id
LIMIT 20;
-- Ожидается: coefficient пересчитан для работающих;
-- у уволенных не изменился; courier_pay содержит запись за текущий месяц


-- E.7. courier_salary() — повторный вызов
CALL courier_salary();

SELECT count(*) FROM courier_pay
WHERE year  = extract(year  FROM current_date)::int
  AND month = extract(month FROM current_date)::int;
-- Ожидается: количество не изменилось (idempotency)

-- F. Представление `how_much_money`
-- F.1. Колонки how_much_money
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'chaplygin_food'
  AND table_name = 'how_much_money'
ORDER BY ordinal_position;
-- Ожидается: year_month (text), sum_no_commission (numeric),
-- sum_with_commission (numeric), commission (numeric),
-- prev_commission (numeric), commission_diff (numeric),
-- courier_pay (numeric), net_profit (numeric)


-- F.2. Месяцы покрыты
SELECT * FROM how_much_money ORDER BY year_month;
-- Ожидается: все месяцы от первого доставленного заказа до последнего


-- F.3. Месяцы без заказов присутствуют (BR-11.9)
SELECT year_month FROM how_much_money
WHERE sum_no_commission = 0 AND sum_with_commission = 0;
-- Ожидается: месяцы без заказов присутствуют (если такие были)

-- Принудительно удаляем 2026-06
SELECT count(*) AS cnt,
       sum(total_amount) AS total
FROM pidido
WHERE status = 'доставлен'
  AND order_timestamp >= '2026-06-01'
  AND order_timestamp <  '2026-07-01';
-- 5	18218.03

BEGIN;

-- 1. запомнить order_id за 2026-06
CREATE TEMP TABLE tmp_june_orders AS
SELECT order_id FROM pidido
WHERE status = 'доставлен'
  AND order_timestamp >= '2026-06-01'
  AND order_timestamp <  '2026-07-01';

-- 2. удалить дочерние review
DELETE FROM review_product
WHERE order_id IN (SELECT order_id FROM tmp_june_orders);

DELETE FROM review_restaurant
WHERE order_id IN (SELECT order_id FROM tmp_june_orders);

DELETE FROM review_order
WHERE order_id IN (SELECT order_id FROM tmp_june_orders);

-- 3. удалить review
DELETE FROM review
WHERE order_id IN (SELECT order_id FROM tmp_june_orders);

-- 4. удалить payment
DELETE FROM payment
WHERE order_id IN (SELECT order_id FROM tmp_june_orders);

-- 5. удалить order_structure
DELETE FROM order_structure
WHERE order_id IN (SELECT order_id FROM tmp_june_orders);

-- 6. удалить pidido
DELETE FROM pidido
WHERE order_id IN (SELECT order_id FROM tmp_june_orders);

COMMIT;

-- 0 [NULL]

SELECT year_month,
       sum_no_commission,
       sum_with_commission,
       commission,
       courier_pay,
       net_profit
FROM how_much_money
WHERE year_month = '2026-06';
-- 2026-06	0	0

-- F.4. Корректность сумм
SELECT year_month,
       sum_no_commission,
       sum_with_commission,
       commission,
       prev_commission,
       commission_diff,
       courier_pay,
       net_profit
FROM how_much_money
ORDER BY year_month
LIMIT 10;
-- Ожидается:
--   commission = sum_with_commission - sum_no_commission
--   commission_diff = commission - prev_commission (NULL для первого)
--   net_profit = commission - courier_pay

-- G. Права `inspector`
-- G.1. Права на схему (адаптировано: role_schema_grants не существует в PG)
SELECT
    nspname AS schema_name,
    has_schema_privilege('inspector', nspname, 'USAGE')  AS usage,
    has_schema_privilege('inspector', nspname, 'CREATE') AS create
FROM pg_namespace
WHERE nspname = 'chaplygin_food';
-- Ожидается: true, true

-- G.2. Права на таблицы
SELECT table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privs
FROM information_schema.role_table_grants
WHERE grantee = 'inspector'
  AND table_schema = 'chaplygin_food'
GROUP BY table_name
ORDER BY table_name;
-- Ожидается: у каждой таблицы SELECT, INSERT, UPDATE, DELETE (или ALL)

-- G.3. information_schema читается под inspector
SET ROLE inspector;
SET search_path TO chaplygin_food, exts, public;

SELECT count(*) FROM information_schema.tables
WHERE table_schema = 'chaplygin_food';
-- Ожидается: 16

RESET ROLE;

-- G.4. pg_catalog читается под inspector
SET ROLE inspector;
SET search_path TO chaplygin_food, exts, public;

SELECT count(*) FROM pg_catalog.pg_tables
WHERE schemaname = 'chaplygin_food';
-- Ожидается: 15

RESET ROLE;


-- G.5. Все процедуры/функции работают под inspector
SET ROLE inspector;
SET search_path TO chaplygin_food, exts;

CALL erase_test_data();
CALL insert_test_data(10);
CALL courier_salary();
SELECT * FROM get_statistic()   LIMIT 5;
SELECT * FROM how_much_money    LIMIT 5;

RESET ROLE;
-- Ожидается: без permission denied

-- H. Оптимизация `get_statistic` (BR-11.8)
-- H.1. EXPLAIN ANALYZE — паттерн «избыточные подзапросы» (плохо)
EXPLAIN ANALYZE
SELECT c.courier_id,
       (SELECT count(*)  FROM pidido o WHERE o.courier_id = c.courier_id AND o.status = 'доставлен') AS cnt,
       (SELECT coalesce(sum(commission), 0) FROM pidido o WHERE o.courier_id = c.courier_id AND o.status = 'доставлен') AS commission_sum
FROM courier c;
-- Ожидается: два SubPlan, каждый — скан pidido

-- H.2. EXPLAIN ANALYZE — паттерн «один JOIN» (хорошо)
EXPLAIN ANALYZE
SELECT c.courier_id,
       count(o.order_id) AS cnt,
       coalesce(sum(o.commission), 0) AS commission_sum
FROM courier c
LEFT JOIN pidido o ON o.courier_id = c.courier_id AND o.status = 'доставлен'
GROUP BY c.courier_id;
-- Ожидается: один Hash Left Join, один скан pidido

-- H.3. EXPLAIN ANALYZE get_statistic
EXPLAIN ANALYZE SELECT * FROM get_statistic();
-- Ожидается: без LATERAL, без множественных подзапросов к pidido,
-- без избыточных окон

-- I. Очистка и повторная генерация
-- I.1. erase_test_data очищает всё
CALL erase_test_data();

SELECT 'client' AS tbl, count(*) FROM client
UNION ALL SELECT 'courier',           count(*) FROM courier
UNION ALL SELECT 'product_category',  count(*) FROM product_category
UNION ALL SELECT 'restaurant',        count(*) FROM restaurant
UNION ALL SELECT 'address',           count(*) FROM address
UNION ALL SELECT 'product',           count(*) FROM product
UNION ALL SELECT 'pidido',            count(*) FROM pidido
UNION ALL SELECT 'review',            count(*) FROM review
UNION ALL SELECT 'payment',           count(*) FROM payment
UNION ALL SELECT 'order_structure',   count(*) FROM order_structure
UNION ALL SELECT 'client_address',    count(*) FROM client_address
UNION ALL SELECT 'courier_pay',       count(*) FROM courier_pay
UNION ALL SELECT 'review_product',    count(*) FROM review_product
UNION ALL SELECT 'review_restaurant', count(*) FROM review_restaurant
UNION ALL SELECT 'review_order',      count(*) FROM review_order
ORDER BY tbl;
-- Ожидается: все 0

-- I.2. Повторный erase_test_data не падает
CALL erase_test_data();
-- Ожидается: без ошибок

-- I.3. После очистки insert_test_data снова работает
CALL insert_test_data(10);

SELECT count(*) FROM pidido;
-- Ожидается: 50

