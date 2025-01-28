chs_fit <- function(Y,X,D) {
  y.rlasso.fit <- rlasso2(Y,X,HC_robust=T)
  d.rlasso.fit <- rlasso2(D,X,HC_robust=T)
  ytilde <- Y-predict.rlasso2(y.rlasso.fit)
  dtilde <- D-predict.rlasso2(d.rlasso.fit)
  fit <- lm_robust(ytilde~dtilde-1,se_type="HC1")
  return(list(fit=fit,yretain=y.rlasso.fit$retained_X,dretain=d.rlasso.fit$retained_X))
}

pds_fit <- function(Y,X,D) {
  require("glmnet")
  y_selected  <- rlasso2(Y,X,HC_robust=T)$retained_X
  d_selected <-NULL
  for (i in 1:ncol(D)) {
    d_selected <- c(d_selected,rlasso2(D[,i,drop=FALSE],X,HC_robust=T,post=FALSE)$retained_X)
  }
  all_selected <- unique(c(y_selected,d_selected))
  X_sel <- as.data.frame(as.matrix(X[,all_selected,drop=FALSE]))
  fit <- lm_robust(Y~.,se_type="HC1",data=cbind(Y,D,X_sel))
  return(list(fit=fit,yretain=y_selected,dretain=d_selected))
}

# Constructed fitted values
predict.ols <- function(object, newdata = NULL, ...){
  # Obtain datamatrix
  if (is.null(newdata)) {
    newdata <- object$X
  } else if (object$const) {
    newdata <- cbind(1, newdata)
  }#IFELSE
  # Calculate and return fitted values with the OLS coefficient
  fitted <- newdata%*%object$coef
  return(fitted)
}#PREDICT.OLSs