#!/bin/bash
# MySQL 스키마 초기화 (테이블 + 파티션 생성)
set -e

cd "$(dirname "$0")/.."

echo "[$(date +%H:%M:%S)] init_mysql: dropping and recreating metrics table..."
docker exec -i bench-mysql mysql -uroot -pbench bench < schemas/mysql.sql 2>&1 | grep -v "Using a password" || true
echo "[$(date +%H:%M:%S)] init_mysql: done"

echo "[$(date +%H:%M:%S)] init_mysql: verifying schema..."
docker exec bench-mysql mysql -uroot -pbench bench -e "
    SELECT
        partition_name,
        partition_description,
        table_rows
    FROM information_schema.partitions
    WHERE table_schema='bench' AND table_name='metrics'
    LIMIT 5;
" 2>&1 | grep -v "Using a password" || true
