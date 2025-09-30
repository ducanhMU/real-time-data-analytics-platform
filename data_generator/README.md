# Data Generator Folder

## Overview

The `data_generator` folder generates **synthetic data** for the Bronze layer tables in the PostgreSQL database of the JADC2-inspired Multi-Domain Operations Monitoring System. It simulates **realistic military scenarios** (e.g., threat tracking, secure C2) for testing and development, enabling downstream analytics and chatbot queries.

## Contents

* **make\_data.py** – Python script that generates records for Bronze tables (e.g., `targets`, `commands`, `detections`). Uses [`faker`](https://faker.readthedocs.io/) for realism and supports configurable record counts.
* **requirements.txt** – Lists Python dependencies (`psycopg2-binary==2.9.10`, `faker==22.2.0`).
* **Dockerfile** – Builds a lightweight Docker image (`python:3.9-slim`) for running the script.
* **README.md** – This documentation file.

## Role in Pipeline

* **Purpose**: Populates PostgreSQL Bronze tables with **synthetic operational data**.
* **Pipeline**:

  ```
  PostgreSQL (populated by data_generator) → Debezium (CDC) → Kafka → Flink → MinIO (Iceberg)
  ```
* **Output**: Synthetic events inserted into PostgreSQL and streamed to MinIO Bronze tables via CDC.

## Usage

### Running with Docker Compose

The generator is integrated into the project’s `docker-compose.yml`. Run:

```bash
docker-compose up --build
```

### Passing Arguments

The generator uses **environment variables** to control connection settings and record counts. You can override these at runtime:

```bash
DB_HOST=postgres \
DB_PORT=5432 \
DB_NAME=jadc2 \
DB_USER=admin \
DB_PASSWORD=secret \
DETECTIONS_COUNT=1000 \
TARGETS_COUNT=200 \
docker-compose up --build
```

Common environment variables:

* `DB_HOST` – PostgreSQL host (default: `postgres`).
* `DB_PORT` – PostgreSQL port (default: `5432`).
* `DB_NAME` – Database name (default: `jadc2`).
* `DB_USER` – Database user.
* `DB_PASSWORD` – Database password.
* `DETECTIONS_COUNT` – Number of detection events to generate.
* `TARGETS_COUNT` – Number of targets to simulate.
* `COMMANDS_COUNT` – Number of command events.

## Integration

* **postgresql** – Bronze schema (`init.sql`) defines target tables for insertion.
* **debezium** – Captures inserts/updates and streams them into Kafka.
* **medallion\_DB\_design.md** – Provides Bronze, Silver, and Gold architecture details.

## Notes

* For **production**, use **Docker secrets** to manage `DB_PASSWORD`.
* Adjust record counts (e.g., `DETECTIONS_COUNT`) for load testing or scalability experiments.
* Designed to generate data continuously to simulate a live operational environment.
* See the top-level `README.md` for **end-to-end pipeline setup**.
