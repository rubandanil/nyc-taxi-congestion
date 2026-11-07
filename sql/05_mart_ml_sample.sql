-- Случайная выборка ~300 тыс. поездок по Манхэттену для модели (1.7% строк, seed 42).

DROP TABLE IF EXISTS mart.ml_trips;

CREATE TABLE mart.ml_trips AS
SELECT
    t.trip_distance,
    t.pickup_hour,
    t.weekday,
    t.pulocationid,
    t.dolocationid,
    t.pickup_date,
    CASE
        WHEN t.pickup_date <= DATE '2024-12-19' THEN 'before'
        WHEN t.pickup_date <= DATE '2025-01-05' THEN 'holiday'
        ELSE 'after'
    END AS period,
    zp.zone_group AS pu_zone_group,
    zd.zone_group AS do_zone_group,
    t.duration_min
FROM core.trips AS t TABLESAMPLE BERNOULLI (1.7) REPEATABLE (42)
JOIN core.zones zp ON zp.locationid = t.pulocationid
JOIN core.zones zd ON zd.locationid = t.dolocationid
WHERE zp.borough = 'Manhattan'
  AND zd.borough = 'Manhattan';
