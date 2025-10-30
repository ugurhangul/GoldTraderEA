//+------------------------------------------------------------------+
//|                                                ChartPatterns.mqh |
//|                                      Copyright 2023, Gold Trader   |
//|                                  REDESIGNED FOR OPTIMAL ENTRY TIMING |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

#include "ChartPatternsImpl.mqh"

// External timeframe variable
extern ENUM_TIMEFRAMES CHP_Timeframe;

// Chart pattern recognition constants (calibrated values, do not change)
const double CHP_Early_Entry_ATR_Multiplier = 0.5;    // Early entry: distance from neckline in ATR (calibrated)
const double CHP_Min_ADX_Trend = 25.0;                // Minimum ADX for trend validation (calibrated)
const double CHP_SR_Proximity_Percent = 0.01;         // S/R proximity tolerance 1% (calibrated)
const bool CHP_Require_Trend_Alignment = true;        // Require pattern to align with trend (best practice)
const bool CHP_Require_SR_Confirmation = true;        // Require S/R level confirmation (best practice)
const double CHP_Pattern_Quality_Min_Score = 60.0;    // Minimum pattern quality score 0-100 (calibrated)
const bool CHP_Use_Pattern_Specific_SL = true;        // Use pattern-specific stop loss (best practice)

// Import functions from main EA file
#import "GoldTraderEA.mq5"
   void DebugPrint(string message);
   bool GetDebugMode();
   void ResetExternalPatternCache();
#import

// External indicator arrays and handles from main EA
extern int handle_adx;
extern int handle_ma_fast;
extern int handle_ma_slow;
extern int handle_atr;
extern double adx[];
extern double ma_fast[];
extern double ma_slow[];
extern double atr[];

// Note: support_levels[], resistance_levels[], support_count, resistance_count
// are defined in SupportResistance.mqh which is included in the main EA
// They are globally available and don't need extern declaration here

// Define static variables with appropriate prefixes
// FIX: Separate cache timestamps to prevent race condition between buy and sell checks
static datetime s_chp_last_buy_check_time = 0;
static datetime s_chp_last_sell_check_time = 0;
static bool s_chp_cached_pattern_results[10] = {false, false, false, false, false, false, false, false, false, false};
static int s_chp_cached_buy_count = -1;
static int s_chp_cached_sell_count = -1;
static double s_chp_pattern_quality_scores[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
static double s_chp_pattern_stop_loss[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

// Define constants for magic numbers
const int MIN_COPIED_RATES = 50;
const int CACHE_SIZE = 10;

// Pattern type constants for stop loss calculation
const int PATTERN_DOUBLE_BOTTOM = 0;
const int PATTERN_HEAD_SHOULDERS_BOTTOM = 1;
const int PATTERN_ASCENDING_TRIANGLE = 2;
const int PATTERN_CUP_HANDLE = 3;
const int PATTERN_BULLISH_WEDGE = 4;
const int PATTERN_DOUBLE_TOP = 5;
const int PATTERN_HEAD_SHOULDERS_TOP = 6;
const int PATTERN_DESCENDING_TRIANGLE = 7;
const int PATTERN_BEARISH_WEDGE = 8;
const int PATTERN_DIAMOND_TOP = 9;

//+------------------------------------------------------------------+
//| Helper: Check if price is near support/resistance level          |
//+------------------------------------------------------------------+
bool IsPriceNearSRLevel(double price, const double &levels[], int count, double tolerance_percent)
{
    double tolerance = price * tolerance_percent;
    for(int i = 0; i < count; i++) {
        if(MathAbs(price - levels[i]) <= tolerance) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Helper: Validate trend alignment using MA and ADX                |
//+------------------------------------------------------------------+
bool ValidateTrendAlignment(bool is_bullish)
{
    if(!CHP_Require_Trend_Alignment)
        return true;

    // Check if we have enough indicator data
    if(ArraySize(adx) < 1 || ArraySize(ma_fast) < 1 || ArraySize(ma_slow) < 1) {
        if(GetDebugMode()) DebugPrint("CHP: Insufficient indicator data for trend validation");
        return false;
    }

    // Check ADX for trend strength
    if(adx[0] < CHP_Min_ADX_Trend) {
        if(GetDebugMode()) DebugPrint("CHP: ADX too low for trend: " + DoubleToString(adx[0], 2));
        return false;
    }

    // Check MA alignment for trend direction
    bool ma_bullish = ma_fast[0] > ma_slow[0];
    bool trend_aligned = (is_bullish && ma_bullish) || (!is_bullish && !ma_bullish);

    if(!trend_aligned && GetDebugMode()) {
        DebugPrint("CHP: Trend not aligned - Pattern: " + (is_bullish ? "Bullish" : "Bearish") +
                   ", MA: " + (ma_bullish ? "Bullish" : "Bearish"));
    }

    return trend_aligned;
}

//+------------------------------------------------------------------+
//| Helper: Check if pattern is forming at key S/R level             |
//+------------------------------------------------------------------+
bool ValidateSRConfirmation(double pattern_level, bool is_support)
{
    if(!CHP_Require_SR_Confirmation)
        return true;

    if(is_support) {
        // For bullish patterns, check if forming near support
        if(support_count == 0) return false;
        return IsPriceNearSRLevel(pattern_level, support_levels, support_count, CHP_SR_Proximity_Percent);
    } else {
        // For bearish patterns, check if forming near resistance
        if(resistance_count == 0) return false;
        return IsPriceNearSRLevel(pattern_level, resistance_levels, resistance_count, CHP_SR_Proximity_Percent);
    }
}

//+------------------------------------------------------------------+
//| Helper: Check for early entry opportunity                        |
//+------------------------------------------------------------------+
bool IsEarlyEntryOpportunity(MqlRates &rates[], double key_level, bool is_bullish)
{
    if(ArraySize(rates) < 1 || ArraySize(atr) < 1)
        return false;

    double current_price = rates[0].close;
    double atr_value = atr[0];
    double entry_distance = CHP_Early_Entry_ATR_Multiplier * atr_value;

    if(is_bullish) {
        // For bullish patterns, enter when price approaches neckline from below
        // Price should be within 0.5 ATR below the breakout level
        return (current_price >= key_level - entry_distance && current_price <= key_level);
    } else {
        // For bearish patterns, enter when price approaches neckline from above
        // Price should be within 0.5 ATR above the breakout level
        return (current_price <= key_level + entry_distance && current_price >= key_level);
    }
}

//+------------------------------------------------------------------+
//| Validate chart data                                               |
//+------------------------------------------------------------------+
bool ValidateChartData()
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), CHP_Timeframe, 0, 100, rates);
    
    if(copied < MIN_COPIED_RATES) {
        if(GetDebugMode()) DebugPrint("Error: Not enough data for chart pattern analysis");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect inverse head and shoulders pattern                         |
//+------------------------------------------------------------------+
bool IsHeadAndShouldersBottom()
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), CHP_Timeframe, 0, 50, rates);
    
    if(copied < 50) return false;
    
    return IsInverseHeadAndShoulders(rates);
}

//+------------------------------------------------------------------+
//| Detect head and shoulders pattern                                  |
//+------------------------------------------------------------------+
bool IsHeadAndShouldersTop()
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), CHP_Timeframe, 0, 50, rates);
    
    if(copied < 50) return false;
    
    return IsHeadAndShoulders(rates);
}

//+------------------------------------------------------------------+
//| Detect diamond top pattern                                         |
//+------------------------------------------------------------------+
bool IsDiamondTop()
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), CHP_Timeframe, 0, 50, rates);

    // FIX: Validate array size before accessing specific indices
    if(copied < 50) return false;

    int size = ArraySize(rates);
    if(size < 50) return false;

    // This is a simplified Diamond Top pattern detection
    // In a real implementation, you would have a more sophisticated algorithm

    // FIX: Add bounds checking before accessing array elements
    // Check for a rapid rise followed by volatility and then a decline
    if(size <= 49 || size <= 30) return false;
    bool has_uptrend = rates[49].close < rates[30].close;
    bool has_volatility = false;

    double avg_range = 0;
    // FIX: Ensure loop bounds are within array size
    int avg_end = MathMin(30, size);
    for(int i = 20; i < avg_end; i++) {
        if(i >= size) break;
        avg_range += rates[i].high - rates[i].low;
    }
    avg_range /= (avg_end - 20);

    double volatility_range = 0;
    // FIX: Ensure loop bounds are within array size
    int vol_end = MathMin(20, size);
    for(int i = 10; i < vol_end; i++) {
        if(i >= size) break;
        volatility_range += rates[i].high - rates[i].low;
    }
    volatility_range /= (vol_end - 10);

    has_volatility = (volatility_range > avg_range * 1.5);

    // FIX: Validate array access before comparison
    if(size <= 10) return false;
    bool has_decline = rates[0].close < rates[10].close;

    return has_uptrend && has_volatility && has_decline;
}

//+------------------------------------------------------------------+
//| Check chart patterns for buy - REDESIGNED                         |
//+------------------------------------------------------------------+
int CheckChartPatternsBuy()
{
    // Use cache for performance improvement
    datetime current_time = TimeCurrent();

    // FIX: Use separate buy cache timestamp to prevent race condition with sell checks
    if(current_time - s_chp_last_buy_check_time < PeriodSeconds(CHP_Timeframe) && s_chp_cached_buy_count >= 0)
        return s_chp_cached_buy_count;

    int confirmations = 0;

    // Quick check for validation
    if(!ValidateChartData()) {
        s_chp_last_buy_check_time = current_time;
        s_chp_cached_buy_count = 0;
        return 0;
    }

    // Validate trend alignment first (fail fast if trend is wrong)
    if(!ValidateTrendAlignment(true)) {
        if(GetDebugMode()) DebugPrint("CHP Buy: Trend validation failed");
        s_chp_last_buy_check_time = current_time;
        s_chp_cached_buy_count = 0;
        return 0;
    }

    // Reset pattern cache
    for(int i=0; i<10; i++) {
        s_chp_cached_pattern_results[i] = false;
        s_chp_pattern_quality_scores[i] = 0;
        s_chp_pattern_stop_loss[i] = 0;
    }

    // Get rate data for pattern detection
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), CHP_Timeframe, 0, 100, rates);

    if(copied < MIN_COPIED_RATES) return 0;

    double neckline = 0, quality_score = 0;

    // Double Bottom - with early entry and quality scoring
    if(IsDoubleBottom(rates, neckline, quality_score)) {
        if(quality_score >= CHP_Pattern_Quality_Min_Score) {
            // Check S/R confirmation
            if(ValidateSRConfirmation(neckline, true)) {
                // Check for early entry opportunity
                if(IsEarlyEntryOpportunity(rates, neckline, true)) {
                    s_chp_cached_pattern_results[PATTERN_DOUBLE_BOTTOM] = true;
                    s_chp_pattern_quality_scores[PATTERN_DOUBLE_BOTTOM] = quality_score;
                    if(CHP_Use_Pattern_Specific_SL)
                        s_chp_pattern_stop_loss[PATTERN_DOUBLE_BOTTOM] = CalculatePatternStopLoss(rates, PATTERN_DOUBLE_BOTTOM, true);
                    confirmations++;
                    if(GetDebugMode()) DebugPrint("CHP: Double Bottom detected - Quality: " + DoubleToString(quality_score, 1) +
                                                   ", Neckline: " + DoubleToString(neckline, 5));
                }
            }
        }
    }

    // Head and Shoulders Bottom
    if(IsHeadAndShouldersBottom()) {
        // Get neckline and quality from the pattern
        MqlRates hs_rates[];
        ArraySetAsSeries(hs_rates, true);
        CopyRates(Symbol(), CHP_Timeframe, 0, 50, hs_rates);

        if(IsInverseHeadAndShoulders(hs_rates, neckline, quality_score)) {
            if(quality_score >= CHP_Pattern_Quality_Min_Score) {
                if(ValidateSRConfirmation(neckline, true)) {
                    if(IsEarlyEntryOpportunity(rates, neckline, true)) {
                        s_chp_cached_pattern_results[PATTERN_HEAD_SHOULDERS_BOTTOM] = true;
                        s_chp_pattern_quality_scores[PATTERN_HEAD_SHOULDERS_BOTTOM] = quality_score;
                        if(CHP_Use_Pattern_Specific_SL)
                            s_chp_pattern_stop_loss[PATTERN_HEAD_SHOULDERS_BOTTOM] = CalculatePatternStopLoss(rates, PATTERN_HEAD_SHOULDERS_BOTTOM, true);
                        confirmations++;
                        if(GetDebugMode()) DebugPrint("CHP: Inverse H&S detected - Quality: " + DoubleToString(quality_score, 1));
                    }
                }
            }
        }
    }

    // Ascending Triangle
    double resistance = 0;
    if(IsAscendingTriangle(rates, resistance, quality_score)) {
        if(quality_score >= CHP_Pattern_Quality_Min_Score) {
            if(ValidateSRConfirmation(resistance, false)) {  // Resistance level
                if(IsEarlyEntryOpportunity(rates, resistance, true)) {
                    s_chp_cached_pattern_results[PATTERN_ASCENDING_TRIANGLE] = true;
                    s_chp_pattern_quality_scores[PATTERN_ASCENDING_TRIANGLE] = quality_score;
                    if(CHP_Use_Pattern_Specific_SL)
                        s_chp_pattern_stop_loss[PATTERN_ASCENDING_TRIANGLE] = CalculatePatternStopLoss(rates, PATTERN_ASCENDING_TRIANGLE, true);
                    confirmations++;
                    if(GetDebugMode()) DebugPrint("CHP: Ascending Triangle detected - Quality: " + DoubleToString(quality_score, 1));
                }
            }
        }
    }

    // Cup and Handle
    double breakout_level = 0;
    if(IsCupAndHandle(rates, breakout_level, quality_score)) {
        if(quality_score >= CHP_Pattern_Quality_Min_Score) {
            if(ValidateSRConfirmation(breakout_level, false)) {
                if(IsEarlyEntryOpportunity(rates, breakout_level, true)) {
                    s_chp_cached_pattern_results[PATTERN_CUP_HANDLE] = true;
                    s_chp_pattern_quality_scores[PATTERN_CUP_HANDLE] = quality_score;
                    if(CHP_Use_Pattern_Specific_SL)
                        s_chp_pattern_stop_loss[PATTERN_CUP_HANDLE] = CalculatePatternStopLoss(rates, PATTERN_CUP_HANDLE, true);
                    confirmations++;
                    if(GetDebugMode()) DebugPrint("CHP: Cup & Handle detected - Quality: " + DoubleToString(quality_score, 1));
                }
            }
        }
    }

    // Bullish Wedge (Falling Wedge)
    double upper_line = 0;
    if(IsBullishWedge(rates, upper_line, quality_score)) {
        if(quality_score >= CHP_Pattern_Quality_Min_Score) {
            if(ValidateSRConfirmation(upper_line, true)) {
                if(IsEarlyEntryOpportunity(rates, upper_line, true)) {
                    s_chp_cached_pattern_results[PATTERN_BULLISH_WEDGE] = true;
                    s_chp_pattern_quality_scores[PATTERN_BULLISH_WEDGE] = quality_score;
                    if(CHP_Use_Pattern_Specific_SL)
                        s_chp_pattern_stop_loss[PATTERN_BULLISH_WEDGE] = CalculatePatternStopLoss(rates, PATTERN_BULLISH_WEDGE, true);
                    confirmations++;
                    if(GetDebugMode()) DebugPrint("CHP: Bullish Wedge detected - Quality: " + DoubleToString(quality_score, 1));
                }
            }
        }
    }

    // Store result in cache
    s_chp_last_buy_check_time = current_time;
    s_chp_cached_buy_count = confirmations;

    if(confirmations > 0 && GetDebugMode()) {
        DebugPrint("CHP Buy: Total confirmations = " + IntegerToString(confirmations));
    }

    return confirmations;
}

//+------------------------------------------------------------------+
//| Check chart patterns for sell - REDESIGNED                        |
//+------------------------------------------------------------------+
int CheckChartPatternsShort()
{
    // Use cache for performance improvement
    datetime current_time = TimeCurrent();

    // FIX: Use separate sell cache timestamp to prevent race condition with buy checks
    if(current_time - s_chp_last_sell_check_time < PeriodSeconds(CHP_Timeframe) && s_chp_cached_sell_count >= 0)
        return s_chp_cached_sell_count;

    int confirmations = 0;

    // Quick check for validation
    if(!ValidateChartData()) {
        s_chp_last_sell_check_time = current_time;
        s_chp_cached_sell_count = 0;
        return 0;
    }

    // Validate trend alignment first (fail fast if trend is wrong)
    if(!ValidateTrendAlignment(false)) {
        if(GetDebugMode()) DebugPrint("CHP Short: Trend validation failed");
        s_chp_last_sell_check_time = current_time;
        s_chp_cached_sell_count = 0;
        return 0;
    }

    // Get rate data for pattern detection
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), CHP_Timeframe, 0, 100, rates);

    if(copied < MIN_COPIED_RATES) return 0;

    double neckline = 0, quality_score = 0;

    // Double Top - with early entry and quality scoring
    if(IsDoubleTop(rates, neckline, quality_score)) {
        if(quality_score >= CHP_Pattern_Quality_Min_Score) {
            if(ValidateSRConfirmation(neckline, false)) {  // Resistance level
                if(IsEarlyEntryOpportunity(rates, neckline, false)) {
                    s_chp_cached_pattern_results[PATTERN_DOUBLE_TOP] = true;
                    s_chp_pattern_quality_scores[PATTERN_DOUBLE_TOP] = quality_score;
                    if(CHP_Use_Pattern_Specific_SL)
                        s_chp_pattern_stop_loss[PATTERN_DOUBLE_TOP] = CalculatePatternStopLoss(rates, PATTERN_DOUBLE_TOP, false);
                    confirmations++;
                    if(GetDebugMode()) DebugPrint("CHP: Double Top detected - Quality: " + DoubleToString(quality_score, 1) +
                                                   ", Neckline: " + DoubleToString(neckline, 5));
                }
            }
        }
    }

    // Head and Shoulders Top
    if(IsHeadAndShouldersTop()) {
        MqlRates hs_rates[];
        ArraySetAsSeries(hs_rates, true);
        CopyRates(Symbol(), CHP_Timeframe, 0, 50, hs_rates);

        if(IsHeadAndShoulders(hs_rates, neckline, quality_score)) {
            if(quality_score >= CHP_Pattern_Quality_Min_Score) {
                if(ValidateSRConfirmation(neckline, true)) {  // Support level
                    if(IsEarlyEntryOpportunity(rates, neckline, false)) {
                        s_chp_cached_pattern_results[PATTERN_HEAD_SHOULDERS_TOP] = true;
                        s_chp_pattern_quality_scores[PATTERN_HEAD_SHOULDERS_TOP] = quality_score;
                        if(CHP_Use_Pattern_Specific_SL)
                            s_chp_pattern_stop_loss[PATTERN_HEAD_SHOULDERS_TOP] = CalculatePatternStopLoss(rates, PATTERN_HEAD_SHOULDERS_TOP, false);
                        confirmations++;
                        if(GetDebugMode()) DebugPrint("CHP: H&S Top detected - Quality: " + DoubleToString(quality_score, 1));
                    }
                }
            }
        }
    }

    // Descending Triangle
    double support = 0;
    if(IsDescendingTriangle(rates, support, quality_score)) {
        if(quality_score >= CHP_Pattern_Quality_Min_Score) {
            if(ValidateSRConfirmation(support, true)) {  // Support level
                if(IsEarlyEntryOpportunity(rates, support, false)) {
                    s_chp_cached_pattern_results[PATTERN_DESCENDING_TRIANGLE] = true;
                    s_chp_pattern_quality_scores[PATTERN_DESCENDING_TRIANGLE] = quality_score;
                    if(CHP_Use_Pattern_Specific_SL)
                        s_chp_pattern_stop_loss[PATTERN_DESCENDING_TRIANGLE] = CalculatePatternStopLoss(rates, PATTERN_DESCENDING_TRIANGLE, false);
                    confirmations++;
                    if(GetDebugMode()) DebugPrint("CHP: Descending Triangle detected - Quality: " + DoubleToString(quality_score, 1));
                }
            }
        }
    }

    // Bearish Wedge (Rising Wedge)
    double lower_line = 0;
    if(IsBearishWedge(rates, lower_line, quality_score)) {
        if(quality_score >= CHP_Pattern_Quality_Min_Score) {
            if(ValidateSRConfirmation(lower_line, false)) {  // Resistance
                if(IsEarlyEntryOpportunity(rates, lower_line, false)) {
                    s_chp_cached_pattern_results[PATTERN_BEARISH_WEDGE] = true;
                    s_chp_pattern_quality_scores[PATTERN_BEARISH_WEDGE] = quality_score;
                    if(CHP_Use_Pattern_Specific_SL)
                        s_chp_pattern_stop_loss[PATTERN_BEARISH_WEDGE] = CalculatePatternStopLoss(rates, PATTERN_BEARISH_WEDGE, false);
                    confirmations++;
                    if(GetDebugMode()) DebugPrint("CHP: Bearish Wedge detected - Quality: " + DoubleToString(quality_score, 1));
                }
            }
        }
    }

    // Diamond Top - simplified check (no quality scoring for now)
    if(IsDiamondTop()) {
        s_chp_cached_pattern_results[PATTERN_DIAMOND_TOP] = true;
        s_chp_pattern_quality_scores[PATTERN_DIAMOND_TOP] = 70.0;  // Default score
        confirmations++;
        if(GetDebugMode()) DebugPrint("CHP: Diamond Top detected");
    }

    // Store result in cache
    s_chp_last_sell_check_time = current_time;
    s_chp_cached_sell_count = confirmations;

    if(confirmations > 0 && GetDebugMode()) {
        DebugPrint("CHP Short: Total confirmations = " + IntegerToString(confirmations));
    }

    return confirmations;
}

//+------------------------------------------------------------------+
//| Reset chart patterns cache                                         |
//+------------------------------------------------------------------+
void ResetChartPatternsCache()
{
    s_chp_last_buy_check_time = 0;
    s_chp_last_sell_check_time = 0;
    s_chp_cached_buy_count = -1;
    s_chp_cached_sell_count = -1;

    for(int i=0; i<10; i++) {
        s_chp_cached_pattern_results[i] = false;
        s_chp_pattern_quality_scores[i] = 0;
        s_chp_pattern_stop_loss[i] = 0;
    }

    // Announcement to the main file that the cache has been reset.
    ResetExternalPatternCache();
}

//+------------------------------------------------------------------+
//| Get pattern quality score for specific pattern                    |
//+------------------------------------------------------------------+
double GetPatternQualityScore(int pattern_index)
{
    if(pattern_index >= 0 && pattern_index < 10)
        return s_chp_pattern_quality_scores[pattern_index];
    return 0;
}

//+------------------------------------------------------------------+
//| Get pattern-specific stop loss for specific pattern               |
//+------------------------------------------------------------------+
double GetPatternStopLoss(int pattern_index)
{
    if(pattern_index >= 0 && pattern_index < 10)
        return s_chp_pattern_stop_loss[pattern_index];
    return 0;
}