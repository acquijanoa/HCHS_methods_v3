


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


%macro GEE_SUDAAN(data,strata, psu, wt, response, covars,class, class_ref, nimpute=3);

		* Loop over each imputed dataset ;
	%do j = 1 %to &nimpute.;		
	/* 
		%let j = 1;
		%let data = ch_four.sol_mi_long ;
		%let strata = strat;
		%let psu = hh_id_num;
		%let wt = weight_final_norm_overall;
		%let response = sbp5;
		%let covars = bmi agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3 time;
		%let class = agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3;
		%let class_ref = agegroup_c6=6 bkgrd1_c7nomiss=3 centernum=4 sex=0 us_born=0 employed=1 education_c3=1;
	*/

		* subset the original dataset ;
		data df;
			set &data.;
			
			if _imputation_ = &j. then output;
		run;

		* fit the GEE model using REGRESS procedure;
		proc regress data = df filetype=sas r = independent semethod=zeger notsorted;
			nest &strata. &psu.;	
			weight &wt.;
			class &class.;
			model &response. = &covars.;
			reflevel &class_ref.;
			output beta sebeta  / filename = est_mi_&j. filetype=sas replace;
		run;	

		* obtain the number of levels for each categorical variable ;
		data betas_mi_&j.;
			set est_mi_&j.;

			_imputation_ = &j.;
			
			parm = cats('Var',MODELRHS);

			rename beta = Estimate sebeta = StdErr;
		run;
	%end;
	
	data outparms;
		set betas_mi_:;
	run;

	proc sql noprint;
		select max(modelrhs) into:maxrhs
		from outparms;
	quit;
	
	%let vlist=;
	%do i=1 %to &maxrhs.;
		%let vlist= &vlist. Var&i.;
	%end;

	data outparms;
		set outparms;
		drop modelrhs procnum modelno;
	run;	

	proc sort data = outparms; by _imputation_; run;
	proc mianalyze parms = outparms;
		modeleffects &vlist.;
		ods output ParameterEstimates = betas_mi(keep=Parm Estimate StdErr tValue Probt );
	run;

	proc datasets library=work nolist;
		delete outparms;
	quit;

%mend GEE_SUDAAN;
 

* Convert hh_id to a numerical variable;
data data;
	set &data.;
	hh_id_num = input(substr(hh_id, 2),8.);
run;

* ;
%GEE_SUDAAN(data= data,
			strata = strat, 
			psu = hh_id_num,
			wt = weight_final_norm_overall,
			response = sbp5,
			covars = bmi agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3 time,
			class = agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3,
			class_ref = agegroup_c6=6 bkgrd1_c7nomiss=3 centernum=4 sex=0 us_born=0 employed=1 education_c3=1);

proc print data = betas_mi; run;
	
