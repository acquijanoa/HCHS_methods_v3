/*********************************************************************************************

Macro:  GEE_MI
Purpose:         Fit and pool GEE models across multiple imputations using SUDAAN.
Author:          Alvaro Quijano-Angarita
Created:         2025-10-29

----------------------------------------------------------------------------------------------
Description:
Automates the fitting of GEE models (PROC REGRESS) across multiple imputations
and combines estimates using PROC MIANALYZE.

Arguments:
data:       Input dataset with multiply imputed data.
strata:     Stratification variable for the survey design.
psu:        Primary sampling unit variable.
weight:     Sampling weight variable.
response:   Outcome variable (binary or continuous).
covars:     List of covariates.
class:      Categorical predictor variables.
class_ref:  Reference levels for class variables.
nimpute:    Number of imputations. Default = 10.

Return:
The macro prints a table with estimates but user can accesso to the
dataset `betas_out` that contains the pooled estimates and standard errors.

Dependencies:
Requires SUDAAN and SAS

 *********************************************************************************************/
%macro GEE_MI(data, strata, psu, wt, response, covars, class, class_ref,
	nimpute=10);

	* Turn off all ODS printing before the procedure starts;
	ods exclude all;

	* Loop over each imputed dataset ;
	%do j=1 %to &nimpute.;

		data db;
			set &data.(where=(_imputation_=&j.));
		run;

		* Fit the GEE model using REGRESS or RLOGIST procedure accordingly ;
		proc regress data=db filetype=sas r=independent semethod=zeger
			notsorted;
			nest &strata. &psu.;
			weight &wt.;
			class &class.;
			model &response.=&covars.;
			reflevel &class_ref.;
			output beta sebeta / filename=est_mi_&j. filetype=sas replace;
		run;

		* Prepare the estimates including imputation number and a categorical variable name as 
			SUDAAN does not output variable names directly ;
		data betas_mi_&j.;
			set est_mi_&j.;
			_imputation_=&j.;
			Parm=cats('V_',modelrhs);
			rename beta=Estimate sebeta=StdErr;
		run;
	%end;

	* Combine all datasets with beta estimates into a single dataset;
	data outparms;
		set betas_mi_:;
	run;

	* obtain the maximum number of parameters ;
	proc sql noprint;
		select max(modelrhs) into:maxrhs from outparms;
	quit;

	* create variable list that includes all parameters;
	%let vlist=;
	%do i=1 %to &maxrhs.;
		%let vlist=&vlist. V_&i.;
	%end;

	* Clean up the dataset for MIANALYZE ;
	data outparms;
		set outparms;
		drop modelrhs procnum modelno;
	run;

	* Sort the dataset by imputation number ;
	proc sort data=outparms;
		by _imputation_;
	run;

	* Use MIANALYZE to obtain the final estimates ;
	proc mianalyze parms=outparms;
		modeleffects &vlist.;
		ods output ParameterEstimates=betas_mi(keep=Parm Estimate StdErr tValue
			Probt );
	run;

	* Clean up intermediate datasets ;
	proc datasets library=work nolist;
		delete outparms;
	quit;

	* Call the var_levels macro to create the labels;
	%var_levels(data=&data., covars=&covars., class=&class.);

	* merge datasets;
	proc sort data=betas_mi;
		by Parm;
	run;

	proc sort data=data_out;
		by Parm;
	run;

	data betas_out;
		merge data_out betas_mi;
		by Parm;
		drop Parm;
	run;

	proc sort data=betas_out;
		by Variable ClassVal;
	run;

	* Restore all ODS objects;
	ods exclude none;

	* Print the consolidated dataset;
	proc print data=betas_out nobs;
		title 'Pooled Beta Estimates using SUDAAN';
	run;

%mend GEE_MI;

%macro var_levels(data=, covars=, class=);

	/* Initialize output dataset */
	data data_out;
		length Variable $32 ClassVal 8;
		Variable=" Intercept";
		ClassVal=.;
		output;
	run;

	%let i=1;
	%let cont=1;

	%do %while (%length(%scan(&covars., &i., %str( ))) > 0);
		%let var=%scan(&covars., &i., %str( ));

		%if %sysfunc(findw(&class., &var.)) > 0 %then %do;
			/* Create temp dataset with distinct category values */
			proc sql noprint;
				create table _temp as select distinct "&var." as Variable
					length=32, &var. as ClassVal from &data. where not
					missing(&var.);
			quit;

			/* append */
			proc append base=data_out data=_temp force;
			run;

			%let cont=%eval(&cont. + &sqlobs);
		%end;
		%else %do;
			/* Continuous variable -> one row with missing ClassVal */
			data _temp;
				length Variable $32 ClassVal 8;
				Variable="&var.";
				ClassVal=.;
			run;

			proc append base=data_out data=_temp force;
			run;

			%let cont=%eval(&cont. + 1);
		%end;

		* Clean up temp ;
		proc datasets library=work nolist;
			delete _temp;
		quit;

		* merge with labels;
		data data_out;
			set data_out;
			Parm=cats('V_',_N_);
			Variable=upcase(Variable);
		run;

		%let i=%eval(&i. + 1);
	%end;

%mend var_levels;
