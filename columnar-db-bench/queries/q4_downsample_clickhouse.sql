-- Q4 (ClickHouse): 분 단위 다운샘플링
-- "지난 7일간 cpu_user 분 단위 평균"
-- 검증: 대규모 집계 + 컬럼별 읽기 효과
SELECT
    toStartOfMinute(ts) AS minute,
    avg(value)          AS avg_value
FROM metrics
WHERE metric_name = 'cpu_user'
  AND ts BETWEEN '2026-05-23 23:00:00' AND '2026-05-30 23:00:00'
GROUP BY minute
ORDER BY minute;
