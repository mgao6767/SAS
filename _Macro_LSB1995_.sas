/********************************************************************************
 * This macro calculates the Lin, Sanger and Booth (1995) measure, which is
 * the proportional adverse selection component of the spread.
 *
 * The input dataset: 	Lee_Ready_result;
 *		The inputDataset can contain transactions of multile securities for
 *		more than one day.
 *		The only requirement is that the trades are assigned direction (DIR).
 *		Variables in the input datasets should include:
 *			Symbol	:	security identifier, like ISIN or ticker;
 *			Date	:	transaction date;
 *			Time	:	transaction time;
 *			Price	: 	transaction price;
 *			Volume	:	transaction volume;
 *			Dir		:	transaction direction,
 *						1 for buyer-initiated and -1 for seller-initiated;
 *
 * The output dataset:	LSB1995;
 *		contains the Lin, Sanger and Booth (1995) measure 
 *		for each stock for each day.
 * 
 * Important:
 *	- Unclassified trades are removed from the dataset.
 *	- As in Lin, Sanger and Booth (1995), the logarithms of transaction price
 *		and the quote midpoint are used to yield a (continuously compounded)
 *		rate of return for the dependent variable and a relative spread for
 *		the independent	variable.
 *
 * This program is written by Mingze Gao first for his Honours thesis,
 * but later refined at 16 Nov 2016.
 *
 ********************************************************************************/


%macro LSB1995 (inputDataset= );

	PROC SORT data= &inputDataset;
		by Symbol Date Time;
	RUN;

	DATA transaction;
		set &inputDataset (keep= Symbol Date Time Price Dir MidPt);
		by Symbol Date;
		/* Unclassified trades are removed from the dataset */
		if DIR = 1 or DIR = -1;
		log_Price = log(Price);
		log_MidPt = log(MidPt);

		/* New Var = change of Bid-Ask Midpoint */
		D_MidPt = log_MidPt - lag(log_MidPt);
		
		/* New Var = signed effective half spread, 
			positive for buy order and negative for sell order */
		E_spread = DIR * abs(log_PRICE - log_MIDPT);

		/* New Var = lagged signed effective half spread */
		lag_E_spread = lag(E_spread);

		/* There should be no lagged variable */
		if first.Date or first.Symbol then delete;

		keep Symbol Date Time D_MidPt lag_E_spread;
	RUN;


	PROC REG data= transaction noprint outest= coef;
		by Symbol Date;
		Lin1995: model D_MidPt = lag_E_spread;
	RUN;


	DATA LSB1995;
		set coef (keep= Symbol Date lag_E_spread);
		rename lag_E_spread = LSB1995;
	RUN;


	/* Delete the temporary datasets */
	PROC DATASETS lib= work nolist;
		delete coef transaction;
	QUIT;

%mend LSB1995;



/* Call the Macro, input dataset is Lee_Ready_result */
%LSB1995(inputDataset = Lee_Ready_result);


