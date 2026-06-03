#!/bin/bash
# Q2 + Projection 데모
# 1. Projection 없을 때 Q2 베이스라인 측정
# 2. Projection 추가 + MATERIALIZE (~3-5분)
# 3. 같은 Q2 재측정
# 4. Projection 제거 (cleanup)
# 5. 디스크 사용량 before/after 비교
#
# 결과: results/projection_demo.csv (with vs without 비교 표)
set -e

cd "$(dirname "$0")/.."

ITERATIONS=5
LOG="logs/projection_demo_$(date +%Y%m%d_%H%M%S).log"
RESULT="results/projection_demo.csv"

mkdir -p logs results
exec > >(tee -a "$LOG") 2>&1

log() { echo "[$(date +%H:%M:%S)] $*"; }
sep() { echo "$(printf '=%.0s' {1..70})"; }

sudo -v
( while true; do sudo -n true; sleep 60; done ) &
SUDO_PID=$!
trap 'kill $SUDO_PID 2>/dev/null; cleanup_projection' EXIT

cleanup_projection() {
    log "cleanup: dropping projection if exists..."
    docker exec bench-clickhouse clickhouse-client --user bench --password bench --database bench \
        --query="ALTER TABLE bench.metrics DROP PROJECTION IF EXISTS p_region SETTINGS mutations_sync = 2" \
        2>/dev/null || true
}

drop_caches() {
    log "dropping caches..."
    docker compose stop clickhouse > /dev/null 2>&1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sudo purge
    else
        sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    fi
    docker compose start clickhouse > /dev/null 2>&1
    ./scripts/wait_for_db.sh clickhouse > /dev/null
    sleep 3
}

run_q2() {
    local start=$(python3 -c 'import time; print(int(time.time()*1000))')
    docker exec -i bench-clickhouse clickhouse-client \
        --user bench --password bench --database bench \
        < queries/q2_region_agg_clickhouse.sql > /dev/null
    local end=$(python3 -c 'import time; print(int(time.time()*1000))')
    echo $((end - start))
}

disk_usage() {
    docker exec bench-clickhouse clickhouse-client --user bench --password bench --query="
        SELECT
            formatReadableSize(sum(data_compressed_bytes))   AS compressed,
            formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed,
            sum(rows)                                         AS total_rows
        FROM system.parts
        WHERE database='bench' AND table='metrics' AND active
        FORMAT PrettyCompact
    "
}

measure_baseline() {
    sep
    log "1단계: Projection 없을 때 베이스라인 측정"
    sep
    drop_caches
    log "Q2 cold..."
    local cold=$(run_q2)
    log "  cold: ${cold}ms"
    echo "no,cold,1,$cold" >> "$RESULT"
    log "warm-up (discarded)..."
    run_q2 > /dev/null
    for i in $(seq 1 $ITERATIONS); do
        local t=$(run_q2)
        log "  warm $i/$ITERATIONS: ${t}ms"
        echo "no,warm,$i,$t" >> "$RESULT"
    done
    log "Disk usage (baseline):"
    disk_usage
}

add_projection() {
    sep
    log "2단계: Projection 추가"
    sep
    log "ALTER TABLE ADD PROJECTION p_region..."
    docker exec bench-clickhouse clickhouse-client --user bench --password bench --database bench --query="
ALTER TABLE bench.metrics ADD PROJECTION p_region (
    SELECT * ORDER BY (region, metric_name, ts)
)
"
    log "MATERIALIZE PROJECTION (수 분 소요 예상)..."
    local mat_start=$(date +%s)
    docker exec bench-clickhouse clickhouse-client --user bench --password bench --database bench --query="
ALTER TABLE bench.metrics MATERIALIZE PROJECTION p_region SETTINGS mutations_sync = 2
"
    local mat_end=$(date +%s)
    local mat_elapsed=$((mat_end - mat_start))
    log "  머지 완료: ${mat_elapsed}초 ($((mat_elapsed / 60))분 $((mat_elapsed % 60))초)"
    log "Disk usage (after projection):"
    disk_usage
}

measure_with_projection() {
    sep
    log "3단계: Projection 있을 때 재측정"
    sep
    drop_caches
    log "Q2 cold..."
    local cold=$(run_q2)
    log "  cold: ${cold}ms"
    echo "yes,cold,1,$cold" >> "$RESULT"
    log "warm-up (discarded)..."
    run_q2 > /dev/null
    for i in $(seq 1 $ITERATIONS); do
        local t=$(run_q2)
        log "  warm $i/$ITERATIONS: ${t}ms"
        echo "yes,warm,$i,$t" >> "$RESULT"
    done
}

drop_projection() {
    sep
    log "4단계: Projection 제거 (cleanup)"
    sep
    docker exec bench-clickhouse clickhouse-client --user bench --password bench --database bench --query="
ALTER TABLE bench.metrics DROP PROJECTION p_region SETTINGS mutations_sync = 2
"
    log "Disk usage (after cleanup):"
    disk_usage
    log "cleanup done"
}

# ============== 메인 흐름 ==============
sep
log "Q2 + Projection 데모"
log "쿼리: queries/q2_region_agg_clickhouse.sql (7일 region 분 단위 집계)"
log "iterations: 콜드 1 + 웜 ${ITERATIONS}"
sep

echo "projection,run_type,iteration,time_ms" > "$RESULT"

measure_baseline
add_projection
measure_with_projection
drop_projection

# 결과 요약
sep
log "데모 완료. 결과: $RESULT"
sep
log "요약 (warm avg):"
python3 -c "
import csv
import statistics
by = {}
with open('$RESULT') as f:
    for row in csv.DictReader(f):
        key = (row['projection'], row['run_type'])
        by.setdefault(key, []).append(int(row['time_ms']))

for proj in ('no', 'yes'):
    cold = by.get((proj, 'cold'), [None])[0]
    warm = by.get((proj, 'warm'), [])
    warm_avg = statistics.mean(warm) if warm else None
    print(f'  projection={proj}: cold={cold}ms, warm_avg={warm_avg:.0f}ms')

n = statistics.mean(by.get(('no','warm'),[1]))
y = statistics.mean(by.get(('yes','warm'),[1]))
if y > 0:
    print(f'  speedup (with vs without): {n/y:.1f}x')
"
