-- FOOD-102 Генератор тестовых данных

CREATE OR REPLACE PROCEDURE chaplygin_food.insert_test_data(p_value INT)
LANGUAGE plpgsql 
AS $$
DECLARE
    i					INT;
    j					INT;
    v_id				UUID;
    v_status			chaplygin_food.courier_status;
	v_hire				DATE;
	v_count				INT;
    v_category_ids		UUID[];
    v_restaurant_ids	UUID[];
    v_client_ids		UUID[];
    v_courier_ids		UUID[];
    v_addresses			UUID[];
    v_work_start		TIME;
    v_work_end			TIME;
    v_deliveries		INT;
	v_coefficient		NUMERIC(2,1);
	v_new_coefficient	NUMERIC(2,1);
	v_month				TIMESTAMP;
	v_commission		NUMERIC(7,2);
    v_n_addr_client     INT;
    v_n_clients         INT;
    v_n_addr            INT;
    v_addr              UUID;
    v_n_rest            INT;
    v_n_cat             INT;
    v_review_types      chaplygin_food.review_entity_type[];
    v_order_id          UUID;
    v_order_ids			UUID[];
    v_client_id         UUID;
    v_restaurant_id     UUID;
    v_order_timestamp   TIMESTAMP;
    v_product_id        UUID;
    v_i                 INT;

BEGIN
	v_count := p_value * 5;

	-- 1. BR-5.7 Категория блюда (product_category)
	FOR i IN 1..p_value LOOP
	    v_id := exts.uuid_generate_v4();
	    INSERT INTO chaplygin_food.product_category (product_category_id, product_category_name)
	    VALUES (
	        v_id,
	        'Категория ' || (SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 1 + floor(random() * 33)::int, 1), '')
	                         FROM generate_series(1, 10))
	    );
	    v_category_ids := array_append(v_category_ids, v_id);
	END LOOP;

    -- 2. BR-6.1–6.5 Курьеры (courier)
    FOR i IN 1..p_value LOOP
	    v_id := exts.uuid_generate_v4();
        v_status := (enum_range(NULL::chaplygin_food.courier_status))[1 + floor(random() * 4)::int];
        v_hire := current_date - (floor(random() * 180))::int;
    	INSERT INTO chaplygin_food.courier(courier_id, fio, phone_number, 
    					status, hire_date, dismissal_date, coefficient)
        VALUES (
            v_id,
            (SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 
            1 + floor(random() * 33)::int, 1), '')
             FROM generate_series(1, 8))
            || ' ' ||
            (SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 
            1 + floor(random() * 33)::int, 1), '')
             FROM generate_series(1, 6))
            || ' ' ||
            (SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 
            1 + floor(random() * 33)::int, 1), '')
             FROM generate_series(1, 10)),
            '+7' || lpad((7000000000 + floor(random() * 1000000000))::bigint::text, 10, '0'),
			v_status, v_hire,
            CASE WHEN v_status = 'уволен'::chaplygin_food.courier_status
                 THEN LEAST(current_date, v_hire + 1 + (floor(random() * 30))::int)
                 ELSE NULL
            END,
            0.1
        );
        v_courier_ids := array_append(v_courier_ids, v_id);
    END LOOP;

    -- 2.1 BR-6.6: минимум один активный курьер
    IF NOT EXISTS (
        SELECT 1 FROM chaplygin_food.courier WHERE status <> 'уволен' LIMIT 1)
    THEN
        UPDATE chaplygin_food.courier
        SET status = 'свободен', dismissal_date = NULL
        WHERE courier_id = (SELECT courier_id FROM chaplygin_food.courier LIMIT 1);
    END IF;

    -- 3. BR-3.1–3.2 Адреса (address)
    FOR i IN 1..v_count LOOP
        v_id := exts.uuid_generate_v4();
        INSERT INTO chaplygin_food.address(address_id, street, house_number, apartment_office)
        VALUES (
            v_id,
            'Улица ' || (SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 
            			1 + floor(random() * 33)::int, 1), '')
            			FROM generate_series(1, 8)),
            (1 + floor(random() * 200))::text,
            CASE WHEN random() < 0.2 THEN NULL ELSE (1 + floor(random() * 200))::text END
        );
        v_addresses := array_append(v_addresses, v_id);
    END LOOP;

    -- 4. BR-4.* Рестораны (restaurant)
    FOR i IN 1..p_value LOOP
    	v_id := exts.uuid_generate_v4();
        v_work_start := time '08:00' + (random() * 6 * interval '1 hour');
        v_work_end := v_work_start
                    + interval '6 hours'
                    + (random() * 3 * interval '1 hour');
        INSERT INTO chaplygin_food.restaurant (
            restaurant_id, restaurant_name, address_id,
            description, work_start, work_end,
            company_details, rating, status)
        VALUES (
            v_id,
            'Ресторан ' || (SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 
            								1 + floor(random() * 33)::int, 1), '') FROM generate_series(1, 10)),
            v_addresses[i],
            (SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 
            					1 + floor(random() * 33)::int, 1), '') FROM generate_series(1, 20)),
            v_work_start,
            v_work_end,
            'Реквизиты ' || (SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 
            									1 + floor(random() * 33)::int, 1), '') FROM generate_series(1, 10)),
            NULL,
            CASE WHEN random() < 0.7 THEN 'активен'::restaurant_status ELSE 'неактивен'::restaurant_status END
        );
        v_restaurant_ids := array_append(v_restaurant_ids, v_id);
    END LOOP;

    
    -- 5. BR-2.* Клиенты (client)
    FOR i IN 1..p_value LOOP
    	v_id := exts.uuid_generate_v4();
        INSERT INTO chaplygin_food.client (client_id, login, password, phone_number)
        VALUES (
            v_id,
            (
                SELECT string_agg(chr(97 + floor(random() * 26)::int), '')
                FROM generate_series(1, 14)
            ),
            md5(random()::text),
            '+7' || lpad((9000000000 + floor(random() * 1000000000))::bigint::text, 10, '0')
        );
        v_client_ids := array_append(v_client_ids, v_id);
    END LOOP;

    -- 6. BR-2.4–2.5, BR-3.4 Клиент-адрес (client_address)
    v_n_addr_client := v_count - p_value;   
    v_n_clients     := array_length(v_client_ids, 1);
    
    FOR i IN 1..v_n_clients LOOP
        v_n_addr := 2 + floor(random() * 2)::int;   -- 2 или 3 адреса

        FOR j IN 1..v_n_addr LOOP
            v_addr := v_addresses[p_value + 1 + floor(random() * v_n_addr_client)::int];

            INSERT INTO chaplygin_food.client_address (client_id, address_id)
            VALUES (v_client_ids[i], v_addr)
            ON CONFLICT (client_id, address_id) DO NOTHING;
        END LOOP;
    END LOOP;

    -- 7. BR-5.1–5.6 Блюда (product)
    v_n_rest := array_length(v_restaurant_ids, 1);
    v_n_cat  := array_length(v_category_ids, 1);

    -- 7.1 Блюда каждому ресторану
    INSERT INTO chaplygin_food.product (
        product_id, product_name, product_category_id,
        price, restaurant_id, photo_url, rating, status, description)
    SELECT
        exts.uuid_generate_v4(),
        'Блюдо ' || (SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 1 + floor(random() * 33)::int, 1), '') FROM generate_series(1, 8)),
        v_category_ids[1 + floor(random() * array_length(v_category_ids, 1))::int],
        round((random() * 5000)::numeric, 2),
        v_restaurant_ids[r.i],
        CASE WHEN random() < 0.5 THEN 'https://foodexpress.ru' || md5(random()::text) || '.jpg' ELSE NULL END,
        NULL,
        CASE WHEN random() < 0.8 THEN 'доступно'::chaplygin_food.product_status
             WHEN random() < 0.5 THEN 'нет_в_наличии'::chaplygin_food.product_status
             ELSE 'архив'::chaplygin_food.product_status
        END,
        (SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 1 + floor(random() * 33)::int, 1), '') FROM generate_series(1, 20))
    FROM (
        SELECT rest_idx AS i
        FROM generate_series(1, p_value) AS rest_idx,
             generate_series(1, 3)
    ) AS r;

    -- 7.2 остальные 2 * p_value — случайно
    INSERT INTO chaplygin_food.product (
        product_id, product_name, product_category_id,
        price, restaurant_id, photo_url, rating, status, description)
    SELECT
        exts.uuid_generate_v4(),
        'Блюдо ' || (SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 1 + floor(random() * 33)::int, 1), '') FROM generate_series(1, 8)),
        v_category_ids[1 + floor(random() * array_length(v_category_ids, 1))::int],
        round((random() * 5000)::numeric, 2),
        v_restaurant_ids[1 + floor(random() * p_value)::int],
        CASE WHEN random() < 0.5 THEN 'https://foodexpress.ru' || md5(random()::text) || '.jpg' ELSE NULL END,
        NULL,
        CASE WHEN random() < 0.8 THEN 'доступно'::chaplygin_food.product_status
             WHEN random() < 0.5 THEN 'нет_в_наличии'::chaplygin_food.product_status
             ELSE 'архив'::chaplygin_food.product_status
        END,
        (SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 1 + floor(random() * 33)::int, 1), '') FROM generate_series(1, 20))
    FROM generate_series(1, 2 * p_value) AS g(i);

    -- 8. BR-7.* Заказы
    WITH gen AS (
        SELECT
            ca.client_id,
            ca.address_id,
			v_restaurant_ids[1 + floor(random() * p_value)::int] AS restaurant_id,
            v_courier_ids[1 + floor(random() * array_length(v_courier_ids, 1))::int] AS courier_id,
            localtimestamp - (random() * 180) * interval '1 day' AS order_timestamp,
            round((1000 + random() * 4000)::numeric, 2) AS order_amount,
            CASE
                WHEN random() < 0.6  THEN 'доставлен'::chaplygin_food.order_status
                WHEN random() < 0.25 THEN 'отменён'::chaplygin_food.order_status
                WHEN random() < 0.33 THEN 'создан'::chaplygin_food.order_status
                WHEN random() < 0.5  THEN 'готовится'::chaplygin_food.order_status
                ELSE 'в_доставке'::chaplygin_food.order_status
            END AS status,
            CASE
                WHEN random() < 0.3 THEN NULL
                ELSE (
                    SELECT string_agg(substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя', 1 + floor(random() * 33)::int, 1), '')
                    FROM generate_series(1, 20)
                )
            END AS description
        FROM (
            SELECT client_id, address_id
            FROM chaplygin_food.client_address
            CROSS JOIN generate_series(1, 5)
            LIMIT 5 * p_value
        ) ca
    ),
    ins AS (
	    INSERT INTO chaplygin_food."order" (
	        order_id, client_id, address_id, restaurant_id, courier_id,
	        order_timestamp, delivery_timestamp,
	        order_amount, commission, total_amount,
	        status, pay_status, description
	    )
	    SELECT
	        exts.uuid_generate_v4(),
	        client_id,
	        address_id,
	        restaurant_id,
	        courier_id,
	        order_timestamp,
	        CASE
	            WHEN status = 'доставлен'
	            THEN order_timestamp + (1 + random() * 2) * interval '1 hour'
	            ELSE NULL
	        END,
	        order_amount,
	        round(order_amount * 0.10, 2),
	        order_amount + round(order_amount * 0.10, 2),
	        status,
	        'ожидает',
	        description
	    FROM gen
	    RETURNING order_id
 	)
    SELECT array_agg(order_id) INTO v_order_ids FROM ins;

    -- 9. BR-7.14–7.16 Структура заказа (order_structure)
    INSERT INTO chaplygin_food.order_structure (order_id, product_id, restaurant_id, quantity)
    SELECT
        o.order_id,
        p.product_id,
        o.restaurant_id,
        floor(1 + random() * 3)::int
    FROM chaplygin_food."order" o
    CROSS JOIN LATERAL (
        SELECT product_id
        FROM chaplygin_food.product
        WHERE restaurant_id = o.restaurant_id
        LIMIT 1 + floor(random() * 5)::int
    ) p
    WHERE o.order_id = ANY(v_order_ids);

    -- 10. BR-8.* Оплаты (payment)
    WITH o AS (
        SELECT
            o.order_id,
            o.total_amount,
            o.order_timestamp,
            1 + floor(random() * 2)::int AS n_attempts
        FROM chaplygin_food."order" o
        WHERE NOT EXISTS (
            SELECT 1 FROM chaplygin_food.payment p
            WHERE p.order_id = o.order_id
              AND p.status = 'успех'
        )
    ),
    gen AS (
        SELECT order_id, total_amount, order_timestamp, n_attempts, 1 AS attempt_no
        FROM o
        UNION ALL
        SELECT order_id, total_amount, order_timestamp, n_attempts, 2
        FROM o
        WHERE n_attempts = 2
    )
    INSERT INTO chaplygin_food.payment (
        payment_id, order_id, payment_type, amount,
        transaction_id, transaction_timestamp, status
    )
    SELECT
        exts.uuid_generate_v4(),
        order_id,
        CASE
            WHEN random() < 0.7 THEN 'карта'::payment_type
            WHEN random() < 0.67 THEN 'наличные'::payment_type
            ELSE 'безнал'::payment_type
        END,
        total_amount,
        md5(random()::text),
        order_timestamp
            + (attempt_no - 1) * interval '30 minutes'
            + random() * interval '30 minutes',
        CASE
            WHEN attempt_no = 1 AND n_attempts = 1 THEN 'успех'::payment_status
            WHEN attempt_no = 1 AND n_attempts = 2 THEN
                CASE WHEN random() < 0.5 THEN 'ошибка'::payment_status
                     ELSE 'в_обработке'::payment_status END
            ELSE 'успех'::payment_status
        END
    FROM gen;

    UPDATE chaplygin_food."order" o
    SET pay_status = 'оплачен'
    WHERE EXISTS (
        SELECT 1 FROM chaplygin_food.payment p
        WHERE p.order_id = o.order_id
          AND p.status = 'успех');

    -- 11. BR-9.1–9.5 Отзывы на заказ (review)
    v_review_types := enum_range(NULL::chaplygin_food.review_entity_type);

    FOR v_i, v_order_id, v_client_id, v_restaurant_id, v_order_timestamp, v_product_id IN
        SELECT
            row_number() OVER (ORDER BY o.order_id)::int,
            o.order_id,
            o.client_id,
            o.restaurant_id,
            o.order_timestamp,
            (SELECT os.product_id
             FROM chaplygin_food.order_structure os
             WHERE os.order_id = o.order_id
             ORDER BY os.product_id
             LIMIT 1)
        FROM chaplygin_food."order" o
        WHERE NOT EXISTS (
            SELECT 1 FROM chaplygin_food.review r
            WHERE r.order_id = o.order_id
        )
    LOOP
        INSERT INTO chaplygin_food.review (
            review_id, client_id, review_timestamp, entity_id, entity_type,
            order_id, description, photo_url, rating
        )
        VALUES (
            exts.uuid_generate_v4(),
            v_client_id,
            v_order_timestamp + interval '1 hour',
            CASE v_review_types[((v_i - 1) % 3) + 1]
                WHEN 'блюдо' THEN v_product_id
                WHEN 'ресторан' THEN v_restaurant_id
                ELSE v_order_id
            END,
            v_review_types[((v_i - 1) % 3) + 1],
            v_order_id,
            'Тестовый отзыв ' || v_i,
            CASE WHEN v_i % 4 = 0 THEN NULL
                 ELSE 'https://foodexpress.ru' || md5(random()::text) || '.jpg'
            END,
            (v_i % 5) + 1
        );
    END LOOP;

    -- 12. BR-10.* Зарплата курьеров (courier_pay) + BR-10.2 courier.coefficient
    FOR i IN 1..p_value LOOP
        v_coefficient := 0.1;
        FOR j IN REVERSE 5..0 LOOP
            v_month := date_trunc('month', localtimestamp) - j * interval '1 month';

            SELECT count(*)::int, coalesce(sum(commission), 0)
            INTO v_deliveries, v_commission
            FROM chaplygin_food."order"
            WHERE courier_id = v_courier_ids[i]
              AND status = 'доставлен'
              AND date_trunc('month', order_timestamp) = v_month;

            INSERT INTO chaplygin_food.courier_pay (year, month, courier_id, amount, coefficient_used)
            VALUES (
                extract(year FROM v_month)::int,
                extract(month FROM v_month)::int,
                v_courier_ids[i],
                round(v_commission * v_coefficient, 2),
                v_coefficient
            )
            ON CONFLICT (year, month, courier_id) DO UPDATE
            SET amount = EXCLUDED.amount,
                coefficient_used = EXCLUDED.coefficient_used;

            v_new_coefficient := CASE
                WHEN v_deliveries <= 150 THEN 0.1
                WHEN v_deliveries <= 250 THEN 0.2
                WHEN v_deliveries <= 500 THEN 0.3
                ELSE 0.5
            END;
            v_coefficient := v_new_coefficient;
        END LOOP;

        UPDATE chaplygin_food.courier
        SET coefficient = v_coefficient
        WHERE courier_id = v_courier_ids[i]
          AND status <> 'уволен';
    END LOOP;

    -- 13. BR-9.6 Пересчёт рейтинга по отзывам
    UPDATE chaplygin_food.product p
    SET rating = sub.avg_rating
    FROM (
        SELECT r.entity_id AS product_id, round(avg(r.rating), 2) AS avg_rating
        FROM chaplygin_food.review r
        WHERE r.entity_type = 'блюдо'::chaplygin_food.review_entity_type
        GROUP BY r.entity_id
    ) sub
    WHERE p.product_id = sub.product_id;

    UPDATE chaplygin_food.restaurant r
    SET rating = sub.avg_rating
    FROM (
        SELECT rv.entity_id AS restaurant_id, round(avg(rv.rating), 2) AS avg_rating
        FROM chaplygin_food.review rv
        WHERE rv.entity_type = 'ресторан'::chaplygin_food.review_entity_type
        GROUP BY rv.entity_id
    ) sub
    WHERE r.restaurant_id = sub.restaurant_id;
END;
$$;