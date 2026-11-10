-- FOOD-101 Индексы

-- Заказы ресторана
CREATE INDEX idx_order_restaurant
ON chaplygin_food."order"(restaurant_id);

-- Заказы курьера
CREATE INDEX idx_order_courier
ON chaplygin_food."order"(courier_id);

-- Доставленные заказы
CREATE INDEX idx_order_status
ON chaplygin_food."order"(status);

-- BR-8.1 Не более одной успешной попытки на заказ
CREATE UNIQUE INDEX unique_payment_one_success
    ON chaplygin_food.payment(order_id)
    WHERE status = 'успех';