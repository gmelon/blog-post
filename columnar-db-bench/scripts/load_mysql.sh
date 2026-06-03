#!/bin/bash
# MySQL 벌크 적재 (일별 CSV 파일 30개를 차례로 LOAD DATA INFILE)
# 진행 상황 매 파일마다 출력
set -e

cd "$(dirname "$0")/.."

DATA_DIR="$(pwd)/data"
LOG_FILE="logs/load_mysql_$(date +%Y%m%d_%H%M%S).log"
mkdir -p logs

CSV_FILES=("$DATA_DIR"/metrics_*.csv)
TOTAL_FILES=${#CSV_FILES[@]}

if [ $TOTAL_FILES -eq 0 ] || [ ! -e "${CSV_FILES[0]}" ]; then
    echo "ERROR: no CSV files in $DATA_DIR. Run generate.py first." | tee -a "$LOG_FILE"
    exit 1
fi

START_TIME=$(date +%s)
TOTAL_ROWS=0

echo "[$(date +%H:%M:%S)] load_mysql: $TOTAL_FILES files to load" | tee "$LOG_FILE"
echo "[$(date +%H:%M:%S)] load_mysql: applying bulk-load tuning (autocommit=0, unique_checks=0)" | tee -a "$LOG_FILE"
echo "[$(date +%H:%M:%S)] $(printf '=%.0s' {1..70})" | tee -a "$LOG_FILE"

for i in "${!CSV_FILES[@]}"; do
    CSV_FILE="${CSV_FILES[$i]}"
    BASENAME=$(basename "$CSV_FILE")
    CONTAINER_PATH="/data/$BASENAME"
    FILE_SIZE_MB=$(($(stat -f%z "$CSV_FILE" 2>/dev/null || stat -c%s "$CSV_FILE") / 1024 / 1024))
    IDX=$((i + 1))

    FILE_START=$(date +%s)
    echo -n "[$(date +%H:%M:%S)] [$IDX/$TOTAL_FILES] loading $BASENAME (${FILE_SIZE_MB}MB)... " | tee -a "$LOG_FILE"

    # bulk-load 트릭: unique_checks=0, autocommit=0, INSERT 후 COMMIT
    # tags 컬럼은 LOAD DATA에서 무시 (DEFAULT NULL). 구조만 유지.
    # ROW_COUNT()는 LOAD DATA 직후 (COMMIT 이전) 캡처
    PREV_TOTAL="$TOTAL_ROWS"
    docker exec bench-mysql mysql -uroot -pbench bench 2>/dev/null -e "
        SET autocommit=0;
        SET unique_checks=0;
        SET foreign_key_checks=0;
        LOAD DATA INFILE '$CONTAINER_PATH'
            INTO TABLE metrics
            FIELDS TERMINATED BY ','
            LINES TERMINATED BY '\n'
            (ts, host, metric_name, region, env, value, @tags_ignored);
        COMMIT;
    " > /dev/null
    NEW_TOTAL=$(docker exec bench-mysql mysql -uroot -pbench bench -N -B 2>/dev/null -e \
        "SELECT COUNT(*) FROM metrics")
    ROWS=$((NEW_TOTAL - PREV_TOTAL))

    FILE_END=$(date +%s)
    FILE_ELAPSED=$((FILE_END - FILE_START))
    TOTAL_ROWS=$((TOTAL_ROWS + ROWS))

    ELAPSED=$((FILE_END - START_TIME))
    REMAINING=$((TOTAL_FILES - IDX))
    AVG_PER_FILE=$((ELAPSED / IDX))
    ETA=$((AVG_PER_FILE * REMAINING))

    printf "%d rows in %ds (cum: %d rows, %d:%02d elapsed, ETA %d:%02d)\n" \
        "$ROWS" "$FILE_ELAPSED" "$TOTAL_ROWS" \
        "$((ELAPSED / 60))" "$((ELAPSED % 60))" \
        "$((ETA / 60))" "$((ETA % 60))" | tee -a "$LOG_FILE"
done

TOTAL_ELAPSED=$(($(date +%s) - START_TIME))
echo "[$(date +%H:%M:%S)] $(printf '=%.0s' {1..70})" | tee -a "$LOG_FILE"
echo "[$(date +%H:%M:%S)] load_mysql: DONE in $((TOTAL_ELAPSED / 60))min $((TOTAL_ELAPSED % 60))s" | tee -a "$LOG_FILE"
echo "[$(date +%H:%M:%S)] load_mysql: total $TOTAL_ROWS rows loaded" | tee -a "$LOG_FILE"

# 적재 후 통계
echo "[$(date +%H:%M:%S)] verifying..." | tee -a "$LOG_FILE"
docker exec bench-mysql mysql -uroot -pbench bench 2>/dev/null -e "
    SELECT COUNT(*) AS total_rows FROM metrics;
" | tee -a "$LOG_FILE"
