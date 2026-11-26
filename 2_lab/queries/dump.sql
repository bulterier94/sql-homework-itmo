BEGIN;

TRUNCATE TABLE
    booking,
    room_amenity,
    user_phone,
    amenity,
    room,
    app_user
RESTART IDENTITY CASCADE;

COMMIT;