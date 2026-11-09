# 05_q3_exposure.R
# Q3: In each field, what share of ALL students (incl. Canadian students)
#     are international students?
# Data: Statistics Canada, Table 37-10-0184-01 (loaded in 01_load.R)


# ---- 0. Setup ----------------------------------------------------------

library(DBI)
library(dplyr)
library(ggplot2)

con <- dbConnect(duckdb::duckdb(), dbdir = "enrolment.duckdb")


# ---- 1. All students in each field (2024/2025) -------------------------
# All students = Canadian + international (status = Total, country = Total)

field_total <- dbGetQuery(con, "
  SELECT \"Classification of Instructional Programs, STEM and BHASE groupings\" AS program,
         VALUE AS all_students
  FROM enrol
  WHERE GEO = 'Ontario'
    AND REF_DATE = '2024/2025'
    AND \"Institution type\" = 'University'
    AND \"International Standard Classification of Education (ISCED)\" LIKE 'Total%'
    AND Gender = 'Total, gender'
    AND \"Status of student in Canada\" LIKE 'Total%'
    AND \"Country of citizenship\" LIKE 'Total%'
    AND \"Classification of Instructional Programs, STEM and BHASE groupings\" LIKE '%[_._]'
")

field_total


# ---- 2. International students in each field (2024/2025) ---------------

field_intl <- dbGetQuery(con, "
  SELECT \"Classification of Instructional Programs, STEM and BHASE groupings\" AS program,
         VALUE AS intl
  FROM enrol
  WHERE GEO = 'Ontario'
    AND REF_DATE = '2024/2025'
    AND \"Institution type\" = 'University'
    AND \"International Standard Classification of Education (ISCED)\" LIKE 'Total%'
    AND Gender = 'Total, gender'
    AND \"Status of student in Canada\" = 'International students'
    AND \"Country of citizenship\" LIKE 'Total%'
    AND \"Classification of Instructional Programs, STEM and BHASE groupings\" LIKE '%[_._]'
")

field_intl


# ---- 3. Share of international students in each field ------------------

field_share <- field_total %>%
  left_join(field_intl, by = "program") %>%
  mutate(intl_share = round(100 * intl / all_students, 1)) %>%
  arrange(desc(intl_share))

field_share


# ---- 4. Share by country: top 5 countries ------------------------------
# Top 5 = largest countries of citizenship among international students
#         at Ontario universities in 2024/2025 (same as Q1 and Q2).

field_country <- dbGetQuery(con, "
  SELECT \"Classification of Instructional Programs, STEM and BHASE groupings\" AS program,
         \"Country of citizenship\" AS country,
         VALUE AS n
  FROM enrol
  WHERE GEO = 'Ontario'
    AND REF_DATE = '2024/2025'
    AND \"Institution type\" = 'University'
    AND \"International Standard Classification of Education (ISCED)\" LIKE 'Total%'
    AND Gender = 'Total, gender'
    AND \"Status of student in Canada\" = 'International students'
    AND \"Country of citizenship\" IN ('China [42156]', 'India [44356]',
                                      'Iran [41364]', 'Nigeria [31566]',
                                      'United States of America [11840]')
    AND \"Classification of Instructional Programs, STEM and BHASE groupings\" LIKE '%[_._]'
")

nrow(field_country)   # expected: 50 (10 fields x 5 countries)

field_country_share <- field_country %>%
  left_join(field_total, by = "program") %>%
  mutate(share = round(100 * n / all_students, 1)) %>%
  arrange(country, desc(share))

field_country_share



# ---- 5. Combine for plotting -------------------------------------------
# Stack "All international" (10 rows) and top 5 countries (50 rows).

plot_data <- bind_rows(
  field_share %>%
    transmute(program, group = "All international", share = intl_share),
  field_country_share %>%
    transmute(program, group = country, share)
) %>%
  mutate(group = case_when(
    group == "United States of America [11840]" ~ "USA",
    TRUE ~ sub(" \\[.*\\]$", "", group)),
    program_name = sub(" \\[.*\\]$", "", program))

nrow(plot_data)          # expected: 60
table(plot_data$group)   # expected: 10 rows for each of the 6 groups



# ---- 6. Figure 4: exposure by field (heatmap) --------------------------
# Rows: fields, ordered by international share (highest at top).
# Columns: all international students, then top 5 countries.

row_order <- field_share %>%
  arrange(intl_share) %>%
  mutate(program_name = sub(" \\[.*\\]$", "", program)) %>%
  pull(program_name)

col_order <- c("All international", "China", "India", "Iran", "Nigeria", "USA")

plot_data %>%
  mutate(program_name = factor(program_name, levels = row_order),
         group = factor(group, levels = col_order)) %>%
  ggplot(aes(x = group, y = program_name, fill = share)) +
  
  
  
  # ---- 7. Q3 results (summary) -------------------------------------------
# 2024/2025, international students as % of ALL students in each field:
# - Math/computer 34.4 (China 13.1, India 9.2)
# - Business 25.1 (China 8.4, India 6.6)
# - Engineering 23.0 (China 6.4, India 5.2)
# - Lowest: Health care 5.5, Education 5.6, Legal 6.4
# - Iran, Nigeria, USA: 2.5% or less in every field
#
# Takeaway (interpretation):
# - A drop in international students would affect Math/computer,
#   Business and Engineering the most.
# - In Math/computer, China + India alone = 22.3% of all students,
#   so a change in either country could noticeably affect enrolment.
# - Limits: one year (2024/2025); all levels combined.
  geom_tile(colour = "white") +
  geom_text(aes(label = share), size = 3) +
  scale_fill_gradient(low = "white", high = "steelblue") +
  labs(x = NULL, y = NULL, fill = "% of all\nstudents\nin field",
       title = "International students as a share of all students, by field",
       subtitle = "Ontario universities, 2024/2025. Total includes Canadian students.",
       caption = "Source: Statistics Canada, Table 37-10-0184-01. Author's calculation.") +
  theme_minimal() +
  theme(plot.title.position = "plot")

ggsave("fig4_exposure.png", width = 9, height = 6, dpi = 300, bg = "white")

