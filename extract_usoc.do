/********************************************************************************
**** Title: 		extract_usoc.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	20/08/2021 
**** Description:	This do file uses the USoc extractor to get the desired variables
					from USOC
********************************************************************************/

/*************************************/
/************* EXTRACTOR *************/
/*************************************/

* Main dataset
# delimit ;

usextract using "$workingdata/usoc_extracted",
		
	waves(2(1)10)
			

	/* hhresp */
	hhrespoptions(
		hhintdate(hhintdate)
		hhrxwgt(hhrxwgt)
		ivfho(ivfho)
		hvalue(hvalue)
		tenure(tenure)
		totmortgage(totmortgage)
		monthlymortgage(monthlymortgage)
		rawvars(hidp tenure_dv)
		mindic
	)

	/* indall */
	indalloptions(
		age(age)
		depkid(depkid)
		female(female)
		couple(couple)
		married(married)
		/*ptrpid(ptrpid)*/
		numkids(numkids)
		kidage(kidage)
		parentinhh(parentinhh)
		rawvars(sex hidp buno_dv pno pidp ppno)
		mindic
	)
	
	/* indresp */
	indrespoptions(
		edgrpnew(edgrpnew)
		agesch(agesch(agesch) schstill(schstill))
		intdate(intdate(intdate) intyear(intyear) intmonth(intmonth))
		mover(mover)
		rxwgt(rxwgt)
		ivfio(ivfio)
		gor(region)
		econstat(econstat)
		jb1start(jb1startd(jb1startd) jb1startm(jb1startm) jb1starty(jb1starty))
		jb1status(jb1status)
		jb2status(jb2status)
		jb1tenure(jb1tenure)
		earndate(earndate(earndate) earnmth(earnmth) earnyear(earnyear))
		jb1earn(jb1earn(jb1earn) jb1earni(jb1earni))
		jb1wage(jb1wage(jb1wage))
		nonlabinc(nonlabinc)
		jb1hrs(jb1hrs)
		jb1hrsot(jb1hrsot)
		saved(saved)
		invinc(invinc)
		ltwgt_ub(ltwgt_ub)
		ltwgt_ui(ltwgt_ui)
		jbpen(jbpen)
		jbpenm(jbpenm)
		pentype(pentype)
		ownperc(ownperc)
		rawvars(sex hidp pno pidp jbterm1 jbsect jbsectpub jbsize 
				jbsic07_cc jbsoc00_cc j2pay_dv marstat_dv samejob
				ndepchl_dv jbsamr mstatsam mstatsamn lwwrong empchk racel health)
		mindic
		
	)
	
	keepindwoiv
	
	replace

	; 

# delimit cr

* Get other variables that are fed forward from different waves 
 # delimit ;

    bhpsextract	using "$workingdata/bhps_constant_vars",
		waves(1(1)18)
		
		/* indresp */
		indrespoptions(
			edgrpnew(edgrpnew)
			rawvars(sex hid pno pid)
			mindic
		)
		replace;
#delimit cr


# delimit ;

usextract using "$workingdata/usoc_wave1",
		
	waves(1)
	
	/* indresp */
	indrespoptions(
		edgrpnew(edgrpnew)
		rawvars(sex hidp pno pidp racel)
		
	)

	replace

	; 

# delimit cr




