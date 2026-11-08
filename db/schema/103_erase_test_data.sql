-- FOOD-103 Удаление тестовых данных

SET search_path TO chaplygin_food, exts, public

CREATE OR REPLACE PROCEDURE erase_test_data()
LANGUAGE plpgsql AS $$
BEGIN
    TRUNCATE TABLE
        review_product, review_restaurant, review_order,
        review, payment, order_structure, pidido,
        courier_pay, product, client_address, restaurant,
        address, courier, product_category, client
    RESTART IDENTITY CASCADE;
END;
$$;

/* Проверка удаления данных в таблице
SELECT 'client' AS tbl, count(*) FROM client
UNION ALL SELECT 'courier', count(*) FROM courier
UNION ALL SELECT 'product_category', count(*) FROM product_category
UNION ALL SELECT 'restaurant', count(*) FROM restaurant
UNION ALL SELECT 'address', count(*) FROM address
UNION ALL SELECT 'product', count(*) FROM product
UNION ALL SELECT 'pidido', count(*) FROM pidido
UNION ALL SELECT 'review', count(*) FROM review
UNION ALL SELECT 'payment', count(*) FROM payment
UNION ALL SELECT 'order_structure', count(*) FROM order_structure
UNION ALL SELECT 'client_address', count(*) FROM client_address
UNION ALL SELECT 'review_product', count(*) FROM review_product
UNION ALL SELECT 'review_restaurant', count(*) FROM review_restaurant
UNION ALL SELECT 'review_order', count(*) FROM review_order
UNION ALL SELECT 'courier_pay', count(*) FROM courier_pay
ORDER BY tbl;
 */

-- CALL erase_test_data();