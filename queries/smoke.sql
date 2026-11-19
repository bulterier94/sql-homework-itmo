SELECT version();

-- -- вставка данных
-- INSERT INTO room (code, capacity)
-- VALUES ('A101', 4), ('A102', 6);

-- INSERT INTO app_user (email, full_name)
-- VALUES ('a@example.com', 'Alice');

-- INSERT INTO booking (room_id, user_id, start_at, end_at, status)
-- SELECT r.room_id, u.user_id,
--        TIMESTAMPTZ '2026-12-01 10:00:00+03',
--        TIMESTAMPTZ '2026-12-01 11:00:00+03',
--        'confirmed'
-- FROM room AS r
-- CROSS JOIN app_user AS u
-- WHERE r.code = 'A101'
--   AND u.email = 'a@example.com';

-- -- чтение данных
-- SELECT * FROM room ORDER BY room_id;
-- SELECT * FROM app_user ORDER BY user_id;

-- SELECT b.booking_id, r.code AS room_code, u.email,
--        b.start_at, b.end_at, b.status
-- FROM booking AS b
-- JOIN room AS r ON r.room_id = b.room_id
-- JOIN app_user AS u ON u.user_id = b.user_id
-- ORDER BY b.booking_id;

-- негативный тест, должен выдать ошибку foreign key violation
INSERT INTO booking (room_id, user_id, start_at, end_at)
VALUES (999999, 999999,
        TIMESTAMPTZ '2026-12-02 10:00:00+03',
        TIMESTAMPTZ '2026-12-02 11:00:00+03');

-- должен выдать constraint violation, тк интервал времени пересекается

INSERT INTO booking (room_id, user_id, start_at, end_at, status)
SELECT r.room_id, u.user_id,
       TIMESTAMPTZ '2026-12-01 10:30:00+03',
       TIMESTAMPTZ '2026-12-01 11:30:00+03',
       'pending'
FROM room AS r CROSS JOIN app_user AS u
WHERE r.code = 'A101' AND u.email = 'a@example.com';
