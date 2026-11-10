-- FOOD-101 Таблицы

--BR-2.* Клиенты
CREATE TABLE chaplygin_food.client (
    client_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    login VARCHAR(50) NOT NULL UNIQUE CHECK (LENGTH(trim(login)) > 0),
    password VARCHAR(32) NOT NULL CHECK (password ~ '^[0-9a-f]{32}$'),
    phone_number CHAR(12) NOT NULL UNIQUE CHECK (phone_number ~ '^\+7[0-9]{10}$')    
);

--BR-3.* Адреса
CREATE TABLE chaplygin_food.address (
    address_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    street VARCHAR(100) NOT NULL CHECK (LENGTH(trim(street)) > 0),
    house_number VARCHAR(20) NOT NULL CHECK (LENGTH(trim(house_number)) > 0),
    apartment_office VARCHAR(20) CHECK (apartment_office IS NULL
							            OR LENGTH(trim(apartment_office)) > 0)
);

--BR-3.4 Клиент-адрес
CREATE TABLE chaplygin_food.client_address (
    client_id UUID NOT NULL REFERENCES chaplygin_food.client(client_id),
    address_id UUID NOT NULL REFERENCES chaplygin_food.address(address_id),
    PRIMARY KEY (client_id, address_id)
);

--BR-4.* Рестораны
CREATE TABLE chaplygin_food.restaurant (
    restaurant_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    restaurant_name VARCHAR(100) NOT NULL CHECK (LENGTH(trim(restaurant_name)) > 0),
    address_id UUID NOT NULL UNIQUE REFERENCES chaplygin_food.address(address_id),
    description TEXT NOT NULL CHECK (LENGTH(trim(description)) > 0),
    work_start TIME NOT NULL,
    work_end TIME NOT NULL,
    company_details TEXT NOT NULL CHECK (LENGTH(trim(company_details)) > 0),
    rating NUMERIC(3,2) DEFAULT NULL CHECK (rating IS NULL OR rating BETWEEN 0 AND 5),
    status chaplygin_food.restaurant_status NOT NULL,
    CHECK (work_end > work_start)
);

--BR-5.7 Категория блюда
CREATE TABLE chaplygin_food.product_category (
    product_category_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_category_name VARCHAR(100) NOT NULL UNIQUE 
    					CHECK (LENGTH(trim(product_category_name)) > 0)
);

--BR-5.* Меню
CREATE TABLE chaplygin_food.product (
    product_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_name VARCHAR(100) NOT NULL CHECK (LENGTH(trim(product_name)) > 0),
    product_category_id UUID NOT NULL REFERENCES chaplygin_food.product_category(product_category_id),
    price NUMERIC(7,2) NOT NULL CHECK (price >= 0),
    restaurant_id UUID NOT NULL REFERENCES chaplygin_food.restaurant(restaurant_id),
    photo_url TEXT,
    rating NUMERIC(3,2) DEFAULT NULL CHECK (rating IS NULL OR rating BETWEEN 0 AND 5),
    status chaplygin_food.product_status NOT NULL,
    description TEXT NOT NULL CHECK (LENGTH(trim(description)) > 0),
    UNIQUE (product_id, restaurant_id)
);

--BR-6.* Курьеры
CREATE TABLE chaplygin_food.courier (
    courier_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    fio VARCHAR(150) NOT NULL CHECK (LENGTH(trim(fio)) > 0),
    phone_number CHAR(12) NOT NULL UNIQUE CHECK (phone_number ~ '^\+7[0-9]{10}$'),
    status chaplygin_food.courier_status NOT NULL CHECK ((status = 'уволен' AND dismissal_date IS NOT NULL)
       													OR (status <> 'уволен' AND dismissal_date IS NULL)),
    hire_date DATE NOT NULL,
    dismissal_date DATE CHECK (dismissal_date IS NULL OR dismissal_date >= hire_date),
    coefficient NUMERIC(2,1) NOT NULL DEFAULT 0.1 CHECK (coefficient BETWEEN 0.1 AND 0.5)
);

--BR-7.* Заказы
CREATE TABLE chaplygin_food."order" (
    order_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    courier_id UUID NOT NULL REFERENCES chaplygin_food.courier(courier_id),
    client_id UUID NOT NULL REFERENCES chaplygin_food.client(client_id),
    address_id UUID NOT NULL REFERENCES chaplygin_food.address(address_id),
    restaurant_id UUID NOT NULL REFERENCES chaplygin_food.restaurant(restaurant_id),
    order_timestamp TIMESTAMP NOT NULL DEFAULT LOCALTIMESTAMP,
    delivery_timestamp TIMESTAMP,
    order_amount NUMERIC(8,2) NOT NULL,
    commission NUMERIC(7,2) NOT NULL CHECK (commission = round(order_amount * 0.10, 2)),
    total_amount NUMERIC(8,2) NOT NULL CHECK (total_amount = order_amount + commission),
    status chaplygin_food.order_status NOT NULL DEFAULT 'создан',
    pay_status chaplygin_food.order_pay_status NOT NULL DEFAULT 'ожидает',
    description TEXT,
    FOREIGN KEY (client_id, address_id)
        REFERENCES chaplygin_food.client_address(client_id, address_id),
    CHECK (total_amount >= 1000),
    CHECK (delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp),
    CHECK ((status = 'доставлен' AND delivery_timestamp IS NOT NULL)
            OR
            (status <> 'доставлен')),
    UNIQUE (order_id, client_id),
    UNIQUE (order_id, restaurant_id)
);

--BR-7.14-7.16 Структура заказа
CREATE TABLE chaplygin_food.order_structure (
    order_id UUID NOT NULL REFERENCES chaplygin_food."order"(order_id),
    product_id UUID NOT NULL REFERENCES chaplygin_food.product(product_id),
    restaurant_id UUID NOT NULL,
    quantity NUMERIC(10,3) NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id, restaurant_id)
    	REFERENCES chaplygin_food."order"(order_id, restaurant_id),
    FOREIGN KEY (product_id, restaurant_id)
    	REFERENCES chaplygin_food.product(product_id, restaurant_id)
);

--BR-8.* Оплаты
CREATE TABLE chaplygin_food.payment (
    payment_id UUID PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES chaplygin_food."order"(order_id),
    payment_type chaplygin_food.payment_type NOT NULL,
    amount NUMERIC(8,2) NOT NULL CHECK (amount >= 0),
    transaction_id VARCHAR(100) NOT NULL UNIQUE,
    transaction_timestamp TIMESTAMP NOT NULL DEFAULT LOCALTIMESTAMP,
    status chaplygin_food.payment_status NOT NULL
);

--BR-9.* Отзывы (полиморфизм)
CREATE TABLE chaplygin_food.review (
    review_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    client_id uuid NOT NULL,
    review_timestamp timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
    entity_id uuid NOT NULL,
    entity_type chaplygin_food.review_entity_type NOT NULL,
    order_id uuid NOT NULL,
    description text NOT NULL,
    photo_url text,
    rating numeric(2,1) NOT NULL CHECK (rating BETWEEN 1 AND 5),
    FOREIGN KEY (order_id, client_id)
        REFERENCES chaplygin_food."order"(order_id, client_id),
    UNIQUE (order_id, entity_type, entity_id)
);

--BR-10.* Зарплата курьеров
CREATE TABLE chaplygin_food.courier_pay (
    year INTEGER NOT NULL CHECK (year BETWEEN 2020 AND 2100),
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    courier_id UUID NOT NULL REFERENCES chaplygin_food.courier(courier_id),
    amount NUMERIC(8,2) NOT NULL CHECK (amount >= 0),
    coefficient_used NUMERIC(2,1) NOT NULL DEFAULT 0.1 CHECK (coefficient_used BETWEEN 0.1 AND 0.5),
    PRIMARY KEY (year, month, courier_id)
);