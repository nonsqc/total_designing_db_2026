-- FOOD-105 Триггер пересчёта рейтинга

SET search_path TO chaplygin_food, exts, public

-- 1. Функции
CREATE OR REPLACE FUNCTION chaplygin_food.rating_change_review()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_entity_id   UUID;
    v_entity_type chaplygin_food.review_entity_type;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_entity_id   := OLD.entity_id;
        v_entity_type := OLD.entity_type;
    ELSE
        v_entity_id   := NEW.entity_id;
        v_entity_type := NEW.entity_type;
    END IF;
    IF TG_OP = 'UPDATE' AND (OLD.entity_id <> NEW.entity_id OR OLD.entity_type <> NEW.entity_type) THEN
        IF OLD.entity_type = 'блюдо'::chaplygin_food.review_entity_type THEN
            UPDATE chaplygin_food.product p
            SET rating = (SELECT round(avg(r.rating), 2) FROM chaplygin_food.review r WHERE r.entity_id = OLD.entity_id AND r.entity_type = 'блюдо')
            WHERE p.product_id = OLD.entity_id;
        ELSIF OLD.entity_type = 'ресторан'::chaplygin_food.review_entity_type THEN
            UPDATE chaplygin_food.restaurant r
            SET rating = (SELECT round(avg(r.rating), 2) FROM chaplygin_food.review r WHERE r.entity_id = OLD.entity_id AND r.entity_type = 'ресторан')
            WHERE r.restaurant_id = OLD.entity_id;
        END IF;
    END IF;
    IF v_entity_type = 'блюдо'::chaplygin_food.review_entity_type THEN
        UPDATE chaplygin_food.product p
        SET rating = (
            SELECT round(avg(r.rating), 2)
            FROM chaplygin_food.review r
            WHERE r.entity_id = v_entity_id 
              AND r.entity_type = 'блюдо'::chaplygin_food.review_entity_type
        )
        WHERE p.product_id = v_entity_id;

    ELSIF v_entity_type = 'ресторан'::chaplygin_food.review_entity_type THEN
        UPDATE chaplygin_food.restaurant rest
        SET rating = (
            SELECT round(avg(r.rating), 2)
            FROM chaplygin_food.review r
            WHERE r.entity_id = v_entity_id 
              AND r.entity_type = 'ресторан'::chaplygin_food.review_entity_type
        )
        WHERE rest.restaurant_id = v_entity_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_rating_change_review
    AFTER INSERT OR UPDATE OR DELETE ON chaplygin_food.review
    FOR EACH ROW 
    EXECUTE FUNCTION chaplygin_food.rating_change_review();