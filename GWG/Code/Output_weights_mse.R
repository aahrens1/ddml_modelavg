
rm(list=ls())


library("ggplot2")
library("haven")
library("dplyr")
library("RColorBrewer")
library("tidyr")
library("stringr")
library("forcats")
library(patchwork)
library("xtable")

setwd("/Users/kahrens/MyProjects/ddml_applied/GWG/Output")

myformat <- function(x,digits=3) {
  require("stringr")
  x <- format(round(x,digits=digits),nsmall=digits)
  print(x)
  x <- str_replace(x,".000",".\\\\phantom{000}")
  x <- str_replace(x,"00$","\\\\phantom{00}")
  x <- str_replace(x,"0$","\\\\phantom{0}")
  return(x)
}
myformat(0)
myformat(0.12)
myformat(0.1)

################################################################################
### estimates
################################################################################

all_folders<-dir()
all_folders<-all_folders[str_detect(all_folders,"out")]


sweights<-list()

for (f in all_folders) {
  this_folder_files <- dir(f)
  this_folder_files <- this_folder_files[!str_detect(this_folder_files,"results.dta")]
  this_folder_files <- this_folder_files[!str_detect(this_folder_files,"nx")]
  this_folder_files <- this_folder_files[!str_detect(this_folder_files,"mse")]
  this_folder_files <- this_folder_files[str_starts(this_folder_files,"D")]
  this_folder_files <- this_folder_files[str_detect(this_folder_files,"ia.dta")]
  for (ff in this_folder_files) {
    tmp <- read_dta(paste0(f,'/',ff))
    tmp <- tmp[,3,drop=FALSE] 
    colnames(tmp) <- c("weight")
    tmp<-tmp |> mutate(learner=row_number())
    tmp <- slice(tmp,1:13)
     sweights[[paste(f,ff)]] <- tmp |> mutate(folder=f,
                                             file=ff)
  }
}

dweights <- bind_rows(sweights)

################################################################################
### estimates
################################################################################

all_folders<-dir()
all_folders<-all_folders[str_detect(all_folders,"out")]


sweights<-list()

for (f in all_folders) {
  this_folder_files <- dir(f)
  this_folder_files <- this_folder_files[!str_detect(this_folder_files,"results.dta")]
  this_folder_files <- this_folder_files[!str_detect(this_folder_files,"nx")]
  this_folder_files <- this_folder_files[str_starts(this_folder_files,"Y")]
  this_folder_files <- this_folder_files[str_detect(this_folder_files,"ia.dta")]
  for (ff in this_folder_files) {
    tmp <- read_dta(paste0(f,'/',ff))
    nc <- ncol(tmp)
    tmp <- tmp[,c((nc-3):(nc-1)),drop=FALSE] 
    colnames(tmp) <- c("learner","D","weight") 
    tmp <- filter(tmp,!is.na(learner))
    sweights[[paste(f,ff)]] <- tmp |> mutate(folder=f,
                                             file=ff)
  }
}

yweights <- bind_rows(sweights)

sweights<-bind_rows(yweights,dweights |> mutate(D=0))

check_sum <-sweights |>
  mutate(learner=round(learner,1)) |>
  group_by(D, file,folder) |>
  summarise(sum=sum(weight))

sweights<-sweights |>
  mutate(learner=round(learner,1)) |>
  group_by(D,learner,file) |>
  summarise(weight=mean(weight))


sweights <- sweights |>
  mutate(final=case_when(str_detect(file,"ols")~"OLS",
                         str_detect(file,"nnls1")~"CLS",
                         str_detect(file,"singlebest")~"Single-best",
                         str_detect(file,"avg")~"Average"),
         cef=if_else(str_starts(file,"Y"),"E[Y|X]","E[D|X]"),
         stack=case_when(str_detect(file,"regular")~"Regular",
                         str_detect(file,"ps")~"Pooled",
                         str_detect(file,"ss")~"Short",
                         ))
         
sweights <- sweights |>
  mutate(learner_name = case_when(learner==1~"OLS/logit",
                                  learner==2~"OLS/logit (simple)",
                                  learner==3~"CV-lasso",
                                  learner==4~"CV-ridge",
                                  learner==5~"CV-lasso (extended)",
                                  learner==6~"CV-ridge (extended)",
                                  learner==7~"Random forest 1",
                                  learner==8~"Random forest 2",
                                  learner==9~"Random forest 3",
                                  learner==10~"Gradient boosting 1",
                                  learner==11~"Gradient boosting 2",
                                  learner==12~"Neural net 1",
                                  learner==13~"Neural net 2" 
  ))

sweights <- sweights |>
  mutate(
    learner_name=as.factor(learner_name),
    learner_name=fct_relevel(learner_name,
                             "OLS/logit",
                             "OLS/logit (simple)",
                             "CV-lasso",
                             "CV-ridge",
                             "CV-lasso (extended)",
                             "CV-ridge (extended)",
                             "Random forest 1",
                             "Random forest 2",
                             "Random forest 3",
                             "Gradient boosting 1",
                             "Gradient boosting 2",
                             "Neural net 1",
                             "Neural net 2"
    ), 
    learner_name =fct_rev(learner_name)
  )

sweights <- sweights |>
  select(-file)


sweights <- sweights |> 
  pivot_wider(names_from = c("D","cef","stack"),values_from = "weight")  |>
  ungroup()

for (fin in c("CLS","OLS","Single-best")) {

  filter(sweights,final==fin) |>
    mutate(gap1="",gap2="") |>
    select(`learner_name`,`0_E[Y|X]_Regular`,`1_E[Y|X]_Regular`,`0_E[D|X]_Regular`,gap1,
                          `0_E[Y|X]_Pooled` , `1_E[Y|X]_Pooled` ,`0_E[D|X]_Pooled` ,gap2,
                          `0_E[Y|X]_Short`,`1_E[Y|X]_Short`,`0_E[D|X]_Short`) |>
    mutate_if(is.numeric,function(x) myformat(x,digits=3)) |>
    xtable(digits=3) |>
    print.xtable(sanitize.text.function =  function(x) str_replace(x,"&","\\\\&"),
                 floating=FALSE,
                include.rownames=FALSE,
                include.colnames=FALSE,
                only.contents=TRUE,
                type="latex",
                hline.after =NULL, 
                file=paste0("/Users/kahrens/MyProjects/ddml_sjpaper/GWG/",fin,"_weights.tex")
                )
  
    filter(sweights,final==fin) |>
      mutate(gap1="",gap2="") |>
      select(`learner_name`,`0_E[Y|X]_Regular`,`1_E[Y|X]_Regular`,`0_E[D|X]_Regular`,gap1,
             `0_E[Y|X]_Short`,`1_E[Y|X]_Short`,`0_E[D|X]_Short`) |>
      mutate_if(is.numeric,function(x) myformat(x,digits=3)) |>
      xtable(digits=3) |>
      print.xtable(sanitize.text.function =  function(x) str_replace(x,"&","\\\\&"),
                   floating=FALSE,
                   include.rownames=FALSE,
                   include.colnames=FALSE,
                   only.contents=TRUE,
                   type="latex",
                   hline.after =NULL, 
                   file=paste0("/Users/kahrens/MyProjects/ddml_sjpaper/GWG/",fin,"_weights_wopooled.tex")
                   )
    
    filter(sweights,final==fin) |>
      mutate(gap1="",gap2="") |>
      select(`learner_name`, 
             `0_E[Y|X]_Pooled` , `1_E[Y|X]_Pooled` ,`0_E[D|X]_Pooled`  ) |>
      mutate_if(is.numeric,function(x) myformat(x,digits=3)) |>
      xtable(digits=3) |>
      print.xtable(sanitize.text.function =  function(x) str_replace(x,"&","\\\\&"),
                   floating=FALSE,
                   include.rownames=FALSE,
                   include.colnames=FALSE,
                   only.contents=TRUE,
                   type="latex",
                   hline.after =NULL, 
                   file=paste0("/Users/kahrens/MyProjects/ddml_sjpaper/GWG/",fin,"_weights_onlypooled.tex")
                   )  
    
    
}

# sweights |>
#   filter(model==the_model) |>  
#   filter(finalest=="cls") |>  
#   mutate(stacking=if_else(stacking=="reg","Regsweular","Short")) |>
#   filter(crossfit) |>  
#   ggplot() +
#   geom_col(aes(x=learner_name,y=weight,fill=stacking),
#            position=position_dodge()) +
#   theme_minimal() +
#   theme(axis.text.x=element_text(angle=60,hjust=1),
#         #legend.position=c(1.2,.5),
#         #axis.text.x = element_blank() 
#   ) +
#   scale_fill_manual("Stacking type",values=brewer.pal(n = 5, name = 'Set1')[1:2]) +
#   scale_y_continuous(breaks=c(0,.25,.5)) +
#   xlab("") + ylab("(Short-)Stacking weights") +
#   facet_wrap(~cef,ncol=1)
# ggsave("/Users/kahrens/MyProjects/ddml_sjpaper/GWG/interactive_K10_weights.png",unit="cm",height=13,width=20)
# 



################################################################################
### mse
################################################################################

all_folders<-dir()
all_folders<-all_folders[str_detect(all_folders,"out")]


mse<-list()
for (f in all_folders) {
  this_folder_files <- dir(f)
  for (ff in c("plm_mse.dta","inter_mse.dta")) {
    tmp <- read_dta(paste0(f,'/',ff))
    mse[[paste(f,ff)]] <- tmp |> mutate(folder=f,
                                        file=ff)
  }
}
mse <- bind_rows(mse)
mse <- mse |> pivot_longer(-c("folder","file"))

mse <- mse |> 
  mutate(cef = case_when(str_detect(name,"_D1_pystacked_")~"E[D|X]",
                         str_detect(name,"_Y1_pystacked_")~"E[Y|X]",
                         str_detect(name,"_Y1_pystacked0_")~"E[Y|X,D=0]",
                         str_detect(name,"_Y1_pystacked1_")~"E[Y|X,D=1]"
  ),
  model = case_when(str_detect(file,"plm_")~"PLM",
                    str_detect(file,"inter_")~"Interactive",
  ),
  learner_name = case_when(str_detect(name,"L10")~"Gradient boosting 1",
                           str_detect(name,"L11")~"Gradient boosting 2",
                           str_detect(name,"L12")~"Neural net 1",
                           str_detect(name,"L13")~"Neural net 2",
                           str_detect(name,"L1")~"OLS/logit",
                           str_detect(name,"L2")~"OLS/logit (simple)",
                           str_detect(name,"L3")~"CV-lasso",
                           str_detect(name,"L4")~"CV-ridge",
                           str_detect(name,"L5")~"CV-lasso (extended)",
                           str_detect(name,"L6")~"CV-ridge (extended)",
                           str_detect(name,"L7")~"Random forest 1",
                           str_detect(name,"L8")~"Random forest 2",
                           str_detect(name,"L9")~"Random forest 3")) |> 
  mutate(
    learner_name=as.factor(learner_name),
    learner_name=fct_relevel(learner_name,
                             "OLS/logit",
                             "OLS/logit (simple)",
                             "CV-lasso",
                             "CV-ridge",
                             "CV-lasso (extended)",
                             "CV-ridge (extended)",
                             "Random forest 1",
                             "Random forest 2",
                             "Random forest 3",
                             "Gradient boosting 1",
                             "Gradient boosting 2",
                             "Neural net 1",
                             "Neural net 2")
  )

mse <- mse |>
  select(cef,model,learner_name,value) |>
  group_by(cef,model,learner_name) |>
  summarise(value=mean(value)) |> 
  filter(!is.na(value) & !is.na(learner_name)) |>
  ungroup()

## interactive
mse |>
  filter(model=="Interactive") |>
  pivot_wider(names_from = "cef") |> 
  mutate_if(is.numeric,function(x) myformat(x,digits=3)) |>
  xtable(digits=3) |>
  print.xtable(sanitize.text.function =  function(x) str_replace(x,"&","\\\\&"),
               floating=FALSE,
               include.rownames=FALSE,
               include.colnames=FALSE,
               only.contents=TRUE,
               type="latex",
               hline.after =NULL, 
               file=paste0("/Users/kahrens/MyProjects/ddml_sjpaper/GWG/Interactive_mse.tex")
               )

################################################################################
### mse/weights table
################################################################################

part1 <-
filter(sweights,final=="CLS") |>
  select(-learner) |>
  mutate(gap1="",gap2="") |>
  select(`learner_name`,`0_E[Y|X]_Regular`,`1_E[Y|X]_Regular`,`0_E[D|X]_Regular`,gap1,
         `0_E[Y|X]_Short`,`1_E[Y|X]_Short`,`0_E[D|X]_Short`) 

part2 <- mse |>
  filter(model=="Interactive") |>
  pivot_wider(names_from = "cef") 

left_join(part1,part2,c("learner_name")) |>
  select(-model) |>
  mutate(gap2="") |>
  select(`learner_name`,`0_E[Y|X]_Regular`,`1_E[Y|X]_Regular`,`0_E[D|X]_Regular`,gap1,
         `0_E[Y|X]_Short`,`1_E[Y|X]_Short`,`0_E[D|X]_Short`,gap2,
         `E[Y|X,D=0]`, `E[Y|X,D=1]` ,`E[D|X]`
         ) |>
  mutate_if(is.numeric,function(x) myformat(x,digits=3)) |>
  xtable(digits=3) |>
  print.xtable(sanitize.text.function =  function(x) str_replace(x,"&","\\\\&"),
               floating=FALSE,
               include.rownames=FALSE,
               include.colnames=FALSE,
               only.contents=TRUE,
               type="latex",
               hline.after =NULL, 
               file=paste0("/Users/kahrens/MyProjects/ddml_sjpaper/GWG/Interactive_mse_weights.tex")
  )


