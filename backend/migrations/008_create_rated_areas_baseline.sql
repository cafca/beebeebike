-- Baseline snapshot used by bounded undo/redo. For each user this holds the
-- merged effect of all paint events that have been squashed out of the undo
-- stack. `rated_areas` is derived as `rated_areas_baseline + active paint_events`.
CREATE TABLE rated_areas_baseline (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    geometry GEOMETRY(Polygon, 4326) NOT NULL,
    value SMALLINT NOT NULL CHECK (value IN (-7, -3, -1, 1, 3, 7))
);

CREATE INDEX idx_rated_areas_baseline_user_id ON rated_areas_baseline (user_id);
CREATE INDEX idx_rated_areas_baseline_geometry ON rated_areas_baseline USING GIST (geometry);
