CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE app_user (
    user_id BIGSERIAL PRIMARY KEY,
    email TEXT NOT NULL UNIQUE CHECK (position('@' IN email) > 1),
    full_name TEXT NOT NULL CHECK (length(trim(full_name)) > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE room (
    room_id BIGSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    capacity INTEGER NOT NULL CHECK (capacity > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE booking (
    booking_id BIGSERIAL PRIMARY KEY,
    room_id BIGINT NOT NULL REFERENCES room(room_id) ON DELETE RESTRICT,
    user_id BIGINT NOT NULL REFERENCES app_user(user_id) ON DELETE RESTRICT,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'confirmed', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT booking_valid_interval CHECK (end_at > start_at),
    CONSTRAINT booking_no_active_overlap
        EXCLUDE USING gist (
            room_id WITH =,
            tstzrange(start_at, end_at, '[)') WITH &&
        )
        WHERE (status IN ('pending', 'confirmed'))
);

CREATE INDEX booking_user_id_idx ON booking(user_id);
CREATE INDEX booking_room_time_idx ON booking(room_id, start_at, end_at);
