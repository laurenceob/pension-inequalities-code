/********************************************************************************
**** Title: 		clean_usoc.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	20/08/2021 
**** Description:	This do file cleans the extracted USoc data. See main program
					at bottom of file for structure
********************************************************************************/

capture program drop main
program define main 

	* First job is to use data from all waves of BHPS and USoc to work out someone's education level 
	* This variable is coded as missing if someone already answered this question in an earlier wave and their 
	* ed level hasn't changed. So use all waves to copy previous answers to other waves 
	* Then after that just keep USoc
	clean_ff_vars
	
	* Just keep USoc observations 
	keep if wave > 0
	
	* Just keep even waves when we have pension data and declare as panel data with only even waves
	keep if mod(wave, 2) == 0
	xtset pidp wave, delta(2)
	
	* Make partner variables 
	make_partner_vars
	
	* Drop people with proxy interviews 
	keep if ivfio == 1

	* Drop households if anyone in them has a missing interview year (this is only a few obs)
	gen missing_intyear = missing(intyear)
	egen missing_intyear_hh = sum(missing_intyear), by(wave hidp)
	qui count if missing_intyear_hh == 1
	assert r(N) < 30
	drop if missing_intyear_hh == 1
	drop missing_intyear*
	
	* Clean pension variables
	clean_pension_vars 
	
	* Clean some of the circumstance variables
	clean_circumstance_vars
	
	* Clean job-related variables
	clean_job_vars 
	
	* Sample is people who are working-age: 22-59 year olds
	keep if inrange(age, 22, 59)
	
	* Drop superfluous variables (these are from BHPS)
	drop pid hid buno
	
	* Save
	save "$workingdata/usoc_clean", replace


end

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
	
	drop _merge

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
	
	gen racea = .
	replace racea = 1 if inlist(racel, 1,2,3,4)
	replace racea = 2 if inlist(racel, 5,6,7,8)
	replace racea = 3 if inlist(racel, 9,10,11,12,13)
	replace racea = 4 if inlist(racel, 14,15,16)
	replace racea = 5 if inlist(racel, 17,18)
	label define racelab 1 "White" 2 "Mixed" 3 "Asian" 4 "Black" 5 "Other"
	label values racea racelab

	*new race variable - for graph
	gen raceb = .
	replace raceb = 1 if inlist(racel, 1,2,3,4) //white
	replace raceb = 2 if inlist(racel, 5,6,7,8) //mixed
	replace raceb = 3 if racel == 9 //Indian
	replace raceb = 4 if racel == 10 //Pakistani
	replace raceb = 5 if racel == 11 //Bangladeshi
	replace raceb = 6 if inlist(racel, 12,13) //Other Asian
	replace raceb = 7 if racel == 14 //Caribbean
	replace raceb = 8 if racel == 15 //African
	replace raceb = 9 if racel == 16 //Other Black
	replace raceb = 10 if inlist(racel, 17,18) //Other
	label define racelab1 1 "White" 2 "Mixed" 3 "Indian" 4 "Pakistani" 5 "Bangladeshi" 6 "Other Asian" 7 "Caribbean" 8 "African" 9 "Other Black" 10 "Other"
	label values raceb racelab1

	order racea raceb, after(racel)

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


end




