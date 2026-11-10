-- FOOD-103 Удаление тестовых данных

CREATE OR REPLACE PROCEDURE chaplygin_food.erase_test_data()
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM chaplygin_food.review;
    DELETE FROM chaplygin_food.payment;
    DELETE FROM chaplygin_food.order_structure;
    DELETE FROM chaplygin_food.courier_pay;
    DELETE FROM chaplygin_food."order";
    DELETE FROM chaplygin_food.client_address;
    DELETE FROM chaplygin_food.product;
    DELETE FROM chaplygin_food.restaurant;
    DELETE FROM chaplygin_food.client;
    DELETE FROM chaplygin_food.courier;
    DELETE FROM chaplygin_food.product_category;
    DELETE FROM chaplygin_food.address;
END;
$$;

/* Проверка удаления данных в таблице
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
UNION ALL SELECT 'courier_pay', count(*) FROM courier_pay
ORDER BY tbl;
 */

-- CALL erase_test_data();