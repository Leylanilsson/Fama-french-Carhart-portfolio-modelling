//Import dataset with stock information
import delimited "/Users/.../"name", numericcols(8 9 11 12)


// Start with creating all veriables that are constant trought the diffrent datasets

* Crate a date variable that stata can reconise
gen date = date(day, "YMD")
format date %td
drop day

* Gen period variable to reconise june each year
gen period = year(date) - 1997 + 1 if month(date) == 6

* Gen periods by year (june t to june t+1)
gen year_period = .

replace year_period = (year(date) - 1997 + 1) if month(date) > 6 & missing(period)
replace year_period = (year(date) - 1996 - 1) if month(date) < 6 & missing(period)
replace year_period = period if month(date) == 6

* Format date_variable
gen date_variable = mofd(date)
format date_variable %tm

*------------------Creating dummy for financials stocks
// If you want to know the diffrence between financial and non-financial stocks otherwise skip or change to desired dummy veriable
 
* Gen a dummy for financials so that 1 = financial stock
gen tmp = isin

inlist2 tmp, values(FI4000297767,GB0007389926,IS0000001469,JE00BLD8Y945,SE0000106304,SE0000106320,SE0000107203,SE0000107401,SE0000107419,SE0000108847,SE0000110165,SE0000110322,SE0000111940,SE0000115610,SE0000120784,SE0000148884,SE0000152084,SE0000164600,SE0000164626,SE0000170110,SE0000170375,SE0000170383,SE0000188500,SE0000188518,SE0000189417,SE0000189425,SE0000189433,SE0000190126,SE0000191090,SE0000193120,SE0000195810,SE0000205932,SE0000205940,SE0000242455,SE0000312043,SE0000371296,SE0000379190,SE0000383259,SE0000391716,SE0000427361,SE0000549412,SE0000588147,SE0000798829,SE0000806994,SE0000936478,SE0000950636,SE0001449380,SE0001785270,SE0001965369,SE0003210590,SE0003652163,SE0004390516,SE0005397106,SE0006887063,SE0007048020,SE0007100599,SE0007100607,SE0007331608,SE0007665823,SE0008321608,SE0008373898,SE0009779796,SE0010100958,SE0010413567,SE0010663302,SE0010663310,SE0011204858,SE0012257970,SE0012454072,SE0012853455,SE0013256674,SE0013719077,SE0014428835,SE0014684510,SE0015192067,SE0015661236,SE0015810239,SE0015810247,SE0015811955,SE0015811963,SE0015949433,SE0016128151,SE0016797732,SE0017082548,SE0017161441,SE0017161458,SE0017831795,SE0018768707)

rename inlist2 financials
drop tmp

// Save to be used for the diffrent sets
save "base_data.dta", replace

*------------------------Dataset with financials included --------------------
use "base_data.dta"

*-----Gen variable for Size
gen size = .

* calculate benchmarks
sort period
by period: egen p_33th = pctile(totalmarketvalue), p(33)
by period: egen p_66th = pctile(totalmarketvalue), p(66)

* Assign grouping
replace size = 1 if totalmarketvalue < p_33th & !missing(totalmarketvalue)
replace size = 2 if totalmarketvalue >= p_33th & !missing(totalmarketvalue)
replace size = 3 if totalmarketvalue >= p_66th & !missing(totalmarketvalue)


*-----Gen variable for BE/ME
gen BEME = bookvalue/marketvalue

* Lagged BE/ME
sort id date
by id: gen lagged_BEME = BEME[_n-1]

* calculate benchmarks
sort period
by period: egen p_30th = pctile(lagged_BEME), p(30)
by period: egen p_70th = pctile(lagged_BEME), p(70)

* Assign grouping
gen BEME_group = .
replace BEME_group = 1 if lagged_BEME < p_30th & !missing(lagged_BEME)
replace BEME_group = 2 if lagged_BEME >= p_30th & !missing(lagged_BEME)
replace BEME_group = 3 if lagged_BEME >= p_70th & !missing(lagged_BEME)


*------Gen veriable for Momentum
sort bidun	
// to see if we had any prices == 0 --> if no we good to go

* Generate prices for last month
sort id date
by id: gen last_month_price = bidun[_n-1] if bidun[_n-1] != 0

* Generate prices for last year (june)
sort id period
by id: gen last_year_price = bidun[_n-1] if period != .

* Generate momentum
sort id date
gen momentum = (last_month_price - last_year_price) / last_year_price if period != .

* calculate benchmarks for momentum
sort period size
by period size : egen p_10th = pctile(momentum), p(10)
by period size : egen p_90th = pctile(momentum), p(90)

* Assign grouping
gen momentum_group = .
replace momentum_group = 1 if momentum <= p_10th & !missing(momentum)
replace momentum_group = 2 if momentum >= p_90th & !missing(momentum)

* drop the benchmarks for sorting
drop  p_30th p_70th p_33th p_66th p_10th p_90th last_month_price last_year_price


*--------------------------------Sorting portfolios-----------------------
* ----- for Size-BEME
* gen portfolios by combining size and BE/ME for each period
gen size_portfolios = "." if month(date) != 6 & year_period > 0
label variable size_portfolios "Marks the new sorted portfolio for each new period"
replace size_portfolios = "S" + string(size) + "BEME" + string(BEME_group) if!missing(size) & !missing(BEME_group) & !missing(period)

* fill in the str for portfolios for the yearly periods
sort id date
gen SBEME_portfolios = size_portfolios
bysort id: replace SBEME_portfolios = SBEME_portfolios[_n-1] if SBEME_portfolios == "."


*--------for Size-MOM
* gen portfolios by combining size and BE/ME for each period
gen mom_portfolios = "." if month(date) != 6 & year_period > 0
label variable mom_portfolios "Marks the new sorted portfolio for each new period"
replace mom_portfolios = "S" + string(size) + "MOM" + string(momentum_group) if!missing(size) & !missing(momentum_group) & !missing(period)

* fill in the str for portfolios for the yearly periods
gen SMOM_portfolios = mom_portfolios
bysort id: replace SMOM_portfolios = SMOM_portfolios[_n-1] if SMOM_portfolios == "."


* ----------------------RETURNS & WEIGHTS----------------------------

*------for Size-BEME
* calculate returns for each stock
gen SBEME_returns = .
by id: replace SBEME_returns = (bidun - bidun[_n-1]) / bidun[_n-1] if missing(SBEME_returns) & !missing(SBEME_portfolios)

* Calculate weights
sort period SBEME_portfolios
by period SBEME_portfolios: egen SBEME_tot_portfolio_mv = total(marketvalue)
label variable SBEME_tot_portfolio_mv "Total portfolio market value for SBEME portfolios"
gen SBEME_weight = totalmarketvalue / SBEME_tot_portfolio_mv if period > 0 & !missing(period)

* Calculate weighted returns to value weight for each period
sort id date
bysort id: replace SBEME_weight = SBEME_weight[_n-1] if SBEME_weight == . & !missing(SBEME_portfolios)
gen SBEME_weighted_return = SBEME_weight * SBEME_returns


* calculate monthly portfolio return 
egen SBEME_tot_Mreturn = total(SBEME_weighted_return), by(date_variable SBEME_portfolios)
label variable SBEME_tot_Mreturn "Total monthly return for SBEME portfolios"
replace SBEME_tot_Mreturn = . if SBEME_weighted_return == .


*------For Size-MOM
* calculate returns for each stock
gen SMOM_returns = .
by id: replace SMOM_returns = (bidun - bidun[_n-1]) / bidun[_n-1] if missing(SMOM_returns) & !missing(SMOM_portfolios)

* Calculate weights
sort period SMOM_portfolios
by period SMOM_portfolios: egen SMOM_tot_portfolio_mv = total(marketvalue)
label variable SMOM_tot_portfolio_mv "Total portfolio market value for SMOM portfolios"
gen SMOM_weight = totalmarketvalue / SMOM_tot_portfolio_mv if period > 0 & !missing(period)

* Calculate weighted returns to value weight for each period
sort id date
bysort id: replace SMOM_weight = SMOM_weight[_n-1] if SMOM_weight == . & !missing(SMOM_portfolios)
gen SMOM_weighted_return = SMOM_weight * SMOM_returns

* calculate monthly portfolio return 
egen SMOM_tot_Mreturn = total(SMOM_weighted_return), by(date_variable SMOM_portfolios)
label variable SMOM_tot_Mreturn "Total monthly return for SMOM portfolios"
replace SMOM_tot_Mreturn = . if SMOM_weighted_return == .


// For data with financials included
save "Data_financials.dta", replace

* --------------Collapse data to prepare for merge-----------
// Importent that you saved you data befor this!!!!!

*--- for size-BEME
collapse  SBEME_tot_Mreturn, by(SBEME_portfolios date_variable)
sort date_variable

* to reshape the data had to add a placeholder for missing values
replace SBEME_portfolios = "Placeholder" if missing(SBEME_portfolios)
reshape wide SBEME_tot_Mreturn, i(date_variable) j(SBEME_portfolios) string
drop SBEME_tot_MreturnPlaceholder

save "collapsed_SBEMEF.dta", replace

*-----for Size-MOM
use "Data_financials.dta"
collapse  SMOM_tot_Mreturn, by(SMOM_portfolios date_variable)
sort date_variable

* to reshape the data had to add a placeholder for missing values
replace SMOM_portfolios = "Placeholder" if missing(SMOM_portfolios)
reshape wide SMOM_tot_Mreturn, i(date_variable) j(SMOM_portfolios) string
drop SMOM_tot_MreturnPlaceholder

save "collapsed_SMOMF.dta", replace

*-----------------------Dataset with financials excluded --------------------
// to not repeat alot of code follow these steps -->

use "base_data.dta" // load data with all constant veriables 

drop if financials == 1 //drop the financial stocks

// now redo all code from line 42 to line 186 to create the Size-BEME & Size-MOM portfolios

// save the data
save "Data_Non-financials.dta", replace


// Now do this step again, note only diffrence is how you name the saved dta files
* --------------Collapse data to prepare for merge-----------
// Importent that you saved you data befor this!!!!!

*--- for size-BEME
collapse  SBEME_tot_Mreturn, by(SBEME_portfolios date_variable)
sort date_variable

* to reshape the data had to add a placeholder for missing values
replace SBEME_portfolios = "Placeholder" if missing(SBEME_portfolios)
reshape wide SBEME_tot_Mreturn, i(date_variable) j(SBEME_portfolios) string
drop SBEME_tot_MreturnPlaceholder

save "collapsed_SBEME.dta", replace

*-----for Size-MOM
use "Data_Non-financials.dta"
collapse  SMOM_tot_Mreturn, by(SMOM_portfolios date_variable)
sort date_variable

* to reshape the data had to add a placeholder for missing values
replace SMOM_portfolios = "Placeholder" if missing(SMOM_portfolios)
reshape wide SMOM_tot_Mreturn, i(date_variable) j(SMOM_portfolios) string
drop SMOM_tot_MreturnPlaceholder

save "collapsed_SMOM.dta", replace


*----------------------FACTORS DATASET--------------------------------------
// to prepare for merge
import delimited "/Users/.../FF4F_monthly.csv" 

* generate the date_variable
gen year = substr(ym, 1, 4)
gen month = substr(ym, 6, .)

* Destring the veriables
destring year, replace
destring month, replace

* Format the date
gen date_variable = ym(year,month)
format date_variable %tm

* some cleaning
drop v1 ym month year
order date_variable, first

save "ff4_monthly.dta", replace

*----------------------COMBINE DATASETS--------------------------------
// from here on the only diffrence will be that you use diffrent sets so to not repeat alot of code i will descibe the way for all sets. and note any diffrence with comments

// load desired dataset from this list
use "collapsed_SMOM.dta"
use "collapsed_SMOMF.dta" // with financial
use "collapsed_SBEME.dta"
use "collapsed_SBEMEF.dta" // with financial

// Merge dataset with the factors
merge 1:1 date_variable using "ff4_monthly.dta"

//Since the factors only goes to 2019 and we had data to 2022 i dropped the outstanding observations also dropped observations befor 1997m6
sort date_variable
drop if _merge == 1 | _merge == 2


*-----Gen the LHS of regression-------------------------
rename date_variable date //Looks better

*----For size-BEME portfolios 
//Portfolios rename, Remove the "F" in S`i'BEME`j'F if the dataset dosnt include financials
forvalues i = 1/3 {
    forvalues j = 1/3 {
        gen S`i'BEME`j'F = SBEME_tot_MreturnS`i'BEME`j'  - rf
    }
}


* Some cleaning and tidy up
// for financial dataset
drop SBEME_tot_MreturnS1BEME1 SBEME_tot_MreturnS1BEME2 SBEME_tot_MreturnS1BEME3 SBEME_tot_MreturnS2BEME1 SBEME_tot_MreturnS2BEME2 SBEME_tot_MreturnS2BEME3 SBEME_tot_MreturnS3BEME1 SBEME_tot_MreturnS3BEME2 SBEME_tot_MreturnS3BEME3 _merge


order S1BEME1F S1BEME2F S1BEME3F S2BEME1F S2BEME2F S2BEME3F S3BEME1F S3BEME2F S3BEME3F, after(date)

save "Combined_SBEMEF.dta", replace

//For Non-financial datasets
drop SBEME_tot_MreturnS1BEME1 SBEME_tot_MreturnS1BEME2 SBEME_tot_MreturnS1BEME3 SBEME_tot_MreturnS2BEME1 SBEME_tot_MreturnS2BEME2 SBEME_tot_MreturnS2BEME3 SBEME_tot_MreturnS3BEME1 SBEME_tot_MreturnS3BEME2 SBEME_tot_MreturnS3BEME3 _merge

order S1BEME1 S1BEME2 S1BEME3 S2BEME1 S2BEME2 S2BEME3 S3BEME1 S3BEME2 S3BEME3, after(date)

save "Combined_SBEME.dta", replace


*----For size-MOM portfolios 
//Portfolios rename, Remove the "F" in S`i'MOM`j'F if the dataset dosnt include financials
forvalues i = 1/3 {
    forvalues j = 1/2 {
        gen S`i'MOM`j'F = SMOM_tot_MreturnS`i'MOM`j' - rf
    }
}



* Some cleaning and tidy up
// for financial dataset
drop SMOM_tot_MreturnS1MOM1 SMOM_tot_MreturnS1MOM2 SMOM_tot_MreturnS2MOM1 SMOM_tot_MreturnS2MOM2 SMOM_tot_MreturnS3MOM1 SMOM_tot_MreturnS3MOM2 _merge

order S1MOM1F S1MOM2F S2MOM1F S2MOM2F S3MOM1F S3MOM2F, after(date)

save "Combined_SMOMF.dta", replace

//For Non-financial datasets
drop SMOM_tot_MreturnS1MOM1 SMOM_tot_MreturnS1MOM2 SMOM_tot_MreturnS2MOM1 SMOM_tot_MreturnS2MOM2 SMOM_tot_MreturnS3MOM1 SMOM_tot_MreturnS3MOM2 _merge
order S1MOM1 S1MOM2 S2MOM1 S2MOM2 S3MOM1 S3MOM2, after(date)

save "Combined_SMOM.dta", replace



*-------------------------------REGRESSIONS--------------------------------------
// Loops over each portfolio and run a separate regression
// Each forlop need to be run directly in the command console and can not be runned truoght the dofile

// load desired dataset from this list
use "Combined_SMOM.dta"
use "Combined_SMOMF.dta" // with financial
use "Combined_SBEME.dta"
use "Combined_SBEMEF.dta" // with financial

// Run one of the local list for the desired portfolio collection before doing the regression loops
**# LOCALS LIST Bookmark
local portfolios S1BEME1 S1BEME2 S1BEME3 S2BEME1 S2BEME2 S2BEME3 S3BEME1 S3BEME2 S3BEME3

local portfolios S1BEME1F S1BEME2F S1BEME3F S2BEME1F S2BEME2F S2BEME3F S3BEME1F S3BEME2F S3BEME3F

local portfolios S1MOM1 S1MOM2 S2MOM1 S2MOM2 S3MOM1 S3MOM2

local portfolios S1MOM1F S1MOM2F S2MOM1F S2MOM2F S3MOM1F S3MOM2F

* CAPM
//paste in list of locals 
foreach port of local portfolios {
    regress `port' rm_rf
}

* Fama-French
//paste in list of locals 
foreach port of local portfolios {
    regress `port' rm_rf smb_ew hml_ew
}

* Carhart
//paste in list of locals 
foreach port of local portfolios {
    regress `port' rm_rf smb_ew hml_ew mom_ew
}



// The doc is more or less organised up to this point
// Here is just code for some data visuals etc need to be altered deepending on dataset

*----------------------DATA VISUALS, ANALYSISES and TESTS-----------------------
// from the whole dataset ie set named "Data_Non-financials.dta" & Data_financials.dta"

* Tab over number of financial stocks in each portfolio in each period
tab size_portfolios period if financials == 1, matcell(N_financials)

* Tab over number of stocks in each portfolio each period
tabulate period size_portfolios


// från collapsed data with factors ie set named "collapsed_S...dta"
*scatter fitted values // change for desired portfolio and factor
twoway (scatter S1BEME1 rm_rf) (lfit S1BEME1 rm_rf)

*---------plot fitted values agaist residuals & graphs combined----------
* CAPM
// run the local list of portfolios you want to use
foreach var of local vars {
    regress `port' rm_rf
	// Save regression --> install outreg2 if not done
	outreg2 using "regression_results.txt", append
    // Run rvfplot and save the plot
     rvfplot, saving(CAPM_`var'F, replace) title("`var'F") // remove "F" if not financials
	
}

// Alter the names for the portfolios if needed, also go change size of plot in the editor
graph combine CAPM_S1BEME1F.gph CAPM_S1BEME2F.gph CAPM_S1BEME3F.gph CAPM_S2BEME1F.gph CAPM_S2BEME2F.gph CAPM_S2BEME3F.gph CAPM_S3BEME1F.gph CAPM_S3BEME2F.gph CAPM_S3BEME3F.gph

* Fama-French 3 factors 
// run the local list of portfolios you want to use
// Might need to exclude the comments for the run to work
foreach var of local vars {
    regress `var' rm_rf smb_ew hml_ew
    // Save regression --> install outreg2 if not done
    outreg2 using "regression_results.txt", append
    // Run rvfplot and save the plot
    rvfplot, saving(FF3F_`var'F, replace) title("`var'F") // remove "F" if not financials
}

// Alter the names for the portfolios if needed, also go change size of plot in the editor
graph combine FF3F_S1BEME1F.gph FF3F_S1BEME2F.gph FF3F_S1BEME3F.gph FF3F_S2BEME1F.gph FF3F_S2BEME2F.gph FF3F_S2BEME3F.gph FF3F_S3BEME1F.gph FF3F_S3BEME2F.gph FF3F_S3BEME3F.gph

* correlation matrix of factors
correlate rm_rf smb_ew hml_ew mom_ew

* line graph of factor returns 
local factors rm_rf smb_ew hml_ew mom_ew
foreach factor of local factors {
twoway (line `factor' date, name(`factor'))
}

graph combine rm_rf smb_ew hml_ew mom_ew, altshrink


* line graph of portfolio returns & graphs combined
// run the local list of portfolios you want to use
foreach port of local portfolios {
twoway (line `port' date, name(line_`port'F)) // remove "F" if not financials
graph save "line_`port'F", replace // remove "F" if not financials
}


// Alter the names for the portfolios if needed
graph combine line_S1BEME1F line_S1BEME2F line_S1BEME3F line_S2BEME1F line_S2BEME2F line_S2BEME3F line_S3BEME1F line_S3BEME2F line_S3BEME3F, altshrink


* Dickey fuller test 
tsset date
// run the local list of portfolios you want to use
foreach port of local portfolios {
    dfuller `port', trend
}

* GRS f-test
grsftest S1MOM1 S1MOM2 S2MOM1 S2MOM2 S3MOM1 S3MOM2, factor(rm_rf smb_ew hml_ew mom_ew ) d


* clear results --> tidy up the console
cls
