set scheme s1color //good looking graph theme
ssc install mylabels // installed for clean axis look
ssc install listtab
global path_JK "P:\JPI_PENSINEQ\Inequalities\Summer_student\analysis" 
local a JK
cd "${path_`a'}\data"
use "usoc_clean.dta", clear 
keep if inlist(econstat, 1, 2)  //drops those who are unemployed; 29,411 dropped
gen pen_mem = 100*jbpenm // so that pension membership is /100

*------------------------------------------------------------------------------
local a JK
cd "${path_`a'}\output"

*graphs of pension membership/contributions by race
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(raceb)
format pen_mem ownperc ownperc_cond %3.2f 
/*mylabels 0(.2).8, clean local(labels) //change 0.0 to 0 on y axis
twoway bar jbpenm raceb, ylabel(`labels', grid format(%03.1f)) xlabel(1 2 3 4 5 6 7 8 9 10, angle(45) valuelabel) ytitle("Pension Membership (%)") color(orange) barwidth(0.6) plotregion(margin(zero)) xtitle("")
*/
graph bar pen_mem, over(raceb, label(angle(45))) ytitle("Membership Rate (%)")
graph export "pension_mem.pdf", replace

*unconditional
graph bar ownperc, over(raceb, label(angle(45))) ytitle("Unconditional Contribution Rate (%)")
graph export "pension_cont.pdf", replace

*conditional
graph bar ownperc_cond, over(raceb, label(angle(45))) ytitle("Conditional Contribution Rate (%)")
graph export "pension_cont_c.pdf", replace

restore


*table output of summary statistics by region, education [edgrpnew](highest qualification), health (long standing illness or disability)

foreach i in region health edgrpnew raceb{
    preserve
	tempfile `i'_t
	collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(`i')
	format pen_mem ownperc ownperc_cond %3.2f 
	decode `i', gen(category)
	save ``i'_t'
	restore
}

use `region_t', clear
append using `edgrpnew_t' `health_t' `raceb_t'
drop health region edgrpnew raceb
order category 
label var category "Category"
label var ownperc "Unconditional Contribution Rate"
label var ownperc_cond " Conditional Contribution Rate"
label var pen_mem "Membership Rate"
drop if inlist(category, "region missing", "Missing", "Refused", "Dont know", "")
replace category = "Health Problem" if category == "Yes"
replace category = "No Health Problem" if category == "No"
listtab using "pen_saving_by_groups_simple.tex", rstyle(tabular) replace














