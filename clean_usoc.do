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
	
	* Drop people with proxy interviews - no pension data 
	keep if ivfio == 1 

	* Drop households if anyone in them has a missing interview year (this is only a few obs)
	gen missing_intyear = missing(intyear)
	egen missing_intyear_hh = sum(missing_intyear), by(wave hidp)
	qui count if missing_intyear_hh == 1
	*assert r(N) < 30
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

	use "$workingdata/bhps_constant_vars1", clear
	append using "$workingdata/bhps_constant_vars2"
	replace wave = wave - 18
	ren racel racel_bhps
	append using "$workingdata/usoc_extracted"
	append using "$workingdata/usoc_extracted_wave8"
	append using "$workingdata/usoc_wave1"
	egen double max_pidp = max(pidp) if !missing(pid), by(pid)
	assert pidp == max_pidp if wave > 0 & !missing(pid) // check that pidp doesn't vary within pid 
	replace pidp = max_pidp if missing(pidp) // give the bhps people pidps 
	drop max_pidp
	drop if missing(pidp) // get rid of people who are in the bhps but not usoc

	* Make consistent race variable 
	*Note: cannot disaggregate white due to variable limitation of race 
	gen raceb = 1 if race == 1 | inlist(racel_bhps, 1, 2, 3, 4, 5) | inlist(racel, 1, 2, 3, 4) //white
	replace raceb = 2 if inlist(racel_bhps, 6, 7, 8, 9) | inlist(racel, 5, 6, 7, 8) // mixed
	replace raceb = 3 if race == 5 | racel == 10 | racel == 9 // Indian
	replace raceb = 4 if race == 6 | racel == 11 | racel == 10 // Pakistani
	replace raceb = 5 if race == 7 | racel == 12 | racel == 11 // Bangladeshi
	replace raceb = 6 if race == 8 | inlist(racel, 13, 17) | inlist(racel, 12, 13) // Other Asian
	replace raceb = 7 if race == 2 | racel == 14 | racel == 14 // Black Caribbean 
	replace raceb = 8 if race == 3 | racel == 15 | racel == 15 // Black African 
	replace raceb = 9 if inlist(race, 4, 9) | inlist(racel, 16, 18) | inlist(racel, 16, 17, 97) // Other
	label define racelab1 1 "White" 2 "Mixed" 3 "Indian" 4 "Pakistani" 5 "Bangladeshi" 6 "Other Asian" 7 "Caribbean" 8 "African" 9 "Other"
	label values raceb racelab1
	drop race racel_bhps
	
	* Try and make consistent UK-born variable 
	gen bornuk = (inrange(ukborn, 1, 4)) if inrange(ukborn, 1, 5)
	replace bornuk = 1 if inrange(plbornd, 1, 368)
	replace bornuk = 0 if inrange(plbornc, 6, 92)
	
	* Copy forward education level and race
	sort pidp wave
	by pidp (wave): replace edgrpnew = edgrpnew[_n-1] if missing(edgrpnew)
	by pidp (wave): replace raceb = raceb[_n-1] if missing(raceb) // still missing sometimes but better
	by pidp (wave): replace bornuk = bornuk[_n-1] if missing(bornuk) 
	
	* Sort out missings for bornuk 
	replace bornuk = 2 if missing(bornuk)
	label define bornuk 0 "Not born in UK" 1 "Born in UK" 2 "Missing"
	label values bornuk bornuk
	drop ukborn plbornd plbornc ff_ukborn
	
	cap label drop edgrpnew
	label define edgrpnew 0 "None of the above qualifications" 1 "Less than GCSEs" 2 "GCSEs" 3 "A-levels" ///
		4 "Vocational higher" 5 "University"
	label values edgrpnew edgrpnew 
	
	* Copy forward job tenure variable 
	by pidp (wave): gen days_since_last_int = intdate - intdate[_n-1]
	
	// If their jb1status changed since previous wave and now they have a job:
	replace jb1tenure = floor(0.5 * days_since_last_int) if ///
		jb1status != jb1status[_n-1] & missing(jb1tenure) & ///
		inlist(jb1status, 1, 2) & inrange(days_since_last_int, 1, 500)
	
	by pidp (wave): replace jb1tenure = jb1tenure[_n-1] + days_since_last_int if ///
		missing(jb1tenure) & !missing(jb1tenure[_n-1]) & jbsamr == 1 & ///
		(wave == wave[_n-1] + 1 | wave == 2 & wave[_n-1] == 0) & inrange(days_since_last_int, 1, 500)
	// copy forward job tenure + int distance if it's missing and they're in same job as last wave & we see them
	// in last wave & their last wave was 1-500 days ago. Note some BHPS people joined usoc straight in wave 2. 
	
	* Generate categorical job tenure variable 
	gen job_tenure = 1 if jb1tenure <= 365.25 | (jbsamr == 2 & days_since_last_int <= 365) 
	// jbsamr = 2 is if changed job since last interview
	replace job_tenure = 2 if inrange(jb1tenure, 365.35, 730.5)
	replace job_tenure = 3 if inrange(jb1tenure, 730.5, 1826.25)
	replace job_tenure = 4 if jb1tenure >= 1826.25 & !missing(jb1tenure)
	label define job_tenure 1 "<1 year" 2 "1-2 years" 3 "2-5 years" 4 "5+ years"
	label values job_tenure job_tenure
	
	
	
end

capture program drop make_partner_vars
program define make_partner_vars

	/* Variable for whether partner is in work or not */
	
	* Sort by household, person number and wave 
	sort hidp wave pno
	
	* Generate a variable for whether the respondent is in work or not
	gen inwork = inlist(jb1status, 1, 2)
	replace jb1earn = 0 if inwork == 0

	* Now get partner's work status. Do this by keeping work status, renaming it to be partner_inwork, and then
	* merging it back in on the partner
	preserve 
	* Just keep relevant variables 
	keep hidp wave ppno marstat_dv inwork jb1earn edgrpnew jbsect jbsectpub jb1status ivfio
	ren inwork partner_inwork 
	ren jb1earn partner_earn
	ren edgrpnew partner_edu
	ren jbsect partner_jbsect
	ren jbsectpub partner_jbsectpub
	ren jb1status partner_jb1status
	ren ivfio partner_ivfio
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
	
	replace partner_earn = 0 if inrange(marstat_dv, 3, 6)
	replace partner_earn = .a if (_merge == 1 & inlist(marstat_dv, 1, 2)) | marstat_dv == -9
	
	replace partner_edu = 0 if inrange(marstat_dv, 3, 6)
	replace partner_edu = .a if (_merge == 1 & inlist(marstat_dv, 1, 2)) | marstat_dv == -9
	
	replace partner_jbsect = 0 if inrange(marstat_dv, 3, 6)
	replace partner_jbsect = .a if (_merge == 1 & inlist(marstat_dv, 1, 2)) | marstat_dv == -9
	
	replace partner_jbsectpub = 0 if inrange(marstat_dv, 3, 6)
	replace partner_jbsectpub = .a if (_merge == 1 & inlist(marstat_dv, 1, 2)) | marstat_dv == -9
	
	replace partner_jb1status = 0 if inrange(marstat_dv, 3, 6)
	replace partner_jb1status = .a if (_merge == 1 & inlist(marstat_dv, 1, 2)) | marstat_dv == -9

	
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
	
	/********** Personal pensions **********/
	
	* Participation
	gen pers_pen = ppen if !missing(ppen)
	replace pers_pen = 0 if inlist(ppreg, 1, 3, 4)
	// For now, say only people who regularly contribute are personal pension "participants"
	label variable pers_pen "Whether regularly contribute to a personal pension"
	label define pers_pen 0 "Don't regularly contribute to a personal pension" ///
		1 "Regularly contribute to a personal pension"
	label values pers_pen pers_pen 
	
	* Weekly contributions 
	* First need to edit the variable saying the number of weeks the contribution covers 
	gen pers_cont_period = pprampc
	replace pers_cont_period = 52/12 if pprampc == 5 // calendar month 
	replace pers_cont_period = 52/6  if pprampc == 7 // two calendar months 
	replace pers_cont_period = . if inlist(pprampc, 95, 96) // one off / lump sum

	gen pers_cont_week = ppram / pers_cont_period if !missing(pprampc, ppram)
	
	* Personal pension contributions as a percent of earnings - what to do about people not in work? 
	gen pers_cont_perc = 100 * (pers_cont_week / jb1earn)
	// ok there are some outliers here so i'm winsorising it 
	sum pers_cont_perc, d
	replace pers_cont_perc = r(p95) if pers_cont_perc >= r(p95) & !missing(pers_cont_perc)
	replace pers_cont_perc = 0 if pers_pen == 0
	
	/********** Aggregating personal and workplace pensions together **********/
	
	* Participation
	gen in_pension = 1 if pers_pen == 1 | jbpenm == 1
	replace in_pension = 0 if pers_pen == 0 & (jbpenm == 0 | jb1status != 1)
	
	* Contributions 
	gen pens_contr = ownperc + pers_cont_perc
	assert pens_contr == 0 if in_pension == 0 
	assert missing(pens_contr) if missing(ownperc) | missing(pers_cont_perc)
	
	gen pens_contr_cond = pens_contr if in_pension == 1
	
	
	
	
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
	
	gen pen_mem = 100*jbpenm // so that pension membership is /100
	replace pen_mem = 0 if pen_mem == . & jb1status != 1
	
	replace ownperc = 0 if missing(ownperc) & jb1status != 1

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

	gen agesq = age^2

	*jb1earn - Usual weekly gross earnings in main job
	*generating log earnings
	gen lnearn = ln(jb1earn)
	gen lnpartearn = ln(partner_earn)

	gen earn_dum = .
	replace earn_dum = 1 if inrange(jb1earn, 0,500)
	replace earn_dum = 2 if jb1earn > 500 & jb1earn <= 1000
	replace earn_dum = 3 if jb1earn >1000
	label define earn_dum 1 "0-500" 2 "500-1000" 3 "1000+" 

	*Generating number of kids categorical variable
	gen kidnum =.
	replace kidnum = 0 if numkids == 0
	replace kidnum = 1 if inrange(numkids,1,2)
	replace kidnum = 2 if inrange(numkids,3,4)
	replace kidnum = 3 if numkids > 4
	label define kid 0 "0" 1 "1-2" 2 "3-4" 3 "5+"
	label values kidnum kid
	save "$workingdata/usoc_clean", replace

	*inflation data - for generating real earnings
	import excel "$workingdata/inflation.xls", sheet("data") cellrange(A9:B42) clear
	destring A, replace
	ren A intyear
	ren B cpih
	save "$workingdata/inflation.dta", replace
	merge 1:m intyear using "$workingdata/usoc_clean.dta"
	keep if _merge == 3
	drop _merge
	*generating real earnings (2020)
	gen real_earn = jb1earn*(108.9/cpih)
	gen lnrealearn = ln(real_earn)
	gen realpartearn = partner_earn*(108.9/cpih)
	gen lnrealpartearn = 0
	replace lnrealpartearn = ln(realpartearn) if !missing(realpartearn) 
	replace lnrealpartearn = 0 if realpartearn == 0

	*generating kid dummies for covariates table
	gen kid0 = 0
	replace kid0 = 1 if kidnum == 0
	gen kid12 = 0
	replace kid12 = 1 if kidnum == 1
	gen kid34 = 0
	replace kid34 = 1 if kidnum == 2
	gen kid5ormore = 0
	replace kid5ormore = 1 if kidnum == 3

	*generating education dummies for covariates table
	gen uni = 0
	replace uni = 1 if edgrpnew == 5
	gen alevels = 0
	replace alevels = 1 if edgrpnew == 3
	gen gcse = 0
	replace gcse = 1 if edgrpnew == 2
	gen lessgcse = 0
	replace lessgcse = 1 if edgrpnew == 1


	*Housing tenure for covariates table
	gen rent = 0 
	replace rent = 1 if tenure_broad == 3
	gen owned = 0 
	replace owned = 1 if tenure_broad == 1
	gen mort = 0
	replace mort = 1 if tenure_broad == 2

	*If have long term condition/disability
	gen disability = 0 
	replace disability = 1 if health == 1

	*relationship dummies for covariates table
	gen mar = 0
	replace mar = 1 if marstat_broad == 1
	gen coupl = 0
	replace coupl = 1 if marstat_broad == 2
	gen divorce = 0
	replace divorce = 1 if marstat_broad == 3
	gen nev_mar = 0
	replace nev_mar = 1 if marstat_broad == 4

	gen retneed = 0 
	replace retneed = -1 if retsuf < 0
	replace retneed = 100 if inrange(retsuf,1,2) //enough or more to meet needs

	gen famcont = 0 
	replace famcont = -1 if rtfnd7 < 0
	replace famcont = 100 if rtfnd7 == 1 //percent with financial support from family

	*winsorizing variables
	winsor houscost1_dv, p(.01) gen(housecost_win)

	*generating nominal yearly earnings and dummy if annual earn > 10k
	gen annual_earn = jb1earn*52
	gen annual_dum = 0
	replace annual_dum = 1 if annual_earn >= 10000 & !missing(annual_earn) 
	label define annual_dum 0 "Less than 10k per year" 1 "More than 10k per year"
	label value annual_dum annual_dum
	
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
	
	gen partner_public =.
	replace partner_public = 1 if inlist(partner_jbsectpub, 1, 2, 3, 4, 6, 8)
	replace partner_public = 0 if partner_jbsect == 1 | inlist(partner_jbsectpub, 5, 7, 9)
	label define partner_public 0 "Private" 1 "Public" 
	label values partner_public partner_public
	label var partner_public "Sector - public vs private vs other. Employees only"
	
	* Aggregated job size variable 
	gen jbsize_broad = 1 if inlist(jbsize, 1, 2, 3, 10)
	replace jbsize_broad = 2 if inlist(jbsize, 4, 5, 6, 11)
	replace jbsize_broad = 3 if inrange(jbsize, 7, 9)
	label define jbsize_broad 1 "1-24" 2 "25-199" 3 "200+"
	label values jbsize_broad jbsize_broad
	
	gen sector =.
	replace sector = 0 if jb1status == 2
	replace sector = 1 if public == 0 & jb1status == 1
	replace sector = 2 if public == 1 & jb1status == 1
	label define sect 0 "Self-employed" 1 "Private" 2 "Public"
	label values sector sect

	gen partner_sector =.
	replace partner_sector = 0 if partner_jb1status == 2
	replace partner_sector = 1 if partner_public == 0 & partner_jb1status == 1
	replace partner_sector = 2 if partner_public == 1 & partner_jb1status == 1
	replace partner_sector = 3 if partner_inwork == 0
	label define partner_sect 0 "Self-employed" 1 "Private" 2 "Public" 3 "Not in work"
	label values partner_sector partner_sect

	*putting jobsize of 1 if self-employed
	replace jbsize = 1 if jbsize == -8 & jb1status == 2

	gen occupation = .
	forvalues i = 1/9{
		replace occupation = `i' if inrange(jbsoc00_cc,`i'00,`i'99)
	}
	label define occ 1 "Managers and senior officials" 2 "Professional occupations" 3 "Associate professional and technical occupations" 4 "Administrative and secretarial occupations" 5 "Skilled trades occupations" 6 "Personal service occupations" 7 "Sales and customer service occupations" 8 "Process, plant and machine operatives" 9 "Elementary occupations"
	label values occupation occ 

	gen industry = . 
	replace industry = 1 if inrange(jbsic07_cc,1,3)
	replace industry = 2 if inrange(jbsic07_cc,4,9)
	replace industry = 3 if inrange(jbsic07_cc,10,32)
	replace industry = 4 if inrange(jbsic07_cc,33,35)
	replace industry = 5 if inrange(jbsic07_cc,36,39)
	replace industry = 6 if inrange(jbsic07_cc,40,43)
	replace industry = 7 if inrange(jbsic07_cc,45,47)
	replace industry = 8 if inrange(jbsic07_cc,49,53)
	replace industry = 9 if inrange(jbsic07_cc,55,56)
	replace industry = 10 if inrange(jbsic07_cc,58,63)
	replace industry = 11 if inrange(jbsic07_cc,64,66)
	replace industry = 12 if jbsic07_cc == 68
	replace industry = 13 if inrange(jbsic07_cc,69,75)
	replace industry = 14 if inrange(jbsic07_cc,77,79)
	replace industry = 15 if inrange(jbsic07_cc,80,84)
	replace industry = 16 if jbsic07_cc == 85
	replace industry = 17 if inrange(jbsic07_cc,86,88)
	replace industry = 18 if inrange(jbsic07_cc,90,93)
	replace industry = 19 if inrange(jbsic07_cc,94,96)
	replace industry = 20 if inrange(jbsic07_cc,97,98)
	replace industry = 21 if jbsic07_cc == 99
	label define ind 1 "Agriculture, Forestry and Fishing" 2 "Mining and Quarrying" 3 "Manufacturing" 4 "Electricity, gas, steam and air conditioning supply" 5 "Water supply, sewerage, waste management and remediation activities" 6 "Construction" 7 "Wholesale and retail trade; repair of motor vehicles and motorcycles" 8 "Transportation and storage" 9 "Accommodation and food service activities" 10 "Information and communication" 11 "Financial and insurance activities" 12 "Real estate activities" 13 "Professional, scientific and technical activities" 14 "Administrative and support service activities" 15 "Public administration and defence; compulsory social security" 16 "Education" 17 "Human health and social work activities" 18 "Arts, entertainment and recreation" 19 "Other service activities" 20 "Activities of households as employers; undifferentiated goods and services producing activities of households for own use" 21 "Activities of extraterritorial organisations and bodies"
	label values industry ind
	
	*sector variable for covariates table
	gen priv = 0
	replace priv = 1 if sector == 1
	gen pub = 0
	replace pub = 1 if sector == 2
	gen self = 0
	replace self = 1 if sector == 0

	*partner sector for covariates table
	gen priv_p = 0
	replace priv_p = 1 if partner_sector == 1
	gen pub_p = 0
	replace pub_p = 1 if partner_sector == 2
	gen self_p = 0
	replace self_p = 1 if partner_sector == 0

	*generating employer size dummies for covariates table
	gen jbsize1_24 = 0
	replace jbsize1_24 = 1 if inrange(jbsize,1,3)
	gen jbsize25_199 = 0
	replace jbsize25_199 = 1 if inrange(jbsize,4,6)
	gen jbsize200plus = 0
	replace jbsize200plus = 1 if inrange(jbsize,7,9)

	gen parttime = 0
	replace parttime = 1 if jb1hrsot <= 30
	
	***************************************************************************
	*missing dummies
	replace lnrealearn = 0 if missing(lnrealearn)
	gen miss_lnrealearn = 0
	replace miss_lnrealearn = 1 if lnrealearn == 0
	replace sector = 3 if missing(sector)
	label define sect 3 "missing", add
	replace jbsize = 0 if inlist(jbsize, -9, -8, -2, -1)
	replace industry = 0 if missing(industry)
	label define ind 0 "missing", add
	replace occupation = 0 if missing(occupation)
	label define occ 0 "missing", add
	replace edgrpnew = 6 if missing(edgrpnew)
	label define edgrpnew 6 "missing", add
	replace region = 13 if missing(region)
	label define region 13 "missing", add
	replace female = 2 if missing(female)
	label define female 2 "missing", add
	replace health = 0 if inlist(health, -2, -1, -9)
	label define health 0 "missing"
	replace partner_edu = 6 if missing(partner_edu)
	gen miss_lnrealpartearn = 0
	replace miss_lnrealpartearn = 1 if inlist(marstat_dv, 1, 2) & missing(realpartearn)
	replace partner_sector = 4 if missing(partner_sector)
	replace raceb = 10 if missing(raceb)
	label define racelab1 10 "missing", add


end




