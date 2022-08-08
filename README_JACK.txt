Title: Inequalities in pension saving by ethnicity
--------------------------------------------------

Description of do files, found at:
P:\JPI_PENSINEQ\Inequalities\Summer_student\analysis\jack_repo\pension-inequalities-code

============================================================================================================================
master.do: clears stata, creates filepath globals, runs project programs
============================================================================================================================
extract_usoc.do: uses the USoc extractor to get the desired variables from USOC
============================================================================================================================
clean_usoc.do: cleans extracted USoc data
============================================================================================================================
analysis_usoc.do: creates output for analysis
============================================================================================================================


Detail on analysis_usoc.do
--------------------------
NOTES: - output for powerpoint in excel format but also often in .tex format for latex output
       - retirement income expectations only asked to those aged 45,50,55 so limited sample size
       - the year 2020 is dropped from graphs of pension participation over time due to limited sample size
       - raceb = 10 are those with missing values for their race/ethnicity - often dropped
       - AE starts in Oct 2012, by Feb 2018 AE applied to all employers
       - problems with job tenure variable - not been cleaned yet - needed to get correct measure of AE eligibility


start: sets scheme colour (changes graph background from blue to white etc); installs commands for analysis

sample_stat: sample size table for pre/post AE by ethnicity; graph of retirement income expectations by ethnicity;
 table on % self-employed by ethnicity

graph_over_time: graphs of pension participation, contribution rates by ethnicity over time: for workers,
 for restricted sample of those eligible for AE, for further restricted sample of those eligible for AE and offered a pension 

bar_restrict: bar chart of pension participation for workers, eligible for AE, and eligible+offered by ethnicity;
 bar chart of % eligible for AE by ethnicity for workers; bar chart of % offered pension by ethnicity for eligible employees

covariates_graphs: distribution of age by ethnicity; scatter of pension vars by age;
 scatter of pension vars by ethnicity and age; distribution of real weekly earnings by ethnicity

regression_post: regression output of pension participation and contribution rates post AE by ethnicity

by_sex: coefficient plots of regression model with all controls pre/post AE by ethnicity,
 with separate regressions for men/women

============================================================================================================================
