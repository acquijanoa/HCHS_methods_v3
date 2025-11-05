* set home path;
%let homepath=J:\HCHS\STATISTICS\GRAS\QAngarita\HCHS_simulation\Manual_V3;

/*---------------------------------------------------------------------------------------

	Program: s4_sudaan_bin.sas

	Purpose: Fit a GEE model for binary outcomes using SUDAAN's REGRESS procedure
				restricted to V3

	Author: Quijano-Angarita, A..

	Date: October 28, 2025

---------------------------------------------------------------------------------------*/
* Define libraries;
libname lib 'J:\HCHS\SC\Review\HC3322\CHAPTER5\SAS' access=readonly;

* Set macro variables ;
%let data= lib.sol_ipw_long ;

* Use a DATA statment to convert hh_id to a numerical variable for SUDAAN;
data hypert_data;
	set lib.sol_ipw_long ;

	* Convert PSU to numerical id;
	hh_id_num = input(substr(hh_id, 2),8.);
run;

* Fit SUDAAN analysis; 
proc rlogist data=data filetype=sas r=independent semethod=zeger notsorted;
			nest strat hh_id_num;
			weight WEIGHT_EXAMONLY_IPW_V3;
			subpopn PARTICIPANT_EXAMONLY_V3 = 1;
			class agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3;
			model hypertension2 = bmi agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3 time;
			reflevel agegroup_c6=6 bkgrd1_c7nomiss=3 centernum=4 sex=0 us_born=0 employed=1 education_c3=1;
			output beta sebeta / filename=estimates filetype=sas replace;
run;
