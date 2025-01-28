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

import delimited "restatw.dat", delimiter(tab) clear 
save restatw.dta, replace

import delimited "data_spec1and2.csv", delimiter(",") clear 
save data_spec1and2.dta, replace

merge 1:1 _n using restatw.dta

assert y == tw
assert d == e401  

save data_401k_final.dta, replace
