-- FOOD-102 Генератор тестовых данных

SET search_path TO chaplygin_food, exts, public

CREATE OR REPLACE PROCEDURE insert_test_data(p_value INT)
LANGUAGE plpgsql AS $$
DECLARE
	-- Массивы ID для связности
    v_category_ids     UUID[];   -- все product_category_id
    v_restaurant_ids   UUID[];   -- все restaurant_id
    v_client_ids       UUID[];   -- все client_id
    v_courier_ids      UUID[];   -- все courier_id
    v_addr_restaurant  UUID[];   -- value адресов под рестораны
    v_addr_client      UUID[];   -- value * 4 адресов под клиентов
    -- Счётчики
    i INT;
    j INT;
BEGIN
    -- 0 этап. Очистка значений
    BEGIN
        TRUNCATE TABLE
            review_product, review_restaurant, review_order,
            review, payment, order_structure, pidido,
            courier_pay, product, client_address, restaurant,
            address, courier, product_category, client
        RESTART IDENTITY CASCADE;
    END;

    -- 1. BR-5.7 Категория блюда (product_category)
    BEGIN
        DECLARE
            v_categories TEXT[] := ARRAY[
                'Пицца', 'Супы', 'Салаты', 'Десерты', 'Напитки',
                'Роллы', 'Бургеры', 'Паста', 'Гриль', 'Завтраки',
                'Вторые блюда', 'Гарниры', 'Морепродукты', 'Стейки', 'Шашлык',
                'Пельмени', 'Блины', 'Каши', 'Омлеты', 'Сэндвичи',
                'Хот-доги', 'Шаурма', 'Лапша', 'Рис', 'Картофель',
                'Овощи', 'Фрукты', 'Ягоды', 'Мороженое', 'Выпечка',
                'Торты', 'Пирожные', 'Печенье', 'Конфеты', 'Шоколад',
                'Кофе', 'Чай', 'Соки', 'Смузи', 'Лимонады',
                'Пиво', 'Вино', 'Коктейли', 'Соусы', 'Специи',
                'Хлеб', 'Сыр', 'Колбасы', 'Мясо', 'Рыба'
            ];
        BEGIN
            FOR i IN 1..p_value LOOP
                INSERT INTO product_category (product_category_id, product_category_name)
                VALUES (
                    exts.uuid_generate_v4(),
                    CASE
                        WHEN i <= array_length(v_categories, 1) THEN v_categories[i]
                        ELSE 'Категория ' || (
                            SELECT string_agg(
                                substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
                                          1 + floor(random() * 33)::int, 1), '')
                            FROM generate_series(1, 10))
                    END);
            END LOOP;
        END;
        SELECT array_agg(product_category_id) INTO v_category_ids FROM product_category;
    END;

    -- 2. BR-6.1–6.5 Курьеры (courier)
    BEGIN
        DECLARE
            v_surnames TEXT[] := ARRAY[
                'Иванов', 'Петров', 'Сидоров', 'Смирнов', 'Кузнецов',
                'Попов', 'Васильев', 'Соколов', 'Михайлов', 'Новиков',
                'Фёдоров', 'Морозов', 'Волков', 'Алексеев', 'Лебедев',
                'Семёнов', 'Егоров', 'Павлов', 'Козлов', 'Степанов',
                'Николаев', 'Орлов', 'Андреев', 'Макаров', 'Никитин',
                'Захаров', 'Зайцев', 'Соловьёв', 'Борисов', 'Яковлев',
                'Григорьев', 'Романов', 'Воробьёв', 'Сергеев', 'Кузьмин',
                'Фролов', 'Александров', 'Дмитриев', 'Королёв', 'Гусев',
                'Киселёв', 'Ильин', 'Максимов', 'Поляков', 'Сорокин',
                'Виноградов', 'Ковалёв', 'Белов', 'Медведев', 'Антонов',
                'Тарасов', 'Жуков', 'Баранов', 'Филиппов', 'Комаров',
                'Давыдов', 'Беляев', 'Герасимов', 'Богданов', 'Осипов',
                'Матвеев', 'Титов', 'Марков', 'Миронов', 'Крылов',
                'Куликов', 'Карпов', 'Власов', 'Мельников', 'Денисов',
                'Гаврилов', 'Тихонов', 'Казаков', 'Афанасьев', 'Данилов',
                'Савельев', 'Тимофеев', 'Фомин', 'Чернов', 'Абрамов',
                'Мартынов', 'Ефимов', 'Федотов', 'Щербаков', 'Назаров',
                'Калинин', 'Исаев', 'Чернышёв', 'Быков', 'Пономарёв',
                'Голубев', 'Виноградов', 'Богданов', 'Воробьёв', 'Фёдоров',
                'Михайлов', 'Беляев', 'Тарасов', 'Белов', 'Комаров'
            ];
            v_names TEXT[] := ARRAY[
                'Иван', 'Пётр', 'Сергей', 'Алексей', 'Дмитрий',
                'Андрей', 'Михаил', 'Николай', 'Владимир', 'Александр',
                'Максим', 'Евгений', 'Олег', 'Виктор', 'Роман',
                'Игорь', 'Павел', 'Денис', 'Артём', 'Антон',
                'Константин', 'Василий', 'Георгий', 'Борис', 'Тимур',
                'Егор', 'Кирилл', 'Матвей', 'Фёдор', 'Ярослав',
                'Глеб', 'Лев', 'Семён', 'Степан', 'Вячеслав',
                'Валентин', 'Юрий', 'Вадим', 'Ростислав', 'Эдуард',
                'Арсений', 'Богдан', 'Всеволод', 'Герман', 'Даниил',
                'Елисей', 'Захар', 'Илья', 'Клим', 'Леонид',
                'Макар', 'Назар', 'Остап', 'Прохор', 'Родион',
                'Савва', 'Трофим', 'Устин', 'Филипп', 'Эрик',
                'Юлиан', 'Яков', 'Анатолий', 'Аркадий', 'Болеслав',
                'Вениамин', 'Гавриил', 'Добрыня', 'Ефим', 'Зиновий',
                'Игнат', 'Казимир', 'Лаврентий', 'Мирон', 'Нестор',
                'Онисим', 'Пантелей', 'Радислав', 'Святослав', 'Тарас',
                'Ульян', 'Фрол', 'Харитон', 'Эмиль', 'Юстин',
                'Аверьян', 'Бронислав', 'Влас', 'Гордей', 'Демид',
                'Евдоким', 'Зосим', 'Измаил', 'Кузьма', 'Лука',
                'Мирослав', 'Никифор', 'Оскар', 'Платон', 'Ратмир'
            ];
            v_patronymics TEXT[] := ARRAY[
                'Иванович', 'Петрович', 'Сергеевич', 'Алексеевич', 'Дмитриевич',
                'Андреевич', 'Михайлович', 'Николаевич', 'Владимирович', 'Александрович',
                'Максимович', 'Евгеньевич', 'Олегович', 'Викторович', 'Романович',
                'Игоревич', 'Павлович', 'Денисович', 'Артёмович', 'Антонович',
                'Константинович', 'Васильевич', 'Георгиевич', 'Борисович', 'Тимурович',
                'Егорович', 'Кириллович', 'Матвеевич', 'Фёдорович', 'Ярославович',
                'Глебович', 'Львович', 'Семёнович', 'Степанович', 'Вячеславович',
                'Валентинович', 'Юрьевич', 'Вадимович', 'Ростиславович', 'Эдуардович',
                'Арсеньевич', 'Богданович', 'Всеволодович', 'Германович', 'Данилович',
                'Елисеевич', 'Захарович', 'Ильич', 'Климович', 'Леонидович',
                'Макарович', 'Назарович', 'Остапович', 'Прохорович', 'Родионович',
                'Саввич', 'Трофимович', 'Устинович', 'Филиппович', 'Эрикович',
                'Юлианович', 'Яковлевич', 'Анатольевич', 'Аркадьевич', 'Болеславович',
                'Вениаминович', 'Гавриилович', 'Добрыневич', 'Ефимович', 'Зиновьевич',
                'Игнатович', 'Казимирович', 'Лаврентьевич', 'Миронович', 'Несторович',
                'Онисимович', 'Пантелеевич', 'Радиславович', 'Святославович', 'Тарасович',
                'Ульянович', 'Фролович', 'Харитонович', 'Эмильевич', 'Юстинович',
                'Аверьянович', 'Брониславович', 'Власович', 'Гордеевич', 'Демидович',
                'Евдокимович', 'Зосимович', 'Измаилович', 'Кузьмич', 'Лукич',
                'Мирославович', 'Никифорович', 'Оскарович', 'Платонович', 'Ратмирович'
            ];
		BEGIN
		        INSERT INTO courier (
		            courier_id, fio, phone_number, status,
		            hire_date, dismissal_date, coefficient
		        )
		        SELECT
		            exts.uuid_generate_v4(),
		            v_surnames[1 + floor(random() * array_length(v_surnames, 1))::int]
		                || ' ' ||
		            v_names[1 + floor(random() * array_length(v_names, 1))::int]
		                || ' ' ||
		            v_patronymics[1 + floor(random() * array_length(v_patronymics, 1))::int],
		            '+7' || lpad(
		                ((s.rn * 11) % 4000000000 + 1000000000)::text,
		                10, '0'),
		            s.generated_status,
		            s.h_date,
		            CASE
		                WHEN s.generated_status = 'уволен'
		                THEN s.h_date + (random() * (current_date - s.h_date))::int
		                ELSE NULL
		            END,
		            0.1
				FROM (
			            SELECT
			                row_number() OVER () AS rn,
			                (enum_range(NULL::courier_status))[1 + floor(random() * 4)::int] AS generated_status,
			                current_date - (random() * 180)::int AS h_date
			            FROM generate_series(1, p_value)) AS s;
    	END;
   		SELECT array_agg(courier_id) INTO v_courier_ids FROM courier;
	END;

    -- 2.1 BR-6.6: минимум один активный курьер
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM courier WHERE status <> 'уволен' LIMIT 1)
        THEN
            UPDATE courier
            SET status = 'свободен', dismissal_date = NULL
            WHERE courier_id = (SELECT courier_id FROM courier LIMIT 1);
        END IF;
    END;

    -- 3. BR-3.1–3.2 Адреса (address)
    BEGIN
        DECLARE
            v_streets TEXT[] := ARRAY[
                'Ленина', 'Пушкина', 'Гагарина', 'Мира', 'Советская',
                'Центральная', 'Молодёжная', 'Школьная', 'Садовая', 'Лесная',
                'Набережная', 'Заречная', 'Полевая', 'Степная', 'Луговая',
                'Горького', 'Кирова', 'Чехова', 'Толстого', 'Гоголя',
                'Лермонтова', 'Некрасова', 'Тургенева', 'Достоевского', 'Крылова',
                'Жукова', 'Суворова', 'Кутузова', 'Нахимова', 'Ушакова',
                'Королёва', 'Титова', 'Терешковой', 'Леонова', 'Комарова',
                'Попова', 'Победы', 'Славы', 'Труда', 'Строителей',
                'Металлургов', 'Шахтёров', 'Нефтяников', 'Энергетиков', 'Железнодорожная',
                'Вокзальная', 'Привокзальная', 'Аэропортовская', 'Портовая', 'Солнечная',
                'Лунная', 'Звёздная', 'Космическая', 'Планетная', 'Радужная',
                'Весенняя', 'Летняя', 'Осенняя', 'Зимняя', 'Северная',
                'Южная', 'Западная', 'Восточная', 'Новая', 'Старая',
                'Большая', 'Малая', 'Верхняя', 'Нижняя', 'Первая',
                'Вторая', 'Третья', 'Четвёртая', 'Пятая', 'Дружбы',
                'Согласия', 'Единства', 'Свободы', 'Независимости', 'Речная',
                'Озёрная', 'Морская', 'Горная', 'Сосновая', 'Берёзовая',
                'Дубовая', 'Кленовая', 'Тополиная', 'Вишнёвая', 'Яблочная',
                'Грушевая', 'Сливовая', 'Виноградная', 'Сиреневая', 'Ромашковая',
                'Васильковая', 'Ландышевая', 'Фиалковая', 'Мятная', 'Лавандовая'
            ];
            v_house_numbers TEXT[] := ARRAY[
                '12А', '1 корп. 1', '2/2', '15', '7Б', '3 стр. 1',
                '5', '10', '20А', '30', '40Б', '50', '60/2', '70', '80',
                '25В', '35', '45', '55', '65', '75', '85', '95'
            ];
        BEGIN
            INSERT INTO address (address_id, street, house_number, apartment_office)
            SELECT
                exts.uuid_generate_v4(),
                v_streets[1 + floor(random() * array_length(v_streets, 1))::int],
                v_house_numbers[1 + floor(random() * array_length(v_house_numbers, 1))::int],
                CASE
                    WHEN random() < 0.8 THEN (1 + floor(random() * 140))::text
                    ELSE NULL
                END
            FROM generate_series(1, p_value * 5);

            WITH ordered AS (
                SELECT address_id, row_number() OVER (ORDER BY address_id) AS rn
                FROM address)
            SELECT
                array_agg(address_id) FILTER (WHERE rn <= p_value),
                array_agg(address_id) FILTER (WHERE rn > p_value)
            INTO v_addr_restaurant, v_addr_client
            FROM ordered;
        END;
    END;

    -- 4. BR-4.* Рестораны (restaurant)
    BEGIN
        DECLARE
            v_work_start TIME;
            v_work_end   TIME;
        BEGIN
            FOR i IN 1..p_value LOOP
                v_work_start := time '08:00' + (random() * 6 * interval '1 hour');
                v_work_end := v_work_start
                            + interval '6 hours'
                            + (random() * 3 * interval '1 hour');

                INSERT INTO restaurant (
                    restaurant_id, restaurant_name, address_id,
                    description, work_start, work_end,
                    company_details, rating, status)
                VALUES (
                    exts.uuid_generate_v4(),
                    (
                        SELECT string_agg(
                            substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
                                      1 + floor(random() * 33)::int, 1), '')
                        FROM generate_series(1, 10 + i * 0)),
                    v_addr_restaurant[i],
                    (
                        SELECT string_agg(
                            substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
                                      1 + floor(random() * 33)::int, 1), '')
                        FROM generate_series(1, 20 + i * 0)),
                    v_work_start,
                    v_work_end,
                    'ООО «' || (
                        SELECT string_agg(
                            substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
                                      1 + floor(random() * 33)::int, 1), '')
                        FROM generate_series(1, 10 + i * 0)) || '», ИНН ' ||
                        lpad((floor(random() * 1000000000000))::bigint::text, 12, '0'),
                    NULL,
                    CASE
                        WHEN random() < 0.8 THEN 'активен'::restaurant_status
                        ELSE 'неактивен'::restaurant_status
                    END);
            END LOOP;
            SELECT array_agg(restaurant_id) INTO v_restaurant_ids FROM restaurant;
        END;
    END;

    -- 5. BR-2.* Клиенты (client)
    BEGIN
        FOR i IN 1..p_value LOOP
            INSERT INTO client (client_id, login, password, phone_number)
            VALUES (
                exts.uuid_generate_v4(),
                (
                    SELECT string_agg(chr(97 + floor(random() * 26)::int), '')
                    FROM generate_series(1, 14)
                ),
                md5(random()::text),
                '+7' || lpad(
                    ((i * 7) % 5000000000 + 3000000000)::text,
                    10, '0'
                )
            );
        END LOOP;

        SELECT array_agg(client_id) INTO v_client_ids FROM client;
    END;

    -- 6. BR-2.4–2.5, BR-3.4 Клиент-адрес (client_address)
    BEGIN
        DECLARE
            v_n_addr_client INT := array_length(v_addr_client, 1);
            v_n_clients     INT := array_length(v_client_ids, 1);
            v_n_addr        INT;
            v_addr          UUID;
        BEGIN
            FOR i IN 1..v_n_clients LOOP
                v_n_addr := 2 + floor(random() * 2)::int;

                FOR j IN 1..v_n_addr LOOP
                    v_addr := v_addr_client[
                        1 + floor(random() * v_n_addr_client)::int
                    ];

                    INSERT INTO client_address (client_id, address_id)
                    VALUES (v_client_ids[i], v_addr)
                    ON CONFLICT (client_id, address_id) DO NOTHING;
                END LOOP;
            END LOOP;
        END;
    END;

    -- 7. BR-5.1–5.6 Блюда (product)
    BEGIN
        DECLARE
            v_n_rest INT := array_length(v_restaurant_ids, 1);
            v_n_cat  INT := array_length(v_category_ids, 1);
        BEGIN
            -- 7.1 Обязательные 3 блюда каждому ресторану
            INSERT INTO product (
                product_id, product_name, product_category_id,
                price, restaurant_id, photo_url, rating, status, description
            )
            SELECT
                exts.uuid_generate_v4(),
                (
                    SELECT string_agg(
                        substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
                                  1 + floor(random() * 33)::int, 1), '')
                    FROM generate_series(1, 8 + r.i * 0)),
                v_category_ids[1 + floor(random() * v_n_cat)::int],
                round((random() * 5000)::numeric, 2),
                v_restaurant_ids[r.i],
                CASE
                    WHEN random() < 0.5
                    THEN 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
                    ELSE NULL
                END,
                NULL,
                CASE
                    WHEN random() < 0.8 THEN 'доступно'::product_status
                    WHEN random() < 0.5 THEN 'нет_в_наличии'::product_status
                    ELSE 'архив'::product_status
                END,
                (
                    SELECT string_agg(
                        substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
                                  1 + floor(random() * 33)::int, 1), '')
                    FROM generate_series(1, 20 + r.i * 0)
                )
            FROM (
                SELECT rest_idx AS i
                FROM generate_series(1, v_n_rest) AS rest_idx,
                     generate_series(1, 3)
            ) AS r;

            -- 7.2 Остальные 2 * value блюд — случайно по ресторанам
            INSERT INTO product (
                product_id, product_name, product_category_id,
                price, restaurant_id, photo_url, rating, status, description)
            SELECT
                exts.uuid_generate_v4(),
                (
                    SELECT string_agg(
                        substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
                                  1 + floor(random() * 33)::int, 1), '')
                    FROM generate_series(1, 8 + g.i * 0)),
                v_category_ids[1 + floor(random() * v_n_cat)::int],
                round((random() * 5000)::numeric, 2),
                v_restaurant_ids[1 + floor(random() * v_n_rest)::int],
                CASE
                    WHEN random() < 0.5
                    THEN 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
                    ELSE NULL
                END,
                NULL,
                CASE
                    WHEN random() < 0.8 THEN 'доступно'::product_status
                    WHEN random() < 0.5 THEN 'нет_в_наличии'::product_status
                    ELSE 'архив'::product_status
                END,
                (
                    SELECT string_agg(
                        substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
                                  1 + floor(random() * 33)::int, 1), '')
                    FROM generate_series(1, 20 + g.i * 0)
                )
            FROM generate_series(1, 2 * p_value) AS g(i);
        END;
    END;

    -- 8. BR-7.* Заказы (pidido)
    BEGIN
        DECLARE
            v_n_rest INT := array_length(v_restaurant_ids, 1);
            v_n_cour INT := array_length(v_courier_ids, 1);
        BEGIN
            WITH gen AS (
                SELECT
                    ca.client_id,
                    ca.address_id,
                    v_restaurant_ids[1 + floor(random() * v_n_rest)::int] AS restaurant_id,
                    v_courier_ids[1 + floor(random() * v_n_cour)::int] AS courier_id,
                    localtimestamp - (random() * 180) * interval '1 day' AS order_timestamp,
                    round((909.09 + random() * 4000)::numeric, 2) AS order_amount,
                    CASE
                        WHEN random() < 0.6  THEN 'доставлен'::order_status
                        WHEN random() < 0.25 THEN 'отменён'::order_status
                        WHEN random() < 0.33 THEN 'создан'::order_status
                        WHEN random() < 0.5  THEN 'готовится'::order_status
                        ELSE 'в_доставке'::order_status
                    END AS status,
                    CASE
                        WHEN random() < 0.3 THEN NULL
                        ELSE (
                            SELECT string_agg(
                                substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
                                          1 + floor(random() * 33)::int, 1), '')
                            FROM generate_series(1, 20 + length(ca.client_id::text) * 0)
                        )
                    END AS description
                FROM (
                    SELECT client_id, address_id
                    FROM client_address
                    CROSS JOIN generate_series(1, 5)
                    LIMIT 5 * p_value
                ) ca
            )
            INSERT INTO pidido (
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
            FROM gen;
        END;
    END;

    -- 9. BR-7.14–7.16 Структура заказа (order_structure)
    BEGIN
        INSERT INTO order_structure (order_id, product_id, restaurant_id, quantity)
        SELECT
            o.order_id,
            p.product_id,
            o.restaurant_id,
            round((0.5 + random() * 2)::numeric, 3)
        FROM pidido o
        CROSS JOIN LATERAL (
            SELECT product_id
            FROM product
            WHERE restaurant_id = o.restaurant_id
            LIMIT 1 + floor(random() * 5)::int
        ) p;
    END;

    -- 10. BR-8.* Оплаты (payment)
    BEGIN
        WITH o AS (
            SELECT
                order_id,
                total_amount,
                order_timestamp,
                1 + floor(random() * 2)::int AS n_attempts
            FROM pidido
        ),
        gen AS (
            SELECT order_id, total_amount, order_timestamp, n_attempts, 1 AS attempt_no
            FROM o
            UNION ALL
            SELECT order_id, total_amount, order_timestamp, n_attempts, 2
            FROM o
            WHERE n_attempts = 2
        )
        INSERT INTO payment (
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

        UPDATE pidido SET pay_status = 'оплачен';
    END;

    -- 11.1 BR-9.1–9.5 Отзывы на заказ (review_order) — 50% заказов
    BEGIN
        WITH gen AS (
			        SELECT
			            exts.uuid_generate_v4() AS review_id,
			            o.client_id,
			            o.order_id,
			            o.order_timestamp
			        FROM pidido o
			        WHERE random() < 0.5),
    							
		    ins AS (
		        	INSERT INTO review (review_id, client_id, order_id, 
		        						review_timestamp, description, photo_url, rating)
            SELECT
	            review_id,
	            client_id,
	            order_id,
	            order_timestamp + (1 + random() * 2) * interval '1 day',
	            (
	                SELECT string_agg(
	                    substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
	                              1 + floor(random() * 33)::int, 1), '')
	                FROM generate_series(1, 30 + length(gen.order_id::text) * 0)
	            ),
	            CASE
	                WHEN random() < 0.5
	                THEN 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
	                ELSE NULL
	            END,
	            1 + floor(random() * 5)::int
	        FROM gen)
	    INSERT INTO review_order (review_id, order_id)
	    SELECT review_id, order_id FROM gen;
	END;

    -- 11.2 BR-9.1–9.5 Отзывы на ресторан (review_restaurant) — 30% заказов
	BEGIN
	    WITH gen AS (
	        SELECT
	            exts.uuid_generate_v4() AS review_id,
	            o.client_id,
	            o.order_id,
	            o.order_timestamp,
	            o.restaurant_id
	        FROM pidido o
	        WHERE random() < 0.3
	    ),
	    ins AS (
	        INSERT INTO review (review_id, client_id, order_id, review_timestamp, description, photo_url, rating)
	        SELECT
	            review_id,
	            client_id,
	            order_id,
	            order_timestamp + (1 + random() * 2) * interval '1 day',
	            (
	                SELECT string_agg(
	                    substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
	                              1 + floor(random() * 33)::int, 1), '')
	                FROM generate_series(1, 30 + length(gen.order_id::text) * 0)
	            ),
	            CASE
	                WHEN random() < 0.5
	                THEN 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
	                ELSE NULL
	            END,
	            1 + floor(random() * 5)::int
	        FROM gen
	    )
	    INSERT INTO review_restaurant (review_id, order_id, restaurant_id)
	    SELECT review_id, order_id, restaurant_id FROM gen;
	END;

    -- 11.3 BR-9.1–9.5 Отзывы на блюдо (review_product) — 30% блюд в заказах
	BEGIN
	    WITH gen AS (
	        SELECT
	            exts.uuid_generate_v4() AS review_id,
	            o.order_id,
	            o.client_id,
	            o.order_timestamp,
	            os.product_id
	        FROM pidido o
	        JOIN order_structure os ON os.order_id = o.order_id
	        WHERE random() < 0.3
	    ),
	    ins AS (
	        INSERT INTO review (review_id, client_id, order_id, review_timestamp, description, photo_url, rating)
	        SELECT
	            review_id,
	            client_id,
	            order_id,
	            order_timestamp + (1 + random() * 2) * interval '1 day',
	            (
	                SELECT string_agg(
	                    substring('абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
	                              1 + floor(random() * 33)::int, 1), '')
	                FROM generate_series(1, 30 + length(gen.order_id::text) * 0)
	            ),
	            CASE
	                WHEN random() < 0.5
	                THEN 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
	                ELSE NULL
	            END,
	            1 + floor(random() * 5)::int
	        FROM gen
	    )
	    INSERT INTO review_product (review_id, order_id, product_id)
	    SELECT review_id, order_id, product_id FROM gen;
	END;

    -- 12. BR-10.* Зарплата курьеров (courier_pay) + BR-10.2 courier.coefficient
    BEGIN
        DECLARE
            v_months DATE[] := ARRAY(
                SELECT generate_series(
                    date_trunc('month', current_date) - interval '5 months',
                    date_trunc('month', current_date),
                    interval '1 month'
                )::date
            );
            v_deliveries INT[];
            v_commissions NUMERIC[];
            v_coeff NUMERIC(2,1);
            v_amount NUMERIC(12,2);
            v_courier_id UUID;
            v_n_months INT := 6;
        BEGIN
            FOR i IN 1..array_length(v_courier_ids, 1) LOOP
                v_courier_id := v_courier_ids[i];

                SELECT
                    array_agg(COALESCE(t.cnt, 0)::int ORDER BY s.m_idx),
                    array_agg(COALESCE(t.comm, 0) ORDER BY s.m_idx)
                INTO v_deliveries, v_commissions
                FROM generate_series(1, v_n_months) AS s(m_idx)
                LEFT JOIN LATERAL (
                    SELECT
                        count(*) AS cnt,
                        COALESCE(sum(commission), 0) AS comm
                    FROM pidido
                    WHERE courier_id = v_courier_id
                      AND status = 'доставлен'
                      AND order_timestamp >= v_months[s.m_idx]
                      AND order_timestamp < v_months[s.m_idx] + interval '1 month'
                ) t ON true;

                FOR j IN 1..v_n_months LOOP
                    IF j = 1 THEN
                        v_coeff := 0.1;
                    ELSE
                        v_coeff := CASE
                            WHEN v_deliveries[j - 1] <= 150 THEN 0.1
                            WHEN v_deliveries[j - 1] <= 250 THEN 0.2
                            WHEN v_deliveries[j - 1] <= 500 THEN 0.3
                            ELSE 0.5
                        END;
                    END IF;

                    v_amount := round(v_coeff * v_commissions[j], 2);

                    INSERT INTO courier_pay (year, month, courier_id, amount, coefficient_used)
                    VALUES (
                        extract(year from v_months[j])::int,
                        extract(month from v_months[j])::int,
                        v_courier_id,
                        v_amount,
                        v_coeff
                    )
                    ON CONFLICT (year, month, courier_id) DO UPDATE
                    SET amount = EXCLUDED.amount,
                        coefficient_used = EXCLUDED.coefficient_used;
                END LOOP;

                v_coeff := CASE
                    WHEN v_deliveries[v_n_months] <= 150 THEN 0.1
                    WHEN v_deliveries[v_n_months] <= 250 THEN 0.2
                    WHEN v_deliveries[v_n_months] <= 500 THEN 0.3
                    ELSE 0.5
                END;

                UPDATE courier
                SET coefficient = v_coeff
                WHERE courier_id = v_courier_id
                  AND status <> 'уволен';
            END LOOP;
        END;
    END;

    -- 13. BR-9.6 Пересчёт рейтинга по отзывам
    BEGIN
        UPDATE product p
        SET rating = sub.avg_rating
        FROM (
            SELECT rp.product_id, round(avg(r.rating), 2) AS avg_rating
            FROM review_product rp
            JOIN review r ON r.review_id = rp.review_id
            GROUP BY rp.product_id
        ) sub
        WHERE p.product_id = sub.product_id;

        UPDATE restaurant r
        SET rating = sub.avg_rating
        FROM (
            SELECT rr.restaurant_id, round(avg(rv.rating), 2) AS avg_rating
            FROM review_restaurant rr
            JOIN review rv ON rv.review_id = rr.review_id
            GROUP BY rr.restaurant_id
        ) sub
        WHERE r.restaurant_id = sub.restaurant_id;
    END;
END;
$$;