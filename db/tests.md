# Протокол для самопроверки

## Окружение

| Параметр           | Значение                 |
| ------------------ | ------------------------ |
| PostgreSQL version | `SELECT version();` → 18 |
| Дата проверки      | 08.11.2026               |
| Схема              | `chaplygin_food`         |
| Роль-аудитор       | `inspector`              |
Скрипты схемы применены с заранее созданной `exts` и расширением `uuid-ossp`. Функциональные сценарии запускались как `inspector`; развертывание и `grants.sql` — как администратор БД.

Все проверки — под `inspector`, если не указано иное.

Заполняй «Факт» и «Вердикт» по каждой проверке. «Вердикт»: `OK` / `FAIL: <что именно>`.

---

## A. Подготовка

### A.1. Восстановление бэкапа

Ожидается: без ошибок.
Факт: pg_restore выполнен без ошибок; exts не пересоздается, используется; role "inspector" создана через вызов grants.sql в терминале.
Вердикт: OK

### A.2. Переключение на inspector

```sql
SET ROLE inspector;
SET search_path TO chaplygin_food, exts;
SELECT current_user;
```

Ожидается: `inspector`.
Факт: при выполнении запросов формируется таблица с 1 столбцом current_user и значением inspector.
Вердикт: OK

---

## B. FOOD-101: Структура схемы

### B.1. Схема существует

```sql
SELECT schema_name FROM information_schema.schemata
WHERE schema_name LIKE '%_food';
```

Ожидается: `chaplygin_food`.
Факт: chaplygin_food
Вердикт: OK

### B.2. Схема `exts` с `uuid-ossp`

```sql
SELECT extname, extnamespace::regnamespace AS schema
FROM pg_extension WHERE extname = 'uuid-ossp';
```

Ожидается: `uuid-ossp`, схема `exts`.
Факт: uuid-ossp | exts
Вердикт: OK

### B.3. Все 12 исходных таблиц + N после нормализации

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'chaplygin_food'
ORDER BY table_name;
```

Ожидается: `address`, `client`, `client_address`, `courier`, `courier_pay`, `order`, `order_structure`, `payment`,  `product`, `product_category`, `restaurant`, `review` (12 штук).
Факт: `address`, `client`, `client_address`, `courier`, `courier_pay`, `order`, `order_structure`, `payment`,  `product`, `product_category`, `restaurant`, `review` (12 штук).
Вердикт: OK

### B.4. Все PK — `uuid`

```sql
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'chaplygin_food'
  AND column_name LIKE '%_id'
  AND data_type != 'uuid';
```

Ожидается: пусто.
Факт: Все PK — uuid. (Запрос выдает payment.transaction_id — это не UUID, а внешний ID от платёжного провайдера, VARCHAR(255) + UNIQUE, BR-8.3 — не UUID по определению.)
Вердикт: OK

### B.5. Enum-типы

```sql
SELECT t.typname, array_agg(e.enumlabel ORDER BY e.enumsortorder) AS values
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'chaplygin_food'
GROUP BY t.typname
ORDER BY t.typname;
```

Ожидается: 8 типов со значениями из constraints.md.
Факт: 8 типов со значениями из constraints.md (courier_status, order_pay_status, order_status, payment_status, payment_type, product_status, restaurant_status, review_entity_type).
Вердикт: OK

### B.6. FK-ограничения

```sql
SELECT conname, conrelid::regclass AS tbl, confrelid::regclass AS ref
FROM pg_constraint
WHERE contype = 'f'
  AND connamespace = 'chaplygin_food'::regnamespace
ORDER BY tbl, conname;
```

Ожидается: не менее 15 FK, все из erd.md.
Факт: 17 FK.
Вердикт: OK

### B.7. Пароль — MD5

```sql
SELECT length(password) AS len, password
FROM client LIMIT 5;
```

Ожидается: `len = 32`, hex-строка.
Факт: len = 32, password = hex-строка.
32	1f9d04ee8d473154afb6e3d085356b15
32	861da0188f76241de711ce5d02f7cbe3
32	ef7a329a74c47707d26e4d3ca61445d7
32	7f3ef92f2f5d3ed76525916d14cfa23f
32	327e5f1abfda692c92ffebf02338545d
Вердикт: OK

---

## C. FOOD-102: `insert_test_data(value)`

### C.1. Чистая схема

```sql
CALL erase_test_data();
```

Ожидается: без ошибок.
Факт: без ошибок
Вердикт: OK

### C.2. Первый запуск

```sql
CALL insert_test_data(10);
```

Ожидается: без ошибок.
Факт: без ошибок
Вердикт: OK

### C.3. Распределение строк (BR-11.7)

```sql
SELECT 'client' AS tbl, count(*) FROM client
UNION ALL SELECT 'courier', count(*) FROM courier
UNION ALL SELECT 'product_category', count(*) FROM product_category
UNION ALL SELECT 'restaurant', count(*) FROM restaurant
UNION ALL SELECT 'address', count(*) FROM address
UNION ALL SELECT 'product', count(*) FROM product
UNION ALL SELECT 'order', count(*) FROM "order"
UNION ALL SELECT 'review', count(*) FROM review
UNION ALL SELECT 'payment', count(*) FROM payment
ORDER BY tbl;
```

Ожидается: 10, 10, 10, 10, 50, 50, 50, 50, 50.
Факт: client=10, courier=10, product_category=10, restaurant=10, address=50, product=50, "order"=50, payment=72, review=50.
Отклонение в payment связано с генерацией нескольких попыток оплаты при сохранении успешных оплат со значением 50 (1 или 2 попытки с равной вероятностью (50/50))
Вердикт: OK

### C.4. Адреса ресторанов vs клиентов (BR-11.7)

```sql
SELECT 'restaurant addresses' AS cat, count(*) FROM restaurant WHERE address_id IS NOT NULL
UNION ALL
SELECT 'total addresses', count(*) FROM address;
```

Ожидается: 10 ресторанных адресов, 50 всего → 40 клиентских.
Факт: restaurant addresses - 10, total addresses -50 → 40 клиентских.
Вердикт: OK

### C.5. Нет пустых строк (BR-11.3)

```sql
SELECT count(*) FROM client WHERE login = '' OR password = '' OR phone_number = '';
-- и аналогично для других varchar-полей с NOT NULL
```

Ожидается: 0.
Факт: 0
Вердикт: OK

### C.6. Нет NULL там, где запрещено (BR-11.3)

```sql
SELECT count(*) FROM "order" WHERE client_id IS NULL OR restaurant_id IS NULL
  OR courier_id IS NULL OR address_id IS NULL OR total_amount IS NULL;
-- и аналогично для других NOT NULL полей
```

Ожидается: 0.
Факт: 0
Вердикт: OK

### C.7. Минимум один активный курьер (BR-6.6)

```sql
SELECT count(*) FROM courier WHERE status != 'уволен';
```

Ожидается: `>= 1`.
Факт: 7
Вердикт: OK

### C.8. `courier_pay` консистентен с правилами (BR-10.2)

```sql
SELECT cp.year, cp.month, cp.courier_id, cp.amount, cp.coefficient_used,
       round(coalesce((
           SELECT sum(o.commission)
           FROM "order" o
           WHERE o.courier_id = cp.courier_id
             AND o.status = 'доставлен'
             AND extract(year  from o.order_timestamp) = cp.year
             AND extract(month from o.order_timestamp) = cp.month
       ), 0) * cp.coefficient_used, 2) AS expected_amount
FROM courier_pay cp
LIMIT 20;
```

Ожидается: `amount = expected_amount` в каждой строке.
Факт: `amount = expected_amount` в каждой строке со значением.
Вердикт: OK

### C.9. Повторный вызов не ломает

```sql
DO $$
BEGIN
    FOR i IN 1..10 LOOP
        CALL insert_test_data(10);
    END LOOP;
END $$;
```

Ожидается: без ошибок, данные добавляются.
Факт: без ошибок, 10 последовательных вызовов insert_test_data(10) выполнены без ошибок. 
Вердикт: OK

---

## D. Проверки бизнес-правил на сгенерированных данных

### D.1. Все FK валидны (нет orphans)

```sql
SELECT 'order_structure → order' AS fk, count(*) AS orphans
FROM order_structure os
LEFT JOIN "order" o ON os.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_structure → product', count(*)
FROM order_structure os
LEFT JOIN product p ON os.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'payment → order', count(*)
FROM payment pmt
LEFT JOIN "order" o ON pmt.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'review → order', count(*)
FROM review r
LEFT JOIN "order" o ON r.order_id = o.order_id
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
```

Ожидается: все 0.
Факт: все 0.
order_structure → order	0
order_structure → product	0
payment → order	0
review → order	0
courier_pay → courier	0
client_address → client	0
client_address → address	0
Вердикт: OK

### D.2. Минимальная сумма заказа (BR-1.8)

```sql
SELECT count(*) FROM "order" WHERE total_amount < 1000;
```

Ожидается: 0.
Факт: count = 0
Вердикт: OK

### D.3. Комиссия = 10% (BR-1.4)

```sql
SELECT count(*) FROM "order" WHERE round(order_amount * 0.10, 2) != commission;
```

Ожидается: 0.
Факт: count = 0
Вердикт: OK

### D.4. `total_amount = order_amount + commission`

```sql
SELECT count(*) FROM "order"
WHERE round(order_amount + commission, 2) != total_amount;
```

Ожидается: 0.
Факт: count = 0
Вердикт: OK

### D.5. Дата доставки не раньше создания (BR-7.13)

```sql
SELECT count(*) FROM "order"
WHERE delivery_timestamp IS NOT NULL AND delivery_timestamp < order_timestamp;
```

Ожидается: 0.
Факт: count = 0
Вердикт: OK

### D.6. Адрес доставки принадлежит клиенту (BR-7.4)

```sql
SELECT count(*) FROM "order" o
LEFT JOIN client_address ca
  ON ca.client_id = o.client_id AND ca.address_id = o.address_id
WHERE ca.client_id IS NULL;
```

Ожидается: 0.
Факт: count = 0
Вердикт: OK

### D.7. Все блюда в заказе из одного ресторана (BR-7.3)

```sql
SELECT count(DISTINCT os.order_id)
FROM order_structure os
JOIN "order" o ON os.order_id = o.order_id
JOIN product p ON os.product_id = p.product_id
WHERE p.restaurant_id != o.restaurant_id;
```

Ожидается: 0.
Факт: count = 0
Вердикт: OK

### D.8. Ровно одна успешная оплата на заказ (BR-8.1)

```sql
SELECT order_id, count(*) AS cnt
FROM payment
WHERE status = 'успех'
GROUP BY order_id
HAVING count(*) != 1;
```

Ожидается: пусто.
Факт: столбцы order_id и cnt пустые.
Вердикт: OK

### D.9. Сумма оплаты = `total_amount` заказа (BR-8.4)

```sql
SELECT count(*) FROM payment p
JOIN "order" o ON p.order_id = o.order_id
WHERE p.amount != o.total_amount;
```

Ожидается: 0.
Факт: count = 0
Вердикт: OK

### D.10. Нет дубликатов в `client_address` (BR-2.5)

```sql
SELECT client_id, address_id, count(*)
FROM client_address
GROUP BY client_id, address_id
HAVING count(*) > 1;
```

Ожидается: пусто.
Факт: столбцы client_id, address_id и count пустые.
Вердикт: OK

### D.11. Нет дубликатов в `order_structure` (BR-7.16)

```sql
SELECT order_id, product_id, count(*)
FROM order_structure
GROUP BY order_id, product_id
HAVING count(*) > 1;
```

Ожидается: пусто.
Факт: столбцы order_id, product_id и count пустые.
Вердикт: OK

### D.12. `work_end > work_start` (BR-4.4)

```sql
SELECT count(*) FROM restaurant WHERE work_end <= work_start;
```

Ожидается: 0.
Факт: count = 0
Вердикт: OK

### D.13. `dismissal_date >= hire_date` (BR-6.3)

```sql
SELECT count(*) FROM courier
WHERE dismissal_date IS NOT NULL AND dismissal_date < hire_date;
```

Ожидается: 0.
Факт: count = 0
Вердикт: OK

### D.14. Рейтинг блюд/ресторанов соответствует отзывам (BR-9.6)

```sql
-- product.rating = AVG(review.rating) по отзывам на блюдо
SELECT p.product_id, p.rating,
       (SELECT round(avg(r.rating), 2) FROM review r
        WHERE r.entity_type = 'блюдо' AND r.entity_id = p.product_id) AS expected
FROM product p
WHERE p.rating IS NOT NULL
LIMIT 20;
```

Ожидается: `rating = expected`.
Факт: все значения rating равны expected
Вердикт: OK

---

## E. Функции и процедуры

### E.1. `add_product` — успешный вызов

```sql
SELECT count(*) AS before FROM product;

DO $$
DECLARE
	v_rest_id UUID;
	v_cat_id UUID;
BEGIN
	SELECT restaurant_id INTO v_rest_id FROM chaplygin_food.restaurant LIMIT 1;
	SELECT product_category_id INTO v_cat_id FROM chaplygin_food.product_category LIMIT 1;

	CALL chaplygin_food.add_product(
	p_restaurant_id => v_rest_id,
	p_product_category_id => v_cat_id,
	p_name => 'Тестовое блюдо',
	p_price => 250,
	p_status => 'доступно'::chaplygin_food.product_status,
	p_description => 'Описание'
	);
END;
$$;

SELECT count(*) AS after FROM product;
```
PostgreSQL не принимает подзапросы в аргументах CALL. Вызов обёрнут в DO-блок с переменными для проверки внутри DBeaver — параметры те же, вызов тот же.

Ожидается: `after = before + 1`.
Факт: До - 50. После 50 + 1 = 51
Вердикт: OK

### E.2. `add_product` — падает на несуществующий ресторан

```sql
DO $$
DECLARE
	v_cat_id UUID;
BEGIN
	SELECT restaurant_id INTO v_rest_id FROM chaplygin_food.restaurant LIMIT 1;
	SELECT product_category_id INTO v_cat_id FROM chaplygin_food.product_category LIMIT 1;

	CALL chaplygin_food.add_product(
	p_restaurant_id => '00000000-0000-0000-0000-000000000000'::UUID,
	p_product_category_id => v_cat_id,
	p_name => 'Тестовое блюдо',
	p_price => 250,
	p_status => 'доступно'::chaplygin_food.product_status,
	p_description => 'Описание'
	);
END;
$$;
```

Ожидается: ошибка с внятным сообщением.
Факт: SQL Error [P0001]: ERROR: Ресторан с id 00000000-0000-0000-0000-000000000000 не существует (BR-5.1)
Вердикт: OK

### E.3. `rating_change` — пересчитывает рейтинг

```sql
-- Выбрать заказ, блюдо и клиента
SELECT p.product_id, p.rating FROM product p WHERE p.rating IS NOT NULL LIMIT 1;
-- product_id                           | rating
-- 1ec97f22-3062-43b8-b051-85c3642eab6c | 2

-- Вставить отзыв на это блюдо
INSERT INTO review (review_id, client_id, review_timestamp, entity_id, entity_type, order_id, description, rating)
SELECT
	exts.uuid_generate_v4(),
	o.client_id,
	localtimestamp,
	'1ec97f22-3062-43b8-b051-85c3642eab6c',
	'блюдо',
	o.order_id,
	'Тестовый отзыв',
	5
FROM chaplygin_food."order" o
WHERE o.order_id = (SELECT order_id FROM chaplygin_food."order" LIMIT 1);

-- Проверить рейтинг
SELECT rating FROM product WHERE product_id = '1ec97f22-3062-43b8-b051-85c3642eab6c';
-- Среднее = (2+5) / 2 = 3.5
```

Ожидается: `rating` пересчитан.
Факт: Начальный рейтинг - 2, рейтинг после добавления тестового отзыва - 3.5, пояснение в коде sql выше.
Вердикт: OK

### E.4. `rating_change` — удаление отзыва

```sql
-- Удалить отзыв из E.3
DELETE FROM review
WHERE review_id = 'b6213862-2be4-4ec2-9839-c3af75c38273';

SELECT rating FROM product
WHERE product_id = '1ec97f22-3062-43b8-b051-85c3642eab6c';
```

Ожидается: если других отзывов нет — `rating IS NULL`; иначе — пересчитан.
Факт: Начальный рейтинг - 3.5 (2 отзыва), рейтинг после удаления тестового отзыва - 2.
Вердикт: OK

### E.5. `get_statistic()`

```sql
SELECT * FROM get_statistic();
```

Ожидается:
- Колонки: `restaurant_name`, `best_product_name`, `total_amount`, `avg_amount`, `best_user`.
- По одной строке на ресторан.
- `best_user` = `client.login` (не NULL при наличии заказов).

Факт: 10 строк (по одной строке на ресторан), колонки restaurant_name, best_product_name, total_amount, avg_amount, best_user.
best_user = client.login
Вердикт: OK

### E.6. `courier_salary()`

```sql
-- До
SELECT courier_id, coefficient FROM courier ORDER BY courier_id;

CALL courier_salary();

-- После
SELECT courier_id, coefficient FROM courier ORDER BY courier_id;
SELECT year, month, courier_id, amount, coefficient_used
FROM courier_pay
ORDER BY year DESC, month DESC, courier_id
LIMIT 20;
```

Ожидается:
- `courier.coefficient` пересчитан для работающих (по BR-10.2).
- У уволенных — не изменился.
- `courier_pay` содержит запись за текущий месяц.

Факт: Для теста сгенерировано по 501 заказу в текущем месяце к существующим для 2 курьеров из общего списка - 1 работающему, 1 уволенному.
При вызове courier_salary(); у работающего ожидаемо courier.coefficient пересчитан на 0.5, у уволенного ожидаемо courier.coefficient сохранен на 0.1
Вердикт: OK

### E.7. `courier_salary()` — повторный вызов

```sql
CALL courier_salary();
SELECT count(*) FROM courier_pay
WHERE year = extract(year from current_date)
  AND month = extract(month from current_date);
```

Ожидается: количество не изменилось (idempotency / обновление).
Факт: количество не изменилось - 10
Вердикт: OK

---

## F. Представление `how_much_money`

### F.1. Колонки

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'chaplygin_food'
  AND table_name = 'how_much_money'
ORDER BY ordinal_position;
```

Ожидается: `year_month` (text), `sum_no_commission`, `sum_with_commission`, `commission`, `prev_commission`, `commission_diff`, `courier_pay`, `net_profit` (numeric).
Факт: 
year_month	text
sum_no_commission	numeric
sum_with_commission	numeric
commission	numeric
prev_commission	numeric
commission_diff	numeric
courier_pay	numeric
net_profit	numeric
Вердикт: OK

### F.2. Месяцы покрыты

```sql
SELECT * FROM how_much_money ORDER BY year_month;
```

Ожидается: месяцы от первого доставленного заказа до последнего (не пропущено ни одного).
Факт: месяцы от первого доставленного заказа до последнего (не пропущено ни одного). Последовательно 2026-05 до 2026-11.
Вердикт: OK

### F.3. Месяцы без заказов присутствуют (BR-11.9)

```sql
SELECT year_month FROM how_much_money
WHERE sum_no_commission = 0 OR sum_no_commission IS NULL;
```

Ожидается: если в какие-то месяцы заказов не было — они есть в результате.
Факт: в каждом месяце были заказы, возвращено пустое поле.
Вердикт: OK

Сценарий: удалены все доставленные заказы за 2026-06.
Связанные данные (review_product, review_restaurant, review_order,
review, payment, order_structure) удалены до "order" из-за FK RESTRICT.

Ожидается: 2026-06 заказов не было — они есть в результате.
Факт: столбец year_month содержит значение 2026-06.
Вердикт: OK

### F.4. Корректность сумм

```sql
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
```

Ожидается:
- `commission = sum_with_commission - sum_no_commission`.
- `commission_diff = commission - prev_commission` (NULL для первого месяца).
- `net_profit = commission - courier_pay`.

Факт: 
- `commission = sum_with_commission - sum_no_commission`.
- `commission_diff = commission - prev_commission` (NULL для первого месяца).
- `net_profit = commission - courier_pay`.

| year_month | sum_no_commission | sum_with_commission | commission | prev_commission | commission_diff | courier_pay | net_profit |
|---|---|---|---|---|---|---|---|
| 2026-05 | 22069.68 | 24276.65 | 2206.97 | NULL | NULL | 0 | 2206.97 |
| 2026-06 | 0 | 0 | 0 | 2206.97 | -2206.97 | 165.62 | -165.62 |
| 2026-07 | 14781.13 | 16259.26 | 1478.13 | 0 | 1478.13 | 147.81 | 1330.32 |
| 2026-08 | 11584.22 | 12742.65 | 1158.43 | 1478.13 | -319.70 | 115.85 | 1042.58 |
| 2026-09 | 14119.03 | 15530.93 | 1411.90 | 1158.43 | 253.47 | 141.19 | 1270.71 |
| 2026-10 | 27608.21 | 30369.05 | 2760.84 | 1411.90 | 1348.94 | 276.08 | 2484.76 |
| 2026-11 | 2690.56 | 2959.62 | 269.06 | 2760.84 | -2491.78 | 26.91 | 242.15 |

Вердикт: OK

---

## G. Права `inspector`

### G.1. Права на схему

```sql
SELECT
    nspname AS schema_name,
    has_schema_privilege('inspector', nspname, 'USAGE')  AS usage,
    has_schema_privilege('inspector', nspname, 'CREATE') AS create
FROM pg_namespace
WHERE nspname = 'chaplygin_food';
```

Ожидается: `USAGE`, `CREATE` (полный доступ).
Факт: `chaplygin_food usage [v] create [v]`
Вердикт: OK

### G.2. Права на таблицы

```sql
SELECT table_name, string_agg(privilege_type, ', ') AS privs
FROM information_schema.role_table_grants
WHERE grantee = 'inspector' AND table_schema = 'chaplygin_food'
GROUP BY table_name;
```

Ожидается: у каждой таблицы `SELECT, INSERT, UPDATE, DELETE` (или `ALL`).
Факт: все 12 таблиц + how_much_money (view) — ALL PRIVILEGES.
Вердикт: OK

### G.3. `information_schema` читается под `inspector`

```sql
SET ROLE inspector;
SELECT count(*) FROM information_schema.tables
WHERE table_schema = 'chaplygin_food';
RESET ROLE;
```

Ожидается: 12 + N (количество таблиц).
Факт: 12 таблиц+1 view
Вердикт: OK

### G.4. `pg_catalog` читается под `inspector`

```sql
SET ROLE inspector;
SELECT count(*) FROM pg_catalog.pg_tables
WHERE schemaname = 'chaplygin_food';
RESET ROLE;
```

Ожидается: 12 + N.
Факт: 12 таблиц
Вердикт: OK

### G.5. Все процедуры/функции работают под `inspector`

```sql
SET ROLE inspector;
SET search_path TO chaplygin_food, exts;

CALL erase_test_data();
CALL insert_test_data(10);
CALL courier_salary();
SELECT * FROM get_statistic();
SELECT * FROM how_much_money LIMIT 5;

RESET ROLE;
```

Ожидается: без `permission denied`.
Факт: все завершено успешно, без permission denied.
Вердикт: OK

---

## H. Оптимизация `get_statistic` (BR-11.8)

### H.1. `EXPLAIN ANALYZE` — паттерн «избыточные подзапросы»

```sql
EXPLAIN ANALYZE
SELECT c.courier_id,
       (SELECT count(*) FROM "order" o WHERE o.courier_id = c.courier_id AND o.status = 'доставлен') AS cnt,
       (SELECT coalesce(sum(commission), 0) FROM "order" o WHERE o.courier_id = c.courier_id AND o.status = 'доставлен') AS commission_sum
FROM courier c;
```

Ожидается: два SubPlan, каждый — скан `"order"`. Время растёт линейно от числа курьеров.
Факт: два SubPlan (SubPlan 1 и SubPlan 2), каждый — скан `"order"`
время 0.321 мс (Execution Time: 0.321 ms), план 0.241 мс (Planning Time: 0.241 ms)
Вердикт: OK

### H.2. `EXPLAIN ANALYZE` — паттерн «один JOIN»

```sql
EXPLAIN ANALYZE
SELECT c.courier_id,
       count(o.order_id) AS cnt,
       coalesce(sum(o.commission), 0) AS commission_sum
FROM courier c
LEFT JOIN "order" o ON o.courier_id = c.courier_id AND o.status = 'доставлен'
GROUP BY c.courier_id;
```

Ожидается: один `Hash Right Join` / `Hash Left Join`, один скан `"order"`. Время меньше, чем в H.1.
Факт: один Hash Right Join
время 0.119 мс (Execution Time: 0.119 ms), план 0.243 мс (Planning Time: 0.217 ms)
Время меньше, чем в H.1.
Вердикт: OK

### H.3. Применить к `get_statistic`

```sql
EXPLAIN ANALYZE SELECT * FROM get_statistic();
```

Ожидается: без `LATERAL`, без множественных подзапросов к одной таблице, без оконных функций там, где хватает агрегата.
Факт: Execution Time: 0.758 ms, Planning Time: 0.042 ms.  
Buffers: shared hit=36.
Вердикт: OK

---

## I. Очистка и повторная генерация

### I.1. `erase_test_data` очищает всё

```sql
CALL erase_test_data();

SELECT 'client' AS tbl, count(*) FROM client
UNION ALL SELECT 'courier', count(*) FROM courier
UNION ALL SELECT 'product_category', count(*) FROM product_category
UNION ALL SELECT 'restaurant', count(*) FROM restaurant
UNION ALL SELECT 'address', count(*) FROM address
UNION ALL SELECT 'product', count(*) FROM product
UNION ALL SELECT 'order', count(*) FROM "order"
UNION ALL SELECT 'review', count(*) FROM review
UNION ALL SELECT 'payment', count(*) FROM payment
UNION ALL SELECT 'order_structure', count(*) FROM order_structure
UNION ALL SELECT 'client_address', count(*) FROM client_address
UNION ALL SELECT 'courier_pay', count(*) FROM courier_pay;
```

Ожидается: все 0.
Факт: все 0
Вердикт: OK

### I.2. Повторный `erase_test_data` не падает

```sql
CALL erase_test_data();
```

Ожидается: без ошибок.
Факт: выполнено без ошибок.
Вердикт: OK

### I.3. После очистки `insert_test_data` снова работает

```sql
CALL insert_test_data(10);
SELECT count(*) FROM "order";
```

Ожидается: 50.
Факт: 50.
Вердикт: OK
