
clear all
cap cd /cluster/home/kahrens/ddml_applied
cap cd /Users/kahrens/MyProjects/ddml_applied

global outpath /Users/kahrens/MyProjects/ddml_sjpaper/Simul/sim_Advantages 

cap mkdir $outpath
global folder out 
cd sim_Advantages

local files : dir outlarge files "*.dta"
foreach f in `files' {
	preserve
	tempfile tfile
	cap use outlarge/`f', clear
	if _rc==0 {
		gen file = "`f'"
		save `tfile', replace	
	}
	restore
	cap append using `tfile'
}
local files: dir outsmall files "*.dta"
foreach f in `files' {
	preserve
	tempfile tfile
	cap use outsmall/`f', clear
	if _rc==0 {
		gen file = "`f'"
		save `tfile', replace	
	}
	restore
	cap append using `tfile'
}

replace obs = obs * dsets

sort dgp obs tau kappa1 kappa2 folds seed tn1
br dgp obs tau kappa1 kappa2 folds seed t*

** drop additional simulation runs if there are more than 1000
*bysort dgp obs tau kappa1 kappa2 folds: gen i=_n
*drop if i>1000

sort dgp obs tau kappa1 kappa2 folds seed tn1


replace t3 = . if tn3[_n-1]==tn3
foreach i of numlist 1 3 4 5 {
	gen double a`i'=t`i'/tn`i'
}

drop if missing(a3)

bysort dgp obs tau kappa1 kappa2 folds  : gen i = _n
keep if i<=40

// only keep last iteration per seed
//keep if mt==tn5

gen count = 1
collapse (mean) a1-a5   (sum) count , by(dgp obs tau kappa1 kappa2 folds)		
 
sort dgp folds obs

keep if dgp==0
keep a1-a5 folds obs 

rename a1 st
rename a3 ss
rename a4 pds
rename a5 ols

gen ratio = ss/st

gen gap = ""
tostring folds, replace
replace folds = "" if obs >200

foreach var of varlist st ss {
	tostring  `var' , replace format(%9.2f) force
}
foreach var of varlist ols pds ratio {
	tostring  `var' , replace format(%9.4f) force 
}

texsave folds obs gap st ss ols pds ratio ///
			using $outpath/timing_long.tex , dataonly replace  

