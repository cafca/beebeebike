CREATE TABLE user_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    label TEXT NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT user_locations_name_not_blank CHECK (length(trim(name)) > 0),
    CONSTRAINT user_locations_label_not_blank CHECK (length(trim(label)) > 0),
    CONSTRAINT user_locations_longitude_range CHECK (longitude >= -180 AND longitude <= 180),
    CONSTRAINT user_locations_latitude_range CHECK (latitude >= -90 AND latitude <= 90)
);

CREATE UNIQUE INDEX idx_user_locations_user_name ON user_locations (user_id, name);
CREATE INDEX idx_user_locations_user_id ON user_locations (user_id);
