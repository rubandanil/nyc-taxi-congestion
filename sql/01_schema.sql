-- Слои базы: raw — данные как есть, core — очищенные, mart — витрины для анализа.
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS mart;

-- Справочник районов TLC (taxi_zone_lookup.csv).
CREATE TABLE IF NOT EXISTS raw.zones (
    locationid   integer PRIMARY KEY,
    borough      text,
    zone         text,
    service_zone text
);

-- Поездки, только нужные колонки. Ограничений нет, чистка в core.
CREATE TABLE IF NOT EXISTS raw.trips (
    pickup_datetime    timestamp,
    dropoff_datetime   timestamp,
    pulocationid       integer,
    dolocationid       integer,
    trip_distance      double precision,
    fare_amount        double precision,
    tip_amount         double precision,
    total_amount       double precision,
    payment_type       integer,
    cbd_congestion_fee double precision,   -- NULL для файлов 2024 года
    source_month       date NOT NULL       -- первое число месяца файла
);
