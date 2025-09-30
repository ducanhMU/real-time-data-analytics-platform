-- =========================================================
-- Flink SQL job: consume Debezium CDC from Kafka topics
-- and write into Pinot
-- =========================================================

SET 'execution.runtime-mode' = 'streaming';
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'execution.checkpointing.interval' = '30s';
SET 'parallelism.default' = '1';

-------------------------------------------------
-- create source tables
-------------------------------------------------

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

-- =========================================================
-- Pinot Sink Tables for Gold Layer
-- =========================================================

-------------------------------------------------
-- gold.effective_unit_strength
-------------------------------------------------
CREATE TABLE IF NOT EXISTS gold_effective_unit_strength (
    unit_id STRING,
    region_id STRING,
    weapon_id STRING,
    terrain_factor DOUBLE,
    effective_range_km DOUBLE,
    adjusted_hit_probability DOUBLE,
    attacking_strength DOUBLE,
    `timestamp` TIMESTAMP
) WITH (
    'connector' = 'pinot',
    'table-name' = 'gold_effective_unit_strength',
    'controller' = 'http://pinot-controller:9000'
);

-------------------------------------------------
-- gold.threat_assessment
-------------------------------------------------
CREATE TABLE IF NOT EXISTS gold_threat_assessment (
    target_id STRING,
    region_id STRING,
    iff_status STRING,
    adjusted_confidence DOUBLE,
    predicted_threat STRING,
    distance_km DOUBLE,
    response_time_sec DOUBLE,
    `timestamp` TIMESTAMP
) WITH (
    'connector' = 'pinot',
    'table-name' = 'gold_threat_assessment',
    'controller' = 'http://pinot-controller:9000'
);

-------------------------------------------------
-- gold.alerts_with_commands
-------------------------------------------------
CREATE TABLE IF NOT EXISTS gold_alerts_with_commands (
    alert_id STRING,
    detection_id STRING,
    region_id STRING,
    threat_level STRING,
    command_id STRING,
    `action` STRING,
    `user_id` STRING,
    `timestamp` TIMESTAMP
) WITH (
    'connector' = 'pinot',
    'table-name' = 'gold_alerts_with_commands',
    'controller' = 'http://pinot-controller:9000'
);

-------------------------------------------------
-- gold.logistics_readiness
-------------------------------------------------
CREATE TABLE IF NOT EXISTS gold_logistics_readiness (
    unit_id STRING,
    region_id STRING,
    supply_level DOUBLE,
    projected_supply DOUBLE,
    resupply_feasibility INT,
    `timestamp` TIMESTAMP
) WITH (
    'connector' = 'pinot',
    'table-name' = 'gold_logistics_readiness',
    'controller' = 'http://pinot-controller:9000'
);

-------------------------------------------------
-- gold.engagement_analysis
-------------------------------------------------
CREATE TABLE IF NOT EXISTS gold_engagement_analysis (
    engagement_id STRING,
    attacker_id STRING,
    target_id STRING,
    weapon_id STRING,
    region_id STRING,
    `result` STRING,
    adjusted_hit_probability DOUBLE,
    impact_factor DOUBLE,
    `timestamp` TIMESTAMP
) WITH (
    'connector' = 'pinot',
    'table-name' = 'gold_engagement_analysis',
    'controller' = 'http://pinot-controller:9000'
);

-------------------------------------------------
-- 1. Effective Unit Strength (upsert)
-------------------------------------------------
INSERT INTO gold_effective_unit_strength
SELECT
    u.id AS unit_id,
    us.region_id,
    w.id AS weapon_id,
    CASE r.terrain_type 
        WHEN 'mountain' THEN 0.8
        WHEN 'swamp' THEN 0.7
        ELSE 1.0
    END AS terrain_factor,
    w.max_range_km 
        * CASE r.terrain_type WHEN 'mountain' THEN 0.8 WHEN 'swamp' THEN 0.7 ELSE 1.0 END
        * (1 - 0.1 * COALESCE(we.wind_speed_kmh,0)/100) AS effective_range_km,
    w.hit_probability
        * (1 - 0.15 * COALESCE(we.precipitation_mm,0)
        - 0.2 * COALESCE(we.intensity, 0) * CASE WHEN we.type='fog' THEN 1 ELSE 0 END) AS adjusted_hit_probability,
    (w.hit_probability
        * (1 - 0.15 * COALESCE(we.precipitation_mm,0)
        - 0.2 * COALESCE(we.intensity, 0) * CASE WHEN we.type='fog' THEN 1 ELSE 0 END))
        * COALESCE(us.health_percent, 0) / 100 AS attacking_strength,
    us.timestamp
FROM units_cdc u
JOIN unit_status_updates_cdc us ON u.id = us.unit_id
JOIN weapons_cdc w ON w.unit_id = u.id
JOIN regions_cdc r ON r.id = us.region_id
LEFT JOIN weather_events_cdc we ON we.region_id = r.id AND we.timestamp <= us.timestamp
GROUP BY u.id, us.region_id, w.id, r.terrain_type, w.max_range_km, w.hit_probability, us.health_percent, us.timestamp,
         COALESCE(we.wind_speed_kmh,0), COALESCE(we.precipitation_mm,0), CASE WHEN we.type='fog' THEN 1 ELSE 0 END
;

-------------------------------------------------
-- 2. Threat Assessment (upsert)
-------------------------------------------------
INSERT INTO gold_threat_assessment
SELECT
    t.id AS target_id,
    d.region_id,
    t.iff_status,
    d.confidence
        * (1 - 0.3 * COALESCE(we.intensity,0) * CASE WHEN we.type IN ('fog','storm') THEN 1 ELSE 0 END
        - 0.5 * CASE WHEN ce.effect='jammed' THEN 1 ELSE 0 END) AS adjusted_confidence,
    CASE 
        WHEN (d.speed_kmh > 500 OR t.iff_status='foe')
             AND d.confidence
                 * (1 - 0.3 * COALESCE(we.intensity,0) * CASE WHEN we.type IN ('fog','storm') THEN 1 ELSE 0 END
                 - 0.5 * CASE WHEN ce.effect='jammed' THEN 1 ELSE 0 END) > 0.8
        THEN 'high'
        ELSE 'medium'
    END AS predicted_threat,
    -- haversine calc placeholder: if cannot compute, assign 1e9
    COALESCE(haversine(u.lat, u.lon, d.lat, d.lon), 1e9) AS distance_km,
    CASE 
        WHEN d.speed_kmh > 0 
        THEN COALESCE(haversine(u.lat, u.lon, d.lat, d.lon), 1e9) / d.speed_kmh * 3600
        ELSE 1e9
    END AS response_time_sec,
    d.timestamp
FROM targets_cdc t
JOIN detections_cdc d ON d.target_id = t.id
LEFT JOIN sensors_cdc s ON s.id = d.sensor_id
LEFT JOIN units_cdc u ON u.id = s.unit_id
LEFT JOIN unit_status_updates_cdc uu 
       ON uu.unit_id = u.id AND uu.timestamp = (
            SELECT MAX(`timestamp`) FROM unit_status_updates_cdc uu2 WHERE uu2.unit_id = u.id
       )
LEFT JOIN weather_events_cdc we ON we.region_id = d.region_id AND we.timestamp <= d.timestamp
LEFT JOIN cyber_ew_events_cdc ce ON ce.target_sensor_id = d.sensor_id AND ce.timestamp <= d.timestamp
GROUP BY t.id, d.region_id, t.iff_status, d.confidence, d.speed_kmh, d.lat, d.lon, u.lat, u.lon, d.timestamp,
         COALESCE(we.intensity,0), we.type, ce.effect
;

-------------------------------------------------
-- 3. Alerts with Commands (upsert)
-------------------------------------------------
INSERT INTO gold_alerts_with_commands
SELECT
    a.id AS alert_id,
    a.detection_id,
    d.region_id,
    a.threat_level,
    c.id AS command_id,
    CASE WHEN u.role='commander' THEN c.action ELSE NULL END AS `action`,
    u.id AS `user_id`,
    GREATEST(a.timestamp, c.timestamp) AS `timestamp`
FROM alerts_cdc a
JOIN detections_cdc d ON d.id = a.detection_id
LEFT JOIN commands_cdc c ON c.alert_id = a.id
LEFT JOIN users_cdc u ON u.id = c.user_id
WHERE a.threat_level >= 'high'
GROUP BY a.id, a.detection_id, d.region_id, a.threat_level, c.id, `action`, u.id, `timestamp`
;

-------------------------------------------------
-- 4. Logistics Readiness (upsert)
-------------------------------------------------
INSERT INTO gold_logistics_readiness
SELECT
    s.unit_id,
    us.region_id,
    s.supply_level,
    s.supply_level * (
        1 - 0.5 * COALESCE(we.intensity,0) 
        * CASE WHEN we.type IN ('storm','rain') THEN 1 ELSE 0 END 
        * CASE WHEN r.terrain_type='mountain' THEN 0.7 ELSE 1.0 END 
    ) AS projected_supply,
    CASE WHEN COALESCE(we.wind_speed_kmh,0) > 50 OR COALESCE(we.precipitation_mm,0) > 10
         THEN 0 ELSE 1 END AS resupply_feasibility,
    GREATEST(s.timestamp, we.timestamp) AS `timestamp`
FROM supply_status_cdc s
JOIN unit_status_updates_cdc us ON us.unit_id = s.unit_id
JOIN regions_cdc r ON r.id = us.region_id
LEFT JOIN weather_events_cdc we ON we.region_id = r.id AND we.timestamp <= s.timestamp
GROUP BY s.unit_id, us.region_id, s.supply_level, r.terrain_type,
         COALESCE(we.intensity,0), COALESCE(we.wind_speed_kmh,0), COALESCE(we.precipitation_mm,0), s.timestamp, we.timestamp
;

-------------------------------------------------
-- 5. Engagement Analysis (upsert)
-------------------------------------------------
INSERT INTO gold_engagement_analysis
SELECT
    e.id AS engagement_id,
    e.attacker_id,
    e.target_id,
    e.weapon_id,
    e.region_id,
    e.result,
    w.hit_probability * (
        1 - 0.2 * COALESCE(we.intensity, 0) * CASE WHEN we.type='fog' THEN 1 ELSE 0 END
        - 0.3 * CASE WHEN ce.effect='jammed' THEN 1 ELSE 0 END
    ) AS adjusted_hit_probability,
    (1 - 0.2 * CASE WHEN we.type='fog' THEN 1 ELSE 0 END
        - 0.3 * CASE WHEN ce.effect='jammed' THEN 1 ELSE 0 END)
        * CASE r.terrain_type WHEN 'mountain' THEN 0.8 ELSE 1.0 END AS impact_factor,
    e.timestamp
FROM engagement_events_cdc e
JOIN weapons_cdc w ON w.id = e.weapon_id
JOIN regions_cdc r ON r.id = e.region_id
LEFT JOIN weather_events_cdc we ON we.region_id = e.region_id AND we.timestamp <= e.timestamp
LEFT JOIN cyber_ew_events_cdc ce ON ce.target_sensor_id = e.attacker_id AND ce.timestamp <= e.timestamp
GROUP BY e.id, e.attacker_id, e.target_id, e.weapon_id, e.region_id, e.result,
         w.hit_probability, e.timestamp, COALESCE(we.type,''), COALESCE(ce.effect,''), r.terrain_type
;
