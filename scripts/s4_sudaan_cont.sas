/*---------------------------------------------------------------------------------------

Program: s4_sudaan_cont.sas

Purpose: Fit a GEE model for continuous outcomes using SUDAAN's REGRESS procedure
restricted to V3

Author: Quijano-Angarita, A..

Date: October 28, 2025

---------------------------------------------------------------------------------------*/
* Define libraries;
libname lib 'J:\HCHS\SC\Review\HC3322\CHAPTER4\SAS' access=readonly;

* Use a DATA statment to convert hh_id to a numerical variable for SUDAAN;
data db_cont_ipw;
  set lib.sol_ipw_long ;
  ;
  hh_id_num=input(substr(hh_id, 2),8.);
run;

* Fit SUDAAN analysis;
proc regress data=db_cont_ipw filetype=sas r=independent semethod=zeger
  notsorted;
  nest strat hh_id_num;
  weight weight_examonly_ipw_v3;
  subpopn participant_examonly_v3=1;
  class agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3;
  model sbp5=bmi agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed
    education_c3 time;
  reflevel agegroup_c6=6 bkgrd1_c7nomiss=3 centernum=4 sex=0 us_born=0
    employed=1 education_c3=1;
  setenv labwidth=25 decwidth=3;
  print beta="Estimate" sebeta="(S.E)" t_beta="t value" p_beta="p-value";
run;
