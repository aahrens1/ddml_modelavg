
mdl_keras <- function(y, X,
                       units = 10, nhidden = 1, lambda1 = 0, lambda2 = 0,
                       optimizer_fun = "rmsprop",
                       loss = "mse",
                       epochs = 10,
                       dropout = NULL,
                       batch_size = min(1000, length(y)),
                       validation_split = 0,
                       callbacks = NULL,
                       steps_per_epoch = NULL,
                       metrics = c("mae"),
                       verbose = 0) {


# Data parameters
nobs <- length(y)

# # Normalize data
std_y <- c(mean(y), sd(y))
std_X <- apply(X, 2, function(x) c(mean(x), max(sd(x), 1e-3)))

y <- (y - std_y[1])/std_y[2]
X <- X - matrix(replicate(nobs, std_X[1, , drop = F]), 
  nrow = nobs, byrow = T)
X <- X / matrix(replicate(nobs, std_X[2, , drop = F]), 
  nrow = nobs, byrow = T)
  
  # ======================================================
  # ADJUST FOR DIFFERENT ARCHITECTURES ===================

  #if ("dgCMatrix" %in% class(X)) X <- as.matrix(X)
  
  # Construct neural network architecture
  nnet <- keras_model_sequential()
  for (k in 1:nhidden) {
    nnet <- nnet |>
      layer_dense(units = units, use_bias = T,
                  activation = "relu",
                  kernel_regularizer = regularizer_l1(l = lambda1)) 
    if (is.numeric(dropout)) {
      nnet <- nnet |>
          layer_dropout(dropout)
    }
  }#FOR
  nnet <- nnet %>% 
    layer_dense(units = 1, use_bias = T,
                kernel_regularizer = regularizer_l1(l = lambda2)) 
  
  # ADJUST FOR DIFFERENT ARCHITECTURES ===================
  # ======================================================
  
  # Compile model
  nnet %>% keras::compile(optimizer = optimizer_fun,
                          loss = loss,
                          metrics = metrics)
  
  # Fit neural net
  nnet %>% keras::fit(X, y,
                      epochs = epochs,
                      batch_size = batch_size,
                      validation_split = validation_split,
                      callbacks = callbacks,
                      steps_per_epoch = steps_per_epoch,
                      verbose = verbose)

  # Add standardization to object
  nnet$std_y <- std_y
  nnet$std_X <- std_X

  # Amend class
  class(nnet) <- c("mdl_keras", class(nnet))

  # Return fit
  return(nnet)
}#MDL_KERAS


predict.mdl_keras <- function(obj, newdata = NULL){
  # Check for new data
  #if(is.null(newdata)) newdata <- obj$X
  # Standardize features
  nobs <- nrow(newdata)
  newdata <- newdata - matrix(replicate(nobs, obj$std_X[1, , drop = F]), 
    nrow = nobs, byrow = T)
  newdata <- newdata / matrix(replicate(nobs, obj$std_X[2, , drop = F]), 
    nrow = nobs, byrow = T)
  # Predict data and output as matrix
  class(obj) <- class(obj)[-1] # Not a pretty solution...
  fitted <- as.numeric(predict(obj, newdata))
  # Re-standardize to output and return
  fitted <- obj$std_y[2] * fitted + obj$std_y[1]
  return(fitted)
}#PREDICT.MDL_KERAS
