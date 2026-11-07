  -- Чистка поездок: длительность, скорость и причина отбраковки.
  -- Чистые поездки -> core.trips, отбракованные по причинам -> core.rejected_summary.

DROP TABLE IF EXISTS core.trips;
DROP TABLE IF EXISTS core.rejected_summary;

  -- Временная таблица, чтобы не считать CASE дважды.
CREATE TEMP TABLE flagged AS
WITH enriched AS (
    SELECT
        t.*,
        EXTRACT(EPOCH FROM (t.dropoff_datetime - t.pickup_datetime)) / 60.0 AS duration_min,
        t.pickup_datetime::date                                             AS pickup_date,
        EXTRACT(HOUR FROM t.pickup_datetime)::int                           AS pickup_hour,
        EXTRACT(ISODOW FROM t.pickup_datetime)::int                         AS weekday,
        pz.locationid                                                       AS pu_zone_known,
        dz.locationid                                                       AS do_zone_known
    FROM raw.trips t
    -- Служебные записи справочника: 264 = Unknown, 265 = Outside of NYC.
    LEFT JOIN raw.zones pz ON pz.locationid = t.pulocationid AND pz.locationid NOT IN (264, 265)
    LEFT JOIN raw.zones dz ON dz.locationid = t.dolocationid AND dz.locationid NOT IN (264, 265)
),
with_speed AS (
    SELECT
        *,
        CASE WHEN duration_min > 0 THEN trip_distance / (duration_min / 60.0) END AS speed_mph
    FROM enriched
)
SELECT
    *,
    CASE
        WHEN date_trunc('month', pickup_datetime)::date IS DISTINCT FROM source_month THEN 'pickup_outside_source_month'
        WHEN duration_min IS NULL OR duration_min <= 0 OR duration_min > 180          THEN 'duration_out_of_range'
        WHEN trip_distance IS NULL OR trip_distance <= 0 OR trip_distance > 100        THEN 'distance_out_of_range'
        WHEN speed_mph > 60                                                            THEN 'speed_over_60_mph'
        WHEN fare_amount IS NULL OR fare_amount < 0                                    THEN 'negative_fare'
        WHEN pu_zone_known IS NULL OR do_zone_known IS NULL                            THEN 'service_zone'
    END AS reject_reason
FROM with_speed;

CREATE TABLE core.trips AS
SELECT
    pickup_datetime,
    dropoff_datetime,
    pickup_date,
    pickup_hour,
    weekday,
    pulocationid,
    dolocationid,
    trip_distance,
    duration_min,
    speed_mph,
    fare_amount,
    tip_amount,
    total_amount,
    payment_type,
    cbd_congestion_fee,
    source_month
FROM flagged
WHERE reject_reason IS NULL;

CREATE TABLE core.rejected_summary AS
SELECT
    reject_reason,
    source_month,
    count(*) AS rows_rejected
FROM flagged
WHERE reject_reason IS NOT NULL
GROUP BY reject_reason, source_month
ORDER BY reject_reason, source_month;

DROP TABLE flagged;
