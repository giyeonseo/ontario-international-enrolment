# 03_q1_countries.R
# Q1. How concentrated are international students at Ontario universities
#     by country of citizenship, and how has this changed since 2010/2011?
# Output: fig1_top5_share.png, fig2_hhi.png

library(DBI)
library(dplyr)
library(ggplot2)

con <- dbConnect(duckdb::duckdb(), dbdir = "enrolment.duckdb")


# ---- Data --------------------------------------------------------------
# Ontario universities, international students, all years.
# Totals for level, field and gender.
# Countries only (5-digit codes), not continents or regions.

q1 <- dbGetQuery(con, "
  SELECT REF_DATE, \"Country of citizenship\" AS country, VALUE AS n
  FROM enrol
  WHERE GEO = 'Ontario'
    AND \"Institution type\" = 'University'
    AND \"International Standard Classification of Education (ISCED)\" LIKE 'Total%'
    AND \"Classification of Instructional Programs, STEM and BHASE groupings\" LIKE 'Total%'
    AND \"Status of student in Canada\" = 'International students'
    AND Gender = 'Total, gender'
    AND \"Country of citizenship\" LIKE '%[_____]'
")

nrow(q1)                          # 2,940
sum(q1$REF_DATE == "2024/2025")   # 203 countries

# Counts are randomly rounded to multiples of 3, so very small counts
# are unreliable. Country rows add up to slightly less than the Total
# row (2024/2025: 103,368 vs 103,857).


# ---- Share by country --------------------------------------------------
# Denominator: sum of country rows in each year.

q1 <- q1 %>%
  group_by(REF_DATE) %>%
  mutate(share = round(100 * n / sum(n), 1)) %>%
  ungroup() %>%
  mutate(country_name = sub(" \\[.*\\]$", "", country))

top5 <- q1 %>%
  filter(REF_DATE == "2024/2025") %>%
  slice_max(n, n = 5) %>%
  pull(country)

top5   # China, India, Iran, Nigeria, USA


# ---- Figure 1: top 5 countries -----------------------------------------

q1 %>%
  filter(country %in% top5) %>%
  ggplot(aes(x = REF_DATE, y = share, colour = country_name, group = country_name)) +
  geom_line() +
  geom_point() +
  labs(x = "Academic year",
       y = "Share of international students (%)",
       colour = "Country of citizenship",
       title = "International students at Ontario universities, by country of citizenship",
       caption = "Source: Statistics Canada, Table 37-10-0184-01. Top 5 countries in 2024/2025.") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("fig1_top5_share.png", width = 9, height = 5.5, dpi = 300, bg = "white")


# ---- Concentration (HHI) -----------------------------------------------
# HHI = sum of squared country shares (%). Near 0 = spread across many
# countries; 10,000 = all from one country.
# 10,000 / HHI = effective number of countries.

q1_hhi <- q1 %>%
  group_by(REF_DATE) %>%
  summarise(hhi = round(sum((100 * n / sum(n))^2))) %>%
  mutate(eff_n = round(10000 / hhi, 1))

q1_hhi   # 2010/2011: 1,181; 2018/2019: 2,635; 2024/2025: 1,537


# ---- Figure 2: HHI -----------------------------------------------------

q1_hhi %>%
  ggplot(aes(x = REF_DATE, y = hhi, group = 1)) +
  geom_line() +
  geom_point() +
  expand_limits(y = 0) +
  labs(x = "Academic year",
       y = "HHI (0-10,000)",
       title = "Concentration of international students by country of citizenship",
       subtitle = "Ontario universities. Higher values = more concentrated in fewer countries.",
       caption = "Source: Statistics Canada, Table 37-10-0184-01. Author's calculation.") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("fig2_hhi.png", width = 9, height = 5.5, dpi = 300, bg = "white")


# ---- International students as a share of all students -----------------

q1_total <- dbGetQuery(con, "
  SELECT REF_DATE, \"Status of student in Canada\" AS status, VALUE AS n
  FROM enrol
  WHERE GEO = 'Ontario'
    AND \"Institution type\" = 'University'
    AND \"International Standard Classification of Education (ISCED)\" LIKE 'Total%'
    AND \"Classification of Instructional Programs, STEM and BHASE groupings\" LIKE 'Total%'
    AND \"Country of citizenship\" LIKE 'Total%'
    AND Gender = 'Total, gender'
    AND (\"Status of student in Canada\" = 'International students'
         OR \"Status of student in Canada\" LIKE 'Total%')
")

q1_share <- q1_total %>%
  group_by(REF_DATE) %>%
  summarise(all_students = n[status != "International students"],
            intl         = n[status == "International students"]) %>%
  mutate(intl_share = round(100 * intl / all_students, 1))

q1_share   # 7.2% (2010/2011), 18.8% (2023/2024), 17.3% (2024/2025)

dbDisconnect(con, shutdown = TRUE)