
/********************************************************************************
 * This program classifies trade direction using Lee and Ready (1991) algorithm.
 * 
 * The input dataset: 	sample_data;
 *		contains both quotes and trades information.
 * The output dataset:	Lee_ready_result;
 *		contains trade direction indicator and some spread measures.
 *
 * Important:
 *	- Trades at the same time and price are aggregated into one 'trade'.
 *	- Quotes are adjusted for late reporting,
 *		i.e. the last outstanding bid/ask are the bid/ask 5 seconds
 *		before the aggregated trade.
 *	- The program does not guarantee classification results for all trades.
 *		DIR = 1, buyer initiated trade;
 *		DIR = -1, seller inititated trade;
 *		DIR = 0, unclassified trade.
 *	- Unclassified trades could have been assigned a trade indicator if in the
 *	  tick test we go back more than one trade.
 *
 * The program mainly comes from the book:
 * "Using SAS in Financial Research" 2002 by Boehmer, Broussard and Kallunki.
 * ISBN-13: 978-1590470398
 *
 * Adjustments are made by Mingze Gao at 12 Nov 2016.
 * 
 ********************************************************************************/


/* 	Subset the data:
	This data step creates two datasets,
	trades in trade_data and quotes in quote_data.
 */
DATA trade_data quote_data;
	set sample_data (keep= _RIC Date_L_ Time_L_ Type Price Volume Bid Ask);
	MidPt = (Bid + Ask)/2;
	rename _RIC 	=	Symbol;
	rename Date_L_ 	=	Date;
	rename Time_L_ 	=	Time;
	if Type = "Trade" then output trade_data;
	if Type = "Quote" then output quote_data;
RUN;


/* 	Combine trades at the same time and price:
	Aggregate all transactions at the same time and price into one trade.
 */
PROC SORT data= trade_data;
	by Symbol Date Time Price;
PROC MEANS data= trade_data noprint;
	by Symbol Date Time Price;
	output out= adjTrades (rename= (_Freq_= numTrades) drop= _Type_) sum(Volume)= Volume;
RUN;


***	Shows the reduction of trade records by combining trades at the same time and price;
	TITLE "Number of trades in the orginal dataset";
	PROC SUMMARY data= trade_data print;
	TITLE "Number of trades after combining trades at the same time and price";
	PROC SUMMARY data= adjTrades print;
	RUN;


/* 	Tick test:
	Tick test and adjust for late reporting.
 */
DATA ntrades;
	set adjTrades;
	* create unique trade identifier;
	Tid = _N_;
	* advance trades by 5 secs to adjust for late reporting;
	Time_real = Time; 
	Time = Time - 5;
	label Time		= 'trade time - 5 secs';
	label Time_real = 'reported trade time';
	format Time_real Time20.3;
	* compute variable for tick test;
	* note: this step can be modified to look back further than one trade;
	lagPrice  = lag(Price);
	lag2Price = lag2(Price);
	if Price > lagPrice then Tick =  1;
	if Price < lagPrice then Tick = -1;
	if Price = lagPrice then do;
		if lagPrice > lag2Price then Tick =  1;
		if lagPrice < lag2Price then Tick = -1;
	end;
	if _N_ < 3 then Tick = 0;	
	if Tick = . then Tick = 0;
	drop Time_real lagPrice lag2Price;
	label Tick      = 'trade indicator based on tick test';
	label Tid       = 'trade identifier';
	label numTrades = 'number of aggregated trades';
RUN;


*** Print frequency counts for tick test;
	/* Unclassified trades have Tick of 0 */
	TITLE "Frequency analysis of tick test";
	PROC FREQ data= ntrades;
		by Symbol;
		table Tick;
	RUN;


/* 	Compute quote changes:
	If Bid-Ask midpoint changes then it is recorded.
 */
PROC SORT data= quote_data;
	by Symbol Date Time;
DATA allqchange;
	set quote_data;
	by Symbol;
	oldMidPt = lag(MidPt);
	if first.Symbol then oldMidPt = .;
	* create unique quote identifier;
	Qid = _N_;
	* output only if the quote has changed;
	drop oldMidPt;
	label Qid      = 'quote identifier';
	label MidPt = 'quote midpoint';
	if MidPt ne oldMidPt then output;
RUN;


* combine trades and quotes;
DATA qandt;     
	set allqchange (in=a) ntrades (in=b);
	if a then trade = 0;
	if b then trade = 1;
RUN;


/*	Trade direction:
  	Also compute net order flow and various spread measures
 */
PROC SORT data=qandt;
	by symbol date time;
DATA tradeDirection;
	set qandt;
	by symbol date;
	* reset retained variables if a new ticker or new day starts;
	if first.symbol or first.date then do;
		nbid = .; 
		nask = .; 
		currentmidpoint = .; 
	end;
	* assign bid and ask to new variables for retaining;
	if bid      ne . then nbid            = bid;
	if ask      ne . then nask            = ask;
	if MidPt	ne . then currentmidpoint = MidPt;
	* compute spread measures;
	effsprd = abs(price - (nbid+nask)/2) * 2;
	asprd   = nask - nbid;
	rsprd   = asprd / price;
	*** compute variables for trade direction;
	if currentmidpoint ne . then do;
		* quote test - compare current trade to quote: -1 is a sell, +1 is a buy;
		if price < currentmidpoint then ordersign = -1;
		if price > currentmidpoint then ordersign =  1;
		* tick test for midpoint trades;
		if price = currentmidpoint then do;
			if tick =  1 then ordersign =  1;
			if tick = -1 then ordersign = -1;
			if tick =  0 then ordersign =  0;
		end;
		* signed net order flow;
		nof = ordersign * Volume;
	end;
	* labels;
	label nbid      = 'last outstanding bid';
	label nask      = 'last outstanding ask';
	label effsprd   = 'effective spread';
	label asprd     = 'absolute spread';
	label rsprd     = 'relative spread';
	label nof       = 'net order flow';
	label ordersign = 'indicator for trade direction';
	* output to data set;
	if trade = 1 then output tradeDirection;
	retain nbid nask currentmidpoint;
	drop bid ask MidPt qid trade type;
RUN;


***	Trade direction classification result;
	TITLE 'Order sign classification';
	PROC FREQ data= tradeDirection;
		by symbol;
		tables ordersign;
	RUN;


DATA Lee_Ready_result;
	set tradeDirection;
	Time = Time + 5;
	label Time				= 'Trade time';
	rename nbid				= Bid;
	rename nask				= Ask;
	rename ordersign		= DIR;
	rename currentmidpoint 	= MidPt;
	drop tid tick;
RUN;



/* Delete the temporary datasets */
PROC DATASETS lib= work nolist;
	delete adjtrades allqchange ntrades qandt quote_data tradedirection trade_data;
QUIT;
