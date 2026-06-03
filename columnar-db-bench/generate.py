#!/usr/bin/env python3
"""메트릭 모니터링 합성 데이터 생성기.

50 hosts × 15 metrics × 30 days × (10s interval) = 약 1.94억 행
일별 CSV 파일 30개로 분할 출력.

Usage:
    python generate.py                # 풀 데이터 생성
    python generate.py --smoke        # 1일 × 1 host × 1 metric (smoke test)
    python generate.py --workers 8    # worker 프로세스 수 (기본: CPU 개수)
"""
import argparse
import csv
import datetime as dt
import math
import multiprocessing as mp
import random
import sys
import time
from pathlib import Path


SEED = 42
START = dt.datetime(2026, 5, 1, 0, 0, 0)
END = dt.datetime(2026, 5, 31, 0, 0, 0)
INTERVAL = dt.timedelta(seconds=10)
NUM_HOSTS = 50

REGIONS = ["us-east", "us-west", "eu-west", "ap-northeast", "ap-southeast"]

METRICS = [
    ("cpu_user",         "percentage",  25.0),
    ("cpu_system",       "percentage",   8.0),
    ("cpu_iowait",       "percentage",   3.0),
    ("mem_used",         "percentage",  60.0),
    ("mem_cached",       "percentage",  20.0),
    ("mem_free",         "percentage",  20.0),
    ("disk_read_bytes",  "bursty",       0.0),
    ("disk_write_bytes", "bursty",       0.0),
    ("net_in_bytes",     "bursty",       0.0),
    ("net_out_bytes",    "bursty",       0.0),
    ("load_1",           "gauge",        2.0),
    ("load_5",           "gauge",        2.0),
    ("load_15",          "gauge",        2.0),
    ("fd_count",         "counter",   1000.0),
    ("conn_count",       "counter",    200.0),
]

DATA_DIR = Path(__file__).parent / "data"


def now_str():
    return dt.datetime.now().strftime("%H:%M:%S")


def build_hosts(num_hosts):
    """task-01 ~ task-N. region 균등 분배, env 비대칭(prod 40 / staging 8 / dev 2)."""
    env_assignments = ["prod"] * 40 + ["staging"] * 8 + ["dev"] * 2
    rng = random.Random(SEED)
    rng.shuffle(env_assignments)

    hosts = []
    for i in range(num_hosts):
        host = f"task-{i+1:02d}"
        region = REGIONS[i % len(REGIONS)]
        env = env_assignments[i % len(env_assignments)]
        hosts.append((host, region, env))
    return hosts


def value_for(pattern, ts, host_seed, base, day_start_ts):
    """패턴별 메트릭 값 합성. 같은 (host, ts, metric) 조합에 결정적."""
    seed_key = (host_seed, int(ts.timestamp()), pattern)
    rnd = random.Random(hash(seed_key))

    if pattern == "percentage":
        daily = math.sin(2 * math.pi * ts.hour / 24) * 15
        noise = rnd.gauss(0, 3)
        spike = rnd.gauss(50, 10) if rnd.random() < 0.01 else 0
        return max(0.0, min(100.0, base + daily + noise + spike))

    elif pattern == "bursty":
        if rnd.random() < 0.05:
            return rnd.expovariate(1 / 10000) + 1000
        return rnd.expovariate(1 / 100)

    elif pattern == "gauge":
        return max(0.0, rnd.gauss(base, 0.5))

    elif pattern == "counter":
        # day 단위로 천천히 증가
        seconds_in_day = (ts - day_start_ts).total_seconds()
        growth = seconds_in_day * 0.001
        return base + growth + rnd.gauss(0, 5)

    raise ValueError(f"unknown pattern: {pattern}")


def generate_day(args):
    """하루치 데이터를 한 CSV 파일에 기록."""
    day_idx, total_days, day_start, hosts, metrics = args
    day_end = day_start + dt.timedelta(days=1)
    day_str = day_start.strftime("%Y%m%d")
    out_path = DATA_DIR / f"metrics_{day_str}.csv"

    started = time.time()
    row_count = 0

    with open(out_path, "w", newline="", buffering=4 * 1024 * 1024) as f:
        writer = csv.writer(f)
        ts = day_start
        while ts < day_end:
            ts_str = ts.strftime("%Y-%m-%d %H:%M:%S")
            for host, region, env in hosts:
                host_seed = hash(host) & 0xFFFFFFFF
                for metric_name, pattern, base in metrics:
                    value = value_for(pattern, ts, host_seed, base, day_start)
                    writer.writerow([
                        ts_str, host, metric_name, region, env,
                        f"{value:.4f}", ""
                    ])
                    row_count += 1
            ts += INTERVAL

    elapsed = time.time() - started
    size_mb = out_path.stat().st_size / 1024 / 1024
    print(
        f"[{now_str()}] day {day_idx+1:2d}/{total_days} ({day_str}): "
        f"{row_count:>10,} rows, {size_mb:>6.1f}MB in {elapsed:>5.1f}s "
        f"({row_count/elapsed/1000:.0f}K rows/s) → {out_path.name}",
        flush=True,
    )
    return row_count, elapsed, size_mb


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--smoke", action="store_true",
                        help="smoke test: 1일 × 1 host × 1 metric")
    parser.add_argument("--workers", type=int, default=min(mp.cpu_count(), 8),
                        help=f"worker 프로세스 수 (기본: {min(mp.cpu_count(), 8)})")
    args = parser.parse_args()

    DATA_DIR.mkdir(exist_ok=True)

    if args.smoke:
        hosts = build_hosts(1)
        metrics = METRICS[:1]
        end = START + dt.timedelta(days=1)
        print(f"[{now_str()}] SMOKE TEST MODE: 1 day × 1 host × 1 metric")
    else:
        hosts = build_hosts(NUM_HOSTS)
        metrics = METRICS
        end = END

    # 일별 작업 단위
    days = []
    day = START
    idx = 0
    while day < end:
        days.append((idx, (end - START).days, day, hosts, metrics))
        day += dt.timedelta(days=1)
        idx += 1
    total_days = len(days)

    # 예상 행 수
    measurements_per_day = 86400 // int(INTERVAL.total_seconds())
    expected_rows = total_days * measurements_per_day * len(hosts) * len(metrics)

    print(f"[{now_str()}] config: {total_days} days, {len(hosts)} hosts, "
          f"{len(metrics)} metrics, interval={INTERVAL.total_seconds():.0f}s")
    print(f"[{now_str()}] expected total: {expected_rows:,} rows")
    print(f"[{now_str()}] workers: {args.workers}")
    print(f"[{now_str()}] output: {DATA_DIR}")
    print(f"[{now_str()}] {'='*70}")

    start_time = time.time()

    if args.workers == 1 or len(days) == 1:
        results = [generate_day(d) for d in days]
    else:
        with mp.Pool(args.workers) as pool:
            results = list(pool.imap_unordered(generate_day, days))

    elapsed = time.time() - start_time
    total_rows = sum(r[0] for r in results)
    total_size_mb = sum(r[2] for r in results)

    print(f"[{now_str()}] {'='*70}")
    print(f"[{now_str()}] DONE in {elapsed/60:.1f} min")
    print(f"[{now_str()}] total rows: {total_rows:,}")
    print(f"[{now_str()}] total size: {total_size_mb/1024:.2f} GB")
    print(f"[{now_str()}] avg throughput: {total_rows/elapsed/1000:.0f}K rows/s")


if __name__ == "__main__":
    main()
