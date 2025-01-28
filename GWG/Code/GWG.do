
clear all

if ("`c(os)'"=="MacOSX") {
	cd "/Users/kahrens/MyProjects/ddml_applied/GWG"
} 
else {
	cd "/cluster/home/kahrens/ddml_applied/GWG"
	//adopath ++ "/cluster/home/kahrens/ddml_applied/ddml"
	adopath + "/cluster/home/kahrens/ddml_applied/GWG"
	cap python set exec /cluster/apps/nss/gcc-8.2.0/python/3.9.9/x86_64/bin/python3	
	cap set processors 1
}

cd Output

local seed `1'
local estimator `2'

cap log close
log using GWG_`1'_`2'.txt, replace text

which ddml
which pystacked

set seed `seed'
local folder out_`seed'

use "../Data/gender_gap_ML_processed", clear

cap mkdir `folder'

********************************************************************************
***  controls
********************************************************************************

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
	i.($discrete0 )							///
	i.new_isco1c#i.new_isic1c#i.new_reg_tl2 ///
	c.($continuous)			 
	
global X_cont								///
	c.($continuous)##i.($discrete)

global X_expanded							///
	i.($discrete)							///
	c.($continuous)							///
	c.age_r#i.($discrete)					///
	c.tenure#i.($discrete)

	

********************************************************************************
***  estimation sample
********************************************************************************

gen byte touse=1
markout touse lnearn $X_expanded
keep if touse


********************************************************************************
***  learners
********************************************************************************

global cores = 5

global rf1 min_samples_leaf(1)  max_features(sqrt) n_estimators(500)
global rf2 min_samples_leaf(50)  max_features(sqrt) n_estimators(500)
global rf3 min_samples_leaf(100)  max_features(sqrt) n_estimators(500)
global grad1 n_estimators(500) n_iter_no_change(10)  
global grad2 n_estimators(500)  
global nnet1 hidden_layer_sizes(40 20 1 20 50) early_stopping 
global nnet2 hidden_layer_sizes(30 30 30) early_stopping  

global pystring_reg0					    			|| ///
					m(ols) 					 			|| ///
					m(ols) xvars($X_simple)				|| ///
					m(lassocv)							|| ///
					m(ridgecv)							|| ///
					m(lassocv)	xvars($X_cont)			|| ///
					m(ridgecv)	xvars($X_cont)			|| ///
					m(rf) opt($rf1)						|| ///
					m(rf) opt($rf2)						|| ///
					m(rf) opt($rf3)						|| ///
					m(gradboost) opt($grad1)			|| ///
					m(gradboost) opt($grad2)			|| ///
					m(nnet) opt($nnet1) 				|| ///
					m(nnet) opt($nnet2) 				|| //

global pystring_reg  $pystring_reg0 , type(reg) njobs($cores) 
 
global pystring_class0									|| ///
					m(logit) 				 			|| ///
					m(logit) xvars($X_simple)			|| ///
					m(lassocv)							|| ///
					m(ridgecv)							|| ///
					m(lassocv)	xvars($X_cont)			|| ///
					m(ridgecv)	xvars($X_cont)			|| ///
					m(rf) opt($rf1)						|| ///
					m(rf) opt($rf2)						|| ///
					m(rf) opt($rf3)						|| ///
					m(gradboost) opt($grad1)			|| ///
					m(gradboost) opt($grad2)			|| ///
					m(nnet) opt($nnet1) 				|| ///
					m(nnet) opt($nnet2) 				|| //			
				
global pystring_class $pystring_class0 , type(class) njobs($cores)
					
global R =1  
global K=10 
global L =13
 	
******************************************************************************	
*** ddml: estimation													   ***
******************************************************************************

if (`estimator'==1) {

	ddml init partial,  reps($R) kfolds($K)
	ddml E[Y|X]: pystacked lnearn $X_expanded $pystring_reg
	ddml E[D|X]: pystacked gender_r $X_expanded $pystring_reg
	ddml crossfit, shortstack poolstack
	ddml estimate, robust
	
	foreach mat in lnearn_mse gender_r_mse {
			ddml extract, show(mse)
			mat `mat' = r(`mat')
			mat list `mat'
				preserve
				svmat `mat'
				keep `mat'*
				keep if _n<=$L
				gen stack_type = "conventional" if _n==1
				replace stack_type = "pooled" if _n==2
				replace stack_type = "short" if _n==3
				gen model = "plm"
				list if _n<=$L
				save `folder'/`mat'_plm_mse, replace
				restore	
	}	

	cap drop mse_*
	foreach var of varlist Y1_* {
		 cap drop sqerr_`var'
		 gen double sqerr_`var'=(lnearn-`var')^2
		 sum sqerr_`var', meanonly
		 gen double mse_`var'=r(mean) if _n ==1 
	}
	foreach var of varlist D1_* {
		 cap drop sqerr_`var'
		 gen double sqerr_`var'=(gender_r-`var')^2
		 sum sqerr_`var', meanonly
		 gen double mse_`var'=r(mean) if _n ==1 
	}
	preserve
		keep mse_*
		keep if _n==1
		save `folder'/plm_mse, replace
	restore
	cap drop mse_*

	** initialize results file
	regsave gender_r using `folder'/results.dta, ci addlabel(model,partial,seed,`seed',final,init,learner,-99) replace

	foreach final in nnls1 singlebest ols avg {

		ddml estimate, robust finalest(`final')
	
			// regular stacking results
			ddml estimate, mname(m0) spec(st) replay  
			regsave gender_r using `folder'/results.dta, ci addlabel(model,partial,seed,`seed',final,`final',learner,-1) append
			
			// shortstacking results
			ddml estimate, mname(m0) spec(ss) replay 
			regsave gender_r using `folder'/results.dta, ci addlabel(model,partial,seed,`seed',final,`final',learner,-2) append
			
			// poolstacking results
			ddml estimate, mname(m0) spec(ps) replay  
			regsave gender_r using `folder'/results.dta, ci addlabel(model,partial,seed,`seed',final,`final',learner,-3) append	
		
			// pystacked weights
			ddml extract, show(stweights)	
			foreach mat in Y1_pystacked_w_mn D1_pystacked_w_mn {
					ddml extract, show(stweights)	
					mat `mat' = r(`mat')
					mat list `mat'
						preserve
						svmat `mat'
						keep `mat'*
						list if _n<=4
						save `folder'/`mat'_`final'_regular, replace
						restore
			}	
			// shortstacked weights
			ddml extract, show(ssweights)
			foreach mat in Y_lnearn_ss D_gender_r_ss {
					qui ddml extract, show(ssweights)
					mat `mat' = r(`mat')
					mat list `mat'
						preserve
						svmat `mat'
						keep `mat'*
						list if _n<=4
						save `folder'/`mat'_`final'_short, replace
						restore
			}	
			// poolstacked weights

			foreach mat in Y_lnearn_ps D_gender_r_ps {
					qui ddml extract, show(psweights)
					mat `mat' = r(`mat')
					mat list `mat'
						preserve
						svmat `mat'
						keep `mat'*
						list if _n<=4
						save `folder'/`mat'_`final'_pooled, replace
						restore
			}	
	
	}

	forvalues i = 1(1)$L {
 			ddml estimate, y(Y1_pystacked_L`i'_1) ///
							d(D1_pystacked_L`i'_1) robust
			regsave gender_r using `folder'/results.dta, ci ///
						addlabel(model,partial,seed,`seed',final,indiv,learner,`i') ///
						append
 	}

}
	
******************************************************************************	
*** interactive: estimation 											   ***
******************************************************************************
	
if (`estimator'==2) {	

	ddml init interactive, kfolds($K) reps($R)
	ddml E[Y|X,D]: pystacked lnearn $X_expanded $pystring_reg
	ddml E[D|X]: pystacked gender_r $X_expanded $pystring_class
	ddml crossfit, shortstack poolstack
	ddml estimate, robust atet

	cap drop mse_*
	foreach var of varlist Y1_pystacked0* {
		 cap drop sqerr_`var'
		 gen double sqerr_`var'=(lnearn-`var')^2 if gender_r==0
		 sum sqerr_`var' if gender_r==0, meanonly
		 gen double mse_`var'=r(mean) if _n ==1 
	}
	foreach var of varlist Y1_pystacked1* {
		 cap drop sqerr_`var'
		 gen double sqerr_`var'=(lnearn-`var')^2 if gender_r==1
		 sum sqerr_`var' if gender_r==1, meanonly
		 gen double mse_`var'=r(mean) if _n ==1 
	}
	foreach var of varlist D1_* {
		 cap drop sqerr_`var'
		 gen double sqerr_`var'=(gender_r-`var')^2
		 sum sqerr_`var', meanonly
		 gen double mse_`var'=r(mean) if _n ==1 
	}
	preserve
		keep mse_*
		keep if _n==1
		save `folder'/inter_mse, replace
	restore
	cap drop mse_*
	
	local mat gender_r_mse
			ddml extract, show(mse)
			mat `mat' = r(`mat')
			mat list `mat'
				preserve
				svmat `mat'
				keep `mat'*
				keep if _n<=$L
				gen stack_type = "conventional" if _n==1
				replace stack_type = "pooled" if _n==2
				replace stack_type = "short" if _n==3
				gen model = "interactive"
				list if _n<=$L
				save `folder'/`mat'_inter_gender_mse, replace
				restore	
				
	local mat lnearn_mse
			ddml extract, show(mse)
			mat `mat' = r(`mat')
			mat list `mat'
				preserve
				svmat `mat'
				keep `mat'*
				keep if _n<=(2*$L)
				gen stack_type = "conventional" if _n<=2
				replace stack_type = "pooled" if _n>=3 & _n<=4
				replace stack_type = "short" if _n>4
				gen model = "interactive"
				list if _n<=(2*$L)
				save `folder'/`mat'_inter_lnearn_mse, replace
				restore	
	
	foreach final in nnls1 singlebest ols avg {

		ddml estimate, robust finalest(`final') atet
	
			// regular stacking results
			ddml estimate, mname(m0) spec(st) replay atet
			regsave gender_r using `folder'/results.dta, ci addlabel(model,interactive,seed,`seed',final,`final',learner,-1) append
			
			// shortstacking results
			ddml estimate, mname(m0) spec(ss) replay atet
			regsave gender_r using `folder'/results.dta, ci addlabel(model,interactive,seed,`seed',final,`final',learner,-2) append
			
			// poolstacking results
			ddml estimate, mname(m0) spec(ps) replay atet
			regsave gender_r using `folder'/results.dta, ci addlabel(model,interactive,seed,`seed',final,`final',learner,-3) append
		
			// pystacked weights
			ddml extract, show(stweights)
			foreach mat in Y1_pystacked_w_mn D1_pystacked_w_mn {
					ddml extract, show(stweights)
					mat `mat' = r(`mat')
					mat list `mat'
						preserve
						svmat `mat'
						keep `mat'*
						list if _n<=8
						save `folder'/`mat'_`final'_regular_ia, replace
						restore
			}	
			// shortstacked weights
			ddml extract, show(ssweights)
			foreach mat in Y_lnearn_ss D_gender_r_ss {
					ddml extract, show(ssweights)
					mat `mat' = r(`mat')
					mat list `mat'
						preserve
						svmat `mat'
						keep `mat'*
						list if _n<=8
						save `folder'/`mat'_`final'_short_ia, replace
						restore
			}	
			// poolstacked weights
			ddml extract, show(psweights)
			foreach mat in Y_lnearn_ps D_gender_r_ps {
					ddml extract, show(psweights)
					mat `mat' = r(`mat')
					mat list `mat'
						preserve
						svmat `mat'
						keep `mat'*
						list if _n<=8
						save `folder'/`mat'_`final'_pooled_ia, replace
						restore
			}	
	
	}

	forvalues i = 1(1)$L {
 			ddml estimate, y1(Y1_pystacked1_L`i'_1) y0(Y1_pystacked0_L`i'_1) ///
							d(D1_pystacked_L`i'_1) robust atet foldvar(m0_sample_1  )
			regsave gender_r using `folder'/results.dta, ci ///
						addlabel(model,interactive,seed,`seed',final,indiv,learner,`i') ///
						append
 	}

}	
	
******************************************************************************	
*** interactive NX: short-stacking										   ***
******************************************************************************

if (`estimator'==3) {

gen one = 1	

	cap drop y0base*
	cap drop dbase*
	cap drop y1base*

	*** no cross-fitting
	pystacked lnearn $X_expanded   $pystring_reg0  if gender_r == 0, type(reg) njobs($cores)  
		mat nxw_ia_y0 = e(weights)
		mat list nxw_ia_y0
				preserve
				svmat nxw_ia_y0
				keep nxw_ia_y0*
				save `folder'/nxw_ia_y0, replace
				restore
	predict y0base0, xb
	predict y0base, base

	pystacked lnearn $X_expanded  $pystring_reg0 if gender_r == 1  , type(reg) njobs($cores)  
		mat nxw_ia_y1 = e(weights)
		mat list nxw_ia_y1
				preserve
				svmat nxw_ia_y1
				keep nxw_ia_y1*
				save `folder'/nxw_ia_y1, replace
				restore
	predict y1base0, xb
	predict y1base, base

	pystacked gender_r $X_expanded $pystring_class  
		mat nxw_ia_d = e(weights)
		mat list nxw_ia_d
				preserve
				svmat nxw_ia_d
				keep nxw_ia_d*
				save `folder'/nxw_ia_d, replace
				restore		
	predict dbase0, pr
	predict dbase, base pr
	
	forvalues i = 0(1)$L {
			_estimate_ate interactive, yname(lnearn) dname(gender_r) ///
						y0(y0base`i') y1(y1base`i') d(dbase`i') ///
						atet foldid(one) robust model(interactive)
			regsave gender_r using `folder'/results.dta, ///
						ci addlabel(model,nxinter,seed,`seed',final,nx,learner,`i') append
	}
		
}
	
******************************************************************************	
*** partial NX: short-stacking											   ***
******************************************************************************

if (`estimator'==4) {
	
cap gen one = 1	

	cap drop Ybase* 
	cap drop Dbase*

	*** no cross-fitting
	pystacked lnearn $X_expanded $pystring_reg 
		mat nxw_y = e(weights)
		mat list nxw_y
				preserve
				svmat nxw_y
				keep nxw_y*
				save `folder'/nxw_y, replace
				restore
	predict Ybase0
	predict Ybase, basexb

	pystacked gender_r $X_expanded $pystring_reg 
		mat nxw_d = e(weights)
		mat list nxw_d
				preserve
				svmat nxw_d
				keep nxw_d*
				save `folder'/nxw_d, replace
				restore		
	predict Dbase0
	predict Dbase, basexb

	forvalues i = 0(1)$L {
		cap drop Ytil
		cap drop Dtil
		gen Ytil = lnearn - Ybase`i'
		gen Dtil = gender_r - Dbase`i'
		reg Ytil Dtil, robust
		regsave Dtil using `folder'/results.dta, ///
			ci addlabel(model,nxpartial,seed,`seed',final,nx,learner,`i') append
	}

}
	
cap log close
 