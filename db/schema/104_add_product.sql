-- FOOD-104 Добавление блюда

SET search_path TO chaplygin_food, exts, public

CREATE OR REPLACE PROCEDURE add_product(
    p_product_name        VARCHAR(100),
    p_product_category_id UUID,
    p_price               NUMERIC(12,2),
    p_restaurant_id       UUID,
    p_photo_url           TEXT DEFAULT NULL,
    p_rating              NUMERIC(3,2) DEFAULT NULL,
    p_status              product_status DEFAULT 'доступно',
    p_description         TEXT DEFAULT ''
)
LANGUAGE plpgsql AS $$
BEGIN
    -- BR-5.1: проверка ресторана
    IF NOT EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = p_restaurant_id) THEN
        RAISE EXCEPTION 'Ресторан с id % не существует (BR-5.1)', p_restaurant_id;
    END IF;

    -- BR-5.1: проверка категории
    IF NOT EXISTS (SELECT 1 FROM product_category WHERE product_category_id = p_product_category_id) THEN
        RAISE EXCEPTION 'Категория с id % не существует (BR-5.1)', p_product_category_id;
    END IF;
    
    INSERT INTO product (
        product_id, product_name, product_category_id,
        price, restaurant_id, photo_url, rating, status, description
    )
    VALUES (
        exts.uuid_generate_v4(),
        p_product_name,
        p_product_category_id,
        p_price,
        p_restaurant_id,
        p_photo_url,
        p_rating,
        p_status,
        p_description
    );
END;
$$;
