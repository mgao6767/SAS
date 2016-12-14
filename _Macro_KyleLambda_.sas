/********************************************************************************
 * This macro calculates the Kyle (1985) Lambda measure. 
 * It follows Hasbrouck (2009) and Goyenko, Holden, Trzcinka (2009).
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
 * The output dataset:	KyleLambda;
 *		contains the Kyle (1985) Lambda measure for each stock for each day.
 * 
 * Important:
 *	- Unclassified trades are removed from the dataset.
 *	- The return in each 5-min time bracket is calculated using log return.
 *	- The final result is the actual Lambda multiplied by 10^6.
 *
 * This program is written by Mingze Gao first for his Honours thesis,
 * but later refined at 15 Nov 2016.
 *
 ********************************************************************************/


%macro Kyle_Lambda (inputDataset= );

	PROC SORT data= &inputDataset;
		by Symbol Date Time;
	RUN;

	DATA transaction;
		set &inputDataset (keep= Symbol Date Time Price Volume Dir);
		by Symbol Date;
		/* Unclassified trades are removed from the dataset */
		if DIR = 1 or DIR = -1;
		retain timeBracket 0;
		retain startBracket 0;
		retain cumSumSignedRootVolume 0;
		format startBracket time20.3;
		if first.Date then do;
			timeBracket = 0;
			startBracket = 0;
			cumSumSignedRootVolume = 0;
		end;
		/* Within a 5 min time bracket */
		if TIME >= startBracket and TIME - startBracket < 300 then do;	
			timeBracket = timeBracket;
			cumSumSignedRootVolume = cumSumSignedRootVolume + DIR * sqrt(VOLUME);
		end;
		/* A new 5min time bracket */
		else do;
			timeBracket = timeBracket + 1;					
			startBracket = TIME;
			cumSumSignedRootVolume = DIR * sqrt(VOLUME);
		end;
	RUN;


	DATA transaction2 (drop= lastPrice cumSumSignedRootVolume);
		set transaction;
		by Symbol Date timeBracket;
		if first.timeBracket or last.timeBracket;
		lastPrice = lag(Price);
		if last.timeBracket then do;
			sumSignedRootVolume = cumSumSignedRootVolume;
			/* The return is calculated using log return */
			bracketReturn = log(Price) - log(lastPrice);
		end;
		if not last.timeBracket then delete;
	RUN;


	PROC REG data= transaction2 noprint outest= coef;
		by Symbol Date;
		Kyle1985: model bracketReturn = sumSignedRootVolume;
	RUN;													

	/* The final result is the actual Lambda multiplied by 10^6 */
	DATA KyleLambda (keep= Symbol Date KyleLambda_6);
		set coef (keep= Symbol Date sumSignedRootVolume);
		KyleLambda_6 = sumSignedRootVolume * 1000000;
	RUN;


	/* Delete the temporary datasets */
	PROC DATASETS lib= work nolist;
		delete coef transaction transaction2;
	QUIT;

%mend Kyle_Lambda;



/* Call the Macro, input dataset is Lee_Ready_result */
%Kyle_Lambda(inputDataset = Lee_Ready_result);

