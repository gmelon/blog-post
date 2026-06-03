# 메트릭 모니터링 — Row DB vs Column DB 벤치마크

블로그 "[컬럼형 DB 파헤치기] 2편" 의 재현 코드.

50 hosts × 15 metrics × 30 days (10s 간격) ≈ 1.94억 행을 두 DB에 각각 적재한 뒤 7개 쿼리에 대해 변인 통제된 측정을 수행한다.

## 요구사항

- macOS / Linux
- Docker 24+ & Docker Compose v2+
- Python 3.10+
- 디스크 약 80GB 여유
- `sudo` 권한 (콜드 측정 시 OS page cache drop 용)

## 디렉토리 구조

```
columnar-db-bench/
├── docker-compose.yml
├── generate.py
├── schemas/
│   ├── mysql.sql
│   ├── clickhouse.sql
│   └── clickhouse-config.xml
├── queries/
│   ├── q1_single_host.sql
│   ├── q2_region_agg.sql
│   ├── q3_alert_scan.sql
│   ├── q4_downsample_mysql.sql
│   ├── q4_downsample_clickhouse.sql
│   ├── q5_top_n.sql
│   ├── q6_single_insert.sql
│   └── q7_bulk_backfill.sql
├── scripts/
│   ├── init_mysql.sh / init_clickhouse.sh
│   ├── load_mysql.sh / load_clickhouse.sh
│   ├── benchmark.sh
│   ├── q6_runner.py / gen_backfill.py
│   ├── analyze.py
│   ├── disk_usage.sh / env_info.sh / wait_for_db.sh
├── data/      (gitignore, ~30GB CSV)
├── logs/      (gitignore)
└── results/   (gitignore)
```

## 실행 순서

### 1. 컨테이너 기동

```bash
docker compose up -d
./scripts/wait_for_db.sh mysql
./scripts/wait_for_db.sh clickhouse
```

### 2. (선택) Smoke test — 작은 데이터로 파이프라인 확인

```bash
python3 generate.py --smoke         # 1일 × 1 host × 1 metric (~360 rows)
./scripts/init_mysql.sh
./scripts/init_clickhouse.sh
./scripts/load_mysql.sh
./scripts/load_clickhouse.sh
```

### 3. 풀 데이터 생성 (약 10분)

```bash
python3 generate.py
# → data/metrics_20260501.csv ~ metrics_20260530.csv (30개 파일, 약 30GB)
```

### 4. 스키마 초기화

```bash
./scripts/init_mysql.sh
./scripts/init_clickhouse.sh
```

### 5. 데이터 적재 (MySQL ~1시간, ClickHouse ~10분)

```bash
./scripts/load_mysql.sh
./scripts/load_clickhouse.sh
```

### 6. 환경 정보 수집

```bash
./scripts/env_info.sh        # → results/environment.md
```

### 7. 디스크 사용량 측정

```bash
./scripts/disk_usage.sh      # → results/disk_usage.txt
```

### 8. 벤치마크 실행 (약 30~60분)

```bash
sudo -v                       # sudo 비밀번호 캐시
./scripts/benchmark.sh        # 자동으로 sudo 캐시 갱신
# → results/all.csv
# → results/explain/
# → logs/benchmark_*.log
```

### 9. 분석

```bash
python3 scripts/analyze.py results/all.csv
```

## 측정 프로토콜

- 콜드 측정: 컨테이너 재시작 + `sudo purge` (macOS) / `drop_caches` (Linux) → 1회
- 웜 측정: warm-up 1회 (버려짐) + 5회 평균 + 표준편차
- 측정값: docker exec wall-clock (서버 측 실행 시간 + Docker 오버헤드)
- 쿼리: 7종 (Q1~Q7), 일부는 DB별로 다른 SQL

## 시드

- 데이터 생성: `random.seed(42)`
- 같은 시드 + 같은 코드 → 동일한 CSV 보장

## 알려진 한계

- 단일 노드 측정. 분산 클러스터 구성에서는 결과 양상 다름
- 데이터 분포(천천히 변하는 메트릭)에 ClickHouse 코덱이 매우 유리
- macOS Docker Desktop의 mount 성능이 Linux보다 느림 — 같은 환경 안에서의 비교는 fair
