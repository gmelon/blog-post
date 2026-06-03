-- Q3: 알림 회고 스캔 (큰 범위)
-- "지난 1일 동안 cpu_user > 80% 였던 host 목록"
-- 검증: 필요 컬럼만 읽기 + Zone Map (ts 1일 범위)
SELECT DISTINCT host
FROM metrics
WHERE metric_name = 'cpu_user'
  AND value > 80
  AND ts BETWEEN '2026-05-29 23:00:00' AND '2026-05-30 23:00:00';
