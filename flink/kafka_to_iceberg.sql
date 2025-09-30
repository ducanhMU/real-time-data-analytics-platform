-- =========================================================
-- Flink SQL job: consume Debezium CDC from Kafka topics
-- and write into Iceberg Bronze layer (Hive catalog + MinIO)
-- =========================================================

SET 'execution.runtime-mode' = 'streaming';
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'execution.checkpointing.interval' = '30s';
SET 'parallelism.default' = '1';

-------------------------------------------------
-- Register Iceberg Hive Catalog
-------------------------------------------------
CREATE CATALOG c_iceberg_hive WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hive',
  'warehouse' = 's3a://warehouse',
  'hive-conf-dir' = './conf'
);

USE CATALOG c_iceberg_hive;
CREATE DATABASE IF NOT EXISTS bronze;
USE bronze;

-------------------------------------------------
-- REGIONS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.regions_cdc (
    id STRING,
    region_name STRING,
    terrain_type STRING,
    infrastructure_level DECIMAL(19,4),
    area_sqkm DECIMAL(19,4),
    lat_center DECIMAL(19,8),
    lon_center DECIMAL(19,8),
    classification STRING,
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.regions',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100', -- avoid OOM error
    'debezium-json.timestamp-format.standard' = 'ISO-8601' 
);

CREATE TABLE IF NOT EXISTS regions_iceberg (
    id STRING,
    region_name STRING,
    terrain_type STRING,
    infrastructure_level DECIMAL(19,4),
    area_sqkm DECIMAL(19,4),
    lat_center DECIMAL(19,8),
    lon_center DECIMAL(19,8),
    classification STRING,
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO regions_iceberg 
SELECT * FROM default_catalog.default_database.regions_cdc;

-------------------------------------------------
-- TARGETS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.targets_cdc (
    id STRING,
    target_id STRING,
    target_type STRING,
    domain STRING,
    estimated_intent STRING,
    threat_level STRING,
    iff_status STRING,
    classification STRING,
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.targets',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS targets_iceberg (
    id STRING,
    target_id STRING,
    target_type STRING,
    domain STRING,
    estimated_intent STRING,
    threat_level STRING,
    iff_status STRING,
    classification STRING,
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO targets_iceberg 
SELECT * FROM default_catalog.default_database.targets_cdc;

-------------------------------------------------
-- USERS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.users_cdc (
    id STRING,
    username STRING,
    `role` STRING,
    classification STRING,
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.users',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS users_iceberg (
    id STRING,
    username STRING,
    `role` STRING,
    classification STRING,
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO users_iceberg 
SELECT * FROM default_catalog.default_database.users_cdc;

-------------------------------------------------
-- UNITS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.units_cdc (
    id STRING,
    `name` STRING,
    domain STRING,
    unit_type STRING,
    `status` STRING,
    classification STRING,
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.units',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS units_iceberg (
    id STRING,
    `name` STRING,
    domain STRING,
    unit_type STRING,
    `status` STRING,
    classification STRING,
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO units_iceberg 
SELECT * FROM default_catalog.default_database.units_cdc;

-------------------------------------------------
-- WEAPONS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.weapons_cdc (
    id STRING,
    unit_id STRING,
    `name` STRING,
    `type` STRING,
    effective_domain STRING,
    range_km DECIMAL(19,4),
    hit_probability DECIMAL(19,4),
    speed_kmh DECIMAL(19,4),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.weapons',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS weapons_iceberg (
    id STRING,
    unit_id STRING,
    `name` STRING,
    `type` STRING,
    effective_domain STRING,
    range_km DECIMAL(19,4),
    hit_probability DECIMAL(19,4),
    speed_kmh DECIMAL(19,4),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO weapons_iceberg 
SELECT * FROM default_catalog.default_database.weapons_cdc;

-------------------------------------------------
-- SENSORS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.sensors_cdc (
    id STRING,
    unit_id STRING,
    sensor_type STRING,
    range_km DECIMAL(19,4),
    `status` STRING,
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.sensors',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS sensors_iceberg (
    id STRING,
    unit_id STRING,
    sensor_type STRING,
    range_km DECIMAL(19,4),
    `status` STRING,
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO sensors_iceberg 
SELECT * FROM default_catalog.default_database.sensors_cdc;

-------------------------------------------------
-- DETECTIONS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.detections_cdc (
    id STRING,
    sensor_id STRING,
    target_id STRING,
    target_domain STRING,
    region_id STRING,
    lat DECIMAL(19,8),
    lon DECIMAL(19,8),
    altitude_depth DECIMAL(19,4),
    speed_kmh DECIMAL(19,4),
    heading_deg DECIMAL(19,4),
    confidence DECIMAL(19,4),
    iff_status STRING,
    threat_level STRING,
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.detections',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS detections_iceberg (
    id STRING,
    sensor_id STRING,
    target_id STRING,
    target_domain STRING,
    region_id STRING,
    lat DECIMAL(19,8),
    lon DECIMAL(19,8),
    altitude_depth DECIMAL(19,4),
    speed_kmh DECIMAL(19,4),
    heading_deg DECIMAL(19,4),
    confidence DECIMAL(19,4),
    iff_status STRING,
    threat_level STRING,
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO detections_iceberg 
SELECT * FROM default_catalog.default_database.detections_cdc;

-------------------------------------------------
-- WEATHER EVENTS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.weather_events_cdc (
    id STRING,
    region_id STRING,
    `type` STRING,
    intensity DECIMAL(19,4),
    wind_speed_kmh DECIMAL(19,4),
    precipitation_mm DECIMAL(19,4),
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.weather_events',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS weather_events_iceberg (
    id STRING,
    region_id STRING,
    `type` STRING,
    intensity DECIMAL(19,4),
    wind_speed_kmh DECIMAL(19,4),
    precipitation_mm DECIMAL(19,4),
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO weather_events_iceberg 
SELECT * FROM default_catalog.default_database.weather_events_cdc;

-------------------------------------------------
-- UNIT STATUS UPDATES
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.unit_status_updates_cdc (
    id STRING,
    unit_id STRING,
    region_id STRING,
    lat DECIMAL(19,8),
    lon DECIMAL(19,8),
    health_percent DECIMAL(19,4),
    max_range_km DECIMAL(19,4),
    `status` STRING,
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.unit_status_updates',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS unit_status_updates_iceberg (
    id STRING,
    unit_id STRING,
    region_id STRING,
    lat DECIMAL(19,8),
    lon DECIMAL(19,8),
    health_percent DECIMAL(19,4),
    max_range_km DECIMAL(19,4),
    `status` STRING,
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO unit_status_updates_iceberg 
SELECT * FROM default_catalog.default_database.unit_status_updates_cdc;

-------------------------------------------------
-- SUPPLY STATUS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.supply_status_cdc (
    id STRING,
    unit_id STRING,
    region_id STRING,
    supply_level DECIMAL(19,4),
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.supply_status',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS supply_status_iceberg (
    id STRING,
    unit_id STRING,
    region_id STRING,
    supply_level DECIMAL(19,4),
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO supply_status_iceberg 
SELECT * FROM default_catalog.default_database.supply_status_cdc;

-------------------------------------------------
-- CYBER / EW EVENTS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.cyber_ew_events_cdc (
    id STRING,
    source_id STRING,
    target_sensor_id STRING,
    effect STRING,
    impact_domain STRING,
    `level` STRING,
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.cyber_ew_events',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS cyber_ew_events_iceberg (
    id STRING,
    source_id STRING,
    target_sensor_id STRING,
    effect STRING,
    impact_domain STRING,
    `level` STRING,
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO cyber_ew_events_iceberg 
SELECT * FROM default_catalog.default_database.cyber_ew_events_cdc;

-------------------------------------------------
-- ENGAGEMENT EVENTS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.engagement_events_cdc (
    id STRING,
    attacker_id STRING,
    target_id STRING,
    weapon_id STRING,
    hit BOOLEAN,
    `result` STRING,
    roe_compliant BOOLEAN,
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.engagement_events',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS engagement_events_iceberg (
    id STRING,
    attacker_id STRING,
    target_id STRING,
    weapon_id STRING,
    hit BOOLEAN,
    `result` STRING,
    roe_compliant BOOLEAN,
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO engagement_events_iceberg 
SELECT * FROM default_catalog.default_database.engagement_events_cdc;

-------------------------------------------------
-- ROE UPDATES
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.roe_updates_cdc (
    id STRING,
    rules STRING,
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.roe_updates',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS roe_updates_iceberg (
    id STRING,
    rules STRING,
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO roe_updates_iceberg 
SELECT * FROM default_catalog.default_database.roe_updates_cdc;

-------------------------------------------------
-- ALERTS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.alerts_cdc (
    id STRING,
    detection_id STRING,
    `status` STRING,
    `message` STRING,
    threat_level STRING,
    created_at TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.alerts',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS alerts_iceberg (
    id STRING,
    detection_id STRING,
    `status` STRING,
    `message` STRING,
    threat_level STRING,
    created_at TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO alerts_iceberg 
SELECT * FROM default_catalog.default_database.alerts_cdc;

-------------------------------------------------
-- COMMANDS
-------------------------------------------------
CREATE TABLE IF NOT EXISTS default_catalog.default_database.commands_cdc (
    id STRING,
    alert_id STRING,
    unit_id STRING,
    `user_id` STRING,
    `action` STRING,
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'jadc2.raw.commands',
    'properties.bootstrap.servers' = 'kafka:9092',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'debezium-json',
    'properties.max.poll.records' = '100',
    'debezium-json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TABLE IF NOT EXISTS commands_iceberg (
    id STRING,
    alert_id STRING,
    unit_id STRING,
    `user_id` STRING,
    `action` STRING,
    `timestamp` TIMESTAMP_LTZ(6),
    ingest_timestamp TIMESTAMP_LTZ(6),
    source STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'write.target-file-size-bytes' = '16000000', -- avoid OOM error
    'sink.commit-interval' = '2s'
);

INSERT INTO commands_iceberg 
SELECT * FROM default_catalog.default_database.commands_cdc;

-- =========================================================
-- End of job
-- =========================================================
