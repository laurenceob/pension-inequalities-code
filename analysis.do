/********************************************************************************
**** Title: 		analysis.do 
**** Author: 		Jack Kemp 
**** Date started: 	27/06/2022 
**** Description:	This do file produces output for pension inequalities project
********************************************************************************/
capture program drop main
program define main 

	start 

	sum_stat

	age_trends

	earn_trends

	oaxaca_decom

	regression_output

	auto_enroll

	ethn_sex

	eligible_employ

end


*-----------------------------------STARTUP-------------------------------------
capture program drop start
program define start

set scheme s1color //good looking graph theme
/*ssc install mylabels // installed for clean axis look
ssc install listtab //table output
ssc install outreg2 //table output
ssc install reghdfe //fixed effects regression
ssc install ftools //needed for reghdfe
ssc install oaxaca //oaxaca decomposition
ssc install binscatter //for scatter graphs
ssc install winsor //winsorize data
ssc install coefplot
*/

*setting working directory

global path_JK "P:\JPI_PENSINEQ\Inequalities\Summer_student\analysis" 
local a JK
cd "${path_`a'}\data"
use "usoc_clean.dta", clear

local a JK
cd "${path_`a'}\output"
*graphs of pension membership/contributions by race - including those not in work
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(raceb)
format pen_mem ownperc ownperc_cond %3.2f 
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"

	graph bar `x' if raceb != 10, over(raceb, label(angle(45))) ytitle("`ytitle'")
	graph export "`x'_race_notinwork.pdf", replace
}
restore

*Table - splitting by sex
preserve
collapse (mean) ownperc pen_mem [pw=rxwgt], by(raceb female)
drop if female == 2 | raceb == 10
format pen_mem ownperc %3.2f 
reshape wide ownperc pen_mem, i(raceb) j(female) 
ren ownperc0 ownperc_m
ren pen_mem0 pen_mem_m
ren ownperc1 ownperc_f
ren pen_mem1 pen_mem_f
order ownperc_f, after(ownperc_m)
listtab using "pen_saving_by_groups_notinwork.tex", rstyle(tabular) replace
restore

***********************IMPORTANT****************************************
keep if inlist(jb1status, 1, 2)  //drops those who are unemployed; 28,605 dropped
drop if sector == 0 //drops self-employed since missing pen_mem; 12,349 dropped
************************************************************************

end

*--------------------------------SUMMARY STATS----------------------------------
capture program drop sum_stat
program define sum_stat

local a JK
cd "${path_`a'}\output"

*only employees in sample
******************RACE**********************************************************
*graphs of pension membership/contributions by race
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(raceb)
format pen_mem ownperc ownperc_cond %3.2f 
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"

	graph bar `x' if inrange(raceb,1,9), over(raceb, label(angle(45))) ytitle("`ytitle'")
	graph export "`x'_race.pdf", replace
}
restore

*Graphs of retirement expectations by race
foreach x in ageret retneed famcont{
    
	if "`x'" == "ageret" local ytitle "Expected Age Of Retirement"
	if "`x'" == "famcont" local ytitle "Expecting Financial Support From Family (%)"
	else if "`x'" == "retneed" local ytitle "Expected Adequate Retirement Income (%)"
	
    preserve
    keep if `x' >= 0
	collapse (mean) `x' [pw=rxwgt], by(raceb)
	graph bar `x' if inrange(raceb,1,9), over(raceb, label(angle(45))) ytitle("`ytitle'")
	graph export "`x'_race.pdf", replace
	restore
}

*table of job vars by ethnicity (including those not in work) over time
local a JK
cd "${path_`a'}\data"
use "usoc_clean.dta", clear
local a JK
cd "${path_`a'}\output"
gen private = 0
replace private = 1 if sector == 1
gen self_employed = 0
replace self_employed = 1 if sector == 0
gen employee = 0
replace employee = 1 if inlist(sector,1,2)

preserve

keep if inlist(intyear,2010,2011,2012,2018,2019,2020)
gen post_ae = 0
replace post_ae = 1 if inlist(intyear,2018,2019,2020)
foreach i in inwork pub private self_employed employee{
	replace `i' = `i'*100
}
collapse (mean) inwork pub private self_employed employee [pw=rxwgt], by(raceb post_ae)
drop if raceb == 10
reshape wide inwork pub private self_employed employee, i(raceb) j(post_ae)
foreach i in inwork pub private self_employed employee{
	order `i'1, after(`i'0)
}
xpose, clear varname
order _varname
drop if _varname == "raceb"
replace _varname = "In Work (Pre)" if _varname == "inwork0"
replace _varname = "In Work (Post)" if _varname == "inwork1"
replace _varname = "Public (Pre)" if _varname == "pub0"
replace _varname = "Public (Post)" if _varname == "pub1"
replace _varname = "Private (Pre)" if _varname == "private0"
replace _varname = "Private (Post)" if _varname == "private1"
replace _varname = "Self-Employed (Pre)" if _varname == "self_employed0"
replace _varname = "Self-Employed (Post)" if _varname == "self_employed1"
replace _varname = "Employee (Pre)" if _varname == "employee0"
replace _varname = "Employee (Post)" if _varname == "employee1"
format v1 v2 v3 v4 v5 v6 v7 v8 v9 %12.1fc 
listtab using "job_vars_race_ae.tex", rstyle(tabular) replace
restore

local a JK
cd "${path_`a'}\data"
use "usoc_clean.dta", clear
keep if inlist(jb1status, 1, 2)
drop if sector == 0
local a JK
cd "${path_`a'}\output"

*% public in restricted sample - table
preserve
keep if inlist(intyear,2010,2011,2012,2018,2019,2020)
gen post_ae = 0
replace post_ae = 1 if inlist(intyear,2018,2019,2020)
replace pub = pub*100

collapse (mean) pub [pw=rxwgt], by(raceb post_ae)
drop if raceb == 10
reshape wide pub, i(raceb) j(post_ae)
order pub1, after(pub0)
xpose, clear varname
order _varname
drop if _varname == "raceb"
replace _varname = "Public (Pre)" if _varname == "pub0"
replace _varname = "Public (Post)" if _varname == "pub1"
format v1 v2 v3 v4 v5 v6 v7 v8 v9 %12.1fc 
listtab using "job_vars_1.tex", rstyle(tabular) replace
restore


*seeing distribution of how many waves an individual is in
egen wavesum = count(intyear), by(pidp)
histogram wavesum, di percent
graph export "wavesum.pdf", replace

*only employees in sample
*********************************************************************************
*graphs of pension membership/contributions by region
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(region)
format pen_mem ownperc ownperc_cond %3.2f 
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"

	graph bar `x', over(region, label(angle(45))) ytitle("`ytitle'")
	graph export "`x'_region.pdf", replace
}
restore

*graphs of pension membership/contributions by health status
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(health)
format pen_mem ownperc ownperc_cond %3.2f 
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"

	graph bar `x' if health >0, over(health, label(angle(45))) ytitle("`ytitle'") 
	graph export "`x'_health.pdf", replace
}
restore

*graphs of pension membership/contributions by education
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(edgrpnew)
format pen_mem ownperc ownperc_cond %3.2f 
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"

	graph bar `x', over(edgrpnew, descending label(angle(45))) ytitle("`ytitle'") 
	graph export "`x'_edu.pdf", replace
}
restore

*table output of summary statistics by region, education [edgrpnew](highest qualification), health (long standing illness or disability) - employees only
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
drop if inlist(category, "region missing", "Missing", "missing", "Refused", "Dont know", "")
replace category = "Health Problem" if category == "Yes"
replace category = "No Health Problem" if category == "No"
listtab using "pen_saving_by_groups_simple.tex", rstyle(tabular) replace

local a JK
cd "${path_`a'}\data"
use "usoc_clean.dta", clear
keep if inlist(jb1status, 1, 2)
drop if sector == 0
local a JK
cd "${path_`a'}\output"

*creating a table of covariates by race - employees only
preserve
foreach i in kid0 kid12 kid34 kid5ormore uni alevels gcse lessgcse jbsize1_24 jbsize25_199 jbsize200plus female couple married disability owned rent mort priv pub priv_p pub_p self_p partner_inwork invinc0 invinc100to1k invinc1to100 invinc1kplus mar coupl divorce nev_mar{
	replace `i' = `i'*100
}
keep if jbsize > 0
collapse (mean) age real_earn kid0 kid12 kid34 kid5ormore uni alevels gcse lessgcse jbsize1_24 jbsize25_199 jbsize200plus priv pub priv_p pub_p self_p female realpartearn owned rent mort hvalue disability partner_inwork saved invinc0 invinc1to100 invinc100to1k invinc1kplus mar coupl divorce nev_mar [pw=rxwgt], by(raceb)
*order of table: individual vars, job vars, partner vars, wealth vars
order partner_inwork realpartearn, after(self)
order disability female, after(real_earn)
order uni alevels gcse lessgcse, before(kid0)
order mar coupl divorce nev_mar, after(lessgcse)
order owned rent mort hvalue, after(invinc1kplus)
xpose, clear varname
order _varname
gen n=_n
drop if n==1
drop n v10
replace _varname = "Age" if _varname == "age"
replace _varname = "Real Weekly Earnings" if _varname == "real_earn"
replace _varname = "Percent With No Kids" if _varname == "kid0"
replace _varname = "Percent With 1-2 Kids" if _varname == "kid12"
replace _varname = "Percent With 3-4 Kids" if _varname == "kid34"
replace _varname = "Percent With 5+ Kids" if _varname == "kid5ormore"
replace _varname = "Percent Uni Degree" if _varname == "uni"
replace _varname = "Percent A-levels" if _varname == "alevels"
replace _varname = "Percent GCSEs" if _varname == "gcse"
replace _varname = "Percent Less Than GCSEs" if _varname == "lessgcse"
replace _varname = "Percent In Company With 1-24 Employees" if _varname == "jbsize1_24"
replace _varname = "Percent In Company With 25-199 Employees" if _varname == "jbsize25_199"
replace _varname = "Percent In Company With 200+ Employees" if _varname == "jbsize200plus"
replace _varname = "Percent Private Sector" if _varname == "priv"
replace _varname = "Percent Public Sector" if _varname == "pub"
replace _varname = "Percent With Partner In Work" if _varname == "partner_inwork"
replace _varname = "Percent Private Sector: Partner" if _varname == "priv_p"
replace _varname = "Percent Public Sector: Partner" if _varname == "pub_p"
replace _varname = "Percent Self-Employed: Partner" if _varname == "self_p"
replace _varname = "Percent Female" if _varname == "female"
replace _varname = "Real Partner Weekly Earnings" if _varname == "realpartearn"
replace _varname = "Percent Living As Couple" if _varname == "coupl"
replace _varname = "Percent Married/Civil Partner" if _varname == "mar"
replace _varname = "Percent Widowed/Divorced/Separated" if _varname == "divorce"
replace _varname = "Percent Never Married" if _varname == "nev_mar"
replace _varname = "Percent Long-Term Condition or Disability" if _varname == "disability"
replace _varname = "Percent Renting House" if _varname == "rent"
replace _varname = "Percent Own House Outright" if _varname == "owned"
replace _varname = "Percent Mortgage" if _varname == "mort"
replace _varname = "Average House Value (if owned)" if _varname == "hvalue"
replace _varname = "Average Monthly Savings" if _varname == "saved"
replace _varname = "Percent With No Annual Investment/Savings Income" if _varname == "invinc0"
replace _varname = "Percent with Annual Investment/Savings Income of 1-100" if _varname == "invinc1to100"
replace _varname = "Percent with Annual Investment/Savings Income of 100-1k" if _varname == "invinc100to1k"
replace _varname = "Percent with Annual Investment/Savings Income of 1k+" if _varname == "invinc1kplus"
format v1 v2 v3 v4 v5 v6 v7 v8 v9 %12.1fc 
listtab using "covariates_by_race.tex", rstyle(tabular) replace
restore
*include in table notes: Education variables refer to the highest qualification an individual has achieved

end

*----------------------------------AGE TRENDS-----------------------------------
capture program drop age_trends
program define age_trends

*graph for pension contributions by age
tab age //over 2000 observations per age (22-59)
local a JK
cd "${path_`a'}\output"

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
	
	twoway connected `x' age_dum if raceb == 1, ytitle("`ytitle'") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) xtitle("Age Group") legend(lab(1 "White") lab(2 "Mixed") lab(3 "Indian") lab(4 "Pakistani") lab(5 "Bangladeshi") lab(6 "Other Asian") lab(7 "Caribbean") lab(8 "African") lab(9 "Other")) || connected `x' age_dum if raceb == 2 || connected `x' age_dum if raceb == 3 || connected `x' age_dum if raceb == 4 || connected `x' age_dum if raceb == 5 || connected `x' age_dum if raceb == 6 || connected `x' age_dum if raceb == 7 || connected `x' age_dum if raceb == 8 || connected `x' age_dum if raceb == 9 
	graph export "`x'_age_race.pdf", replace
}
restore

*Checking distribution of age by ethnic group
preserve
estpost tabstat age if raceb != 10, by(raceb) statistics(count mean sd) columns(statistics) listwise
esttab using dist_age_race.tex, replace cell("count mean sd") noobs nonumber
eststo clear
restore

kdensity age, nograph gen(x fx)
forvalues i=1/9{
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
label var fx9 "Other"
line fx1 fx2 fx3 fx4 fx5 fx6 fx7 fx8 fx9 x, sort ytitle(Density)
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
keep if inlist(jb1status, 1, 2)
drop if sector == 0
local a JK
cd "${path_`a'}\output"

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
keep if inlist(jb1status, 1, 2)
drop if sector == 0
local a JK
cd "${path_`a'}\output"


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

preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(age_dum_1 region)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' age_dum_1 if region == 1, ytitle("`ytitle'") xlabel(0 "22-29" 1 "30-39" 2 "40-49" 3 "50-59") xtitle("Age Group") legend(lab(1 "North East") lab(2 "North West and Merseyside") lab(3 "Yorks and Humberside") lab(4 "East Midlands") lab(5 "West Midlands") lab(6 "Eastern") lab(7 "London") lab(8 "South East") lab(9 "South West") lab(10 "Wales") lab(11 "Scotland") lab(12 "Northern Ireland")) || connected `x' age_dum_1 if region == 2 || connected `x' age_dum_1 if region == 3 || connected `x' age_dum_1 if region == 4 || connected `x' age_dum_1 if region == 5 || connected `x' age_dum_1 if region == 6 || connected `x' age_dum_1 if region == 7 || connected `x' age_dum_1 if region == 8 || connected `x' age_dum_1 if region == 9 || connected `x' age_dum_1 if region == 10 || connected `x' age_dum_1 if region == 11 || connected `x' age_dum_1 if region == 12 
	graph export "`x'_age_region.pdf", replace
}
restore


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
	
	twoway connected `x' age_dum_1 if edgrpnew == 0, ytitle("`ytitle'") xlabel(0 "22-29" 1 "30-39" 2 "40-49" 3 "50-59") xtitle("Age Group") legend(lab(1 "None of the above") lab(2 "Less than GCSEs") lab(3 "GCSEs") lab(4 "A-levels") lab(5 "Vocational higher") lab(6 "University")) || connected `x' age_dum_1 if edgrpnew == 1 || connected `x' age_dum_1 if edgrpnew == 2 || connected `x' age_dum_1 if edgrpnew == 3 || connected `x' age_dum_1 if edgrpnew == 4 || connected `x' age_dum_1 if edgrpnew == 5    
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
	
	twoway connected `x' intyear if raceb == 1, ytitle("`ytitle'") legend(lab(1 "White") lab(2 "Mixed") lab(3 "Indian") lab(4 "Pakistani") lab(5 "Bangladeshi") lab(6 "Other Asian") lab(7 "Caribbean") lab(8 "African") lab(9 "Other")) || connected `x' intyear if raceb == 2 || connected `x' intyear if raceb == 3 || connected `x' intyear if raceb == 4 || connected `x' intyear if raceb == 5 || connected `x' intyear if raceb == 6 || connected `x' intyear if raceb == 7 || connected `x' intyear if raceb == 8 || connected `x' intyear if raceb == 9
	graph export "`x'_time_race.pdf", replace
}
restore

*graph with only white, Bangladeshi, Pakistani
preserve
drop if intyear == 2020
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(intyear raceb)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' intyear if raceb == 1 & inrange(intyear,2010,2019), ytitle("`ytitle'") xtitle("Year")  legend(lab(1 "White") lab(2 "Pakistani") lab(3 "Bangladeshi")) || connected `x' intyear if raceb == 4 || connected `x' intyear if raceb == 5
	graph export "`x'_time_race_detail.pdf", replace
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

*---------------------------------EARNINGS TRENDS-------------------------------
capture program drop earn_trends
program define earn_trends

local a JK
cd "${path_`a'}\output"

**************************HEALTH******************************************
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(earn_dum health)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' earn_dum if health == 1, ytitle("`ytitle'") xlabel( 1 "0-500" 2 "500-1000" 3 "1000+") xtitle("Weekly Earnings (£)") legend(lab(1 "Health Condition") lab(2 "No Health Condition")) || connected `x' earn_dum if health == 2
	graph export "`x'_inc_health.pdf", replace
}
restore

*Find that those with a health condition are more likely to be in a pension and have higher contribution rates at every earnings category -- why?]

*Binscatter
preserve
keep if inrange(health,1,2)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	binscatter `x' lnrealearn, by(health) ytitle("`ytitle'") xtitle("Log Weekly Real Earnings (£)") legend(lab(1 "Health Condition") lab(2 "No Health Condition")) line(none) 
	graph export "`x'_inc_health_bin.pdf", replace
}
restore


*checking distribution of logged real earnings by health status
kdensity lnrealearn, nograph gen(c fc)
forvalues i=1/2{
	kdensity lnrealearn if health == `i', nograph gen(fc`i') at(c)
}
label var fc1 "Health Condition"
label var fc2 "No Health Condition"
line fc1 fc2 c if inrange(c,2,10), sort ytitle(Density) xtitle(ln(Real Earnings))
graph export "dens_inc_health.pdf", replace

****************************RACE*********************************************

*Binscatter
preserve
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	binscatter `x' real_earn if raceb != 10,  by(raceb) nquantiles(10) ytitle("`ytitle'") xtitle("Real Weekly Earnings (£)") legend(lab(1 "White") lab(2 "Mixed") lab(3 "Indian") lab(4 "Pakistani") lab(5 "Bangladeshi") lab(6 "Other Asian") lab(7 "Caribbean") lab(8 "African") lab(9 "Other")) line(connect)
	graph export "`x'_inc_race_bin.pdf", replace
}
restore

*Binscatter for key groups
preserve
keep if inlist(raceb,1,4,5)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	binscatter `x' real_earn,  by(raceb) nquantiles(10) ytitle("`ytitle'") xtitle("Real Weekly Earnings (£)") legend(lab(1 "White") lab(2 "Pakistani") lab(3 "Bangladeshi")) line(connect)
	graph export "`x'_inc_race_bin_detail.pdf", replace
}
restore



*distribution of earnings by race

kdensity real_earn, nograph gen(d fd)
forvalues i=1/9{
	kdensity real_earn if raceb == `i', nograph gen(fd`i') at(d)
}
label var fd1 "White"
label var fd2 "Mixed"
label var fd3 "Indian"
label var fd4 "Pakistani"
label var fd5 "Bangladeshi"
label var fd6 "Other Asian"
label var fd7 "Caribbean"
label var fd8 "African"
label var fd9 "Other"
line fd1 fd2 fd3 fd4 fd5 fd6 fd7 fd8 fd9 d if inrange(d,-200,2500), sort ytitle(Density) xtitle(Real Weekly Earnings)
graph export "dens_inc_race.pdf", replace


*NOTE: whiskers set to 1.5*Interquartile_range
graph hbox real_earn if raceb != 10, over(raceb) nooutsides ytitle("Real Weekly Earnings")
graph export "box_earn_race.pdf", replace

**************************EDUCATION***********************************************
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(earn_dum edgrpnew)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' earn_dum if edgrpnew == 0, ytitle("`ytitle'") xlabel( 1 "0-500" 2 "500-1000" 3 "1000+") xtitle("Weekly Earnings (£)") legend(lab(1 "None of the above") lab(2 "Less than GCSEs") lab(3 "GCSEs") lab(4 "A-levels") lab(5 "Vocational higher") lab(6 "University")) || connected `x' earn_dum if edgrpnew == 1 || connected `x' earn_dum if edgrpnew == 2 || connected `x' earn_dum if edgrpnew == 3 || connected `x' earn_dum if edgrpnew == 4 || connected `x' earn_dum if edgrpnew == 5   
	graph export "`x'_inc_edu.pdf", replace
}
restore

*Binscatter
preserve
keep if inrange(edgrpnew,0,5)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	binscatter `x' lnrealearn, by(edgrpnew) ytitle("`ytitle'") xtitle("Log Weekly Real Earnings (£)") legend(lab(1 "None of the above") lab(2 "Less than GCSEs") lab(3 "GCSEs") lab(4 "A-levels") lab(5 "Vocational higher") lab(6 "University")) line(none)
	graph export "`x'_inc_edu_bin.pdf", replace
}
restore


kdensity lnrealearn, nograph gen(f ff)
forvalues i=0/5{
	kdensity lnrealearn if edgrpnew == `i', nograph gen(ff`i') at(f)
}
label var ff0 "None of the above"
label var ff1 "Less than GCSEs"
label var ff2 "GCSEs"
label var ff3 "A-Levels"
label var ff4 "Vocational higher"
label var ff5 "University"
line ff0 ff1 ff2 ff3 ff4 ff5 f if inrange(f,2,10), sort ytitle(Density) xtitle(ln(Real Earnings))
graph export "dens_inc_edu.pdf", replace


*********************REGION****************************************************
preserve
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(earn_dum region)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' earn_dum if region == 1, ytitle("`ytitle'") xlabel( 1 "0-500" 2 "500-1000" 3 "1000+") xtitle("Weekly Earnings (£)") legend(lab(1 "North East") lab(2 "North West and Merseyside") lab(3 "Yorks and Humberside") lab(4 "East Midlands") lab(5 "West Midlands") lab(6 "Eastern") lab(7 "London") lab(8 "South East") lab(9 "South West") lab(10 "Wales") lab(11 "Scotland") lab(12 "Northern Ireland")) || connected `x' earn_dum if region == 2 || connected `x' earn_dum if region == 3 || connected `x' earn_dum if region == 4 || connected `x' earn_dum if region == 5 || connected `x' earn_dum if region == 6 || connected `x' earn_dum if region == 7 || connected `x' earn_dum if region == 8 || connected `x' earn_dum if region == 9 || connected `x' earn_dum if region == 10 || connected `x' earn_dum if region == 11 || connected `x' earn_dum if region == 12 
	graph export "`x'_inc_region.pdf", replace
}
restore

*binscatter
preserve
drop if region == .
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	binscatter `x' lnrealearn, by(region) ytitle("`ytitle'") xtitle("Log Weekly Real Earnings (£)") legend(lab(1 "North East") lab(2 "North West and Merseyside") lab(3 "Yorks and Humberside") lab(4 "East Midlands") lab(5 "West Midlands") lab(6 "Eastern") lab(7 "London") lab(8 "South East") lab(9 "South West") lab(10 "Wales") lab(11 "Scotland") lab(12 "Northern Ireland")) line(none)
	graph export "`x'_inc_region_bin.pdf", replace
}
restore


kdensity lnrealearn, nograph gen(e fe)
forvalues i=1/12{
	kdensity lnrealearn if region == `i', nograph gen(fe`i') at(e)
}
label var fe1 "North East"
label var fe2 "North West and Merseyside"
label var fe3 "Yorks and Humberside"
label var fe4 "East Midlands"
label var fe5 "West Midlands"
label var fe6 "Eastern"
label var fe7 "London"
label var fe8 "South East"
label var fe9 "South West"
label var fe10 "Wales"
label var fe11 "Scotland"
label var fe12 "Northern Ireland"
line fe1 fe2 fe3 fe4 fe5 fe6 fe7 fe8 fe9 fe10 fe11 fe12 e if inrange(e,2,10), sort ytitle(Density) xtitle(ln(Real Earnings))
graph export "dens_inc_region.pdf", replace
*lots of lines, maybe make graph of key regions with large differences e.g. London, Scotland 

end

*------------------------------OAXACA DECOMPOSITION-----------------------------
capture program drop oaxaca_decom
program define oaxaca_decom

*using two way decomp - pooled is suggested

local a JK
cd "${path_`a'}\output"

*------------------------HEALTH-------------------------------------------------
foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: oaxaca `x' age [pw=rxwgt] if inrange(health,1,2), by(health) pooled
	
	eststo: oaxaca `x' age agesq intyear lnrealearn [pw=rxwgt] if inrange(health,1,2), by(health) pooled 
	
	eststo: oaxaca age agesq intyear lnrealearn sector jbsize industry occupation [pw=rxwgt] if inrange(health,1,2), by(health) pooled 
	
	eststo: oaxaca `x' age agesq intyear lnrealearn sector jbsize industry occupation edgrpnew region female kidnum raceb  [pw=rxwgt] if inrange(health,1,2), by(health) pooled 
	
	eststo: oaxaca `x' age agesq intyear lnrealearn sector jbsize industry occupation edgrpnew region female kidnum raceb married partner_edu lnrealpartearn partner_sector [pw=rxwgt] if inrange(health,1,2), by(health) pooled 
	
	esttab using `x'_oax_health.tex, se replace booktabs nodepvars nomtitles coeflabels(group_1 "Health Condition" group_2 "No Health Condition" difference "Difference" explained "Explained" unexplained "Unexplained") drop(unexplained:* explained:*)
	eststo clear
}


*-----------------------EDUCATION-----------------------------------------------
/*
foreach x in ownperc ownperc_cond pen_mem {
	forvalues i=1/4{
		eststo: oaxaca `x' age [pw=rxwgt] if inlist(edgrpnew,`i',5), swap by(edgrpnew) pooled detail 
		esttab using `x'_`i'_oax_edu.tex, replace label
		eststo clear
	}
}
*/

end

*--------------------------------REGRESSION OUTPUT------------------------------
capture program drop regression_output
program define regression_output

local a JK
cd "${path_`a'}\output"

/*
Controls 1: age, age^2, year
Controls 2: earnings
Controls 3: job variables
Controls 4: other individual variables
Controls 5: partner variables
Controls 6: housing costs
*/
**********REGION**********************************
foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.region [pw=rxwgt]
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.region age agesq i.intyear [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.region age agesq i.intyear lnrealearn [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.region age agesq i.intyear lnrealearn i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.region age agesq i.intyear lnrealearn i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.raceb i.female i.health i.kidnum [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.region age agesq i.intyear lnrealearn i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.raceb i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.partner_sector [pw=rxwgt] 
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.region age agesq i.intyear lnrealearn i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.raceb i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.partner_sector housecost_win [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_reg_region.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.region) drop(1.region) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" " Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}

***********************RACE*********************************
/*foreach var of varlist raceb age agesq intyear lnrealearn sector jbsize industry occupation parttime edgrpnew  region female health kidnum married partner_edu lnrealpartearn partner_sector housecost_win ownperc ownperc_cond pen_mem{
	qui count if missing(`var') | `var' < 0
	di "`var': `r(N)'"
}
*/
*clustering standard errors in regression at individual level
foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector  [pw=rxwgt], vce(cluster pidp) 
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp) 
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum [pw=rxwgt], vce(cluster pidp)  
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_reg_race.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.raceb) drop(1.raceb 10.raceb) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" "Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}

******************EDUCATION************************************
*university degree is base 
foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' ib5.edgrpnew [pw=rxwgt]
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' ib5.edgrpnew age agesq i.intyear [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' ib5.edgrpnew age agesq i.intyear lnrealearn [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' ib5.edgrpnew age agesq i.intyear lnrealearn i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' ib5.edgrpnew age agesq i.intyear lnrealearn i.sector i.jbsize i.industry i.occupation i.parttime i.region i.female i.health i.kidnum i.raceb [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' ib5.edgrpnew age agesq i.intyear lnrealearn i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.region i.female i.health i.kidnum i.raceb i.married i.partner_edu lnrealpartearn i.partner_sector [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' ib5.edgrpnew age agesq i.intyear lnrealearn i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.region i.female i.health i.kidnum i.raceb i.married i.partner_edu lnrealpartearn i.partner_sector housecost_win [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_reg_edu.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.edgrpnew) drop(5.edgrpnew) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3"  "Controls 4" "Controls 5" "Controls 6" "Observations"))
	eststo clear
}

***************HEALTH********************************************
foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.health [pw=rxwgt] if health > 0 & jbsize > 0
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.health age agesq i.intyear [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.health age agesq i.intyear lnrealearn [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.health age agesq i.intyear lnrealearn i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.health age agesq i.intyear lnrealearn i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.region i.female i.kidnum i.raceb [pw=rxwgt] 
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.health age agesq i.intyear lnrealearn i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.region i.female i.kidnum i.raceb i.married i.partner_edu lnrealpartearn i.partner_sector [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.health age agesq i.intyear lnrealearn i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.region i.female i.kidnum i.raceb i.married i.partner_edu lnrealpartearn i.partner_sector housecost_win [pw=rxwgt]
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_reg_health.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.health) drop(1.health) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3"  "Controls 4" "Controls 5" "Controls 6" "Observations"))
	eststo clear
}

end
*-------------------------------PRE/POST AE-------------------------------------
*AE starts in Oct 2012, by Feb 2018 AE applied to all employers
capture program drop auto_enroll
program define auto_enroll

*Regression pre
preserve
keep if inlist(intyear,2010,2011,2012)

foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp)
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_preae_race.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.raceb) drop(1.raceb 10.raceb) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" "Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}
restore

*regression post
preserve
keep if inlist(intyear,2018,2019,2020)

foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector[pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt], vce(cluster pidp) 
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_postae_race.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.raceb) drop(1.raceb 10.raceb) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" "Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}
restore

*PLOTTING ESTIMATES OF MODEL WITH ALL CONTROLS
foreach x in ownperc ownperc_cond pen_mem{
	
	if "`x'" == "pen_mem" local ytitle "Membership"
	if "`x'" == "ownperc" local ytitle "Uncond. Cont."
	else if "`x'" == "ownperc_cond" local ytitle "Cond. Cont."
	
	qui reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt] if inlist(intyear,2010,2011,2012), vce(cluster pidp)
	estimates store pre
	qui reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt] if inlist(intyear,2018,2019,2020), vce(cluster pidp)
	estimates store post
	coefplot (pre, label(Pre AE)) (post, label(Post AE)), drop(_cons 1.raceb 10.raceb) xlabel(,angle(45)) ytitle("Point Estimate (`ytitle')") keep(*.raceb) yline(0) vertical
	graph export "`x'_coefplot_AE_race.pdf", replace
}



end
*------------------------------ETHNICITY/SEX------------------------------------
capture program drop ethn_sex
program define ethn_sex

*Male regression
preserve
keep if female == 0

foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.health i.kidnum [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_male_race.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.raceb) drop(1.raceb 10.raceb) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" "Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}
restore

*Female regression
preserve
keep if female == 1

foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.health i.kidnum [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_female_race.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.raceb) drop(1.raceb 10.raceb) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" "Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}
restore


foreach x in ownperc ownperc_cond pen_mem{
	
	if "`x'" == "pen_mem" local ytitle "Membership"
	if "`x'" == "ownperc" local ytitle "Uncond. Cont."
	else if "`x'" == "ownperc_cond" local ytitle "Cond. Cont."
	
	qui reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt] if female == 0, vce(cluster pidp)
	estimates store male
	qui reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt] if female == 1, vce(cluster pidp)
	estimates store female
	coefplot (male, label(Male)) (female, label(Female)), drop(_cons 1.raceb 10.raceb) xlabel(,angle(45)) ytitle("Point Estimate (`ytitle')") keep(*.raceb) yline(0) vertical
	graph export "`x'_coefplot_sex_race.pdf", replace
}

end

*-----------------------------ELIGIBLE EMPLOYEES ONLY---------------------------
capture program drop eligible_employ
program define eligible_employ

local a JK
cd "${path_`a'}\data"
use "usoc_clean.dta", clear
keep if inlist(jb1status, 1, 2)
drop if sector == 0
keep if annual_dum == 1 //only those affected by AE
local a JK
cd "${path_`a'}\output"

foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector [pw=rxwgt], vce(cluster pidp) 
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum [pw=rxwgt], vce(cluster pidp)  
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_reg_race_eligible.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.raceb) drop(1.raceb 10.raceb) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" "Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}


********************************************************************************

preserve
keep if inlist(intyear,2010,2011,2012)

foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp)
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt], vce(cluster pidp) 
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_eligible.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.raceb) drop(1.raceb 10.raceb) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" "Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}
restore

*regression post
preserve
keep if inlist(intyear,2018,2019,2020)

foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt], vce(cluster pidp) 
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_postae_race_eligible.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.raceb) drop(1.raceb 10.raceb) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" "Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}
restore

*PLOTTING ESTIMATES OF MODEL WITH ALL CONTROLS
foreach x in ownperc ownperc_cond pen_mem{
	
	if "`x'" == "pen_mem" local ytitle "Membership"
	if "`x'" == "ownperc" local ytitle "Uncond. Cont."
	else if "`x'" == "ownperc_cond" local ytitle "Cond. Cont."
	
	qui reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt] if inlist(intyear,2010,2011,2012), vce(cluster pidp)
	estimates store pre
	qui reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt] if inlist(intyear,2018,2019,2020), vce(cluster pidp)
	estimates store post
	coefplot (pre, label(Pre AE)) (post, label(Post AE)), drop(_cons 1.raceb 10.raceb) xlabel(,angle(45)) ytitle("Point Estimate (`ytitle')") keep(*.raceb) yline(0) vertical
	graph export "`x'_coefplot_AE_race_eligible.pdf", replace
}

preserve
drop if intyear == 2020
collapse (mean) ownperc ownperc_cond pen_mem [pw=rxwgt], by(intyear raceb)
foreach x in ownperc ownperc_cond pen_mem {
    
	if "`x'" == "pen_mem" local ytitle "Membership Rate (%)"
	if "`x'" == "ownperc" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "ownperc_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' intyear if raceb == 1 & inrange(intyear,2010,2019), ytitle("`ytitle'") xtitle("Year")  legend(lab(1 "White") lab(2 "Pakistani") lab(3 "Bangladeshi")) || connected `x' intyear if raceb == 4 || connected `x' intyear if raceb == 5
	graph export "`x'_time_race_detail_eligible.pdf", replace
}
restore


*****************Pre/post AE by sex*********************************************
******MEN**************
*pre
preserve
keep if female == 0
keep if inlist(intyear,2010,2011,2012)

foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt], vce(cluster pidp) 
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_preae_men_race.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.raceb) drop(1.raceb 10.raceb) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" "Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}
restore

*post
preserve
keep if female == 0
keep if inlist(intyear,2018,2019,2020)

foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt], vce(cluster pidp) 
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_postae_men_race.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.raceb) drop(1.raceb 10.raceb) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" "Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}
restore

******WOMEN**************
*pre
preserve
keep if female == 1
keep if inlist(intyear,2010,2011,2012)

foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt], vce(cluster pidp) 
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_preae_women_race.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.raceb) drop(1.raceb 10.raceb) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" "Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}
restore

*post
preserve
keep if female == 1
keep if inlist(intyear,2018,2019,2020)

foreach x in ownperc ownperc_cond pen_mem {
	
	eststo: reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "No"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "No"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "No"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "No"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "No"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "No"
	eststo: reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt], vce(cluster pidp) 
	estadd local cont_1 "Yes"
	estadd local cont_2 "Yes"
	estadd local cont_3 "Yes"
	estadd local cont_4 "Yes"
	estadd local cont_5 "Yes"
	estadd local cont_6 "Yes"
	esttab using `x'_postae_women_race.tex, star(* 0.10 ** 0.05 *** 0.01) se replace booktabs keep(*.raceb) drop(1.raceb 10.raceb) nomtitles label stat(cont_1 cont_2 cont_3 cont_4 cont_5 cont_6 N, label("Controls 1" "Controls 2" "Controls 3" "Controls 4" "Controls 5" "Controls 6" "Observations")) 
	eststo clear
}
restore


*PLOTTING COEFICIENT ESTIMATES FOR PRE/POST BY SEX
foreach x in ownperc ownperc_cond pen_mem{
	
	if "`x'" == "pen_mem" local ytitle "Membership"
	if "`x'" == "ownperc" local ytitle "Uncond. Cont."
	else if "`x'" == "ownperc_cond" local ytitle "Cond. Cont."
	
	qui reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt] if inlist(intyear,2010,2011,2012) & female == 0, vce(cluster pidp)
	estimates store pre_men
	qui reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt] if inlist(intyear,2018,2019,2020) & female == 0, vce(cluster pidp)
	estimates store post_men
	qui reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt] if inlist(intyear,2010,2011,2012) & female == 1, vce(cluster pidp)
	estimates store pre_women
	qui reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win [pw=rxwgt] if inlist(intyear,2018,2019,2020) & female == 1, vce(cluster pidp)
	estimates store post_women
	coefplot (pre_men, label(Pre AE)) (post_men, label(Post AE)) || (pre_women, label(Pre AE)) (post_women, label(Post AE)), drop(_cons 1.raceb 10.raceb) xlabel(,angle(45)) ytitle("Point Estimate (`ytitle')") keep(*.raceb) yline(0) vertical bylabels("Men" "Women")
	graph export "`x'_coefplot_AE_sex.pdf", replace
}


end