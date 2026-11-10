-- FOOD-101 Создание перечисляемых типов и статусов 

-- 1. Статус ресторана (BR-4.3)
CREATE TYPE chaplygin_food.restaurant_status AS ENUM (
    'активен',
    'неактивен')

-- 2. Статус блюда (BR-5.5)
CREATE TYPE chaplygin_food.product_status AS ENUM (
    'доступно',
    'нет_в_наличии',
    'архив')

-- 3. Статус курьера (BR-6.2)
CREATE TYPE chaplygin_food.courier_status AS ENUM (
    'свободен',
    'занят',
    'на_доставке',
    'уволен')

-- 4. Статус заказа (BR-7.7)
CREATE TYPE chaplygin_food.order_status AS ENUM (
    'создан',
    'готовится',
    'в_доставке',
    'доставлен',
    'отменён')

-- 5. Статус оплаты заказа (BR-7.9)
CREATE TYPE chaplygin_food.order_pay_status AS ENUM (
    'ожидает',
    'оплачен',
    'ошибка')

-- 6. Тип оплаты (BR-8.2)
CREATE TYPE chaplygin_food.payment_type AS ENUM (
    'карта',
    'наличные',
    'безнал')

-- 7. Статус платежа (BR-8.2)
CREATE TYPE chaplygin_food.payment_status AS ENUM (
    'успех',
    'ошибка',
    'в_обработке')

-- 8. Тип сущности отзыва (BR-9.1)
CREATE TYPE chaplygin_food.review_entity_type AS ENUM (
    'блюдо',
    'ресторан',
    'заказ')