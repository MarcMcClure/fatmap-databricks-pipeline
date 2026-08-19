-- temporary view to check if row is valid
CREATE TEMP VIEW validated_bronze AS
SELECT
  *,
  COUNT(*) OVER (PARTITION BY route_id) AS route_id_count,
  (
    -- check that ID matches route_id and they are not null
    ID = route_id
    AND ID IS NOT NULL
    -- check that route_id is not repeated.
    AND COUNT(*) OVER (PARTITION BY route_id) = 1
    -- check gpx array size
    AND (
      array_size(GPX) = 0
      OR (
        array_size(GPX) = 2
        AND GPX[0] IS NOT NULL
        AND GPX[1] IS NOT NULL
      )
    )
    -- check that characteristics is a list of valid characteristics
    AND (
      characteristics = ''
      OR characteristics RLIKE r'\A(Single Descent|Alpine|Walk Required|Glacier|Trees|Tree Skiing|Face|Couloir|Cliffs|Bowl|Ski Mountaineering|Ski Safari|Couloirs)(,(Single Descent|Alpine|Walk Required|Glacier|Trees|Tree Skiing|Face|Couloir|Cliffs|Bowl|Ski Mountaineering|Ski Safari|Couloirs))*\z'
    )
    -- check that recommended_time_of_year is a list of valid months
    AND (
      recommended_time_of_year = ''
      OR recommended_time_of_year RLIKE r'\A(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)(,(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec))*\z'
    )
    -- checks that aspect is like "[NSEW]{1,2} facing" or is null
    AND (
      aspect is null
      OR aspect RLIKE r'\A(N|NE|E|SE|S|SW|W|NW) facing\z'
    )
    -- checks that grading is always an empty string
    AND grading = ''
    -- check that sport, difficulty, exposure, and remoteness contain valid values
    AND sport in ('free_ride', 'touring')
    AND difficulty in ('Easy', 'Moderate', 'Difficult', 'Severe', 'Extreme')
    AND exposure IN (
      'Low Exposure (E1)', 'Medium Exposure (E2)', 'High Exposure (E3)', 'Extreme Exposure (E4)', ''
    )
    AND remoteness IN ('Extremely remote', 'Very remote', 'Remote', 'Not remote', '')
    -- check if ascent_distance, descent_distance, and max_angle are ints followed by units
    AND ascent_distance RLIKE r'\A\d{1,3}(,\d{3})* ft\z'
    AND descent_distance RLIKE r'\A\d{1,3}(,\d{3})* ft\z'
    AND max_angle RLIKE r'\A[12345678]?\d max°\z'
    -- check if length is a float followed by units
    AND length RLIKE r'\A\d+(\.\d+)? mi\z'
    -- check if duration is like "[float] - [float] hrs and elevation_min_max is like [int] - [int] ft"
    AND elevation_min_max RLIKE r'\A\d{1,3}(,\d{3})* - \d{1,3}(,\d{3})* ft\z'
    AND duration RLIKE r'\A(\d+(\.\d+)? - \d+(\.\d+)? hrs|1 day \+|)\z'
  ) IS TRUE AS is_valid
FROM
  ${bronze_table_name}
  ;