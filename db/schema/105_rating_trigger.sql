-- FOOD-105 Триггер пересчёта рейтинга

SET search_path TO chaplygin_food, exts, public

-- 1. Функции
CREATE OR REPLACE FUNCTION rating_change_product()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_old_product_id UUID := OLD.product_id;
    v_new_product_id UUID := NEW.product_id;
    v_target_product_id UUID;
BEGIN
    IF TG_OP = 'UPDATE' AND v_old_product_id <> v_new_product_id THEN
        UPDATE product p SET rating = (
            SELECT round(avg(r.rating), 2)
            FROM review_product rp
            JOIN review r ON r.review_id = rp.review_id
            WHERE rp.product_id = v_old_product_id
        ) WHERE p.product_id = v_old_product_id;
    END IF;

    v_target_product_id := COALESCE(NEW.product_id, OLD.product_id);

    UPDATE product p SET rating = (
        SELECT round(avg(r.rating), 2)
        FROM review_product rp
        JOIN review r ON r.review_id = rp.review_id
        WHERE rp.product_id = v_target_product_id
    ) WHERE p.product_id = v_target_product_id;

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE OR REPLACE FUNCTION rating_change_restaurant()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_old_restaurant_id UUID := OLD.restaurant_id;
    v_new_restaurant_id UUID := NEW.restaurant_id;
    v_target_restaurant_id UUID;
BEGIN
    IF TG_OP = 'UPDATE' AND v_old_restaurant_id <> v_new_restaurant_id THEN
        UPDATE restaurant r SET rating = (
            SELECT round(avg(rv.rating), 2)
            FROM review_restaurant rr
            JOIN review rv ON rv.review_id = rr.review_id
            WHERE rr.restaurant_id = v_old_restaurant_id
        ) WHERE r.restaurant_id = v_old_restaurant_id;
    END IF;

    v_target_restaurant_id := COALESCE(NEW.restaurant_id, OLD.restaurant_id);

    UPDATE restaurant r SET rating = (
        SELECT round(avg(rv.rating), 2)
        FROM review_restaurant rr
        JOIN review rv ON rv.review_id = rr.review_id
        WHERE rr.restaurant_id = v_target_restaurant_id
    ) WHERE r.restaurant_id = v_target_restaurant_id;

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE OR REPLACE FUNCTION rating_change_review()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE product p SET rating = (
        SELECT round(avg(r.rating), 2)
        FROM review_product rp
        JOIN review r ON r.review_id = rp.review_id
        WHERE rp.product_id = p.product_id
    ) WHERE p.product_id IN (
        SELECT product_id FROM review_product WHERE review_id = NEW.review_id
    );

    UPDATE restaurant r SET rating = (
        SELECT round(avg(rv.rating), 2)
        FROM review_restaurant rr
        JOIN review rv ON rv.review_id = rr.review_id
        WHERE rr.restaurant_id = r.restaurant_id
    ) WHERE r.restaurant_id IN (
        SELECT restaurant_id FROM review_restaurant WHERE review_id = NEW.review_id
    );

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION rating_change_order()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- 2. Триггеры
DROP TRIGGER IF EXISTS trg_rating_change_product ON review_product;
CREATE TRIGGER trg_rating_change_product
    AFTER INSERT OR UPDATE OR DELETE ON review_product
    FOR EACH ROW EXECUTE FUNCTION rating_change_product();

DROP TRIGGER IF EXISTS trg_rating_change_restaurant ON review_restaurant;
CREATE TRIGGER trg_rating_change_restaurant
    AFTER INSERT OR UPDATE OR DELETE ON review_restaurant
    FOR EACH ROW EXECUTE FUNCTION rating_change_restaurant();

DROP TRIGGER IF EXISTS trg_rating_change_review ON review;
CREATE TRIGGER trg_rating_change_review
    AFTER UPDATE OF rating ON review
    FOR EACH ROW EXECUTE FUNCTION rating_change_review();

DROP TRIGGER IF EXISTS trg_rating_change_order ON review_order;
CREATE TRIGGER trg_rating_change_order
    AFTER INSERT OR UPDATE OR DELETE ON review_order
    FOR EACH ROW EXECUTE FUNCTION rating_change_order();