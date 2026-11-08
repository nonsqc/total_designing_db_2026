-- FOOD-101 Создание перечисляемых типов и статусов 

SET search_path TO chaplygin_food, exts, public -- временно задать таблицу по умолчанию

-- 1. Статус ресторана (BR-4.3)
CREATE TYPE restaurant_status AS ENUM (
    'активен',
    'неактивен')

-- 2. Статус блюда (BR-5.5)
CREATE TYPE product_status AS ENUM (
    'доступно',
    'нет_в_наличии',
    'архив')

-- 3. Статус курьера (BR-6.2)
CREATE TYPE courier_status AS ENUM (
    'свободен',
    'занят',
    'на_доставке',
    'уволен')

-- 4. Статус заказа (BR-7.7)
CREATE TYPE order_status AS ENUM (
    'создан',
    'готовится',
    'в_доставке',
    'доставлен',
    'отменён')

-- 5. Статус оплаты заказа (BR-7.9)
CREATE TYPE order_pay_status AS ENUM (
    'ожидает',
    'оплачен',
    'ошибка')

-- 6. Тип оплаты (BR-8.2)
CREATE TYPE payment_type AS ENUM (
    'карта',
    'наличные',
    'безнал')

-- 7. Статус платежа (BR-8.2)
CREATE TYPE payment_status AS ENUM (
    'успех',
    'ошибка',
    'в_обработке')

-- 8. Тип сущности отзыва (BR-9.1)
CREATE TYPE review_entity_type AS ENUM (
    'блюдо',
    'ресторан',
    'заказ')