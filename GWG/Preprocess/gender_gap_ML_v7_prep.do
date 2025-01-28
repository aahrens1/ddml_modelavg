clear all
cap cd "/Users/kahrens/MyProjects/ddml_simulations/GWG/Preprocess"
//cap log close
//log using "gender_gap_ML_v7_prep.txt", text replace


********************************************************************************
// 1. PRELIMINARIES
********************************************************************************

// set graph scheme to Stata Journal :)
set scheme sj

// set maximum number of variables to the highest possible
set maxvar 32767

// load data
use "piaac_gbr.dta"


********************************************************************************
// 2. EARNINGS
********************************************************************************

// Earnings is hourly earnings including bonuses.
// Refers to wage and salary earners only; self-employed (~10%) excluded.
// No outliers dropped here, but drop zeros.

drop if missing(earnhrbonusppp) == 1

// count and drop zeros
count if earnhrbonusppp==0
drop if earnhrbonusppp==0

// gen ln(earnings)
cap drop lnearn
gen lnearn = log(earnhrbonusppp)
label variable lnearn "Natural logarithm of hourly earnings"

// drop the unemployed and out-of-labour-force
// Nothing dropped if using earnhrbonusppp.
drop if c_d05 != 1

********************************************************************************
// 3. GENDER
********************************************************************************

// drop if missing

count if missing(gender_r) == 1
drop if missing(gender_r) == 1
tab gender_r
replace gender_r = 0 if gender_r == 1
replace gender_r = 1 if gender_r == 2
label define GENDER_R 0 `"Male"', modify
label define GENDER_R 1 `"Female"', modify
tab gender_r

********************************************************************************
// 5. CONTROLS
********************************************************************************

// Foreign education b_q01a is detailed in b_q01a3.
tab b_q01a3 b_q01a
// Merge foreign education variable
replace b_q01a = b_q01a3 if b_q01a == 15 & !missing(b_q01a3)
// Assume remaining non-detailed foreign degree=16 ISCED 5A bachelor, 5A master
replace b_q01a = 16 if b_q01a == 15 & b_q01a3 == 15
drop b_q01a3


// 5.1 ENCODING STRINGS
//------------------------------------------------------------------------------

// encoding string variables

quietly ds, has(type string)
foreach var of any `r(varlist)' {
	cap drop "new_`var'"
	encode `var', generate("new_`var'")
	drop `var'
}

// 5.2 DROPPING
//------------------------------------------------------------------------------

// drop weights
drop d3* c3* e3* c6* e6* u0* u1* u2* p3* m3* m6* n3* p6* p9* spfwt* zz*		///
	vemethodn new_vemethod vefayfac venreps varstrat varunit

// drop categorical versions of continuous variables
// drop *_c *_ca *cat

// drop Trend-IALS/ALL versions of variables
// drop *_t *_t1 *_t2

// drop earnings-related variables
drop earnhr* earnmth* monthlyincpr yearlyincpr earnflag d_q16* d_q17* d_q18* d_s16*

// drop admin variables
drop cba* corestage* random_* prc_* disp_* pbroute cntryid cntryid_e seqid

// drop second order occupation groups
drop  new_isic2l  new_isic2c  new_isco2c  new_isco2l new_iscosk~4 


// 5.3.2 MAKING DISCRETE CONTROLS COMPUTATIONALLY FEASIBLE
//------------------------------------------------------------------------------

// identify country variables and aggregate them
cap macro drop country_vars
global country_vars cnt_h cnt_brth 

foreach var in $country_vars {
	cap drop ag_`var'
	gen 	ag_`var' = 1 if `var' == 826
	replace ag_`var' = 2 if `var' != 826 & `var' != 0
	replace ag_`var' = 0 if `var' == 0
	local x : variable label `var'
	label variable ag_`var' "`x' (UK or not)"
	drop `var'
}

// identify language variables and aggregate them
cap macro drop language_vars
global language_vars new_lng_l1 new_lng_home new_lng_l2 

foreach var in $language_vars {
	cap drop ag_`var'
	gen 	ag_`var' = 1 if `var' == "eng":`var'
	replace ag_`var' = 2 if `var' != "eng":`var' & `var' != 0
	replace ag_`var' = 0 if `var' == 0
	local x : variable label `var'
	label variable ag_`var' "`x' (English or not)"
	drop `var'
}

// merge age of child and youngest child
replace j_q03d1 = j_q03c if !missing(j_q03c) & missing(j_q03d1)

// create job tenure variable in years = current age - age at joining firm
gen tenure = age_r - d_q05a1
// if -1 because of rounding, set to zero
replace tenure = 0 if tenure==-1
assert tenure >=0

// create years in country = current age - age at immigration
// if -1 because of rounding, set to zero
// can use instead of categorical j_q04c1_c
gen immig_years = age_r - j_q04c1
replace immig_years = 0 if immig_years==-1
assert immig_years >=0

********************************************************************************

// All variable transformations, dropping unused variables, etc., done by here.
// Key variables are earnings and gender.
// Three sets of variables: keyvars, continuous controls, discrete controls.
// Additional set of alternative (continuous) variables.

global keyvars																///
	lnearn																	///
	gender_r

global continuous															///
	age_r																	/// no missing
	yrsqual		/* years of education (derived) */							/// 355 missing
	leavedu		/* age when left education (derived) */						/// 1,081 missing
	pvlit1		/* literacy score: plausible value 1 (also 2-10 avail) */	/// no missing
	pvnum1		/* numeracy score: plausible value 1 (also 2-10 avail) */	/// no missing
	tenure		/* tenure = years in work for current employer */			/// 2 missing
																			//

global discrete																///
	new_reg_tl2	/* geographical region */									/// 2 missing
	new_isco1c	/* occupation */											/// no missing
	new_isic1c	/* industry */												/// no missing
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

// personality variables (all discrete)
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

// alternative variables that could be used
global alternative															///
	immig_years	/* immigration: years in country */							/// 4,375 missing
	d_q10		/* hours per week */										/// 1 missing
	j_q03d1		/* age of youngest child */									/// 1,858 missing
	pared		/* parents' highest level educ (derived) */					/// 706 missing
	nfehrs		/* hours in non-formal education (derived) */				/// 1,844 missing
																			//
********************************************************************************

// keep only specified variables
keep $keyvars $discrete $continuous $alternative $personality

// all discrete variables (should) have non-negative values
// so can set missing to zero = "n.a."
// do this only if at least 100 missing observations
foreach var of varlist $discrete {
	di "var=`var'"
	sum `var', meanonly
	assert r(min)>=0
	qui count if missing(`var')
	if r(N)>100 {
		qui replace `var'=0 if missing(`var')
	}
}

// all continuous variables (should) have non-negative values
// set missing = -1 and create corresponding dummy
// do this only if at least 100 missing observations
cap macro drop continuous_na
foreach var of varlist $continuous {
	sum `var', meanonly
	assert r(min)>=0
	qui count if missing(`var')
	if r(N)>100 {
		qui gen `var'_na = missing(`var')
		qui replace `var' = -1 if missing(`var')
		global continuous_na $continuous_na `var'_na
	}
}

// repeat for set of alternative (continuous) controls
// all continuous variables (should) have non-negative values
// set missing = -1 and create corresponding dummy
// do this only if at least 100 missing observations
cap macro drop alternative_na
foreach var of varlist $alternative {
	sum `var', meanonly
	assert r(min)>=0
	qui count if missing(`var')
	if r(N)>100 {
		qui gen `var'_na = missing(`var')
		qui replace `var' = -1 if missing(`var')
		global alternative_na $alternative_na `var'_na
	}
}



// 5.7 SAVE DATASET
//------------------------------------------------------------------------------

save ../Data/gender_gap_ML_processed, replace
