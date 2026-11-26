
BEGIN;

-- Пользователи
INSERT INTO app_user (user_id, email, full_name) VALUES
(1, 'ivan@example.com', 'Иван Иванов'),
(2, 'petr@example.com', 'Пётр Петров'),
(3, 'anna@example.com', 'Анна Смирнова'),
(4, 'maria@example.com', 'Мария Кузнецова'),
(5, 'alex@example.com', 'Алексей Сидоров');

-- Помещения
-- Сначала создаём родительские помещения
INSERT INTO room (room_id, parent_room_id, code, name, capacity, is_active) VALUES
(1, NULL, 'OFFICE-A', 'Офисный блок A', 30, TRUE),
(2, NULL, 'OFFICE-B', 'Офисный блок B', 20, TRUE),
(3, NULL, 'MEETING-1', 'Большой конференц-зал', 15, TRUE),
(4, NULL, 'MEETING-2', 'Малый конференц-зал', 6, TRUE),
(5, 1, 'OFFICE-A-101', 'Переговорная в блоке A', 8, TRUE),
(6, 2, 'OFFICE-B-101', 'Рабочая комната в блоке B', 10, FALSE);

-- Удобства
INSERT INTO amenity (amenity_id, name, description) VALUES
(1, 'Wi-Fi', 'Беспроводной доступ в интернет'),
(2, 'Projector', 'Проектор для презентаций'),
(3, 'Whiteboard', 'Маркерная доска'),
(4, 'Coffee machine', 'Кофемашина'),
(5, 'Air conditioning', 'Кондиционер'),
(6, 'Monitor', 'Дополнительный монитор');

-- Связи помещений и удобств
INSERT INTO room_amenity (room_id, amenity_id, quantity) VALUES
(1, 1, 1),
(1, 4, 2),
(1, 5, 1),
(2, 1, 1),
(2, 6, 5),
(3, 1, 1),
(3, 2, 1),
(3, 3, 2),
(3, 5, 1),
(4, 1, 1),
(4, 3, 1),
(5, 1, 1),
(5, 2, 1),
(5, 3, 1),
(6, 1, 1),
(6, 6, 4);

-- Телефоны пользователей
INSERT INTO user_phone (user_id, phone, label) VALUES
(1, '+79990000001', 'personal'),
(1, '+79990000002', 'work'),
(2, '+79990000003', 'personal'),
(3, '+79990000004', 'work'),
(4, '+79990000005', 'personal'),
(5, '+79990000006', 'other');

-- Бронирования
-- Интервалы одной комнаты не пересекаются
INSERT INTO booking (
    booking_id, room_id, user_id, start_at, end_at, status
) VALUES
(1, 3, 1, '2026-12-01 09:00:00+03', '2026-12-01 11:00:00+03', 'confirmed'),
(2, 3, 2, '2026-12-01 11:00:00+03', '2026-12-01 13:00:00+03', 'pending'),
(3, 4, 3, '2026-12-01 10:00:00+03', '2026-12-01 12:00:00+03', 'confirmed'),
(4, 5, 4, '2026-12-02 09:00:00+03', '2026-12-02 10:30:00+03', 'completed'),
(5, 1, 5, '2026-12-02 12:00:00+03', '2026-12-02 15:00:00+03', 'cancelled'),
(6, 3, 3, '2026-12-02 09:00:00+03', '2026-12-02 12:00:00+03', 'confirmed'),
(7, 2, 1, '2026-12-03 14:00:00+03', '2026-12-03 16:00:00+03', 'pending');

-- Синхронизируем последовательности после вставки явных ID
SELECT setval(
    pg_get_serial_sequence('app_user', 'user_id'),
    (SELECT MAX(user_id) FROM app_user)
);

SELECT setval(
    pg_get_serial_sequence('room', 'room_id'),
    (SELECT MAX(room_id) FROM room)
);

SELECT setval(
    pg_get_serial_sequence('amenity', 'amenity_id'),
    (SELECT MAX(amenity_id) FROM amenity)
);

SELECT setval(
    pg_get_serial_sequence('booking', 'booking_id'),
    (SELECT MAX(booking_id) FROM booking)
);

COMMIT;
