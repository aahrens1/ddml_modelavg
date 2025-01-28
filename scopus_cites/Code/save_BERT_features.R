# User Input ===================================================================

# BERT hyperparameters
data_batch_size = 5000
batch_size = 64
max_length = 300

# Cross-validation ==========================================================

# load R dependencies
library(reticulate)
library(arrow)

# Initialize python environment
py_env <- py_run_string(
    paste(
        "import datasets",
        "import transformers",
        "import numpy as np",
        "import pandas as pd",
        "import torch",
        "import gc",
        "clear_memory = False", # global python boolean
        sep = "\n"
    ),
    convert = FALSE
)

# read data
df <- read_parquet("Data/scopus_with_gender_all.parquet")
X_abstracts <- as.matrix(df$abstract)

# Setup tokenizer & model
py_run_string(
"
model = transformers.BertModel.from_pretrained('bert-base-uncased')
tokenizer = transformers.AutoTokenizer.from_pretrained('bert-base-uncased')
")
py_run_string(paste(
    paste0(
    "training_args = transformers.TrainingArguments(
        output_dir='../models/bert-R',
        per_device_eval_batch_size=", batch_size, ")"),
    "trainer = transformers.Trainer(
        model=model,
        args=training_args)",
    sep = "\n"))


nobs <- length(X_abstracts)
n_databatch <- ceiling(nobs / data_batch_size)
X_bert <- matrix(0, nobs, 768)
#rownames(X_bert) <- df$scopus_id
for (j in 1:n_databatch) {

  # print update
  cat("r\ databatch:", j, "/", n_databatch)

  # Check whether memory should be cleared
  py_run_string(
      "if clear_memory:
          del ds_j
          gc.collect()
          torch.cuda.empty_cache()")

  # Get batch
  indices_j <- c( 1 + (j - 1) * data_batch_size, min( j * data_batch_size, nobs))
  X_abstracts_j <- X_abstracts[indices_j[1]:indices_j[2]]

  # Send to python and tokenize
  df_j <- data.frame(text = X_abstracts_j)
  dta_py_j <- r_to_py(df_j)
  py_run_string(paste(
        "ds_j = datasets.Dataset.from_pandas(r.dta_py_j)",
        paste0(
        "def tokenize_function(x):
            return tokenizer.batch_encode_plus(x['text'], max_length=", max_length, ", padding='max_length', truncation=True, is_split_into_words=False)"),
        "ds_j = ds_j.map(tokenize_function, batched=True, remove_columns=['text'])",
        sep = "\n"),
    convert = FALSE)

  # Get fitted values
  py_run_string("fitted_values_j = trainer.predict(ds_j).predictions", convert = FALSE)
  # Compute and return fitted values
  fitted_values_j <- py_to_r(py_env$fitted_values_j[[1]])
  X_bert[indices_j[1]:indices_j[2], ] <- fitted_values_j

  py_run_string("clear_memory=True")
}#FOR

# Save BERT data
write.csv(cbind(df$scopus_id, X_bert), "Data/bert_data.csv", 
    row.names=F, col.names=T)