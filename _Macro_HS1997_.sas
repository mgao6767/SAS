/********************************************************************************
 * This macro calculates the Huang and Stoll (1997) adverse selection measure, 
 * which is the proportional adverse selection component of the spread.
 *
 * The input dataset: 	Lee_Ready_result;
 *		The inputDataset can contain transactions of multile securities for
 *		more than one day.
 *		The only requirement is that the trades are assigned direction (DIR).
 *		Variables in the input datasets should include:
 *			Symbol	:	security identifier, like ISIN or ticker;
 *			Date	:	transaction date;
 *			Time	:	transaction time;
 *			Asprd	: 	absolute spread;
 *			MidPt	:	spread midpoint;
 *			Dir		:	transaction direction,
 *						1 for buyer-initiated and -1 for seller-initiated;
 *
 * The output dataset:	HS1997;
 *		contains the Huang and Stoll (1997) measure 
 *		for each stock for each day.
 * 
 * Important:
 *	- Unclassified trades are removed from the dataset.
 *	- This program estimates an equation system using two methods:
 *		2SLS, two stage least square;
 *		GMM, generalised method of moments.
 *		The GMM method is the one used in Huang and Stoll (1997) and other studies.
 *	- This program does not have the requirement on pi, the probability of reversal,
 *		while the model might require pi > 0.5. When this requirement is needed,
 *		user can make the change in the PROC MODEL.
 *	- If pi > 0.5 is required, then the adverse selection measure (alpha) is not
 *		statistically significant under both methods.
 *
 * This program is written by Mingze Gao first for his Honours thesis,
 * but later refined at 16 Nov 2016.
 *
 ********************************************************************************/


%macro HS1997 (inputDataset= );
		
	DATA transaction;
		set &inputDataset (keep= Symbol Date Time Dir Asprd MidPt);
		by Symbol Date;
		/* Unclassified trades are removed from the dataset */
		if DIR = 1 or DIR = -1;

		/* New Var = Change of Bid-Ask Midpoint */
		D_MidPt = MidPt - lag(MidPt);
		/* New Var = Lagged absolute spread */
		lagASprd = lag(Asprd);
		lag2ASprd = lag2(Asprd);
		/* New Var = Lagged trade direction indicator */
		lagDir = lag(Dir);
		lag2Dir = lag2(Dir);

		/* There should be no lagged variable */
		secondDateOrSymbol = lag(first.Date) or lag(first.Symbol);
		if first.Date or first.Symbol or secondDateOrSymbol then delete;

		keep Symbol Date Time D_MidPt lagDir lag2Dir lagASprd lag2ASprd;
	RUN;


	PROC MODEL data= transaction noprint;
		by Symbol Date;
		parms alpha beta pi;
		eq.m1 = lagDir - (1 - 2 * pi) * lag2Dir;
		eq.m2 = D_MidPt - (alpha + beta) * lagASprd/2 * lagDir 
				- alpha * (1 - 2 * pi) * lag2ASprd/2 * lag2Dir;
		fit m1 m2 / gmm 2sls outest= coef;
		* bounds pi > 0.5;
	QUIT;


	DATA HS1997 (keep= Symbol Date _TYPE_ HS1997);
		set coef;
		rename alpha = HS1997;
	RUN;


	/* Delete the temporary datasets */
	PROC DATASETS lib= work nolist;
		delete coef transaction;
	QUIT;

%mend HS1997;



/* Call the Macro, input dataset is Lee_Ready_result */
%HS1997(inputDataset = Lee_Ready_result);


