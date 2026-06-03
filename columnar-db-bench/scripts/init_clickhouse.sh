#!/bin/bash
# ClickHouse 스키마 초기화
set -e

cd "$(dirname "$0")/.."

echo "[$(date +%H:%M:%S)] init_clickhouse: dropping and recreating metrics table..."
docker exec -i bench-clickhouse clickhouse-client \
    --user bench --password bench --multiquery < schemas/clickhouse.sql
echo "[$(date +%H:%M:%S)] init_clickhouse: done"

echo "[$(date +%H:%M:%S)] init_clickhouse: verifying schema..."
docker exec bench-clickhouse clickhouse-client \
    --user bench --password bench \
    --query="SHOW CREATE TABLE bench.metrics" \
    --format Vertical
