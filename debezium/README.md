# CDC Pipeline: PostgreSQL → Debezium → Kafka

This repository demonstrates how to set up a **Change Data Capture (CDC) pipeline** from PostgreSQL to Kafka using **Debezium**, enabling near real-time data replication and streaming.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
  - [1. Start Docker Containers](#1-start-docker-containers)
  - [2. Configure PostgreSQL](#2-configure-postgresql)
  - [3. Set up Debezium PostgreSQL Connector](#3-set-up-debezium-postgresql-connector)
  - [4. Consume Kafka Topics](#4-consume-kafka-topics)
- [Verification](#verification)
- [Cleanup](#cleanup)

---

## Overview

A **CDC (Change Data Capture) pipeline** allows capturing changes (insert, update, delete) in a database table in **near real-time** and streaming them to downstream systems, such as Kafka, data warehouses, or data lakes.  

**Components:**

- **PostgreSQL**: The source database where data changes occur. Debezium reads its **WAL (Write-Ahead Log)** to detect changes.  
- **Debezium**: A CDC connector that captures database changes and publishes them to Kafka topics.  
- **Kafka**: A distributed messaging system that stores the captured events. Downstream systems consume these events for analytics or ETL.  
- **Consumer / ETL applications**: Read the Kafka topics to update downstream storage or perform analytics.  

CDC is often preferred over batch ETL because it **reduces latency** and ensures **near real-time consistency** between source and target systems.

**Notes**

- Each table included in the connector has a dedicated Kafka topic.
- Events include `before` and `after` states plus operation type (`c`=insert, `u`=update, `d`=delete).

---

## Architecture

``` bash
PostgreSQL --> Debezium (Kafka Connect) --> Kafka Topics --> Consumers / Applications
```


### Component Details

- **PostgreSQL**: Must have **logical replication** enabled. This allows Debezium to track changes using replication slots without interfering with normal operations.  
- **Debezium / Kafka Connect**: Monitors PostgreSQL WAL, converts changes into events, and publishes them to Kafka topics. Each table can correspond to a Kafka topic.  
- **Kafka**: Provides durable storage for the change events. Kafka topics can be partitioned and replicated for scalability and fault tolerance.  
- **Consumer**: Any application that subscribes to the Kafka topic can process the changes in near real-time.  

---

## Prerequisites

- Docker and Docker Compose installed
- Basic knowledge of PostgreSQL and Kafka
- Optional: `jq` for pretty-printing Kafka messages

---

## Setup

### 1. Start Docker Containers

All services (PostgreSQL, Zookeeper, Kafka, Debezium, Kafka UI) are defined in `docker-compose.yml`. 

**Start all containers:**
``` bash
docker compose up -d
```

**Check logs to verify they started successfully:**
``` bash
docker logs -f jadc2-kafka
docker logs -f jadc2-debezium
```

### 2. Configure PostgreSQL

Debezium requires **logical replication** to capture changes.

**Enable logical replication and replication slots:**
``` yaml
command:
  - "postgres"
  - "-c"
  - "wal_level=logical"
  - "-c"
  - "max_wal_senders=10"
  - "-c"
  - "max_replication_slots=10"
```

**Load initial SQL and publication files via:**

``` bash
volumes:
  - ./postgresql/init.sql:/docker-entrypoint-initdb.d/init.sql
  - ./postgresql/create_publication.sql:/docker-entrypoint-initdb.d/create_publication.sql
```

**Publication allows Debezium to track selected tables:**
``` sql
CREATE PUBLICATION dbz_publication FOR ALL TABLES;
```

### 3. Set up Debezium Connector

Debezium is deployed via **Kafka Connect**. Connector configuration specifies which database, tables, and replication slot to use. Debezium container automatically registers a connector from: `./debezium/register-postgres.json`.

``` json
{
  "name": "jadc2-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "tasks.max": "1",

    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "admin",
    "database.password": "password",
    "database.dbname": "jadc2_db",

    "topic.prefix": "jadc2",
    "schema.include.list": "raw",
    "table.include.list": "raw.regions,raw.targets,raw.users,raw.units,raw.weapons,raw.sensors,raw.detections,raw.weather_events,raw.unit_status_updates,raw.supply_status,raw.cyber_ew_events,raw.engagement_events,raw.roe_updates,raw.alerts,raw.commands",
   
    "plugin.name": "pgoutput",
    "slot.name": "debezium",
    "publication.name": "dbz_publication",

    "decimal.handling.mode": "string",
    "tombstones.on.delete": "false",

    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "false",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",

    "snapshot.mode": "initial"
  }
}
```

**Register the connector:**
``` bash
volumes:
  - ./debezium/register-postgres.json:/kafka/config/register-postgres.json:ro
command: >
  bash -c '
    echo "Waiting for Kafka..."
    cub kafka-ready -b kafka:9092 1 30

    echo "Starting Kafka Connect..."
    /docker-entrypoint.sh start &

    echo "Waiting for Connect to start..."
    until curl -s -o /dev/null -w "%{http_code}" http://localhost:8083/connectors | grep -q 200; do
      sleep 2
    done

    echo "Registering connector..."
    curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" http://localhost:8083/connectors/ -d @/kafka/config/register-postgres.json || true

    wait
  '
```

**Check connector status:**
``` bash
curl -H "Accept:application/json" localhost:8083/connectors/jadc2-connector/status
```

### 4. Consume Kafka Topics

After the connector runs, changes will appear in Kafka topics. Each table has its topic: e.g., `jadc2.raw.users`.

**Install Kafka client:**
``` bash
curl -O https://dlcdn.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz
tar -xzf kafka_2.13-3.9.0.tgz
```

**Consume messages:**
``` bash
kafka_2.13-3.9.0/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic jadc2.raw.users \
  --from-beginning | jq
```

Messages contain **before/after states** and **operation type** (`c` **insert**, `u` **update**, `d` **delete**):
``` json
{
  "before": null,
  "after": { 
    "id": 1, 
    "first_name": "Alice", 
    "last_name": "Smith", 
    "email": "alice.smith@example.com" 
  },
  "source": { ... },
  "op": "c",
  "ts_ms": 1695140000000
}
```

## 5️⃣ Monitor / Track Components

Once the pipeline is running, you can **monitor the status of each component** through the following URLs and commands:

| Component | Purpose | How to Check |
|-----------|---------|--------------|
| **Kafka UI** | View Kafka topics, messages, partitions, consumer groups | [http://localhost:8080](http://localhost:8080) |
| **Debezium Connector** | Check connector status, offsets, snapshot progress | `curl -H "Accept:application/json" localhost:8083/connectors/jadc2-connector/status` |
| **Kafka Topics** | List topics, verify data | ```docker exec -it jadc2-kafka kafka-topics --bootstrap-server kafka:9092 --list``` |
| **Kafka Console Consumer** | View messages in a topic directly | ```docker exec -it jadc2-kafka kafka-console-consumer --bootstrap-server kafka:9092 --topic jadc2.raw.users --from-beginning``` |
| **PostgreSQL** | Check source data, publications, replication slots | ```docker exec -it jadc2-postgres psql -U admin -d jadc2_db``` |

### Notes

1. **Kafka UI** ([http://localhost:8080](http://localhost:8080)) is the most visual way to inspect **topics, messages, and consumer groups**.  
2. **Debezium status endpoint** shows whether the connector is performing a **snapshot or streaming CDC**, and whether any errors exist.  
3. **Kafka console consumer** is useful to verify **new data pushed by Debezium**.  
4. **PostgreSQL** remains the source of truth; you can **INSERT / UPDATE / DELETE** rows to test the CDC pipeline.

## Verification

- Perform `INSERT`, `UPDATE`, or `DELETE` operations in `PostgreSQL` and verify that the changes appear in the corresponding `Kafka` topics. On the first run, perform a `read` operation to capture and confirm the `existing records`, which serves as the `initial snapshot` for the `CDC` pipeline.

- Use `kafka-ui` or `kafka-console-consumer` to monitor the events.

## Cleanup

**Stop and remove all containers:**
``` bash
docker compose down -v
```

**Remove Docker volumes if needed:**
``` bash
docker volume rm postgres_data kafka_data
```