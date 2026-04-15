CREATE EXTENSION IF NOT EXISTS "postgis";

CREATE TABLE rated_areas (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    geometry GEOMETRY(Polygon, 4326) NOT NULL,
    value SMALLINT NOT NULL CHECK (value IN (-7, -3, -1, 1, 3, 7)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_rated_areas_user_id ON rated_areas (user_id);
CREATE INDEX idx_rated_areas_geometry ON rated_areas USING GIST (geometry);
