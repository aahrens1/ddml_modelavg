rm(list=ls())

library("arrow")
library("dplyr")
library("tidyr")
library("quanteda")

dta_all <- read_parquet("Data/scopus_with_gender_all.parquet")

dta_all <- dta_all |> distinct()

corp <- corpus(dta_all,docid_field="scopus_id",text_field="abstract")
dfm <- corp |> 
  tokens(remove_punct=TRUE,remove_numbers=TRUE,remove_separators=TRUE) |>
  tokens_remove(pattern=stopwords("english")) |>
  tokens_tolower() |>
  tokens_wordstem() |>
  tokens_ngrams(n = 1) |>
  dfm() |> 
  dfm_trim(min_termfreq=0.001,termfreq_type = "prop") 

idx <- match(dta_all$scopus_id,rownames(dfm))
y_dfm <- dta_all$citedby_count[idx]
d_dfm <- dta_all$any_female[idx]
save(dfm,y_dfm,d_dfm,file="Data/unigram.RData")

# #testing
# library("glmnet")
# fit <- cv.glmnet(x=dfm,y=y_dfm)
# coef(fit,s="lambda.min")
