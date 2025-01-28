
clear all

if ("`c(os)'"=="MacOSX") {
	adopath + "/Users/kahrens/MyProjects/ddml"
	adopath + "/Users/kahrens/MyProjects/pystacked"
	cd "/Users/kahrens/MyProjects/ddml_simulations/"
}
else {
	cd "/cluster/home/kahrens/ddml_simulations/"
	cap python set exec /cluster/apps/nss/gcc-8.2.0/python/3.9.9/x86_64/bin/python3
	cap set processors 1
}

global outpath /Users/kahrens/MyProjects/ddml_sjpaper/Intro_example
global outpath2 /Users/kahrens/MyProjects/ddml_applied/Intro_example
cap mkdir $outpath
cd sim_SJ

global folder 

local files : dir out files "*.dta"
foreach f in `files' {
	cap append using out/`f'	
}
 
foreach var of varlist ddml*_b pds_b ols_b pds2_b pds3_b oracle_b {
	local var = subinstr("`var'","_b","",1)
	di "`var'"
	qui gen `var'_p = 2*normal(-abs((`var'_b)/(`var'_se)))
	qui gen `var'_abias = abs(`var'_b-beta)
	qui gen `var'_bias = (`var'_b-beta)
	qui gen `var'_sign=`var'_p<0.05
	qui gen `var'_cov = inrange(beta,`var'_b-1.96*`var'_se,`var'_b+1.96*`var'_se)
} 

drop if missing(dgp)

save sim_temp_all.dta, replace

gen byte count = 1
collapse (mean) *sign *_p *_cov *_b ssw_* stw_* psw_* mspe* rd ry *_bias (median) *abias (sum) count, by(beta dgp0 obs) 

tab dgp, summarize(ry)
tab dgp, summarize(rd)


save sim_temp.dta, replace


********* histogram

use sim_temp_all.dta, clear

keep if dgp0==2 & obs ==1000

label var oracle_bias "Infeasible Oracle"
 
twoway  /// (hist oracle_bias   , width(0.01) start(-0.4) color(midgreen%30)  ) ///
		(kdensity ddml_ss_nnls1_bias  , bw(0.01) lcolor(midgreen) lwidth(0.4) ) ///
		(kdensity ddml_x_2_bias  ,  bw(0.01) lcolor(red)  lpattern(dash) lwidth(0.4) ) ///
		(kdensity ddml_x_14_bias  , bw(0.01) lcolor(navy) lpattern(dash_dot) lwidth(0.4) ) , ///
		scheme(tab1) ///
		legend(order(1 "DDML & Stacking" 2 "DDML & CV-Lasso" 3 "DDML & Neural net")  size(medsmall)) ///
		xlabel(-.3(0.1).5,labsize(medsmall)) xsc(r(-.3 .5)  ) ///
		ylabel(,labsize(medsmall))  ///
		ytitle("",size(medsmall)) ///
		xtitle("Bias",size(medsmall))   
graph export $outpath/example1.png, replace
graph export $outpath2/example1.png, replace
 
********* Example 2

use sim_temp_all.dta, clear

keep if dgp0==5 & obs ==1000

label var oracle_bias "Infeasible Oracle"
 
twoway /// (hist oracle_bias   , width(0.01) start(-0.4) color(midgreen%30)  ) ///
		(kdensity ddml_st_nnls1_bias  , bw(0.01)  lcolor(midgreen) lwidth(0.4)  lwidth(0.4) ) /// 
		(kdensity ddml_x_2_bias , bw(0.01) lcolor(red)  lpattern(dash) lwidth(0.4)  ) ///  
		(kdensity ddml_x_14_bias , bw(0.01)  lcolor(navy)  lpattern(dash_dot) lwidth(0.4) ) , ///  
		scheme(tab1) ///
		legend(order(1 "DDML & Stacking" 2 "DDML & CV-Lasso" 3 "DDML & Neural net")  size(medsmall)) ///
		xlabel(-.4(0.1).3,labsize(medsmall)) xsc(r(-.4 .2)  ) ///
		ylabel(,labsize(medsmall))  ///
		ytitle("",size(medsmall)) ///
		xtitle("Bias",size(medsmall))   
graph export $outpath/example2.png, replace
graph export $outpath2/example2.png, replace
