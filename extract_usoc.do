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

* Main dataset (except wave 8 because ff_ukborn isn't in it for some reason)
# delimit ;

usextract using "$workingdata/usoc_extracted",
		
	waves(2 3 4 5 6 7 9 10)
			

	/* hhresp */
	hhrespoptions(
		hhintdate(hhintdate)
		hhrxwgt(hhrxwgt)
		ivfho(ivfho)
		hvalue(hvalue)
		tenure(tenure)
		totmortgage(totmortgage)
		monthlymortgage(monthlymortgage)
		rawvars(hidp tenure_dv rent_dv houscost1_dv houscost2_dv)
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
		ppen(ppen)
		ppreg(ppreg)
		ppram(ppram)
		pprampc(pprampc) 
		rawvars(sex hidp pno pidp jbterm1 jbsect jbsectpub jbsize 
				jbsic07_cc jbsoc00_cc j2pay_dv marstat_dv samejob
				ndepchl_dv jbsamr mstatsam mstatsamn lwwrong empchk racel 
				health ageret retamt retsuf rtfnd1 rtfnd2 rtfnd3 rtfnd4 rtfnd5 
				rtfnd6 rtfnd7 rtfnd8 rtfnd9 rtfnd10 rtfnd96 ff_ukborn ukborn oprlg oprlg1 nirel)
		mindic
		
	)
	
	keepindwoiv
	
	replace

	; 

# delimit cr

* UK born was weird in this wave so get it separately
# delimit ;

usextract using "$workingdata/usoc_extracted_wave8",
		
	waves(8)
			

	/* hhresp */
	hhrespoptions(
		hhintdate(hhintdate)
		hhrxwgt(hhrxwgt)
		ivfho(ivfho)
		hvalue(hvalue)
		tenure(tenure)
		totmortgage(totmortgage)
		monthlymortgage(monthlymortgage)
		rawvars(hidp tenure_dv rent_dv houscost1_dv houscost2_dv)
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
		ppen(ppen)
		ppreg(ppreg)
		ppram(ppram)
		pprampc(pprampc) 
		rawvars(sex hidp pno pidp jbterm1 jbsect jbsectpub jbsize 
				jbsic07_cc jbsoc00_cc j2pay_dv marstat_dv samejob
				ndepchl_dv jbsamr mstatsam mstatsamn lwwrong empchk racel 
				health ageret retamt retsuf rtfnd1 rtfnd2 rtfnd3 rtfnd4 rtfnd5 
				rtfnd6 rtfnd7 rtfnd8 rtfnd9 rtfnd10 rtfnd96 ukborn oprlg oprlg1 nirel)
		mindic
		
	)
	
	keepindwoiv
	
	replace

	; 

# delimit cr

* Get other variables that are fed forward from different waves 
* Get religion and original BHPS race variable (race)
# delimit ;

    bhpsextract	using "$workingdata/bhps_constant_vars1",
		waves(1 7 9)
		
		/* indresp */
		indrespoptions(
			edgrpnew(edgrpnew)
			jb1status(jb1status)
			jb1start(jb1startd(jb1startd) jb1startm(jb1startm) jb1starty(jb1starty))
			jb1tenure(jb1tenure)
			gor(region)
			intdate(intdate(intdate) intyear(intyear) intmonth(intmonth))
			spellstart(startday(startday) startmonth(startmonth) startyear(startyear))
			rawvars(sex hid pno pid race plbornc plbornd oprlg1)
			mindic
		)
		replace;
#delimit cr

* Waves with original BHPS race variable (race) but no religion variable
# delimit ;

    bhpsextract	using "$workingdata/bhps_constant_vars2",
		waves(2 3 4 5 6 8 10 11 12)
		/* note that wave 11 does have oprlg1 but it's mainly missing so not bothering getting it */
		
		/* indresp */
		indrespoptions(
			edgrpnew(edgrpnew)
			jb1status(jb1status)
			jb1start(jb1startd(jb1startd) jb1startm(jb1startm) jb1starty(jb1starty))
			jb1tenure(jb1tenure)
			gor(region)
			intdate(intdate(intdate) intyear(intyear) intmonth(intmonth))
			spellstart(startday(startday) startmonth(startmonth) startyear(startyear))
			rawvars(sex hid pno pid race plbornc plbornd)
			mindic
		)
		replace;
#delimit cr

* Waves with new BHPS race variable (racel) and religion variable
 # delimit ;

    bhpsextract	using "$workingdata/bhps_constant_vars3",
		waves(14 18)
		
		/* indresp */
		indrespoptions(
			edgrpnew(edgrpnew)
			jb1status(jb1status)
			jb1start(jb1startd(jb1startd) jb1startm(jb1startm) jb1starty(jb1starty))
			jb1tenure(jb1tenure)
			gor(region)
			intdate(intdate(intdate) intyear(intyear) intmonth(intmonth))
			spellstart(startday(startday) startmonth(startmonth) startyear(startyear))
			rawvars(sex hid pno pid racel plbornc plbornd oprlg1)
			mindic
		)
		replace;
#delimit cr

* Waves with new BHPS race variable (racel) and no religion variable
 # delimit ;

    bhpsextract	using "$workingdata/bhps_constant_vars4",
		waves(13 15 16 17)
		
		/* indresp */
		indrespoptions(
			edgrpnew(edgrpnew)
			jb1status(jb1status)
			jb1start(jb1startd(jb1startd) jb1startm(jb1startm) jb1starty(jb1starty))
			jb1tenure(jb1tenure)
			gor(region)
			intdate(intdate(intdate) intyear(intyear) intmonth(intmonth))
			spellstart(startday(startday) startmonth(startmonth) startyear(startyear))
			rawvars(sex hid pno pid racel plbornc plbornd)
			mindic
		)
		replace;
#delimit cr


* Wave 1 of USoc
# delimit ;

usextract using "$workingdata/usoc_wave1",
		
	waves(1)
	
	/* indresp */
	indrespoptions(
		intdate(intdate(intdate) intyear(intyear) intmonth(intmonth))
		edgrpnew(edgrpnew)
		jb1status(jb1status)
		gor(region)
		jb1start(jb1startd(jb1startd) jb1startm(jb1startm) jb1starty(jb1starty))
		jb1tenure(jb1tenure)
		rawvars(sex hidp pno pidp racel ukborn oprlg1 oprlg nirel)
		
	)

	replace

	; 

# delimit cr




