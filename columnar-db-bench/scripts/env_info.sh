#!/bin/bash
# 측정 환경 정보 수집 → results/environment.md
set -e

cd "$(dirname "$0")/.."
mkdir -p results
OUT="results/environment.md"

{
    echo "# Measurement Environment"
    echo
    echo "## Date"
    date
    echo
    echo "## Hardware"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "- CPU: $(sysctl -n machdep.cpu.brand_string)"
        echo "- CPU cores: $(sysctl -n hw.ncpu)"
        echo "- RAM: $(echo "$(sysctl -n hw.memsize) / 1024 / 1024 / 1024" | bc) GB"
        echo "- Disk: $(diskutil info / | grep "Media Name" | awk -F: '{print $2}' | xargs)"
    else
        echo "- CPU: $(lscpu | grep "Model name" | awk -F: '{print $2}' | xargs)"
        echo "- CPU cores: $(nproc)"
        echo "- RAM: $(free -g | awk '/^Mem:/{print $2}') GB"
    fi
    echo
    echo "## OS"
    echo "- $(uname -srm)"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "- macOS: $(sw_vers -productVersion)"
    fi
    echo
    echo "## Software"
    echo "- Docker: $(docker --version)"
    echo "- Docker Compose: $(docker compose version)"
    echo "- Python: $(python3 --version)"
    echo "- MySQL image: mysql:8.0"
    echo "- ClickHouse image: clickhouse/clickhouse-server:24.10"
    echo
    echo "## Container resources"
    echo "- CPU limit: 4 cores each"
    echo "- Memory limit: 8GB each"
    echo "- MySQL innodb_buffer_pool: 2GB"
    echo "- ClickHouse mark/uncompressed cache: 2GB each"
} > "$OUT"

cat "$OUT"
