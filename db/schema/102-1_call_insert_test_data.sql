-- FOOD-102 Вызов процедуры генератора тестовых данных

-- CALL insert_test_data(10);

/* Проверка добавления данных в таблице
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