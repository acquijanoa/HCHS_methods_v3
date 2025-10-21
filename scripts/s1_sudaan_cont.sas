* set home path;
%let homepath = J:\HCHS\STATISTICS\GRAS\QAngarita\HCHS_simulation\Manual_V3;

/*
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
*/


* Define libraries;
libname ch_four 'J:\HCHS\SC\Review\HC3322\CHAPTER4\SAS';

* Set macro variables ;
%let data = ch_four.sol_mi_long ;


/*
	Macro: GEE_SUDAAN
	
	Purpose: Fit a GEE model using SUDAAN's REGRESS procedure across multiple imputed datasets
			 and prepare the results for MIANALYZE.

	Arguments:
	- data: Name of the input dataset containing imputed datasets.
	- strata: Stratification variable for the survey design.
	- psu: Primary sampling unit variable for the survey design.
	- wt: Weight variable for the survey design.
	- response: Dependent variable in the GEE model.
	- covars: Independent variables in the GEE model.
	- class: Categorical variables to be treated as class variables.
	- class_ref: Reference levels for the categorical variables.
	- nimpute: Number of imputed datasets (default is 10).

	Outputs: Dataset 'betas_mi' containing combined parameter estimates suitable for MIANALYZE.

*/
%macro GEE_SUDAAN(data,strata, psu, wt, response, covars,class, class_ref, nimpute=10);

		* Loop over each imputed dataset ;
	%do j = 1 %to &nimpute.;		

		* subset the input to obtain the j-th imputed dataset ;
		data df;
			set &data.;
			
			if _imputation_ = &j. then output;
		run;

		* Fit the GEE model using REGRESS procedure;
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
			* add imputation number ;
			_imputation_ = &j.;
			* create variable names ;
			parm = cats('Var',MODELRHS);
			* rename estimates for MIANALYZE ;
			rename beta = Estimate sebeta = StdErr;
		run;
	%end;
	
	* Combine all datasets with beta estimates into a single dataset;
	data outparms;
		set betas_mi_:;
	run;

	* Create a variable list for MIANALYZE ;
		* obtain the maximum number of parameters ;
		proc sql noprint;
			select max(modelrhs) into:maxrhs
			from outparms;
		quit;
	
		* create variable list that includes all parameters;
		%let vlist=;
			%do i=1 %to &maxrhs.;
				%let vlist= &vlist. Var&i.;
		%end;
		
		* Clean up the dataset for MIANALYZE ;
	data outparms;
		set outparms;
		drop modelrhs procnum modelno;
	run;	

	* Sort the dataset by imputation number ;
	proc sort data = outparms; by _imputation_; run;

	* Use MIANALYZE to obtain the final estimates ;
	proc mianalyze parms = outparms;
		modeleffects &vlist.;
		ods output ParameterEstimates = betas_mi(keep=Parm Estimate StdErr tValue Probt );
	run;

	* Clean up intermediate datasets ;
	proc datasets library=work nolist;
		delete outparms;
	quit;

%mend GEE_SUDAAN;
 

* Use a DATA statment to convert hh_id to a numerical variable for SUDAAN;
data data;
	set &data.;
	hh_id_num = input(substr(hh_id, 2),8.);
run;

* Call the GEE_SUDAAN macro to fit the model and obtain estimates ;
%GEE_SUDAAN(data= data,
			strata = strat, 
			psu = hh_id_num,
			wt = weight_final_norm_overall,
			response = sbp5,
			covars = bmi agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3 time,
			class = agegroup_c6 bkgrd1_c7nomiss centernum sex us_born employed education_c3,
			class_ref = agegroup_c6=6 bkgrd1_c7nomiss=3 centernum=4 sex=0 us_born=0 employed=1 education_c3=1);

* Print the final combined estimates ;
proc print data = betas_mi; run;
	
