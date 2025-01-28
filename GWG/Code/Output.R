
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
library("patchwork")

setwd("/Users/kahrens/MyProjects/ddml_applied/GWG/Output")


################################################################################
### estimates
################################################################################

all_folders<-dir()
all_folders<-all_folders[str_detect(all_folders,"out")]

all_results <-list()
for (f in all_folders) {
  all_results[[paste(f)]] <-  
                           read_dta(paste0(f,"/results.dta"))
}
 

################################################################################
### estimates
################################################################################


dta<- bind_rows(all_results)

dta <- dta |> mutate(crossfit=!str_detect(model,"nx"))

dta <- dta |>
  mutate(stacking=if_else(learner<1,"Regular","short"))

dta <- dta |>
  mutate(learner_name = case_when(learner==1~"OLS/logit",
                                  learner==2~"OLS/logit\n(simple)",
                                  learner==3~"CV-lasso",
                                  learner==4~"CV-ridge",
                                  learner==5~"CV-lasso\n(extended)",
                                  learner==6~"CV-ridge\n(extended)",
                                  learner==7~"Random\nforest 1",
                                  learner==8~"Random\nforest 2",
                                  learner==9~"Random\nforest 3",
                                  learner==10~"Gradient\nboosting 1",
                                  learner==11~"Gradient\nboosting 2",
                                  learner==12~"Neural\nnet 1",
                                  learner==13~"Neural\nnet 2",
                                  learner==0 ~"Stacking\nw/o cross-fitting",
                                  learner==-1  ~"Regular\nstacking",
                                  learner==-2  ~"Short-\nstacking",
                                  learner==-3  ~"Pooled\nstacking"
  ))

dta <- dta |>
  mutate(
    learner_name=as.factor(learner_name),
  learner_name=fct_relevel(learner_name,
                           "OLS/logit",
                           "OLS/logit\n(simple)",
                           "CV-lasso",
                           "CV-ridge",
                           "CV-lasso\n(extended)",
                           "CV-ridge\n(extended)",
                           "Random\nforest 1",
                           "Random\nforest 2",
                           "Random\nforest 3",
                           "Gradient\nboosting 1",
                           "Gradient\nboosting 2",
                           "Neural\nnet 1",
                           "Neural\nnet 2",
                           "Regular\nstacking",
                           "Short-\nstacking",
                           "Pooled\nstacking"
              ), 
    learner_name =fct_rev(learner_name)
  )

dta <- dta |>
  mutate(statistic=coef/stderr,
          p.value=2*pnorm(-abs(statistic)))

dta_median <- dta |> 
  group_by(model,crossfit,learner_name,final,stacking) |>
  mutate(coef_median=median(coef)
  ) |>
  ungroup() |>  
  mutate(stderr_median=stderr^2+(coef_median-coef)^2) |>
  group_by(model,crossfit,learner_name,final,stacking) |>
  summarise(coef=first(coef_median),
            stderr=mean(stderr_median),
            var=first(var) 
  ) |>
  mutate(stderr=sqrt(stderr),
         statistic=coef/stderr,
         p.value=2*pnorm(-abs(statistic)),
         ci_lower=coef-1.96*stderr,
         ci_upper=coef+1.96*stderr)

dta <- bind_rows(dta %>% mutate(aggregate="Single cross-fit"),
                 dta_median %>% mutate(aggregate="Median aggregation",seed=0))

dta <- dta |> 
    mutate(aggregate=as.factor(aggregate),
           aggregate=fct_relevel(aggregate,"Single cross-fit","Median aggregation"),
           learner_name=fct_rev(learner_name)
           )

################################################################################
### plots                                                                    ###
################################################################################
 

plot_indiv <- dta |>  
  filter(model=="interactive") |>
  filter(crossfit) |>
  filter(final =="indiv") |> 
  ggplot() +
  geom_pointrange(aes(x=learner_name,ymin=ci_lower,ymax=ci_upper,y=coef,
                      color=aggregate, 
                      group=seed
  ),size=.3,alpha=.7,
  position = position_dodge(width=.8)
  )+
  geom_hline(yintercept=0,alpha=.7)+
  theme_minimal() +
  theme(axis.text.x=element_text(angle=60,hjust=1),
    legend.position="bottom",#c(.8,.1)
    #legend.box.background=element_rect(fill="white", color="white")
  ) +
  scale_color_manual("",values=brewer.pal(n = 5, name = 'Dark2'))+
  scale_linetype_discrete("Controls")+
  scale_shape_manual("Controls",values=15:19)+ 
  xlab("") +
  ylab("Unexplained wage gap")  +
  guides(color = guide_legend(nrow = 1)) +
  ggtitle("Candidate learners")   
plot_indiv  
#ggsave("/Users/kahrens/MyProjects/ddml_sjpaper/GWG/indiv_estimates.png",unit="cm",height=13,width=20)

plot_cls <- dta |>  
  filter(model=="interactive") |>
  filter(crossfit) |>
  filter(final =="nnls1") |> 
  ggplot() +
  geom_pointrange(aes(x=learner_name,ymin=ci_lower,ymax=ci_upper,y=coef,
                      color=aggregate, 
                      group=seed
  ),size=.3,alpha=.7,
  position = position_dodge(width=.8)
  )+
  geom_hline(yintercept=0,alpha=.7)+
  theme_minimal() +
  theme(axis.text.x=element_text(angle=60,hjust=1),
    legend.position="bottom",#c(.8,.1)
    #legend.box.background=element_rect(fill="white", color="white")
  ) +
  scale_color_manual("",values=brewer.pal(n = 5, name = 'Dark2'))+
  scale_linetype_discrete("Controls")+
  scale_shape_manual("Controls",values=15:19)+ 
  scale_y_continuous(limits=c(-.25,.225)) +
  xlab("") +
  ylab("Unexplained wage gap")  +
  guides(color = guide_legend(nrow = 1)) +
  ggtitle("Constrained least squares")  
plot_cls
#ggsave("/Users/kahrens/MyProjects/ddml_sjpaper/GWG/cls_estimates.png",unit="cm",height=13,width=20)
 

plot_sb <- dta |>  
  filter(model=="interactive") |>
  filter(crossfit) |>
  filter(final =="singlebest") |> 
  ggplot() +
  geom_pointrange(aes(x=learner_name,ymin=ci_lower,ymax=ci_upper,y=coef,
                      color=aggregate, 
                      group=seed
  ),size=.3,alpha=.7,
  position = position_dodge(width=.8)
  ) +
  geom_hline(yintercept=0,alpha=.7)+
  theme_minimal() +
  theme(axis.text.x=element_text(angle=60,hjust=1),
    legend.position="bottom",#c(.8,.1)
    #legend.box.background=element_rect(fill="white", color="white")
  ) +
  scale_color_manual("",values=brewer.pal(n = 5, name = 'Dark2'))+
  scale_linetype_discrete("Controls")+
  scale_shape_manual("Controls",values=15:19)+ 
  scale_y_continuous(limits=c(-.25,.225)) +
  xlab("") +
  ylab("")  +
  ggtitle("Single-best") +
  guides(color = guide_legend(nrow = 1)) 
plot_sb
#ggsave("/Users/kahrens/MyProjects/ddml_sjpaper/GWG/sb_estimates.png",unit="cm",height=13,width=20)
 

 

plot_indiv / (plot_cls + plot_sb) + plot_layout(guides = "collect")  + plot_layout(height = c(2, 1)) & theme(legend.position = 'bottom')
ggsave("/Users/kahrens/MyProjects/ddml_sjpaper/GWG/all_estimates.png",unit="cm",height=15,width=20)



################################################################################
### table.                                                                   ###
################################################################################

dta_table <- 
dta |>
  filter(final!="init") |>
  filter(str_detect(aggregate,"Median")) |>
  filter(model=="interactive") |>
  rename(std.error=stderr,estimate=coef,estimator=learner_name) |>
  mutate(stars=case_when(p.value<.1~"*",
                           p.value<.05~"**",
                           p.value<.01~"***",
                           TRUE~""
    ),
    std.error=paste0("(",round(std.error,3),")",stars),
    estimate=as.character(round(estimate,3))
    ) |> 
  select(estimate,std.error,estimator,final) |>
  pivot_longer(-c(3:4)) |>
  mutate( 
    estimator=fct_relevel(estimator,
                          c( "OLS/logit",
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
                             "Neural net 2",
                             "Regular stacking",
                             "Short-stacking",
                             "Pooled stacking")) 
    ) |>
  arrange(estimator,name) 

dta_table |>
  filter(final!="indiv") |>
  pivot_wider(names_from="final") |> 
  mutate(estimator=if_else(name=="estimate",estimator,"")) |>
  select(-name) |>
  xtable(digits=3) |>
  print(hline.after=NULL,
        include.rownames=FALSE,
        include.colnames=TRUE,
        only.contents=TRUE ,
        file="/Users/kahrens/MyProjects/ddml_sjpaper/GWG/regression_results_1.tex"
  )

dta_table |>
  filter(final=="indiv") |>
  pivot_wider(names_from="final") |> 
  mutate(estimator=if_else(name=="estimate",estimator,"")) |>
  select(-name) |>
  xtable(digits=3) |>
  print(hline.after=NULL,
        include.rownames=FALSE,
        include.colnames=TRUE,
        only.contents=TRUE ,
        file="/Users/kahrens/MyProjects/ddml_sjpaper/GWG/regression_results_2.tex"
  )

