//+------------------------------------------------------------------+
//|                                                ChartPatterns.mqh |
//|                                      Copyright 2023, Gold Trader   |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

#include "ChartPatternsImpl.mqh"

// External timeframe variable
extern ENUM_TIMEFRAMES CHP_Timeframe;

#import "GoldTraderEA_cleaned.mq5"
void DebugPrint(string message);
bool GetDebugMode();
void ResetExternalPatternCache();
#import

// Define static variables with appropriate prefixes
static datetime s_chp_last_pattern_check_time = 0;
static bool s_chp_cached_pattern_results[10] = {false, false, false, false, false, false, false, false, false, false};
static int s_chp_cached_buy_count = -1;
static int s_chp_cached_sell_count = -1;

// Declare pattern detection functions - using #import instead of extern
#import "ChartPatternsImpl.mqh"
   bool IsDoubleTop(MqlRates &rates[]);
   bool IsDoubleBottom(MqlRates &rates[]);
   bool IsHeadAndShoulders(MqlRates &rates[]);
   bool IsInverseHeadAndShoulders(MqlRates &rates[]);
   bool IsBullishFlag(MqlRates &rates[]);
   bool IsBearishFlag(MqlRates &rates[]);
   bool IsCupAndHandle(MqlRates &rates[]);
   bool IsAscendingTriangle(MqlRates &rates[]);
   bool IsDescendingTriangle(MqlRates &rates[]);
   bool IsBullishWedge(MqlRates &rates[]);
   bool IsBearishWedge(MqlRates &rates[]);
   void ResetPatternCache();
#import 

// Define constants for magic numbers
const int MIN_COPIED_RATES = 50;
const int CACHE_SIZE = 10;

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
    
    if(copied < 50) return false;
    
    // This is a simplified Diamond Top pattern detection
    // In a real implementation, you would have a more sophisticated algorithm
    
    // Check for a rapid rise followed by volatility and then a decline
    bool has_uptrend = rates[49].close < rates[30].close;
    bool has_volatility = false;
    
    double avg_range = 0;
    for(int i = 20; i < 30; i++) {
        avg_range += rates[i].high - rates[i].low;
    }
    avg_range /= 10;
    
    double volatility_range = 0;
    for(int i = 10; i < 20; i++) {
        volatility_range += rates[i].high - rates[i].low;
    }
    volatility_range /= 10;
    
    has_volatility = (volatility_range > avg_range * 1.5);
    
    bool has_decline = rates[0].close < rates[10].close;
    
    return has_uptrend && has_volatility && has_decline;
}

//+------------------------------------------------------------------+
//| Check chart patterns for buy                                       |
//+------------------------------------------------------------------+
int CheckChartPatternsBuy()
{
    // Use cache for performance improvement
    datetime current_time = TimeCurrent();
    
    // If still in the same candle and cached result exists
    if(current_time - s_chp_last_pattern_check_time < PeriodSeconds(CHP_Timeframe) && s_chp_cached_buy_count >= 0)
        return s_chp_cached_buy_count;
    
    int confirmations = 0;
    
    // Quick check for validation
    if(!ValidateChartData()) {
        s_chp_last_pattern_check_time = current_time;
        s_chp_cached_buy_count = 0;
        return 0;
    }
    
    // Reset pattern cache
    for(int i=0; i<10; i++)
        s_chp_cached_pattern_results[i] = false;
    
    // Get rate data for pattern detection
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), CHP_Timeframe, 0, 100, rates);
    
    if(copied < MIN_COPIED_RATES) return 0;
    
    // Double Bottom
    if(IsDoubleBottom(rates)) {
        s_chp_cached_pattern_results[0] = true;
        confirmations++;
    }
    
    // Head and Shoulders Bottom
    if(IsHeadAndShouldersBottom()) {
        s_chp_cached_pattern_results[1] = true;
        confirmations++;
    }
    
    // Ascending Triangle
    if(IsAscendingTriangle(rates)) {
        s_chp_cached_pattern_results[2] = true;
        confirmations++;
    }
    
    // Cup and Handle
    if(IsCupAndHandle(rates)) {
        s_chp_cached_pattern_results[3] = true;
        confirmations++;
    }
    
    // Bullish Wedge
    if(IsBullishWedge(rates)) {
        s_chp_cached_pattern_results[4] = true;
        confirmations++;
    }
    
    // Store result in cache
    s_chp_last_pattern_check_time = current_time;
    s_chp_cached_buy_count = confirmations;
    
    return confirmations;
}

//+------------------------------------------------------------------+
//| Check chart patterns for sell                                      |
//+------------------------------------------------------------------+
int CheckChartPatternsShort()
{
    // Use cache for performance improvement
    datetime current_time = TimeCurrent();
    
    // If still in the same candle and cached result exists
    if(current_time - s_chp_last_pattern_check_time < PeriodSeconds(CHP_Timeframe) && s_chp_cached_sell_count >= 0)
        return s_chp_cached_sell_count;
    
    int confirmations = 0;
    
    // Quick check for validation
    if(!ValidateChartData()) {
        s_chp_last_pattern_check_time = current_time;
        s_chp_cached_sell_count = 0;
        return 0;
    }
    
    // Get rate data for pattern detection
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), CHP_Timeframe, 0, 100, rates);
    
    if(copied < MIN_COPIED_RATES) return 0;
    
    // Double Top
    if(IsDoubleTop(rates)) {
        s_chp_cached_pattern_results[5] = true;
        confirmations++;
    }
    
    // Head and Shoulders Top
    if(IsHeadAndShouldersTop()) {
        s_chp_cached_pattern_results[6] = true;
        confirmations++;
    }
    
    // Descending Triangle
    if(IsDescendingTriangle(rates)) {
        s_chp_cached_pattern_results[7] = true;
        confirmations++;
    }
    
    // Bearish Wedge
    if(IsBearishWedge(rates)) {
        s_chp_cached_pattern_results[8] = true;
        confirmations++;
    }
    
    // Diamond Top
    if(IsDiamondTop()) {
        s_chp_cached_pattern_results[9] = true;
        confirmations++;
    }
    
    // Store result in cache
    s_chp_last_pattern_check_time = current_time;
    s_chp_cached_sell_count = confirmations;
    
    return confirmations;
}

//+------------------------------------------------------------------+
//| Reset chart patterns cache                                         |
//+------------------------------------------------------------------+
void ResetChartPatternsCache()
{
    s_chp_last_pattern_check_time = 0;
    s_chp_cached_buy_count = -1;
    s_chp_cached_sell_count = -1;
    
    for(int i=0; i<10; i++)
        s_chp_cached_pattern_results[i] = false;
    
    // Announcement to the main file that the cache has been reset.
    ResetExternalPatternCache();
} 