-- Q2 (MySQL): region 진입 집계 (큰 범위)
-- "us-east region 전체 cpu_user 분 단위 평균 지난 7일"
-- 검증: non-leading 컬럼 진입 시 Column DB 약점 / Projection 효과 대상
SELECT
    DATE_FORMAT(ts, '%Y-%m-%d %H:%i:00') AS minute,
    AVG(value)                            AS avg_cpu
FROM metrics
WHERE region = 'us-east'
  AND metric_name = 'cpu_user'
  AND ts BETWEEN '2026-05-23 23:00:00' AND '2026-05-30 23:00:00'
GROUP BY minute
ORDER BY minute;
