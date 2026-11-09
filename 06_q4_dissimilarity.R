# 06_q4_dissimilarity.R
# Q4. How differently are international and Canadian students spread
#     across fields of study, and has this changed since 2010/2011?
# Measure: Index of Dissimilarity (D), Duncan & Duncan (1955).
#   D = 1/2 x sum of |international share - Canadian share| across fields.
#   Reading: % of international students who would need to change fields
#   to match Canadian students' field distribution (0 = same, 100 = no overlap).
# Output: fig6_dissimilarity.png

library(DBI)
library(dplyr)
library(ggplot2)

con <- dbConnect(duckdb::duckdb(), dbdir = "enrolment.duckdb")


# ---- Data --------------------------------------------------------------
# Ontario universities, all years, 10 detailed fields.

q4 <- dbGetQuery(con, "
  SELECT REF_DATE,
         \"Classification of Instructional Programs, STEM and BHASE groupings\" AS program,
         \"Status of student in Canada\" AS status,
         VALUE AS n
  FROM enrol
  WHERE GEO = 'Ontario'
    AND \"Institution type\" = 'University'
    AND \"International Standard Classification of Education (ISCED)\" LIKE 'Total%'
    AND Gender = 'Total, gender'
    AND \"Country of citizenship\" LIKE 'Total%'
    AND \"Classification of Instructional Programs, STEM and BHASE groupings\" LIKE '%[_._]'
    AND \"Status of student in Canada\" IN ('Canadian students', 'International students')
")

q4_cty <- dbGetQuery(con, "
  SELECT REF_DATE,
         \"Classification of Instructional Programs, STEM and BHASE groupings\" AS program,
         \"Country of citizenship\" AS country,
         VALUE AS n
  FROM enrol
  WHERE GEO = 'Ontario'
    AND \"Institution type\" = 'University'
    AND \"International Standard Classification of Education (ISCED)\" LIKE 'Total%'
    AND Gender = 'Total, gender'
    AND \"Status of student in Canada\" = 'International students'
    AND \"Country of citizenship\" IN ('China [42156]', 'India [44356]')
    AND \"Classification of Instructional Programs, STEM and BHASE groupings\" LIKE '%[_._]'
")

nrow(q4);      sum(is.na(q4$n))       # 300, 0
nrow(q4_cty);  sum(is.na(q4_cty$n))   # 300, 0


# ---- D: international vs Canadian students -----------------------------

q4 <- q4 %>%
  group_by(REF_DATE, status) %>%
  mutate(share = 100 * n / sum(n)) %>%
  ungroup() %>%
  mutate(program_name = sub(" \\[.*\\]$", "", program))

q4_diff <- q4 %>%
  group_by(REF_DATE, program_name) %>%
  summarise(intl_share = share[status == "International students"],
            dom_share  = share[status == "Canadian students"],
            .groups = "drop") %>%
  mutate(abs_diff = abs(intl_share - dom_share))

q4_D <- q4_diff %>%
  group_by(REF_DATE) %>%
  summarise(D = round(sum(abs_diff) / 2, 1))

q4_D   # 2013/2014: 30.9 (highest); 2024/2025: 23.5 (lowest)


# ---- D: China and India vs Canadian students ---------------------------

dom <- q4 %>%
  filter(status == "Canadian students") %>%
  select(REF_DATE, program_name, dom_share = share)

q4_cty_D <- q4_cty %>%
  group_by(REF_DATE, country) %>%
  mutate(share = 100 * n / sum(n)) %>%
  ungroup() %>%
  mutate(program_name = sub(" \\[.*\\]$", "", program)) %>%
  left_join(dom, by = c("REF_DATE", "program_name")) %>%
  mutate(abs_diff = abs(share - dom_share)) %>%
  group_by(REF_DATE, country) %>%
  summarise(D = round(sum(abs_diff) / 2, 1), .groups = "drop")

q4_cty_D %>% print(n = 30)   # China 44.6 -> 23.8; India 46.3 -> 42.3


# ---- Figure 6 ----------------------------------------------------------
# Note: China is part of "All international", so the lines are not independent.

fig6_data <- bind_rows(
  q4_D %>% mutate(group = "All international"),
  q4_cty_D %>% transmute(REF_DATE, D, group = sub(" \\[.*\\]$", "", country))
)

nrow(fig6_data)   # 45

fig6_data %>%
  ggplot(aes(x = REF_DATE, y = D, colour = group, group = group)) +
  geom_line() +
  geom_point() +
  expand_limits(y = 0) +
  labs(x = "Academic year",
       y = "Index of Dissimilarity (0-100)",
       colour = NULL,
       title = "How differently international and Canadian students are spread across fields",
       subtitle = "Ontario universities. Higher = more different from Canadian students' field distribution.",
       caption = "Index of Dissimilarity across 10 fields of study.\nSource: Statistics Canada, Table 37-10-0184-01. Author's calculation.") +
  theme_minimal() +
  theme(plot.title.position = "plot",
        axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("fig6_dissimilarity.png", width = 9, height = 5.5, dpi = 300, bg = "white")


# ---- Which fields drive D? (2024/2025) ---------------------------------
# Each field's contribution = |international share - Canadian share| / 2.

q4_contrib <- q4_diff %>%
  filter(REF_DATE == "2024/2025") %>%
  mutate(contrib = abs_diff / 2,
         direction = ifelse(intl_share > dom_share,
                            "More international", "More Canadian")) %>%
  arrange(desc(contrib))

q4_contrib %>%
  mutate(across(c(intl_share, dom_share, contrib), ~ round(.x, 1))) %>%
  select(program_name, intl_share, dom_share, contrib, direction)

sum(q4_contrib$contrib)   # equals D for 2024/2025 (23.5)

dbDisconnect(con, shutdown = TRUE)