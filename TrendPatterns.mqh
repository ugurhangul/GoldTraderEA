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
    double trendline_value = 0;
    int count_touches = 0;
    double slope = 0;
    int first_touch_idx = -1;

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
                trendline_value = rates[i].high;
                first_touch_idx = i;
                count_touches++;
            } else if(count_touches == 1) {
                // Calculate the slope of the trend line (using actual distance between points)
                slope = (rates[i].high - trendline_value) / (i - first_touch_idx);
                trendline_value = rates[i].high;
                count_touches++;
            } else {
                // Check alignment with the trend line
                double expected_value = trendline_value - (slope * (i - first_touch_idx));
                if(MathAbs(rates[i].high - expected_value) < 20 * Point()) {
                    trendline_value = rates[i].high;
                    count_touches++;
                }
            }
        }
    }
    
    // At least three touches with the trend line for validity
    if(count_touches < 3)
        return false;
        
    // Calculate the trend line value at the current point
    trendline_value = trendline_value - (slope * size);
    
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
    double trendline_value = 0;
    int count_touches = 0;
    double slope = 0;
    int first_touch_idx = -1;

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
                trendline_value = rates[i].low;
                first_touch_idx = i;
                count_touches++;
            } else if(count_touches == 1) {
                // Calculate the slope of the trend line (using actual distance between points)
                slope = (rates[i].low - trendline_value) / (i - first_touch_idx);
                trendline_value = rates[i].low;
                count_touches++;
            } else {
                // Check alignment with the trend line
                double expected_value = trendline_value + (slope * (i - first_touch_idx));
                if(MathAbs(rates[i].low - expected_value) < 20 * Point()) {
                    trendline_value = rates[i].low;
                    count_touches++;
                }
            }
        }
    }
    
    // At least three touches with the trend line for validity
    if(count_touches < 3)
        return false;
        
    // Calculate the trend line value at the current point
    trendline_value = trendline_value + (slope * size);
    
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
    
    // If the rates array is empty, fill it
    if(ArraySize(rates) < 100)
    {
        // Retrieve candle data
        ArraySetAsSeries(rates, true);
        CopyRates(Symbol(), TP_Timeframe, 0, 100, rates);
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
    
    // If the rates array is empty, fill it
    if(ArraySize(rates) < 100)
    {
        // Retrieve candle data
        ArraySetAsSeries(rates, true);
        CopyRates(Symbol(), TP_Timeframe, 0, 100, rates);
    }
    
    // Bearish Trend Breakout
    if(IsBearishTrendBreakout(rates))
        confirmations++;
    
    return confirmations;
} 