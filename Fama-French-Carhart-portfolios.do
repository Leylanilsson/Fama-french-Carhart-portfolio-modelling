// Starting with creating all veriables that are constant trought the diffrent datasets

 * Crate a date variable stata can reconise
gen date = date(day, "YMD")
format date %td
drop day

* Gen period variable to reconise june each year
gen period = year(date) - 1997 + 1 if month(date) == 6

* gen periods by year (june t to june t+1)
gen year_period = .

replace year_period = (year(date) - 1997 + 1) if month(date) > 6 & missing(period)
replace year_period = (year(date) - 1996 - 1) if month(date) < 6 & missing(period)
replace year_period = period if month(date) == 6

* format date_variable
gen date_variable = mofd(date)
format date_variable %tm
rename date_variable date

* save data as dta file
save "base_data.dta", replace

*------------------------Creating veriables--------------------
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
sort bidun	// to see if we had any prices == 0 --> no so we good

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
sort period
by period: egen p_10th = pctile(momentum), p(10)
by period: egen p_90th = pctile(momentum), p(90)

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

// Here maybe we can dropthese-->?? size BEME lagged_BEME BEME_group momentum momentum_group
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
egen SBEME_tot_Mreturn = total(SBEME_weighted_return), by(date SBEME_portfolios)
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
egen SMOM_tot_Mreturn = total(SMOM_weighted_return), by(date SMOM_portfolios)
label variable SMOM_tot_Mreturn "Total monthly return for SMOM portfolios"
replace SMOM_tot_Mreturn = . if SMOM_weighted_return == .

* Save data
save "data.dta", replace

* --------------Collapse data to prepare for merge-----------
// Importent that you saved you data befor this!!!!!

*--- for size-BEME
use "data.dta"
collapse  SBEME_tot_Mreturn, by(SBEME_portfolios date)
sort date

* to reshape the data had to add a placeholder for missing values
drop if SBEME_portfolios == "."
reshape wide SBEME_tot_Mreturn, i(date) j(SBEME_portfolios) string

save "collapsed_SBEME.dta", replace

*-----for Size-MOM
use "data.dta"
rename mom_portfolios SMOM_portfolios
collapse  SMOM_tot_Mreturn, by(SMOM_portfolios date)
sort date

* to reshape the data had to add a placeholder for missing values
drop if SMOM_portfolios == "."
reshape wide SMOM_tot_Mreturn, i(date) j(SMOM_portfolios) string

save "collapsed_SMOM.dta", replace


*----------------------COMBINE DATASETS--------------------------------
// here combine your datasets with factors

// load desired dataset from this list
use "collapsed_SMOM.dta"
use "collapsed_SBEME.dta"

// Merge dataset with the factors data
merge 1:1 common_veriable using "factor_dataset_name.dta"

sort common_veriable
drop if _merge == 1 | _merge == 2

save "combined_data.dta"
*-----Gen the LHS of regression-------------------------
*----For size-BEME portfolios 
forvalues i = 1/3 {
    forvalues j = 1/3 {
        gen S`i'BEME`j' = SBEME_tot_MreturnS`i'BEME`j'  - rf
    }
}


* Some cleaning and tidy up
drop SBEME_tot_MreturnS1BEME1 SBEME_tot_MreturnS1BEME2 SBEME_tot_MreturnS1BEME3 SBEME_tot_MreturnS2BEME1 SBEME_tot_MreturnS2BEME2 SBEME_tot_MreturnS2BEME3 SBEME_tot_MreturnS3BEME1 SBEME_tot_MreturnS3BEME2 SBEME_tot_MreturnS3BEME3 _merge


order S1BEME1 S1BEME2 S1BEME3 S2BEME1 S2BEME2 S2BEME3 S3BEME1 S3BEME2 S3BEME3, after(date)



*----For size-MOM portfolios 
//Portfolios rename, Remove the "F" in S`i'MOM`j'F if the dataset dosnt include financials
forvalues i = 1/3 {
    forvalues j = 1/2 {
        gen S`i'MOM`j'F = SMOM_tot_MreturnS`i'MOM`j' - rf
    }
}


* Some cleaning and tidy up
drop SMOM_tot_MreturnS1MOM1 SMOM_tot_MreturnS1MOM2 SMOM_tot_MreturnS2MOM1 SMOM_tot_MreturnS2MOM2 SMOM_tot_MreturnS3MOM1 SMOM_tot_MreturnS3MOM2 _merge
order S1MOM1 S1MOM2 S2MOM1 S2MOM2 S3MOM1 S3MOM2, after(date)


*-------------------------------REGRESSIONS--------------------------------------

use "combined_data.dta"


local portfolios S1BEME1 S1BEME2 S1BEME3 S2BEME1 S2BEME2 S2BEME3 S3BEME1 S3BEME2 S3BEME3 S1MOM1 S1MOM2 S2MOM1 S2MOM2 S3MOM1 S3MOM2



* CAPM
local portfolios S1BEME1 S1BEME2 S1BEME3 S2BEME1 S2BEME2 S2BEME3 S3BEME1 S3BEME2 S3BEME3 S1MOM1 S1MOM2 S2MOM1 S2MOM2 S3MOM1 S3MOM2
foreach port of local portfolios {
    regress `port' rm_rf
}

* Fama-French
local portfolios S1BEME1 S1BEME2 S1BEME3 S2BEME1 S2BEME2 S2BEME3 S3BEME1 S3BEME2 S3BEME3 S1MOM1 S1MOM2 S2MOM1 S2MOM2 S3MOM1 S3MOM2
foreach port of local portfolios {
    regress `port' rm_rf smb_ew hml_ew
}

* Carhart
local portfolios S1BEME1 S1BEME2 S1BEME3 S2BEME1 S2BEME2 S2BEME3 S3BEME1 S3BEME2 S3BEME3 S1MOM1 S1MOM2 S2MOM1 S2MOM2 S3MOM1 S3MOM2
foreach port of local portfolios {
    regress `port' rm_rf smb_ew hml_ew mom_ew
}
