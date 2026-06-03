-- Q6: 단건 INSERT (의도된 ClickHouse 패배 카드)
-- "수집 daemon 단건 INSERT" — 1000회 반복 측정
-- 검증: 1편의 "Column DB 단건 쓰기 약점"
INSERT INTO metrics (ts, host, metric_name, region, env, value, tags)
VALUES ('2026-05-30 23:30:00', 'task-01', 'cpu_user', 'us-east', 'prod', 45.6, NULL);
