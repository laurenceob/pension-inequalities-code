/********************************************************************************
**** Title: 		analysis_usoc.do 
**** Author: 		Jack Kemp 
**** Date started: 	27/06/2022 
**** Description:	This do file produces output for pension inequalities project
********************************************************************************/

capture program drop main
program define main 

	start 
	
	sample_stat
	
	graph_over_time
	
	bar_restrict
	
	covariates_graphs
	
	regression_post
	
	by_sex
	
	self_employed
	

end


*-----------------------------------STARTUP-------------------------------------
capture program drop start
program define start

set scheme s1color //good looking graph theme

/*
PROGRAMMES INSTALLED
ssc install mylabels // installed for clean axis look
ssc install listtab //table output
ssc install outreg2 //table output
ssc install reghdfe //fixed effects regression
ssc install ftools //needed for reghdfe
ssc install oaxaca //oaxaca decomposition
ssc install binscatter //for scatter graphs
ssc install winsor //winsorize data
ssc install coefplot //coeficient plots of regression output
ssc install tsegen //for egen using time series variables
*/

*working directory set from master do file

use "$workingdata/usoc_clean.dta", clear

***Restricting sample to employed/self-employed
keep if inlist(jb1status, 1, 2) //drops those who are unemployed; 28,605 dropped

*making pension participation /100 
replace in_pension = in_pension*100 

end


*-----------------------------------SAMPLE STATS--------------------------------
capture program drop sample_stat
program define sample_stat

*Table for number in each ethnic group pre/post AE - checking sample size

preserve
*generating dummy variables for pre/post AE
gen preae = 0
replace preae = 1 if inlist(intyear, 2010, 2011, 2012)
gen postae = 0
replace postae = 1 if inlist(intyear, 2018, 2019, 2020)
*keeping only if pre/post AE, not during rollout
keep if preae == 1 | postae == 1
gen num = _n
*collapsing by the number of observations by race pre/post
collapse (count) num, by(postae raceb)
*reshaping so correct format for exporting
reshape wide num, i(postae) j(raceb)
*drop missing
drop num10
*exporting to excel
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("racecount_table") sheetreplace
restore

********************************************************************************
*Graphs of retirement expectations by ethnicity
*NOTE: only asked to a limited sample - those aged 45,50,55

preserve
*keeping sample for those asked the question
keep if inlist(age,45,50,55) & retneed >= 0 // takes value of -1 if missing
*collapsing by race - mean retirement income expectations (weighted)
collapse (mean) retneed [pw=rxwgt], by(raceb)
*for powerpoint
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("retirement_expectations") sheetreplace
*for latex
graph bar retneed if inrange(raceb,1,9), over(raceb, label(angle(45))) ytitle("Expected Adequate Retirement Income (%)")
graph export "$output/retneed_race.pdf", replace
restore

********************************************************************************

*share of different ethnicities in employment post AE
preserve 
*keep if post AE
keep if inrange(intyear,2018,2020)
*generating dummy variable for if employed or self-employed
gen employed = .
replace employed = 0 if sector == 0 
replace employed = 1 if sector == 1 | sector == 2
*collapsing by racae - mean self-employment rate (for workers)
collapse (mean) employed, by(raceb)
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("selfemploy_race") sheetreplace
restore
*Pakistani and Bangladeshi individuals more likely to be self-employed -- by roughly 5-7% points
********************************************************************************

*table: % of each religion by ethnic group e.g. x% of Whites are Christian
preserve
gen num = _n
*collapsing by the number of observations by ethnicity and religion
collapse (count) num, by(religion raceb)
reshape wide num, i(raceb) j(religion)
drop if inrange(raceb,9,10)
egen total = rowtotal(num*)
forvalues i = 0/7{
   replace num`i' = (num`i'/ total)*100 
}
drop total 
ren num0 No_religion
ren num1 Christian
ren num2 Muslim
ren num3 Hindu
ren num4 Jewish
ren num5 Sikh
ren num6 Other
ren num7 Missing
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("religion_eth") sheetreplace
restore

********************************************************************************

end 


*-----------------------------------OVER TIME-----------------------------------
capture program drop graph_over_time
program define graph_over_time

*pension vars over time by ethnicity - workers
preserve
drop if intyear == 2020 // limited sample size so noisy plot for 2020
*collapsing pension participation/contribution rates by year and race (weighted)
collapse (mean) in_pension pens_contr pens_contr_cond [pw=rxwgt], by(intyear raceb)
*dropping those with missing race value
drop if raceb == 10
*reshaping 
reshape wide in_pension pens_contr pens_contr_cond, i(intyear) j(raceb)
*exporting to excel
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_time") sheetreplace
*reshaping back
reshape long
*exporting to latex
foreach x in in_pension pens_contr pens_contr_cond {
    
	if "`x'" == "in_pension" local ytitle "Participation Rate (%)"
	if "`x'" == "pens_contr" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "pens_contr_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' intyear if raceb == 1, ytitle("`ytitle'") legend(lab(1 "White") lab(2 "Mixed") lab(3 "Indian") lab(4 "Pakistani") lab(5 "Bangladeshi") lab(6 "Other Asian") lab(7 "Caribbean") lab(8 "African") lab(9 "Other")) || connected `x' intyear if raceb == 2 || connected `x' intyear if raceb == 3 || connected `x' intyear if raceb == 4 || connected `x' intyear if raceb == 5 || connected `x' intyear if raceb == 6 || connected `x' intyear if raceb == 7 || connected `x' intyear if raceb == 8 || connected `x' intyear if raceb == 9
	graph export "$output/`x'_time_race.pdf", replace
}
restore

********************************************************************************
*pension vars over time by ethnicity - eligible for AE

preserve
*generating dummy for AE eligibility
gen eligible = 0 
replace eligible = 1 if annual_dum == 1 & inrange(sector,1,2) // eligible if employed (public (sector = 2) or private (sector = 1)) and earning more than 10k per year
*restricting sample to those offered a pension and eligible for AE 
drop if eligible == 0
drop if intyear == 2020
*collapsing pension participation/contribution rates by race/year (weighted)
collapse (mean) in_pension pens_contr pens_contr_cond [pw=rxwgt], by(intyear raceb)
*dropping those with missing race value
drop if raceb == 10 
*reshaping so correct for exporting to excel
reshape wide in_pension pens_contr pens_contr_cond, i(intyear) j(raceb)
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_time_eli") sheetreplace
restore

********************************************************************************
*pension vars over time by ethnicity - eligible + offered pension

preserve
*generating dummy for AE eligibility
gen eligible = 0 
replace eligible = 1 if annual_dum == 1 & inrange(sector,1,2)
*restricting sample to those offered a pension and eligible for AE 
drop if eligible == 0 
keep if jbpen == 1 // jbpen = 1 if report being offered a pension
drop if intyear == 2020
*collapsing pension participation/contribution rates by race/year (weighted)
collapse (mean) in_pension pens_contr pens_contr_cond [pw=rxwgt], by(intyear raceb)
drop if raceb == 10
*reshaping
reshape wide in_pension pens_contr pens_contr_cond, i(intyear) j(raceb)
*exporting to excel
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_time_elioff") sheetreplace
restore
********************************************************************************

end


*-----------------------------------RESTRICT SAMPLE-----------------------------
capture program drop bar_restrict
program define bar_restrict

*Bar chart data for non-restricted, eligible, eligible+offer pension participation by ethnicity

*generating dummy variables for if sample is workers, only those eligible for AE, or only those eligible+offered a pension
gen unrestrict = 1
replace jbpen = jbpen*100 // so /100
gen eligible = 0 
replace eligible = 1 if annual_dum == 1 & inrange(sector,1,2) 
gen elioffer = 0
replace elioffer = 1 if jbpen == 100 & eligible == 1
*generating dummy variable for if post AE
gen postae = 0
replace postae = 1 if inlist(intyear, 2018, 2019, 2020)
keep if postae == 1

*for each sample, generate a temporary file and collapse pension participation by race (weighted)
foreach i in unrestrict eligible elioffer {
    preserve
	tempfile `i'
	keep if `i' == 1
	collapse (mean) in_pension [pw=rxwgt], by(raceb)
	drop if raceb == 10 
	ren in_pension `i'
	save ``i''
	restore
}
*merging mean pension participation by race for different samples into one dataset
use `unrestrict', clear
merge 1:1 raceb using `eligible'
drop _merge
merge 1:1 raceb using `elioffer' 
drop _merge
*exporting to excel
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_restrict") sheetreplace

*reload data
use "$workingdata/usoc_clean.dta", clear
keep if inlist(jb1status, 1, 2) //drops those who are unemployed; 28,605 dropped
replace in_pension = in_pension*100 

********************************************************************************
*Table/graph for % eligible by ethnicity for workers
preserve
*generating dummy for AE eligibility
gen eligible = 0 
replace eligible = 100 if annual_dum == 1 & inrange(sector,1,2)
*generating dummy for pre/post AE
gen preae = 0
replace preae = 1 if inlist(intyear, 2010, 2011, 2012)
gen postae = 0
replace postae = 1 if inlist(intyear, 2018, 2019, 2020)
*keeping if pre/post AE, not during
keep if preae ==1 | postae ==1
*collapsing eligibility by race and pre/post AE (weighted)
collapse (mean) eligible [pw=rxwgt], by(raceb postae)
*dropping if missing race value
drop if raceb == 10
*reshaping
reshape wide eligible, i(raceb) j(postae)
ren eligible0 Pre
ren eligible1 Post
*exporting to excel
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_eli") sheetreplace
restore

********************************************************************************
*Table/graph for % offered pension by ethnicity for eligible employees
preserve
replace jbpen = jbpen*100 //so if report being offered a pension is /100
*generating dummy if eligible for AE
gen eligible = 0 
replace eligible = 100 if annual_dum == 1 & inrange(sector,1,2)
*generating dummy for pre/post AE
gen preae = 0
replace preae = 1 if inlist(intyear, 2010, 2011, 2012)
gen postae = 0
replace postae = 1 if inlist(intyear, 2018, 2019, 2020)
*keeping if pre/post AE
keep if preae ==1 | postae ==1
*collapsing if report offered a pension by race and pre/post AE
collapse (mean) jbpen [pw=rxwgt], by(eligible raceb postae)
*only for those eligible for AE, dropping those missing race value
drop if raceb == 10 | eligible == 0
drop eligible
*reshaping
reshape wide jbpen, i(raceb) j(postae)
ren jbpen0 Pre
ren jbpen1 Post
*exporting to excel
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_offer_eli") sheetreplace
restore
********************************************************************************

*CHECK - restricting to public sector only
*unlikely to be non-compliance so tells us likely extent of measurement error in reporting being offered a pension

*Table/graph for % offered pension by ethnicity for eligible public sector employees
preserve
replace jbpen = jbpen*100 //so if report being offered a pension is /100
*generating dummy if eligible for AE
gen eligible = 0 
replace eligible = 100 if annual_dum == 1 & inrange(sector,1,2)
*generating dummy for pre/post AE
gen preae = 0
replace preae = 1 if inlist(intyear, 2010, 2011, 2012)
gen postae = 0
replace postae = 1 if inlist(intyear, 2018, 2019, 2020)
*keeping if pre/post AE
keep if preae ==1 | postae ==1
*keeping if public sector
keep if sector == 2
*collapsing if report offered a pension by race and pre/post AE
collapse (mean) jbpen [pw=rxwgt], by(eligible raceb postae)
*only for those eligible for AE, dropping those missing race value
drop if raceb == 10 | eligible == 0
drop eligible
*reshaping
reshape wide jbpen, i(raceb) j(postae)
ren jbpen0 Pre
ren jbpen1 Post
*exporting to excel
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("offer_check") sheetreplace
restore

*find that it is mostly firm non-compliance, not measurement error

********************************************************************************
*graph to show extent of non-compliance by firm size
*% offered pension by firm size for eligible private sector employees
preserve
replace jbpen = jbpen*100 //so if report being offered a pension is /100
*generating dummy if eligible for AE
gen eligible = 0 
replace eligible = 100 if annual_dum == 1 & inrange(sector,1,2)
*generating dummy for pre/post AE
gen preae = 0
replace preae = 1 if inlist(intyear, 2010, 2011, 2012)
gen postae = 0
replace postae = 1 if inlist(intyear, 2018, 2019, 2020)
*keeping if pre/post AE
keep if preae ==1 | postae ==1
*keeping if private sector
keep if sector == 1
*collapsing if report offered a pension by firm size and pre/post AE
collapse (mean) jbpen [pw=rxwgt], by(eligible jbsize postae)
*only for those eligible for AE, dropping those missing race value
drop if inlist(jbsize,0,10,11) | eligible == 0
drop eligible
*reshaping
reshape wide jbpen, i(jbsize) j(postae)
ren jbpen0 Pre
ren jbpen1 Post
*exporting to excel
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("offer_jbsize") sheetreplace
restore

*bar chart showing % of each ethnicity in a small firm [1-9 employees] (sizes with greatest non-compliance)
preserve
*generating dummy if in small firm
gen small = .
replace small = 0 if inrange(jbsize,3,9)
replace small = 100 if inrange(jbsize,1,2)
*generating dummy if eligible for AE
gen eligible = 0 
replace eligible = 100 if annual_dum == 1 & inrange(sector,1,2)
*generating dummy for post AE
gen postae = 0
replace postae = 1 if inlist(intyear, 2018, 2019, 2020)
*keeping if post AE
keep if postae ==1
*keeping if private sector
keep if sector == 1
drop if eligible == 0
*collapsing if report offered a pension by firm size and pre/post AE
collapse (mean) small [pw=rxwgt], by(raceb)
*exporting to excel
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("jbsize_eth") sheetreplace
restore


********************************************************************************



end


*-----------------------------------COVARIATES GRAPHS---------------------------
capture program drop covariates_graphs
program define covariates_graphs


*Distribution of age by ethnic group
preserve
*overall age distribution 
kdensity age, nograph gen(x fx) // x stores the estimation points and fx stores the density estimates - x needed for separate estimation by ethnicity
 
*estimating age distribution by ethnicity
*at(x) specifies a variable that contains the values at which the density should be estimated. This option allows you to more easily obtain density estimates for different variables or different subsamples of a variable and then overlay the estimated densities for comparison.

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
keep fx1 fx2 fx3 fx4 fx5 fx6 fx7 fx8 fx9 x
*for powerpoint
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("age_dist") sheetreplace
*for latex
line fx1 fx2 fx3 fx4 fx5 fx6 fx7 fx8 fx9 x, sort ytitle(Density)
graph export "$output/dens_age_race.pdf", replace
restore

********************************************************************************

*Pension vars by age scatter + line of best fit (added in powerpoint)
preserve
collapse (mean) in_pension pens_contr pens_contr_cond [pw=rxwgt], by(age)
*for powerpoint
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_age") sheetreplace
*for latex
foreach x in in_pension pens_contr pens_contr_cond {
    
	if "`x'" == "in_pension" local ytitle "Participation Rate (%)"
		local lab "Membership"
	if "`x'" == "pens_contr" local ytitle "Unconditional Contribution Rate (%)"
		local lab "Cont. Rate"
	else if "`x'" == "pens_contr_cond" local ytitle "Conditional Contribution Rate (%)"
		local lab "Cont. Rate"

	twoway scatter `x' age, ytitle("`ytitle'") legend(lab(1 "`lab'")) || lfit `x' age 
	graph export "$output/`x'_age.pdf", replace
}
restore

********************************************************************************
*Scatter of pen vars by ethnicity and age - looking within each age group for differences in pen vars by ethnicity
preserve
collapse (mean) in_pension pens_contr pens_contr_cond [pw=rxwgt], by(age_dum raceb)
*for powerpoint
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_age_eth") sheetreplace
*for latex
foreach x in in_pension pens_contr pens_contr_cond {
    
	if "`x'" == "in_pension" local ytitle "Participation Rate (%)"
	if "`x'" == "pens_contr" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "pens_contr_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' age_dum if raceb == 1, ytitle("`ytitle'") xlabel(0 "22-25" 1 "26-29" 2 "30-33" 3 "34-37" 4 "38-41" 5 "42-45" 6 "46-49" 7 "50-53" 8 "54-57" 9 "58-59", angle(45)) xtitle("Age Group") legend(lab(1 "White") lab(2 "Mixed") lab(3 "Indian") lab(4 "Pakistani") lab(5 "Bangladeshi") lab(6 "Other Asian") lab(7 "Caribbean") lab(8 "African") lab(9 "Other")) || connected `x' age_dum if raceb == 2 || connected `x' age_dum if raceb == 3 || connected `x' age_dum if raceb == 4 || connected `x' age_dum if raceb == 5 || connected `x' age_dum if raceb == 6 || connected `x' age_dum if raceb == 7 || connected `x' age_dum if raceb == 8 || connected `x' age_dum if raceb == 9 
	graph export "$output/`x'_age_race.pdf", replace
}
restore

********************************************************************************
*earnings distribution by ethnicity

preserve
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
keep fd1 fd2 fd3 fd4 fd5 fd6 fd7 fd8 fd9 d
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("earn_dist") sheetreplace
line fd1 fd2 fd3 fd4 fd5 fd6 fd7 fd8 fd9 d if inrange(d,-200,2500), sort ytitle(Density) xtitle(Real Weekly Earnings)
graph export "$output/dens_inc_race.pdf", replace
restore
********************************************************************************

end


*-----------------------------------POST AE REG---------------------------------
capture program drop regression_post
program define regression_post

*regression results post AE for eligible employees offered a pension (restricted sample)
*Note: AE starts in Oct 2012, by Feb 2018 AE applied to all employers

local age_vars "age agesq i.intyear"
local earn_vars "lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector"
local job_vars "i.sector i.jbsize i.industry i.occupation i.parttime"
local indiv_vars "i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.havekid1 i.havekid2 i.havekid3 i.havekid4"
local partner_vars "i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector"
local other_vars "housecost_win i.tenure_broad i.bornuk"

local drp_rce "2.raceb 3.raceb 4.raceb 5.raceb 6.raceb 7.raceb 8.raceb 9.raceb"


preserve
*keeping if post AE
keep if inlist(intyear,2018,2019,2020)
*eligible for AE
drop if sector == 0 // employed
keep if annual_dum == 1 // earnings threshold
*offered a pension
keep if jbpen == 1 

foreach x in in_pension pens_contr pens_contr_cond {
	
	*column 1 - raw difference
	reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, replace label keep(`drp_rce') 
	
	*column 2 - age controls
	reg `x' i.raceb `age_vars' [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, append label keep(`drp_rce')
	
	*column 3 - earning controls
	reg `x' i.raceb `age_vars' `earn_vars' [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, append label keep(`drp_rce')
	
	*column 4 - job variables
	reg `x' i.raceb `age_vars' `earn_vars' `job_vars' [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, append label keep(`drp_rce')
	
	*column 5 - individual variables
	reg `x' i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, append label keep(`drp_rce')
	
	*column 6 - partner variables
	reg `x' i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' `partner_vars' [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, append label keep(`drp_rce')
	
	*column 7 - all controls
	reg `x' i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' `partner_vars' `other_vars' [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, append label keep(`drp_rce')
}
restore
*NOTE: regression tables outputted to different excel sheet to powerpoint_data


********************************************************************************
*pension participation - adding in new controls
preserve
*keeping if post AE
keep if inlist(intyear,2018,2019,2020)
*eligible for AE
drop if sector == 0 // employed
keep if annual_dum == 1 // earnings threshold
*offered a pension
keep if jbpen == 1 

*column 1 - corresponds to column 7 in past regressions - all old controls
reg in_pension i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' `partner_vars' `other_vars' [pw=rxwgt], vce(cluster pidp)
outreg2 using $output/new_post_reg.xls, replace label keep(`drp_rce') 

*column 2 - long run earnings and earnings volatility
reg in_pension i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' `partner_vars' `other_vars' avg_earn5 i.missing_avgearn coefvar i.missing_coefvar [pw=rxwgt], vce(cluster pidp)
outreg2 using $output/new_post_reg.xls, append label keep(`drp_rce')

*column 3 - religion
reg in_pension i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' `partner_vars' `other_vars' avg_earn5 coefvar i.religion [pw=rxwgt], vce(cluster pidp)
outreg2 using $output/new_post_reg.xls, append label keep(`drp_rce')

restore


end


*-----------------------------------BY SEX--------------------------------------
capture program drop by_sex
program define by_sex

*gender gap in pension participation post AE for whites
preserve
*keeping whites only
keep if raceb == 1
*keeping if post AE
keep if inrange(intyear,2018,2020)
collapse (mean) in_pension, by (female)
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("sex_pension") sheetreplace
restore
*Women: 79.4%
*Men: 78.5%


********************************************************************************
*regression results by sex and ethnicity - coeficient plot pre/post AE
*separate regressions for men/women

local age_vars "age agesq i.intyear"
local earn_vars "lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector"
local job_vars "i.sector i.jbsize i.industry i.occupation i.parttime"
local indiv_vars "i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.havekid1 i.havekid2 i.havekid3 i.havekid4"
local partner_vars "i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector"
local other_vars "housecost_win i.tenure_broad i.bornuk avg_earn5 coefvar"

local drp_rce "2.raceb 3.raceb 4.raceb 5.raceb 6.raceb 7.raceb 8.raceb 9.raceb"

*MEN
foreach var of varlist in_pension pens_contr {

	preserve
	drop if sector == 0 //not including self-employed
	keep if annual_dum == 1 //earning above 10k
	keep if jbpen == 1 // only those offered a pension
    * Do regression (pre)
    reg `var' i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' `partner_vars' `other_vars' if inrange(intyear,2010,2012) & female == 0 [pw=rxwgt], vce(cluster pidp)
    
    * Save coefficients and standard errors 
    gen b_mixed_pre = _b[2.raceb]
    gen err_mixed_pre = 1.96 * _se[2.raceb]
	
	gen b_indian_pre = _b[3.raceb]
    gen err_indian_pre = 1.96 * _se[3.raceb]
	
	gen b_pakistani_pre = _b[4.raceb]
    gen err_pakistani_pre = 1.96 * _se[4.raceb]
	
	gen b_bangladeshi_pre = _b[5.raceb]
    gen err_bangladeshi_pre = 1.96 * _se[5.raceb]
	
	gen b_other_asian_pre = _b[6.raceb]
    gen err_other_asian_pre = 1.96 * _se[6.raceb]
	
	gen b_caribbean_pre = _b[7.raceb]
    gen err_caribbean_pre = 1.96 * _se[7.raceb]
	
	gen b_african_pre = _b[8.raceb]
    gen err_african_pre = 1.96 * _se[8.raceb]
	
	gen b_other_pre = _b[9.raceb]
    gen err_other_pre = 1.96 * _se[9.raceb]

	
   * Do regression (post)
     reg `var' i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' `partner_vars' `other_vars' if inrange(intyear,2018,2020) & female == 0 [pw=rxwgt], vce(cluster pidp)
    
    * Save coefficients and standard errors 
    gen b_mixed_post = _b[2.raceb]
    gen err_mixed_post = 1.96 * _se[2.raceb]
	
	gen b_indian_post = _b[3.raceb]
    gen err_indian_post = 1.96 * _se[3.raceb]
	
	gen b_pakistani_post = _b[4.raceb]
    gen err_pakistani_post = 1.96 * _se[4.raceb]
	
	gen b_bangladeshi_post = _b[5.raceb]
    gen err_bangladeshi_post = 1.96 * _se[5.raceb]
	
	gen b_other_asian_post = _b[6.raceb]
    gen err_other_asian_post = 1.96 * _se[6.raceb]
	
	gen b_caribbean_post = _b[7.raceb]
    gen err_caribbean_post = 1.96 * _se[7.raceb]
	
	gen b_african_post = _b[8.raceb]
    gen err_african_post = 1.96 * _se[8.raceb]
	
	gen b_other_post = _b[9.raceb]
    gen err_other_post = 1.96 * _se[9.raceb]
	
    
    local obs_`var' = e(N)
    
    * Just keep relevant bits
    keep b_* err_*
    duplicates drop
    
    * Reshape
    gen n = 1
    reshape long b_ err_, i(n) j(race_ae) string
    
    * Tidy up
    drop n
    ren *_ *
	
	*sorting 
	gen sorter = 1 if race_ae == "mixed_pre"
	replace sorter = 2 if race_ae == "mixed_post"
	replace sorter = 3 if race_ae == "indian_pre"
	replace sorter = 4 if race_ae == "indian_post"
	replace sorter = 5 if race_ae == "pakistani_pre"
	replace sorter = 6 if race_ae == "pakistani_post"
	replace sorter = 7 if race_ae == "bangladeshi_pre"
	replace sorter = 8 if race_ae == "bangladeshi_post"
	replace sorter = 9 if race_ae == "other_asian_pre"
	replace sorter = 10 if race_ae == "other_asian_post"
	replace sorter = 11 if race_ae == "caribbean_pre"
	replace sorter = 12 if race_ae == "caribbean_post"
	replace sorter = 13 if race_ae == "african_pre"
	replace sorter = 14 if race_ae == "african_post"
	replace sorter = 15 if race_ae == "other_pre"
	replace sorter = 16 if race_ae == "other_post"
	sort sorter
	drop sorter
	
    *Export 
	*Have to keep sheetname short otherwise won't work
    export excel using "$output/powerpoint_data.xlsx", sheet("`var'_coef_eli_men", replace) first(var)
    restore
}

********************************************************************************
*WOMEN
foreach var of varlist in_pension pens_contr {

	preserve
	drop if sector == 0 // dropping self-employed
	keep if annual_dum == 1 //earning above 10k
	keep if jbpen == 1 // only those offered a pension
    * Do regression (pre)
    reg `var' i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' `partner_vars' `other_vars' if inrange(intyear,2010,2012) & female == 1 [pw=rxwgt], vce(cluster pidp)
    
    * Save coefficients and standard errors 
    gen b_mixed_pre = _b[2.raceb]
    gen err_mixed_pre = 1.96 * _se[2.raceb]
	
	gen b_indian_pre = _b[3.raceb]
    gen err_indian_pre = 1.96 * _se[3.raceb]
	
	gen b_pakistani_pre = _b[4.raceb]
    gen err_pakistani_pre = 1.96 * _se[4.raceb]
	
	gen b_bangladeshi_pre = _b[5.raceb]
    gen err_bangladeshi_pre = 1.96 * _se[5.raceb]
	
	gen b_other_asian_pre = _b[6.raceb]
    gen err_other_asian_pre = 1.96 * _se[6.raceb]
	
	gen b_caribbean_pre = _b[7.raceb]
    gen err_caribbean_pre = 1.96 * _se[7.raceb]
	
	gen b_african_pre = _b[8.raceb]
    gen err_african_pre = 1.96 * _se[8.raceb]
	
	gen b_other_pre = _b[9.raceb]
    gen err_other_pre = 1.96 * _se[9.raceb]

	
   * Do regression (post)
     reg `var' i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' `partner_vars' `other_vars' if inrange(intyear,2018,2020) & female == 1 [pw=rxwgt], vce(cluster pidp)
    
    * Save coefficients and standard errors 
    gen b_mixed_post = _b[2.raceb]
    gen err_mixed_post = 1.96 * _se[2.raceb]
	
	gen b_indian_post = _b[3.raceb]
    gen err_indian_post = 1.96 * _se[3.raceb]
	
	gen b_pakistani_post = _b[4.raceb]
    gen err_pakistani_post = 1.96 * _se[4.raceb]
	
	gen b_bangladeshi_post = _b[5.raceb]
    gen err_bangladeshi_post = 1.96 * _se[5.raceb]
	
	gen b_other_asian_post = _b[6.raceb]
    gen err_other_asian_post = 1.96 * _se[6.raceb]
	
	gen b_caribbean_post = _b[7.raceb]
    gen err_caribbean_post = 1.96 * _se[7.raceb]
	
	gen b_african_post = _b[8.raceb]
    gen err_african_post = 1.96 * _se[8.raceb]
	
	gen b_other_post = _b[9.raceb]
    gen err_other_post = 1.96 * _se[9.raceb]
	
    
    local obs_`var' = e(N)
    
    * Just keep relevant bits
    keep b_* err_*
    duplicates drop
    
    * Reshape
    gen n = 1
    reshape long b_ err_, i(n) j(race_ae) string
    
    * Tidy up
    drop n
    ren *_ *
	
	*sorting 
	gen sorter = 1 if race_ae == "mixed_pre"
	replace sorter = 2 if race_ae == "mixed_post"
	replace sorter = 3 if race_ae == "indian_pre"
	replace sorter = 4 if race_ae == "indian_post"
	replace sorter = 5 if race_ae == "pakistani_pre"
	replace sorter = 6 if race_ae == "pakistani_post"
	replace sorter = 7 if race_ae == "bangladeshi_pre"
	replace sorter = 8 if race_ae == "bangladeshi_post"
	replace sorter = 9 if race_ae == "other_asian_pre"
	replace sorter = 10 if race_ae == "other_asian_post"
	replace sorter = 11 if race_ae == "caribbean_pre"
	replace sorter = 12 if race_ae == "caribbean_post"
	replace sorter = 13 if race_ae == "african_pre"
	replace sorter = 14 if race_ae == "african_post"
	replace sorter = 15 if race_ae == "other_pre"
	replace sorter = 16 if race_ae == "other_post"
	sort sorter
	drop sorter
	
    * Export 
    export excel using "$output/powerpoint_data.xlsx", sheet("`var'_coef_eli_wo", replace) first(var)
    restore
}

end


*-----------------------------------SELF EMPLOYED-------------------------------
capture program drop self_employed
program define self_employed

local age_vars "age agesq i.intyear"
local earn_vars "lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector"
local job_vars "i.sector i.jbsize i.industry i.occupation i.parttime"
local indiv_vars "i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.havekid1 i.havekid2 i.havekid3 i.havekid4"
local partner_vars "i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector"
local other_vars "housecost_win i.tenure_broad i.bornuk avg_earn5 coefvar"

local drp_rce "2.raceb 3.raceb 4.raceb 5.raceb 6.raceb 7.raceb 8.raceb 9.raceb"

*regression of pension participation (pooled) on ethnicity - which covariates are important?
preserve
*keeping self employed
keep if sector == 0 

*column 1 - raw difference
reg in_pension i.raceb [pw=rxwgt], vce(cluster pidp)
outreg2 using $output/self_reg.xls, replace label keep(`drp_rce') 

*column 2 - age variables
reg in_pension i.raceb `age_vars' [pw=rxwgt], vce(cluster pidp)
outreg2 using $output/self_reg.xls, append label keep(`drp_rce')

*column 3 - earnings variables
reg in_pension i.raceb `age_vars' `earn_vars' [pw=rxwgt], vce(cluster pidp)
outreg2 using $output/self_reg.xls, append label keep(`drp_rce')

*column 4 - job variables
reg in_pension i.raceb `age_vars' `earn_vars' `job_vars' [pw=rxwgt], vce(cluster pidp)
outreg2 using $output/self_reg.xls, append label keep(`drp_rce')

*column 5 - individual variables
reg in_pension i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' [pw=rxwgt], vce(cluster pidp)
outreg2 using $output/self_reg.xls, append label keep(`drp_rce')

*column 6 - partner variables
reg in_pension i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' `partner_vars' [pw=rxwgt], vce(cluster pidp)
outreg2 using $output/self_reg.xls, append label keep(`drp_rce')

*column 7 - all controls
reg in_pension i.raceb `age_vars' `earn_vars' `job_vars' `indiv_vars' `partner_vars' `other_vars' [pw=rxwgt], vce(cluster pidp)
outreg2 using $output/self_reg.xls, append label keep(`drp_rce')


*collapsing pension participation by year and race (weighted)
collapse (mean) in_pension [pw=rxwgt], by(raceb)
*dropping those with missing race value
drop if raceb == 10
*exporting to excel
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_self") sheetreplace

restore

end




