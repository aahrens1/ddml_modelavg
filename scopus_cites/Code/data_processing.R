
library("arrow")
library("dplyr")
library("rjson")
library("jsonlite")
library("httr")
library("stringr")
library("tidyr")
library("tidylog")

setwd("/Users/kahrens/MyProjects/ddml_applied_scopus")

dta <- open_dataset("parquet")
dta <- dta |> collect()

dta$journal |> table() |> length()

# deal with duplicates
dta <- dta |>
  group_by(scopus_id) |>
  mutate(max_cite=max(citedby_count)) |>
  ungroup() |>
  filter(max_cite==citedby_count)
dta <- dta |> 
  group_by(scopus_id) |>
  filter(row_number()==1) |>
  ungroup()  
  
author_json <- list()
for (i in 1:nrow(dta)) {
  x <- dta[i,]
  scopus_id <- x$scopus_id
  if (!is.na(x$author)) {
    json <- fromJSON(x$author)
    author_json[[as.character(scopus_id)]] <-
            data.frame(given_name=json$`given-name`,
                      surname=json$surname,
                      scopus_id=scopus_id
                      )
  }
}
authors <- bind_rows(author_json)

# unique author names
unique_authors <- authors |> select(-scopus_id) |> unique()

## retrieve already-gendered authors (from previous runs)
#gendered_authors <- readRDS(file="gendered_authors.RDS")
gendered_authors <- readRDS(file="gendered_authors30-May-2024 15.54.RDS")
unique_authors <- left_join(unique_authors,gendered_authors,
                     c("given_name","surname"))

## retrieve gender via Namsor
if (FALSE) {
  unique_authors$likelyGender <- NA
  unique_authors$probabilityCalibrated <- NA
  for (i in 1:nrow(unique_authors)) {
    if ((i %% 100)==0) print(i)
    if (is.na(unique_authors[i,"likelyGender"])) {
      first_name <- unique_authors[i,"given_name"]
      surname <- unique_authors[i,"surname"]
      first_name <- URLencode(first_name)
      surname <- URLencode(surname)
      getdata<-GET(url=paste0("https://v2.namsor.com/NamSorAPIv2/api2/json/gender/",
                              first_name,"/",surname), 
                       add_headers(.headers=c("X-API-KEY"="< your API here >",
                                              "Accept"="application/json"
                   )))
      cont <- content(getdata, as = 'parsed')   
      unique_authors$likelyGender[i] <- cont$likelyGender
      unique_authors$probabilityCalibrated[i] <- cont$probabilityCalibrated
    }
  }
  gendered_authors <- unique_authors
  saveRDS(gendered_authors,
            file=paste0("gendered_authors",format(Sys.time(), "%d-%b-%Y %H.%M"),".RDS"))
}
## retrieve origin via Namsor
if (FALSE) {
  unique_authors$regionOrigin <- NA
  unique_authors$topRegionOrigin <- NA
  unique_authors$subRegionOrigin <- NA
  unique_authors$countryOrigin <- NA
  unique_authors$probabilityCalibratedOrigin <- NA
  for (i in 1:nrow(unique_authors)) {
    if ((i %% 100)==0) print(i)
    if (is.na(unique_authors[i,"regionOrigin"])) {
      first_name <- unique_authors[i,"given_name"]
      surname <- unique_authors[i,"surname"]
      first_name <- URLencode(first_name)
      surname <- URLencode(surname)
      getdata<-GET(url=paste0("https://v2.namsor.com/NamSorAPIv2/api2/json/origin/",
                              first_name,"/",surname), 
                   add_headers(.headers=c("X-API-KEY"="< your API here >",
                                          "Accept"="application/json"
                   )))
      cont <- content(getdata, as = 'parsed')   
      unique_authors$regionOrigin[i] <- cont$regionOrigin
      unique_authors$topRegionOrigin[i] <- cont$topRegionOrigin
      unique_authors$subRegionOrigin[i] <- cont$subRegionOrigin
      unique_authors$countryOrigin[i] <- cont$countryOrigin
      unique_authors$probabilityCalibratedOrigin[i] <- cont$probabilityCalibrated
    }
  }
  gendered_authors <- unique_authors
  saveRDS(gendered_authors,
          file=paste0("gendered_authors",format(Sys.time(), "%d-%b-%Y %H.%M"),".RDS"))
}

# get share of excluded by region
library("xtable")
region_stats <- unique_authors |>
  mutate(cert = case_when(probabilityCalibrated<.6~"lower than 60%",
                          probabilityCalibrated<.7~"lower than 70%",
                          probabilityCalibrated<.9~"lower than 90%",
                          TRUE ~ "All"
                          ),
         cert=as.factor(cert),
         cert=forcats::fct_relevel(cert,
                          "lower than 60%",
                          "lower than 70%",
                          "lower than 90%",
                          "All"
                          )
         ) 
region_stats1 <- region_stats |>
  group_by(cert,regionOrigin) |>
  summarise(count=n()) |>
  group_by(regionOrigin) |>
  mutate(total=sum(count)) |>
  ungroup() |>
  mutate(share=count/total) |>
  select(-count,-total) |>
  group_by(regionOrigin) |>
  mutate(share=cumsum(share)) |> 
  pivot_wider(values_from=c("share"),names_from="regionOrigin")
region_stats2 <- region_stats |>
  group_by(cert) |>
  summarise(total=n()) |>
  ungroup() |>
  mutate(total=cumsum(total))
left_join(region_stats1,region_stats2,c("cert")) |>
  xtable()

# set to NA if p<.7
unique_authors <- unique_authors |>
  mutate(likelyGender_original=likelyGender,
         likelyGender = if_else(probabilityCalibrated<.6,"n/a",likelyGender),
         female =likelyGender=="female",
         missing =likelyGender=="n/a", 
         reg_europe=1*(regionOrigin=="Europe"),
         reg_africa=1*(regionOrigin=="Africa"),
         reg_lac=1*(regionOrigin=="Latin America and the Caribbean"),
         reg_asia=1*(regionOrigin=="Asia")
            )

# add to author-paper table
authors <- left_join(authors,unique_authors,c("given_name","surname"))

papers <- authors |> 
  group_by(scopus_id) |>
  summarise(female=mean(female),
            missing=mean(missing),
            author_count=n(),
            reg_europe=mean(reg_europe,na.rm=TRUE),
            reg_africa=mean(reg_africa,na.rm=TRUE),
            reg_lac=mean(reg_lac,na.rm=TRUE),
            reg_asia=mean(reg_asia,na.rm=TRUE)
            ) |>
  ungroup()
papers <- filter(papers,missing==0)
papers <- papers |>
  mutate(any_female =female>0,
         all_female=female==1)

dta <- left_join(dta,papers,c("scopus_id"))
dta <- filter(dta,!is.na(abstract))
dta <- filter(dta,!is.na(any_female))

write_parquet(dta,"scopus_with_gender_60.parquet")
  
if (FALSE) {
  dta_final <- left_join(read_parquet("scopus_with_gender_60.parquet") |> 
                           mutate(threshold60=1) |>
                           rename(any_female60=any_female,all_female60=all_female),
                         read_parquet("scopus_with_gender_70.parquet") |> 
                            mutate(threshold70=1) |> 
                            select(scopus_id,any_female,all_female,threshold70) |>
                           rename(any_female70=any_female,all_female70=all_female),
                          c("scopus_id"))
  dta_final <- left_join(dta_final,
                         read_parquet("scopus_with_gender_90.parquet") |> 
                           mutate(threshold90=1) |> 
                           select(scopus_id,any_female,all_female,threshold90)  |>
                           rename(any_female90=any_female,all_female90=all_female),
                         c("scopus_id"))  
 write_parquet(dta_final,"scopus_with_gender_all.parquet")
 dta_final$threshold60 |> table(useNA="al")
 dta_final$threshold70 |> table(useNA="al")
 dta_final$threshold90 |> table(useNA="al")
}
