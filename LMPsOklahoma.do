* Evaluating LMPs emissions

******* Housekeeping;
# delimit ;             * assign ';' as line-ender;
version 13;           * tell Stata to use version 13, so that code will still work in future versions;
clear;                * clear anything in memory left over from previous runs;
capture log close;    * close log from previous runs (capture prevents error if no log was open);
set more off;         * allow log to be outputted without requiring keypresses;
set logtype text; 
clear matrix;
clear mata;


cd /Users/jho81/Desktop/SummerWork/pnodelip;          * set working directory;



log using LMPSOklahoma.log, replace;        *start log file;
set matsize 2000;      * set largest matrix size;
set memory 256m;       * set memory to 256 MB;


****************************************REGRESSIONS FOR TOU***********************************;

clear all;
import delimited lip_by_pnode_201107.csv;

gen str centralDate = substr(hour_ending_cpt, 1, 8);
gen str centralTime = substr(hour_ending_cpt, 10,4);
gen double edateCentral = date(centralDate, "YMD") * 24 * 60 * 60 * 1000;
gen double etimeCentral = clock(centralTime, "hm");
format edateCentral %td;
drop hour_ending_gmt;
gen double timeStamp = edateCentral + etimeCentral;
format timeStamp %tc;
gen dayOfWeek = dow(dofc(timeStamp));
local 6hours = 1000 * 60 * 60 * 4;
* number of milliseconds in 4 hours;

replace dayOfWeek = 7 if dayOfWeek ==0;

save lmpjuly.dta, replace;

clear all;
import delimited lip_by_pnode_201108.csv;

gen str centralDate = substr(hour_ending_cpt, 1, 8);
gen str centralTime = substr(hour_ending_cpt, 10,4);
gen double edateCentral = date(centralDate, "YMD") * 24 * 60 * 60 * 1000;
gen double etimeCentral = clock(centralTime, "hm");
format edateCentral %td;
drop hour_ending_gmt;
gen double timeStamp = edateCentral + etimeCentral;
format timeStamp %tc;
gen dayOfWeek = dow(dofc(timeStamp));
save lmpaugust.dta, replace;

clear all;
import delimited lip_by_pnode_201109.csv;

gen str centralDate = substr(hour_ending_cpt, 1, 8);
gen str centralTime = substr(hour_ending_cpt, 10,4);
gen double edateCentral = date(centralDate, "YMD") * 24 * 60 * 60 * 1000;
gen double etimeCentral = clock(centralTime, "hm");
format edateCentral %td;

drop hour_ending_gmt;
gen double timeStamp = edateCentral + etimeCentral;
format timeStamp %tc;
gen dayOfWeek = dow(dofc(timeStamp));

save lmpseptember.dta, replace;

clear all;
use lmpjuly.dta;
append using lmpaugust.dta;
append using lmpseptember.dta;


gen month = month(date(centralDate, "YMD"));
gen day = day(date(centralDate, "YMD"));

gen hour = mod((hh(timeStamp) - 1), 24);
drop if dayOfWeek > 5;

egen LMPnode = group(pnode);
list LMPnode, nolabel;

keep if LMPnode <= 276 & LMPnode >= 236;

cd /Users/jho81/Desktop/SummerWork;


merge m:1 month day hour using CEMS_Emissions_SPP_Aggregated-2011.dta;
drop _merge;
drop if lmp == .;
drop year so2pounds noxpounds co2shorttons heatinput* grossloadmw co2pounds hour_ending*;

save lmpSPP.dta, replace;

#delimit;

clear all; 
use dataAnalysisSortedVPP.dta;

keep bsdewp* bstemp* month day hour;
collapse (first) bsdewp* bstemp*, by (month day hour);
save VPP_tempSplines.dta, replace;

clear all;
use lmpSPP.dta;
merge m:1 month day hour using VPP_tempSplines.dta;
drop if _merge != 3;
drop _merge;

gen VPPDay = 1;	

 
replace VPPDay = 2 if month == 7 & day == 1 | month == 7 & day == 5 | 
month == 7 & day == 6 | month == 7 & day == 11 | month == 7 & day == 12 | 
month == 8 & day == 11 | month == 8 & day == 12 | month == 8 & day == 15 | 
month == 8 & day == 16 | month == 8 & day == 26 | month == 8 & day == 29 |
 month == 8 & day == 31 | month == 9 & day == 2 | month == 9 & day == 13 ;

replace VPPDay = 3 if month == 7 & day == 7  | month == 7 & day == 8 |
month == 7 & day == 13 | month == 7 & day == 14 | month == 7 & day == 15 | 
month == 7 & day == 18 | month == 7 & day == 19 | month == 7 & day == 20 | 
month == 7 & day == 21 | month == 7 & day == 22 | month == 7 & day == 25 | 
month == 7 & day == 26 | month == 7 & day == 27 | month == 7 & day == 28 | 
month == 7 & day == 29 | month == 8 & day == 9 | month == 8 & day == 10 | 
month == 8 & day == 17 | month == 8 & day == 18 | month == 8 & day == 19 | 
month == 8 & day == 22 | month == 8 & day == 23 | month == 8 & day == 24 | 
month == 8 & day == 25 | month == 8 & day == 30 | month == 9 & day == 1;

replace VPPDay = 4 if month == 8 & day == 1 | month == 8 & day == 2 | 
month == 8 & day == 3 | month == 8 & day == 4 | month == 8 & day == 5 | 
month == 8 & day == 8;

replace VPPDay = 5 if month == 7 & day == 8 | month == 7 & day == 15 | 
month == 8 & day == 8 | month == 8 & day == 24 | month == 9 & day == 1 | 
month == 9 & day == 13 | month == 9 & day == 27;

gen lmp_Predict = 0;
gen lmp_stdp = 0;
#delimit;
sort month day hour LMPnode;
forval vppIndex = 2/5 {;
forval tt = 0/23 {;
   reg lmp if hour == `tt' & VPPDay == `vppIndex', vce(cluster LMPnode);
   replace lmp_Predict = _b[_cons] if hour == `tt' & VPPDay == `vppIndex';
   replace lmp_stdp = _se[_cons] if hour == `tt' & VPPDay == `vppIndex';
};
};


*getting an average LMP for all of the nodes in the OGE area, for each hour

#delimit;
collapse (first) lmp_Predict lmp_stdp, by (VPPDay hour);
replace lmp_Predict = lmp_Predict/10^3;
replace lmp_stdp = lmp_stdp/10^3;
save  LMP_aggregates.dta, replace;

