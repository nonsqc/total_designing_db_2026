-- FOOD-101 Индексы

SET search_path TO chaplygin_food, exts, public;

-- Поиск блюд ресторана
CREATE INDEX idx_product_restaurant
ON product(restaurant_id);

-- Поиск блюд по категориям
CREATE INDEX idx_product_category
ON product(product_category_id);

-- Заказы клиента
CREATE INDEX idx_order_client
ON pidido(client_id);

-- Заказы ресторана
CREATE INDEX idx_order_restaurant
ON pidido(restaurant_id);

-- Заказы курьера
CREATE INDEX idx_order_courier
ON pidido(courier_id);

-- Доставленные заказы
CREATE INDEX idx_order_status
ON pidido(status);

-- Платежи заказа
CREATE INDEX idx_payment_order
ON payment(order_id);

-- Не более одной успешной попытки на заказ
CREATE UNIQUE INDEX unique_payment_one_success
    ON payment(order_id)
    WHERE status = 'успех';

-- Отзывы по объекту
CREATE INDEX idx_review_product
ON review_product(product_id);

CREATE INDEX idx_review_restaurant
ON review_restaurant(restaurant_id);

CREATE INDEX idx_review_order
ON review_order(order_id);

CREATE INDEX idx_review_client
ON review(client_id);

-- Выплаты курьеров
CREATE INDEX idx_courier_pay_courier
ON courier_pay(courier_id);