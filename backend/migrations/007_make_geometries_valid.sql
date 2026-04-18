-- Repair invalid geometries stored by earlier versions that inserted polygons
-- without validation. GEOS rejects self-intersecting inputs in ST_Difference,
-- which breaks undo's rebuild (via replaying paint_events).

-- rated_areas: replace each invalid row with its dumped valid polygon(s).
WITH bad AS (
    SELECT id, user_id, value,
           (ST_Dump(ST_CollectionExtract(ST_MakeValid(geometry), 3))).geom AS g
    FROM rated_areas
    WHERE NOT ST_IsValid(geometry)
),
ins AS (
    INSERT INTO rated_areas (user_id, geometry, value)
    SELECT user_id, g, value FROM bad
    WHERE g IS NOT NULL AND NOT ST_IsEmpty(g) AND ST_Area(g) > 0
    RETURNING 1
)
DELETE FROM rated_areas
WHERE id IN (SELECT id FROM bad);

-- paint_events: update in place to preserve id/seq/status/created_at.
-- If MakeValid yields multiple polygons, pick the largest by area.
UPDATE paint_events
SET geometry = (
    SELECT geom
    FROM (
        SELECT (ST_Dump(ST_CollectionExtract(ST_MakeValid(geometry), 3))).geom AS geom
    ) d
    WHERE geom IS NOT NULL AND NOT ST_IsEmpty(geom)
    ORDER BY ST_Area(geom) DESC
    LIMIT 1
)
WHERE NOT ST_IsValid(geometry);

-- Remove events whose geometry collapsed to nothing after repair.
DELETE FROM paint_events
WHERE geometry IS NULL OR ST_IsEmpty(geometry);
