# Обоснование ограничений

## Enum-типы

Перечисли типы, которые создал. Если добавил/изменил значения относительно BR — обоснуй.

| Тип                | Значения                                          | BR     | Примечание |
| ------------------ | ------------------------------------------------- | ------ | ---------- |
| restaurant_status  | активен, неактивен                                | BR-4.3 | —          |
| product_status     | доступно, нет_в_наличии, архив                    | BR-5.5 | —          |
| courier_status     | свободен, занят, на_доставке, уволен              | BR-6.2 | —          |
| order_status       | создан, готовится, в_доставке, доставлен, отменён | BR-7.7 | —          |
| order_pay_status   | ожидает, оплачен, ошибка                          | BR-7.9 | —          |
| payment_type       | карта, наличные, безнал                           | BR-8.2 | —          |
| payment_status     | успех, ошибка, в_обработке                        | BR-8.2 | —          |
| review_entity_type | блюдо, ресторан, заказ                            | BR-9.1 | —          |

Все 8 типов соответствуют BR без изменений значений. Реализованы через CREATE TYPE ... AS ENUM (BR-11.5).

---
## Ловушки

Здесь — не готовые решения, а **фиксация того, как ты решил** каждую ловушку. Преподаватель читает, чтобы понять ход мысли.

### Ловушка 1: `payment` — неполная сущность

**Какие атрибуты добавил в `payment` и почему** (BR-8.2):

К атрибутам из ERD добавлены:
- payment_type, amount, transaction_timestamp, status, потому что это обязательные поля из BR-8.2;
- transaction_id — внешний ID от платёжного провайдера (BR-8.3, также входит в обязательные BR-8.2).

**Где хранится тип оплаты — `payment` или `order`** (BR-8.6):

Тип оплаты payment_type хранится в payment, потому что BR-8.6 явно требует: «Тип оплаты относится к попытке оплаты, а не к заказу. У заказа может быть несколько попыток с разными типами».

### Ловушка 2: `"order".address_id` — принадлежность клиенту (BR-7.4)

**Как обеспечено, что адрес доставки принадлежит клиенту:**


Сделан составной внешний ключ:
`FOREIGN KEY (client_id, address_id) REFERENCES client_address(client_id, address_id)`.
Это декларативно гарантирует, что адрес доставки принадлежит именно этому клиенту. Триггер не нужен.вень приложения не нужен.

### Ловушка 3: `order_structure` — один ресторан в заказе (BR-7.3)

**Как обеспечено, что все блюда из `"order".restaurant_id`:**

В таблицу `order_structure` добавлен избыточный столбец `restaurant_id`. 
Он введён осознанно для декларативной гарантии BR-7.3. Инвариант обеспечивается двумя составными FK:
1. `(order_id, restaurant_id)` → `"order"(order_id, restaurant_id)` — ресторан позиции = ресторан заказа;
2. `(product_id, restaurant_id)` → `product(product_id, restaurant_id)` — блюдо принадлежит тому же ресторану.
Оба родительских UNIQUE-ключа (`"order"(order_id, restaurant_id)` и `product(product_id, restaurant_id)`) специально добавлены для этих FK.
Формально `restaurant_id` транзитивно зависит от `order_id` и `product_id`, но это механизм ограничения целостности (инвариант), а не хранение данных. Аномалий обновления не создаёт.
### Ловушка 4: `review` — полиморфизм (BR-9.1)

**Как реализована валидность `review.entity_id`:**

Реализован полиморфизм: `entity_id` + `entity_type`.
- Нет FK на `product` или `restaurant`, так как `entity_id` может ссылаться на разные таблицы в зависимости от `entity_type`.
- Валидность `entity_id` (что отзыв действительно на то, что заказал клиент) проверяется в приложении и триггере `rating_change_review`.
- Связь с заказом клиента гарантируется составным FK `(order_id, client_id) → "order"(order_id, client_id)` (BR-9.2).

---

## CHECK-ограничения

Каждое — с ссылкой на BR.

| Таблица          | Столбец                    | Условие                                                                                               | BR              | Обоснование                                                                                                         |
| ---------------- | -------------------------- | ----------------------------------------------------------------------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------- |
| client           | login                      | LENGTH(trim(login)) > 0                                                                               | BR-11.3         | Логин не может быть пустым                                                                                          |
| client           | password                   | password ~ '^[0-9a-f]{32}$'                                                                           | BR-2.3          | Пароль — MD5-хэш (32 hex-символа)                                                                                   |
| client           | phone_number               | phone_number ~ '^+7[0-9]{10}$'                                                                        | BR-2.1          | Телефон в формате +7XXXXXXXXXX                                                                                      |
| address          | street                     | LENGTH(trim(street)) > 0                                                                              | BR-3.1, BR-11.3 | Улица обязательна                                                                                                   |
| address          | house_number               | LENGTH(trim(house_number)) > 0                                                                        | BR-3.1, BR-11.3 | Номер дома обязателен                                                                                               |
| address          | apartment_office           | IS NULL OR LENGTH(trim(...)) > 0                                                                      | BR-3.2          | Квартира/офис необязательна, но пустая строка — не NULL                                                             |
| restaurant       | restaurant_name            | LENGTH(trim(...)) > 0                                                                                 | BR-4.1, BR-11.3 | Название обязательно                                                                                                |
| restaurant       | description                | LENGTH(trim(...)) > 0                                                                                 | BR-4.1          | У ресторана есть описание; пустая строка — не описание                                                              |
| restaurant       | legal_name                 | LENGTH(trim(...)) > 0                                                                                 | BR-4.5          | Юридическое название обязательно (1НФ: вынесено из company_details)                                                 |
| restaurant       | inn                        | inn ~ '^[0-9]{10,12}$'                                                                                | BR-4.5          | ИНН — 10 (юрлицо) или 12 (ИП) цифр (1НФ: вынесено из company_details)                                               |
| restaurant       | bank_account               | bank_account ~ '^[0-9]{20}$'                                                                          | BR-4.5          | Расчётный счёт — 20 цифр (1НФ: вынесено из company_details)                                                         |
| restaurant       | rating                     | IS NULL OR BETWEEN 0 AND 5                                                                            | BR-4.2, BR-9.6  | Рейтинг от 0 до 5, NULL при отсутствии отзывов                                                                      |
| restaurant       | work_start, work_end       | work_end > work_start                                                                                 | BR-4.4          | Время закрытия позже открытия                                                                                       |
| product_category | product_category_name      | LENGTH(trim(...)) > 0                                                                                 | BR-5.7, BR-11.3 | Название категории обязательно                                                                                      |
| product          | product_name               | LENGTH(trim(...)) > 0                                                                                 | BR-5.2, BR-11.3 | Название обязательно                                                                                                |
| product          | price                      | price >= 0                                                                                            | BR-5.3          | Цена неотрицательна                                                                                                 |
| product          | rating                     | IS NULL OR BETWEEN 0 AND 5                                                                            | BR-5.4, BR-9.6  | Рейтинг от 0 до 5, NULL при отсутствии отзывов                                                                      |
| product          | description                | LENGTH(trim(...)) > 0                                                                                 | BR-5.2, BR-11.3 | Описание обязательно                                                                                                |
| courier          | last_name                  | LENGTH(trim(...)) > 0                                                                                 | BR-6.1, BR-11.3 | Фамилия обязательна (1НФ: вынесено из fio)                                                                          |
| courier          | first_name                 | LENGTH(trim(...)) > 0                                                                                 | BR-6.1, BR-11.3 | Имя обязательно (1НФ: вынесено из fio)                                                                              |
| courier          | middle_name                | LENGTH(trim(...)) > 0                                                                                 | BR-6.1, BR-11.3 | Отчество обязательно (1НФ: вынесено из fio)                                                                         |
| courier          | phone_number               | phone_number ~ '^+7[0-9]{10}$'                                                                        | BR-6.1          | Телефон в формате +7XXXXXXXXXX                                                                                      |
| courier          | status, dismissal_date     | (status = 'уволен' AND dismissal_date IS NOT NULL) OR (status <> 'уволен' AND dismissal_date IS NULL) | BR-6.3          | BR-6.3: уволенный обязан иметь дату. Ужесточено до XOR — состояние «работает, но уволен» семантически противоречиво |
| courier          | dismissal_date, hire_date  | dismissal_date IS NULL OR dismissal_date >= hire_date                                                 | BR-6.3          | Дата увольнения не раньше найма                                                                                     |
| courier          | coefficient                | BETWEEN 0.1 AND 0.5                                                                                   | BR-6.4          | Коэффициент от 0.1 до 0.5 включительно                                                                              |
| order            | commission                 | commission = round(order_amount * 0.10, 2)                                                            | BR-1.4, BR-7.10 | Комиссия = 10% от суммы без комиссии                                                                                |
| order            | total_amount               | total_amount = order_amount + commission                                                              | BR-7.10         | Общая сумма = сумма без комиссии + комиссия                                                                         |
| order            | total_amount               | total_amount >= 1000                                                                                  | BR-1.8, BR-7.11 | Минимальная сумма заказа 1000 ₽                                                                                     |
| order            | delivery_timestamp         | IS NULL OR delivery_timestamp >= order_timestamp                                                      | BR-7.13         | Время окончания не раньше создания                                                                                  |
| order            | status, delivery_timestamp | (status = 'доставлен' AND delivery_timestamp IS NOT NULL) OR (status <> 'доставлен')                  | BR-7.12         | Время окончания заполняется при статусе «доставлен»                                                                 |
| order_structure  | quantity                   | quantity > 0                                                                                          | BR-7.15         | Количество положительное                                                                                            |
| payment          | amount                     | amount >= 0                                                                                           | BR-8.2          | Сумма попытки неотрицательна (избыточен из-за FK на total_amount, оставлен как страховка)                           |
| review           | rating                     | rating BETWEEN 1 AND 5                                                                                | BR-9.4          | Рейтинг отзыва от 1 до 5                                                                                            |
| review           | description                | LENGTH(trim(...)) > 0                                                                                 | BR-9.3, BR-11.3 | Текст отзыва обязателен                                                                                             |
| courier_pay      | month                      | month BETWEEN 1 AND 12                                                                                | —               | Месяц 1–12 (календарная логика)                                                                                     |
| courier_pay      | year                       | year BETWEEN 2020 AND 2100                                                                            | BR-10.2         | Год выплаты — разумный горизонт; BR-10.2 не задаёт диапазон, CHECK защищает от опечаток                             |
| courier_pay      | amount                     | amount >= 0                                                                                           | BR-10.4         | Сумма зарплаты неотрицательна                                                                                       |
| courier_pay      | coefficient_used           | BETWEEN 0.1 AND 0.5                                                                                   | BR-6.4          | Применённый коэффициент из диапазона BR-6.4                                                                         |

---

## UNIQUE-ограничения

| Таблица          | Столбцы                                                    | BR      | Обоснование                                      |
| ---------------- | ---------------------------------------------------------- | ------- | ------------------------------------------------ |
| client           | login                                                      | BR-2.2  | Логин уникален                                   |
| client           | phone_number                                               | BR-2.2  | Телефон уникален                                 |
| client_address   | (client_id, address_id) (PK)                               | BR-2.5  | Один адрес у клиента — один раз                  |
| restaurant       | address_id                                                 | BR-3.3  | Два ресторана не могут делить адрес              |
| product_category | product_category_name                                      | BR-5.7  | Названия категорий уникальны                     |
| product          | (product_id, restaurant_id)                                | BR-5.1  | Для составного FK из order_structure             |
| courier          | phone_number                                               | BR-6.1  | Телефон курьера уникален                         |
| "order"          | (order_id, client_id)                                      | BR-9.2  | Для составного FK из review (заказ клиента)      |
| "order"          | (order_id, restaurant_id)                                  | BR-7.3  | Для составного FK из order_structure             |
| "order"          | (order_id, total_amount)                                   | BR-8.4  | Для FK из payment (сумма = total_amount)         |
| order_structure  | (order_id, product_id) (PK)                                | BR-7.16 | Одно блюдо в заказе — один раз                   |
| payment          | transaction_id                                             | BR-8.3  | ID транзакции уникален                           |
| payment          | (order_id) WHERE status = 'успех' (частичный UNIQUE INDEX) | BR-8.1  | Не более одной успешной попытки на заказ         |
| review           | (order_id, entity_type, entity_id)                         | BR-9.5  | Не более одного отзыва на объект в рамках заказа |
| courier_pay      | (year, month, courier_id) (PK)                             | BR-10.3 | Одна запись на курьера в месяц                   |

---

## FK-ограничения

| Таблица | Столбцы | → Таблица | BR | Обоснование |
|---|---|---|---|---|
| client_address | client_id | client(client_id) | BR-2.4 | Адрес привязан к клиенту |
| client_address | address_id | address(address_id) | BR-2.4 | Связь M:N клиент↔адрес |
| restaurant | address_id | address(address_id) | BR-3.3 | Ресторан имеет адрес |
| product | product_category_id | product_category(product_category_id) | BR-5.1 | Блюдо принадлежит категории |
| product | restaurant_id | restaurant(restaurant_id) | BR-5.1 | Блюдо принадлежит ресторану |
| "order" | courier_id | courier(courier_id) | BR-7.5 | Заказ доставляет курьер |
| "order" | client_id | client(client_id) | BR-7.1, BR-7.2 | Заказ оформляет клиент |
| "order" | restaurant_id | restaurant(restaurant_id) | BR-7.2 | Заказ привязан к ресторану |
| "order" | (client_id, address_id) | client_address(client_id, address_id) | BR-7.4 | Адрес доставки — из адресов клиента |
| order_structure | (order_id, restaurant_id) | "order"(order_id, restaurant_id) | BR-7.3 | Позиция из ресторана заказа |
| order_structure | (product_id, restaurant_id) | product(product_id, restaurant_id) | BR-7.3 | Блюдо из того же ресторана |
| payment | order_id | "order"(order_id) | BR-8.1 | Платёж относится к заказу |
| payment | (order_id, amount) | "order"(order_id, total_amount) | BR-8.4 | Сумма платежа = total_amount заказа |
| review | (order_id, client_id) | "order"(order_id, client_id) | BR-9.2 | Отзыв связан с заказом клиента |
| courier_pay | courier_id | courier(courier_id) | BR-10.2 | Выплата привязана к курьеру |

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
| "order"    | delivery_timestamp | BR-7.12 | Заполняется при статусе «доставлен» и не присутствует в таблице сразу                                                                                                                                                                                                                                                                                                                     |
| "order"    | description        | BR-11.3 | Описание заказа - свободный комментарий клиента, которого может не быть. BR-7.* перечисляет обязательные атрибуты заказа (дата, клиент, ресторан, курьер, статус, pay_status, суммы, времена) - описания среди них нет, значит это необязательное поле расширения, оставленное ERD на логический уровень. BR-11.3 «Всё остальное — обязательно» применяю к атрибутам, перечисленным в BR. |
| review     | photo_url          | BR-9.3  | Фотография необязательна                                                                                                                                                                                                                                                                                                                                                                  |

---

## DEFAULT и GENERATED

| Таблица     | Столбец          | Что                             | Обоснование                                                                                                                                                                                                                                                                     |
| ----------- | ---------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| все таблицы | *_id (PK)        | DEFAULT exts.uuid_generate_v4() | BR-11.1: все ID генерируются через exts.uuid_generate_v4()                                                                                                                                                                                                                      |
| restaurant  | rating           | DEFAULT NULL                    | BR-9.6: рейтинг NULL при отсутствии отзывов (явно, для читаемости)                                                                                                                                                                                                              |
| product     | rating           | DEFAULT NULL                    | BR-9.6: рейтинг NULL при отсутствии отзывов (явно, для читаемости)                                                                                                                                                                                                              |
| courier     | coefficient      | DEFAULT 0.1                     | BR-6.5: изначальный коэффициент нового курьера — 0.1                                                                                                                                                                                                                            |
| "order"     | order_timestamp  | DEFAULT LOCALTIMESTAMP          | BR-7.1: дата/время создания фиксируется при создании; BR-11.2: без таймзоны                                                                                                                                                                                                     |
| "order"     | pay_status       | DEFAULT 'ожидает'               | BR-7.9: начальный статус — «ожидает». BR-8.7 требует пересчёта по попыткам — это поведение, не структура. На уровне FOOD-101 DEFAULT обеспечивает валидное начальное состояние; пересчёт при изменении payment — задача приложения (отдельного тикета на триггер в бэклоге нет) |
| review      | review_timestamp | DEFAULT LOCALTIMESTAMP          | BR-9.3: дата отзыва фиксируется при создании; BR-11.2                                                                                                                                                                                                                           |
| courier_pay | coefficient_used | DEFAULT 0.1                     | BR-6.5: страховка, если процедура не передала коэффициент                                                                                                                                                                                                                       |

`commission` и `total_amount` - обычные поля с `CHECK`, потому что BR-7.10 говорит «у заказа есть сумма без комиссии, комиссия, общая сумма» - это атрибуты, а не вычисляемые поля. GENERATED усложнил бы insert_test_data (нельзя вставить явное значение); CHECK-а достаточно для гарантии формулы.

---
## Нормализация (3НФ)

В таблицах с простым ключом все неключевые атрибуты зависят от этого первичного ключа. В таблицах связей (например, `client_address`) атрибуты зависят от полного составного ключа. Категории, адреса, платежи, позиции и отзывы вынесены в отдельные отношения, поэтому их атрибуты не дублируются транзитивно.
В `order_structure` ресторан не повторяется: для декларативной гарантии BR-7.3 добавлен избыточный `restaurant_id`, и соответствие ресторана блюда и заказа проверяется двумя составными внешними ключами, что исключает аномалии обновления. 
`commission` и `total_amount` — это вычисляемые атрибуты, но в схеме они реализованы как **обычные поля с CHECK-ограничениями** (проверяют формулы `commission = round(order_amount * 0.10, 2)` и `total_amount = order_amount + commission`). Они зависят напрямую от `order_amount` в той же таблице, поэтому 3НФ не нарушают.
`rating` в `product`/`restaurant` и `pay_status` в `"order"` — это агрегаты, сохранённые ради контракта бэкенда и поддерживаемые триггерами (`rating_change_review` и приложением соответственно). Это документированные исключения из строгой 3НФ (осознанная денормализация).
`review.entity_type/entity_id` — полиморфная ссылка из контракта; целостность ссылок обеспечивается на уровне приложения и триггера пересчёта рейтинга, поскольку единого FK на три разные таблицы в PostgreSQL создать нельзя.