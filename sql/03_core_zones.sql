-- Делим районы Манхэттена на зону (cbd) и контроль (control).
-- Берём поездки с 6 января 2025, где посадка и высадка в одном районе,
-- и считаем долю поездок с платой за въезд.
-- Доля >= 0.9 - cbd, <= 0.1 - control, остальное - excluded.
-- Районы вне Манхэттена и с < 100 такими поездками тоже excluded.

DROP TABLE IF EXISTS core.zones;

CREATE TABLE core.zones AS
WITH same_zone AS (
    SELECT
        pulocationid AS locationid,
        count(*)                               AS same_zone_trips,
        avg((cbd_congestion_fee > 0)::int)     AS cbd_fee_share
    FROM core.trips
    WHERE pickup_date >= DATE '2025-01-06'
      AND pulocationid = dolocationid
    GROUP BY pulocationid
)
SELECT
    z.locationid,
    z.borough,
    z.zone,
    z.service_zone,
    s.same_zone_trips,
    s.cbd_fee_share,
    CASE
        WHEN z.borough <> 'Manhattan'            THEN 'excluded'
        WHEN coalesce(s.same_zone_trips, 0) < 100 THEN 'excluded'
        WHEN s.cbd_fee_share >= 0.9              THEN 'cbd'
        WHEN s.cbd_fee_share <= 0.1              THEN 'control'
        ELSE 'excluded'
    END AS zone_group
FROM raw.zones z
LEFT JOIN same_zone s USING (locationid)
ORDER BY z.locationid;
