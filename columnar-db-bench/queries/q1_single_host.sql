-- Q1: 단일 host 시계열 조회
-- "task-01의 지난 1시간 cpu_user 추이"
-- 검증: row DB도 PK 매치는 빠르다 / 정렬 키 효과
SELECT ts, value
FROM metrics
WHERE host = 'task-01'
  AND metric_name = 'cpu_user'
  AND ts BETWEEN '2026-05-30 22:00:00' AND '2026-05-30 23:00:00'
ORDER BY ts;
