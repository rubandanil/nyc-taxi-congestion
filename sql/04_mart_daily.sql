  -- Метрики по дням для зоны и контроля, только поездки внутри одной группы.

DROP TABLE IF EXISTS mart.daily_group_metrics;
DROP TABLE IF EXISTS mart.daily_diff;

CREATE TABLE mart.daily_group_metrics AS
SELECT
    t.pickup_date,
    zp.zone_group,
    CASE
        WHEN t.pickup_date <= DATE '2024-12-19' THEN 'before'
        WHEN t.pickup_date <= DATE '2025-01-05' THEN 'holiday'   -- праздники, из анализа исключаются
        ELSE 'after'                                              -- плата действует с 5 января, первый полный день 6-е
    END AS period,
    count(*) AS trips,
    -- Средняя скорость как отношение сумм: устойчивее, чем среднее скоростей
    -- отдельных поездок, где короткие поездки с большой погрешностью весят столько же,
    -- сколько длинные.
    sum(t.trip_distance) / (sum(t.duration_min) / 60.0) AS avg_speed_mph,
    -- Тариф по счётчику без доплат и без платы за въезд. payment_type 0 — Flex Fare,
    -- поездка с заранее фиксированной ценой через приложение, не по счётчику,
    -- поэтому в avg_fare её нет. avg_fare_all по всем поездкам — для проверки.
    avg(t.fare_amount) FILTER (WHERE t.payment_type BETWEEN 1 AND 4) AS avg_fare,
    avg(t.fare_amount) AS avg_fare_all
FROM core.trips t
JOIN core.zones zp ON zp.locationid = t.pulocationid
JOIN core.zones zd ON zd.locationid = t.dolocationid
WHERE zp.zone_group IN ('cbd', 'control')
  AND zd.zone_group = zp.zone_group
GROUP BY t.pickup_date, zp.zone_group
ORDER BY t.pickup_date, zp.zone_group;

-- Разности cbd минус control по каждой дате. На одну дату и группу ровно одна
-- строка, поэтому max(...) FILTER (WHERE zone_group = ...) просто достаёт это значение.
-- Для числа поездок берётся разность логарифмов: это разность в процентах,
-- а не в штуках, и она не зависит от размера групп.
CREATE TABLE mart.daily_diff AS
SELECT
    pickup_date,
    period,
    ln(max(trips) FILTER (WHERE zone_group = 'cbd'))
        - ln(max(trips) FILTER (WHERE zone_group = 'control'))         AS log_trips_diff,
    max(avg_speed_mph) FILTER (WHERE zone_group = 'cbd')
        - max(avg_speed_mph) FILTER (WHERE zone_group = 'control')     AS speed_diff,
    max(avg_fare) FILTER (WHERE zone_group = 'cbd')
        - max(avg_fare) FILTER (WHERE zone_group = 'control')          AS fare_diff,
    max(avg_fare_all) FILTER (WHERE zone_group = 'cbd')
        - max(avg_fare_all) FILTER (WHERE zone_group = 'control')      AS fare_all_diff
FROM mart.daily_group_metrics
GROUP BY pickup_date, period
HAVING count(*) = 2   -- обе группы есть в этот день
ORDER BY pickup_date;
