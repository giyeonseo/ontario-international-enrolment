# 01_load.R
# Load Statistics Canada Table 37-10-0184-01 into a local DuckDB database.
#
# Table: Postsecondary enrolments, by status of student in Canada,
#        country of citizenship and CIP STEM/BHASE groupings.
# Download the full table (CSV) from Statistics Canada:
#   https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=3710018401
# Unzip and put 37100184.csv in the project folder.
# The CSV (about 6 GB) is not included in this repository.

library(DBI)

con <- dbConnect(duckdb::duckdb(), dbdir = "enrolment.duckdb")

# Create the table once (takes a few minutes)
if (!dbExistsTable(con, "enrol")) {
  dbExecute(con, "
    CREATE TABLE enrol AS
    SELECT * FROM read_csv_auto('37100184.csv')
  ")
}

dbGetQuery(con, "SELECT COUNT(*) AS n_rows FROM enrol")   # 21,861,191

dbDisconnect(con, shutdown = TRUE)