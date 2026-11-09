library(DBI)
con <- dbConnect(duckdb::duckdb(), dbdir = "enrolment.duckdb")

dbGetQuery(con, "
  SELECT REF_DATE, \"Institution type\", VALUE
  FROM enrol
  WHERE GEO = 'Canada'
    AND REF_DATE = '2023/2024'
    AND \"International Standard Classification of Education (ISCED)\" LIKE 'Total%'
    AND \"Classification of Instructional Programs, STEM and BHASE groupings\" LIKE 'Total%'
    AND \"Status of student in Canada\" = 'International students'
    AND \"Country of citizenship\" LIKE 'Total%'
    AND Gender = 'Total, gender'
")

# [검증 1] 2026-11-05
# 2023/2024 캐나다 전체 칼리지 유학생: 데이터 288,831 / 공식 발표 288,801 (30명 차이)
# 칼리지 비율 50.4%: 발표와 일치
# 차이 원인은 발표 후 데이터 수정 또는 반올림으로 추정 (확인 안 됨)