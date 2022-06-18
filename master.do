/********************************************************************************
**** Title: 		master_usoc.do 
**** Author: 		Laurence O'Brien 
**** Date started: 	20/08/2021 
**** Description:	Master do file for USoc analysis as part of Nuffield project
********************************************************************************/
* Clear stata
clear all
macro drop _all
set more off

* Filepath globals
global project_root "P:/JPI_PENSINEQ/Inequalities/Summer_student/analysis"
global code "$project_root/pension-inequalities-code"
global workingdata "$project_root/data"
global output "$project_root/output"

* Other globals
global graphconfig "graphregion(color(white)) bgcolor(white)"

**** Run project programs ****

*do "$dofiles/extract_usoc"  // extracts a dataset with pension variables using the USoc Extractor
do "$dofiles/clean_usoc" 
*main // clean the extracted dataset 
do "$dofiles/analysis_usoc"
*main // do analysis 
