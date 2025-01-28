clear all 

if ("`c(os)'"=="MacOSX") {
	cd "/Users/kahrens/MyProjects/ddml_simulations/"
}
else {
	cd "/cluster/home/kahrens/ddml_applied/sim_Advantages"
	cap python set exec /cluster/apps/nss/gcc-8.2.0/python/3.9.9/x86_64/bin/python3
	cap set processors 1
}

local folder `6'
cap mkdir out`folder'
cap mkdir log`folder'

cap log close
log using log`folder'/log`folder'_`1'_`2'_`3'_`4'_`5'.txt, text replace

whichpkg ddml
whichpkg pystacked

cap set seed `1'
di "`1' `2' `3' `4' `5'"

global Y net_tfa
global D e401  
global X age inc educ fsize marr twoearn db pira hown 
global Xcont age inc educ fsize
global Xbin marr twoearn db pira hown 

global reps = 5 // 10
global each_reps = 1 // 4 
if ("`4'"=="1" & "`2'"!="9915") {
	global reps 1
	global each_reps 100
}
if ("`4'"=="1" & "`2'"=="9915") {
	global reps 5
	global each_reps 10
}

* options
global pyopt njobs(1)  
global rflow max_features(8) min_samples_leaf(1) max_samples(.7)
global rfhigh max_features(5) min_samples_leaf(10) max_samples(.7)
global gradlow n_estimators(500) learning_rate(0.01)
global gradhigh n_estimators(250) learning_rate(0.01)
global nnetopt hidden_layer_sizes(5 5 5)
global xvar_poly2 c.($Xcont)##c.($Xcont) $Xbin
global xvar_poly10 poly10* $Xbin 

* program 
cap program drop mysim
program define mysim , rclass

	syntax [, 	dgp(string) ///
				kappa1(real 0.35) ///
				kappa2(real 55500) ///
				tau(real 6000) ///
				obs(integer 9915) ///
				dsets(integer 1) ///
				folds(integer 2) ///
			]
			
	use "../Data/PVW_data.dta", clear
	
	*if "`tau'"=="" {
	*	local dgp ols
	*	local kappa1 0.35
	*	local kappa2 55500
	*	local tau 6000
	*	local obs 3000
	*	local dsets 1
	*	local folds 2
	*}
	
	*** DGP // coef = 5896.198 
	reg $Y $D $X  
	gen double yr = $Y - _b[$D]*$D
	
	*** fit learners to reduced form
	if ("`dgp'"=="gradboost") {
		pystacked yr $X, method(gradboost) $pyopt 
		predict double ghat
		pystacked $D $X, method(gradboost) $pyopt 
		predict double hhat 
		local dgpflag = 1
		local kappa2 = 54000
	}
	else if ("`dgp'"=="ols") {
		reg yr $X
		predict double ghat
		reg $D $X
		predict double hhat 
		local dgpflag = 0
		local kappa2 = 55500
	}
	else {
		di as err "dgp unknown"
		exit 198
	}

	*** draw bootstrap sample
	if `dsets'==1 {
		bsample `obs'
	}
	else {
		* save original data
		tempfile tfile0 
		save `tfile0'
		clear
		forvalues i = 1(1)`dsets' {
			tempfile tfile
			preserve
			* bootstrap from original data
			use `tfile0', clear 
			bsample `obs'
			save `tfile'
			restore
			* append
			append using `tfile' 
		}	
	}

	*** DGP
	gen double nu = rnormal(0,`kappa1')
	gen byte d_b = ((hhat+nu)>0.5)

	gen double e = rnormal(0,`kappa2')
	gen double y_b = (`tau')*d_b + ghat + e 
	
	*** create poly up to 10, w/o interactions
	foreach var of varlist $Xcont {
		forvalues i = 2(1)10 {
			gen double poly10_`var'`i'=(`var')^(`i')
		}	
	}

	*** ddml partial ***********************************************************
			
	timer on 1
	ddml init partial, kfolds(`folds')  
	ddml E[Y|X], l(Y0_py): pystacked y_b $X, ///
						method(ols lassocv ridgecv lassocv ridgecv rf rf gradboost gradboost nnet) ///
						xvars2($xvar_poly2) ///
						xvars3($xvar_poly2) ///
						xvars4($xvar_poly10)  ///
						xvars5($xvar_poly10) ///
						pipe6(sparse) cmdopt6($rflow) ///
						pipe7(sparse) cmdopt7($rfhigh) ///
						pipe8(sparse) cmdopt8($gradlow) ///
						pipe9(sparse) cmdopt9($gradhigh) ///
						cmdopt10($nnetopt) pipe10(stdscaler) ///
						$pyopt 
	ddml E[D|X], l(D0_py): pystacked d_b $X, ///
						method(ols lassocv ridgecv lassocv ridgecv rf rf gradboost gradboost nnet) ///
						xvars2($xvar_poly2) ///
						xvars3($xvar_poly2) ///
						xvars4($xvar_poly10)  ///
						xvars5($xvar_poly10) ///
						pipe6(sparse) cmdopt6($rflow) ///
						pipe7(sparse) cmdopt7($rfhigh) ///
						pipe8(sparse) cmdopt8($gradlow) ///
						pipe9(sparse) cmdopt9($gradhigh) ///
						cmdopt10($nnetopt) pipe10(stdscaler) ///
						$pyopt 
	ddml crossfit, shortstack poolstack
	ddml estimate, robust
	timer off 1
		
	local nlearners = 10
	
	foreach final in nnls1 singlebest ols avg {

		ddml estimate, robust finalest(`final')
	
			// regular stacking results
			ddml estimate, mname(m0) spec(st) replay  
			local ddml_st_`final'_b = _b[d_b]
			local ddml_st_`final'_se = _se[d_b]
			// shortstacking results
			ddml estimate, mname(m0) spec(ss) replay 
			local ddml_ss_`final'_b = _b[d_b]
			local ddml_ss_`final'_se = _se[d_b]	
			// poolstacking results
			ddml estimate, mname(m0) spec(ps) replay  
			local ddml_ps_`final'_b = _b[d_b]
			local ddml_ps_`final'_se = _se[d_b]	
		
			tempname By Bd
			// pystacked weights
			ddml extract, show(stweights)
			mat `By'=r(Y0_py_w_mn)
			mat `Bd'=r(D0_py_w_mn)
			mat list `Bd'
			mat list `By'
			forvalues i = 1(1)`nlearners' {
				local stw_`final'_d`i' = el(`Bd',`i',2)
				local stw_`final'_y`i' = el(`By',`i',2)
			}
			// shortstacked weights
			ddml extract, show(ssweights)
			mat `By'=r(Y_y_b_ss)
			mat `Bd'=r(D_d_b_ss)
			mat list `Bd'
			mat list `By'
			forvalues i = 1(1)`nlearners' {
				local ssw_`final'_d`i' = el(`Bd',`i',2)
				local ssw_`final'_y`i' = el(`By',`i',2)
			}
			// poolstacked weights
			ddml extract, show(psweights)
			mat `By'=r(Y_y_b_ps)
			mat `Bd'=r(D_d_b_ps)
			mat list `Bd'
			mat list `By'
			forvalues i = 1(1)`nlearners' {
				local psw_`final'_d`i' = el(`Bd',`i',2)
				local psw_`final'_y`i' = el(`By',`i',2)
			}

	}
	
	
	*** get candidate-learner-specific betas
	forvalues i = 1(1)`nlearners' {
		cap drop ytil
		cap drop dtil
		gen double ytil = y_b - Y0_py_L`i'_
		gen double dtil = d_b - D0_py_L`i'_
		reg ytil dtil, robust
		local ddml_`i'_b = _b[dtil]
		local ddml_`i'_se = _se[dtil]
	}
	
	*** get mspe
	forvalues i = 1(1)`nlearners' {
		cap drop Drsq
		gen Drsq=(d_b - D0_py_L`i'_)^2 
		sum Drsq , meanonly 
		local mspe_d`i'=r(mean)
		cap drop Yrsq
		gen Yrsq=(y_b - Y0_py_L`i'_)^2 
		sum Yrsq , meanonly 
		local mspe_y`i'=r(mean)
	}
	ddml drop
			
	* partial ddml with short-stacking *****************************************
	* we only need this for timing, so let this run only once a while **********
	if ((runiform()<0.05) | (`folds'==5)) {
		timer on 3
		ddml init partial, kfolds(`folds')  
		ddml E[Y|X]: reg y_b $X 
		ddml E[Y|X]: pystacked y_b $X, method(lassocv)  xvars1($xvar_poly2) 
		ddml E[Y|X]: pystacked y_b $X, method(ridgecv)  xvars1($xvar_poly2)
		ddml E[Y|X]: pystacked y_b $X, method(lassocv)  xvars1($xvar_poly10)  
		ddml E[Y|X]: pystacked y_b $X, method(ridgecv)  xvars1($xvar_poly10) 
		ddml E[Y|X]: pystacked y_b $X, method(rf) pipe1(sparse) cmdopt1($rflow) 
		ddml E[Y|X]: pystacked y_b $X, method(rf) pipe1(sparse) cmdopt1($rfhigh) 
		ddml E[Y|X]: pystacked y_b $X, method(gradboost) pipe1(sparse) cmdopt1($gradlow) 
		ddml E[Y|X]: pystacked y_b $X, method(gradboost) pipe1(sparse) cmdopt1($gradhigh) 
		ddml E[Y|X]: pystacked y_b $X, method(nnet) cmdopt1($nnetopt) pipe1(stdscaler)
		ddml E[D|X]: reg d_b $X  
		ddml E[D|X]: pystacked d_b $X, method(lassocv)  xvars1($xvar_poly2) 
		ddml E[D|X]: pystacked d_b $X, method(ridgecv)  xvars1($xvar_poly2) 
		ddml E[D|X]: pystacked d_b $X, method(lassocv)  xvars1($xvar_poly10) 
		ddml E[D|X]: pystacked d_b $X, method(ridgecv)  xvars1($xvar_poly10) 
		ddml E[D|X]: pystacked d_b $X, method(rf) pipe1(sparse) cmdopt1($rflow) 
		ddml E[D|X]: pystacked d_b $X, method(rf) pipe1(sparse) cmdopt1($rfhigh) 
		ddml E[D|X]: pystacked d_b $X, method(gradboost) pipe1(sparse) cmdopt1($gradlow) 
		ddml E[D|X]: pystacked d_b $X, method(gradboost) pipe1(sparse) cmdopt1($gradhigh) 
		ddml E[D|X]: pystacked d_b $X, method(nnet) cmdopt1($nnetopt) pipe1(stdscaler)
		ddml crossfit, shortstack nostdstack
		ddml estimate, robust allcombos
		timer off 3
	}


	* full sample estimators ***************************************************

	timer on 4
	pdslasso y_b d_b ($X), robust
	timer off 4
	local pds_b = _b[d_b]
	local pds_se = _se[d_b]
	
	timer on 5
	local ols_b = .
	local ols_se = .
	cap reg y_b d_b $X,  robust
	timer off 5
	if _rc==0 {
		local ols_b = _b[d_b]
		local ols_se = _se[d_b]
	}
	
	*** misc *******************************************************************	
	
	*** sd
	foreach var of varlist $Y $D y_b d_b {
		sum `var'
		local sd_`var' = r(sd)
	}
	
	* timer 
	timer list
	foreach i of numlist 1 3 4 5 {
		local t`i'=r(t`i')
		local tn`i'=r(nt`i')
	}
	
	*** return *****************************************************************
	ereturn clear
	* timer
	foreach i of numlist 1 3 4 5 {
		return scalar t`i'=`t`i''
		return scalar tn`i'=`tn`i''
	}
	* coefficients per final learner
	foreach final in nnls1 singlebest ols avg {
		foreach v in st ss ps {
			return scalar ddml_`v'_`final'_b = `ddml_`v'_`final'_b'
			return scalar ddml_`v'_`final'_se = `ddml_`v'_`final'_se'
		}
	}
	* stacking weights per final learner
	foreach final in nnls1 singlebest ols avg {
		foreach type in stw ssw psw {
			forvalues i = 1(1)`nlearners' {
				return scalar `type'_`final'_d`i' = ``type'_`final'_d`i'' 
				return scalar `type'_`final'_y`i' = ``type'_`final'_y`i''
			}
		}
	}
	* coefficients from alternative short-stacking estimation
	foreach v in 1 2 3 4 5 6 7 8 9 10 {
		return scalar ddml_`v'_b = `ddml_`v'_b'
		return scalar ddml_`v'_se = `ddml_`v'_se'
	}
	* full sample estimates
	foreach v in ols pds {
		return scalar `v'_b = ``v'_b'
		return scalar `v'_se = ``v'_se'
	}
	* sd of vars
	foreach var of varlist $Y $D y_b d_b {
		return scalar sd_`var' = `sd_`var''
	}
	* mspe
	forvalues i = 1(1)`nlearners' {
		return scalar mspe_d`i' = `mspe_d`i''  
		return scalar mspe_y`i' = `mspe_y`i''  
	}	
	***** settings
	return scalar kappa1 = `kappa1'
	return scalar kappa2 = `kappa2'
	return scalar tau = `tau'
	return scalar obs = `obs'
	return scalar dgpflag = `dgpflag'
	return scalar dsets = `dsets'
	return scalar folds = `folds'
end

timer clear
forvalues i = 1(1)$reps {
	clear
	cap confirm file out`folder'/out_`1'_`2'_`3'_`4'_`5'_`i'.dta 
	if _rc {
		simulate, reps($each_reps): mysim, obs(`2') dgp(`3') dsets(`4') folds(`5')
		gen seed = `1'
		save out`folder'/out_`1'_`2'_`3'_`4'_`5'_`i'.dta, replace
	}
	cap rm "error.txt"
	cap rm "output.txt"
}
timer list

cap log close
