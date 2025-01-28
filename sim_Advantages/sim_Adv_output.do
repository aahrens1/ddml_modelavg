
clear all
cap cd /cluster/home/kahrens/ddml_applied
cap cd /Users/kahrens/MyProjects/ddml_applied

global outpath /Users/kahrens/MyProjects/ddml_sjpaper/Simul/sim_Advantages
cap mkdir $outpath 
global folder out 
cap mkdir sim_Advantages
cd sim_Advantages

local files : dir outlarge files "*.dta"
foreach f in `files' {
	preserve
	tempfile tfile
	qui cap use outlarge/`f', clear
	if _rc==0 {
		gen file = "`f'"
		qui save `tfile', replace	
	}
	restore
	qui cap append using `tfile'
}
local files: dir outsmall files "*.dta"
foreach f in `files' {
	preserve
	tempfile tfile
	qui cap use outsmall/`f', clear
	if _rc==0 {
		gen file = "`f'"
		qui save `tfile', replace	
	}
	restore
	qui cap append using `tfile'
}

replace obs = obs*dsets
drop dsets

tab obs dgp

global estlist
foreach var of varlist ddml*b ols_b pds_b {
	local i = subinstr("`var'","_b","",.)
	di "`i'"
	global estlist $estlist `i'_
	qui gen `i'_bias = (`i'_b-tau) 
	qui gen `i'_abias = abs(`i'_b - tau)
	qui gen `i'_z = (`i'_b - tau)/`i'_se
	qui gen `i'_cover = abs(`i'_z)<=1.96
}

** drop additional simulation runs if there are more than 1000
bysort dgp obs tau kappa1 kappa2 folds: gen i=_n
drop if i>1000

foreach var of varlist *_bias {
	gen `var'se = `var'
}

gen count = 1
collapse (mean) *_bias *_cover		///
		 (semean) *_biasse          ///
		 (median) *_abias  			///
		 (sum) count 				///
		 (mean) *_b stw* ssw* psw* mspe* , by(dgp obs tau kappa1 kappa2 folds)		

order count, first	 
	
// confirm 1000 repetitions
assert count == 1000 | folds ==5	 
	 
save sim_temp.dta, replace

********************************************************************************
********* bias and coverage 
********************************************************************************

use sim_temp.dta, clear

drop stw* psw* ssw_* mspe* sd*
	
reshape long $estlist, ///
				i(dgp obs tau kappa1 kappa2 folds) j(measure) string
foreach var of varlist $estlist {
	rename `var' v_`var' 
}
reshape long v_, i(measure dgp obs tau kappa1 kappa2 folds) j(estimator) string
reshape wide v_, i(estimator dgp obs tau kappa1 kappa2 folds) j(measure) string

drop count

reshape wide v_b v_bias v_abias v_cover v_biasse, i(estimator dgp tau kappa1 kappa2 folds) j(obs)  

keep folds dgp estimator v*

gen sortid=1 if estimator=="ols_"
replace sortid=2 if estimator=="pds_"
replace sortid=4 if estimator=="ddml_1_"
replace sortid=5 if estimator=="ddml_2_"
replace sortid=6 if estimator=="ddml_3_"
replace sortid=7 if estimator=="ddml_4_"
replace sortid=8 if estimator=="ddml_5_"
replace sortid=9 if estimator=="ddml_6_"
replace sortid=10 if estimator=="ddml_7_"
replace sortid=11 if estimator=="ddml_8_"
replace sortid=12 if estimator=="ddml_9_"
replace sortid=12.1 if estimator=="ddml_10_"
replace sortid=13.1 if estimator=="ddml_st_nnls1_"
replace sortid=13.2 if estimator=="ddml_st_avg_"
replace sortid=13.21 if estimator=="ddml_st_ols_"
replace sortid=13.22 if estimator=="ddml_st_singlebest_"
replace sortid=14.1 if estimator=="ddml_ss_nnls1_"
replace sortid=14.2 if estimator=="ddml_ss_avg_"
replace sortid=14.21 if estimator=="ddml_ss_ols_"
replace sortid=14.22 if estimator=="ddml_ss_singlebest_"
replace sortid=14.61 if estimator=="ddml_ss2_"
replace sortid=14.62 if estimator=="ddml_sb2_"
replace sortid=15.1 if estimator=="ddml_ps_nnls1_"
replace sortid=15.2 if estimator=="ddml_ps_avg_"
replace sortid=15.21 if estimator=="ddml_ps_ols_"
replace sortid=15.22 if estimator=="ddml_ps_singlebest_"
replace estimator = "OLS" if estimator=="ols_"
replace estimator = "PDS-Lasso" if estimator=="pds_"
replace estimator = "OLS" if estimator=="ddml_1_"
replace estimator = "Lasso with CV (2nd order poly)" if estimator=="ddml_2_"
replace estimator = "Ridge with CV (2nd order poly)" if estimator=="ddml_3_"
replace estimator = "Lasso with CV (10th order poly)" if estimator=="ddml_4_"
replace estimator = "Ridge with CV (10th order poly)" if estimator=="ddml_5_"
replace estimator = "Random forest (low regularization)" if estimator=="ddml_6_"
replace estimator = "Random forest (high regularization)" if estimator=="ddml_7_"
replace estimator = "Gradient boosting (low regularization)" if estimator=="ddml_8_"
replace estimator = "Gradient boosting (high regularization)" if estimator=="ddml_9_"
replace estimator = "Neural net" if estimator=="ddml_10_"
* regular stacking
replace estimator = "Stacking: CLS" 		if estimator=="ddml_st_nnls1_"
replace estimator = "Stacking: Average" 	if estimator=="ddml_st_avg_"
replace estimator = "Stacking: OLS" 		if estimator=="ddml_st_ols_"
replace estimator = "Stacking: Single-best" if estimator=="ddml_st_singlebest_"
* short stacking
replace estimator = "Short-stacking: CLS" if estimator=="ddml_ss_nnls1_"
replace estimator = "Short-stacking: Average" if estimator=="ddml_ss_avg_"
replace estimator = "Short-stacking: OLS" if estimator=="ddml_ss_ols_"
replace estimator = "Short-stacking: Single-best" if estimator=="ddml_ss_singlebest_"
replace estimator = "Short-stacking: CLS 2" if estimator=="ddml_ss2_"
replace estimator = "Short-stacking: Single-best 2" if estimator=="ddml_sb2_"
* pooled stacking
replace estimator = "Pooled stacking: CLS" if estimator=="ddml_ps_nnls1_"
replace estimator = "Pooled stacking: Average" if estimator=="ddml_ps_avg_"
replace estimator = "Pooled stacking: OLS" if estimator=="ddml_ps_ols_"
replace estimator = "Pooled stacking: Single-best" if estimator=="ddml_ps_singlebest_"

foreach var of varlist *bias* *cover* {
	replace `var'=round(`var',0.01)
}

tostring  *bias* , replace format(%6.1f) force
tostring  *cover* , replace format(%6.2f) force
foreach var of varlist *cover* {
	replace `var'="0.\phantom{00}" if `var'=="0.00"
	replace `var'="1.\phantom{00}" if `var'=="1.00"
}
foreach var of varlist *bias* {
	replace `var'=subinstr(`var',"e+0","e",.)
}

gen gap1=""
gen gap2=""

sort dgp sortid
order gap1 estimator *_bias9915 *_abias9915 *_cover9915 gap2 *_bias99150 *_abias99150 *_cover99150, first

//br estimator dgp fold *_bias9915 *_abias9915 *_cover9915 gap2 *_bias99150 *_abias99150 *_cover99150

 
** with se, Appendix Table A.2
preserve	

/*br gap1 estimator *_bias200 *_biasse200 *_bias400 *_biasse400 *_bias800 *_biasse800 *_bias1600 *_biasse1600  *_bias9915 *_biasse9915 ///
		using $outpath/sim_output_dgp0_10folds_withse.tex ///
		if dgp==0	& folds==10
		
br gap1 estimator *_bias200 *_biasse200 *_bias400 *_biasse400 *_bias800 *_biasse800 *_bias1600 *_biasse1600  *_bias9915 *_biasse9915 ///
		using $outpath/sim_output_dgp0_10folds_withse.tex ///
		if dgp==1	& folds==10
*/

texsave gap1 estimator *_bias200 *_biasse200 *_bias400 *_biasse400 *_bias800 *_biasse800 *_bias1600 *_biasse1600  *_bias9915 *_biasse9915 ///
		using $outpath/sim_output_dgp0_10folds_withse.tex ///
		if dgp==0	& folds==10, ///
		dataonly replace nofix noendash

texsave gap1 estimator *_bias200 *_biasse200 *_bias400 *_biasse400 *_bias800 *_biasse800 *_bias1600 *_biasse1600  *_bias9915 *_biasse9915 ///
		using $outpath/sim_output_dgp1_10folds_withse.tex ///
		if dgp==1	& folds==10, ///
		dataonly replace nofix noendash						
		
texsave gap1 estimator *_bias200 *_biasse200 *_bias400 *_biasse400 *_bias800 *_biasse800 *_bias1600 *_biasse1600  *_bias9915 *_biasse9915 ///
		using $outpath/sim_output_dgp0_2folds_withse.tex ///
		if dgp==0	& folds==2, ///
		dataonly replace nofix noendash

texsave gap1 estimator *_bias200 *_biasse200 *_bias400 *_biasse400 *_bias800 *_biasse800 *_bias1600 *_biasse1600  *_bias9915 *_biasse9915 ///
		using $outpath/sim_output_dgp1_2folds_withse.tex ///
		if dgp==1	& folds==2, ///
		dataonly replace nofix noendash						
restore
 
drop gap1 gap2

************************************
**** to wide format
************************************
foreach var of varlist v_* {
	rename `var' `var'_
}
ds v_*
local vars = r(varlist)
reshape wide `vars', i(estimator  folds sortid) j(dgp)

gen gap1 =""
gen gap2 =""
gen gap3 =""
gen gap4 =""

sort folds sortid estimator

//br gap1 estimator *_bias9915_0 *_abias9915_0 *_cover9915_0 gap2 *_bias99150_0 *_abias99150_0 *_cover99150_0 ///
//					gap3	*_bias9915_1 *_abias9915_1 *_cover9915_0 gap4 *_bias99150_1 *_abias99150_1 *_cover99150_1 ///
//			 if  folds==2

*** Table 1
texsave gap1 estimator *_bias9915_0 *_abias9915_0 *_cover9915_0 gap2 *_bias99150_0 *_abias99150_0 *_cover99150_0 ///
					gap3	*_bias9915_1 *_abias9915_1 *_cover9915_1 gap4 *_bias99150_1 *_abias99150_1 *_cover99150_1 ///
			using $outpath/sim_output_folds2.tex if  folds==2, dataonly replace nofix noendash
			
*** Table A.2
texsave gap1 estimator *_bias9915_0 *_biasse9915_0  gap2 *_bias99150_0 *_biasse99150_0  ///
						gap3  *_bias9915_1 *_biasse9915_1 gap4 *_bias99150_1 *_biasse99150_1  /// 
			using $outpath/sim_output_folds2_se.tex if  folds==2, dataonly replace nofix noendash
			
** for presentation
texsave gap1 estimator *_bias9915_0 *_abias9915_0 *_cover9915_0 gap2 *_bias99150_0 *_abias99150_0 *_cover99150_0   ///
			using $outpath/sim_output_folds2_pres_dgp0.tex if  folds==2, dataonly replace nofix noendash
texsave gap1 estimator 	*_bias9915_1 *_abias9915_1 *_cover9915_1 gap4 *_bias99150_1 *_abias99150_1 *_cover99150_1 ///
			using $outpath/sim_output_folds2_pres_dgp1.tex if  folds==2, dataonly replace nofix noendash

foreach ff in 2 10 {
	 	
	*** (not used)
	texsave gap1 estimator *_bias200_0 *_bias400_0 *_bias800_0 *_bias1600_0 *_bias9915_0   ///
						gap2	*_bias200_1 *_bias400_1 *_bias800_1 *_bias1600_1 *_bias9915_1   ///
				using $outpath/sim_small_bias_wide_folds`ff'.tex if  folds==`ff', dataonly replace nofix noendash
	 
	*** Table B.5
	texsave gap1 estimator *_cover200_0 *_cover400_0 *_cover800_0 *_cover1600_0 *_cover9915_0   ///
						gap2	*_cover200_1 *_cover400_1 *_cover800_1 *_cover1600_1 *_cover9915_1   ///
				using $outpath/sim_small_cover_wide_folds`ff'.tex if  folds==`ff', dataonly replace nofix noendash
	 	

}

 
********************************************************************************
********* bias PLOT
********************************************************************************

use sim_temp.dta, clear

drop stw* psw* ssw_* mspe* sd*
	
reshape long $estlist, ///
				i(dgp obs tau kappa1 kappa2 folds) j(measure) string
foreach var of varlist $estlist {
	rename `var' v_`var' 
}
reshape long v_, i(measure dgp obs tau kappa1 kappa2 folds) j(estimator) string
reshape wide v_, i(estimator dgp obs tau kappa1 kappa2 folds) j(measure) string

drop count

keep dgpflag obs estimator folds v_bias v_biasse

gen double v_lower=v_bias - 1.96*v_biasse
gen double v_upper=v_bias + 1.96*v_biasse
drop v_biasse

reshape wide v_bias v_lower v_upper, i(dgpflag obs folds  ) j(estimator) string
local v 
foreach i of varlist v_* {
	local v `v' `i'
}
reshape wide `v', i(dgpflag obs  ) j( folds)  	


foreach f of numlist 2 5 10 {
	label var v_biasols_`f' "OLS"  
	label var v_biaspds_`f' "PDS-Lasso"  
	label var v_biasddml_1_`f' "OLS, K=`f'"  
	label var v_biasddml_2_`f' "Lasso with CV (2nd order poly), K=`f'"  
	label var v_biasddml_3_`f' "Ridge with CV (2nd order poly), K=`f'"  
	label var v_biasddml_4_`f' "Lasso with CV (10th order poly), K=`f'"  
	label var v_biasddml_5_`f' "Ridge with CV (10th order poly), K=`f'"  
	label var v_biasddml_6_`f' "Random forest (low regularization), K=`f'" 
	label var v_biasddml_7_`f' "Random forest (high regularization), K=`f'" 
	label var v_biasddml_8_`f' "Gradient boosting (low regularization), K=`f'"  
	label var v_biasddml_9_`f' "Gradient boosting (high regularization), K=`f'"  
	label var v_biasddml_10_`f' "Neural net, K=`f'"  
	label var v_biasddml_ss_nnls1_`f' "Short-stacking: CLS, K=`f'"  
	label var v_biasddml_ss_singlebest_`f' "Short-stacking: Single-best, K=`f'" 
	label var v_biasddml_ps_nnls1_`f' "Pooled stacking: CLS, K=`f'" 
	label var v_biasddml_ps_singlebest_`f' "Pooled stacking: Single-best, K=`f'"  
	label var v_biasddml_st_nnls1_`f' "Stacking: CLS, K=`f'"  
	label var v_biasddml_st_singlebest_`f' "Stacking: Single best, K=`f'"  
}

drop if obs >10000

*** Figure 5 a
line 	v_biasols_2  ///
				v_biaspds_2  ///
				v_biasddml_st_nnls1_10  ///
				v_biasddml_ss_nnls1_10  ///
				v_biasddml_ps_nnls1_10  /// 
				obs  if dgp==0 , ///
				lcol(black dkgreen  blue red gray  ) ///
		lpat(solid solid solid solid solid)  ///
		ytitle("Average bias") xtitle("Bootstrap sample size (log scale)")  /// 
		xtick(200 400 600 800 1200 1600 9915) xlabel(200 400 600 800 1200 1600 9915)  ///
		xscale(log) 
graph export $outpath/sim_small_linear.png, replace 

*** Figure 5 b
line v_biasols_2  ///
		v_biaspds_2  ///
		v_biasddml_st_nnls1_10  ///
		v_biasddml_ss_nnls1_10  ///
		v_biasddml_ps_nnls1_10  /// 
		obs  if dgp==1 ///
		, ///
		ytitle("Average bias") xtitle("Bootstrap sample size (log scale)")  /// 
		xtick(200 400 600 800 1200 1600 9915) xlabel(200 400 600 800 1200 1600 9915)  ///
		lcol(black dkgreen  blue red gray  ) ///
		lpat(solid solid solid solid solid) ///
		xscale(log)
graph export $outpath/sim_small_nonlinear.png, replace 




********************************************************************************
********* stacking weights 
********************************************************************************

use sim_temp.dta, clear

keep if folds==2

keep dgp obs stw* psw* ssw_*  

sort dgp obs

gen dgp_desc = "Gradient boosting" if dgpflag==1
replace dgp_desc="Linear DGP" if dgpflag==0
drop dgpflag

reshape long stw_ psw_ ssw_  , i(obs dgp) j(estimator) string

gen equation = "D" if regexm(estimator,"d")
replace equation = "Y" if regexm(estimator,"y")

gen estimator_desc = ""
replace estimator_desc = "OLS" if regexm(estimator,"1") & !regexm(estimator,"10") 
replace estimator_desc = "Lasso with CV (2nd order poly)" if regexm(estimator,"2")
replace estimator_desc = "Ridge with CV (2nd order poly)" if regexm(estimator,"3")
replace estimator_desc = "Lasso with CV (10th order poly)" if regexm(estimator,"4")
replace estimator_desc = "Ridge with CV (10th order poly)" if regexm(estimator,"5")
replace estimator_desc = "Random forest (low regularization)" if regexm(estimator,"6")
replace estimator_desc = "Random forest (high regularization)" if regexm(estimator,"7")
replace estimator_desc = "Gradient boosting (low regularization)" if regexm(estimator,"8")
replace estimator_desc = "Gradient boosting (high regularization)" if regexm(estimator,"9")
replace estimator_desc = "Neural net" if regexm(estimator,"10")
drop if estimator_desc==""

gen sortid = 1
replace sortid = 1  if regexm(estimator,"1") & !regexm(estimator,"10") & !regexm(estimator,"nnls1") 
replace sortid = 2  if regexm(estimator,"2")
replace sortid = 3 if regexm(estimator,"3")
replace sortid = 4 if regexm(estimator,"4")
replace sortid = 5 if regexm(estimator,"5")
replace sortid = 6 if regexm(estimator,"6")
replace sortid = 7 if regexm(estimator,"7")
replace sortid = 8 if regexm(estimator,"8")
replace sortid = 9 if regexm(estimator,"9")
replace sortid = 10 if regexm(estimator,"10")
destring sortid, replace

gen final = "nnls1"  
replace final = "avg" if regexm(estimator,"avg")
replace final = "singlebest" if regexm(estimator,"singlebest")
replace final = "ols" if regexm(estimator,"ols")
drop estimator 

collapse (sum) stw_ psw_ ssw_  , by(obs dgp_desc equation estimator_desc sortid final)

tostring  stw* psw* ssw*   , replace format(%9.3f) force
foreach var of varlist stw* psw* ssw*  {
	replace `var'="0.\phantom{000}" if `var'=="0.000"
	replace `var'="1.\phantom{000}" if `var'=="1.000"
}
sort obs dgp_desc final equation sortid estimator_desc

reshape wide stw_ psw_ ssw_ , i(sortid obs dgp_desc final estimator_desc) j(equation) string
reshape wide stw_Y psw_Y ssw_Y   stw_D psw_D ssw_D , i(sortid dgp_desc final estimator_desc) j(obs)

sort dgp_desc final sortid

 
drop if final =="avg"

gen gap = ""
gen gap2 =""


*** Table 2 & Appendix Tables A.3, A.4
foreach f in nnls1 singlebest ols {

	texsave estimator_desc stw_Y9915 stw_D9915 gap ssw_Y9915 ssw_D9915 ///
							using $outpath/sweights_`f'_grad_nopooled.tex ///
							if dgp_desc=="Gradient boosting" & final=="`f'" ///
							, dataonly replace nofix
	texsave estimator_desc stw_Y9915 stw_D9915 gap ssw_Y9915 ssw_D9915 ///
							using $outpath/sweights_`f'_ols_nopooled.tex ///
							if dgp_desc=="Linear DGP"  & final=="`f'" ///
							, dataonly replace nofix
	texsave estimator_desc stw_Y99150 stw_D99150 gap ssw_Y99150 ssw_D99150 ///
							using $outpath/sweights_`f'_grad_large_nopooled.tex ///
							if dgp_desc=="Gradient boosting" & final=="`f'" ///
							, dataonly replace nofix
	texsave estimator_desc stw_Y99150 stw_D99150 gap ssw_Y99150 ssw_D99150 ///
							using $outpath/sweights_`f'_ols_large_nopooled.tex ///
							if dgp_desc=="Linear DGP"& final=="`f'" ///
							, dataonly replace nofix

	texsave estimator_desc stw_Y9915 stw_D9915 gap psw_Y9915 psw_D9915 gap2 ssw_Y9915 ssw_D9915 ///
							using $outpath/sweights_`f'_grad.tex ///
							if dgp_desc=="Gradient boosting"  & final=="`f'" ///
							, dataonly replace nofix
	texsave estimator_desc stw_Y9915 stw_D9915 gap psw_Y9915 psw_D9915 gap2 ssw_Y9915 ssw_D9915 ///
							using $outpath/sweights_`f'_ols.tex ///
							if dgp_desc=="Linear DGP"  & final=="`f'" ///
							, dataonly replace nofix
	texsave estimator_desc stw_Y99150 stw_D99150 gap psw_Y99150 psw_D99150 gap2 ssw_Y99150 ssw_D99150 ///
							using $outpath/sweights_`f'_grad_large.tex ///
							if dgp_desc=="Gradient boosting"  & final=="`f'" ///
							, dataonly replace nofix
	texsave estimator_desc stw_Y99150 stw_D99150 gap psw_Y99150 psw_D99150  gap2 ssw_Y99150 ssw_D99150 ///
							using $outpath/sweights_`f'_ols_large.tex ///
							if dgp_desc=="Linear DGP"  & final=="`f'" ///
							, dataonly replace nofix
					
}



********************************************************************************
********* MSPE 
********************************************************************************

use sim_temp.dta, clear

keep if folds==2

keep dgp obs mspe*

sort dgp obs

gen dgp_desc = "Gradient boosting" if dgpflag==1
replace dgp_desc="Linear DGP" if dgpflag==0
drop dgpflag

reshape long mspe, i(obs dgp) j(estimator) string

gen equation = "Y" if regexm(estimator,"_y") |  regexm(estimator,"y_")
replace equation = "D" if equation==""

** NB: the order of the learners got mixed
gen estimator_desc = ""
replace estimator_desc = "OLS" if regexm(estimator,"1") & !regexm(estimator,"10") 
replace estimator_desc = "Lasso with CV (2nd order poly)" if regexm(estimator,"2")
replace estimator_desc = "Ridge with CV (2nd order poly)" if regexm(estimator,"3")
replace estimator_desc = "Lasso with CV (10th order poly)" if regexm(estimator,"4")
replace estimator_desc = "Ridge with CV (10th order poly)" if regexm(estimator,"5")
replace estimator_desc = "Random forest (low regularization)" if regexm(estimator,"6")
replace estimator_desc = "Random forest (high regularization)" if regexm(estimator,"7")
replace estimator_desc = "Gradient boosting (low regularization)" if regexm(estimator,"8")
replace estimator_desc = "Gradient boosting (high regularization)" if regexm(estimator,"9")
replace estimator_desc = "Neural net" if regexm(estimator,"10")
drop if estimator_desc==""

gen sortid = 1
replace sortid = 1  if regexm(estimator,"1") & !regexm(estimator,"10") & !regexm(estimator,"nnls1") 
replace sortid = 2  if regexm(estimator,"2")
replace sortid = 3 if regexm(estimator,"3")
replace sortid = 4 if regexm(estimator,"4")
replace sortid = 5 if regexm(estimator,"5")
replace sortid = 6 if regexm(estimator,"6")
replace sortid = 7 if regexm(estimator,"7")
replace sortid = 8 if regexm(estimator,"8")
replace sortid = 9 if regexm(estimator,"9")
replace sortid = 10 if regexm(estimator,"10")
destring sortid, replace

drop estimator

reshape wide mspe, i(sortid obs dgp_desc estimator_desc) j(equation) string
reshape wide mspeD mspeY, i(sortid dgp_desc estimator_desc) j(obs)

foreach var of varlist mspeY* {
	replace `var' = `var'/10^9
}

tostring  mspe* , replace format(%9.3f) force


sort dgp_desc sortid

gen gap =""
gen gap0 = ""

*** Table A.1
texsave gap0 estimator_desc mspeY9915 mspeD9915 gap mspeY99150 mspeD99150 ///
			using $outpath/sim_mspe_grad.tex if dgp_desc=="Gradient boosting", dataonly replace 
texsave gap0 estimator_desc mspeY9915 mspeD9915 gap mspeY99150 mspeD99150 ///
			using $outpath/sim_mspe_ols.tex if dgp_desc=="Linear DGP", dataonly replace 
