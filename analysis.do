set scheme s1color //good looking graph theme
ssc install mylabels // installed for clean axis look
cd "P:\JPI_PENSINEQ\Inequalities\Summer_student\analysis\jack_repo\pension-inequalities-code"
use "$workingdata/usoc_clean", clear 
gsort pidp wave 
tab racel

*new aggregate race variable - useful when over time
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

cd "P:\JPI_PENSINEQ\Inequalities\Summer_student\analysis\output"
preserve
collapse (mean) ownperc ownperc_cond jbpenm [pw=rxwgt], by(raceb)
format jbpenm ownperc ownperc_cond %3.2f 
/*mylabels 0(.2).8, clean local(labels) //change 0.0 to 0 on y axis
twoway bar jbpenm raceb, ylabel(`labels', grid format(%03.1f)) xlabel(1 2 3 4 5 6 7 8 9 10, angle(45) valuelabel) ytitle("Pension Membership (%)") color(orange) barwidth(0.6) plotregion(margin(zero)) xtitle("")
*/
graph bar jbpenm, over(raceb, label(angle(45))) ytitle("Membership Rate (%)")
graph export "pension_mem.pdf", replace

*unconditional
graph bar ownperc, over(raceb, label(angle(45))) ytitle("Unconditional Contribution Rate (%)")
graph export "pension_cont.pdf", replace

*conditional
graph bar ownperc_cond, over(raceb, label(angle(45))) ytitle("Conditional Contribution Rate (%)")
graph export "pension_cont_c.pdf", replace

restore
