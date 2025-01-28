library("arrow")
library("readr")
library("stringr")
library("dplyr")

journal_list <- c(
    "Quarterly Journal of Economics",
    "American Economic Review",
    "Journal of Political Economy",
    "Journal of Finance",
    "Review of Economic Studies",
    "Econometrica",
    "Journal of Economic Literature",
    "Review of Financial Studies",
    "Journal of Marketing",
    "Journal of Financial Economics",
    "Annual Review of Economics",
    "Journal of Economic Perspectives",
    "Review of Economics and Statistics",
    "Marketing Science",
    "Journal of Marketing Research",
    "Journal of the Academy of Marketing Science",
    "Journal of Business and Economic Statistics",
    "Journal of Accounting and Economics",
    "Journal of Consumer Research",
    "Journal of Monetary Economics",
    "Journal of Econometrics",
    "Review of Finance",
    "Review of Corporate Finance Studies",
    "Journal of Financial Intermediation",
    "Journal of Accounting Research",
    "Journal of Public Economics",
    "Journal of International Business Studies",
    "Handbook of Econometrics",
    "Innovation Policy and the Economy",
    "Journal of Labor Economics"
    )

# Increase the chunk size appropriately
chunk_size <- 1e6

# Assumption: There is a header on the first line
# but we don't know what it is.
col_names <- TRUE
line_num <- 0
j <- 1

while (TRUE) {

  chunk <- read_csv("/cluster/work/lawecon/Work/dcai/scopus_export_achim/data_export_scopus.csv",
    skip = line_num,
    n_max = chunk_size,
    # On the first iteration, col_names is TRUE
    # so the first line "X,Y,Z" is assumed to be the header
    # On any subsequent iteration, col_names is a character vector
    # of the actual column names
    col_names = col_names)

  # If the chunk has now rows, then reached end of file
  if (!nrow(chunk)) {
    break
  }

  # Update `col_names` so that it is equal the actual column names
  print(col_names)
  col_names <- colnames(chunk)

  # Do something with the chunk of data
  chunk <- chunk |> 
    filter(journal %in% journal_list) 
  write_parquet(chunk,sink=paste0("/cluster/scratch/kahrens/scopus_",j,".parquet"))


  # Move to the next chunk. Add 1 for the header.
  line_num <- line_num + chunk_size + (line_num == 1)
  j <- j +1
}
 