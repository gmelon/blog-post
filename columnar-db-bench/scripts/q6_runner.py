#!/usr/bin/env python3
"""Q6 단건 INSERT 1000회 실행기.

각 DB에 대해 1000개의 unique timestamp INSERT를 단일 connection으로 순차 실행.
실행 시간 측정 → ms 단위로 stdout 출력.

Usage:
    python q6_runner.py mysql      # 1000 single INSERTs to MySQL
    python q6_runner.py clickhouse # 1000 single INSERTs to ClickHouse
"""
import datetime as dt
import subprocess
import sys
import time


N_INSERTS = 1000
BASE_TS = dt.datetime(2026, 5, 31, 12, 0, 0)


def gen_mysql_sql():
    """1000개의 INSERT (서로 다른 ts) 한 묶음. 각 ts는 +1초씩."""
    lines = []
    for i in range(N_INSERTS):
        ts = (BASE_TS + dt.timedelta(seconds=i)).strftime("%Y-%m-%d %H:%M:%S")
        lines.append(
            f"INSERT INTO metrics (ts, host, metric_name, region, env, value, tags) "
            f"VALUES ('{ts}', 'task-01', 'cpu_user', 'us-east', 'prod', 45.6, NULL);"
        )
    return "\n".join(lines)


def gen_clickhouse_sql():
    """ClickHouse 동일 형식. 단건 INSERT 1000개를 줄 단위로."""
    lines = []
    for i in range(N_INSERTS):
        ts = (BASE_TS + dt.timedelta(seconds=i)).strftime("%Y-%m-%d %H:%M:%S")
        lines.append(
            f"INSERT INTO bench.metrics (ts, host, metric_name, region, env, value, tags) "
            f"VALUES ('{ts}', 'task-01', 'cpu_user', 'us-east', 'prod', 45.6, map());"
        )
    return "\n".join(lines)


def run_mysql():
    sql = gen_mysql_sql()
    t0 = time.time()
    p = subprocess.run(
        ["docker", "exec", "-i", "bench-mysql", "mysql", "-uroot", "-pbench", "bench"],
        input=sql, capture_output=True, text=True,
    )
    elapsed_ms = int((time.time() - t0) * 1000)
    if p.returncode != 0:
        print(f"ERROR (mysql): {p.stderr}", file=sys.stderr)
        sys.exit(1)
    return elapsed_ms


def run_clickhouse():
    sql = gen_clickhouse_sql()
    t0 = time.time()
    p = subprocess.run(
        ["docker", "exec", "-i", "bench-clickhouse", "clickhouse-client",
         "--user", "bench", "--password", "bench", "--multiquery"],
        input=sql, capture_output=True, text=True,
    )
    elapsed_ms = int((time.time() - t0) * 1000)
    if p.returncode != 0:
        print(f"ERROR (clickhouse): {p.stderr}", file=sys.stderr)
        sys.exit(1)
    return elapsed_ms


def cleanup(db):
    """Q6 실행 후 추가된 1000 row 제거 (재실행 가능하게)."""
    if db == "mysql":
        subprocess.run(
            ["docker", "exec", "bench-mysql", "mysql", "-uroot", "-pbench", "bench",
             "-e", f"DELETE FROM metrics WHERE ts >= '{BASE_TS}' AND ts < '{BASE_TS + dt.timedelta(seconds=N_INSERTS)}'"],
            capture_output=True,
        )
    else:
        subprocess.run(
            ["docker", "exec", "bench-clickhouse", "clickhouse-client",
             "--user", "bench", "--password", "bench",
             "--query", f"ALTER TABLE bench.metrics DELETE WHERE ts >= '{BASE_TS}' AND ts < '{BASE_TS + dt.timedelta(seconds=N_INSERTS)}'"],
            capture_output=True,
        )


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("mysql", "clickhouse"):
        print("Usage: q6_runner.py <mysql|clickhouse>", file=sys.stderr)
        sys.exit(2)

    db = sys.argv[1]
    cleanup(db)
    elapsed = run_mysql() if db == "mysql" else run_clickhouse()
    cleanup(db)
    print(elapsed)


if __name__ == "__main__":
    main()
