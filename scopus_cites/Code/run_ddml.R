# ==============================================================================
# Estimating DDML

# ============================================================================== 
# User Input 

# Arguments should be supplied in the following order:

# Get the arguments as a character vector.
args <- commandArgs(trailingOnly = TRUE)

# hyperparameters
counter = as.numeric(args[1])
shortstack = as.numeric(args[2]) == 1
seed = as.integer(args[3])
inlogs = as.numeric(args[4]) == 1
temp_dir = args[5]
threshold = args[6]

# Debugging parameters
# counter = 1
# shortstack = TRUE
# seed = 99580 # 86812 97227 23356 27018 25807 50617 95423 72221 33861
# inlogs = FALSE
# threshold = 70

# Set seed
set.seed(seed)

# ==============================================================================
# Dependencies

library(ddml)
library(keras)

mdl_lm <- function(y, X, ...) {
  lm_fit <- lm.fit(X, y)
  class(lm_fit) <- c("mdl_lm", class(lm_fit))
  return(lm_fit)
}#MDL_LM
predict.mdl_lm <- function(object, newdata) {
  newdata %*% object$coef
}#PREDICT.MDL_LM

source("Code/mdl_keras.R")



# keras specification
callbacks_list <- list(callback_early_stopping(monitor = "val_loss", 
                                               patience = 15,
                                               restore_best_weights = T),
                       callback_reduce_lr_on_plateau(monitor = "val_loss",
                                                     factor = 1/10,
                                                     patience = 10,
                                                     verbose = T),
                       callback_learning_rate_scheduler(
                         function(epoch, learning_rate){
                           if(epoch == 0) learning_rate <- 0.01
                           return(learning_rate)
                         }))

nnet_args <- list(units = 10, nhidden = 3,
  lambda1 = 0, lambda2 = 0,
  dropout = 0.5,
  epochs = 50,
  batch_size = 500, 
  verbose = 1,
  validation_split = 0.1,
  callbacks = callbacks_list,
  optimizer = keras::keras$optimizers$legacy$Adam(learning_rate=0.01, clipnorm=1)) #optimizer_adam(learning_rate = 0.1, clipnorm=1000))# , clipnorm=1




# ==============================================================================
# Data

load(file="Data/all_data_prepared.rds")
# citedby_count, X_all, indx_list

# Select sample
if (threshold == "60") {
  citedby_count = citedby_count[threshold60 == 1]
  X_all <- X_all[threshold60 == 1, ]
} else if (threshold == "70") {
  citedby_count = citedby_count[threshold70 == 1]
  X_all <- X_all[threshold70 == 1, ]
} else if (threshold == "90") {
  indx <- which(threshold90 == 1)
  citedby_count = citedby_count[indx]
  X_all <- X_all[indx, ]
}#IFELSE

# Add logs
if (inlogs) {
  positive_citations = which(citedby_count > 0)
  citedby_count <- citedby_count[positive_citations]
  X_all <- X_all[positive_citations, ]
} else if (any(is.na(citedby_count))) {
  is_na = which(is.na(citedby_count))
  citedby_count <- citedby_count[-is_na]
  X_all <- X_all[-is_na, ]
}#IFELSE


# ==============================================================================
# Learner list

learners <- list(
  list(fun = mdl_lm,
       assign_X = c(indx_list$base, indx_list$unigram)),
   list(fun = mdl_lm,
       assign_X = c(indx_list$base, indx_list$bert)),
  list(fun = mdl_glmnet,
       assign_X = c(indx_list$base, indx_list$unigram)),
   list(fun = mdl_glmnet,
       assign_X = c(indx_list$base, indx_list$bert)),
  list(fun = mdl_glmnet,
       args = list(alpha = 0),
       assign_X = c(indx_list$base, indx_list$unigram)),
   list(fun = mdl_glmnet,
       args = list(alpha = 0),
       assign_X = c(indx_list$base, indx_list$bert)),
  list(fun = mdl_xgboost,
       assign_X = c(indx_list$base, indx_list$unigram)),
   list(fun = mdl_xgboost,
       assign_X = c(indx_list$base, indx_list$bert)),
  list(fun = mdl_ranger,
       assign_X = c(indx_list$base, indx_list$unigram)),
   list(fun = mdl_ranger,
       assign_X = c(indx_list$base, indx_list$bert)),
  list(fun = mdl_keras,
       args = nnet_args,
       assign_X = c(indx_list$base, indx_list$unigram)),
  list(fun = mdl_keras,
       args = nnet_args,
       assign_X = c(indx_list$base, indx_list$bert)))


# learners <- list(
#   list(fun = mdl_keras,
#        args = nnet_args,
#        assign_X = c(indx_list$base, indx_list$unigram)),
#   list(fun = mdl_keras,
#        args = nnet_args,
#        assign_X = c(indx_list$base, indx_list$bert)))

# Generate weights for by-learner estimation
nlearners <- length(learners)
single_models <- diag(nlearners)
colnames(single_models) <- c("ols:ngram", "ols:bert",
    "lasso:ngram", "lasso:bert",
    "ridge:ngram", "ridge:bert",
    "xgboost:ngram", "xgboost:bert",
    "ranger:ngram", "ranger:bert",
    "keras:ngram", "keras:bert")

# colnames(single_models) <- c(
#     "keras:ngram", "keras:bert")

# ==============================================================================
# Estimate DDML

# Set outcome variable
if (inlogs) {
  y = log(citedby_count)
} else {
  y = citedby_count
}#IFELSE


ddml_fit <- ddml_plm(y = y, 
    D = X_all[, 1:2], # all_female, mixed_gender
    X = X_all, # note: all_female, mixed_gender are never assigned as controls!
    learners = learners,
    sample_folds = 5,
    cv_folds = 5,
    ensemble_type = c("singlebest", "nnls"),
    shortstack = shortstack,
    custom_ensemble_weights = single_models,
    silent = FALSE)
summary(ddml_fit)
ddml_fit$weights

ddml_fit$coef

# ==============================================================================
# Store results in a .rds

# Construct file name and folder
file_name <- paste0(temp_dir, "/fit1_sstack", toString(shortstack*1), "_thres", threshold, "_", toString(counter), ".rds")
if (!dir.exists(dirname(file_name))) 
  dir.create(dirname(file_name), recursive = T)

# Store file
save(ddml_fit, file=file_name)