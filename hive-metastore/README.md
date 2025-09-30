# Hive Metastore (HMS) 
Standalone Hive Metastore used as the **catalog service** for Iceberg tables in this stack.
This README explains why HMS is used, configuration options (Derby vs PostgreSQL), how to run it in Docker, and how to verify it is working.

---

## Why use Hive Metastore?

- Central metadata/catalog service for Iceberg (and many other query engines).
- Stores table/schema/partition/snapshot metadata (not the data files) so multiple engines (Flink, Spark, Trino, Dremio, etc.) can read/write the same tables consistently.
- Useful for schema evolution and cross-engine compatibility.

---

## Modes: Embedded Derby (quick) vs PostgreSQL (recommended for multiple services)

### Quick / local testing — Embedded Derby
- Simple, zero external DB required.
- Metadata stored inside container (or inside a mounted volume if you persist `/tmp/metastore_db`).
- Good for development and smoke tests.

**Pros:** Easy to run.  
**Cons:** Not suitable for multi-node or production; Derby is file-based, single-writer.

### Production / multi-service — PostgreSQL backend
- Run a dedicated Postgres database (e.g., DB: `hms`, user: `hms`).
- `schematool -dbType postgres -initSchema` initializes the metastore schema.
- Use when multiple services need to share metadata reliably.

**Pros:** Robust, multi-writer safe.  
**Cons:** Requires DB setup + credentials.

---

## Files in this folder (important)

- `conf/hive-site.xml` — Hive Metastore configuration (S3/MinIO + DB settings).  
  - If using Derby keep the Derby `javax.jdo...` entries.  
  - If using Postgres, set JDBC URL and driver & ensure JDBC driver is in container.
- `Dockerfile` — image build steps (jars, debugging tools). The image should expose the HMS thrift on port `9083`.

---

## Docker Compose environment (key env vars)

When you run via `docker-compose.yml` we typically mount `conf/hive-site.xml` into the container and set these env vars:

```yaml
MINIO_ENDPOINT: http://minio:9000
MINIO_ACCESS_KEY: admin
MINIO_SECRET_KEY: password
HMS_LOGLEVEL: INFO

# If you use Postgres backend:
HIVE_METASTORE_DB_HOST: postgres
HIVE_METASTORE_DB_PORT: 5432
HIVE_METASTORE_DB_NAME: hms
HIVE_METASTORE_DB_USER: hms
HIVE_METASTORE_DB_PASSWORD: password
```

**Note**: If you choose `Derby`, you can omit the Postgres envs and remove Postgres dependency from `depends_on`.

## How to run (Derby quick start)

1. Build (if you changed the Dockerfile):
``` bash
docker compose build hive-metastore
```

2. Start Hive Metastore (Derby mode):
``` bash
docker compose up -d hive-metastore
```

3. Tail logs:
``` bash
docker logs -f jadc2-hms
```

- **Expected**: logs show HMS starting and listening on `9083`. Healthcheck should become healthy.
---

- If your Hive image runs `schematool` automatically during start, it will initialize the metastore schema.
---

## Verify HMS is working

1. Confirm container is running:
``` bash
docker ps --filter "name=jadc2-hms"
```

2. Tail logs to confirm HMS bound to Thrift port:
``` bash
docker logs -f jadc2-hms
# Look for "Starting Hive Metastore" and "Listening on 9083" (or similar)
```

3. Check thrift port inside container:
``` bash
docker exec -it jadc2-hms bash -c "nc -z localhost 9083 && echo 'HMS thrift listening' || echo 'HMS thrift not listening'"
```

4. From Flink (or another engine) confirm connectivity:
``` bash
# open Flink SQL client
docker exec -it jadc2-flink ./bin/sql-client.sh

# inside SQL client:
SHOW CATALOGS;
-- or (if using hive catalog) try
USE CATALOG c_iceberg_hive;
SHOW DATABASES;
```

- If HMS is reachable, Iceberg catalogs should be visible (assuming Flink is configured to point to `thrift://hms:9083` and `hive-conf-dir` contains the correct `hive-site.xml`).
---

## Troubleshooting (common problems & fixes)

- HMS container exits immediately (`ExitCode=0`)
   - **Cause**: command: in compose contains only a comment or points to a non-existent file. **Solution**: remove custom command: override and let the base image ENTRYPOINT run.

- HMS cannot connect to Postgres
   - Check DB exists (`\l`) and user exists. If the Postgres volume already exists, init scripts will not re-run; either create DB manually or recreate the volume.

- Missing JDBC / S3 JARs
   - If Hive cannot use MinIO or Postgres driver, confirm JARs exist under `/opt/hive-metastore/lib` inside the image (modify Dockerfile to fetch them).

- Port conflicts
   - Ensure `9083` not used by another container on host.

---

### Persisting Derby metadata (optional)

If you use `Derby` and want metadata to survive container restart, mount `/tmp/metastore_db` to a volume:
``` bash
volumes:
  - ./hive-metastore/metastore_db:/tmp/metastore_db
```
---

## Summary

- For quick dev/tests: use embedded Derby (minimal fuss).

- For multi-service / production-like setups: use Postgres and initialize `hms` DB + `hms` user.

- HMS must be reachable at `thrift://hms:9083` for Flink to correctly resolve Iceberg tables.