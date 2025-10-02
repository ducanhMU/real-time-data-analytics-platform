# Multi-Domain Operations Monitoring System - Medallion Architecture Database

## Overview

The **Multi-Domain Operations Monitoring System** implements a **Medallion Architecture** (Bronze, Silver, Gold layers) to manage real-time data for Joint All-Domain Command and Control (JADC2)-inspired military operations across land, sea, air, space, and cyber domains. It processes high-velocity sensor data (e.g., radar, sonar, satellites) to support Intelligence, Surveillance, Reconnaissance (ISR), fire coordination, electronic warfare (EW) management, and command and control (C2). The **Gold Layer** serves as an OLAP datastore, optimized for analytics and accessible via a chatbot interface for real-time queries (e.g., “List high-threat targets in region Alpha”).

### Layers
- **Bronze Layer**: Raw, immutable data from sensors, telemetry, and C2 feeds. Includes `ingest_timestamp` and `source` for auditability. Partitioned by `ingest_timestamp` and `domain`.
- **Silver Layer**: Cleaned, validated, and enriched data with deduplication and standardized ENUMs. Supports intermediate analytics (e.g., threat tracking).
- **Gold Layer**: Aggregated, denormalized views optimized for OLAP queries and MCP chatbot interactions. Includes computed metrics (e.g., terrain-adjusted combat strength).

### Technology
- **Storage**: PostgreSQL for ACID compliance, partitioning, and auditability.
- **Processing**: SQL-based ETL for transformations; triggers for real-time streaming.
- **Security**: Row-level access via `classification` (e.g., `secret`, `unclassified`); role-based access via `users_raw.role` (e.g., `commander`, `analyst`).
- **Scalability**: Handles 1M+ events daily with indexes on `lat`, `lon`, `timestamp`, `region_id`.
- **Chatbot Integration**: MCP REST API for natural language queries on Gold Layer views.

## Problem Statement

### Context
The system supports JADC2 operations, processing sensor data for:
- **Sensor Ingestion**: Radar, sonar, satellites, EW monitors.
- **Data Fusion**: AI-driven track correlation across domains.
- **Coordination**: Joint C2 for cross-domain fires and logistics.
- **Storage**: Secure, partitioned database with role-based access.
- **Analytics**: Threat assessment, regional combat effectiveness, logistics forecasting.
- **Access**: Real-time MCP chatbot for commanders (decision-making) and analysts (monitoring).

It helps avoid failures (e.g., sensor jamming, false positives, unauthorized commands) risk mission failure, loss of battlespace awareness, or friendly fire.

### Goals
- **Real-time Monitoring**: Track threats, units, and logistics by region.
- **Data Quality**: Mitigate false positives via confidence scores and alerts.
- **Proactive Alerting**: Trigger alerts for high/critical threats (e.g., inbound missiles).
- **Secure C2**: Restrict decision-making to authorized users (e.g., `commander` role).
- **Scalability**: Process millions of events daily with optimized OLAP queries.
- **Chatbot Accessibility**: Enable queries like “Show hostile targets in region Alpha” or “Can resupply proceed in region Delta?”
- **Realistic Scenarios**: Support radar-guided targeting, ROE-constrained engagements, logistics under terrain/weather constraints, and secure cross-domain C2.

### User Concerns (for MCP Chatbot)
Based on FM 3-0 and JADC2, users need:
1. **Situational Awareness**: Real-time threat and unit status by region (e.g., “List hostile targets in region Alpha”).
2. **Decision Support**: Query terrain/weather-adjusted combat effectiveness (e.g., “Which units can engage in region Bravo?”).
3. **Threat Prioritization**: Alerts for high/critical threats (e.g., “Missile inbound, region Charlie”).
4. **Logistics Planning**: Assess resupply feasibility (e.g., “Can air drops proceed in region Delta?”).
5. **Engagement Analysis**: Review outcomes (e.g., “Why did missile miss in region Echo?”).
6. **Security**: Restrict commands to `commander` role, limit `analyst` to monitoring.
7. **Ease of Use**: Fast, accurate natural language queries.

### Military Scenarios
1. **Threat Tracking**: Identify and track harmful objects (e.g., missiles) using `targets_raw` and `detections_raw`. Query: “List high-threat missiles in region Alpha.”
2. **Regional Combat Effectiveness**: Estimate unit strength using `regions_raw` (terrain) and `weather_events_raw` (e.g., tanks lose 20% range in swamps, 15% in rain). Query: “What’s the effective strength of air units in region Bravo?”
3. **Secure C2**: Restrict commands (e.g., “Engage target”) to `commander` role via `users_raw`. Query: “Who can authorize strikes in region Charlie?”
4. **Logistics Feasibility**: Assess resupply using `supply_status_raw`, `regions_raw`, and `weather_events_raw` (e.g., storms block air drops in mountains). Query: “Can resupply proceed in region Delta?”
5. **Engagement Analysis**: Review outcomes using `engagement_events_raw` and `targets_raw` (e.g., jamming causes 30% miss rate). Query: “Why did missile miss target X in region Echo?”

## ENUM Types
- **unit_status**: `ready` (operational), `engaged` (in combat), `damaged` (degraded), `destroyed` (neutralized), `retreat` (withdrawing).
- **domain_type**: `land` (tanks, infantry), `sea` (submarines, carriers), `air` (fighters, drones), `space` (satellites), `cyber` (EW, network ops).
- **alert_status**: `active` (unresolved), `resolved` (neutralized), `acknowledged` (reviewed), `dismissed` (false positive).
- **ew_effect**: `jammed` (signal interference), `spoofed` (false data), `disabled` (sensor outage), `ddos` (network denial).
- **weather_type**: `rain` (reduces mobility), `fog` (impairs radar), `storm` (disrupts sea/air), `solar_flare` (degrades space/cyber).
- **engagement_result**: `destroyed` (target eliminated), `damaged` (degraded), `escaped` (evaded), `missed` (weapon failed).
- **threat_level**: `low` (distant), `medium` (approaching), `high` (imminent), `critical` (direct attack).
- **iff_status**: `friend` (allied), `foe` (hostile), `neutral` (civilian), `unknown` (unidentified).
- **user_role**: `commander` (authorizes commands), `analyst` (monitors), `operator` (executes tasks).

## Database Schema

### Bronze Layer (Raw Data)
Raw, immutable data from sensors, telemetry, and C2 feeds. Partitioned by `ingest_timestamp`, `domain`.

#### bronze.regions_raw
| Col                 | Data Type                | Description                             |
|---------------------|--------------------------|-----------------------------------------|
| id                  | UUID                     | Primary key.                            |
| region_name         | VARCHAR(255)             | Name (e.g., 'Alpha').                   |
| terrain_type        | VARCHAR(50)              | Terrain (e.g., 'mountain', 'desert').   |
| infrastructure_level | DECIMAL(19,4)            | Road/port quality (0-1).                |
| area_sqkm           | DECIMAL(19,4)            | Area (km²).                             |
| lat_center          | DECIMAL(19,8)            | Center latitude.                        |
| lon_center          | DECIMAL(19,8)            | Center longitude.                       |
| classification      | VARCHAR(50)              | Security (e.g., 'secret').              |
| ingest_timestamp    | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src              | VARCHAR(255)             | Source (e.g., 'GIS feed').              |

#### bronze.targets_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| target_id        | VARCHAR(255) UNIQUE      | Designator (e.g., 'HOSTILE_001').       |
| target_type      | VARCHAR(255)             | Type (e.g., 'missile', 'aircraft').     |
| domain           | domain_type (ENUM)       | Domain.                                 |
| estimated_intent | VARCHAR(255)             | Intent (e.g., 'attack', 'recon').       |
| threat_level     | threat_level (ENUM)      | Risk level.                             |
| iff_status       | iff_status (ENUM)        | Friend/foe.                             |
| classification   | VARCHAR(50)              | Security (e.g., 'secret').              |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'ISR feed').              |

#### bronze.users_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| username         | VARCHAR(255) UNIQUE      | Username.                               |
| role             | user_role (ENUM)         | Role (e.g., 'commander').               |
| classification   | VARCHAR(50)              | Access level (e.g., 'secret').          |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'auth system').           |

#### bronze.units_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| name             | VARCHAR(255)             | Callsign (e.g., 'F16_01').              |
| domain           | domain_type (ENUM)       | Domain (e.g., 'air').                   |
| unit_type        | VARCHAR(255)             | Type (e.g., 'F-16').                    |
| status           | unit_status (ENUM)       | Status.                                 |
| classification   | VARCHAR(50)              | Security (e.g., 'secret').              |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'C2 feed').               |

#### bronze.weapons_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| unit_id          | UUID                     | Host unit ID.                           |
| name             | VARCHAR(255)             | Weapon (e.g., 'AIM-120').               |
| type             | VARCHAR(255)             | Category (e.g., 'radar-guided missile').|
| effective_domain | domain_type (ENUM)       | Domain.                                 |
| range_km         | DECIMAL(19,4)            | Range.                                  |
| hit_probability  | DECIMAL(19,4)            | Accuracy (0-1).                         |
| speed_kmh        | DECIMAL(19,4)            | Velocity (km/h).                        |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'weapon DB').             |

#### bronze.sensors_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| unit_id          | UUID                     | Host unit ID.                           |
| sensor_type      | VARCHAR(255)             | Type (e.g., 'AN/APG-81').               |
| range_km         | DECIMAL(19,4)            | Detection range.                        |
| status           | VARCHAR(50)              | Status (e.g., 'active').                |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'sensor log').            |

#### bronze.detections_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| sensor_id        | UUID                     | Sensor ID.                              |
| target_id        | UUID                     | FK to targets_raw.                      |
| target_domain    | domain_type (ENUM)       | Domain.                                 |
| region_id        | UUID                     | FK to regions_raw.                      |
| lat              | DECIMAL(19,8)            | Latitude.                               |
| lon              | DECIMAL(19,8)            | Longitude.                              |
| altitude_depth   | DECIMAL(19,4)            | Altitude/depth (m).                     |
| speed_kmh        | DECIMAL(19,4)            | Speed (km/h).                           |
| heading_deg      | DECIMAL(19,4)            | Course (degrees).                       |
| confidence       | DECIMAL(19,4)            | Probability (0-1).                      |
| iff_status       | iff_status (ENUM)        | Friend/foe.                             |
| threat_level     | threat_level (ENUM)      | Risk level.                             |
| event_time        | TIMESTAMP WITH TIME ZONE | Detection time.                         |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'radar feed').            |

#### bronze.weather_events_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| region_id        | UUID                     | FK to regions_raw.                      |
| type             | weather_type (ENUM)      | Weather.                                |
| intensity        | DECIMAL(19,4)            | Severity (0-1).                         |
| wind_speed_kmh   | DECIMAL(19,4)            | Wind speed.                             |
| precipitation_mm | DECIMAL(19,4)            | Precipitation.                          |
| event_time        | TIMESTAMP WITH TIME ZONE | Event time.                             |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'METOC').                 |

#### bronze.unit_status_updates_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| unit_id          | UUID                     | Unit ID.                                |
| region_id        | UUID                     | FK to regions_raw.                      |
| lat              | DECIMAL(19,8)            | Latitude.                               |
| lon              | DECIMAL(19,8)            | Longitude.                              |
| health_percent   | DECIMAL(19,4)            | Fuel/ammo/health (0-100).               |
| max_range_km     | DECIMAL(19,4)            | Dynamic range.                          |
| status           | unit_status (ENUM)       | Status.                                 |
| event_time        | TIMESTAMP WITH TIME ZONE | Update time.                            |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'unit telemetry').        |

#### bronze.supply_status_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| unit_id          | UUID                     | Unit ID.                                |
| region_id        | UUID                     | FK to regions_raw.                      |
| supply_level     | DECIMAL(19,4)            | Supplies (0-100).                       |
| event_time        | TIMESTAMP WITH TIME ZONE | Update time.                            |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'logistics feed').        |

#### bronze.cyber_ew_events_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| source_id        | UUID                     | Source unit ID (attacker).              |
| target_sensor_id | UUID                     | Target sensor ID.                       |
| effect           | ew_effect (ENUM)         | EW effect.                              |
| impact_domain    | domain_type (ENUM)       | Affected domain.                        |
| level            | threat_level (ENUM)      | Severity.                               |
| event_time        | TIMESTAMP WITH TIME ZONE | Event time.                             |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'EW monitor').            |

#### bronze.engagement_events_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| attacker_id      | UUID                     | Attacker unit ID.                       |
| target_id        | UUID                     | FK to targets_raw.                      |
| weapon_id        | UUID                     | Weapon ID.                              |
| hit              | BOOLEAN                  | Impact confirmation.                    |
| result           | engagement_result (ENUM) | Outcome.                                |
| roe_compliant    | BOOLEAN                  | ROE adherence.                          |
| event_time        | TIMESTAMP WITH TIME ZONE | Event time.                             |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'fire control system').   |

#### bronze.roe_updates_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| rules            | JSONB                    | Constraints (e.g., `["no_collateral"]`).|
| event_time        | TIMESTAMP WITH TIME ZONE | Effective time.                         |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'C2 policy feed').        |

#### bronze.alerts_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| detection_id     | UUID                     | Detection ID.                           |
| status           | alert_status (ENUM)      | Status.                                 |
| msg          | TEXT                     | Details (e.g., 'Inbound foe').          |
| threat_level     | threat_level (ENUM)      | Priority.                               |
| created_at       | TIMESTAMP WITH TIME ZONE | Alert time.                             |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'alert system').          |

#### bronze.commands_raw
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | Primary key.                            |
| alert_id         | UUID                     | Alert ID (triggered by).                |
| unit_id          | UUID                     | Unit ID (executor).                     |
| user_id          | UUID                     | FK to users_raw (issuer).               |
| action           | VARCHAR(255)             | Command (e.g., 'Engage target').        |
| event_time        | TIMESTAMP WITH TIME ZONE | Issue time.                             |
| ingest_timestamp | TIMESTAMP WITH TIME ZONE | Ingestion time.                         |
| src           | VARCHAR(255)             | Source (e.g., 'C2 system').             |

### Silver Layer (Refined Data)
Cleaned, validated, enriched data. Deduplicated, standardized with ENUMs, and joined for analytics. Partitioned by `timestamp`, `domain`.

#### silver.regions
| Col                 | Data Type                | Description                             |
|---------------------|--------------------------|-----------------------------------------|
| id                  | UUID                     | PK (deduped).                           |
| region_name         | VARCHAR(255)             | Name (e.g., 'Alpha').                   |
| terrain_type        | VARCHAR(50)              | Terrain (e.g., 'mountain').             |
| infrastructure_level | DECIMAL(19,4)            | Validated (0-1).                        |
| area_sqkm           | DECIMAL(19,4)            | Validated (>0).                         |
| lat_center          | DECIMAL(19,8)            | Validated latitude.                     |
| lon_center          | DECIMAL(19,8)            | Validated longitude.                    |
| classification      | VARCHAR(50)              | Security (e.g., 'secret').              |
| update_timestamp    | TIMESTAMP WITH TIME ZONE | Last update.                            |

#### silver.targets
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK (deduped).                           |
| target_id        | VARCHAR(255) UNIQUE      | Designator (e.g., 'HOSTILE_001').       |
| target_type      | VARCHAR(255)             | Validated type (e.g., 'missile').       |
| domain           | domain_type (ENUM)       | Domain.                                 |
| estimated_intent | VARCHAR(255)             | Validated (e.g., 'attack').             |
| threat_level     | threat_level (ENUM)      | Risk level.                             |
| iff_status       | iff_status (ENUM)        | Friend/foe.                             |
| classification   | VARCHAR(50)              | Security (e.g., 'secret').              |
| update_timestamp | TIMESTAMP WITH TIME ZONE | Last update.                            |

#### silver.users
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK (deduped).                           |
| username         | VARCHAR(255) UNIQUE      | Username.                               |
| role             | user_role (ENUM)         | Role (e.g., 'commander').               |
| classification   | VARCHAR(50)              | Access level (e.g., 'secret').          |
| update_timestamp | TIMESTAMP WITH TIME ZONE | Last update.                            |

#### silver.units
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK (deduped).                           |
| name             | VARCHAR(255)             | Cleaned callsign.                       |
| domain           | domain_type (ENUM)       | Domain.                                 |
| unit_type        | VARCHAR(255)             | Validated type (e.g., 'F-16').          |
| status           | unit_status (ENUM)       | Status.                                 |
| classification   | VARCHAR(50)              | Security (e.g., 'secret').              |
| update_timestamp | TIMESTAMP WITH TIME ZONE | Last update.                            |

#### silver.weapons
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK.                                     |
| unit_id          | UUID                     | FK to silver.units.                     |
| name             | VARCHAR(255)             | Weapon name.                            |
| type             | VARCHAR(255)             | Category (e.g., 'radar-guided missile').|
| effective_domain | domain_type (ENUM)       | Domain.                                 |
| range_km         | DECIMAL(19,4)            | Validated.                              |
| hit_probability  | DECIMAL(19,4)            | Validated (0-1).                        |
| speed_kmh        | DECIMAL(19,4)            | Validated.                              |
| update_timestamp | TIMESTAMP WITH TIME ZONE | Last update.                            |

#### silver.sensors
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK.                                     |
| unit_id          | UUID                     | FK to silver.units.                     |
| sensor_type      | VARCHAR(255)             | Validated type.                         |
| range_km         | DECIMAL(19,4)            | Validated.                              |
| status           | VARCHAR(50)              | Validated (e.g., 'active').             |
| update_timestamp | TIMESTAMP WITH TIME ZONE | Last update.                            |

#### silver.detections
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK.                                     |
| sensor_id        | UUID                     | FK to silver.sensors.                   |
| target_id        | UUID                     | FK to silver.targets.                   |
| target_domain    | domain_type (ENUM)       | Domain.                                 |
| region_id        | UUID                     | FK to silver.regions.                   |
| lat              | DECIMAL(19,8)            | Validated latitude.                     |
| lon              | DECIMAL(19,8)            | Validated longitude.                    |
| altitude_depth   | DECIMAL(19,4)            | Validated.                              |
| speed_kmh        | DECIMAL(19,4)            | Validated.                              |
| heading_deg      | DECIMAL(19,4)            | Normalized (0-360).                     |
| confidence       | DECIMAL(19,4)            | Validated (0-1).                        |
| iff_status       | iff_status (ENUM)        | Friend/foe.                             |
| threat_level     | threat_level (ENUM)      | Risk level.                             |
| event_time        | TIMESTAMP WITH TIME ZONE | Detection time.                         |

#### silver.weather_events
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK.                                     |
| region_id        | UUID                     | FK to silver.regions.                   |
| type             | weather_type (ENUM)      | Weather.                                |
| intensity        | DECIMAL(19,4)            | Validated (0-1).                        |
| wind_speed_kmh   | DECIMAL(19,4)            | Validated.                              |
| precipitation_mm | DECIMAL(19,4)            | Validated (>=0).                        |
| event_time        | TIMESTAMP WITH TIME ZONE | Event time.                             |

#### silver.unit_status_updates
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK.                                     |
| unit_id          | UUID                     | FK to silver.units.                     |
| region_id        | UUID                     | FK to silver.regions.                   |
| lat              | DECIMAL(19,8)            | Validated latitude.                     |
| lon              | DECIMAL(19,8)            | Validated longitude.                    |
| health_percent   | DECIMAL(19,4)            | Validated (0-100).                      |
| max_range_km     | DECIMAL(19,4)            | Validated (>0).                         |
| status           | unit_status (ENUM)       | Status.                                 |
| event_time        | TIMESTAMP WITH TIME ZONE | Update time.                            |

#### silver.supply_status
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK.                                     |
| unit_id          | UUID                     | FK to silver.units.                     |
| region_id        | UUID                     | FK to silver.regions.                   |
| supply_level     | DECIMAL(19,4)            | Validated (0-100).                      |
| event_time        | TIMESTAMP WITH TIME ZONE | Update time.                            |

#### silver.cyber_ew_events
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK (deduped).                           |
| source_id        | UUID                     | FK to silver.units (attacker).          |
| target_sensor_id | UUID                     | FK to silver.sensors.                   |
| effect           | ew_effect (ENUM)         | Standardized effect.                    |
| impact_domain    | domain_type (ENUM)       | Affected domain.                        |
| level            | threat_level (ENUM)      | Severity.                               |
| event_time        | TIMESTAMP WITH TIME ZONE | Event time.                             |

#### silver.engagement_events
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK.                                     |
| attacker_id      | UUID                     | FK to silver.units.                     |
| target_id        | UUID                     | FK to silver.targets.                   |
| weapon_id        | UUID                     | FK to silver.weapons.                   |
| hit              | BOOLEAN                  | Impact confirmation.                    |
| result           | engagement_result (ENUM) | Outcome.                                |
| roe_compliant    | BOOLEAN                  | ROE adherence.                          |
| event_time        | TIMESTAMP WITH TIME ZONE | Event time.                             |


#### silver.roe_updates
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK.                                     |
| rules            | JSONB                    | Validated constraints.                  |
| event_time        | TIMESTAMP WITH TIME ZONE | Effective time.                         |
| update_timestamp | TIMESTAMP WITH TIME ZONE | Last update.                            |

#### silver.alerts
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK.                                     |
| detection_id     | UUID                     | FK to silver.detections.                |
| status           | alert_status (ENUM)      | Status.                                 |
| msg          | TEXT                     | Details (e.g., 'Inbound foe').          |
| threat_level     | threat_level (ENUM)      | Priority.                               |
| created_at       | TIMESTAMP WITH TIME ZONE | Alert time.                             |
| update_timestamp | TIMESTAMP WITH TIME ZONE | Last update.                            |

#### silver.commands
| Col              | Data Type                | Description                             |
|------------------|--------------------------|-----------------------------------------|
| id               | UUID                     | PK.                                     |
| alert_id         | UUID                     | FK to silver.alerts.                    |
| unit_id          | UUID                     | FK to silver.units.                     |
| user_id          | UUID                     | FK to silver.users.                     |
| action           | VARCHAR(255)             | Command (e.g., 'Engage target').        |
| event_time        | TIMESTAMP WITH TIME ZONE | Issue time.                             |
| update_timestamp | TIMESTAMP WITH TIME ZONE | Last update.                            |


### Gold Layer (OLAP Datastore for MCP/Chatbot)

Each table is **denormalized**, built from Silver layer tables, and **materialized** for real-time C2 queries.
Partitioned by `timestamp`, `region_id` where applicable.

---

#### gold.effective\_unit\_strength

**Purpose**: Terrain/weather-adjusted combat effectiveness of units.

**Source Silver Tables**:

* `silver.units` (unit\_id, classification)
* `silver.weapons` (weapon\_id, max\_range\_km, hit\_probability)
* `silver.regions` (region\_id, terrain\_type)
* `silver.weather_events` (region\_id, wind\_speed\_kmh, precipitation\_mm, intensity, type, timestamp)
* `silver.unit_status_updates` (unit\_id, status, health\_percent, region\_id, timestamp)

**Columns**:

| Column                     | Formula / Source                                                                     |
| -------------------------- | ------------------------------------------------------------------------------------ |
| unit\_id                   | silver.unit\_status\_updates.unit\_id                                                |
| region\_id                 | silver.unit\_status\_updates.region\_id                                              |
| weapon\_id                 | silver.weapons.id                                                            |
| terrain\_factor            | `CASE terrain_type WHEN 'mountain' THEN 0.8 WHEN 'swamp' THEN 0.7 ELSE 1.0 END`      |
| effective\_range\_km       | `max_range_km * terrain_factor * (1 - 0.1 * wind_speed_kmh / 100)`                   |
| adjusted\_hit\_probability | `hit_probability * (1 - 0.15 * precipitation_mm - 0.2 * intensity * (type = 'fog'))` |
| attacking\_strength        | `adjusted_hit_probability * health_percent / 100`                                    |
| event_time                  | silver.unit\_status\_updates.event_time                                               |

---

#### gold.threat_assessment

**Purpose**  
Threat prioritization with weather and EW adjustments.

**Source Silver Tables**  
- `silver.targets` (target_id, iff_status)  
- `silver.detections` (detection_id, target_id, sensor_id, region_id, confidence, speed_kmh, timestamp)  
- `silver.sensors` (sensor_id, unit_id)  
- `silver.units` (unit_id)  
- `silver.unit_status_updates` (unit_id, lat, lon, timestamp)  
- `silver.weather_events` (region_id, intensity, type, timestamp)  
- `silver.cyber_ew_events` (target_sensor_id, effect, timestamp)  

**Columns**

| Column              | Definition                                                                                       |
| ------------------- | ------------------------------------------------------------------------------------------------ |
| target_id           | `silver.targets.target_id`                                                                       |
| region_id           | `silver.detections.region_id`                                                                    |
| iff_status          | `silver.targets.iff_status`                                                                      |
| adjusted_confidence | `confidence * (1 - 0.3 * intensity * (type IN ('fog','storm')) - 0.5 * (effect = 'jammed'))`     |
| predicted_threat    | `CASE WHEN (speed_kmh > 500 OR iff_status = 'foe') AND adjusted_confidence > 0.8 THEN 'high' ELSE 'medium' END` |
| distance_km         | **Calculated:**<br>1. From `detection.sensor_id` → get `unit_id` from `silver.sensors`.<br>2. Get latest (`lat, lon`) of unit from `silver.unit_status_updates`.<br>3. Use target (`lat, lon`) from `silver.detections`.<br>4. Compute haversine distance (km).<br>5. If no unit position → assign a **large value** (e.g., `1e9`) so that `MIN(distance_km)` works correctly. |
| response_time_sec   | `(distance_km / NULLIF(speed_kmh,0)) * 3600`. If `distance_km = 1e9`, keep it as `1e9` to indicate not computable. |
| event_time           | `silver.detections.event_time`                                                                    |

---

#### gold.alerts\_with\_commands

**Purpose**: Alerts joined with authorized C2 actions.

**Source Silver Tables**:

* `silver.alerts` (alert\_id, detection\_id, message, threat\_level, status, timestamp)
* `silver.commands` (command\_id, alert\_id, action, user\_id, timestamp)
* `silver.detections` (detection\_id, target\_id, region\_id)
* `silver.users` (user\_id, role, classification)

**Columns**:

| Column        | Formula / Source                                                        |
| ------------- | ----------------------------------------------------------------------- |
| alert\_id     | silver.alerts.id                                                 |
| detection\_id | silver.alerts.detection\_id                                             |
| region\_id    | silver.detections.region\_id                                            |
| threat\_level | silver.alerts.threat\_level (only include ≥ 'high')                     |
| command\_id   | silver.commands.id (only from users.role = 'commander')        |
| action        | `CASE WHEN users.role = 'commander' THEN commands.action ELSE NULL END` |
| user\_id      | silver.users.id                                                   |
| event_time     | GREATEST(silver.alerts.event_time, silver.commands.event_time)            |

---

#### gold.logistics\_readiness

**Purpose**: Supply feasibility under weather/terrain constraints.

**Source Silver Tables**:

* `silver.supply_status` (unit\_id, supply\_level, timestamp)
* `silver.regions` (region\_id, terrain\_type)
* `silver.weather_events` (region\_id, wind\_speed\_kmh, precipitation\_mm, intensity, type, timestamp)
* `silver.unit_status_updates` (unit\_id, region\_id, timestamp)

**Columns**:

| Column                | Formula / Source                                                                                                                |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| unit\_id              | silver.supply\_status.unit\_id                                                                                                  |
| region\_id            | silver.unit\_status\_updates.region\_id                                                                                         |
| supply\_level         | silver.supply\_status.supply\_level                                                                                             |
| projected\_supply     | `supply_level * (1 - 0.5 * intensity * (type IN ('storm','rain')) * CASE WHEN terrain_type = 'mountain' THEN 0.7 ELSE 1.0 END)` |
| resupply\_feasibility | `CASE WHEN wind_speed_kmh > 50 OR precipitation_mm > 10 THEN 0 ELSE 1 END`                                                      |
| event_time             | GREATEST(silver.supply\_status.event_time, silver.weather\_events.event_time)                                                     |

---

#### gold.engagement_analysis

**Purpose**: After-action review of engagements, enriched with attacker's current region, terrain/weather context, and cyber-EW impacts.

**Source Silver Tables**:

-   `silver.engagement_events`\
    (`id`, `attacker_id`, `target_id`, `weapon_id`, `result`, `event_time`)

-   `silver.unit_status_updates`\
    (`unit_id`, `region_id`, `event_time`) → used to resolve **attacker's region** at time of engagement

-   `silver.regions`\
    (`id`, `terrain_type`)

-   `silver.weather_events`\
    (`region_id`, `type`, `intensity`, `event_time`)

-   `silver.cyber_ew_events`\
    (`target_sensor_id`, `effect`, `event_time`)

-   `silver.weapons`\
    (`id`, `hit_probability`)

**Columns**:

| Column | Formula / Source |
| --- | --- |
| engagement_id | `engagement_events.id` |
| attacker_id | `engagement_events.attacker_id` |
| target_id | `engagement_events.target_id` |
| weapon_id | `engagement_events.weapon_id` |
| region_id | From `unit_status_updates.region_id` where `unit_status_updates.unit_id = engagement_events.attacker_id` (closest by `event_time`). |
| result | `engagement_events.result` |
| adjusted_hit_probability | `weapons.hit_probability * (1 - 0.2 * weather_events.intensity * (weather_events.type='fog') - 0.3 * (cyber_ew_events.effect='jammed'))` |
| impact_factor | `(1 - 0.2 * (weather_events.type='fog') - 0.3 * (cyber_ew_events.effect='jammed')) * (CASE regions.terrain_type WHEN 'mountain' THEN 0.8 ELSE 1.0 END)` |
| event_time | `engagement_events.event_time` |

## Indexes
Optimized for PostgreSQL, supporting real-time C2 queries for the MCP chatbot, handling 1M+ events daily with `classification` for security.

### Bronze Layer Indexes
- **General Indexes**:
  - `(ingest_timestamp DESC)`: Auditability.
  - `(source)`: Source tracing.
- **Specific Indexes**:
  - **regions_raw**: `(region_name)` for region lookups.
  - **targets_raw**: `(target_id, threat_level)` for threat tracking.
  - **users_raw**: `(role, classification)` for access control.
  - **detections_raw**: `(target_id, region_id, event_time DESC)` for threat detection.
  - **unit_status_updates_raw**: `(unit_id, region_id, event_time DESC)` for unit tracking.
  - **weather_events_raw**: `(region_id, event_time DESC)` for weather impacts.
  - **engagement_events_raw**: `(attacker_id, target_id, event_time DESC)` for engagement logs.
  - **alerts_raw**: `(detection_id, created_at DESC)` for alert tracking.
  - **commands_raw**: `(alert_id, user_id, event_time DESC)` for C2 actions.

### Silver Layer Indexes
- **General Indexes**:
  - `(event_time DESC)`: Time-based queries.
  - `(domain)`: Domain-specific analytics.
- **Specific Indexes**:
  - **silver.regions**: `(region_name, classification)` for secure region queries.
  - **silver.targets**: `(target_id, threat_level)` for threat prioritization.
  - **silver.users**: `(role, classification)` for access control.
  - **silver.detections**: `(target_id, region_id, threat_level, event_time DESC)`, `(lat, lon, event_time DESC)` for geospatial queries.
  - **silver.unit_status_updates**: `(unit_id, region_id, status, event_time DESC)` for unit tracking.
  - **silver.weather_events**: `(region_id, type, event_time DESC)` for weather analysis.
  - **silver.cyber_ew_events**: `(target_sensor_id, effect, event_time DESC)` for EW analysis.
  - **silver.engagement_events**: `(attacker_id, target_id, result, event_time DESC)` for after-action reviews.
  - **silver.supply_status**: `(unit_id, region_id, event_time DESC)` for logistics.
  - **silver.commands**: `(alert_id, user_id, event_time DESC)` for C2 tracking.

### Gold Layer Indexes
- **General Indexes**:
  - `(event_time DESC)`: Recent data access.
  - `(region_id, classification)`: Secure, region-specific queries.
- **Specific Indexes**:
  - **gold.effective_unit_strength**: `(unit_id, region_id, attacking_strength DESC, event_time DESC)` for combat strength.
  - **gold.threat_assessment**: `(region_id, target_id, threat_level, event_time DESC)` for threat prioritization.
  - **gold.alerts_with_commands**: `(region_id, threat_level, user_id, event_time DESC)` for alert/action tracking.
  - **gold.logistics_readiness**: `(region_id, resupply_feasibility DESC, event_time DESC)` for logistics planning.
  - **gold.engagement_analysis**: `(region_id, target_id, result, event_time DESC)` for after-action reviews.