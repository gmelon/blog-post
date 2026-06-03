#!/bin/bash
# 적재 후 디스크 사용량 비교
# results/disk_usage.txt 에 기록
set -e

cd "$(dirname "$0")/.."

OUT="results/disk_usage.txt"
mkdir -p results

{
    echo "=== Disk usage comparison ==="
    echo "Measured at: $(date)"
    echo

    echo "[MySQL]"
    docker exec bench-mysql mysql -uroot -pbench bench -e "
        SELECT
            CONCAT(ROUND(SUM(data_length) / 1024 / 1024 / 1024, 2), ' GB') AS data,
            CONCAT(ROUND(SUM(index_length) / 1024 / 1024 / 1024, 2), ' GB') AS index_size,
            CONCAT(ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2), ' GB') AS total,
            SUM(table_rows) AS approx_rows
        FROM information_schema.tables
        WHERE table_schema='bench' AND table_name='metrics';
    " 2>/dev/null
    echo

    echo "[ClickHouse]"
    docker exec bench-clickhouse clickhouse-client --user bench --password bench --query="
        SELECT
            formatReadableSize(sum(data_compressed_bytes))   AS compressed,
            formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed,
            round(sum(data_uncompressed_bytes) / sum(data_compressed_bytes), 2) AS ratio,
            sum(rows) AS total_rows
        FROM system.parts
        WHERE database='bench' AND table='metrics' AND active
        FORMAT Vertical
    "
    echo

    echo "[ClickHouse - per column compression]"
    docker exec bench-clickhouse clickhouse-client --user bench --password bench --query="
        SELECT
            column,
            formatReadableSize(sum(column_data_compressed_bytes))   AS compressed,
            formatReadableSize(sum(column_data_uncompressed_bytes)) AS uncompressed,
            round(sum(column_data_uncompressed_bytes) / sum(column_data_compressed_bytes), 2) AS ratio
        FROM system.parts_columns
        WHERE database='bench' AND table='metrics' AND active
        GROUP BY column
        ORDER BY sum(column_data_compressed_bytes) DESC
        FORMAT PrettyCompact
    "
} | tee "$OUT"
