-- Ensure gold database exists
CREATE DATABASE IF NOT EXISTS gold;

-- ===================================================
-- Effective Unit Strength
-- ===================================================
CREATE TABLE IF NOT EXISTS gold.effective_unit_strength (
    unit_id UUID,
    weapon_id UUID,
    region_id UUID,
    effective_range_km Decimal(19,4),
    adjusted_hit_probability Decimal(19,4),
    attacking_strength Decimal(19,4),
    terrain_factor Decimal(19,4),
    status String,             -- mapped from ENUM unit_status
    classification String,
    timestamp DateTime64(3, 'UTC')
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (region_id, unit_id, timestamp);

-- ===================================================
-- Threat Assessment
-- ===================================================
CREATE TABLE IF NOT EXISTS gold.threat_assessment (
    detection_id UUID,
    target_id UUID,
    region_id UUID,
    adjusted_confidence Decimal(19,4),
    predicted_threat String,   -- mapped from ENUM threat_level
    response_time_sec Decimal(19,4),
    iff_status String,         -- mapped from ENUM iff_status
    classification String,
    timestamp DateTime64(3, 'UTC')
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (region_id, detection_id, timestamp);

-- ===================================================
-- Alerts with Commands
-- ===================================================
CREATE TABLE IF NOT EXISTS gold.alerts_with_commands (
    alert_id UUID,
    detection_id UUID,
    command_id UUID,
    target_id UUID,
    region_id UUID,
    user_id UUID,
    threat_level String,       -- mapped from ENUM threat_level
    message String,
    action String,
    status String,             -- mapped from ENUM alert_status
    classification String,
    timestamp DateTime64(3, 'UTC')
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (region_id, alert_id, timestamp);

-- ===================================================
-- Logistics Readiness
-- ===================================================
CREATE TABLE IF NOT EXISTS gold.logistics_readiness (
    unit_id UUID,
    region_id UUID,
    projected_supply Decimal(19,4),
    resupply_feasibility Decimal(19,4),
    classification String,
    timestamp DateTime64(3, 'UTC')
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (region_id, unit_id, timestamp);

-- ===================================================
-- Engagement Analysis
-- ===================================================
CREATE TABLE IF NOT EXISTS gold.engagement_analysis (
    engagement_id UUID,
    attacker_id UUID,
    target_id UUID,
    weapon_id UUID,
    region_id UUID,
    result String,             -- mapped from ENUM engagement_result
    adjusted_hit_probability Decimal(19,4),
    impact_factor Decimal(19,4),
    classification String,
    timestamp DateTime64(3, 'UTC')
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (region_id, engagement_id, timestamp);
