-- FOOD-109 Пользователь inspector и права

-- 1. Создать пользователя
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'inspector') THEN
        CREATE ROLE inspector LOGIN PASSWORD 'NetoSQL2025';
    END IF;
END;
$$;

-- 2. search_path по умолчанию
ALTER ROLE inspector SET search_path = chaplygin_food, exts, public;

-- 3. Права на схему chaplygin_food
GRANT USAGE, CREATE ON SCHEMA chaplygin_food TO inspector;

-- 4. Права на существующие объекты
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA chaplygin_food TO inspector;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA chaplygin_food TO inspector;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA chaplygin_food TO inspector;
GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA chaplygin_food TO inspector;

-- 5. USAGE на exts (uuid_generate_v4)
GRANT USAGE ON SCHEMA exts TO inspector;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA exts TO inspector;

-- 6. USAGE на public
GRANT USAGE ON SCHEMA public TO inspector;

/*-- Права на будущие объекты (использовано в ходе проекта)
ALTER DEFAULT PRIVILEGES IN SCHEMA chaplygin_food
    GRANT ALL PRIVILEGES ON TABLES TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA chaplygin_food
    GRANT ALL PRIVILEGES ON SEQUENCES TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA chaplygin_food
    GRANT ALL PRIVILEGES ON FUNCTIONS TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA chaplygin_food
    GRANT ALL PRIVILEGES ON TYPES TO inspector;*/