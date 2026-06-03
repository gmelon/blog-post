#!/usr/bin/env python3
"""results/all.csv 를 읽어 요약 표 출력.

각 (db, query) 조합에 대해:
  - cold 시간
  - warm 평균 / stddev / min / max
  - DB 간 speedup (warm 기준)
"""
import csv
import statistics
import sys
from collections import defaultdict
from pathlib import Path


def main():
    if len(sys.argv) != 2:
        print("Usage: analyze.py <results/all.csv>", file=sys.stderr)
        sys.exit(2)
    path = Path(sys.argv[1])

    # data[(db, query)] = {'cold': int, 'warm': [int, ...]}
    data = defaultdict(lambda: {"cold": None, "warm": []})

    with open(path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            key = (row["db"], row["query"])
            t = int(row["time_ms"])
            if row["run_type"] == "cold":
                data[key]["cold"] = t
            else:
                data[key]["warm"].append(t)

    queries = sorted({q for _, q in data.keys()})
    dbs = sorted({d for d, _ in data.keys()})

    # 요약 표 출력
    print()
    print("=" * 95)
    print(f"{'Query':<25} {'DB':<12} {'Cold(ms)':>10} {'Warm avg':>10} "
          f"{'Warm σ':>8} {'Min':>8} {'Max':>8}")
    print("=" * 95)

    for q in queries:
        for db in dbs:
            d = data.get((db, q))
            if not d or not d["warm"]:
                continue
            warm_avg = statistics.mean(d["warm"])
            warm_std = statistics.stdev(d["warm"]) if len(d["warm"]) > 1 else 0.0
            cold = d["cold"] if d["cold"] is not None else "-"
            print(f"{q:<25} {db:<12} {str(cold):>10} {warm_avg:>10.0f} "
                  f"{warm_std:>8.1f} {min(d['warm']):>8} {max(d['warm']):>8}")
        print("-" * 95)

    # MySQL 대비 ClickHouse speedup (warm 기준)
    print()
    print("=" * 60)
    print("MySQL vs ClickHouse — warm avg speedup")
    print("=" * 60)
    print(f"{'Query':<25} {'MySQL':>10} {'ClickHouse':>12} {'Speedup':>10}")
    print("-" * 60)
    for q in queries:
        my = data.get(("mysql", q))
        ch = data.get(("clickhouse", q))
        if not (my and ch and my["warm"] and ch["warm"]):
            continue
        my_avg = statistics.mean(my["warm"])
        ch_avg = statistics.mean(ch["warm"])
        if ch_avg > 0:
            speedup = my_avg / ch_avg
            indicator = " 🔺" if speedup > 1 else " 🔻"
            print(f"{q:<25} {my_avg:>10.0f} {ch_avg:>12.0f} "
                  f"{speedup:>9.2f}x{indicator}")
        else:
            print(f"{q:<25} {my_avg:>10.0f} {ch_avg:>12.0f}")
    print()


if __name__ == "__main__":
    main()
