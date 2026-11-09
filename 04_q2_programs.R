# 04_q2_programs.R
# Q2: Do international students from different countries
#     enrol in different fields of study?
# Data: Statistics Canada, Table 37-10-0184-01 (loaded in 01_load.R)


# ---- 0. Setup ----------------------------------------------------------

library(DBI)
library(dplyr)
library(ggplot2)

con <- dbConnect(duckdb::duckdb(), dbdir = "enrolment.duckdb")


# ---- 1. Extract data (SQL) ---------------------------------------------
# Same filters as Q1, but now by field of study.
# Fields: the 10 detailed groups only (codes like [a.1], [b.3]).
# Excludes totals (Total, STEM [a], BHASE [b]) and "Unclassified".

q2 <- dbGetQuery(con, "
  SELECT REF_DATE,
         \"Country of citizenship\" AS country,
         \"Classification of Instructional Programs, STEM and BHASE groupings\" AS program,
         VALUE AS n
  FROM enrol
  WHERE GEO = 'Ontario'
    AND \"Institution type\" = 'University'
    AND \"International Standard Classification of Education (ISCED)\" LIKE 'Total%'
    AND \"Status of student in Canada\" = 'International students'
    AND Gender = 'Total, gender'
    AND \"Country of citizenship\" LIKE '%[_____]'
    AND \"Classification of Instructional Programs, STEM and BHASE groupings\" LIKE '%[_._]'
")


# ---- 2. Checks ---------------------------------------------------------

nrow(q2)                          # expected: 20008
n_distinct(q2$program)            # expected: 10 fields
sum(is.na(q2$n))                  # expected: 72 missing (suppressed) values
sum(is.na(q2$n[q2$REF_DATE == "2024/2025"]))   # expected: 0


# ---- 3. Field-of-study mix by country (2024/2025) ----------------------
# share = % of each country's students in each field.
# Decision: denominator = sum of the 10 fields for that country
#           (excludes "Unclassified").

q2_2025 <- q2 %>%
  filter(REF_DATE == "2024/2025") %>%
  group_by(country) %>%
  mutate(share = round(100 * n / sum(n), 1)) %>%
  ungroup() %>%
  mutate(country_name = sub(" \\[.*\\]$", "", country),
         program_name = sub(" \\[.*\\]$", "", program))

q2_2025 %>%
  filter(country_name %in% c("China", "India")) %>%
  arrange(country_name, desc(share)) %>%
  select(country_name, program_name, n, share) %>%
  print(n = 20)