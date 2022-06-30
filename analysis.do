set scheme s1color //good looking graph theme
ssc install mylabels // installed for clean axis look
ssc install listtab
ssc install outreg2
ssc install reghdfe
ssc install ftools
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

*------AGE TRENDS--------------------------------------------------------------

*graph for pension contributions by age
tab age //over 2000 observations per age (22-59)

gen age_dum = 0 if inrange(age,22,25)
replace age_dum = 1 if inrange(age,26,29)
replace age_dum = 2 if inrange(age,30,33)
replace age_dum = 3 if inrange(age,34,37)
replace age_dum = 4 if inrange(age,38,41)
replace age_dum = 5 if inrange(age,42,45)
replace age_dum = 6 if inrange(age,46,49)
replace age_dum = 7 if inrange(age,50,53)
replace age_dum = 8 if inrange(age,54,57)
replace age_dum = 9 if inrange(age,58,59)
label define age_dum1 0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59"
label values age_dum age_dum1


local a JK
cd "${path_`a'}\output"
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(age)
twoway scatter pen_mem age, ytitle("Membership Rate (%)") legend(label(1 "Membership"))   || lfit pen_mem age 
graph export "mem_age.pdf", replace

twoway scatter ownperc age, ytitle("Unconditional Contribution Rate (%)") legend(label(1 "Cont. Rate"))   || lfit ownperc age 
graph export "cont_age.pdf", replace

twoway scatter ownperc_cond age, ytitle("Conditional Contribution Rate (%)") legend(label(1 "Cont. Rate"))   || lfit ownperc_cond age 
graph export "cont_c_age.pdf", replace

restore

*1. RACE 

preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(age_dum raceb)
twoway connected pen_mem age_dum if raceb == 1, ytitle("Membership Rate (%)") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) xtitle("Age Group") legend(lab(1 "White") lab(2 "Mixed") lab(3 "Indian") lab(4 "Pakistani") lab(5 "Bangladeshi") lab(6 "Caribbean") lab(7 "African")) || connected pen_mem age_dum if raceb == 2 || connected pen_mem age_dum if raceb == 3 || connected pen_mem age_dum if raceb == 4 || connected pen_mem age_dum if raceb == 5 || connected pen_mem age_dum if raceb == 7 || connected pen_mem age_dum if raceb == 8 
graph export "mem_age_race.pdf", replace

twoway connected ownperc age_dum if raceb == 1, ytitle("Unconditional Contribution Rate (%)") xtitle("Age Group") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) legend(lab(1 "White") lab(2 "Mixed") lab(3 "Indian") lab(4 "Pakistani") lab(5 "Bangladeshi") lab(6 "Caribbean") lab(7 "African")) || connected ownperc age_dum if raceb == 2 || connected ownperc age_dum if raceb == 3 || connected ownperc age_dum if raceb == 4 || connected ownperc age_dum if raceb == 5 || connected ownperc age_dum if raceb == 7 || connected ownperc age_dum if raceb == 8 
graph export "cond_age_race.pdf", replace

twoway connected ownperc_cond age_dum if raceb == 1, ytitle("Conditional Contribution Rate (%)") xtitle("Age Group") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) legend(lab(1 "White") lab(2 "Mixed") lab(3 "Indian") lab(4 "Pakistani") lab(5 "Bangladeshi") lab(6 "Caribbean") lab(7 "African")) || connected ownperc_cond age_dum if raceb == 2 || connected ownperc_cond age_dum if raceb == 3 || connected ownperc_cond age_dum if raceb == 4 || connected ownperc_cond age_dum if raceb == 5 || connected ownperc_cond age_dum if raceb == 7 || connected ownperc_cond age_dum if raceb == 8 
graph export "cond_c_age_race.pdf", replace
restore

*regression output for pension cont and membership by race, controlling for age
eststo: qui reg pen_mem age ib1.raceb
eststo: qui reg ownperc age ib1.raceb
eststo: qui reg ownperc_cond age ib1.raceb
esttab using pen_age_race.tex, se replace mtitles("Membership" "Uncond. Contribution Rate" "Cond. Contribution Rate") label drop(1.raceb) addnotes("Coefficients compare outcome of interest for the stated ethnic group compared to Whites, controlling for age trends")
eststo clear

*controlling for age fixed effects
*Cluster standard errors??
eststo: qui reghdfe pen_mem ib1.raceb, absorb(age)
estadd local age_fe "Yes"
eststo: qui reghdfe ownperc ib1.raceb, absorb(age)
estadd local age_fe "Yes"
eststo: qui reghdfe ownperc_cond ib1.raceb, absorb(age)
estadd local age_fe "Yes"
esttab using pen_age_race.tex, se replace mtitles("Membership" "Uncond. Contribution Rate" "Cond. Contribution Rate") label drop(1.raceb) addnotes("Coefficients compare outcome of interest for the stated ethnic group compared to Whites, controlling for age fixed effects") stat(age_fe N, label("Age FE" "Observations")) 
eststo clear

*2 PUBLIC VS PRIVATE SECTOR [public = 1 if in public sector]

preserve

collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(age_dum public)
twoway connected pen_mem age_dum if public == 0, ytitle("Membership Rate (%)") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) xtitle("Age Group") legend(lab(1 "Private") lab(2 "Public")) || connected pen_mem age_dum if public == 1
graph export "mem_age_pub.pdf", replace

twoway connected ownperc age_dum if public == 0, ytitle("Unconditional Contribution Rate (%)") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) xtitle("Age Group") legend(lab(1 "Private") lab(2 "Public")) || connected ownperc age_dum if public == 1
graph export "cont_age_pub.pdf", replace

twoway connected ownperc_cond age_dum if public == 0, ytitle("Conditional Contribution Rate (%)") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) xtitle("Age Group") legend(lab(1 "Private") lab(2 "Public")) || connected ownperc_cond age_dum if public == 1
graph export "cont_c_age_pub.pdf", replace

restore

*3 HEALTH STATUS

preserve

collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(age_dum health)
twoway connected pen_mem age_dum if health == 1, ytitle("Membership Rate (%)") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) xtitle("Age Group") legend(lab(1 "Health Condition") lab(2 "No Health Condition")) || connected pen_mem age_dum if health == 2
graph export "mem_age_health.pdf", replace

twoway connected ownperc age_dum if health == 1, ytitle("Unconditional Contribution Rate (%)") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) xtitle("Age Group") legend(lab(1 "Health Condition") lab(2 "No Health Condition")) || connected ownperc age_dum if health == 2
graph export "cont_age_health.pdf", replace

twoway connected ownperc_cond age_dum if health == 1, ytitle("Conditional Contribution Rate (%)") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) xtitle("Age Group") legend(lab(1 "Health Condition") lab(2 "No Health Condition")) || connected ownperc_cond age_dum if health == 2
graph export "cont_c_age_health.pdf", replace

restore

*Checking distribution of age by ethnic group
estpost tabstat age, by(raceb) statistics(count mean sd) columns(statistics) listwise
esttab using dist_age_race.tex, replace cell("count mean sd") noobs nonumber
eststo clear

kdensity age, nograph gen(x fx)
forvalues i=1/10{
	kdensity age if raceb == `i', nograph gen(fx`i') at(x)
}
label var fx1 "White"
label var fx2 "Mixed"
label var fx3 "Indian"
label var fx4 "Pakistani"
label var fx5 "Bangladeshi"
label var fx6 "Other Asian"
label var fx7 "Caribbean"
label var fx8 "African"
label var fx9 "Other Black"
label var fx10 "Other"
line fx1 fx2 fx3 fx4 fx5 fx6 fx7 fx8 fx9 fx10 x, sort ytitle(Density)
graph export "dens_age_race.pdf", replace


*---------TIME TRENDS--------------------------------------------------------------







