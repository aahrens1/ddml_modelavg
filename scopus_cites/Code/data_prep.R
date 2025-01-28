rm(list=ls())

# load R dependencies
library(arrow)
library(Matrix)



# read parquet data
df <- read_parquet("Data/scopus_with_gender_all.parquet")

# read BERT data
X_bert <- read.csv("Data/bert_data.csv")
row.names(X_bert) <- df$scopus_id

# also load unigrams
load(file="Data/unigram.RData")
dfm <- as(dfm,"sparseMatrix")
dfm <- dfm[(rownames(dfm) %in% df$scopus_id),] # just to make smaller
dfm <- as.matrix(dfm) #to dense matrix

# generate base (non-text) controls
X_base <- model.matrix(~  as.factor(year), data = df) # + as.factor(journal)
row.names(X_base) <- df$scopus_id

# generate all_female and mixed_gender indicators
all_female <- df$all_female60 * 1
mixed_gender <- ((df$any_female60 > 0) & (df$all_female60 < 1)) * 1

# Get sample thresholds
threshold60 <- df$threshold60
threshold70 <- df$threshold70
threshold90 <- df$threshold90

# Combine data
X_all <- base::merge(cbind(all_female, mixed_gender, X_base, X_bert), dfm, by="row.names",sort=FALSE)[, -c(1)]
X_all <- as.matrix(X_all)
dim(X_all)

# Generate indices
indx_all_female = 1
indx_mixed_gender = 2
indx_base <- 3:(2 + ncol(X_base))
indx_bert <- (2 + ncol(X_base) + 1):(2 + ncol(X_base) + ncol(X_bert))
indx_unigram <- (2 + ncol(X_base) + ncol(X_bert) + 1):(ncol(X_all))
indx_list = list(all_female = indx_all_female,
                 mixed_gender = indx_mixed_gender,
                 base = indx_base,
                 bert = indx_bert,
                 unigram = indx_unigram)
                

# Save to Data folder
citedby_count = df$citedby_count
save(threshold60, threshold70, threshold90, 
    citedby_count, X_all, indx_list, file="./Data/all_data_prepared.rds")

# Check whether X_all and df have the same order
# all((df$all_female * 1 - X_all[, 1]) == 0)

summary(X_all[, indx_base])
