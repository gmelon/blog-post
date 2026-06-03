#!/bin/bash
# ClickHouse 벌크 적재 (일별 CSV 파일 30개를 차례로 INSERT FROM INFILE)
# 진행 상황 매 파일마다 출력
set -e

cd "$(dirname "$0")/.."

DATA_DIR="$(pwd)/data"
LOG_FILE="logs/load_clickhouse_$(date +%Y%m%d_%H%M%S).log"
mkdir -p logs

CSV_FILES=("$DATA_DIR"/metrics_*.csv)
TOTAL_FILES=${#CSV_FILES[@]}

if [ $TOTAL_FILES -eq 0 ] || [ ! -e "${CSV_FILES[0]}" ]; then
    echo "ERROR: no CSV files in $DATA_DIR. Run generate.py first." | tee -a "$LOG_FILE"
    exit 1
fi

START_TIME=$(date +%s)
TOTAL_ROWS=0

echo "[$(date +%H:%M:%S)] load_clickhouse: $TOTAL_FILES files to load" | tee "$LOG_FILE"
echo "[$(date +%H:%M:%S)] $(printf '=%.0s' {1..70})" | tee -a "$LOG_FILE"

for i in "${!CSV_FILES[@]}"; do
    CSV_FILE="${CSV_FILES[$i]}"
    BASENAME=$(basename "$CSV_FILE")
    CONTAINER_PATH="/data/$BASENAME"
    FILE_SIZE_MB=$(($(stat -f%z "$CSV_FILE" 2>/dev/null || stat -c%s "$CSV_FILE") / 1024 / 1024))
    IDX=$((i + 1))

    FILE_START=$(date +%s)
    echo -n "[$(date +%H:%M:%S)] [$IDX/$TOTAL_FILES] loading $BASENAME (${FILE_SIZE_MB}MB)... " | tee -a "$LOG_FILE"

    # stdin 파이핑 — input() 함수로 CSV의 7개 컬럼 (마지막 tags는 빈 문자열) 받아서
    # tags 는 빈 Map 으로 변환해 INSERT
    PREV_TOTAL="$TOTAL_ROWS"
    cat "$CSV_FILE" | docker exec -i bench-clickhouse clickhouse-client \
        --user bench --password bench \
        --query="INSERT INTO bench.metrics
                 SELECT ts, host, metric_name, region, env, value, map() AS tags
                 FROM input('ts DateTime, host String, metric_name String, region String, env String, value Float64, tags String')
                 FORMAT CSV" 2>&1 | tee -a "$LOG_FILE"

    NEW_TOTAL=$(docker exec bench-clickhouse clickhouse-client \
        --user bench --password bench \
        --query="SELECT count() FROM bench.metrics" 2>/dev/null || echo "0")
    ROWS=$((NEW_TOTAL - PREV_TOTAL))

    FILE_END=$(date +%s)
    FILE_ELAPSED=$((FILE_END - FILE_START))
    TOTAL_ROWS=$((TOTAL_ROWS + ROWS))

    ELAPSED=$((FILE_END - START_TIME))
    REMAINING=$((TOTAL_FILES - IDX))
    AVG_PER_FILE=$((ELAPSED / IDX))
    ETA=$((AVG_PER_FILE * REMAINING))

    printf "[%s] [%d/%d] done in %ds (cum: %d rows, %d:%02d elapsed, ETA %d:%02d)\n" \
        "$(date +%H:%M:%S)" "$IDX" "$TOTAL_FILES" "$FILE_ELAPSED" "$TOTAL_ROWS" \
        "$((ELAPSED / 60))" "$((ELAPSED % 60))" \
        "$((ETA / 60))" "$((ETA % 60))" | tee -a "$LOG_FILE"
done

TOTAL_ELAPSED=$(($(date +%s) - START_TIME))
echo "[$(date +%H:%M:%S)] $(printf '=%.0s' {1..70})" | tee -a "$LOG_FILE"
echo "[$(date +%H:%M:%S)] load_clickhouse: DONE in $((TOTAL_ELAPSED / 60))min $((TOTAL_ELAPSED % 60))s" | tee -a "$LOG_FILE"

# 적재 후 통계
echo "[$(date +%H:%M:%S)] verifying..." | tee -a "$LOG_FILE"
docker exec bench-clickhouse clickhouse-client \
    --user bench --password bench \
    --query="SELECT count() AS total_rows FROM bench.metrics" | tee -a "$LOG_FILE"

# OPTIMIZE FINAL — 머지 강제 (벤치 fair 측정 위해)
echo "[$(date +%H:%M:%S)] running OPTIMIZE TABLE FINAL for stable measurement..." | tee -a "$LOG_FILE"
docker exec bench-clickhouse clickhouse-client \
    --user bench --password bench \
    --query="OPTIMIZE TABLE bench.metrics FINAL" 2>&1 | tee -a "$LOG_FILE"
echo "[$(date +%H:%M:%S)] OPTIMIZE done" | tee -a "$LOG_FILE"
