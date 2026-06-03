-- Q5: top-N 쿼리
-- "지난 1시간 cpu_user 평균 상위 10개 host"
-- 검증: GROUP BY + ORDER BY + LIMIT, 컬럼형 sweet spot
SELECT host, AVG(value) AS avg_cpu
FROM metrics
WHERE metric_name = 'cpu_user'
  AND ts BETWEEN '2026-05-30 22:00:00' AND '2026-05-30 23:00:00'
GROUP BY host
ORDER BY avg_cpu DESC
LIMIT 10;
