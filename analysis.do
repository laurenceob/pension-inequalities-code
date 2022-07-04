/********************************************************************************
**** Title: 		analysis.do 
**** Author: 		Jack Kemp 
**** Date started: 	27/06/2022 
**** Description:	This do file produces output for pension inequalities project
********************************************************************************/

*-----------------------------------STARTUP-------------------------------------
capture program start
program define start

set scheme s1color //good looking graph theme
ssc install mylabels // installed for clean axis look
ssc install listtab //table output
ssc install outreg2 //table output
ssc install reghdfe //fixed effects regression
ssc install ftools //needed for reghdfe
ssc install oaxaca //oaxaca decomposition

*setting working directory

global path_JK "P:\JPI_PENSINEQ\Inequalities\Summer_student\analysis" 
local a JK
cd "${path_`a'}\data"
use "usoc_clean.dta", clear 


***********************IMPORTANT****************************************
keep if inlist(econstat, 1, 2)  //drops those who are unemployed; 29,411 dropped
gen pen_mem = 100*jbpenm // so that pension membership is /100
************************************************************************

*creating age dummy 
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

*creating age dummy 1
gen age_dum_1 = 0 if inrange(age,22,29)
replace age_dum_1 = 1 if inrange(age,30,39)
replace age_dum_1 = 2 if inrange(age,40,49)
replace age_dum_1 = 3 if inrange(age,50,59)
label define age_dumx 0 "22-29" 1 "30-39" 2 "40-49" 3 "50-59" 
label values age_dum_1 age_dumx

end

*--------------------------------SUMMARY STATS----------------------------------
capture program drop sum
program define sum

local a JK
cd "${path_`a'}\output"
*graphs of pension membership/contributions by race
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(raceb)
format pen_mem ownperc ownperc_cond %3.2f 
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"

	graph bar `x', over(raceb, label(angle(45))) ytitle("`ytitle'")
	graph export "`x'.pdf", replace
}
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

local a JK
cd "${path_`a'}\data"
use "usoc_clean.dta", clear

end

*----------------------------------AGE TRENDS-----------------------------------
capture program drop age_trends
program define age_trends

*graph for pension contributions by age
tab age //over 2000 observations per age (22-59)
local a JK
cd "${path_`a'}\output"

*The year 2020 is not included since very few observations
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(age)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
		local lab "Membership"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
		local lab "Cont. Rate"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
		local lab "Cont. Rate"

	twoway scatter `x' age, ytitle("`ytitle'") legend(lab(1 "`lab'")) || lfit `x' age 
	graph export "`x'_age.pdf", replace
}
restore

*1.---------------------------- RACE----------------------------------------------- 

preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(age_dum raceb)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' age_dum if raceb == 1, ytitle("`ytitle'") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) xtitle("Age Group") legend(lab(1 "White") lab(2 "Mixed") lab(3 "Indian") lab(4 "Pakistani") lab(5 "Bangladeshi") lab(6 "Caribbean") lab(7 "African")) || connected `x' age_dum if raceb == 2 || connected `x' age_dum if raceb == 3 || connected `x' age_dum if raceb == 4 || connected `x' age_dum if raceb == 5 || connected `x' age_dum if raceb == 7 || connected `x' age_dum if raceb == 8 
	graph export "`x'_age_race.pdf", replace
}
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

*Creating a table of age by race
forvalues i=0/9{
    preserve
	tempfile age_`i'
	keep if age_dum == `i'
	collapse (count) age_dum, by(raceb)
	ren age_dum age_`i'
	save `age_`i''
	restore
}

use `age_0', clear
forvalues i=1/9{
	merge 1:1 raceb using `age_`i''
	drop _merge
}
label var age_0 "22-25"
label var age_1 "26-29"
label var age_2 "30-33"
label var age_3 "34-37"
label var age_4 "38-41"
label var age_5 "42-45"
label var age_6 "46-49"
label var age_7 "50-53"
label var age_8 "54-57"
label var age_9 "58-59"
local a JK
cd "${path_`a'}\output"
listtab using "age_by_race.tex", rstyle(tabular) replace
local a JK
cd "${path_`a'}\data"
use "usoc_clean.dta", clear

*creating a second table with different aggregation
forvalues i=0/3{
    preserve
	tempfile age_`i'
	keep if age_dum_1 == `i'
	collapse (count) age_dum_1, by(raceb)
	ren age_dum_1 age_`i'
	save `age_`i''
	restore
}

use `age_0', clear
forvalues i=1/3{
	merge 1:1 raceb using `age_`i''
	drop _merge
}
label var age_0 "22-29"
label var age_1 "30-39"
label var age_2 "40-49"
label var age_3 "50-59"
local a JK
cd "${path_`a'}\output"
listtab using "age_by_race_1.tex", rstyle(tabular) replace
local a JK
cd "${path_`a'}\data"
use "usoc_clean.dta", clear



*2----------------- PUBLIC VS PRIVATE SECTOR [public = 1 if in public sector]----------------

preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(age_dum public)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' age_dum if public == 0, ytitle("`ytitle'") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) xtitle("Age Group") legend(lab(1 "Private") lab(2 "Public")) || connected `x' age_dum if public == 1
	graph export "`x'_age_pub.pdf", replace
}
restore

*Checking distribution of age by sector
kdensity age, nograph gen(y fy)
forvalues i=0/1{
	kdensity age if public == `i', nograph gen(fy`i') at(y)
}
label var fy0 "Private"
label var fy1 "Public"
line fy0 fy1 y, sort ytitle(Density)
graph export "dens_age_pub.pdf", replace


*3------------------------------HEALTH STATUS----------------------------------
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(age_dum health)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' age_dum if health == 1, ytitle("`ytitle'") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) xtitle("Age Group") legend(lab(1 "Health Condition") lab(2 "No Health Condition")) || connected `x' age_dum if health == 2
	graph export "`x'_age_health.pdf", replace
}
restore

*checking distribution of age by health status
kdensity age, nograph gen(z fz)
forvalues i=1/2{
	kdensity age if health == `i', nograph gen(fz`i') at(z)
}
label var fz1 "Health Condition"
label var fz2 "No Health Condition"
line fz1 fz2 z, sort ytitle(Density)
graph export "dens_age_health.pdf", replace


*------------------------------REGION-------------------------------------------
kdensity age, nograph gen(a fa)
forvalues i=1/12{
	kdensity age if region == `i', nograph gen(fa`i') at(a)
}
label var fa1 "North East"
label var fa2 "North West and Merseyside"
label var fa3 "Yorks and Humberside"
label var fa4 "East Midlands"
label var fa5 "West Midlands"
label var fa6 "Eastern"
label var fa7 "London"
label var fa8 "South East"
label var fa9 "South West"
label var fa10 "Wales"
label var fa11 "Scotland"
label var fa12 "Northern Ireland"
line fa1 fa2 fa3 fa4 fa5 fa6 fa7 fa8 fa9 fa10 fa11 fa12 a, sort ytitle(Density)
graph export "dens_age_region.pdf", replace

*-----------------------------EDUCATION-----------------------------------------
kdensity age, nograph gen(b fb)
forvalues i=0/5{
	kdensity age if edgrpnew == `i', nograph gen(fb`i') at(b)
}
label var fb0 "None of the above"
label var fb1 "Less than GCSEs"
label var fb2 "GCSEs"
label var fb3 "A-Levels"
label var fb4 "Vocational higher"
label var fb5 "University"
line fb0 fb1 fb2 fb3 fb4 fb5 b, sort ytitle(Density)
graph export "dens_age_edu.pdf", replace

preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(age_dum_1 edgrpnew)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' age_dum_1 if edgrpnew == 0, ytitle("`ytitle'") xlabel(0 "22-29" 1 "30-39" 2 "40-49" 3 "50-59", angle(45)) xtitle("Age Group") legend(lab(1 "None of the above") lab(2 "Less than GCSEs") lab(3 "GCSEs") lab(4 "A-levels") lab(5 "Vocational higher") lab(6 "University")) || connected `x' age_dum_1 if edgrpnew == 1 || connected `x' age_dum_1 if edgrpnew == 2 || connected `x' age_dum_1 if edgrpnew == 3 || connected `x' age_dum_1 if edgrpnew == 4 || connected `x' age_dum_1 if edgrpnew == 5    
	graph export "`x'_age_edu.pdf", replace
}
restore



end

*----------------------------------TIME TRENDS----------------------------------
capture program drop time_trends
program define time_trends

local a JK
cd "${path_`a'}\output"
preserve
drop if intyear == 2020
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(intyear)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
		local lab "Membership"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
		local lab "Cont. Rate"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
		local lab "Cont. Rate"

	twoway connected `x' intyear, ytitle("`ytitle'") legend(lab(1 "`lab'")) || lfit `x' intyear 
	graph export "`x'_time.pdf", replace
}
restore

*---------------------------------------RACE-------------------------------------
preserve
drop if intyear == 2020
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(intyear raceb)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' intyear if raceb == 1, ytitle("`ytitle'") legend(lab(1 "White") lab(2 "Mixed") lab(3 "Indian") lab(4 "Pakistani") lab(5 "Bangladeshi") lab(6 "Caribbean") lab(7 "African")) || connected `x' intyear if raceb == 2 || connected `x' intyear if raceb == 3 || connected `x' intyear if raceb == 4 || connected `x' intyear if raceb == 5 || connected `x' intyear if raceb == 7 || connected `x' intyear if raceb == 8 
	graph export "`x'_time_race.pdf", replace
}
restore

*---------------------------------------SECTOR----------------------------------
preserve
drop if intyear == 2020
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(intyear public)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' intyear if public == 0, ytitle("`ytitle'") legend(lab(1 "Private") lab(2 "Public")) || connected `x' intyear if public == 1
	graph export "`x'_time_pub.pdf", replace
}
restore

*-------------------------------------------HEALTH STATUS------------------------
preserve
drop if intyear == 2020
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(intyear health)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' intyear if health == 1, ytitle("`ytitle'") legend(lab(1 "Health Condition") lab(2 "No Health Condition")) || connected `x' intyear if health == 2

	graph export "`x'_time_health.pdf", replace
}
restore

end

*------------------------------OAXACA DECOMPOSITION-----------------------------
capture program drop oaxaca_decom
program define oaxaca_decom

*using two way decomp - pooled is suggested

***********************************AGE*****************************************

*------------------------HEALTH-------------------------------------------------
foreach x in ownperc ownperc_cond pen_mem {
	eststo: oaxaca `x' age [pw=rxwgt] if inrange(health,1,2), by(health) pooled detail
	esttab using `x'_oax_health.tex, replace label 
	eststo clear
}

*-----------------------EDUCATION-----------------------------------------------

foreach x in ownperc ownperc_cond pen_mem {
	forvalues i=1/4{
		eststo: oaxaca `x' age [pw=rxwgt] if inlist(edgrpnew,`i',5), swap by(edgrpnew) pooled detail 
		esttab using `x'_`i'_oax_edu.tex, replace label
		eststo clear
	}
}


end

