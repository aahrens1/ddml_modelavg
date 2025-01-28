clear all 

if ("`c(os)'"=="MacOSX") {
	cd "/Users/kahrens/MyProjects/ddml_applied/"
}
else {
	cd "/cluster/home/kahrens/ddml_applied/"
	cap python set exec /cluster/apps/nss/gcc-8.2.0/python/3.9.9/x86_64/bin/python3
	cap set processors 1
}

cd sim_WZ_linear

cap log close
cap log using log/log_`1'_`2'_`3'_`4'_`5'.txt, text replace

which ddml
which pystacked

cap set seed `1'
di "`1' `2' `3' `4' `5'"

global reps = 5
global each_reps = 5 

global Y tw
global D e401  
global X i1 i2 i3 i4 i5 i6 i7 a1 a2 a3 a4 a5 fsize nohs hs smcol col marr twoearn db pira hown 
global xvar_poly2 s1_x*
global xvar_spline s2_x*

* options
global pyopt  
global rflow max_features(8) min_samples_leaf(1) max_samples(.7)
global rfhigh max_features(5) min_samples_leaf(10) max_samples(.7)
global gradlow n_estimators(500) learning_rate(0.01)
global gradhigh n_estimators(250) learning_rate(0.01)
global nnetopt hidden_layer_sizes(5 5 5)

* program 
cap program drop mysim
program define mysim , rclass

	syntax [, 	obs(integer 9915) ///
				BOOTstrap(integer 1) ///
				f(integer 2) ///
				rep(integer 2) ///
			]
			
	use "../Data/data_401k_final.dta", replace
	
	timer clear

	if ("`obs'"=="") {
		local obs = 400
		local bootstrap 1
		local f 2 
		local rep 2
	}	
 
	*** draw bootstrap sample
	if (`bootstrap'==1) bsample `obs'
	
	local nlearners = 4
			
	*** ddml partial
	timer on 1
	ddml init partial, kfolds(`f') reps(`rep')	
	ddml E[Y|X]: pystacked $Y $X 								|| ///
					m(ols) xvars($xvar_poly2) 					|| ///
					m(ols) xvars($xvar_spline) 					|| ///
					m(lassocv) xvars($xvar_poly2) 				|| ///
					m(lassocv) xvars($xvar_spline) 			 , $pyopt 
	ddml E[D|X]: pystacked $D $X 								|| ///
					m(ols) xvars($xvar_poly2) 					|| ///
					m(ols) xvars($xvar_spline) 					|| ///
					m(lassocv) xvars($xvar_poly2) 				|| ///
					m(lassocv) xvars($xvar_spline) 			 , $pyopt 
	ddml crossfit, shortstack poolstack
	ddml estimate, robust
	timer off 1
		
	foreach final in nnls1 singlebest ols avg {

		ddml estimate, robust finalest(`final')
	
			numlist "1(1)`rep'"
			local rnums = r(numlist)
			foreach r in `rnums' mn md {
				// regular stacking results
				ddml estimate, mname(m0) spec(st) replay rep(`r')
				local ddml_st_`final'_`r'_b = _b[$D]
				local ddml_st_`final'_`r'_se = _se[$D]
				// shortstacking results
				ddml estimate, mname(m0) spec(ss) replay rep(`r')
				local ddml_ss_`final'_`r'_b = _b[$D]
				local ddml_ss_`final'_`r'_se = _se[$D]	
				// poolstacking results
				ddml estimate, mname(m0) spec(ps) replay rep(`r')
				local ddml_ps_`final'_`r'_b = _b[$D]
				local ddml_ps_`final'_`r'_se = _se[$D]	
			}
		
			tempname By Bd
			// pystacked weights
			ddml extract, show(stweights)
			mat `By'=r(Y1_pystacked_w_mn)
			mat `Bd'=r(D1_pystacked_w_mn)
			mat list `Bd'
			mat list `By'
			forvalues i = 1(1)`nlearners' {
				local stw_`final'_d`i' = el(`Bd',`i',2)
				local stw_`final'_y`i' = el(`By',`i',2)
			}
			// shortstacked weights
			ddml extract, show(ssweights)
			mat `By'=r(Y_tw_ss) 
			mat `Bd'=r(D_e401_ss)
			mat list `Bd'
			mat list `By'
			forvalues i = 1(1)`nlearners' {
				local ssw_`final'_d`i' = el(`Bd',`i',2)
				local ssw_`final'_y`i' = el(`By',`i',2)
			}
			// poolstacked weights
			ddml extract, show(psweights)
			mat `By'=r(Y_tw_ps)
			mat `Bd'=r(D_e401_ps)
			mat list `Bd'
			mat list `By'
			forvalues i = 1(1)`nlearners' {
				local psw_`final'_d`i' = el(`Bd',`i',2)
				local psw_`final'_y`i' = el(`By',`i',2)
			}

					
			
	}
	
	*** individual learners
	forvalues r = 1(1)`rep' {
		forvalues l = 1(1)`nlearners' {
			qui ddml estimate, y(Y1_pystacked_L`l'_`r') d(D1_pystacked_L`l'_`r') robust
			local ddml_x_`l'_`r'_b = _b[$D]
			local ddml_x_`l'_`r'_se = _se[$D]
		}	
	}

	ddml drop	

	
	*** full-sample estimators: OLS and pdslasso ******************************
	
	local csmall = 0.5*1.1
	local clarge = 1.5*1.1
	
	pdslasso $Y $D ($xvar_poly2), robust lopt(c(`csmall') c0(`csmall'))
	local pds1a_b = _b[$D]
	local pds1a_se = _se[$D]

	timer on 3
	pdslasso $Y $D ($xvar_poly2), robust
	timer off 3
	local pds2a_b = _b[$D]
	local pds2a_se = _se[$D]	
	
	pdslasso $Y $D ($xvar_poly2), robust lopt(c(`clarge') c0(`clarge'))
	local pds3a_b = _b[$D]
	local pds3a_se = _se[$D]
	
	pdslasso $Y $D ($xvar_spline), robust lopt(c(`csmall') c0(`csmall'))
	local pds1b_b = _b[$D]
	local pds1b_se = _se[$D]

	timer on 4
	pdslasso $Y $D ($xvar_spline), robust
	timer off 4
	local pds2b_b = _b[$D]
	local pds2b_se = _se[$D]	
	
	pdslasso $Y $D ($xvar_spline), robust lopt(c(`clarge') c0(`clarge'))
	local pds3b_b = _b[$D]
	local pds3b_se = _se[$D]
	
	local olsa_b = .
	local olsa_se = .
	timer on 5
	cap reg $Y $D $xvar_poly2, robust
	timer off 5
	if _rc==0 {
		local olsa_b = _b[$D]
		local olsa_se = _se[$D]
	}
	
	local olsb_b = .
	local olsb_se = .
	cap reg $Y $D $xvar_spline, robust
	if _rc==0 {
		local olsb_b = _b[$D]
		local olsb_se = _se[$D]
	}
	
	* timer 
	timer list
	forvalues i = 1(1)5 {
			local t`i'=r(t`i')
	}
	
	*** return ***************************************************************
	ereturn clear
	* timer
	forvalues i = 1(1)5 {
		return scalar t`i'=`t`i''
	}
	* coefficients
	foreach final in nnls1 singlebest ols avg {
		foreach r in `rnums' mn md {
			foreach stype in st ss ps {
				return scalar ddml_`stype'_`final'_`r'_b = `ddml_`stype'_`final'_`r'_b'
				return scalar ddml_`stype'_`final'_`r'_se = `ddml_`stype'_`final'_`r'_se'
			}
		}
	}
	forvalues r = 1(1)`rep' {
		forvalues l = 1(1)`nlearners' {
			return scalar ddml_x_`l'_`r'_b = `ddml_x_`l'_`r'_b' 
			return scalar ddml_x_`l'_`r'_se =`ddml_x_`l'_`r'_se'
		}	
	}
	* OLS and PDS
	foreach v in olsa olsb pds1a pds2a pds3a pds1b pds2b pds3b {
		return scalar `v'_b = ``v'_b'
		return scalar `v'_se = ``v'_se'
	}
	* pystacked weights
	foreach final in nnls1 singlebest ols avg {	
		forvalues i = 1(1)`nlearners' {
			return scalar stw_`final'_d`i' =  `stw_`final'_d`i''
			return scalar stw_`final'_y`i' =  `stw_`final'_y`i''
			return scalar ssw_`final'_d`i' =  `ssw_`final'_d`i''
			return scalar ssw_`final'_y`i' =  `ssw_`final'_y`i''
			return scalar psw_`final'_d`i' =  `psw_`final'_d`i''
			return scalar psw_`final'_y`i' =  `psw_`final'_y`i''
		}
	}

	return scalar obs = `obs'
	return scalar bootstrap = `bootstrap'
	return scalar rep = `rep'
	return scalar f = `f'
end

timer clear
forvalues i = 1(1)$reps {
	clear
	di "reps=`i'"
	cap confirm file out/out_`1'_`2'_`3'_`4'_`5'_`i'.dta
	if _rc {
		simulate, reps($each_reps): mysim, obs(`2') bootstrap(`3') f(`4') rep(`5')
		gen seed = `1'
		save out/out_`1'_`2'_`3'_`4'_`5'_`i'.dta, replace
	}
	cap rm "error.txt"
	cap rm "output.txt"
}
timer list

cap log close
