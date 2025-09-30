# PostgreSQL Folder: Bronze Schema

## Overview

The `postgresql` folder manages the **PostgreSQL** database, serving as the data source for the JADC2-inspired Multi-Domain Operations Monitoring System. It defines the **Bronze schema** (`raw`) for raw ingested data and configures **Change Data Capture (CDC)** to stream changes to Kafka via Debezium. This supports real-time analytics for military scenarios such as threat tracking, secure command & control (C2), and situational awareness.

## Contents

* **init.sql** – Creates Bronze schema tables (`raw`) such as `targets`, `regions`, and `units`.
* **create\_publication.sql** – Configures CDC publications for Debezium streaming.
* **README.md** – Documentation of the Bronze schema (this file).

## Role in Pipeline

* **Purpose**: Stores raw operational data in PostgreSQL tables, populated by the `data_generator`.
* **Pipeline**:

  ```
  PostgreSQL (raw data) → Debezium (CDC) → Kafka → Flink → MinIO (Iceberg)
  ```
* **Output**: Streams raw data changes to Kafka topics for downstream processing and ingestion into MinIO Bronze tables.

## Schema Tables

* **regions** – Operational regions (terrain, coordinates).
* **targets** – Hostile entities (missiles, drones, threat levels).
* **users** – Users (commanders, analysts) for C2.
* **units** – Friendly units (tanks, ships, aircraft, status).
* **weapons** – Weapon systems (missiles, range, capabilities).
* **sensors** – Sensors (radar, sonar) linked to units.
* **detections** – Target detections (location, speed, confidence).
* **weather\_events** – Weather conditions (storms, turbulence).
* **unit\_status\_updates** – Unit health, readiness, and location updates.
* **supply\_status** – Supply levels (fuel, ammunition, food).
* **cyber\_ew\_events** – Cyber/electronic warfare events (jamming, spoofing).
* **engagement\_events** – Combat outcomes (hits, misses, damage).
* **roe\_updates** – Rules of Engagement (ROE) updates.
* **alerts** – Threat alerts (status, priority, escalation).
* **commands** – C2 commands issued by authorized users.

All tables include:

* **UUIDs** for primary keys.
* **ENUMs** where applicable for categorical attributes.
* **Audit fields** (`ingest_timestamp`, `source`) for lineage tracking.

## Usage

### Running with Docker Compose

To initialize PostgreSQL with the Bronze schema and CDC configuration:

```bash
sudo systemctl stop postgresql # stop current postgresql process
docker compose up -d postgres 
```

### check

```bash
docker exec -it jadc2-postgres psql -U admin -d jadc2_db # access to psql terminal to check whether the postgresql operate in a properly way
# then in the psql terminal
\dn # list of schemas
SHOW search_path; # show the current schema , which is 'public'
SET search_path TO raw; # in 'init.sql' file, we create tables in schema 'raw', so that we need to switch to it to watch our tables
\dt # list of tables of the current schema
\d alerts # watch specific information of table 'alerts'
\q # exit from psql terminal
```

### Passing Custom Arguments

You can override environment variables such as database name, user, and password. For example:

```bash
DB_NAME=jadc2 \
DB_USER=admin \
DB_PASSWORD=secret \
docker-compose up --build
```

Default values are defined in the `docker-compose.yml` file.

## Integration

* **data\_generator** – Populates PostgreSQL with simulated operational data.
* **debezium** – Captures changes and streams them to Kafka.
* **medallion\_DB\_design.md** – Provides details on the Bronze, Silver, and Gold data layers.

## Notes

* Designed for real-time streaming pipelines.
* Ensures schema evolution handling via Debezium & Kafka.
* See top-level `README.md` for project-wide setup instructions.
