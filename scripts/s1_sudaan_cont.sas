


* set home path;
%let homepath = J:\HCHS\STATISTICS\GRAS\QAngarita\HCHS_simulation\Manual_V3;

* define libraries;
libname ch_four 'J:\HCHS\SC\Review\HC3322\CHAPTER4\SAS';

* Set macro variables;
%let data = ch_four.sol_mi_long ;

/* 
	SUDAAN does not provide a BY statement to generate the estimates for each imputed dataset. Therefore the following macro 
	is required to fit the model across the generated datasets. The following macro will be helpful in to generate the estimates
	and obtain a dataset that is suitable for using MIANALIZE.
*/

* Define formats;
proc format;
	value sex_fmt
	0 = 'Female'
	1 = 'Male';
run;



%macro GEE_SUDAAN(nimpute=10, data=,strata=, psu=, wt=, formula=,class=, class_ref);



	


%do j = 1 %to &nimpute.;
	
	%let j = 1;
	%let data = ch_four.sol_mi_long ;
	%let strata = strat;
	%let psu = hh_id_num;
	%let wt = weight_final_norm_overall;
	%let response = sbp5;
	%let covars = bmi agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3 time;
	%let class = agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3;
	%let class_ref = agegroup_c6=6 bkgrd1_c7nomiss=3 centernum=4 sex=0 us_born=0 employed=1 education_c3=1;

	* subset the original dataset ;
	data data;
		set &data.;
		
		if _imputation_ = &j.;

		hh_id_num = input(substr(hh_id, 2),8.);
	run;

	* fit the GEE model using REGRESS procedure;
	proc regress data = data filetype=sas r = independent semethod=zeger notsorted;
		nest &strata. &psu.;	
		weight &wt.;
		class &class.;
		model &response. = &covars.;
		reflevel &class_ref.;
		output beta sebeta p_beta t_beta / filename = est_mi_&j. filetype=sas replace;
		rformat sex sex_fmt.;
	run;	

	* obtain the number of levels for each categorical variable ;



	proc print data = est_mi_1; run;



	* ;
	
%end;

%mend GEE_SUDAAN;
 
%GEE_SUDAAN(data= df,
			strata = strat, psu = hh_id,
			wt = weight_final_norm_overall,
			response = sbp5;
			covars = bmi agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3 sbp5 time,
			class = age_group_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3,
			class_ref = age_group_c6=6 bkgrd1_c7nomiss=3 centernum=4 sex=0 us_born=0 employed=1 education_c3=1);

