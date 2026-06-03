#!/bin/bash
# Usage: ./wait_for_db.sh <mysql|clickhouse>
# 컨테이너가 healthy 상태가 될 때까지 대기

set -e
DB=$1
MAX_WAIT=120

echo "[$(date +%H:%M:%S)] waiting for $DB to be healthy..."
for i in $(seq 1 $MAX_WAIT); do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' bench-$DB 2>/dev/null || echo "starting")
    if [ "$STATUS" = "healthy" ]; then
        echo "[$(date +%H:%M:%S)] $DB is healthy (after ${i}s)"
        exit 0
    fi
    sleep 1
done

echo "[$(date +%H:%M:%S)] ERROR: $DB did not become healthy within ${MAX_WAIT}s"
docker logs --tail 30 bench-$DB
exit 1
