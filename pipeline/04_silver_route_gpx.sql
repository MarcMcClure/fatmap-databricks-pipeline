-- temporary view of parsed GPX for all valid rows with GPX length 2
CREATE TEMP VIEW parsed_gpx AS
SELECT
  route_id,
  from_xml(
    concat(GPX[0], GPX[1]),
    'STRUCT<
      _creator: STRING,
      _version: DOUBLE,
      trk: STRUCT<
        name: STRING,
        trkpt: ARRAY<STRUCT<
          _lat: DOUBLE,
          _lon: DOUBLE,
          ele: DOUBLE
        >>,
        trkseg: ARRAY<STRUCT<
          trkpt: ARRAY<STRUCT<
            _lat: DOUBLE,
            _lon: DOUBLE,
            ele: DOUBLE
          >>
        >>
      >
    >'
  ) AS parsed
FROM validated_bronze
WHERE is_valid
  AND size(GPX) = 2;

-- temporary view to explode GPX points and validate each point
-- rows are uniquely identified by (route_id, segment_index, point_index)
CREATE TEMP VIEW validated_gpx_points AS
SELECT
  *,
  (
    latitude BETWEEN -90 AND 90
    AND longitude BETWEEN -180 AND 180
    AND elevation_m IS NOT NULL
  ) IS TRUE AS is_valid_point
FROM (
  SELECT
    parsed_gpx.route_id,
    segment_index,
    point_index,
    point._lat AS latitude,
    point._lon AS longitude,
    point.ele AS elevation_m
  FROM parsed_gpx,
  LATERAL posexplode(parsed_gpx.parsed.trk.trkseg)
    AS segment(segment_index, segment_data),
  LATERAL posexplode(segment_data.trkpt)
    AS track_point(point_index, point)
);

-- create quarantine silver gpx table for invalid points and record reason
CREATE OR REFRESH MATERIALIZED VIEW ${quarantine_silver_gpx_table_name} AS
SELECT
  route_id,
  segment_index,
  point_index,
  latitude,
  longitude,
  elevation_m,
  CASE
    WHEN latitude IS NULL THEN 'Latitude is null'
    WHEN latitude NOT BETWEEN -90 AND 90 THEN 'Latitude is outside valid range'
    WHEN longitude IS NULL THEN 'Longitude is null'
    WHEN longitude NOT BETWEEN -180 AND 180 THEN 'Longitude is outside valid range'
    WHEN elevation_m IS NULL THEN 'Elevation is null'
  END AS quarantine_reason
FROM validated_gpx_points
WHERE NOT is_valid_point;

-- create silver gpx table
CREATE OR REFRESH MATERIALIZED VIEW ${silver_gpx_table_name} AS
SELECT
  route_id,
  segment_index,
  point_index,
  latitude,
  longitude,
  elevation_m
FROM validated_gpx_points
WHERE is_valid_point;