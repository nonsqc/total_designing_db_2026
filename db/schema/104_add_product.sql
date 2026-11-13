-- FOOD-104 Добавление блюда

CREATE OR REPLACE PROCEDURE chaplygin_food.add_product(
    p_restaurant_id uuid,
    p_product_category_id uuid,
    p_name varchar,
    p_price numeric,
    p_status chaplygin_food.product_status,
    p_description text,
    p_photo_url text DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO chaplygin_food.product
        (product_id, product_name, product_category_id, price, restaurant_id,
         photo_url, rating, status, description)
    VALUES
        (exts.uuid_generate_v4(), p_name, p_product_category_id, p_price,
         p_restaurant_id, p_photo_url, NULL, p_status, p_description);
END;
$$;
