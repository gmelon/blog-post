#!/usr/bin/env python3
"""Q7 (벌크 백필) 용 별도 CSV 생성기.

5/31 00:00 ~ 5/31 01:00 (1시간) 의 50 host × 15 metric 데이터.
약 50 * 15 * 360 = 270,000 행. (5/30까지의 메인 데이터와 시간대 안 겹침)
"""
import datetime as dt
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from generate import build_hosts, value_for, METRICS, INTERVAL

BACKFILL_START = dt.datetime(2026, 5, 31, 0, 0, 0)
BACKFILL_END = dt.datetime(2026, 5, 31, 1, 0, 0)
OUTPUT = Path(__file__).parent.parent / "data" / "backfill_1hour.csv"


def main():
    import csv
    hosts = build_hosts(50)
    print(f"generating backfill: {BACKFILL_START} ~ {BACKFILL_END} → {OUTPUT}")
    count = 0
    with open(OUTPUT, "w", newline="") as f:
        writer = csv.writer(f)
        ts = BACKFILL_START
        while ts < BACKFILL_END:
            ts_str = ts.strftime("%Y-%m-%d %H:%M:%S")
            for host, region, env in hosts:
                host_seed = hash(host) & 0xFFFFFFFF
                for metric_name, pattern, base in METRICS:
                    value = value_for(pattern, ts, host_seed, base, BACKFILL_START)
                    writer.writerow([
                        ts_str, host, metric_name, region, env,
                        f"{value:.4f}", ""
                    ])
                    count += 1
            ts += INTERVAL
    size_mb = OUTPUT.stat().st_size / 1024 / 1024
    print(f"done: {count:,} rows, {size_mb:.1f}MB")


if __name__ == "__main__":
    main()
