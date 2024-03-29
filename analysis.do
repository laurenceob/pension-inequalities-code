/********************************************************************************
**** Title: 		analysis.do 
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
ssc install coefplot
*/

*working directory set from master do file

use "$workingdata/usoc_clean.dta", clear
***Restricting sample to employed/self-employed
keep if inlist(jb1status, 1, 2) //drops those who are unemployed; 28,605 dropped
replace in_pension = in_pension*100 

end

capture program drop sample_stat
program define sample_stat

*Table for number in each ethnic group pre/post AE
preserve
gen preae = 0
replace preae = 1 if inlist(intyear, 2010, 2011, 2012)
gen postae = 0
replace postae = 1 if inlist(intyear, 2018, 2019, 2020)
keep if preae ==1 | postae ==1
gen num = _n
collapse (count) num, by(postae raceb)
reshape wide num, i(postae) j(raceb)
drop num10
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("racecount_table") sheetreplace
restore

*Graphs of retirement expectations by race 
preserve
keep if retneed >= 0
collapse (mean) retneed [pw=rxwgt], by(raceb)
*for powerpoint
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("retirement_expectations") sheetreplace
*for latex
graph bar retneed if inrange(raceb,1,9), over(raceb, label(angle(45))) ytitle("Expected Adequate Retirement Income (%)")
graph export "$output/retneed_race.pdf", replace
restore

*share of different ethnicities in employment post AE
preserve 
keep if inrange(intyear,2018,2020)
gen employed = .
replace employed = 0 if sector == 0 
replace employed = 1 if sector == 1 | sector == 2
collapse (mean) employed, by(raceb)
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("selfemploy_race") sheetreplace
restore
*Pakistani and Bangladeshi individuals more likely to be self-employed -- by roughly 5-7% points

end 

capture program drop graph_over_time
program define graph_over_time

*PENSION VARS OVER TIME BY ETHNICITY
preserve
drop if intyear == 2020
collapse (mean) in_pension pens_contr pens_contr_cond [pw=rxwgt], by(intyear raceb)
drop if raceb == 10
reshape wide in_pension pens_contr pens_contr_cond, i(intyear) j(raceb)
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_time") sheetreplace
reshape long
foreach x in in_pension pens_contr pens_contr_cond {
    
	if "`x'" == "in_pension" local ytitle "Participation Rate (%)"
	if "`x'" == "pens_contr" local ytitle "Unconditional Contribution Rate (%)"
	else if "`x'" == "pens_contr_cond" local ytitle "Conditional Contribution Rate (%)"
	
	twoway connected `x' intyear if raceb == 1, ytitle("`ytitle'") legend(lab(1 "White") lab(2 "Mixed") lab(3 "Indian") lab(4 "Pakistani") lab(5 "Bangladeshi") lab(6 "Other Asian") lab(7 "Caribbean") lab(8 "African") lab(9 "Other")) || connected `x' intyear if raceb == 2 || connected `x' intyear if raceb == 3 || connected `x' intyear if raceb == 4 || connected `x' intyear if raceb == 5 || connected `x' intyear if raceb == 6 || connected `x' intyear if raceb == 7 || connected `x' intyear if raceb == 8 || connected `x' intyear if raceb == 9
	graph export "$output/`x'_time_race.pdf", replace
}
restore

********************************************************************************
*PENSION VARS OVER TIME BY ETHNICITY - eligible only!!
preserve
gen eligible = 0 
replace eligible = 1 if annual_dum == 1 & inrange(sector,1,2)
*restricting sample to those offered a pension and eligible for AE 
drop if eligible == 0
drop if intyear == 2020
collapse (mean) in_pension pens_contr pens_contr_cond [pw=rxwgt], by(intyear raceb)
drop if raceb == 10
reshape wide in_pension pens_contr pens_contr_cond, i(intyear) j(raceb)
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_time_eli") sheetreplace
restore

********************************************************************************
*PENSION VARS OVER TIME BY ETHNICITY - eligible +offered pension only!!
preserve
gen eligible = 0 
replace eligible = 1 if annual_dum == 1 & inrange(sector,1,2)
*restricting sample to those offered a pension and eligible for AE 
drop if eligible == 0 
keep if jbpen == 1
drop if intyear == 2020
collapse (mean) in_pension pens_contr pens_contr_cond [pw=rxwgt], by(intyear raceb)
drop if raceb == 10
reshape wide in_pension pens_contr pens_contr_cond, i(intyear) j(raceb)
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_time_elioff") sheetreplace
restore

end

capture program drop bar_restrict
program define bar_restrict

*Bar chart data for non-restricted, eligible, eligible+offer pension participation by ethnicity
gen unrestrict = 1
replace jbpen = jbpen*100
gen eligible = 0 
replace eligible = 1 if annual_dum == 1 & inrange(sector,1,2) 
gen elioffer = 0
replace elioffer = 1 if jbpen == 100 & eligible == 1
gen postae = 0
replace postae = 1 if inlist(intyear, 2018, 2019, 2020)
keep if postae == 1

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
use `unrestrict', clear
merge 1:1 raceb using `eligible'
drop _merge
merge 1:1 raceb using `elioffer' 
drop _merge
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_restrict") sheetreplace

use "$workingdata/usoc_clean.dta", clear
keep if inlist(jb1status, 1, 2) //drops those who are unemployed; 28,605 dropped
replace in_pension = in_pension*100 


*Table/graph for %offered by race for eligible employees
preserve
replace jbpen = jbpen*100
gen eligible = 0 
replace eligible = 100 if annual_dum == 1 & inrange(sector,1,2)
gen preae = 0
replace preae = 1 if inlist(intyear, 2010, 2011, 2012)
gen postae = 0
replace postae = 1 if inlist(intyear, 2018, 2019, 2020)
keep if preae ==1 | postae ==1
collapse (mean) jbpen [pw=rxwgt], by(eligible raceb postae)
drop if raceb == 10 | eligible == 0
drop eligible
reshape wide jbpen, i(raceb) j(postae)
ren jbpen0 Pre
ren jbpen1 Post
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_offer_eli") sheetreplace
restore

********************************************************************************
*Table/graph for %eligible by race
preserve
gen eligible = 0 
replace eligible = 100 if annual_dum == 1 & inrange(sector,1,2)
gen preae = 0
replace preae = 1 if inlist(intyear, 2010, 2011, 2012)
gen postae = 0
replace postae = 1 if inlist(intyear, 2018, 2019, 2020)
keep if preae ==1 | postae ==1
collapse (mean) eligible [pw=rxwgt], by(raceb postae)
drop if raceb == 10
reshape wide eligible, i(raceb) j(postae)
ren eligible0 Pre
ren eligible1 Post
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_eli") sheetreplace
restore

********************************************************************************
*restricting sample to those offered a pension and eligible for AE
preserve
replace jbpen = jbpen*100
gen eligible = 0 
replace eligible = 100 if annual_dum == 1 & inrange(sector,1,2)
*restricting sample to those offered a pension and eligible for AE 
drop if eligible == 0 | jbpen == 0 //59,762 obs
gen preae = 0
replace preae = 1 if inlist(intyear, 2010, 2011, 2012)
gen postae = 0
replace postae = 1 if inlist(intyear, 2018, 2019, 2020)
keep if preae ==1 | postae ==1 //31,751 obs
collapse (mean) in_pension [pw=rxwgt], by(raceb postae)
drop if raceb == 10 
reshape wide in_pension, i(raceb) j(postae)
ren in_pension0 Pre
ren in_pension1 Post
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("pen_participation_elioffer") sheetreplace
restore

end

capture program drop covariates_graphs
program define covariates_graphs


*Checking distribution of age by ethnic group
preserve
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
keep fx1 fx2 fx3 fx4 fx5 fx6 fx7 fx8 fx9 x
*for powerpoint
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("age_dist") sheetreplace
*for latex
line fx1 fx2 fx3 fx4 fx5 fx6 fx7 fx8 fx9 x, sort ytitle(Density)
graph export "$output/dens_age_race.pdf", replace
restore

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
*Scatter of pen vars by ethnicity and age
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


*EARNINGS DISTRIBUTION BY ETHNICITY
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

end

capture program drop regression_post
program define regression_post

*AE starts in Oct 2012, by Feb 2018 AE applied to all employers

*******REGRESSION RESULTS POST AE FOR ELIGIBLE/OFFER ONLY*****
preserve
keep if inlist(intyear,2018,2019,2020)
keep if inlist(jb1status, 1, 2)
drop if sector == 0
keep if annual_dum == 1 //only those affected by AE
keep if jbpen == 1 // only those offered a pension

foreach x in in_pension pens_contr pens_contr_cond {
	reg `x' i.raceb [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, replace label keep(2.raceb 3.raceb 4.raceb 5.raceb 6.raceb 7.raceb 8.raceb 9.raceb) 
	reg `x' i.raceb age agesq i.intyear [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, append label keep(2.raceb 3.raceb 4.raceb 5.raceb 6.raceb 7.raceb 8.raceb 9.raceb)
	reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, append label keep(2.raceb 3.raceb 4.raceb 5.raceb 6.raceb 7.raceb 8.raceb 9.raceb)
	reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, append label keep(2.raceb 3.raceb 4.raceb 5.raceb 6.raceb 7.raceb 8.raceb 9.raceb)
	reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, append label keep(2.raceb 3.raceb 4.raceb 5.raceb 6.raceb 7.raceb 8.raceb 9.raceb)
	reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, append label keep(2.raceb 3.raceb 4.raceb 5.raceb 6.raceb 7.raceb 8.raceb 9.raceb)
	reg `x' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win i.bornuk [pw=rxwgt], vce(cluster pidp)
	outreg2 using $output/`x'_post_reg.xls, append label keep(2.raceb 3.raceb 4.raceb 5.raceb 6.raceb 7.raceb 8.raceb 9.raceb)
}
restore
*NOTE: regression tables outputted to different excel sheet to powerpoint_data


end

capture program drop by_sex
program define by_sex

*gender gap in pension participation post AE for whites
preserve
keep if raceb == 1
keep if inrange(intyear,2018,2020)
collapse (mean) in_pension, by (female)
export excel "$output/powerpoint_data.xlsx", firstrow(var) sheet("sex_pension") sheetreplace
restore
*Women: 79.4%
*Men: 78.5%


******FOR ELIGIBLE EMPLOYEES offered pension, BY SEX-----------------------------------
foreach var of varlist in_pension pens_contr {

	preserve
	keep if inlist(jb1status, 1, 2)
	drop if sector == 0
	keep if annual_dum == 1 //only those affected by AE
	keep if jbpen == 1 // only those offered a pension
    * Do regression (pre)
   qui reg `var' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win i.bornuk if inrange(intyear,2010,2012) & female == 0 [pw=rxwgt], vce(cluster pidp)
    
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
    qui reg `var' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win i.bornuk if inrange(intyear,2018,2020) & female == 0 [pw=rxwgt], vce(cluster pidp)
    
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

foreach var of varlist in_pension pens_contr {

	preserve
	keep if inlist(jb1status, 1, 2)
	drop if sector == 0
	keep if annual_dum == 1 //only those affected by AE
	keep if jbpen == 1 // only those offered a pension
    * Do regression (pre)
   qui reg `var' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win i.bornuk if inrange(intyear,2010,2012) & female == 1 [pw=rxwgt], vce(cluster pidp)
    
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
    qui reg `var' i.raceb age agesq i.intyear lnrealearn i.miss_lnrealearn i.annual_dum i.annual_dum#i.sector i.sector i.jbsize i.industry i.occupation i.parttime i.edgrpnew i.edgrpnew#c.age i.region i.female i.health i.kidnum i.married i.partner_edu lnrealpartearn i.miss_lnrealpartearn i.partner_sector housecost_win i.bornuk if inrange(intyear,2018,2020) & female == 1 [pw=rxwgt], vce(cluster pidp)
    
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

