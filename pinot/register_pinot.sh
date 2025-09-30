#!/bin/bash
set -e

PINOT_CONTROLLER="pinot-controller"
PINOT_PORT=9000
SCHEMA_DIR="/opt/pinot/configs/bronze/schemas"
TABLE_DIR="/opt/pinot/configs/bronze/tables"

echo "Waiting for Pinot Controller..."
until curl -s "http://$PINOT_CONTROLLER:$PINOT_PORT/health" > /dev/null; do
  sleep 5
done
echo "Pinot Controller is ready."

# Add all schemas
for schema in "$SCHEMA_DIR"/*.json; do
  echo "Adding schema: $schema"
  curl -s -X POST \
    "http://$PINOT_CONTROLLER:$PINOT_PORT/schemas" \
    -H "Content-Type: application/json" \
    -d @"$schema" \
    || echo "Schema $schema might already exist."
done

# Add or update all tables
for table in "$TABLE_DIR"/*.json; do
  echo "Adding/updating table: $table"

  # Lấy tableName từ file JSON (tránh mismatch)
  TABLE_NAME=$(grep -Po '"tableName"\s*:\s*"\K[^"]+' "$table")

  if [ -z "$TABLE_NAME" ]; then
    echo "Cannot find tableName in $table, skipping..."
    continue
  fi

  # Try to create table first
  resp=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "http://$PINOT_CONTROLLER:$PINOT_PORT/tables" \
    -H "Content-Type: application/json" \
    -d @"$table")

  if [ "$resp" -eq 405 ] || [ "$resp" -eq 400 ]; then
    echo "Table $TABLE_NAME exists, updating with PUT..."
    curl -s -X PUT \
      "http://$PINOT_CONTROLLER:$PINOT_PORT/tables/$TABLE_NAME" \
      -H "Content-Type: application/json" \
      -d @"$table"
  else
    echo "Table $TABLE_NAME created successfully."
  fi
done

echo "All schemas and tables processed."
