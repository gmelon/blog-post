-- ClickHouse 메트릭 테이블 스키마
-- 컬럼별 코덱 + LowCardinality + 일 단위 파티션 + TTL

DROP TABLE IF EXISTS bench.metrics;

CREATE TABLE bench.metrics
(
    ts          DateTime                CODEC(DoubleDelta, ZSTD(3)),
    host        LowCardinality(String),
    metric_name LowCardinality(String),
    region      LowCardinality(String),
    env         LowCardinality(String),
    value       Float64                 CODEC(Gorilla, ZSTD(3)),
    tags        Map(LowCardinality(String), String)
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(ts)
ORDER BY (metric_name, host, ts)
-- TTL ts + INTERVAL 30 DAY  -- 벤치 재현성을 위해 비활성. 블로그 본문에서 기능 설명만.
SETTINGS index_granularity = 8192;
