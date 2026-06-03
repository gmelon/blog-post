#!/bin/bash
# 메인 벤치마크 — Q1~Q7 × 2 DB × (콜드 1 + 웜 5회)
# 변인 통제:
#   - 콜드: 컨테이너 재시작 + sudo purge (OS page cache)
#   - 웜: 같은 쿼리 1회 (warm-up, 측정 X) + 5회 측정
# 결과:
#   - results/all.csv: db,query,run_type,iteration,time_ms,rows_returned
#   - results/explain/: 각 쿼리 EXPLAIN 결과
#   - logs/benchmark_<timestamp>.log: 전체 실행 로그

set -e

cd "$(dirname "$0")/.."

ITERATIONS=5
DBS=(mysql clickhouse)

# subset 모드 — 인자로 쿼리명 받으면 그것만 실행
if [ $# -gt 0 ]; then
    QUERIES=("$@")
    SUBSET_MODE=1
else
    QUERIES=(q1_single_host q2_region_agg q3_alert_scan q4_downsample q5_top_n q6_single_insert q7_bulk_backfill)
    SUBSET_MODE=0
fi

RESULTS_DIR="results"
EXPLAIN_DIR="$RESULTS_DIR/explain"
LOG_FILE="logs/benchmark_$(date +%Y%m%d_%H%M%S).log"
if [ $SUBSET_MODE -eq 1 ]; then
    RESULT_FILE="$RESULTS_DIR/subset_$(date +%Y%m%d_%H%M%S).csv"
else
    RESULT_FILE="$RESULTS_DIR/all.csv"
fi

mkdir -p "$RESULTS_DIR" "$EXPLAIN_DIR" logs

# tee 통해 모든 출력을 로그 파일에도 기록
exec > >(tee -a "$LOG_FILE") 2>&1

# ================ 유틸 ================
log() { echo "[$(date +%H:%M:%S)] $*"; }
sep() { echo "$(printf '=%.0s' {1..70})"; }
section() { sep; log "$*"; sep; }

# sudo 비밀번호 캐시 미리 활성화
sudo -v
( while true; do sudo -n true; sleep 60; done ) &
SUDO_REFRESH_PID=$!
trap 'kill $SUDO_REFRESH_PID 2>/dev/null' EXIT

# ================ 캐시 클리어 ================
drop_caches() {
    local db=$1
    log "dropping caches for $db..."
    docker compose stop $db > /dev/null 2>&1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sudo purge
    else
        sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    fi
    docker compose start $db > /dev/null 2>&1
    ./scripts/wait_for_db.sh $db > /dev/null
    sleep 3   # health check 후 안정화 잠시
}

# ================ 단일 쿼리 실행 + 시간 측정 (ms) ================
run_query() {
    local db=$1
    local query=$2

    # Q6는 별도 runner (단건 INSERT 1000회 묶음)
    if [[ "$query" == "q6_single_insert" ]]; then
        python3 scripts/q6_runner.py $db
        return
    fi

    # Q7은 별도 bulk load
    if [[ "$query" == "q7_bulk_backfill" ]]; then
        run_q7_backfill $db
        return
    fi

    # DB별로 다른 SQL이 있는 쿼리 (q2_region_agg, q4_downsample 등) 자동 감지
    local sql_file="queries/${query}_${db}.sql"
    if [ ! -f "$sql_file" ]; then
        sql_file="queries/${query}.sql"
    fi

    if [[ "$db" == "mysql" ]]; then
        # MySQL: stdin으로 SQL 파일 주입 — -i 필수 (없으면 docker exec가 stdin 전달 안 함)
        local start=$(python3 -c 'import time; print(int(time.time()*1000))')
        docker exec -i bench-mysql mysql -uroot -pbench bench -N -B < "$sql_file" > /dev/null 2>&1
        local end=$(python3 -c 'import time; print(int(time.time()*1000))')
        echo $((end - start))
    else
        local start=$(python3 -c 'import time; print(int(time.time()*1000))')
        docker exec -i bench-clickhouse clickhouse-client \
            --user bench --password bench --database bench < "$sql_file" > /dev/null 2>&1
        local end=$(python3 -c 'import time; print(int(time.time()*1000))')
        echo $((end - start))
    fi
}

# ================ Q7 벌크 백필 (별도 적재 시간 측정) ================
run_q7_backfill() {
    local db=$1
    if [ ! -f data/backfill_1hour.csv ]; then
        log "generating backfill CSV..." >&2
        python3 scripts/gen_backfill.py >&2
    fi

    # 기존 backfill 영역 제거 (재실행 가능)
    if [[ "$db" == "mysql" ]]; then
        docker exec bench-mysql mysql -uroot -pbench bench -e \
            "DELETE FROM metrics WHERE ts >= '2026-05-31 00:00:00' AND ts < '2026-05-31 01:00:00'" \
            > /dev/null 2>&1
    else
        docker exec bench-clickhouse clickhouse-client --user bench --password bench --query \
            "ALTER TABLE bench.metrics DELETE WHERE ts >= '2026-05-31 00:00:00' AND ts < '2026-05-31 01:00:00' SETTINGS mutations_sync = 2" \
            > /dev/null 2>&1
    fi

    local start=$(python3 -c 'import time; print(int(time.time()*1000))')
    if [[ "$db" == "mysql" ]]; then
        docker exec bench-mysql mysql -uroot -pbench bench -e "
            SET autocommit=0;
            SET unique_checks=0;
            LOAD DATA INFILE '/data/backfill_1hour.csv'
                INTO TABLE metrics
                FIELDS TERMINATED BY ','
                LINES TERMINATED BY '\n'
                (ts, host, metric_name, region, env, value, @tags_ignored);
            COMMIT;
        " > /dev/null 2>&1
    else
        cat data/backfill_1hour.csv | docker exec -i bench-clickhouse clickhouse-client \
            --user bench --password bench \
            --query="INSERT INTO bench.metrics
                     SELECT ts, host, metric_name, region, env, value, map() AS tags
                     FROM input('ts DateTime, host String, metric_name String, region String, env String, value Float64, tags String')
                     FORMAT CSV" > /dev/null 2>&1
    fi
    local end=$(python3 -c 'import time; print(int(time.time()*1000))')
    echo $((end - start))
}

# ================ EXPLAIN 캡처 (1회만) ================
capture_explain() {
    local db=$1
    local query=$2

    if [[ "$query" == "q6_single_insert" || "$query" == "q7_bulk_backfill" ]]; then
        return  # bulk/runner 쿼리는 EXPLAIN 의미 X
    fi

    local sql_file="queries/${query}_${db}.sql"
    if [ ! -f "$sql_file" ]; then
        sql_file="queries/${query}.sql"
    fi

    local out_file="$EXPLAIN_DIR/${db}_${query}.txt"
    if [[ "$db" == "mysql" ]]; then
        local sql_content=$(cat "$sql_file")
        docker exec bench-mysql mysql -uroot -pbench bench -e \
            "EXPLAIN FORMAT=JSON $sql_content" > "$out_file" 2>&1
    else
        local sql_content=$(cat "$sql_file")
        docker exec bench-clickhouse clickhouse-client \
            --user bench --password bench --database bench \
            --query="EXPLAIN PLAN $sql_content" > "$out_file" 2>&1
    fi
}

# ================ 메인 루프 ================
section "BENCHMARK START at $(date)"
log "iterations: $ITERATIONS warm runs per query"
log "queries: ${QUERIES[*]}"
log "DBs: ${DBS[*]}"
log "result file: $RESULT_FILE"
log "log file: $LOG_FILE"

# 결과 헤더
echo "db,query,run_type,iteration,time_ms" > "$RESULT_FILE"

TOTAL_TASKS=$((${#DBS[@]} * ${#QUERIES[@]}))
TASK_IDX=0
BENCH_START=$(date +%s)

for db in "${DBS[@]}"; do
    for query in "${QUERIES[@]}"; do
        TASK_IDX=$((TASK_IDX + 1))
        section "[$TASK_IDX/$TOTAL_TASKS] $db / $query"

        # EXPLAIN 캡처 (1회만)
        log "capturing EXPLAIN..."
        capture_explain $db $query || log "  EXPLAIN failed (non-fatal)"

        # 콜드 측정
        drop_caches $db
        log "running COLD..."
        cold_ms=$(run_query $db $query)
        log "  COLD: ${cold_ms}ms"
        echo "$db,$query,cold,1,$cold_ms" >> "$RESULT_FILE"

        # Warm-up (측정 X)
        log "warm-up (discarded)..."
        run_query $db $query > /dev/null

        # 웜 측정 N회
        for i in $(seq 1 $ITERATIONS); do
            warm_ms=$(run_query $db $query)
            log "  WARM $i/$ITERATIONS: ${warm_ms}ms"
            echo "$db,$query,warm,$i,$warm_ms" >> "$RESULT_FILE"
        done

        # ETA 계산
        ELAPSED=$(($(date +%s) - BENCH_START))
        AVG_PER_TASK=$((ELAPSED / TASK_IDX))
        REMAINING=$((TOTAL_TASKS - TASK_IDX))
        ETA=$((AVG_PER_TASK * REMAINING))
        log "  progress: $TASK_IDX/$TOTAL_TASKS done, elapsed $((ELAPSED / 60))m$((ELAPSED % 60))s, ETA $((ETA / 60))m$((ETA % 60))s"
    done
done

TOTAL_ELAPSED=$(($(date +%s) - BENCH_START))
section "BENCHMARK DONE in $((TOTAL_ELAPSED / 60))m $((TOTAL_ELAPSED % 60))s"
log "results: $RESULT_FILE"
log "logs: $LOG_FILE"

# 요약 즉시 출력
log "running quick summary..."
python3 scripts/analyze.py "$RESULT_FILE"
