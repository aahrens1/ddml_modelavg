
rm(list=ls())

library("dplyr")
library("tidyr")
library("ggplot2")
library("broom")
library("estimatr")
library("ddml")
library("stringr")
library("RColorBrewer")
library("forcats")
library("arrow")
library("xtable")

setwd("/Users/kahrens/MyProjects/ddml_applied/scopus_cites")

outpath <- "/Users/kahrens/MyProjects/ddml_sjpaper/scopus_cites/"
data_folder <- "/Users/kahrens/MyProjects/ddml_applied_scopus/"

load(file=paste0(data_folder,"Data/all_data_prepared.rds"))
# citedby_count, X_all, indx_list

myformat <- function(x,digits=3) {
  require("stringr")
  x <- format(round(x,digits=digits),nsmall=digits)
  print(x)
  x <- str_replace(x,".000",".\\\\phantom{000}")
  x <- str_replace(x,"00$","\\\\phantom{00}")
  x <- str_replace(x,"0$","\\\\phantom{0}")
  return(x)
}
 

############################
## PDS and OLS
############################


source("./Code/rlasso2.R")
source("./Code/pdslasso.R")

pds_results <- list()

for (t in c(60,70,90)) {
  for (out in c("log","levels")) {
    
  if (out=="log") {
    out_var <- log(citedby_count)
    cited_pos <- citedby_count>0
  } else {
    cited_pos <- rep(TRUE,length(citedby_count))
    out_var <- citedby_count
  }
    
  # Select sample
  if (t==60) {
    sel <- !is.na(threshold60) & cited_pos
  } else if (t == 70) {
    sel <- !is.na(threshold70) & cited_pos
  } else if (t == 90) {
    sel <- !is.na(threshold90) & cited_pos
  }#IFELSE

  pds_results[[paste("base",out,t)]] <- pds_fit(Y=out_var[sel],
                      X=X_all[sel,c(indx_list$base)],
                      D=X_all[sel,c(indx_list$all_female,indx_list$mixed_gender)]
                      )$fit |> 
    tidy() |> 
    mutate(learner="PDS-lasso & base controls",
               agg=TRUE,
               threshold=t,
               spec=out)
  
  pds_results[[paste("ols base",out,t)]] <- lm_robust(out_var[sel]~0+X_all[sel,c(indx_list$all_female,indx_list$mixed_gender,indx_list$base)]) |>
    tidy() |>
    mutate(learner="OLS & base controls",
           agg=TRUE,
           threshold=t,
           spec=out)
    
  pds_results[[paste("ols uncond",out,t)]] <- lm_robust(out_var[sel]~X_all[sel,c(indx_list$all_female,indx_list$mixed_gender)]) |>
    tidy() |>
    mutate(learner="OLS & no controls",
           agg=TRUE,
           threshold=t,
           spec=out)
  
  pds_results[[paste("bert",out,t)]] <- pds_fit(Y=out_var[sel], 
                      X=X_all[sel,c(indx_list$base,indx_list$bert)],
                      D=X_all[sel,c(indx_list$all_female,indx_list$mixed_gender)]
                      )$fit |> 
    tidy() |> 
    mutate(learner="PDS-lasso & BERT",
               agg=TRUE,
               threshold=t,
               spec=out)
  
  pds_results[[paste("uni",out,t)]] <- pds_fit(Y=out_var[sel], 
                         X=X_all[sel,c(indx_list$base,indx_list$unigram)],
                         D=X_all[sel,c(indx_list$all_female,indx_list$mixed_gender)]
                      )$fit |> 
    tidy() |> 
    mutate(learner="PDS-lasso & Unigrams",
               agg=TRUE,
               threshold=t,
               spec=out)

}
}


############################
## tidy fitted ddml objects
############################

source("./Code/ddml_auxiliary.R")

all_weights <- NULL
all_mspe <- NULL
all_tidied <- list()

for (j in 1:5) {
for (t in c(60,70,90)) {
  load(paste0(data_folder,"Results/short_log/fit1_sstack1_thres",t,"_",j,".rds"))
  ddml_tidy <- lapply(ddml_fit$ols_fit,tidy)
  for (i in 1:length(ddml_tidy)) ddml_tidy[[i]] <- ddml_tidy[[i]] |> mutate(learner=names(ddml_tidy)[i])
  ddml_tidy <- bind_rows(ddml_tidy)
  ddml_tidy <- ddml_tidy |> mutate(rep=j,stacking="Short",spec="log",threshold=t)
  all_tidied[[paste("short",j,"log",t)]] <- ddml_tidy
  all_weights <- bind_rows(all_weights,
                           get_short_weights(ddml_fit) |> 
                             mutate(rep=j,stacking="Short",spec="log",threshold=t)
                           )
  all_mspe <- bind_rows(all_mspe,
                        get_short_mspe(ddml_fit) |>
                          mutate(rep=j,stacking="Short",spec="log",threshold=t)
                            )
  
  load(paste0(data_folder,"Results/regular_log/fit1_sstack0_thres",t,"_",j,".rds"))
  ddml_tidy <- lapply(ddml_fit$ols_fit,tidy)
  for (i in 1:length(ddml_tidy)) ddml_tidy[[i]] <- ddml_tidy[[i]] |> mutate(learner=names(ddml_tidy)[i])
  ddml_tidy <- bind_rows(ddml_tidy)
  ddml_tidy <- ddml_tidy |> mutate(rep=j,stacking="Conventional",spec="log",threshold=t)
  all_tidied[[paste("reg",j,"log",t)]] <- ddml_tidy
  all_weights <- bind_rows(all_weights,
                           get_weights(ddml_fit) |> 
                             mutate(rep=j,stacking="Conventional",spec="log",threshold=t)
                           )
  all_mspe <- bind_rows(all_mspe,
                        get_mspe(ddml_fit) |>
                          mutate(rep=j,stacking="Conventional",spec="log",threshold=t)
                          )
  
  load(paste0(data_folder,"Results/short_levels/fit1_sstack1_thres",t,"_",j,".rds"))
  ddml_tidy <- lapply(ddml_fit$ols_fit,tidy)
  for (i in 1:length(ddml_tidy)) ddml_tidy[[i]] <- ddml_tidy[[i]] |> mutate(learner=names(ddml_tidy)[i])
  ddml_tidy <- bind_rows(ddml_tidy)
  ddml_tidy <- ddml_tidy |> mutate(rep=j,stacking="Short",spec="levels",threshold=t)
  all_tidied[[paste("short",j,"levels",t)]] <- ddml_tidy
  all_weights <- bind_rows(all_weights,
                           get_short_weights(ddml_fit) |> 
                             mutate(rep=j,stacking="Short",spec="levels",threshold=t)
                           )
  all_mspe <- bind_rows(all_mspe,
                        get_short_mspe(ddml_fit) |>
                          mutate(rep=j,stacking="Short",spec="levels",threshold=t)
                        )
  
  load(paste0(data_folder,"Results/regular_levels/fit1_sstack0_thres",t,"_",j,".rds"))
  ddml_tidy <- lapply(ddml_fit$ols_fit,tidy)
  for (i in 1:length(ddml_tidy)) ddml_tidy[[i]] <- ddml_tidy[[i]] |> mutate(learner=names(ddml_tidy)[i])
  ddml_tidy <- bind_rows(ddml_tidy)
  ddml_tidy <- ddml_tidy |> mutate(rep=j,stacking="Conventional",spec="levels",threshold=t)
  all_tidied[[paste("reg",j,"levels",t)]] <- ddml_tidy
  all_weights <- bind_rows(all_weights,
                           get_weights(ddml_fit) |> 
                             mutate(rep=j,stacking="Conventional",spec="levels",threshold=t)
                           )
  all_mspe <- bind_rows(all_mspe,
                        get_mspe(ddml_fit) |>
                          mutate(rep=j,stacking="Conventional",spec="levels",threshold=t)
                          )
  
}
}

all_tidied <- bind_rows(all_tidied)
all_tidied <- all_tidied |> 
  mutate(conf.low=estimate-1.96*std.error,
         conf.high=estimate+1.96*std.error)

## median aggregation
median_agg <- all_tidied |> 
  group_by(learner,stacking,term,spec,threshold) |>
  mutate(estimate_median=median(estimate) 
  ) |>
  ungroup() |>
  mutate(std.error_median=std.error^2+(estimate_median-estimate)^2) |>
  group_by(learner,stacking,term,spec,threshold) |>
  summarise(estimate=first(estimate_median),
            std.error=mean(std.error_median) 
  ) |>
  mutate(std.error=sqrt(std.error),
         statistic=estimate/std.error,
         p.value=2*pnorm(-abs(statistic)),
         conf.low=estimate-1.96*std.error,
         conf.high=estimate+1.96*std.error,
         rep=-1
  )


##################################################
## put all together: coefficients
##################################################

all_tidied2 <- 
  bind_rows(all_tidied |> mutate(agg=FALSE),
            median_agg |> mutate(agg=TRUE) , 
            pds_results |> bind_rows()  
  )


all_tidied3 <- all_tidied2 |>
  mutate(term=str_remove(term,".*\\]")) |> 
  filter(str_detect(term,"all_female") | str_detect(term,"mixed_gender") ) |>  
  filter((learner %in% c("nnls","singlebest")) | str_detect(learner,"PDS") | str_detect(learner,"OLS") | (stacking=="Short")) |> 
  mutate(learner=case_when(learner=="nnls" & stacking=="Conventional"~"CLS & stacking",
                          learner=="singlebest" & stacking=="Conventional"~"Single-best & stacking",
                          learner=="nnls" & stacking=="Short"~"CLS & short-stacking",
                          learner=="singlebest" & stacking=="Short"~"Single-best & short-stacking",
                          TRUE~learner
            )) |>
  mutate(term=case_when(str_detect(term,"mixed_gender")~"Mixed gender",
                        str_detect(term,"all_female")~"All female"
                        )) |>
  mutate(learner=str_replace(learner,"keras[:]","Neural net"),
         learner=str_replace(learner,"lasso[:]","CV-lasso"),
         learner=str_replace(learner,"ridge[:]","CV-ridge"),
         learner=str_replace(learner,"ranger[:]","Random forest"),
         learner=str_replace(learner,"xgboost[:]","XGBoost"),
         learner=str_replace(learner,"ols[:]","OLS"),
         learner=str_replace(learner,"bert"," & BERT"),
         learner=str_replace(learner,"ngram"," & Unigrams"),
         ) |>  
  mutate(learner=as.factor(learner),
         learner=fct_relevel(learner,
                             "OLS & no controls"   ,
                             "OLS & base controls",
                             "PDS-lasso & base controls",
                             "PDS-lasso & Unigrams",
                             "PDS-lasso & BERT",
                             "OLS & Unigrams",
                             "OLS & BERT",
                             "CV-lasso & Unigrams"   ,
                             "CV-lasso & BERT"       ,
                             "CV-ridge & Unigrams"  ,          
                             "CV-ridge & BERT"     ,          
                             "XGBoost & Unigrams"  ,    
                             "XGBoost & BERT"      ,           
                             "Random forest & Unigrams" ,
                             "Random forest & BERT"     ,   
                             "Neural net & Unigrams"    ,      
                             "Neural net & BERT"       ,                    
                             "Single-best & stacking",  
                             "CLS & stacking"       ,  
                             "Single-best & short-stacking",
                             "CLS & short-stacking"      ,           
                            ) 
         )

for (t in c(60,70,90)) {
all_tidied3 |>
  filter(threshold==t) |>
  filter(spec=="log") |>
  filter(!str_detect(learner,"no controls")) |>
  ggplot() +
  geom_pointrange(aes(x=learner,ymin=conf.low,ymax=conf.high,y=estimate,
                      color=agg,#linetype=predictor,shape=predictor, 
                      group=rep
  ),size=.3,
  position = position_dodge(width=.8)
  )+
  geom_hline(yintercept=0,alpha=.7)+
  theme_minimal() +
  theme(axis.text.x=element_text(angle=90,hjust=1),
        legend.position="n") +
  scale_color_manual("Controls",values=brewer.pal(n = 5, name = 'Dark2'))+
  scale_linetype_discrete("Controls")+
  scale_shape_manual("Controls",values=15:19)+
  facet_wrap(~term,scale="free_y",ncol=1) + 
  xlab("") +
  ylab("Estimated citation gap") 
ggsave(paste0(outpath,"results_log",t,".png"),
       unit="cm",height=13,width=20)
}

all_tidied3 |>
  filter(threshold==70) |>
  filter(!str_detect(learner,"no controls")) |>
  filter(agg) |>
  select(spec,learner,term,estimate,std.error,p.value) |>
  mutate(stars = case_when(p.value<0.01~"***",
                           p.value >= .01 & p.value<0.05~"**",
                           p.value >= .05 & p.value<0.1~"*",
                           TRUE~""
                        ),
          estimate=paste0(round(estimate,3),stars),
          std.error=paste0("(",round(std.error,3),")")) |>
  select(-stars,-p.value) |>
  pivot_longer(4:5) |>
  pivot_wider(names_from = c("spec","term")) |> 
  select(learner,name,`log_All female` , `log_Mixed gender`,`levels_All female`,`levels_Mixed gender`) |>
  arrange(learner,name) |>
  mutate(learner=if_else(name=="std.error","",learner)) |>
  select(-name) |>
  xtable() |>
  print(  
    hline.after=NULL,
    include.rownames=FALSE,
    include.colnames=FALSE,
    only.contents=TRUE ,
    file=paste0(outpath,"results_tab.tex")
  )


##################################################
## put all together: weights
##################################################

 

all_weights2 <- all_weights |>
  filter(threshold==70) |>
  mutate(learner=case_when(learner==1~"OLS & Unigrams",
                           learner==2~"OLS & BERT",
                           learner==3~"CV-lasso & Unigrams"   ,
                           learner==4~"CV-lasso & BERT"       ,
                           learner==5~"CV-ridge & Unigrams"  ,          
                           learner==6~"CV-ridge & BERT"     ,          
                           learner==7~"XGBoost & Unigrams"  ,    
                           learner==8~"XGBoost & BERT"      ,           
                           learner==9~"Random forest & Unigrams" ,
                           learner==10~"Random forest & BERT"     ,   
                           learner==11~"Neural net & Unigrams"    ,      
                           learner==12~"Neural net & BERT"  ),
         learner=as.factor(learner),
         learner=fct_relevel(learner,
                             "OLS & Unigrams",
                             "OLS & BERT",
                             "CV-lasso & Unigrams"   ,
                             "CV-lasso & BERT"       ,
                             "CV-ridge & Unigrams"  ,          
                             "CV-ridge & BERT"     ,          
                             "XGBoost & Unigrams"  ,    
                             "XGBoost & BERT"      ,           
                             "Random forest & Unigrams" ,
                             "Random forest & BERT"     ,   
                             "Neural net & Unigrams"    ,      
                             "Neural net & BERT"              
                             )
         )

weights_tidied <- all_weights2 |> 
  filter(threshold==70) |>
  group_by(cef,learner,spec,stacking) |>
  summarise(nnls=mean(nnls),
            singlebest=mean(singlebest)) |>
  ungroup() |>
  select(-singlebest) |>
  pivot_wider(names_from=c("cef","stacking"),values_from = "nnls") |>
  mutate(gap0="",gap1="",gap2="",gap3="") |>  
  select(spec,gap0,learner,gap1,y_X_Conventional,y_X_Short,
                gap2,D1_X_Conventional,D1_X_Short,
                gap3,D2_X_Conventional,D2_X_Short
                      )

weights_tidied |> 
  filter(spec=="log") |>
  select(-spec) |>
  mutate_if(is.numeric,function(x) myformat(x,digits=3)) |>
  xtable() |>
  print( sanitize.text.function = function(x) str_replace(x,"&","\\\\&"),
         hline.after=NULL,
        include.rownames=FALSE,
        include.colnames=TRUE,
        only.contents=TRUE ,
        file=paste0(outpath,"weights_log.tex")
  )

weights_tidied |>
  filter(spec=="levels") |>
  select(-spec) |>
  mutate_if(is.numeric,function(x) myformat(x,digits=3)) |>
  xtable() |>
  print(sanitize.text.function = function(x) str_replace(x,"&","\\\\&"),
        hline.after=NULL,
        include.rownames=FALSE,
        include.colnames=TRUE,
        only.contents=TRUE ,
        file=paste0(outpath,"weights_levels.tex")
  )



##################################################
## put all together: mspe
##################################################

mspe_tidied <- all_mspe |> 
  filter(threshold==70) |>
  group_by(names,cef,spec,stacking) |>
  summarise(value=mean(value)) |>
  ungroup() |>
  pivot_wider(names_from=c("cef","stacking"),values_from="value") |>
  rename(learner=names) |>
  mutate(learner=str_replace(learner,"keras[:]","Neural net"),
         learner=str_replace(learner,"lasso[:]","CV-lasso"),
         learner=str_replace(learner,"ridge[:]","CV-ridge"),
         learner=str_replace(learner,"ranger[:]","Random forest"),
         learner=str_replace(learner,"xgboost[:]","XGBoost"),
         learner=str_replace(learner,"ols[:]","OLS"),
         learner=str_replace(learner,"bert"," & BERT"),
         learner=str_replace(learner,"ngram"," & Unigrams"),
         learner=as.factor(learner),
         learner=fct_relevel(learner,
                             "OLS & Unigrams",
                             "OLS & BERT",
                             "CV-lasso & Unigrams"   ,
                             "CV-lasso & BERT"       ,
                             "CV-ridge & Unigrams"  ,          
                             "CV-ridge & BERT"     ,          
                             "XGBoost & Unigrams"  ,    
                             "XGBoost & BERT"      ,           
                             "Random forest & Unigrams" ,
                             "Random forest & BERT"     ,   
                             "Neural net & Unigrams"    ,      
                             "Neural net & BERT"              
         )
  ) |>
  filter(!is.na(D1_X_Conventional))  |>
  mutate(gap0="",gap1="",gap2="",gap3="") |>
  select(spec,gap0,learner,gap1,y_X_Conventional,y_X_Short,
         gap2,D1_X_Conventional,D1_X_Short,
         gap3,D2_X_Conventional,D2_X_Short
  )

mspe_tidied |>
  filter(spec=="levels") |>
  select(-spec) |>
  arrange(learner) |>
  mutate_if(is.numeric,function(x) myformat(x,digits=1)) |>
  xtable() |>
  print(sanitize.text.function =  function(x) str_replace(x,"&","\\\\&"),
        hline.after=NULL,
        include.rownames=FALSE,
        include.colnames=TRUE,
        only.contents=TRUE  ,
         file=paste0(outpath,"mspe_levels.tex")
  )

mspe_tidied |>
  filter(spec=="log") |>
  select(-spec) |>
  arrange(learner) |>
  mutate_if(is.numeric,function(x) myformat(x,digits=3)) |>
  xtable() |>
  print( sanitize.text.function =  function(x) str_replace(x,"&","\\\\&"),
        hline.after=NULL,
        include.rownames=FALSE,
        include.colnames=TRUE,
        only.contents=TRUE ,
        file=paste0(outpath,"mspe_log.tex")
  )

mspe_tidied |>
  filter(spec=="log") |>
  select(-spec) |>
  arrange(learner) |>
  mutate_if(is.numeric,function(x) myformat(x,digits=3)) |>
  select(-y_X_Short,-D1_X_Short ,-D2_X_Short) |>
  mutate( 
         y_X_Conventional=paste0("\\multicolumn{2}{c}{",y_X_Conventional,"}"),
         D2_X_Conventional=paste0("\\multicolumn{2}{c}{",D2_X_Conventional,"}"),
         D1_X_Conventional=paste0("\\multicolumn{2}{c}{",D1_X_Conventional,"}")
         ) |>
  xtable() |>
  print( sanitize.text.function =  function(x) str_replace(x,"&","\\\\&"),
         hline.after=NULL,
         include.rownames=FALSE,
         include.colnames=TRUE,
         only.contents=TRUE   ,
         file=paste0(outpath,"mspe_log_joined.tex")
  )

