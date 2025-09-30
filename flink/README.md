
# Apache Flink

This README explains how Flink is configured in this repository to consume CDC events from Kafka and persist them into Iceberg tables on MinIO. It includes required connectors/jars, config locations, how to submit your Flink SQL job, and step-by-step checks to verify the pipeline end-to-end.

---

## Overview

**Goal**: read Debezium CDC messages from `Kafka` topics (e.g. `jadc2.raw.*`) and write them into `Iceberg` tables using a Hive catalog with metadata in `Hive Metastore` and data files in `MinIO` (S3-compatible).

Services involved:
- `Kafka` (sources)
- `Debezium` (CDC connector)
- `Flink` (SQL job -> Iceberg sink)
- `MinIO` (S3 object storage for Iceberg)
- `Hive Metastore` (Iceberg catalog metadata)
- `mc` (MinIO client) for inspection

---

## Required software / runtime

- Java 11+ (Flink image is built with Java 11)
- Flink 1.18.x (image used: `apache/flink:1.18.1-scala_2.12-java11`)
- Flink SQL client (bundled with Flink)
- JARs (connectors & dependencies) placed into Flink image `lib` / `plugins` (we include these in the `flink/Dockerfile`):
  - Flink Kafka connector
  - Flink Iceberg connector and corresponding Iceberg runtime
  - Hadoop AWS / S3A and AWS SDK (for MinIO)
  - Hadoop core deps required by S3A and Iceberg

> If you see `ClassNotFoundException` in Flink logs, it's likely a missing JAR — add the correct artifact to `flink/Dockerfile` and rebuild.

---

## Key config files (paths in this repo)

- `./flink/Dockerfile` — builds the Flink image with connector jars and copies configs.
- `./flink/conf/flink-conf.yaml` — Flink runtime options (parallelism, memory, checkpoints).
- `./flink/conf/hive-site.xml` — Hive Metastore connection (`thrift://hms:9083`) and MinIO S3a settings used by the Iceberg Hive catalog.
- `./flink/kafka_to_iceberg.sql` — Flink SQL job file: create Kafka source tables, create Iceberg catalog + tables, and `INSERT INTO` from source → sink.

---

## How Flink connects to Iceberg + MinIO

- Flink uses an **Iceberg Hive catalog** configured via `CREATE CATALOG ... 'catalog-type'='hive'` and `hive-conf-dir` pointing to `./conf` where `hive-site.xml` is mounted.
- `hive-site.xml` contains `fs.s3a.*` properties so Iceberg writes data files to MinIO (`s3a://warehouse/...`).
- Iceberg metadata (table entries) are stored in Hive Metastore (HMS).

---

## Run & Check — step by step

> All commands assume `docker compose` was run in this project root and container names from your compose file (e.g. `jadc2-flink`, `jadc2-kafka`, `jadc2-minio`, `jadc2-mc`, `jadc2-hms`, `jadc2-debezium`) are available.

### 0. Ensure the required services are up
```bash
docker compose up -d kafka debezium minio hive-metastore flink mc
# or to bring up whole stack:
docker compose up -d
```
Check status:
``` bash
docker ps --filter "name=jadc2-" --format "{{.Names}}\t{{.Status}}"
```

### 1. Confirm Debezium connector (if using CDC pipeline)

List connectors:
``` bash
curl -sS http://localhost:8083/connectors | jq .
```

Connector status:
``` bash
curl -sS http://localhost:8083/connectors/<connector-name>/status | jq .
```

### 2. Confirm Kafka topics exist (look for `jadc2.raw.*`)
``` bash
docker exec -it jadc2-kafka kafka-topics --bootstrap-server kafka:9092 --list | grep jadc2 || true
```

### 3. Produce test data (Postgres → Debezium → Kafka)

If you use Postgres + Debezium, create a test row in the source DB:
``` bash
docker exec -it jadc2-postgres psql -U admin -d jadc2_db -c "
CREATE TABLE IF NOT EXISTS public.regions (
  id TEXT PRIMARY KEY,
  region_name TEXT,
  terrain_type TEXT,
  infrastructure_level DECIMAL,
  ingest_timestamp TIMESTAMP WITH TIME ZONE,
  source TEXT
);
INSERT INTO public.regions (id, region_name, terrain_type, infrastructure_level, ingest_timestamp, source)
VALUES ('r-1','Alpha','mountain', 0.75, now(), 'manual');
"
```

Verify message in Kafka:
``` bash
docker exec -it jadc2-kafka --bootstrap-server kafka:9092 \
  --topic jadc2.raw.regions --from-beginning --max-messages 5
```
Expected: Debezium envelope JSON (with `payload.after`, `op`, etc.)

### 4. Submit Flink SQL job (use provided SQL file)

Interactive (blocks your terminal — good for watching startup errors):
``` bash
docker exec -it jadc2-flink bash -c "./bin/sql-client.sh -f /opt/flink/kafka_to_iceberg.sql"
```

Run detached (recommended for long-running streaming):
``` bash
# run SQL client in background and write logs to file inside container
docker exec -d jadc2-flink bash -c "./bin/sql-client.sh -f /opt/flink/kafka_to_iceberg.sql > /tmp/flink_sql.log 2>&1"
# then tail the log
docker exec -it jadc2-flink tail -n 200 /tmp/flink_sql.log
```

### 5. Check Flink UI

Open: http://localhost:8081
- Job should be listed and in `RUNNING` state.
- Check job logs / exceptions if failing.

### 6. Inspect MinIO for Iceberg files

MinIO Console: http://localhost:9001 (user `admin`, password `password`)

Using the `mc` container:
``` bash
# list buckets
docker exec -it jadc2-mc mc ls minio

# list warehouse contents (iceberg root)
docker exec -it jadc2-mc mc ls --recursive minio/warehouse | head -n 50

# find metadata or parquet files
docker exec -it jadc2-mc mc find minio/warehouse --name "metadata*.json" --print
docker exec -it jadc2-mc mc find minio/warehouse --name "*.parquet" --print
```

Expected: folders like `warehouse/<db>/<table>/metadata/` and data files (parquet) and manifest/metadata json files.

### 7. Query Iceberg table using Flink SQL client

Open SQL client:
``` bash
docker exec -it jadc2-flink ./bin/sql-client.sh
```

Then run:
``` bash
USE CATALOG c_iceberg_hive;
USE bronze; -- or the DB name you created
SHOW TABLES;
SELECT * FROM regions_iceberg LIMIT 10;
```
- If rows appear, data is correctly written into Iceberg.
---

## Debugging tips / common errors

- No data in MinIO but Kafka has messages

  - Check Flink job: is it running? Look into `/opt/flink/log` or Flink UI for exceptions.

  - Common cause: Flink missing Iceberg or S3 connector jars → `ClassNotFoundException`.

  - Add the missing jar to `flink/Dockerfile` and `lib/`, then rebuild.

- Flink → S3 (MinIO) access denied

  - Verify `fs.s3a.*` keys & endpoint in both `flink/conf/hive-site.xml` and `hive-metastore/conf/hive-site.xml`.

  - Ensure `fs.s3a.path.style.access=true` for MinIO.

- Iceberg table not visible / HMS errors

  - Ensure Hive Metastore is reachable at `thrift://hms:9083` from the Flink container.

  - Check HMS logs: `docker logs -f jadc2-hms`.

  - Ensure the Hive client config (`hive-site.xml`) is mounted to Flink and proper `hive-conf-dir` path is used in `CREATE CATALOG`.

- Debezium messages not appearing in Kafka

  - Validate connector status via http://localhost:8083/connectors.

  - Validate Postgres logical decoding configuration (`wal_level`, `replication slots`).
---

## Where to add/adjust jars (if you must rebuild Flink image)

`flink/Dockerfile` is set to download the required jars into `./lib/*` or `./plugins/*`. Add missing artifacts there and run:
``` bash
docker compose build flink
docker compose up -d flink
```
---

## Quick smoke test (summary commands)
``` bash
# bring up core services
docker compose up -d kafka debezium minio hive-metastore flink mc

# produce a test row (postgres -> debezium -> kafka)
docker exec -it jadc2-postgres psql -U admin -d jadc2_db -c "INSERT INTO public.regions (id,region_name,terrain_type,ingest_timestamp,source) VALUES ('r-1','Alpha','mountain', now(), 'manual');"

# check kafka
docker exec -it jadc2-kafka --bootstrap-server kafka:9092 --topic jadc2.raw.regions --from-beginning --max-messages 5

# submit SQL job
docker exec -d jadc2-flink bash -c "./bin/sql-client.sh -f /opt/flink/kafka_to_iceberg.sql > /tmp/flink_sql.log 2>&1"
docker exec -it jadc2-flink tail -f /tmp/flink_sql.log

# check minio objects
docker exec -it jadc2-mc mc ls --recursive minio/warehouse | head -n 50

# query with Flink SQL client
docker exec -it jadc2-flink ./bin/sql-client.sh
# then run SQL queries as shown earlier
```
---

## Final notes

- For local development prefer `Derby` for `HMS` and persist `MinIO` with a docker volume so you don't lose data during restarts.

- For any errors, collect logs from:

  - `docker logs jadc2-flink`

  - `docker logs jadc2-debezium`

  - `docker logs jadc2-kafka`

  - `docker logs jadc2-hms`

  - `docker logs jadc2-minio`

  - `docker exec -it jadc2-mc mc ls --recursive minio/warehouse`
