//cap cd "C:\LocalStore\ecomes\Dropbox (Heriot-Watt University Team)\RES_SOSS_CEERP\CEERP\Research\GWG\obml"
//cap cd "/Users/kahrens/MyProjects/ddml_simulations/GWG"
//
//if ("`c(username)'"=="kahrens") {
//	cd "/Users/kahrens/MyProjects/ddml_simulations/GWG"
//}

clear all

if ("`c(os)'"=="MacOSX") {
	//adopath + "/Users/kahrens/MyProjects/ddml"
	//adopath + "/Users/kahrens/MyProjects/pystacked"
	adopath + "/Users/kahrens/MyProjects/ddml_simulations/"
	adopath + "/Users/kahrens/MyProjects/ddml_simulations/GWG"
	cd "/Users/kahrens/MyProjects/ddml_simulations/GWG"
} 
else {
	cd "/cluster/home/kahrens/ddml_simulations/GWG"
	cap python set exec /cluster/apps/nss/gcc-8.2.0/python/3.9.9/x86_64/bin/python3	
	cap set processors 1
}

local seed `2'
local strat `1'
local model Strategy`1'_seed`seed'

cap log close
log using GWG_`model'_`seed'.txt, replace text

mkdir `model'

set seed `seed'

use "Data/gender_gap_ML_processed", clear

// create squared age and tenure here
gen age_r2 = age_r^2
gen tenure2 = tenure^2

// no base categories
global continuous															///
	age_r																	/// no missing
	yrsqual		/* years of education (derived) */							/// 355 missing
	/// leavedu		/* age when left education (derived) */					/// 1,081 missing
	pvlit1		/* literacy score: plausible value 1 (also 2-10 avail) */	/// no missing
	pvnum1		/* numeracy score: plausible value 1 (also 2-10 avail) */	/// no missing
	tenure		/* tenure = years in work for current employer */			/// 2 missing
																			//
// add second order terms here
global continuous $continuous age_r2 tenure2

global continuous_na														///
	yrsqual_na	/* years of education (derived) */							///
	/// leavedu_na	/* age when left education (derived) */					///
	immig_years_na	/* immigration: years in country */						///
	j_q03d1_na	/* age of youngest child */									//
	
global discrete0															///		
	b_q01a		/* education, highest level attained */						/// no missing
	b_q01b		/* area of study */											/// 434 missing
	d_q06c		/* part of a larger organization */							/// 13 missing
	d_q08a		/* management position */									/// no missing
	d_q09		/* type of contract */										/// 12 missing
	d_q10_t1	/* hours per week at this job or business */				/// 1 missing
	d_q14		/* job satisfaction */										/// 1 missing
	i_q08		/* health status */											/// 2 missing
	j_q02a		/* living with a partner */									/// 899 missing
	j_q03d1_c	/* age of youngest child */									/// 2,718 missing
	j_q04c1_c	/* immigration: age */										/// 4,375 missing
	j_q06b		/* mother's highest level of educ */						/// 445 missing
	j_q07b		/* father's highest level of educ */						/// 515 missing
	j_q03b		/* number of children*/										/// 1,856 missing
	impar		/* immigration: parents */									/// 21 missing
	imgen		/* immigration: generation */								/// 344 missing
	nfe12jr		/* informal job-related educ in prev 12 months */			/// 116 missing
	nfe12njr	/* informal non-job-related educ in prev 12 months */		/// 116 missing
																			//
																			
global personality															///
	i_q04b		/* Learning strategies, Relate new ideas into real life */	/// 16 missing
	i_q04d		/* Learning strategies, Like learning new things */			/// no missing
	i_q04h		/* Learning strategies, Attribute something new */			/// 10 missing
	i_q04j		/* Learning strategies, Deal with difficult things */		/// no missing
	i_q04l		/* Learning strategies, Fit different ideas together */		/// 5 missing
	i_q04m		/* Learning strategies, Looking for additional info */		/// 1 missing
	i_q05f		/* Cultural engagement, Voluntary non-profit work */		/// no missing
	i_q06a		/* Political efficacy, No influence on the government */	/// 14 missing
	i_q07a		/* Social trust, Trust only few people */					/// 4 missing
	i_q07b		/* Social trust, Other people take advantage of you */		/// 6 missing
																			//

global discrete	$discrete0						  							///
	new_reg_tl2	/* geographical region */									/// 2 missing
	new_isco1c	/* occupation */											/// no missing
	new_isic1c	/* industry */												// no missing

global X_simple								///
	i.(b_q01a d_q10_t1 j_q03b)				///
	c.($continuous)

global X_fullinteracted						///
	i.($discrete0 )			///
	i.new_isco1c#i.new_isic1c#i.new_reg_tl2 ///
	c.($continuous)			 
	
global X_cont								///
	c.($continuous)##i.($discrete)

global X_expanded							///
	i.($discrete)			///
	c.($continuous)							///
	c.age_r#i.($discrete)					///
	c.tenure#i.($discrete)

	
	
********************************************************************************

// estimation sample
gen byte touse=1
markout touse lnearn $X_expanded
keep if touse


********************************************************************************

					
global K =10  
global L =8
	

******************************************************************************	
*** fold varlist														   ***
******************************************************************************

foreach var of varlist $discrete {
	tab `var' gender_r  , nolabel
	cap drop  count_`var'
	bysort `var' gender_r  : egen count_`var' = count(gender_r)
	di "`strat'"
	if ("`strat'"=="2") {
		replace `var'=9991 if count_`var' <20
		bysort `var': egen mean_`var'=mean(gender_r)
		replace `var'=9991 if mean_`var'>.9 | mean_`var'<.1
	}
	if ("`strat'"=="3") {
		drop  if count_`var' <20
		bysort `var': egen mean_`var'=mean(gender_r)
		drop if mean_`var'>.9 | mean_`var'<.1
	}
	tab `var' gender_r  , nolabel
}

******************************************************************************	
*** partial: short-stacking												   ***
******************************************************************************

	ddml init partial, kfolds($K)
	ddml E[Y|X]: pystacked lnearn $X_expanded , m(ols)
	ddml E[Y|X]: pystacked lnearn $X_simple , m(ols)
	ddml E[Y|X]: pystacked lnearn $X_fullinteracted , m(ols)
	ddml E[Y|X]: pystacked lnearn $X_cont , m(ols)
	ddml E[Y|X]: reg lnearn $X_expanded  
	ddml E[Y|X]: reg lnearn $X_simple
	ddml E[Y|X]: reg lnearn $X_fullinteracted
	ddml E[Y|X]: reg lnearn $X_cont 
	ddml E[D|X]: pystacked gender_r $X_expanded , m(ols)
	ddml E[D|X]: pystacked gender_r $X_simple , m(ols)
	ddml E[D|X]: pystacked gender_r $X_fullinteracted , m(ols)
	ddml E[D|X]: pystacked gender_r $X_cont , m(ols)
	ddml E[D|X]: reg gender_r $X_expanded 
	ddml E[D|X]: reg gender_r $X_simple 
	ddml E[D|X]: reg gender_r $X_fullinteracted 
	ddml E[D|X]: reg gender_r $X_cont
	ddml crossfit
	ddml estimate	
	
	preserve
	clear
	save `model'/results_partial.dta, emptyok replace
	restore
	forvalues i = 1(1)$L {

			ddml estimate, y(Y`i'_ ) ///
							d(D`i'_ ) robust
			regsave gender_r using `model'/results_partial.dta, ci ///
						addlabel(model,partial,seed,`seed',learner,`i') ///
						append
		
	}
	
******************************************************************************	
*** interactive: short-stacking											   ***
******************************************************************************

	ddml init interactive, kfolds($K)
	ddml E[Y|X,D]: pystacked lnearn $X_expanded , m(ols) type(reg)
	ddml E[Y|X,D]: pystacked lnearn $X_simple , m(ols) type(reg)
	ddml E[Y|X,D]: pystacked lnearn $X_fullinteracted , m(ols) type(reg)
	ddml E[Y|X,D]: pystacked lnearn $X_cont , m(ols) type(reg)
	//ddml E[Y|X,D]: reg lnearn $X_expanded  
	//ddml E[Y|X,D]: reg lnearn $X_simple
	//ddml E[Y|X,D]: reg lnearn $X_fullinteracted
	ddml E[D|X]: pystacked gender_r $X_expanded ,m(logit) type(class)
	ddml E[D|X]: pystacked gender_r $X_simple , m(logit) type(class)
	ddml E[D|X]: pystacked gender_r $X_fullinteracted ,m(logit) type(class)
	ddml E[D|X]: pystacked gender_r $X_cont ,m(logit) type(class)
	//ddml E[D|X]: logit gender_r $X_expanded 
	//ddml E[D|X]: logit gender_r $X_simple 
	//ddml E[D|X]: logit gender_r $X_fullinteracted 
	ddml crossfit
	ddml estimate	
	
	preserve
	clear
	save `model'/results_interactive.dta, emptyok replace
	restore
	forvalues i = 1(1)4 {

			ddml estimate, y0(Y`i'_*0_1 ) y1(Y`i'_*1_1 ) ///
							d(D`i'_ ) robust
			regsave gender_r using `model'/results_interactive.dta, ci ///
						addlabel(model,interactive,seed,`seed',learner,`i') ///
						append
		
	}
	
cap log close
