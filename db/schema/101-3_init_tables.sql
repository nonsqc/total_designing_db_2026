-- FOOD-101 Таблицы

SET search_path TO chaplygin_food, exts, public


--BR-2.* Клиенты
CREATE TABLE client (
    client_id UUID PRIMARY KEY
        DEFAULT exts.uuid_generate_v4(),
    login VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(32) NOT NULL,
    phone_number CHAR(12) NOT NULL UNIQUE,    
    CONSTRAINT chk_client_login
        CHECK (LENGTH(trim(login)) > 0),        
    CONSTRAINT chk_client_password
        CHECK (password ~ '^[a-f0-9]{32}$'),        
    CONSTRAINT chk_client_phone
        CHECK (phone_number ~ '^\+7[0-9]{10}$'));

--BR-3.* Адреса
CREATE TABLE address (
    address_id UUID PRIMARY KEY
        DEFAULT exts.uuid_generate_v4(),
    street VARCHAR(100) NOT NULL,
    house_number VARCHAR(20) NOT NULL,
    apartment_office VARCHAR(20),
    CONSTRAINT chk_address_street
        CHECK (LENGTH(trim(street)) > 0),
    CONSTRAINT chk_address_house
        CHECK (LENGTH(trim(house_number)) > 0),
    CONSTRAINT chk_address_apartment
        CHECK (
            apartment_office IS NULL
            OR LENGTH(trim(apartment_office)) > 0));

--BR-3.4 Клиент-адрес
CREATE TABLE client_address (
    client_id UUID NOT NULL,
    address_id UUID NOT NULL,
    CONSTRAINT pk_client_address
        PRIMARY KEY (client_id, address_id),
    CONSTRAINT fk_client_address_client
        FOREIGN KEY (client_id)
        REFERENCES client(client_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_client_address_address
        FOREIGN KEY (address_id)
        REFERENCES address(address_id)
        ON DELETE RESTRICT);

--BR-4.* Рестораны
CREATE TABLE restaurant (
    restaurant_id UUID PRIMARY KEY
        DEFAULT exts.uuid_generate_v4(),
    restaurant_name VARCHAR(100) NOT NULL,
    address_id UUID NOT NULL UNIQUE,
    description TEXT NOT NULL,
    work_start TIME NOT NULL,
    work_end TIME NOT NULL,
    company_details TEXT NOT NULL,
    rating NUMERIC(3,2) DEFAULT NULL,
    status restaurant_status NOT NULL,
    CONSTRAINT fk_restaurant_address
        FOREIGN KEY (address_id)
        REFERENCES address(address_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_restaurant_rating
        CHECK (rating IS NULL OR rating BETWEEN 0 AND 5),
    CONSTRAINT chk_restaurant_work_time
        CHECK (work_end > work_start),
    CONSTRAINT chk_restaurant_name
        CHECK (LENGTH(trim(restaurant_name)) > 0),
    CONSTRAINT chk_restaurant_description
        CHECK (LENGTH(trim(description)) > 0),
    CONSTRAINT chk_restaurant_details
        CHECK (LENGTH(trim(company_details)) > 0));

--BR-5.7 Категория блюда
CREATE TABLE product_category (
    product_category_id UUID PRIMARY KEY
        DEFAULT exts.uuid_generate_v4(),
    product_category_name VARCHAR(100) NOT NULL UNIQUE,
    CONSTRAINT chk_category_name
        CHECK (LENGTH(trim(product_category_name)) > 0));

--BR-5.* Меню
CREATE TABLE product (
    product_id UUID PRIMARY KEY
        DEFAULT exts.uuid_generate_v4(),
    product_name VARCHAR(100) NOT NULL,
    product_category_id UUID NOT NULL,
    price NUMERIC(12,2) NOT NULL,
    restaurant_id UUID NOT NULL,
    photo_url TEXT,
    rating NUMERIC(3,2) DEFAULT NULL,
    status product_status NOT NULL,
    description TEXT NOT NULL,
    CONSTRAINT fk_product_category
        FOREIGN KEY (product_category_id)
        REFERENCES product_category(product_category_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_product_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(restaurant_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_product_price
        CHECK (price >= 0),
    CONSTRAINT chk_product_rating
        CHECK (rating IS NULL OR rating BETWEEN 0 AND 5),
    CONSTRAINT chk_product_name
        CHECK (LENGTH(trim(product_name)) > 0),
    CONSTRAINT uq_product_restaurant
        UNIQUE (product_id, restaurant_id));

--BR-6.* Курьеры
CREATE TABLE courier (
    courier_id UUID PRIMARY KEY
        DEFAULT exts.uuid_generate_v4(),
    fio VARCHAR(150) NOT NULL,
    phone_number CHAR(12) NOT NULL UNIQUE,
    status courier_status NOT NULL,
    hire_date DATE NOT NULL,
    dismissal_date DATE,
    coefficient NUMERIC(2,1) NOT NULL DEFAULT 0.1,
    CONSTRAINT chk_courier_coefficient
        CHECK (coefficient BETWEEN 0.1 AND 0.5),
    CONSTRAINT chk_courier_dismissal
        CHECK (
            (status = 'уволен' AND dismissal_date IS NOT NULL)
            OR
            (status <> 'уволен' AND dismissal_date IS NULL)),
    CONSTRAINT chk_courier_diss_hire_dates
        CHECK (
            dismissal_date IS NULL
            OR dismissal_date >= hire_date),
    CONSTRAINT chk_courier_fio
        CHECK (LENGTH(trim(fio)) > 0),
    CONSTRAINT chk_courier_phone
        CHECK (phone_number ~ '^\+7[0-9]{10}$'));

--BR-7.* Заказы
CREATE TABLE pidido (
    order_id UUID PRIMARY KEY
        DEFAULT exts.uuid_generate_v4(),
    courier_id UUID NOT NULL,
    client_id UUID NOT NULL,
    address_id UUID NOT NULL,
    restaurant_id UUID NOT NULL,
    order_timestamp TIMESTAMP NOT NULL
        DEFAULT LOCALTIMESTAMP,
    delivery_timestamp TIMESTAMP,
    order_amount NUMERIC(12,2) NOT NULL,
    commission NUMERIC(12,2) NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL,
    status order_status NOT NULL,
    pay_status order_pay_status NOT NULL DEFAULT 'ожидает',
    description TEXT,
    CONSTRAINT fk_order_courier
        FOREIGN KEY (courier_id)
        REFERENCES courier(courier_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_order_client
        FOREIGN KEY (client_id)
        REFERENCES client(client_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_order_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(restaurant_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_order_address
        FOREIGN KEY (client_id, address_id)
        REFERENCES client_address(client_id, address_id)
        ON DELETE RESTRICT,
    CONSTRAINT uq_sum_order
        UNIQUE (order_id, total_amount),
    CONSTRAINT chk_order_commission
        CHECK (commission = round(order_amount * 0.10, 2)),
    CONSTRAINT chk_order_total
        CHECK (total_amount = order_amount + commission),
    CONSTRAINT chk_order_minimum
        CHECK (total_amount >= 1000),
    CONSTRAINT chk_order_delivery_time
        CHECK (
            delivery_timestamp IS NULL
            OR delivery_timestamp >= order_timestamp),
    CONSTRAINT chk_order_delivery_status
        CHECK (
            (status = 'доставлен' AND delivery_timestamp IS NOT NULL)
            OR
            (status <> 'доставлен')),
    CONSTRAINT uq_order_restaurant
        UNIQUE (order_id, restaurant_id));

--BR-7.14-7.16 Структура заказа
CREATE TABLE order_structure (
    order_id UUID NOT NULL,
    product_id UUID NOT NULL,
    restaurant_id UUID NOT NULL, -- денормализация
    quantity NUMERIC(10,3) NOT NULL,
    CONSTRAINT pk_order_structure
        PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_structure_order
        FOREIGN KEY (order_id, restaurant_id)
        REFERENCES pidido(order_id, restaurant_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_structure_product
        FOREIGN KEY (product_id, restaurant_id)
        REFERENCES product(product_id, restaurant_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_order_quantity
        CHECK (quantity > 0));

--BR-8.* Оплаты
CREATE TABLE payment (
    payment_id UUID PRIMARY KEY
        DEFAULT exts.uuid_generate_v4(),
    order_id UUID NOT NULL,
    payment_type payment_type NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    transaction_id VARCHAR(255) NOT NULL UNIQUE,
    transaction_timestamp TIMESTAMP NOT NULL,
    status payment_status NOT NULL,
    CONSTRAINT fk_payment_order
        FOREIGN KEY (order_id)
        REFERENCES pidido(order_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_payment_amount
        FOREIGN KEY (order_id, amount)
        REFERENCES pidido(order_id, total_amount)
        ON DELETE RESTRICT);

--BR-9.* Отзывы (с нормализацией без полиморфизма)
CREATE TABLE review (
    review_id UUID PRIMARY KEY
        DEFAULT exts.uuid_generate_v4(),
    client_id UUID NOT NULL,
    order_id UUID NOT NULL,
    review_timestamp TIMESTAMP NOT NULL
        DEFAULT LOCALTIMESTAMP,
    description TEXT NOT NULL,
    photo_url TEXT,
    rating NUMERIC(2,1) NOT NULL,
    CONSTRAINT fk_review_client
        FOREIGN KEY (client_id)
        REFERENCES client(client_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_review_order
        FOREIGN KEY (order_id)
        REFERENCES pidido(order_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_review_rating
        CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT chk_review_description
        CHECK (LENGTH(trim(description)) > 0));

-- Отзывы на блюдо
CREATE TABLE review_product (
    review_id UUID PRIMARY KEY,
    order_id UUID NOT NULL,
    product_id UUID NOT NULL,
    CONSTRAINT fk_review_product_review
        FOREIGN KEY (review_id)
        REFERENCES review(review_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_review_product_order
        FOREIGN KEY (order_id)
        REFERENCES pidido(order_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_review_product_product
        FOREIGN KEY (product_id)
        REFERENCES product(product_id)
        ON DELETE RESTRICT,
    CONSTRAINT uq_review_product
        UNIQUE (order_id, product_id));

-- Отзывы на ресторан
CREATE TABLE review_restaurant (
    review_id UUID PRIMARY KEY,
    order_id UUID NOT NULL,
    restaurant_id UUID NOT NULL,
    CONSTRAINT fk_review_restaurant_review
        FOREIGN KEY (review_id)
        REFERENCES review(review_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_review_restaurant_order
        FOREIGN KEY (order_id)
        REFERENCES pidido(order_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_review_restaurant_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(restaurant_id)
        ON DELETE RESTRICT,
    CONSTRAINT uq_review_restaurant
        UNIQUE (order_id, restaurant_id));

-- Отзывы на заказ
CREATE TABLE review_order (
    review_id UUID PRIMARY KEY,
    order_id UUID NOT NULL UNIQUE,
    CONSTRAINT fk_review_order_review
        FOREIGN KEY (review_id)
        REFERENCES review(review_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_review_order_order
        FOREIGN KEY (order_id)
        REFERENCES pidido(order_id)
        ON DELETE RESTRICT);

--BR-10.* Зарплата курьеров
CREATE TABLE courier_pay (
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    courier_id UUID NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    coefficient_used NUMERIC(2,1) NOT NULL DEFAULT 0.1,
    CONSTRAINT pk_courier_pay
        PRIMARY KEY (year, month, courier_id),
    CONSTRAINT fk_courier_pay_courier
        FOREIGN KEY (courier_id)
        REFERENCES courier(courier_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_courier_pay_month
        CHECK (month BETWEEN 1 AND 12),
    CONSTRAINT chk_courier_pay_year
        CHECK (year BETWEEN 2020 AND 2100),
    CONSTRAINT chk_courier_pay_amount
        CHECK (amount >= 0),
    CONSTRAINT chk_courier_pay_coefficient
        CHECK (coefficient_used BETWEEN 0.1 AND 0.5));