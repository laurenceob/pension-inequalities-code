/********************************************************************************
**** Title: 		clean_usoc.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	20/08/2021 
**** Description:	This do file cleans the extracted USoc data. See main program
					at bottom of file for structure
********************************************************************************/

capture program drop clean_ff_vars
program define clean_ff_vars 

	/* Append the BHPS and USOC and sort out all the carried forward variables */

	use "$workingdata/bhps_constant_vars", clear
	replace wave = wave - 18
	append using "$workingdata/usoc_extracted"
	append using "$workingdata/usoc_wave1"
	egen double max_pidp = max(pidp) if !missing(pid), by(pid)
	assert pidp == max_pidp if wave > 0 & !missing(pid) // check that pidp doesn't vary within pid 
	replace pidp = max_pidp if missing(pidp) // give the bhps people pidps 
	drop max_pidp
	drop if missing(pidp) // get rid of people who are in the bhps but not usoc

	* Copy forward education level (and race but this is still often missing)
	sort pidp wave
	by pidp (wave): replace edgrpnew = edgrpnew[_n-1] if missing(edgrpnew)
	by pidp (wave): replace racel = racel[_n-1] if missing(racel) | racel < 0

	cap label drop edgrpnew
	label define edgrpnew 0 "None of the above qualifications" 1 "Less than GCSEs" 2 "GCSEs" 3 "A-levels" ///
		4 "Vocational higher" 5 "University"
	label values edgrpnew edgrpnew 

end

capture program drop make_employer_change
program define make_employer_change

	/* Use the annual event history questions to get at changes in employer/job (over 2 waves) */
	xtset pidp wave
	
	* Employer change (this includes people who were not continously employed over the year)
	gen employer_change = 1 if jbsamr == 2 | L.jbsamr == 2
	replace employer_change = 1 if empchk == 2 | L.empchk == 2 // not continuously employed
	replace employer_change = 0 if jbsamr == 1 & L.jbsamr == 1
	label var employer_change "Whether changed employer in past two years"
	label define employer_change 0 "Not changed employer" 1 "Changed employer"
	label values employer_change employer_change
	
	* Job change (including employer change)
	gen job_change = 1 if employer_change == 1
	replace job_change = 1 if samejob == 2 | L.samejob == 2
	replace job_change = 0 if samejob == 1 & L.samejob == 1
	label var job_change "Whether changed job in past two years"
	label define job_change 0 "Not changed job" 1 "Changed job"
	label values job_change job_change

end

capture program drop make_partner_vars
program define make_partner_vars

	/* Variable for whether partner is in work or not */
	
	* Sort by household, person number and wave 
	sort hidp wave pno
	
	* Generate a variable for whether the respondent is in work or not
	gen inwork = inlist(econstat, 1, 2)

	* Now get partner's work status. Do this by keeping work status, renaming it to be partner_inwork, and then
	* merging it back in on the partner
	preserve 
	* Just keep relevant variables 
	keep hidp wave ppno marstat_dv inwork 
	ren inwork partner_inwork 
	ren ppno pno
	* Only keep people with a partner
	keep if pno > 0
	tempfile partnerdata
	save `partnerdata'
	restore 
	
	* Merge in patner's work status
	merge 1:1 hidp wave pno using `partnerdata'
	* Check the merging went ok 
	assert _merge != 2 // no one in the partner data that isn't in the main data 
	assert _merge != 3 if inrange(marstat_dv, 3, 6) 
	// no one who doesn't have a partner in the main data in the partner data
	
	* Label the missing values 
	replace partner_inwork = 0 if inrange(marstat_dv, 3, 6)  // partner is not in work if you don't have one
	replace partner_inwork = .a if (_merge == 1 & inlist(marstat_dv, 1, 2)) | marstat_dv == -9
	label define partner_inwork 0 "Partner not in paid work" 1 "Partner in paid work" .a "Missing"
	label values partner_inwork partner_inwork
	

end

capture program drop make_weights
program define make_weights 

	/* Make weights for both pooled cross-sectional analysis and longitudinal analysis */
	
	/******** Longitudinal weights over the course of 2 years - self made ********/

	/* For each period, run a logit regression predicting the prob of the individual being 
	  in wave based on characteristics in previous (even) wave */
	  
	* Need to tsfill to start with
	tsfill, full
	
	* Our outcome variable is whether you have a full interview in the current period 
	replace ivfio = 0 if missing(ivfio)
	
	local predictors tenure hvalue sex couple married numkids age jbterm1 jbsize jbsect ///
		jbpen jbpenm region jb1tenure jb1hrs jb1earn nonlabinc saved
	
	* Check our predictors don't have missing values
	//sum `predictors' if wave != 10
	
	* Create temp variables with no missings 
	foreach var of varlist tenure jbterm1 jbsect jbpenm region sex {
		gen `var'_temp = `var'
		qui sum `var'
		replace `var'_temp = `=r(max)+1' if (missing(`var'_temp) | `var' < 0) & (rxwgt != 0 & !missing(rxwgt))
		replace `var'_temp = . if rxwgt == 0 | missing(rxwgt)
	}
	foreach var of varlist hvalue jb1earn nonlabinc jb1hrs saved {
		gen `var'_temp = `var'
		replace `var'_temp = 0 if missing(`var') & (rxwgt != 0 & !missing(rxwgt))
		replace `var'_temp = . if rxwgt == 0 | missing(rxwgt)
	}
	
	local predictors_new "i.tenure_temp hvalue_temp i.sex_temp i.couple i.married i.numkids age i.jbterm1_temp"
	local predictors_new "`predictors_new' i.jbsect_temp i.jbpenm_temp i.region_temp jb1hrs_temp" 
	local predictors_new "`predictors_new' jb1earn_temp nonlabinc_temp saved_temp i.wave"
	
	* Predict future response 
	qui stepwise, pr(0.05): logit ivfio L.(`predictors_new') if L.rxwgt != 0 & !missing(L.rxwgt)
	predict prob2 if ivfio == 1 & rxwgt != 0 & L.rxwgt != 0 & !missing(L.rxwgt)
	
	* Make new weight 
	gen weight_new_li2 = rxwgt / prob2 if !missing(prob2)
	replace weight_new_li2 = 0 if missing(weight_new_li2)
	
	drop *temp
	
	* Just keep people with full interviews 
	keep if ivfio == 1
	
	
	/******** Longitudinal weights in USoc ********/
	/* The USoc longitudinal weights are in the variables `w'_indinub_lw and `w'_indinui_lw.
	  `w'_indinub_lw contains weights starting in wave 2, while `w'_indinui_lw starts in wave 6.
	  So make a single weight using the right longitudinal weight for each wave */
	gen weight_li = ltwgt_ub if inrange(wave, 4, 6)
	replace weight_li = ltwgt_ui if inrange(wave, 8, 10)
	
	/******** Balanced panel weights in USoc ********/
	/* The USoc longitudinal weights are in the variables `w'_indinub_lw and `w'_indinui_lw.
	  `w'_indinub_lw contains weights starting in wave 2, while `w'_indinui_lw starts in wave 6.
	  So make a single weight using the right longitudinal weight for each wave */
	gen weight_li_bp_temp = ltwgt_ub if wave == 10
	by pidp: egen weight_li_bp = max(weight_li_bp_temp)
	drop weight_li_bp_temp

end

capture program drop clean_pension_vars
program define clean_pension_vars 
	
	/********** Workplace pensions **********/
	* A lot of the cleaning of these variables happens in the USoc extractor 
	
	* Dummies for DC/DB pension - these are zero if you are an employee without the type of pension 
	* unless you don't know the type of pension, or you have missing for pension variables for some reason 
	* or if your pension is some sort of DB/DC combination
	gen pen_dc = (pentype == 2) if inlist(pentype, 1, 2, 3, .c)
	gen pen_db = (pentype == 1) if inlist(pentype, 1, 2, 3, .c)
	gen pen_other = (pentype == 3) if inlist(pentype, 1, 2, 3, .c)
	
	* Winsorise contribution rate 
	sum ownperc if jbpenm == 1, d
	replace ownperc = r(p99) if ownperc >= r(p99) & !missing(ownperc)
	
	* Pension contribution rate, conditional on being a member of a pension 
	gen ownperc_cond = ownperc if jbpenm == 1
	label var ownperc_cond "Employee contribution rate, workplace pension members only"
	
	/********** Changes in workplace pension saving **********/

	* Generate variables for changes in pension saving 
	gen join_workplace_pension  = (jbpenm == 1 & L.jbpenm == 0) if L.jbpenm == 0 & inlist(jbpenm, 0, 1)
	gen leave_workplace_pension = (jbpenm == 0 & L.jbpenm == 1) if L.jbpenm == 1 & inlist(jbpenm, 0, 1)
	
	gen nopen_to_pen 	= (jbpenm == 1 & L.jbpenm == 0) if inlist(jbpenm, 0, 1) & inlist(L.jbpenm, 0, 1)
	gen pen_to_nopen 	= (jbpenm == 0 & L.jbpenm == 1) if inlist(jbpenm, 0, 1) & inlist(L.jbpenm, 0, 1)
	gen pen_to_pen		= (jbpenm == 1 & L.jbpenm == 1) if inlist(jbpenm, 0, 1) & inlist(L.jbpenm, 0, 1)
	gen nopen_to_nopen 	= (jbpenm == 0 & L.jbpenm == 0) if inlist(jbpenm, 0, 1) & inlist(L.jbpenm, 0, 1)
	
	gen delta_ownperc = ownperc - L.ownperc if !missing(ownperc, L.ownperc)
	gen ownperc_change = delta_ownperc != 0 if !missing(delta_ownperc)
	gen delta_ownperc_cond = ownperc - L.ownperc if !missing(ownperc, L.ownperc) & jbpenm == 1 & L.jbpenm == 1
	gen ownperc_change_cond = delta_ownperc_cond != 0 if !missing(delta_ownperc_cond)
	
	* Trim really big changes in contribution rates 
	replace delta_ownperc = . if abs(delta_ownperc) > 15
	replace delta_ownperc_cond = . if abs(delta_ownperc_cond) > 15

	* Indicator variables for different amounts of changes in contributions 
	gen ownperc_same    = inrange(delta_ownperc, -0.05, 0.05) if !missing(delta_ownperc)
	gen ownperc_inc_2p5 = delta_ownperc > 0.05 & delta_ownperc <= 2.5 if !missing(delta_ownperc)
	gen ownperc_inc_5   = delta_ownperc > 2.5  & delta_ownperc <= 5 if !missing(delta_ownperc)
	gen ownperc_inc_mt5 = delta_ownperc > 5 if !missing(delta_ownperc)
	gen ownperc_dec_2p5 = delta_ownperc < -0.05 & delta_ownperc >= -2.5 if !missing(delta_ownperc)
	gen ownperc_dec_5   = delta_ownperc < -2.5  & delta_ownperc >= -5 if !missing(delta_ownperc)
	gen ownperc_dec_mt5 = delta_ownperc < -5 if !missing(delta_ownperc)
	
	local if2 "jbpenm == 1 & L.jbpenm == 1"
	gen ownperc_same_cond    = inrange(delta_ownperc, -0.05, 0.05) if !missing(delta_ownperc) & `if2'
	gen ownperc_inc_2p5_cond = delta_ownperc > 0.05 & delta_ownperc <= 2.5 if !missing(delta_ownperc) & `if2'
	gen ownperc_inc_5_cond   = delta_ownperc > 2.5  & delta_ownperc <= 5 if !missing(delta_ownperc) & `if2'
	gen ownperc_inc_mt5_cond = delta_ownperc > 5 if !missing(delta_ownperc) & `if2'
	gen ownperc_dec_2p5_cond = delta_ownperc < -0.05 & delta_ownperc >= -2.5 if !missing(delta_ownperc) & `if2'
	gen ownperc_dec_5_cond   = delta_ownperc < -2.5  & delta_ownperc >= -5 if !missing(delta_ownperc) & `if2'
	gen ownperc_dec_mt5_cond = delta_ownperc < -5 if !missing(delta_ownperc) & `if2'
	

end

capture program drop clean_circumstance_vars 
program define clean_circumstance_vars

	/* Create a few new variables for analysing individual/household circumstances (statically) */
	
	* Marital status
	gen marstat_broad = 1 if marstat_dv == 1
	replace marstat_broad = 2 if marstat_dv == 2
	replace marstat_broad = 3 if inrange(marstat_dv, 3, 5)
	replace marstat_broad = 4 if marstat_dv == 6
	label define marstat_broad 1 "Married/Civil partner" 2 "Living as couple" 3 "Widowed/divorced/separated" ///
		4 "Never married"
	label values marstat_broad marstat_broad

	* Housing tenure 
	gen tenure_broad = 1 if tenure == 1
	replace tenure_broad = 2 if tenure == 2
	replace tenure_broad = 3 if inrange(tenure, 3, 7)
	label define tenure_broad 1 "Own outright" 2 "Mortgage" 3 "Rent/other"
	label values tenure_broad tenure_broad

	* Has a child 
	gen has_child = (ndepchl_dv > 0) if !missing(ndepchl_dv)
	label define has_child 0 "No child in household" 1 "Own child in household"
	label values has_child has_child

	* Age group 
	gen age_group10 = 1 if inrange(age, 22, 29)
	replace age_group10 = 2 if inrange(age, 30, 39)
	replace age_group10 = 3 if inrange(age, 40, 49)
	replace age_group10 = 4 if inrange(age, 50, 59)
	label define age_group10 1 "22-29" 2 "30-39" 3 "40-49" 4 "50-59"
	label values age_group10 age_group10 
	
	gen age_group5 = 1 if inrange(age, 22, 24)
	replace age_group5 = 2 if inrange(age, 25, 29)
	replace age_group5 = 3 if inrange(age, 30, 34)
	replace age_group5 = 4 if inrange(age, 35, 39)
	replace age_group5 = 5 if inrange(age, 40, 44)
	replace age_group5 = 6 if inrange(age, 45, 49)
	replace age_group5 = 7 if inrange(age, 50, 54)
	replace age_group5 = 8 if inrange(age, 55, 59)
	label define age_group5 1 "22-24" 2 "25-29" 3 "30-34" 4 "35-39" 5 "40-44" 6 "45-49" 7 "50-54" 8 "55-59"
	label values age_group5 age_group5 
	
	* Sex 
	cap label drop female 
	label define female 0 "Men" 1 "Women"
	label values female female 

end

capture program drop make_circumstance_changes
program define make_circumstance_changes

	/* Variables denoting changes in household circumstances */
	
	* First make marstat missing if -9
	replace marstat_dv = . if marstat_dv < 0
	 
	 * Make number of children equal to zero if missing because living alone 
	 replace ndepchl_dv = 0 if ndepchl_dv == -8
	
	* Children 
	gen still_no_child   = (ndepchl_dv == 0 & L.ndepchl_dv == 0) if !missing(ndepchl_dv, L.ndepchl_dv)
	gen first_child    	 = (ndepchl_dv > 0 & L.ndepchl_dv == 0) if !missing(ndepchl_dv, L.ndepchl_dv)
	gen additnl_child	 = (ndepchl_dv > L.ndepchl_dv & L.ndepchl_dv > 0) if !missing(ndepchl_dv, L.ndepchl_dv)
	gen child_leaves     = (ndepchl_dv < L.ndepchl_dv) if !missing(ndepchl_dv, L.ndepchl_dv)
	gen still_same_child = (ndepchl_dv >= 1 & ndepchl_dv == L.ndepchl_dv) if !missing(ndepchl_dv, L.ndepchl_dv)
	
	gen child_change = 1 if still_no_child == 1 | still_same_child == 1
	replace child_change = 2 if first_child == 1
	replace child_change = 3 if additnl_child == 1
	replace child_change = 4 if child_leaves == 1
	label define child_change 1 "No child change" 2 "First child" 3 "Additional child" 4 "Child leaves"
	label values child_change child_change
	
	* Children starting school
	*Can you just define this in an analogous way to the children variable, but making it an indicator for being 
	*above 5 years old? Or maybe below?
	* DON'T BOTHER
	
	* Change in relationship status 
	gen still_married   = (marstat_dv == 1 & L.marstat_dv == 1) if !missing(marstat_dv, L.marstat_dv)
	gen leave_marriage  = (marstat_dv != 1 & L.marstat_dv == 1) if !missing(marstat_dv, L.marstat_dv)
	gen get_married     = (marstat_dv == 1 & L.marstat_dv != 1) if !missing(marstat_dv, L.marstat_dv)
	gen still_not_marrd = (marstat_dv != 1 & L.marstat_dv != 1) if !missing(marstat_dv, L.marstat_dv)
	
	gen marital_change = 1 if still_not_marrd == 1 | still_married == 1
	replace marital_change = 2 if get_married == 1
	replace marital_change = 3 if leave_marriage == 1
	label define marital_change 1 "No marriage change" 2 "Get married" 3 "Leave marriage"
	label values marital_change marital_change
	
	* Change in mortgage
	gen still_mortgage  = (tenure == 2 & L.tenure == 2) if !missing(tenure, L.tenure)
	gen new_mortgage    = (tenure == 2 & L.tenure != 2) if !missing(tenure, L.tenure)
	gen fin_mortgage    = (tenure == 1 & L.tenure == 2) if !missing(tenure, L.tenure)
	gen still_no_mortge = (tenure != 2 & L.tenure != 2) if !missing(tenure, L.tenure)
	gen mortge_to_rent  = (inrange(tenure, 3, 7) & L.tenure == 2) if !missing(tenure, L.tenure)
	
	gen mortgage_change = 1 if still_no_mortge == 1 | still_mortgage == 1
	replace mortgage_change = 2 if new_mortgage == 1
	replace mortgage_change = 3 if fin_mortgage == 1
	replace mortgage_change = 4 if mortge_to_rent == 1
	label define mortgage_change 1 "No mortgage change" 2 "New mortgage" 3 "Paid off mortgage" ///
		4 "Mortgage to renter"
	label values mortgage_change mortgage_change 
	
	* Change in partner work status 
	gen part_start_work  = (partner_inwork == 1 & L.partner_inwork == 0)
	gen part_stop_work   = (partner_inwork == 0 & L.partner_inwork == 1)
	gen part_never_work  = (partner_inwork == 0 & L.partner_inwork == 0)
	gen part_still_work  = (partner_inwork == 1 & L.partner_inwork == 1)
	
	gen partner_work_change = 1 if part_never_work == 1 | part_still_work == 1
	replace partner_work_change = 2 if part_start_work == 1
	replace partner_work_change = 3 if part_stop_work == 1
	label define partner_work_change 1 "No partner work change" 2 "Partner starts work" 3 "Partner stops work"
	label values partner_work_change partner_work_change
	

end

capture program drop clean_job_vars 
program define clean_job_vars  

	* Make a simpler public sector variable (similar to ASHE) -  this is missing for self-employed
	gen public = .
	replace public = 1 if inlist(jbsectpub, 1, 2, 3, 4, 6, 8)
	replace public = 0 if jbsect == 1 | inlist(jbsectpub, 5, 7, 9)
	label define public 0 "Private" 1 "Public" 
	label values public public
	label var public "Sector - public vs private vs other. Employees only"
	
	* Aggregated job size variable 
	gen jbsize_broad = 1 if inlist(jbsize, 1, 2, 3, 10)
	replace jbsize_broad = 2 if inlist(jbsize, 4, 5, 6, 11)
	replace jbsize_broad = 3 if inrange(jbsize, 7, 9)
	label define jbsize_broad 1 "1-24" 2 "25-199" 3 "200+"
	label values jbsize_broad jbsize_broad
	
	* Change in (log) earnings 
	gen log_earn = ln(jb1earn)
	gen change_log_earn = log_earn - L.log_earn
	label var change_log_earn "Change in log earnings"
	
	* Change in hours 
	gen change_hrs = jb1hrs - L.jb1hrs 
	label var change_hrs "Change in usual weekly hours (excl. overtime)"


end

capture program drop create_lagged_vars
program define create_lagged_vars 

	/* Create variables containing lags of some variables */
	
	* Lag of whether in public sector 
	gen lag_public = L.public
	label values lag_public public 
	
	* Lag of education (this is equal for nearly all of our sample)
	gen lag_edgrpnew = L.edgrpnew
	label values lag_edgrpnew edgrpnew 
	
	* Lag of region 
	gen lag_region = L.region 
	label values lag_region region 
	

end

capture program drop main
program define main 

	* First job is to use data from all waves of BHPS and USoc to work out someone's education level 
	* This variable is coded as missing if someone already answered this question in an earlier wave and their 
	* ed level hasn't changed. So use all waves to copy previous answers to other waves 
	* Then after that just keep USoc
	clean_ff_vars
	
	* Just keep USoc observations 
	keep if wave > 0
	
	* Next, make a variable indicating if they changed employer/job over the course of two years 
	make_employer_change
	
	* Just keep even waves when we have pension data and declare as panel data with only even waves
	keep if mod(wave, 2) == 0
	xtset pidp wave, delta(2)
	
	* Make partner variables 
	make_partner_vars
	
	* Drop people with proxy interviews 
	keep if ivfio == 1
	
	* Make weights 
	make_weights

	* Drop households if anyone in them has a missing interview year (this is only a few obs)
	gen missing_intyear = missing(intyear)
	egen missing_intyear_hh = sum(missing_intyear), by(wave hidp)
	qui count if missing_intyear_hh == 1
	assert r(N) < 30
	drop if missing_intyear_hh == 1
	drop missing_intyear*
	
	* Clean pension variables, and create variables for changes in pension saving over the course of two waves 
	clean_pension_vars 
	
	* Clean some of the circumstance variables
	clean_circumstance_vars
	
	* Make variables for changes in marital status/children/mortgage 
	make_circumstance_changes
	
	* Clean job-related variables, and create variables for changes in job-related info 
	clean_job_vars 
	
	* Create lags of some variables
	create_lagged_vars
	
	* Who do we want in our sample? 22-59 year olds?
	keep if inrange(age, 22, 59)
	
	* Drop superfluous variables 
	drop pid hid buno
	
	* Save
	save "$workingdata/usoc_clean", replace

	
	

end



