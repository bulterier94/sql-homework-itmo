-- Проверки ограничений целостности для PostgreSQL
-- Запускать надо после schema.sql
-- docker exec -i course_db psql -v ON_ERROR_STOP=1 -U app -d coworking < queries/02_constraints.sql
-- Негативные тесты ловят ожидаемые ошибки внутри DO-блоков
-- Если ограничение не сработало, тест выдаст собственную ошибку

BEGIN;
TRUNCATE room_amenity, user_phone, booking, amenity, room, app_user RESTART IDENTITY CASCADE;

-- Вставка контактных данных, должно все выполниться
INSERT INTO app_user (email, full_name)
VALUES ('alice@example.com', 'Alice Example'), ('bob@example.com', 'Bob Example');
INSERT INTO room (code, name, capacity)
VALUES ('HALL-1', 'Большой зал', 20), ('ROOM-1', 'Переговорная 1', 6);
UPDATE room SET parent_room_id = (SELECT room_id FROM room WHERE code = 'HALL-1')
WHERE code = 'ROOM-1';
INSERT INTO amenity (name, description)
VALUES ('Проектор', 'Для презентаций'), ('Доска', 'Маркерная доска');
INSERT INTO room_amenity (room_id, amenity_id, quantity)
SELECT r.room_id, a.amenity_id, 1 FROM room r CROSS JOIN amenity a
WHERE r.code = 'ROOM-1' AND a.name = 'Проектор';
INSERT INTO user_phone (user_id, phone)
SELECT user_id, '+358401234567' FROM app_user WHERE email = 'alice@example.com';
INSERT INTO booking (room_id, user_id, start_at, end_at)
SELECT r.room_id, u.user_id, TIMESTAMPTZ '2026-12-01 10:00:00+02',
       TIMESTAMPTZ '2026-12-01 11:00:00+02'
FROM room r CROSS JOIN app_user u
WHERE r.code = 'ROOM-1' AND u.email = 'alice@example.com';

-- status должен автоматически стать confirmed
DO $$
BEGIN
    IF (SELECT status FROM booking LIMIT 1) <> 'confirmed' THEN
        RAISE EXCEPTION 'DEFAULT для booking.status не сработал';
    END IF;
    RAISE NOTICE 'OK: DEFAULT booking.status';
END $$;

-- email обязателен. Должен выдать not_null_violation (not_null)
DO $$
BEGIN
    BEGIN
        INSERT INTO app_user (email, full_name) VALUES (NULL, 'No Email');
        RAISE EXCEPTION 'NOT NULL app_user.email не сработал';
    EXCEPTION WHEN not_null_violation THEN
        RAISE NOTICE 'OK: ожидаемая ошибка NOT NULL app_user.email';
    END;
END $$;

-- email не должен повторяться (unique)
DO $$
BEGIN
    BEGIN
        INSERT INTO app_user (email, full_name) VALUES ('alice@example.com', 'Duplicate');
        RAISE EXCEPTION 'UNIQUE app_user.email не сработал';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'OK: ожидаемая ошибка UNIQUE app_user.email';
    END;
END $$;

-- capacity > 0. Должен выдать check_violation
DO $$
BEGIN
    BEGIN
        INSERT INTO room (code, name, capacity) VALUES ('BAD-ROOM', 'Плохая комната', 0);
        RAISE EXCEPTION 'CHECK capacity > 0 не сработал';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: ожидаемая ошибка CHECK capacity > 0';
    END;
END $$;

-- end_at > start_at. Должен выдать check_violation
DO $$
BEGIN
    BEGIN
        INSERT INTO booking (room_id, user_id, start_at, end_at)
        SELECT r.room_id, u.user_id, TIMESTAMPTZ '2026-12-02 12:00:00+02',
               TIMESTAMPTZ '2026-12-02 11:00:00+02'
        FROM room r CROSS JOIN app_user u
        WHERE r.code = 'ROOM-1' AND u.email = 'alice@example.com';
        RAISE EXCEPTION 'CHECK booking time не сработал';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: ожидаемая ошибка CHECK booking time';
    END;
END $$;

-- отсутствующая комната недопустима (нет fk)
DO $$
BEGIN
    BEGIN
        INSERT INTO booking (room_id, user_id, start_at, end_at)
        SELECT -999, user_id, TIMESTAMPTZ '2026-12-03 10:00:00+02',
               TIMESTAMPTZ '2026-12-03 11:00:00+02'
        FROM app_user WHERE email = 'alice@example.com';
        RAISE EXCEPTION 'FOREIGN KEY booking.room_id не сработал';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'OK: ожидаемая ошибка FOREIGN KEY booking.room_id';
    END;
END $$;

-- room_amenity запрещает дублировать пару (дублирование pk)
DO $$
BEGIN
    BEGIN
        INSERT INTO room_amenity (room_id, amenity_id)
        SELECT r.room_id, a.amenity_id FROM room r CROSS JOIN amenity a
        WHERE r.code = 'ROOM-1' AND a.name = 'Проектор';
        RAISE EXCEPTION 'PRIMARY KEY room_amenity не сработал';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'OK: ожидаемая ошибка составного PRIMARY KEY room_amenity';
    END;
END $$;

-- значение quantity должно быть положительно
DO $$
BEGIN
    BEGIN
        INSERT INTO room_amenity (room_id, amenity_id, quantity)
        SELECT r.room_id, a.amenity_id, 0 FROM room r CROSS JOIN amenity a
        WHERE r.code = 'ROOM-1' AND a.name = 'Доска';
        RAISE EXCEPTION 'CHECK room_amenity.quantity не сработал';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: ожидаемая ошибка CHECK room_amenity.quantity';
    END;
END $$;

-- активные брони одной комнаты не могут пересекаться
DO $$
BEGIN
    BEGIN
        INSERT INTO booking (room_id, user_id, start_at, end_at, status)
        SELECT r.room_id, u.user_id, TIMESTAMPTZ '2026-12-01 10:30:00+02',
               TIMESTAMPTZ '2026-12-01 11:30:00+02', 'confirmed'
        FROM room r CROSS JOIN app_user u
        WHERE r.code = 'ROOM-1' AND u.email = 'bob@example.com';
        RAISE EXCEPTION 'EXCLUSION пересечения броней не сработал';
    EXCEPTION WHEN exclusion_violation THEN
        RAISE NOTICE 'OK: ожидаемая ошибка EXCLUSION пересечения броней';
    END;
END $$;

-- бронь с 11:00 допустима, если предыдущая заканчивается в 11:00
INSERT INTO booking (room_id, user_id, start_at, end_at)
SELECT r.room_id, u.user_id, TIMESTAMPTZ '2026-12-01 11:00:00+02',
       TIMESTAMPTZ '2026-12-01 12:00:00+02'
FROM room r CROSS JOIN app_user u
WHERE r.code = 'ROOM-1' AND u.email = 'bob@example.com';

-- нельзя удалить пользователя с историей бронирований (ON DELETE RESTRICT)
DO $$
BEGIN
    BEGIN
        DELETE FROM app_user WHERE email = 'alice@example.com';
        RAISE EXCEPTION 'ON DELETE RESTRICT booking.user_id не сработал';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'OK: ожидаемая ошибка ON DELETE RESTRICT пользователя с бронью';
    END;
END $$;

-- телефоны удаляются вместе с пользователем (ON DELETE CASCADE)
INSERT INTO app_user (email, full_name) VALUES ('charlie@example.com', 'Charlie Example');
INSERT INTO user_phone (user_id, phone)
SELECT user_id, '+358409876543' FROM app_user WHERE email = 'charlie@example.com';
DELETE FROM app_user WHERE email = 'charlie@example.com';
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM user_phone WHERE phone = '+358409876543') THEN
        RAISE EXCEPTION 'ON DELETE CASCADE user_phone не сработал';
    END IF;
    RAISE NOTICE 'OK: ON DELETE CASCADE user_phone';
END $$;

SELECT 'app_user' AS entity, count(*) AS rows_count FROM app_user
UNION ALL SELECT 'room', count(*) FROM room
UNION ALL SELECT 'booking', count(*) FROM booking
UNION ALL SELECT 'amenity', count(*) FROM amenity
UNION ALL SELECT 'room_amenity', count(*) FROM room_amenity
UNION ALL SELECT 'user_phone', count(*) FROM user_phone;

ROLLBACK;
