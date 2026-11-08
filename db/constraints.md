# Обоснование ограничений

## Enum-типы

Перечисли типы, которые создал. Если добавил/изменил значения относительно BR — обоснуй.

| Тип                | Значения                                          | BR     | Примечание                                                                                                                                                      |
| ------------------ | ------------------------------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| restaurant_status  | активен, неактивен                                | BR-4.3 | —                                                                                                                                                               |
| product_status     | доступно, нет_в_наличии, архив                    | BR-5.5 | —                                                                                                                                                               |
| courier_status     | свободен, занят, на_доставке, уволен              | BR-6.2 | —                                                                                                                                                               |
| order_status       | создан, готовится, в_доставке, доставлен, отменён | BR-7.7 | —                                                                                                                                                               |
| order_pay_status   | ожидает, оплачен, ошибка                          | BR-7.9 | —                                                                                                                                                               |
| payment_type       | карта, наличные, безнал                           | BR-8.2 | —                                                                                                                                                               |
| payment_status     | успех, ошибка, в_обработке                        | BR-8.2 | —                                                                                                                                                               |
| review_entity_type | блюдо, ресторан, заказ                            | BR-9.1 | Создан по тикету FOOD-101 (8 типов). В нормализованной схеме review не используется — полиморфизм заменён на review_product / review_restaurant / review_order. |

Все 8 типов соответствуют BR без изменений значений. Реализованы через CREATE TYPE ... AS ENUM (BR-11.5).

---
## Ловушки

Здесь — не готовые решения, а **фиксация того, как ты решил** каждую ловушку. Преподаватель читает, чтобы понять ход мысли.

### Ловушка 1: `payment` — неполная сущность

**Какие атрибуты добавил в `payment` и почему** (BR-8.2):

```
К атрибутам из ERD добавлены:
- payment_type, amount, transaction_timestamp, status, потому что это обязательные поля из BR-8.2;
- transaction_id — внешний ID от платёжного провайдера (BR-8.3, также входит в обязательные BR-8.2).
```

**Где хранится тип оплаты — `payment` или `order`** (BR-8.6):

```
Тип оплаты payment_type хранится в payment, потому что BR-8.6 явно требует: «Тип оплаты относится к попытке оплаты, а не к заказу. У заказа может быть несколько попыток с разными типами».
```

### Ловушка 2: `pidido.address_id` — принадлежность клиенту (BR-7.4)

**Как обеспечено, что адрес доставки принадлежит клиенту:**

```
Сделан составной FK:
FOREIGN KEY (client_id, address_id)
    REFERENCES client_address(client_id, address_id)

Такой составной FK декларативно гарантирует, что пара (client_id, address_id) существует в client_address, то есть адрес привязан именно к этому клиенту. Триггер и перенос логики на уровень приложения не нужен.
```

### Ловушка 3: `order_structure` — один ресторан в заказе (BR-7.3)

**Как обеспечено, что все блюда из `pidido.restaurant_id`:**

```
Обеспечение условия "один ресторан в заказе" осуществлено путем добавления атрибута order_structure.restaurant_id. Он является избыточным столбцом относительно order_id и product_id, введён осознанно для декларативной гарантии BR-7.3. 
Инвариант обеспечивается двумя составными FK:
в pidido FK(order_id, restaurant_id) — ресторан позиции = ресторан заказа;
в product FK(product_id, restaurant_id) — блюдо принадлежит тому же ресторану.
+ оба родительских UNIQUE-ключа добавлены специально для этих FK.

Формально order_structure.restaurant_id транзитивно зависит от order_id и product_id, но это механизм ограничения целостности - значение не «хранится как данные», а «проверяется как инвариант». Аномалий обновления не создаёт.
```

### Ловушка 4: `review` — нормализация вместо полиморфизма (BR-9.1)

**Как реализована валидность `review.entity_id`:**

```
Сделана нормализация. 
Исходная таблица review из ERD нормализована на 4 таблицы:

review — общие атрибуты (клиент, заказ, текст, фото, рейтинг, дата);
review_product — отзыв на блюдо (review_id, order_id, product_id);
review_restaurant — отзыв на ресторан (review_id, order_id, restaurant_id);
review_order — отзыв на заказ (review_id, order_id).

Выбрана нормализация, а не полиморфизм потому что:

1. Декларативная целостность.
FK product.product_id / restaurant.restaurant_id / pidido.order_id гарантируют, что отзыв ссылается на существующую сущность. Полиморфизм такой гарантии не даёт.

2. Бизнес-требование BR-9.5 гарантировано на уровне схемы.
UNIQUE (order_id, product_id) в review_product, UNIQUE (order_id, restaurant_id) в review_restaurant, UNIQUE (order_id) в review_order — все три ограничения обеспечивают «не более одного отзыва на объект в рамках заказа». 
При сохранении полиморфизма это пришлось бы делать триггером.

3. Реализации триггерной функции rating_change (FOOD-105) проще реализовать. Триггер на review_product / review_restaurant вместо разбора entity_type.
```

---

## CHECK-ограничения

Каждое — с ссылкой на BR.

| Таблица          | Столбец                    | Условие                                                                                               | BR              | Обоснование                                                                                                                                                    |
| ---------------- | -------------------------- | ----------------------------------------------------------------------------------------------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| client           | login                      | LENGTH(trim(login)) > 0                                                                               | BR-11.3         | Логин не может быть пустым (BR-11.3: «Всё остальное — обязательно»)                                                                                            |
| client           | password                   | `password ~ '^[a-f0-9]{32}$'`                                                                         | BR-2.3          | Пароль — MD5-хэш (32 hex-символа)                                                                                                                              |
| client           | phone_number               | `phone_number ~ '^\+7[0-9]{10}$'`                                                                     | BR-2.1          | Телефон в формате +7XXXXXXXXXX; BR-2.1 требует телефон                                                                                                         |
| address          | street                     | LENGTH(trim(street)) > 0                                                                              | BR-3.1, BR-11.3 | Улица обязательна (BR-3.1)                                                                                                                                     |
| address          | house_number               | LENGTH(trim(house_number)) > 0                                                                        | BR-3.1, BR-11.3 | Номер дома обязателен (BR-3.1)                                                                                                                                 |
| address          | apartment_office           | IS NULL OR LENGTH(trim(...)) > 0                                                                      | BR-3.2          | Квартира/офис необязательна (BR-3.2), но пустая строка — не NULL                                                                                               |
| restaurant       | rating                     | IS NULL OR BETWEEN 0 AND 5                                                                            | BR-4.2, BR-9.6  | Рейтинг от 0 до 5 (BR-4.2), NULL при отсутствии отзывов (BR-9.6)                                                                                               |
| restaurant       | work_start, work_end       | work_end > work_start                                                                                 | BR-4.4          | Время закрытия позже открытия                                                                                                                                  |
| restaurant       | restaurant_name            | LENGTH(trim(...)) > 0                                                                                 | BR-4.1, BR-11.3 | Название обязательно (BR-4.1)                                                                                                                                  |
| restaurant       | description                | LENGTH(trim(...)) > 0                                                                                 | BR-4.1          | BR-4.1: у ресторана есть описание. Пустая строка — не описание; CHECK уточняет «есть описание» = «непустая строка» (аналогично chk_restaurant_name)            |
| restaurant       | company_details            | LENGTH(trim(...)) > 0                                                                                 | BR-4.5          | Реквизиты обязательны (BR-4.5)                                                                                                                                 |
| product_category | product_category_name      | LENGTH(trim(...)) > 0                                                                                 | BR-5.7, BR-11.3 | Название категории обязательно (BR-5.7)                                                                                                                        |
| product          | price                      | price >= 0                                                                                            | BR-5.3          | BR-5.3: цена неотрицательна                                                                                                                                    |
| product          | rating                     | IS NULL OR BETWEEN 0 AND 5                                                                            | BR-5.4, BR-9.6  | Рейтинг от 0 до 5 (BR-5.4), NULL при отсутствии отзывов (BR-9.6)                                                                                               |
| product          | product_name               | LENGTH(trim(...)) > 0                                                                                 | BR-5.2, BR-11.3 | Название обязательно (BR-5.2)                                                                                                                                  |
| courier          | coefficient                | BETWEEN 0.1 AND 0.5                                                                                   | BR-6.4          | Коэффициент от 0.1 до 0.5 включительно                                                                                                                         |
| courier          | status, dismissal_date     | (status = 'уволен' AND dismissal_date IS NOT NULL) OR (status <> 'уволен' AND dismissal_date IS NULL) | BR-6.3          | BR-6.3: уволенный обязан иметь дату. Ужесточено до dismissal_date IS NOT NULL ⇔ status = 'уволен' — состояние «работает, но уволен» семантически противоречиво |
| courier          | dismissal_date, hire_date  | dismissal_date IS NULL OR dismissal_date >= hire_date                                                 | BR-6.3          | Дата увольнения не раньше найма (логика BR-6.3)                                                                                                                |
| courier          | fio                        | LENGTH(trim(...)) > 0                                                                                 | BR-6.1, BR-11.3 | ФИО обязательно (BR-6.1)                                                                                                                                       |
| courier          | phone_number               | `phone_number ~ '^\+7[0-9]{10}$'`                                                                     | BR-6.1          | Телефон в формате +7XXXXXXXXXX                                                                                                                                 |
| pidido           | commission                 | commission = round(order_amount * 0.10, 2)                                                            | BR-1.4, BR-7.10 | Комиссия = 10% от суммы без комиссии                                                                                                                           |
| pidido           | total_amount               | total_amount = order_amount + commission                                                              | BR-7.10         | Общая сумма = сумма без комиссии + комиссия                                                                                                                    |
| pidido           | total_amount               | total_amount >= 1000                                                                                  | BR-1.8, BR-7.11 | Минимальная сумма заказа 1000 ₽                                                                                                                                |
| pidido           | delivery_timestamp         | IS NULL OR delivery_timestamp >= order_timestamp                                                      | BR-7.13         | Время окончания не раньше создания                                                                                                                             |
| pidido           | status, delivery_timestamp | (status = 'доставлен' AND delivery_timestamp IS NOT NULL) OR (status <> 'доставлен')                  | BR-7.12         | Время окончания заполняется при статусе «доставлен»                                                                                                            |
| order_structure  | quantity                   | quantity > 0                                                                                          | BR-7.15         | Количество положительное                                                                                                                                       |
| review           | rating                     | rating BETWEEN 1 AND 5                                                                                | BR-9.4          | Рейтинг отзыва от 1 до 5                                                                                                                                       |
| review           | description                | LENGTH(trim(...)) > 0                                                                                 | BR-9.3, BR-11.3 | Текст отзыва обязателен (BR-9.3)                                                                                                                               |
| courier_pay      | month                      | month BETWEEN 1 AND 12                                                                                | —               | Месяц 1–12 (календарная логика)                                                                                                                                |
| courier_pay      | year                       | year BETWEEN 2020 AND 2100                                                                            | BR-10.2         | Год выплаты — разумный горизонт; BR-10.2 не задаёт диапазон, CHECK защищает от опечаток                                                                        |
| courier_pay      | amount                     | amount >= 0                                                                                           | BR-10.4         | Сумма зарплаты неотрицательна                                                                                                                                  |
| courier_pay      | coefficient_used           | BETWEEN 0.1 AND 0.5                                                                                   | BR-6.4          | Применённый коэффициент из диапазона BR-6.4                                                                                                                    |

---

## UNIQUE-ограничения

| Таблица                                           | Столбцы                                                    | BR      | Обоснование                                                                                           |
| ------------------------------------------------- | ---------------------------------------------------------- | ------- | ----------------------------------------------------------------------------------------------------- |
| client                                            | login                                                      | BR-2.2  | Логин уникален                                                                                        |
| client                                            | phone_number                                               | BR-2.2  | Телефон уникален                                                                                      |
| client_address                                    | (client_id, address_id) (PK)                               | BR-2.5  | Один адрес у клиента — один раз (BR-2.5)                                                              |
| restaurant                                        | address_id                                                 | BR-3.3  | Два ресторана не могут делить адрес                                                                   |
| product_category                                  | product_category_name                                      | BR-5.7  | Названия категорий уникальны (иначе справочник теряет смысл)                                          |
| product                                           | (product_id, restaurant_id)                                | BR-5.1  | Для составного FK из order_structure (ловушка 3); гарантирует, что блюдо принадлежит одному ресторану |
| courier                                           | phone_number                                               | BR-6.1  | Телефон курьера уникален                                                                              |
| pidido                                            | (order_id, restaurant_id)                                  | BR-7.3  | Для составного FK из order_structure (ловушка 3)                                                      |
| pidido                                            | (order_id, total_amount)                                   | BR-8.4  | Для составного FK из payment (BR-8.4: сумма платежа = total_amount)                                   |
| order_structure                                   | (order_id, product_id) (PK)                                | BR-7.16 | Одно блюдо в заказе — один раз (BR-7.16)                                                              |
| payment                                           | transaction_id                                             | BR-8.3  | ID транзакции уникален                                                                                |
| payment                                           | (order_id) WHERE status = 'успех' (частичный UNIQUE INDEX) | BR-8.1  | Не более одной успешной попытки на заказ                                                              |
| review_product                                    | (order_id, product_id)                                     | BR-9.5  | Не более одного отзыва на блюдо в рамках заказа                                                       |
| review_restaurant                                 | (order_id, restaurant_id)                                  | BR-9.5  | Не более одного отзыва на ресторан в рамках заказа                                                    |
| review_order                                      | (order_id)                                                 | BR-9.5  | Не более одного отзыва на заказ                                                                       |
| review_product / review_restaurant / review_order | review_id (PK)                                             | BR-9.1  | 1:1 к review                                                                                          |
| courier_pay                                       | (year, month, courier_id) (PK)                             | BR-10.3 | Одна запись на курьера в месяц                                                                        |

---

## FK-ограничения

| Таблица           | Столбцы                     | → Таблица                             | BR             | Обоснование                                     |
| ----------------- | --------------------------- | ------------------------------------- | -------------- | ----------------------------------------------- |
| client_address    | client_id                   | client(client_id)                     | BR-2.4         | Адрес привязан к клиенту                        |
| client_address    | address_id                  | address(address_id)                   | BR-2.4         | Связь M:N клиент↔адрес                          |
| restaurant        | address_id                  | address(address_id)                   | BR-3.3         | Ресторан имеет адрес                            |
| product           | product_category_id         | product_category(product_category_id) | BR-5.1         | Блюдо принадлежит категории                     |
| product           | restaurant_id               | restaurant(restaurant_id)             | BR-5.1         | Блюдо принадлежит ресторану                     |
| pidido            | courier_id                  | courier(courier_id)                   | BR-7.5         | Заказ доставляет курьер                         |
| pidido            | client_id                   | client(client_id)                     | BR-7.1, BR-7.2 | Заказ оформляет клиент                          |
| pidido            | restaurant_id               | restaurant(restaurant_id)             | BR-7.2         | Заказ привязан к ресторану                      |
| pidido            | (client_id, address_id)     | client_address(client_id, address_id) | BR-7.4         | Адрес доставки — из адресов клиента (ловушка 2) |
| order_structure   | (order_id, restaurant_id)   | pidido(order_id, restaurant_id)       | BR-7.3         | Позиция из ресторана заказа (ловушка 3)         |
| order_structure   | (product_id, restaurant_id) | product(product_id, restaurant_id)    | BR-7.3         | Блюдо из того же ресторана (ловушка 3)          |
| payment           | order_id                    | pidido(order_id)                      | BR-8.1         | Платёж относится к заказу                       |
| payment           | (order_id, amount)          | pidido(order_id, total_amount)        | BR-8.4         | Сумма платежа = total_amount заказа             |
| review            | client_id                   | client(client_id)                     | BR-9.1         | Отзыв оставляет клиент                          |
| review            | order_id                    | pidido(order_id)                      | BR-9.2         | Отзыв связан с заказом                          |
| review_product    | review_id                   | review(review_id)                     | BR-9.1         | Отзыв на блюдо — подчинённая запись review      |
| review_product    | order_id                    | pidido(order_id)                      | BR-9.5         | Для UNIQUE (order_id, product_id)               |
| review_product    | product_id                  | product(product_id)                   | BR-9.1         | Отзыв ссылается на существующее блюдо           |
| review_restaurant | review_id                   | review(review_id)                     | BR-9.1         | Отзыв на ресторан — подчинённая запись review   |
| review_restaurant | order_id                    | pidido(order_id)                      | BR-9.5         | Для UNIQUE (order_id, restaurant_id)            |
| review_restaurant | restaurant_id               | restaurant(restaurant_id)             | BR-9.1         | Отзыв ссылается на существующий ресторан        |
| review_order      | review_id                   | review(review_id)                     | BR-9.1         | Отзыв на заказ — подчинённая запись review      |
| review_order      | order_id                    | pidido(order_id)                      | BR-9.5         | Для UNIQUE (order_id)                           |
| courier_pay       | courier_id                  | courier(courier_id)                   | BR-10.2        | Выплата привязана к курьеру                     |

**fk_payment_order и fk_payment_amount** — оба на pidido. fk_payment_order (order_id → pidido.order_id) явно говорит «платёж относится к заказу». fk_payment_amount ((order_id, amount) → pidido(order_id, total_amount)) гарантирует BR-8.4. fk_payment_amount функционально включает fk_payment_order, но оба оставлены для явности.

---
## ON DELETE

**`ON DELETE RESTRICT`** (21 FK) — BR-3.5 («история заказов должна сохраняться»), BR-1.6 («возвратов нет»), BR-10.6 («уволенный получает зарплату за месяц»). Удаление `client` / `courier` / `restaurant` / `product` не должно каскадно удалять `pidido` / `order_structure` / `payment` / `review` / `courier_pay`. `RESTRICT` явно говорит о намерении.

**`ON DELETE CASCADE`** (3 FK: `review_product → review`, `review_restaurant → review`, `review_order → review`) — композиция 1:1. При удалении `review` дочерние строки должны исчезнуть (иначе останутся «висячие» отзывы без текста/рейтинга). BR-3.5 не противоречит — он про `address` и `pidido`, а не про `review`.

| Таблица           | `ON DELETE` | BR      | Обоснование                              |
| ----------------- | ----------- | ------- | ---------------------------------------- |
| client_address    | RESTRICT    | BR-3.5  | История заказов; адрес не удаляется      |
| client_address    | RESTRICT    | BR-3.5  | Адрес не удаляется                       |
| restaurant        | RESTRICT    | BR-3.5  | Адрес не удаляется                       |
| product           | RESTRICT    | BR-5.1  | Блюдо без категории невалидно            |
| product           | RESTRICT    | BR-5.1  | Блюдо без ресторана невалидно            |
| pidido            | RESTRICT    | BR-3.5  | История заказов                          |
| pidido            | RESTRICT    | BR-3.5  | История заказов                          |
| pidido            | RESTRICT    | BR-3.5  | История заказов                          |
| pidido            | RESTRICT    | BR-7.4  | Адрес из адресов клиента                 |
| order_structure   | RESTRICT    | BR-3.5  | История заказов                          |
| order_structure   | RESTRICT    | BR-3.5  | История заказов                          |
| payment           | RESTRICT    | BR-3.5  | История заказов                          |
| payment           | RESTRICT    | BR-3.5  | История заказов                          |
| review            | RESTRICT    | BR-3.5  | История заказов                          |
| review            | RESTRICT    | BR-3.5  | История заказов                          |
| review_product    | **CASCADE** | BR-9.1  | Композиция 1:1                           |
| review_product    | RESTRICT    | BR-3.5  | История заказов                          |
| review_product    | RESTRICT    | BR-3.5  | История заказов                          |
| review_restaurant | **CASCADE** | BR-9.1  | Композиция 1:1                           |
| review_restaurant | RESTRICT    | BR-3.5  | История заказов                          |
| review_restaurant | RESTRICT    | BR-3.5  | История заказов                          |
| review_order      | **CASCADE** | BR-9.1  | Композиция 1:1                           |
| review_order      | RESTRICT    | BR-3.5  | История заказов                          |
| courier_pay       | RESTRICT    | BR-10.6 | Уволенный получает зарплату за месяц     |

---

## NOT NULL (только бизнес-обязательные)

Все NOT NULL — очевидные

---

## NULL (осознанно разрешено)

| Таблица    | Столбец            | BR      | Почему NULL                                                                                                                                                                                                                                                                                                                                                                               |
| ---------- | ------------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| address    | apartment_office   | BR-3.2  | Квартира/офис необязательна (частные дома, отдельные входы)                                                                                                                                                                                                                                                                                                                               |
| restaurant | rating             | BR-9.6  | Если отзывов нет - рейтинг NULL                                                                                                                                                                                                                                                                                                                                                           |
| product    | photo_url          | BR-5.6  | Фотография необязательна                                                                                                                                                                                                                                                                                                                                                                  |
| product    | rating             | BR-9.6  | Если отзывов нет - рейтинг NULL                                                                                                                                                                                                                                                                                                                                                           |
| courier    | dismissal_date     | BR-6.3  | Работающий курьер не имеет даты увольнения                                                                                                                                                                                                                                                                                                                                                |
| pidido     | delivery_timestamp | BR-7.12 | Заполняется при статусе «доставлен» и не присутствует в таблице сразу                                                                                                                                                                                                                                                                                                                     |
| pidido     | description        | BR-11.3 | Описание заказа - свободный комментарий клиента, которого может не быть. BR-7.* перечисляет обязательные атрибуты заказа (дата, клиент, ресторан, курьер, статус, pay_status, суммы, времена) - описания среди них нет, значит это необязательное поле расширения, оставленное ERD на логический уровень. BR-11.3 «Всё остальное — обязательно» применяю к атрибутам, перечисленным в BR. |
| review     | photo_url          | BR-9.3  | Фотография необязательна                                                                                                                                                                                                                                                                                                                                                                  |

---

## DEFAULT и GENERATED

| Таблица     | Столбец          | Что                             | Обоснование                                                                                                                                                                                                                                                                     |
| ----------- | ---------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| все таблицы | *_id (PK)        | DEFAULT exts.uuid_generate_v4() | BR-11.1: все ID генерируются через exts.uuid_generate_v4()                                                                                                                                                                                                                      |
| restaurant  | rating           | DEFAULT NULL                    | BR-9.6: рейтинг NULL при отсутствии отзывов (явно, для читаемости)                                                                                                                                                                                                              |
| product     | rating           | DEFAULT NULL                    | BR-9.6: рейтинг NULL при отсутствии отзывов (явно, для читаемости)                                                                                                                                                                                                              |
| courier     | coefficient      | DEFAULT 0.1                     | BR-6.5: изначальный коэффициент нового курьера — 0.1                                                                                                                                                                                                                            |
| pidido      | order_timestamp  | DEFAULT LOCALTIMESTAMP          | BR-7.1: дата/время создания фиксируется при создании; BR-11.2: без таймзоны                                                                                                                                                                                                     |
| pidido      | pay_status       | DEFAULT 'ожидает'               | BR-7.9: начальный статус — «ожидает». BR-8.7 требует пересчёта по попыткам — это поведение, не структура. На уровне FOOD-101 DEFAULT обеспечивает валидное начальное состояние; пересчёт при изменении payment — задача приложения (отдельного тикета на триггер в бэклоге нет) |
| review      | review_timestamp | DEFAULT LOCALTIMESTAMP          | BR-9.3: дата отзыва фиксируется при создании; BR-11.2                                                                                                                                                                                                                           |
| courier_pay | coefficient_used | DEFAULT 0.1                     | BR-6.5: страховка, если процедура не передала коэффициент                                                                                                                                                                                                                       |

`commission` и `total_amount` - обычные поля с `CHECK`, потому что BR-7.10 говорит «у заказа есть сумма без комиссии, комиссия, общая сумма» - это атрибуты, а не вычисляемые поля. GENERATED усложнил бы insert_test_data (нельзя вставить явное значение); CHECK-а достаточно для гарантии формулы.

---
## Нормализация (3НФ)

Короткое обоснование, что все таблицы в 3НФ:

```
Все атрибуты атомарны, повторяющихся групп нет, а где связи многие-ко-многим, один-к-одному реализованы составным первичным ключом (1НФ). 
Все неключевые атрибуты зависят от полного первичного ключа. В client_address и order_structure неключевых атрибутов нет (только ключи + quantity/restaurant_id), поэтому 2НФ тривиальна. В остальных таблицах первичный ключ - суррогатный UUID, зависимость от полного первичного ключа тривиальна. 
Нет транзитивных зависимостей неключевых атрибутов от первичного ключа (3НФ).

Особые случаи:
- pidido.commission = 10% от order_amount — вычисляемое и pidido.total_amount = order_amount + commission — вычисляемое. Оставлены как обычные поля с CHECK. Зависят напрямую от атрибута в этой же таблице, а не транзитивно через другую таблицу (3НФ).
  
- product.rating и restaurant.rating — агрегаты, поддерживаются триггером rating_change. Это осознанная денормализация для скорости чтения, потому что BR-9.6 явно требует хранить агрегат в product.rating / restaurant.rating и значение всегда консистентно с review (триггер на INSERT/UPDATE/DELETE).
  
- review.entity_id + entity_type — полиморфизм. Формально не нарушает 3НФ, но выбрана нормализация (review + review_product + review_restaurant + review_order), потому что: FK гарантируют существование сущности, BR-9.5 гарантирован на уровне схемы, rating_change проще. Полиморфизм (entity_id + entity_type) заменён на нормализованную схему.[Подробнее -> Ловушка 4]
   
- pidido — переименование `order` (BR-13.1). Осознанное решение: `order` — зарезервированное слово PostgreSQL, требующее кавычек во всех запросах. Переименовано в pidido (перевод на испанский), чтобы избежать кавычек в коде функций/процедур. Это не нарушение 3НФ, а соглашение об именовании (BR-13.1 явно разрешает оба варианта).
  
- order_structure.restaurant_id - реализован для логики "один ресторан в заказе" BR-7.3. Аномалий обновления не создает, без этого атрибута требуется триггер. [Подробнее -> Ловушка 3]
```