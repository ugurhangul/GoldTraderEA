//+------------------------------------------------------------------+
//|                                                CandlePatterns.mqh |
//|                                       Copyright 2023, Gold Trader |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Declare external variables needed
extern ENUM_TIMEFRAMES CP_Timeframe;

// Static variables for caching
static datetime s_cp_last_candle_time = 0;
static int s_cp_cached_buy_count = -1;
static int s_cp_cached_sell_count = -1;
static bool s_cp_pattern_cache[10] = {false, false, false, false, false, false, false, false, false, false};

// The DebugPrint function must be defined in the main file
#import "GoldTraderEA_cleaned.mq5"
void DebugPrint(string message);
bool GetDebugMode();
void ResetExternalCandleCache();
#import

//+------------------------------------------------------------------+
//| Check candlestick patterns for buying                             |
//+------------------------------------------------------------------+
int CheckCandlePatternsBuy()
{
    // Use caching for performance improvement
    datetime current_time = TimeCurrent();
    
    // If we are still in the same candle and cached result exists
    if(current_time - s_cp_last_candle_time < PeriodSeconds(CP_Timeframe) && s_cp_cached_buy_count >= 0)
        return s_cp_cached_buy_count;
    
    int confirmations = 0;
    
    // Get candlestick data
    MqlRates rates[];
    ArrayResize(rates, 10); // Pre-allocate array for better performance
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), CP_Timeframe, 0, 10, rates);
    
    // Quick check for potential errors
    if(copied < 3) {
        // Log the error for debugging
        DebugPrint("Error: Not enough data copied. Copied: " + IntegerToString(copied));
        s_cp_last_candle_time = current_time;
        s_cp_cached_buy_count = 0;
        return 0;
    }
    
    // Reset pattern cache
    for(int i=0; i<10; i++)
        s_cp_pattern_cache[i] = false;
    
    // Pin Bar (Bullish)
    if(IsBullishPinBar(rates)) {
        s_cp_pattern_cache[0] = true;
        confirmations++;
    }
        
    // Inside Bar (Bullish)
    if(IsBullishInsideBar(rates)) {
        s_cp_pattern_cache[1] = true;
        confirmations++;
    }
        
    // Hammer
    if(IsHammer(rates)) {
        s_cp_pattern_cache[2] = true;
        confirmations++;
    }
        
    // Bullish Engulfing
    if(IsBullishEngulfing(rates)) {
        s_cp_pattern_cache[3] = true;
        confirmations++;
    }
        
    // Morning Star
    if(IsMorningStar(rates)) {
        s_cp_pattern_cache[4] = true;
        confirmations++;
    }
    
    // Store result in cache
    s_cp_last_candle_time = current_time;
    s_cp_cached_buy_count = confirmations;
        
    return confirmations;
}

//+------------------------------------------------------------------+
//| Check candlestick patterns for selling                            |
//+------------------------------------------------------------------+
int CheckCandlePatternsShort()
{
    // Use caching for performance improvement
    datetime current_time = TimeCurrent();
    
    // If we are still in the same candle and cached result exists
    if(current_time - s_cp_last_candle_time < PeriodSeconds(CP_Timeframe) && s_cp_cached_sell_count >= 0)
        return s_cp_cached_sell_count;
    
    int confirmations = 0;
    
    // Get candlestick data
    MqlRates rates[];
    ArrayResize(rates, 10); // Pre-allocate array for better performance
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), CP_Timeframe, 0, 10, rates);
    
    // Quick check for potential errors
    if(copied < 3) {
        // Log the error for debugging
        DebugPrint("Error: Not enough data copied. Copied: " + IntegerToString(copied));
        s_cp_last_candle_time = current_time;
        s_cp_cached_sell_count = 0;
        return 0;
    }
    
    // Pin Bar (Bearish)
    if(IsBearishPinBar(rates)) {
        s_cp_pattern_cache[5] = true;
        confirmations++;
    }
        
    // Inside Bar (Bearish)
    if(IsBearishInsideBar(rates)) {
        s_cp_pattern_cache[6] = true;
        confirmations++;
    }
        
    // Shooting Star
    if(IsShootingStar(rates)) {
        s_cp_pattern_cache[7] = true;
        confirmations++;
    }
        
    // Bearish Engulfing
    if(IsBearishEngulfing(rates)) {
        s_cp_pattern_cache[8] = true;
        confirmations++;
    }
        
    // Evening Star
    if(IsEveningStar(rates)) {
        s_cp_pattern_cache[9] = true;
        confirmations++;
    }
    
    // Store result in cache
    s_cp_last_candle_time = current_time;
    s_cp_cached_sell_count = confirmations;
        
    return confirmations;
}

//+------------------------------------------------------------------+
//| Detect Bullish Pin Bar                                           |
//+------------------------------------------------------------------+
bool IsBullishPinBar(MqlRates &rates[])
{
    // If already checked and exists in cache
    if(s_cp_last_candle_time > 0 && s_cp_pattern_cache[0])
        return true;
    
    // Calculate only if needed
    double body = MathAbs(rates[0].close - rates[0].open);
    double upper_shadow = rates[0].high - MathMax(rates[0].open, rates[0].close);
    double lower_shadow = MathMin(rates[0].open, rates[0].close) - rates[0].low;
    double total_length = rates[0].high - rates[0].low;
    
    // Bullish Pin Bar conditions - faster with minimal calculations
    return (lower_shadow > 2 * body && lower_shadow > upper_shadow && lower_shadow > 0.6 * total_length);
}

//+------------------------------------------------------------------+
//| Detect Bearish Pin Bar                                           |
//+------------------------------------------------------------------+
bool IsBearishPinBar(MqlRates &rates[])
{
    double body = MathAbs(rates[0].close - rates[0].open);
    double upper_shadow = rates[0].high - MathMax(rates[0].open, rates[0].close);
    double lower_shadow = MathMin(rates[0].open, rates[0].close) - rates[0].low;
    double total_length = rates[0].high - rates[0].low;
    
    // Bearish Pin Bar conditions
    return (upper_shadow > 2 * body && upper_shadow > lower_shadow && upper_shadow > 0.6 * total_length);
}

//+------------------------------------------------------------------+
//| Detect Bullish Inside Bar                                        |
//+------------------------------------------------------------------+
bool IsBullishInsideBar(MqlRates &rates[])
{
    // Inside Bar conditions (current candle completely within the previous candle)
    return (rates[0].high < rates[1].high && rates[0].low > rates[1].low && rates[0].close > rates[0].open);
}

//+------------------------------------------------------------------+
//| Detect Bearish Inside Bar                                        |
//+------------------------------------------------------------------+
bool IsBearishInsideBar(MqlRates &rates[])
{
    // Inside Bar conditions (current candle completely within the previous candle)
    return (rates[0].high < rates[1].high && rates[0].low > rates[1].low && rates[0].close < rates[0].open);
}

//+------------------------------------------------------------------+
//| Detect Hammer                                                    |
//+------------------------------------------------------------------+
bool IsHammer(MqlRates &rates[])
{
    double body = MathAbs(rates[0].close - rates[0].open);
    double upper_shadow = rates[0].high - MathMax(rates[0].open, rates[0].close);
    double lower_shadow = MathMin(rates[0].open, rates[0].close) - rates[0].low;
    double total_length = rates[0].high - rates[0].low;
    
    // Hammer conditions
    return (lower_shadow > 2 * body && lower_shadow > upper_shadow && lower_shadow > 0.6 * total_length && rates[0].close > rates[0].open);
}

//+------------------------------------------------------------------+
//| Detect Shooting Star                                             |
//+------------------------------------------------------------------+
bool IsShootingStar(MqlRates &rates[])
{
    double body = MathAbs(rates[0].close - rates[0].open);
    double upper_shadow = rates[0].high - MathMax(rates[0].open, rates[0].close);
    double lower_shadow = MathMin(rates[0].open, rates[0].close) - rates[0].low;
    double total_length = rates[0].high - rates[0].low;
    
    // Shooting Star conditions
    return (upper_shadow > 2 * body && upper_shadow > lower_shadow && upper_shadow > 0.6 * total_length && rates[0].close < rates[0].open);
}

//+------------------------------------------------------------------+
//| Detect Bullish Engulfing                                         |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(MqlRates &rates[])
{
    // Ensure at least two candles are present
    if(ArraySize(rates) < 2)
        return false;
        
    // Calculate candle bodies
    double body1 = MathAbs(rates[1].close - rates[1].open);
    double body2 = MathAbs(rates[0].close - rates[0].open);
    
    // Bullish Engulfing conditions with more flexibility
    bool bearish_candle = rates[1].close < rates[1].open;                // Previous candle is bearish
    bool bullish_candle = rates[0].close > rates[0].open;                // Current candle is bullish
    bool engulfs_body = rates[0].close >= rates[1].open &&               // Current candle's close is above or equal to previous candle's open
                        rates[0].open <= rates[1].close;                 // Current candle's open is below or equal to previous candle's close
    bool significant_size = body2 > body1 * 0.8;                         // Current candle's body is at least 80% of previous candle's body
    
    // Allow some flexibility (accept patterns close to engulfing)
    return bearish_candle && bullish_candle && (engulfs_body || significant_size);
}

//+------------------------------------------------------------------+
//| Detect Bearish Engulfing                                         |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(MqlRates &rates[])
{
    // Ensure at least two candles are present
    if(ArraySize(rates) < 2)
        return false;
        
    // Calculate candle bodies
    double body1 = MathAbs(rates[1].close - rates[1].open);
    double body2 = MathAbs(rates[0].close - rates[0].open);
    
    // Bearish Engulfing conditions with more flexibility
    bool bullish_candle = rates[1].close > rates[1].open;               // Previous candle is bullish
    bool bearish_candle = rates[0].close < rates[0].open;               // Current candle is bearish
    bool engulfs_body = rates[0].close <= rates[1].close &&             // Current candle's close is below or equal to previous candle's close
                        rates[0].open >= rates[1].open;                 // Current candle's open is above or equal to previous candle's open
    bool significant_size = body2 > body1 * 0.8;                        // Current candle's body is at least 80% of previous candle's body
    
    // Allow some flexibility (accept patterns close to engulfing)
    return bullish_candle && bearish_candle && (engulfs_body || significant_size);
}

//+------------------------------------------------------------------+
//| Detect Morning Star                                              |
//+------------------------------------------------------------------+
bool IsMorningStar(MqlRates &rates[])
{
    // Ensure at least three candles are present
    if(ArraySize(rates) < 3)
        return false;
        
    double body1 = MathAbs(rates[2].close - rates[2].open);
    double body2 = MathAbs(rates[1].close - rates[1].open);
    double body3 = MathAbs(rates[0].close - rates[0].open);
    
    // Morning Star conditions with more flexibility
    bool bearish_first = rates[2].close < rates[2].open;               // First candle is bearish
    bool small_middle = body2 < body1 * 0.5;                           // Second candle's body is small (less than 50% of the first candle)
    bool bullish_last = rates[0].close > rates[0].open;                // Third candle is bullish
    bool good_recovery = rates[0].close > (rates[2].open + rates[2].close)/2 * 0.9; // Third candle covers at least 90% of the first candle's half
    
    return bearish_first && small_middle && bullish_last && good_recovery;
}

//+------------------------------------------------------------------+
//| Detect Evening Star                                              |
//+------------------------------------------------------------------+
bool IsEveningStar(MqlRates &rates[])
{
    // Ensure at least three candles are present
    if(ArraySize(rates) < 3)
        return false;
        
    double body1 = MathAbs(rates[2].close - rates[2].open);
    double body2 = MathAbs(rates[1].close - rates[1].open);
    double body3 = MathAbs(rates[0].close - rates[0].open);
    
    // Evening Star conditions with more flexibility
    bool bullish_first = rates[2].close > rates[2].open;               // First candle is bullish
    bool small_middle = body2 < body1 * 0.5;                           // Second candle's body is small (less than 50% of the first candle)
    bool bearish_last = rates[0].close < rates[0].open;                // Third candle is bearish
    bool good_decline = rates[0].close < (rates[2].open + rates[2].close)/2 * 1.1; // Third candle covers at least 90% of the first candle's half
    
    return bullish_first && small_middle && bearish_last && good_decline;
}

//+------------------------------------------------------------------+
//| Check candlestick patterns                                         |
//+------------------------------------------------------------------+
int FindCandlestickPattern(MqlRates &rates[], int bullish_pattern)
{
   if(ArraySize(rates) < 3)
      return 0;
   
   if(bullish_pattern > 0)
   {
      // Check bullish patterns
      if(IsBullishEngulfing(rates) || IsHammer(rates) || IsMorningStar(rates))
         return 1;
   }
   else
   {
      // Check bearish patterns
      if(IsBearishEngulfing(rates) || IsShootingStar(rates) || IsEveningStar(rates))
         return 1;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Detect Three White Soldiers                                        |
//+------------------------------------------------------------------+
bool IsThreeWhiteSoldiers(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 3) {
        DebugPrint("Error in IsThreeWhiteSoldiers: Array size is too small: " + IntegerToString(size));
        return false;
    }
    
    // Re-check array bounds point by point
    if(size <= 0 || size <= 1 || size <= 2) {
        DebugPrint("Error in IsThreeWhiteSoldiers: Required indices are not available");
        return false;
    }
    
    // Three White Soldiers conditions
    bool cond1 = rates[2].close > rates[2].open;  // Three bullish candles in a row
    bool cond2 = rates[1].close > rates[1].open;
    bool cond3 = rates[0].close > rates[0].open;
    bool cond4 = rates[1].close > rates[2].close;  // Each candle closes higher than the previous one
    bool cond5 = rates[0].close > rates[1].close;
    bool cond6 = rates[1].open > rates[2].open;    // Each candle opens higher than the previous one
    bool cond7 = rates[0].open > rates[1].open;
    
    // Relatively large bodies with small shadows
    bool cond8 = (rates[0].close - rates[0].open) > 0.7 * (rates[0].high - rates[0].low);
    bool cond9 = (rates[1].close - rates[1].open) > 0.7 * (rates[1].high - rates[1].low);
    bool cond10 = (rates[2].close - rates[2].open) > 0.7 * (rates[2].high - rates[2].low);
    
    bool result = cond1 && cond2 && cond3 && cond4 && cond5 && cond6 && cond7 && cond8 && cond9 && cond10;
    
    if(result) {
        DebugPrint("Three White Soldiers pattern identified");
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Detect Three Black Crows                                           |
//+------------------------------------------------------------------+
bool IsThreeBlackCrows(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 3) {
        DebugPrint("Error in IsThreeBlackCrows: Array size is too small: " + IntegerToString(size));
        return false;
    }
    
    // Re-check array bounds point by point
    if(size <= 0 || size <= 1 || size <= 2) {
        DebugPrint("Error in IsThreeBlackCrows: Required indices are not available");
        return false;
    }
    
    // Three Black Crows conditions
    bool cond1 = rates[2].close < rates[2].open;  // Three bearish candles in a row
    bool cond2 = rates[1].close < rates[1].open;
    bool cond3 = rates[0].close < rates[0].open;
    bool cond4 = rates[1].close < rates[2].close;  // Each candle closes lower than the previous one
    bool cond5 = rates[0].close < rates[1].close;
    bool cond6 = rates[1].open < rates[2].open;    // Each candle opens lower than the previous one
    bool cond7 = rates[0].open < rates[1].open;
    
    // Relatively large bodies with small shadows
    bool cond8 = (rates[0].open - rates[0].close) > 0.7 * (rates[0].high - rates[0].low);
    bool cond9 = (rates[1].open - rates[1].close) > 0.7 * (rates[1].high - rates[1].low);
    bool cond10 = (rates[2].open - rates[2].close) > 0.7 * (rates[2].high - rates[2].low);
    
    bool result = cond1 && cond2 && cond3 && cond4 && cond5 && cond6 && cond7 && cond8 && cond9 && cond10;
    
    if(result) {
        DebugPrint("Three Black Crows pattern identified");
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Reset candlestick patterns cache                                   |
//+------------------------------------------------------------------+
void ResetCandlePatternsCache()
{
    s_cp_last_candle_time = 0;
    s_cp_cached_buy_count = -1;
    s_cp_cached_sell_count = -1;
    
    for(int i=0; i<10; i++)
        s_cp_pattern_cache[i] = false;
    
    // Notify the main file that the cache has been reset
    ResetExternalCandleCache(); 
}

// Add exit conditions (example)
void CheckExitConditions() {
    // Implement exit logic based on market conditions or patterns
    // Example: if a bearish pattern is detected after a buy signal, trigger an exit
} 