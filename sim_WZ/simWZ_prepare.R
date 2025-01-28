
library(R.matlab)
library("tidyverse")

setwd("/Users/kahrens/MyProjects/ddml_simulations")

dta1 <- readMat("data_spec1.mat")
k1 <- ncol(dta1$Xmat)
dta1 <- as.data.frame(cbind(dta1$y,dta1$d,dta1$Xmat))
colnames(dta1) <- c("y","d",paste0("s1_x",1:k1))

dta2 <- readMat("data_spec2.mat")
k2 <- ncol(dta2$Xmat)
dta2 <- as.data.frame(cbind(dta2$y,dta2$d,dta2$Xmat))
colnames(dta2) <- c("y","d",paste0("s2_x",1:k2))

sum(dta1$y!=dta2$y)
sum(dta1$d!=dta2$d)

dtaBoth <- cbind(dta1,dta2[,-c(1,2)])

write_csv(dtaBoth,file="data_spec1and2.csv")
 