get_weights <- function(fit) {
  # extract stacking weights from fitted ddml object
  out <- NULL
  for (i in 1:5) {
    for (n in names(fit$weights)) {
      out<-bind_rows(out,
                     fit$weights[[n]][,,i] |> 
                       as_tibble() |> 
                       mutate(cef=n,fold=i,learner=row_number()) |>
                       select(cef,fold,learner,singlebest,nnls) 
      )
    }
  }
  return(out)
}
get_short_weights <- function(fit) {
  # extract short stacking weights from fitted ddml object
  out <- NULL
  for (n in names(fit$weights)) {
    out<-bind_rows(out,
                   fit$weights[[n]] |> 
                     as_tibble() |> 
                     mutate(cef=n,fold=NA,learner=row_number()) |>
                     select(cef,fold,learner,singlebest,nnls)  
    )
  }
  return(out)
}
get_mspe <- function(fit) {
  out <- NULL
  for (n in names(fit$mspe)) {
    tmp <- fit$mspe[[n]] |> rowMeans() |> as_tibble()
    tmp$names <- ddml_fit$ensemble_type[-c(1,2)]
    tmp <- tmp |> mutate(cef=n)
    out <- bind_rows(out,tmp)
  }
  return(out)
}
get_short_mspe <- function(fit) {
  out <- NULL
  for (n in names(fit$mspe)) {
    tmp <- fit$mspe[[n]] |> as_tibble()
    tmp$names <- names(fit$mspe[[n]])
    tmp <- tmp |> mutate(cef=n)
    out <- bind_rows(out,tmp)
  }
  return(out)
}
