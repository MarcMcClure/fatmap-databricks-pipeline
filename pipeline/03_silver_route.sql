-- create silver route quarantine table
CREATE OR REFRESH MATERIALIZED VIEW ${quarantine_silver_table_name} AS
SELECT
  *
FROM
  validated_bronze
WHERE
  not is_valid;

  -- create silver route table
CREATE OR REFRESH MATERIALIZED VIEW ${silver_table_name} AS
SELECT
  route_id,
  CASE
    WHEN array_size(GPX) = 0 THEN NULL
    ELSE array_join(GPX, '') 
  END AS GPX,
  int(
    replace(
      regexp_extract(elevation_min_max, r'\A(\d{1,3}(?:,\d{3})*) - (\d{1,3}(?:,\d{3})*) ft\z', 1),
      ',',
      ''
    )
  ) as elevation_min_ft,
  int(
    replace(
      regexp_extract(elevation_min_max, r'\A(\d{1,3}(?:,\d{3})*) - (\d{1,3}(?:,\d{3})*) ft\z', 2),
      ',',
      ''
    )
  ) as elevation_max_ft,
  CASE
    When duration = '' THEN NULL
    WHEN duration = '1 day +' THEN NULL
    ELSE DOUBLE(regexp_extract(duration, r'- (\d+(\.\d+)?)', 1))
  END AS max_duration_hr,
  CASE
    When duration = '' THEN NULL
    WHEN duration = '1 day +' THEN 24
    ELSE DOUBLE(regexp_extract(duration, r'\A(\d+(\.\d+)?)', 1))
  END AS min_duration_hr,
  double(trim(TRAILING ' mi' from length)) as length_mi,
  int(replace(trim(TRAILING ' ft' from ascent_distance), ',', '')) as ascent_distance_ft,
  int(replace(trim(TRAILING ' ft' from descent_distance), ',', '')) as descent_distance_ft,
  int(trim(TRAILING ' max°' from max_angle)) as max_angle_degrees,
  NULLIF(short_description, '') AS short_description,
  NULLIF(creator, '') AS creator,
  NULLIF(description, '') AS description,
  NULLIF(name, '') AS name,
  aspect,
  nullif(exposure, '') AS exposure,
  difficulty,
  nullif(remoteness, '') AS remoteness,
  replace(sport, '_', '') AS sport,
  CASE
    WHEN recommended_time_of_year = '' THEN CAST(array() AS ARRAY<STRING>)
    ELSE split(recommended_time_of_year, ',')
  END AS recommended_time_of_year,
  CASE
    WHEN characteristics = '' THEN CAST(array() AS ARRAY<STRING>)
    ELSE split(characteristics, ',')
  END AS characteristics
FROM
  validated_bronze
WHERE
  is_valid;