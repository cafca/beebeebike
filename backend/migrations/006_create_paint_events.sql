CREATE TABLE paint_events (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    seq BIGINT NOT NULL,
    geometry GEOMETRY(Polygon, 4326) NOT NULL,
    value SMALLINT NOT NULL CHECK (value IN (-7, -3, -1, 0, 1, 3, 7)),
    status SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, seq)
);

CREATE INDEX idx_paint_events_user_status_seq
    ON paint_events (user_id, status, seq);
