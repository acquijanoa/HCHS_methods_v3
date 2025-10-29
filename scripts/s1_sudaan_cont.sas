* set home path;
%let homepath=J:\HCHS\STATISTICS\GRAS\QAngarita\HCHS_simulation\Manual_V3;

/*---------------------------------------------------------------------------------------

Program: s1_sudaan_cont.sas

Purpose: Fit a GEE model for continuous outcomes using SUDAAN's REGRESS procedure
across multiple imputed datasets and combine the results using MIANALYZE.

Author: Quijano-Angarita, A..

Date: October 21, 2025

Notes:
- This script assumes that the imputed datasets are stored in a single dataset
with an indicator variable '_imputation_' to identify each imputed dataset.
- The macro GEE_SUDAAN fits the GEE model for each imputed dataset and prepares the results for MIANALYZE.
- Ensure that SUDAAN is properly installed and configured to run the REGRESS procedure.
- Modify the macro call at the end of the script to specify the appropriate variables and dataset names.

---------------------------------------------------------------------------------------*/
* Define libraries;
libname ch_four 'J:\HCHS\SC\Review\HC3322\CHAPTER4\SAS' access=readonly;
%include "J:\HCHS\STATISTICS\GRAS\QAngarita\HCHS_methods_V3\scripts\GEE_MI.sas";

* Set macro variables ;
%let data= ch_four.sol_mi_long ;

* Use a DATA statement to convert hh_id to a numerical variable for SUDAAN;
data data;
	set &data.;
	hh_id_num=input(substr(hh_id, 2),8.);
run;

* Call the REGRESS_MI macro to fit the model and obtain estimates ;
%GEE_MI(data=data, 
	strata=strat, 
	psu=hh_id_num, 
	wt=weight_final_norm_overall, 
	response=sbp5, 
	covars=bmi agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3 time, 
	class= agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3,
	class_ref= agegroup_c6=6 bkgrd1_c7nomiss=3 centernum=4 sex=0 us_born=0 employed=1 education_c3=1);

