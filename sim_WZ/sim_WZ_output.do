
clear all

if ("`c(os)'"=="MacOSX") {
	adopath + "/Users/kahrens/MyProjects/ddml"
	adopath + "/Users/kahrens/MyProjects/pystacked"
	cd "/Users/kahrens/MyProjects/ddml_applied/"
}
else {
	cd "/cluster/home/kahrens/ddml_applied/"
	cap python set exec /cluster/apps/nss/gcc-8.2.0/python/3.9.9/x86_64/bin/python3
	cap set processors 1
}

global outpath /Users/kahrens/MyProjects/ddml_sjpaper/Simul/sim_WZ
global outpath2 /Users/kahrens/MyProjects/ddml_simulations/sim_WZ/output
cap mkdir $outpath
global folder out 
cd sim_WZ

local files : dir $folder files "*.dta"
foreach f in `files' {
	cap append using $folder/`f'	
}

drop if missing(obs)

foreach i of numlist 1(1)10 {
	egen ddml_x_`i'_md_b = rowmedian(ddml_x_`i'_*_b)
	egen ddml_x_`i'_mn_b = rowmean(ddml_x_`i'_*_b)
}

bysort obs f rep: gen i = _n
*keep if i <= 600 | obs>=9915

save simWZ_temp.dta, replace


**************************************************************************	
********* collapse
**************************************************************************	

use simWZ_temp.dta, clear

gen count = 1

** duplicate to calculate sd
foreach var of varlist *_b {
	gen double `var'sd=`var'
}

collapse (mean) *_b (sum) count (sd) *_bsd (mean) *_se, by(f rep obs)
order count, first

** bias relative to the full-sample estimates
foreach var of varlist *_b {
	gen `var'0 = `var'
	replace `var'0 = . if obs <9915
	egen `var'true = max(`var'0)
	drop `var'0
 	gen `var'bias = `var' - `var'true
	gen `var'biassd = (`var' - `var'true)/`var'sd
}
order obs count, first

save simWZ_temp_collapse_foldlong.dta, replace

ds pds* ddml* ols*
local vars =r(varlist)
reshape wide `vars' , i(obs count rep) j(f)

foreach f in 2 10 {
foreach i in bbias bbiassd  {
	label var olsa_`i'`f' "OLS TWI"
	label var olsb_`i'`f' "OLS QSI"
	label var pds1a_`i'`f' "pdslasso TWI c=0.5"
	label var pds2a_`i'`f' "pdslasso TWI c=1"
	label var pds3a_`i'`f' "pdslasso TWI c=1.5"
	label var pds1b_`i'`f' "pdslasso QSI c=0.5"
	label var pds2b_`i'`f' "pdslasso QSI c=1"
	label var pds3b_`i'`f' "pdslasso QSI c=1.5"
	foreach m in md mn {
		label var ddml_x_1_`m'_`i'`f' "DDML & OLS (K=`f')"
		label var ddml_x_2_`m'_`i'`f' "DDML & CV lasso TWI (K=`f')"
		label var ddml_x_3_`m'_`i'`f' "DDML & CV ridge TWI (K=`f')"
		label var ddml_x_4_`m'_`i'`f' "DDML & CV lasso QSI (K=`f')"
		label var ddml_x_5_`m'_`i'`f' "DDML & CV ridge QSI (K=`f')"
		label var ddml_x_6_`m'_`i'`f' "DDML & RF low (K=`f')"
		label var ddml_x_7_`m'_`i'`f' "DDML & RF high (K=`f')"
		label var ddml_x_8_`m'_`i'`f' "DDML & boosting low (K=`f')"
		label var ddml_x_9_`m'_`i'`f' "DDML & boosting high (K=`f')"
		label var ddml_x_10_`m'_`i'`f' "DDML & neural net (K=`f')" 
	}
	label var ddml_ss_singlebest_md_`i'`f' "DDML, short-stacking & single-best (K=`f')"
	label var ddml_ss_nnls1_md_`i'`f' "DDML & short-stacking (K=`f')"
	label var ddml_ps_singlebest_md_`i'`f' "DDML, short-stacking & single-best (K=`f')"
	label var ddml_ps_nnls1_md_`i'`f' "DDML & short-stacking (K=`f')"
	label var ddml_st_singlebest_md_`i'`f' "DDML, regular stacking & single-best (K=`f')"
	label var ddml_st_nnls1_md_`i'`f' "DDML & regular stacking (K=`f')"
	replace olsb_`i'`f'= . if obs<300 // not identified
}
}
save simWZ_temp_collapse.dta, replace


**************************************************************************	
********* bias  
**************************************************************************	

use simWZ_temp_collapse.dta, clear


drop *_se*

global graph_set ytitle("Mean bias relative to full sample") xtitle("Bootstrap sample size")  ///
	xtick(200 400 600 800 1200 1600) xlabel(200 400 600 800 1200 1600) //ylabel(-2000 0 2000 4000 6000 8000 10000)
global graph_set_sd ytitle("Ratio of bias to standard deviation") xtitle("Bootstrap sample size")  /// 
	xtick(200 400 600 800 1200 1600) xlabel(200 400 600 800 1200 1600) ///
	//ylabel(-.2 0 .2 .4 .6 .8)
	
*replace ddml2_6_bbias = . if  ddml2_6_bbias<10000
*replace ddml2_7_bbias = . if  ddml2_7_bbias<10000
*replace ddml2_6_bbiassd = . if  ddml2_6_bbiassd<.8
*replace ddml2_7_bbiassd = . if  ddml2_7_bbiassd<.8

keep if obs<9915
drop *true*

	*local i bbias
	*local i bbias
 	*line olsa_bbias  olsb_bbias  pds2a_bbias  pds2b_bbias  ///
	*	ddml_st_nnls1_md_bbias ddml_ss_nnls1_md_bbias     ///
	*	///ddml2_0_`i' ddml2_ss_`i'   ///
	*	///ddmlx_0_`i'     ///
	*	obs , ///
	*	lpat(solid dash solid dash solid solid dash dash dash_dot ) ///
	*	lcol(black black gray gray dkgreen   blue dkgreen blue dkgreen) ///
	*	$graph_set 

foreach i in bbias bbiassd {
	
	global graph_set_use nodraw
	if ("`i'"=="bbias") global graph_set_use $graph_set  
	if ("`i'"=="bbiassd") global graph_set_use $graph_set_sd  
	
	line olsa_`i'10  ///
		pds1a_`i'10 pds2a_`i'10 pds3a_`i'10 ///
		obs , ///
		lpat(solid solid dash dash_dot  ) ///
		lcol(black dkgreen dkgreen dkgreen ) ///
		$graph_set_use
	graph export $outpath/pdsa_`i'.png, replace 
	graph export $outpath2/pdsa_`i'.png, replace 
	
	line olsb_`i'2  ///
		pds1b_`i'2 pds2b_`i'2 pds3b_`i'2  ///
		obs , ///
		lpat(solid solid dash dash_dot  ) ///
		lcol(black dkgreen dkgreen dkgreen ) ///
		$graph_set_use
	graph export $outpath/pdsb_`i'.png, replace 
	graph export $outpath2/pdsb_`i'.png, replace 
	
	forvalues j=1(1)10 {
		line olsa_`i'2 olsb_`i'2 pds2a_`i'2 pds2b_`i'2 ///
			ddml_x_`j'_md_`i'10 ///
			ddml_x_`j'_md_`i'2 /// 
 			obs , ///
			lpat(solid dash solid dash solid solid ) ///
			lcol(black black dkgreen dkgreen blue red) ///
			$graph_set_use
		graph export $outpath/candidate`j'_`i'.png, replace 	
		graph export $outpath2/candidate`j'_`i'.png, replace 
	}
	
	line olsa_`i'2 olsb_`i'2 pds2a_`i'2 pds2b_`i'2 ///
		ddml_st_nnls1_md_`i'10 /// 
		ddml_ss_nnls1_md_`i'10 /// 
 		obs , ///
		lpat(solid dash solid dash solid solid ) ///
		lcol(black black dkgreen dkgreen blue red) ///
		$graph_set_use
	graph export $outpath/stack_`i'.png, replace 	
	graph export $outpath2/stack_`i'.png, replace 	
	
	foreach stack in ss st ps {
		line olsa_`i'2 olsb_`i'2 pds2a_`i'2 pds2b_`i'2 ///
			ddml_`stack'_nnls1_md_`i'2 /// 
			ddml_`stack'_nnls1_md_`i'10 /// 
			obs , ///
			lpat(solid dash solid dash solid solid ) ///
			lcol(black black dkgreen dkgreen blue red) ///
			$graph_set_use
		graph export $outpath/`stack'_`i'.png, replace 	
		graph export $outpath2/`stack'_`i'.png, replace
	}
	
}

**************************************************************************	
********* table bias  
**************************************************************************	

use simWZ_temp_collapse_foldlong.dta, clear

*** as table
drop count
keep obs f rep *bias*
foreach var of varlist *bbias*  {
	rename `var' v_`var'
}

reshape long v_, i(obs rep f) j(estimator) string
reshape wide v_, i(estimator rep f) j(obs) 
drop v_9915

gen estimator_desc = ""
replace estimator_desc = "OLS" if regexm(estimator,"ddml_x_1_md") 
replace estimator_desc = "Lasso with CV (TWI)" if regexm(estimator,"ddml_x_2_md")
replace estimator_desc = "Ridge with CV (TWI)" if regexm(estimator,"ddml_x_3_md")
replace estimator_desc = "Lasso with CV (QSI)" if regexm(estimator,"ddml_x_4_md")
replace estimator_desc = "Ridge with CV (QSI)" if regexm(estimator,"ddml_x_5_md")
replace estimator_desc = "Random forest (low regularization)" if regexm(estimator,"ddml_x_6_md")
replace estimator_desc = "Random forest (high regularization)" if regexm(estimator,"ddml_x_7_md")
replace estimator_desc = "Gradient boosting (low regularization)" if regexm(estimator,"ddml_x_8_md")
replace estimator_desc = "Gradient boosting (high regularization)" if regexm(estimator,"ddml_x_9_md")
replace estimator_desc = "Neural net" if regexm(estimator,"ddml_x_10_md")
replace estimator_desc = "Short-stacking: CLS" if regexm(estimator,"ddml_ss_nnls1_md")
replace estimator_desc = "Short-stacking: Single-best" if regexm(estimator,"ddml_ss_singlebest_md")
replace estimator_desc = "Pooled stacking: CLS" if regexm(estimator,"ddml_ps_nnls1_md")
replace estimator_desc = "Pooled stacking: Single-best" if regexm(estimator,"ddml_ps_singlebest_md")
replace estimator_desc = "Stacking: CLS" if regexm(estimator,"ddml_st_nnls1_md")
replace estimator_desc = "Stacking: Single-best" if regexm(estimator,"ddml_st_singlebest_md")
replace estimator_desc="Post double Lasso TWI c=0.5"  if regexm(estimator,"pds1a")
replace estimator_desc="Post double Lasso TWI c=1"  if regexm(estimator,"pds2a")
replace estimator_desc="Post double Lasso TWI c=1.5"  if regexm(estimator,"pds3a")
replace estimator_desc="Post double Lasso QSI c=0.5" if regexm(estimator,"pds1b")
replace estimator_desc="Post double Lasso QSI c=1" if regexm(estimator,"pds2b")
replace estimator_desc="Post double Lasso QSI c=1.5" if regexm(estimator,"pds3b")
replace estimator_desc="OLS TWI" if regexm(estimator,"olsa")
replace estimator_desc="OLS QSI" if regexm(estimator,"olsb")
keep if estimator_desc!=""

keep if !regexm(estimator,"_bbiassd")

gen sortid = estimator
replace sortid =subinstr(sortid,"ddml_x_","",.)
replace sortid =subinstr(sortid,"_md","",.)
replace sortid =subinstr(sortid,"_bbias","",.)
destring sortid, force replace

replace sortid=0.01 if regexm(estimator,"ols")
replace sortid=0.1 if regexm(estimator,"pds")
replace sortid=11 if regexm(estimator,"ddml_ss")
replace sortid=12 if regexm(estimator,"ddml_st")
replace sortid=12 if regexm(estimator,"ddml_ps")

sort sortid estimator_desc

gen gap = ""

foreach var of varlist v* {
	replace `var' = round(`var',0.1)
}

foreach ff in 2 10 {

	texsave gap estimator_desc v_200 v_400 v_600 v_800 v_1200 v_1600 ///
				using $outpath/bias_ddml_candidate_f`ff'.tex if regexm(estimator,"ddml_x") & f==`ff', dataonly replace
	texsave gap estimator_desc v_200 v_400 v_600 v_800 v_1200 v_1600 ///
				using $outpath/bias_ddml_meta_f`ff'.tex if !regexm(estimator,"ddml_x") & regexm(estimator,"ddml")  & f==`ff', dataonly replace
	texsave gap estimator_desc v_200 v_400 v_600 v_800 v_1200 v_1600 ///
				using $outpath/bias_olspds_f`ff'.tex if (regexm(estimator,"ols") | regexm(estimator,"pds"))  & f==`ff', dataonly replace
	 
	texsave gap estimator_desc v_200 v_400 v_600 v_800 v_1200 v_1600 ///
				using $outpath2/bias_ddml_candidate_f`ff'.tex if regexm(estimator,"ddml_x")  & f==`ff', dataonly replace
	texsave gap estimator_desc v_200 v_400 v_600 v_800 v_1200 v_1600 ///
				using $outpath2/bias_ddml_meta_f`ff'.tex if !regexm(estimator,"ddml_x") & regexm(estimator,"ddml")  & f==`ff', dataonly replace
	texsave gap estimator_desc v_200 v_400 v_600 v_800 v_1200 v_1600 ///
				using $outpath2/bias_olspds_f`ff'.tex if (regexm(estimator,"ols") | regexm(estimator,"pds")) & f==`ff', dataonly replace
	 
}

**************************************************************************	
********* export weights  
**************************************************************************	
 
foreach ww in stw ssw psw {
foreach ff in 2 10 { 
foreach final in singlebest nnls1 {
		
	use simWZ_temp.dta, clear

	gen count = 1
	collapse (mean) `ww'_`final'_* (sum) count , by(obs f rep)

	drop count

	reshape long `ww'_`final'_, i(obs f rep) j(estimator) string
	reshape wide `ww'_`final'_, i(estimator  f rep) j(obs)  
	
	keep if f==`ff'  & rep ==5

	keep estimator `ww'*

	gen estimator_desc = ""
	replace estimator_desc = "OLS" if regexm(estimator,"1") & !regexm(estimator,"10") 
	replace estimator_desc = "Lasso with CV (TWI)" if regexm(estimator,"2")
	replace estimator_desc = "Ridge with CV (TWI)" if regexm(estimator,"3")
	replace estimator_desc = "Lasso with CV (QSI)" if regexm(estimator,"4")
	replace estimator_desc = "Ridge with CV (QSI)" if regexm(estimator,"5")
	replace estimator_desc = "Random forest (low regularization)" if regexm(estimator,"6")
	replace estimator_desc = "Random forest (high regularization)" if regexm(estimator,"7")
	replace estimator_desc = "Gradient boosting (low regularization)" if regexm(estimator,"8")
	replace estimator_desc = "Gradient boosting (high regularization)" if regexm(estimator,"9")
	replace estimator_desc = "Neural net" if regexm(estimator,"10")

	foreach var of varlist `ww'* {
		replace `var'=round(`var',0.001)
	}

	gen gap = ""
	texsave gap estimator_desc `ww'* ///
				using $outpath/`ww'_d_`final'_folds`ff'.tex if regexm(estimator,"d"), dataonly replace
	texsave gap estimator_desc `ww'* ///
				using $outpath/`ww'_y_`final'_folds`ff'.tex if regexm(estimator,"y"), dataonly replace

	texsave gap estimator_desc `ww'* ///
				using $outpath2/`ww'_d_`final'_folds`ff'.tex if regexm(estimator,"d"), dataonly replace
	texsave gap estimator_desc `ww'* ///
				using $outpath2/`ww'_y_`final'_folds`ff'.tex if regexm(estimator,"y"), dataonly replace

}
}
}
			
**************************************************************************	
********* full sample estimates 
**************************************************************************	

use simWZ_temp_collapse_foldlong.dta, clear

keep if obs == 9915 & f==10
keep obs *_b *_se

foreach var of varlist *_b {
	local var = subinstr("`var'","_b","",.)
	rename `var'_b est_`var'
}
foreach var of varlist *_se {
	local var = subinstr("`var'","_se","",.)
	rename `var'_se se_`var'
}
reshape long est_ se_ , i(obs) j(estimator) string

drop obs

drop if regexm(estimator,"_x_") & !regexm(estimator,"_x_")

gen estimator_desc = ""
replace estimator_desc = "OLS" if regexm(estimator,"ddml_x_1_md") 
replace estimator_desc = "Lasso with CV (TWI)" if regexm(estimator,"ddml_x_2_md")
replace estimator_desc = "Ridge with CV (TWI)" if regexm(estimator,"ddml_x_3_md")
replace estimator_desc = "Lasso with CV (QSI)" if regexm(estimator,"ddml_x_4_md")
replace estimator_desc = "Ridge with CV (QSI)" if regexm(estimator,"ddml_x_5_md")
replace estimator_desc = "Random forest (low regularization)" if regexm(estimator,"ddml_x_6_md")
replace estimator_desc = "Random forest (high regularization)" if regexm(estimator,"ddml_x_7_md")
replace estimator_desc = "Gradient boosting (low regularization)" if regexm(estimator,"ddml_x_8_md")
replace estimator_desc = "Gradient boosting (high regularization)" if regexm(estimator,"ddml_x_9_md")
replace estimator_desc = "Neural net" if regexm(estimator,"ddml_x_10_md")
replace estimator_desc = "Short-stacking: CLS" if regexm(estimator,"ddml_ss_nnls1_md")
replace estimator_desc = "Short-stacking: Single-best" if regexm(estimator,"ddml_ss_singlebest_md")
replace estimator_desc = "Pooled stacking: CLS" if regexm(estimator,"ddml_ps_nnls1_md")
replace estimator_desc = "Pooled stacking: Single-best" if regexm(estimator,"ddml_ps_singlebest_md")
replace estimator_desc = "Stacking: CLS" if regexm(estimator,"ddml_st_nnls1_md")
replace estimator_desc = "Stacking: Single-best" if regexm(estimator,"ddml_st_singlebest_md")
replace estimator_desc="Post double Lasso TWI c=0.5"  if regexm(estimator,"pds1a")
replace estimator_desc="Post double Lasso TWI c=1"  if regexm(estimator,"pds2a")
replace estimator_desc="Post double Lasso TWI c=1.5"  if regexm(estimator,"pds3a")
replace estimator_desc="Post double Lasso QSI c=0.5" if regexm(estimator,"pds1b")
replace estimator_desc="Post double Lasso QSI c=1" if regexm(estimator,"pds2b")
replace estimator_desc="Post double Lasso QSI c=1.5" if regexm(estimator,"pds3b")
replace estimator_desc="OLS TWI" if regexm(estimator,"olsa")
replace estimator_desc="OLS QSI" if regexm(estimator,"olsb")
keep if estimator_desc!=""

gen gap = ""
texsave gap estimator_desc est_   ///
			using $outpath/fullsample_ddml.tex if regexm(estimator,"ddml_x")  , dataonly replace
texsave gap estimator_desc est_  ///
			using $outpath/fullsample_meta.tex if !regexm(estimator,"ddml_x") & regexm(estimator,"ddml"), dataonly replace
texsave gap estimator_desc est_  ///
			using $outpath/fullsample_olspds.tex if regexm(estimator,"ols") | regexm(estimator,"pds"), dataonly replace

texsave gap estimator_desc est_   ///
			using $outpath2/fullsample_ddml.tex if regexm(estimator,"ddml_x")  , dataonly replace
texsave gap estimator_desc est_   ///
			using $outpath2/fullsample_meta.tex if !regexm(estimator,"ddml_x") & regexm(estimator,"ddml"), dataonly replace
texsave gap estimator_desc est_  ///
			using $outpath2/fullsample_olspds.tex if regexm(estimator,"ols") | regexm(estimator,"pds"), dataonly replace
