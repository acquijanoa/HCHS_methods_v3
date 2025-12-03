/*---------------------------------------------------------------------------------------

	Program: s1_sudaan_cont.sas

	Purpose: Fit a GEE model for continuous outcomes using SUDAAN's REGRESS procedure
	across multiple imputed datasets and combine the results using MIANALYZE.

	Author: Quijano-Angarita, A..

	Date: October 21, 2025

---------------------------------------------------------------------------------------*/
* Define libraries;
libname lib 'J:\HCHS\SC\Review\HC3001-HC4000\HC3322\CHAPTER4\SAS' access=readonly;
%include "J:\HCHS\STATISTICS\GRAS\QAngarita\HCHS_methods_V3\scripts\GEE_MI.sas";

* Use a DATA statement to convert hh_id to a numerical variable for SUDAAN;
data db_sudaan_mi;
	set lib.sol_mi_long; 
	hh_id_num=input(substr(hh_id, 2),8.);
run;

* Call the REGRESS_MI macro to fit the model and obtain estimates ;
%GEE_MI(data=db_sudaan_mi, 
	strata=strat, 
	psu=hh_id_num, 
	weight=weight_final_norm_overall, 
	response=sbp5, 
	covars=bmi agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3 time, 
	class= agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3,
	class_ref= agegroup_c6=6 bkgrd1_c7nomiss=3 centernum=4 sex=0 us_born=0 employed=1 education_c3=1);

