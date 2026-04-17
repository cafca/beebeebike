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

-- Backfill existing rated_areas as seed events so undo doesn't wipe
-- pre-migration data. Existing areas are non-overlapping by invariant,
-- so replaying them in any order via apply_paint produces the same state.
INSERT INTO paint_events (user_id, seq, geometry, value, status)
SELECT
    user_id,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY id) AS seq,
    geometry,
    value,
    0 AS status
FROM rated_areas;
