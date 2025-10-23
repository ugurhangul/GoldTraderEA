//+------------------------------------------------------------------+
//|                                                TrendPatterns.mqh |
//|                                      Copyright 2023, Gold Trader   |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Declare external variables needed
extern ENUM_TIMEFRAMES TP_Timeframe;
input bool TP_Debug = false;  // Debug flag for TrendPatterns module (will be set programmatically)

//+------------------------------------------------------------------+
//| DebugPrint function declared extern from the main file           |
//+------------------------------------------------------------------+
#import "GoldTraderEA_cleaned.mq5"
   void DebugPrint(string message);
   bool CheckArrayAccess(int index, int array_size, string function_name);
#import

//+------------------------------------------------------------------+
//| Detect Bullish Trend Breakout                                     |
//+------------------------------------------------------------------+
bool IsBullishTrendBreakout(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 30) {
        DebugPrint("Error in IsBullishTrendBreakout: Array size is too small: " + IntegerToString(size));
        return false;
    }

    // Find the downtrend line
    double first_touch_value = 0;
    double second_touch_value = 0;
    int count_touches = 0;
    double slope = 0;
    int first_touch_idx = -1;
    int second_touch_idx = -1;
    int last_touch_idx = -1;

    // Search for local maxima
    for(int i = 3; i < size - 3; i++) {
        if(!CheckArrayAccess(i, size, "IsBullishTrendBreakout") ||
           !CheckArrayAccess(i+1, size, "IsBullishTrendBreakout") ||
           !CheckArrayAccess(i-1, size, "IsBullishTrendBreakout"))
            continue;

        // Local maximum if the current candle is higher than the adjacent candles
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high) {
            // Collect trend line points
            if(count_touches == 0) {
                first_touch_value = rates[i].high;
                first_touch_idx = i;
                last_touch_idx = i;
                count_touches++;
            } else if(count_touches == 1) {
                // Protection against division by zero
                if(i == first_touch_idx) continue;

                // Calculate the slope of the trend line (using actual distance between points)
                second_touch_value = rates[i].high;
                second_touch_idx = i;
                slope = (second_touch_value - first_touch_value) / (second_touch_idx - first_touch_idx);
                last_touch_idx = i;
                count_touches++;
            } else {
                // Protection against division by zero
                if(i == second_touch_idx) continue;

                // Check alignment with the trend line
                // Project from second touch point to current position
                double expected_value = second_touch_value + (slope * (i - second_touch_idx));
                if(MathAbs(rates[i].high - expected_value) < 20 * Point()) {
                    last_touch_idx = i;
                    count_touches++;
                }
            }
        }
    }

    // At least three touches with the trend line for validity
    if(count_touches < 3)
        return false;

    // Calculate the trend line value at the current point (index 0)
    // Project from the second touch point to current position (index 0)
    // Since array is series, index 0 is most recent, higher indices are older
    // Distance from second_touch_idx to 0 is: 0 - second_touch_idx = -second_touch_idx
    double trendline_value = second_touch_value + (slope * (0 - second_touch_idx));

    // Check for trend line breakout
    if(CheckArrayAccess(0, size, "IsBullishTrendBreakout") &&
       CheckArrayAccess(1, size, "IsBullishTrendBreakout"))
    {
        DebugPrint("Trend line value: " + DoubleToString(trendline_value) +
                   ", Current price: " + DoubleToString(rates[0].close) +
                   ", Previous price: " + DoubleToString(rates[1].close));
        return (rates[0].close > trendline_value && rates[1].close <= trendline_value);
    }

    return false;
}

//+------------------------------------------------------------------+
//| Detect Bearish Trend Breakout                                     |
//+------------------------------------------------------------------+
bool IsBearishTrendBreakout(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 30) {
        DebugPrint("Error in IsBearishTrendBreakout: Array size is too small: " + IntegerToString(size));
        return false;
    }

    // Find the uptrend line
    double first_touch_value = 0;
    double second_touch_value = 0;
    int count_touches = 0;
    double slope = 0;
    int first_touch_idx = -1;
    int second_touch_idx = -1;
    int last_touch_idx = -1;

    // Search for local minima
    for(int i = 3; i < size - 3; i++) {
        if(!CheckArrayAccess(i, size, "IsBearishTrendBreakout") ||
           !CheckArrayAccess(i+1, size, "IsBearishTrendBreakout") ||
           !CheckArrayAccess(i-1, size, "IsBearishTrendBreakout"))
            continue;

        // Local minimum if the current candle is lower than the adjacent candles
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low) {
            // Collect trend line points
            if(count_touches == 0) {
                first_touch_value = rates[i].low;
                first_touch_idx = i;
                last_touch_idx = i;
                count_touches++;
            } else if(count_touches == 1) {
                // Protection against division by zero
                if(i == first_touch_idx) continue;

                // Calculate the slope of the trend line (using actual distance between points)
                second_touch_value = rates[i].low;
                second_touch_idx = i;
                slope = (second_touch_value - first_touch_value) / (second_touch_idx - first_touch_idx);
                last_touch_idx = i;
                count_touches++;
            } else {
                // Protection against division by zero
                if(i == second_touch_idx) continue;

                // Check alignment with the trend line
                // Project from second touch point to current position
                double expected_value = second_touch_value + (slope * (i - second_touch_idx));
                if(MathAbs(rates[i].low - expected_value) < 20 * Point()) {
                    last_touch_idx = i;
                    count_touches++;
                }
            }
        }
    }

    // At least three touches with the trend line for validity
    if(count_touches < 3)
        return false;

    // Calculate the trend line value at the current point (index 0)
    // Project from the second touch point to current position (index 0)
    // Since array is series, index 0 is most recent, higher indices are older
    // Distance from second_touch_idx to 0 is: 0 - second_touch_idx = -second_touch_idx
    double trendline_value = second_touch_value + (slope * (0 - second_touch_idx));

    // Check for trend line breakout
    if(CheckArrayAccess(0, size, "IsBearishTrendBreakout") &&
       CheckArrayAccess(1, size, "IsBearishTrendBreakout"))
    {
        DebugPrint("Trend line value: " + DoubleToString(trendline_value) +
                   ", Current price: " + DoubleToString(rates[0].close) +
                   ", Previous price: " + DoubleToString(rates[1].close));
        return (rates[0].close < trendline_value && rates[1].close >= trendline_value);
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check trend breakout patterns for buying                         |
//+------------------------------------------------------------------+
int CheckTrendPatternsBuy(MqlRates &rates[])
{
    int confirmations = 0;
    int size = ArraySize(rates);

    // Validate array has enough data for trend analysis
    if(size < 30) {
        DebugPrint("CheckTrendPatternsBuy: Insufficient data for trend analysis. Size: " + IntegerToString(size));
        return 0;
    }

    // Bullish Trend Breakout
    if(IsBullishTrendBreakout(rates))
        confirmations++;

    return confirmations;
}

//+------------------------------------------------------------------+
//| Check trend breakout patterns for selling                        |
//+------------------------------------------------------------------+
int CheckTrendPatternsShort(MqlRates &rates[])
{
    int confirmations = 0;
    int size = ArraySize(rates);

    // Validate array has enough data for trend analysis
    if(size < 30) {
        DebugPrint("CheckTrendPatternsShort: Insufficient data for trend analysis. Size: " + IntegerToString(size));
        return 0;
    }

    // Bearish Trend Breakout
    if(IsBearishTrendBreakout(rates))
        confirmations++;

    return confirmations;
}