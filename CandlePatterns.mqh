//+------------------------------------------------------------------+
//|                                                CandlePatterns.mqh |
//|                                       Copyright 2023, Gold Trader |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Declare external variables needed
extern ENUM_TIMEFRAMES CP_Timeframe;

// Configurable pattern thresholds
input double CP_PinBar_Shadow_Body_Ratio = 2.0;      // Pin Bar: Shadow to body ratio
input double CP_PinBar_Shadow_Length_Ratio = 0.6;    // Pin Bar: Shadow to total length ratio
input double CP_Hammer_Shadow_Body_Ratio = 2.0;      // Hammer: Shadow to body ratio
input double CP_Hammer_Shadow_Length_Ratio = 0.6;    // Hammer: Shadow to total length ratio
input double CP_Star_Small_Body_Ratio = 0.5;         // Morning/Evening Star: Small body ratio
input double CP_Star_Recovery_Ratio = 0.5;           // Morning/Evening Star: Recovery ratio
input double CP_Engulfing_Min_Size_Ratio = 0.8;      // Engulfing: Minimum size ratio
input double CP_Soldiers_Body_Ratio = 0.7;           // Three Soldiers/Crows: Body to total ratio
input bool CP_Use_Three_Soldiers_Crows = true;       // Use Three White Soldiers/Black Crows patterns

// Static variables for caching - separate for buy and sell
static datetime s_cp_last_buy_time = 0;
static datetime s_cp_last_sell_time = 0;
static int s_cp_cached_buy_count = -1;
static int s_cp_cached_sell_count = -1;
static bool s_cp_buy_pattern_cache[7] = {false, false, false, false, false, false, false};
static bool s_cp_sell_pattern_cache[7] = {false, false, false, false, false, false, false};

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
    if(current_time - s_cp_last_buy_time < PeriodSeconds(CP_Timeframe) && s_cp_cached_buy_count >= 0)
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
        s_cp_last_buy_time = current_time;
        s_cp_cached_buy_count = 0;
        return 0;
    }

    // Reset pattern cache
    for(int i=0; i<7; i++)
        s_cp_buy_pattern_cache[i] = false;

    // Pin Bar (Bullish)
    if(IsBullishPinBar(rates)) {
        s_cp_buy_pattern_cache[0] = true;
        confirmations++;
    }

    // Inside Bar (Bullish)
    if(IsBullishInsideBar(rates)) {
        s_cp_buy_pattern_cache[1] = true;
        confirmations++;
    }

    // Hammer
    if(IsHammer(rates)) {
        s_cp_buy_pattern_cache[2] = true;
        confirmations++;
    }

    // Bullish Engulfing
    if(IsBullishEngulfing(rates)) {
        s_cp_buy_pattern_cache[3] = true;
        confirmations++;
    }

    // Morning Star
    if(IsMorningStar(rates)) {
        s_cp_buy_pattern_cache[4] = true;
        confirmations++;
    }

    // Three White Soldiers (if enabled)
    if(CP_Use_Three_Soldiers_Crows && IsThreeWhiteSoldiers(rates)) {
        s_cp_buy_pattern_cache[5] = true;
        confirmations++;
    }

    // Store result in cache
    s_cp_last_buy_time = current_time;
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
    if(current_time - s_cp_last_sell_time < PeriodSeconds(CP_Timeframe) && s_cp_cached_sell_count >= 0)
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
        s_cp_last_sell_time = current_time;
        s_cp_cached_sell_count = 0;
        return 0;
    }

    // Reset pattern cache
    for(int i=0; i<7; i++)
        s_cp_sell_pattern_cache[i] = false;

    // Pin Bar (Bearish)
    if(IsBearishPinBar(rates)) {
        s_cp_sell_pattern_cache[0] = true;
        confirmations++;
    }

    // Inside Bar (Bearish)
    if(IsBearishInsideBar(rates)) {
        s_cp_sell_pattern_cache[1] = true;
        confirmations++;
    }

    // Shooting Star
    if(IsShootingStar(rates)) {
        s_cp_sell_pattern_cache[2] = true;
        confirmations++;
    }

    // Bearish Engulfing
    if(IsBearishEngulfing(rates)) {
        s_cp_sell_pattern_cache[3] = true;
        confirmations++;
    }

    // Evening Star
    if(IsEveningStar(rates)) {
        s_cp_sell_pattern_cache[4] = true;
        confirmations++;
    }

    // Three Black Crows (if enabled)
    if(CP_Use_Three_Soldiers_Crows && IsThreeBlackCrows(rates)) {
        s_cp_sell_pattern_cache[5] = true;
        confirmations++;
    }

    // Store result in cache
    s_cp_last_sell_time = current_time;
    s_cp_cached_sell_count = confirmations;

    return confirmations;
}

//+------------------------------------------------------------------+
//| Detect Bullish Pin Bar                                           |
//+------------------------------------------------------------------+
bool IsBullishPinBar(MqlRates &rates[])
{
    // If already checked and exists in cache
    if(s_cp_last_buy_time > 0 && s_cp_buy_pattern_cache[0])
        return true;

    // Calculate only if needed
    double body = MathAbs(rates[0].close - rates[0].open);
    double upper_shadow = rates[0].high - MathMax(rates[0].open, rates[0].close);
    double lower_shadow = MathMin(rates[0].open, rates[0].close) - rates[0].low;
    double total_length = rates[0].high - rates[0].low;

    // Protection against division by zero
    if(total_length <= 0)
        return false;

    // Bullish Pin Bar conditions - faster with minimal calculations
    return (lower_shadow > CP_PinBar_Shadow_Body_Ratio * body &&
            lower_shadow > upper_shadow &&
            lower_shadow > CP_PinBar_Shadow_Length_Ratio * total_length);
}

//+------------------------------------------------------------------+
//| Detect Bearish Pin Bar                                           |
//+------------------------------------------------------------------+
bool IsBearishPinBar(MqlRates &rates[])
{
    // If already checked and exists in cache
    if(s_cp_last_sell_time > 0 && s_cp_sell_pattern_cache[0])
        return true;

    double body = MathAbs(rates[0].close - rates[0].open);
    double upper_shadow = rates[0].high - MathMax(rates[0].open, rates[0].close);
    double lower_shadow = MathMin(rates[0].open, rates[0].close) - rates[0].low;
    double total_length = rates[0].high - rates[0].low;

    // Protection against division by zero
    if(total_length <= 0)
        return false;

    // Bearish Pin Bar conditions
    return (upper_shadow > CP_PinBar_Shadow_Body_Ratio * body &&
            upper_shadow > lower_shadow &&
            upper_shadow > CP_PinBar_Shadow_Length_Ratio * total_length);
}

//+------------------------------------------------------------------+
//| Detect Bullish Inside Bar                                        |
//+------------------------------------------------------------------+
bool IsBullishInsideBar(MqlRates &rates[])
{
    // If already checked and exists in cache
    if(s_cp_last_buy_time > 0 && s_cp_buy_pattern_cache[1])
        return true;

    // Inside Bar conditions (current candle completely within the previous candle)
    return (rates[0].high < rates[1].high && rates[0].low > rates[1].low && rates[0].close > rates[0].open);
}

//+------------------------------------------------------------------+
//| Detect Bearish Inside Bar                                        |
//+------------------------------------------------------------------+
bool IsBearishInsideBar(MqlRates &rates[])
{
    // If already checked and exists in cache
    if(s_cp_last_sell_time > 0 && s_cp_sell_pattern_cache[1])
        return true;

    // Inside Bar conditions (current candle completely within the previous candle)
    return (rates[0].high < rates[1].high && rates[0].low > rates[1].low && rates[0].close < rates[0].open);
}

//+------------------------------------------------------------------+
//| Detect Hammer                                                    |
//+------------------------------------------------------------------+
bool IsHammer(MqlRates &rates[])
{
    // If already checked and exists in cache
    if(s_cp_last_buy_time > 0 && s_cp_buy_pattern_cache[2])
        return true;

    double body = MathAbs(rates[0].close - rates[0].open);
    double upper_shadow = rates[0].high - MathMax(rates[0].open, rates[0].close);
    double lower_shadow = MathMin(rates[0].open, rates[0].close) - rates[0].low;
    double total_length = rates[0].high - rates[0].low;

    // Protection against division by zero
    if(total_length <= 0)
        return false;

    // Hammer conditions
    return (lower_shadow > CP_Hammer_Shadow_Body_Ratio * body &&
            lower_shadow > upper_shadow &&
            lower_shadow > CP_Hammer_Shadow_Length_Ratio * total_length &&
            rates[0].close > rates[0].open);
}

//+------------------------------------------------------------------+
//| Detect Shooting Star                                             |
//+------------------------------------------------------------------+
bool IsShootingStar(MqlRates &rates[])
{
    // If already checked and exists in cache
    if(s_cp_last_sell_time > 0 && s_cp_sell_pattern_cache[2])
        return true;

    double body = MathAbs(rates[0].close - rates[0].open);
    double upper_shadow = rates[0].high - MathMax(rates[0].open, rates[0].close);
    double lower_shadow = MathMin(rates[0].open, rates[0].close) - rates[0].low;
    double total_length = rates[0].high - rates[0].low;

    // Protection against division by zero
    if(total_length <= 0)
        return false;

    // Shooting Star conditions
    return (upper_shadow > CP_Hammer_Shadow_Body_Ratio * body &&
            upper_shadow > lower_shadow &&
            upper_shadow > CP_Hammer_Shadow_Length_Ratio * total_length &&
            rates[0].close < rates[0].open);
}

//+------------------------------------------------------------------+
//| Detect Bullish Engulfing                                         |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(MqlRates &rates[])
{
    // If already checked and exists in cache
    if(s_cp_last_buy_time > 0 && s_cp_buy_pattern_cache[3])
        return true;

    // Ensure at least two candles are present
    if(ArraySize(rates) < 2)
        return false;

    // Calculate candle bodies
    double body1 = MathAbs(rates[1].close - rates[1].open);
    double body2 = MathAbs(rates[0].close - rates[0].open);

    // Bullish Engulfing conditions - TRUE engulfing required
    bool bearish_candle = rates[1].close < rates[1].open;                // Previous candle is bearish
    bool bullish_candle = rates[0].close > rates[0].open;                // Current candle is bullish
    bool true_engulfing = rates[0].close > rates[1].open &&              // Current candle's close is above previous candle's open
                          rates[0].open < rates[1].close;                // Current candle's open is below previous candle's close
    bool significant_size = body2 > body1 * CP_Engulfing_Min_Size_Ratio; // Current candle's body is significant

    // Require true engulfing AND significant size
    return bearish_candle && bullish_candle && true_engulfing && significant_size;
}

//+------------------------------------------------------------------+
//| Detect Bearish Engulfing                                         |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(MqlRates &rates[])
{
    // If already checked and exists in cache
    if(s_cp_last_sell_time > 0 && s_cp_sell_pattern_cache[3])
        return true;

    // Ensure at least two candles are present
    if(ArraySize(rates) < 2)
        return false;

    // Calculate candle bodies
    double body1 = MathAbs(rates[1].close - rates[1].open);
    double body2 = MathAbs(rates[0].close - rates[0].open);

    // Bearish Engulfing conditions - TRUE engulfing required
    bool bullish_candle = rates[1].close > rates[1].open;               // Previous candle is bullish
    bool bearish_candle = rates[0].close < rates[0].open;               // Current candle is bearish
    bool true_engulfing = rates[0].close < rates[1].open &&             // Current candle's close is below previous candle's open
                          rates[0].open > rates[1].close;               // Current candle's open is above previous candle's close
    bool significant_size = body2 > body1 * CP_Engulfing_Min_Size_Ratio; // Current candle's body is significant

    // Require true engulfing AND significant size
    return bullish_candle && bearish_candle && true_engulfing && significant_size;
}

//+------------------------------------------------------------------+
//| Detect Morning Star                                              |
//+------------------------------------------------------------------+
bool IsMorningStar(MqlRates &rates[])
{
    // If already checked and exists in cache
    if(s_cp_last_buy_time > 0 && s_cp_buy_pattern_cache[4])
        return true;

    // Ensure at least three candles are present
    if(ArraySize(rates) < 3)
        return false;

    double body1 = MathAbs(rates[2].close - rates[2].open);
    double body2 = MathAbs(rates[1].close - rates[1].open);
    double body3 = MathAbs(rates[0].close - rates[0].open);

    // Morning Star conditions with more flexibility
    bool bearish_first = rates[2].close < rates[2].open;               // First candle is bearish
    bool small_middle = body2 < body1 * CP_Star_Small_Body_Ratio;      // Second candle's body is small
    bool bullish_last = rates[0].close > rates[0].open;                // Third candle is bullish

    // Third candle should recover into the first candle's body
    double first_candle_midpoint = (rates[2].open + rates[2].close) / 2.0;
    double recovery_target = rates[2].close + (first_candle_midpoint - rates[2].close) * CP_Star_Recovery_Ratio;
    bool good_recovery = rates[0].close > recovery_target;

    return bearish_first && small_middle && bullish_last && good_recovery;
}

//+------------------------------------------------------------------+
//| Detect Evening Star                                              |
//+------------------------------------------------------------------+
bool IsEveningStar(MqlRates &rates[])
{
    // If already checked and exists in cache
    if(s_cp_last_sell_time > 0 && s_cp_sell_pattern_cache[4])
        return true;

    // Ensure at least three candles are present
    if(ArraySize(rates) < 3)
        return false;

    double body1 = MathAbs(rates[2].close - rates[2].open);
    double body2 = MathAbs(rates[1].close - rates[1].open);
    double body3 = MathAbs(rates[0].close - rates[0].open);

    // Evening Star conditions with more flexibility
    bool bullish_first = rates[2].close > rates[2].open;               // First candle is bullish
    bool small_middle = body2 < body1 * CP_Star_Small_Body_Ratio;      // Second candle's body is small
    bool bearish_last = rates[0].close < rates[0].open;                // Third candle is bearish

    // Third candle should decline into the first candle's body
    double first_candle_midpoint = (rates[2].open + rates[2].close) / 2.0;
    double decline_target = rates[2].close - (rates[2].close - first_candle_midpoint) * CP_Star_Recovery_Ratio;
    bool good_decline = rates[0].close < decline_target;

    return bullish_first && small_middle && bearish_last && good_decline;
}

//+------------------------------------------------------------------+
//| Check candlestick patterns (unified with main check functions)    |
//+------------------------------------------------------------------+
int FindCandlestickPattern(MqlRates &rates[], int bullish_pattern)
{
   if(ArraySize(rates) < 3)
      return 0;

   if(bullish_pattern > 0)
   {
      // Check bullish patterns - aligned with CheckCandlePatternsBuy
      if(IsBullishPinBar(rates) || IsBullishInsideBar(rates) || IsHammer(rates) ||
         IsBullishEngulfing(rates) || IsMorningStar(rates))
         return 1;

      // Check Three White Soldiers if enabled
      if(CP_Use_Three_Soldiers_Crows && IsThreeWhiteSoldiers(rates))
         return 1;
   }
   else
   {
      // Check bearish patterns - aligned with CheckCandlePatternsShort
      if(IsBearishPinBar(rates) || IsBearishInsideBar(rates) || IsShootingStar(rates) ||
         IsBearishEngulfing(rates) || IsEveningStar(rates))
         return 1;

      // Check Three Black Crows if enabled
      if(CP_Use_Three_Soldiers_Crows && IsThreeBlackCrows(rates))
         return 1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Detect Three White Soldiers                                        |
//+------------------------------------------------------------------+
bool IsThreeWhiteSoldiers(MqlRates &rates[])
{
    // If already checked and exists in cache
    if(s_cp_last_buy_time > 0 && s_cp_buy_pattern_cache[5])
        return true;

    // Check array size
    int size = ArraySize(rates);
    if(size < 3) {
        DebugPrint("Error in IsThreeWhiteSoldiers: Array size is too small: " + IntegerToString(size));
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

    // Relatively large bodies with small shadows - with division protection
    double total0 = rates[0].high - rates[0].low;
    double total1 = rates[1].high - rates[1].low;
    double total2 = rates[2].high - rates[2].low;

    bool cond8 = (total0 > 0) && ((rates[0].close - rates[0].open) > CP_Soldiers_Body_Ratio * total0);
    bool cond9 = (total1 > 0) && ((rates[1].close - rates[1].open) > CP_Soldiers_Body_Ratio * total1);
    bool cond10 = (total2 > 0) && ((rates[2].close - rates[2].open) > CP_Soldiers_Body_Ratio * total2);

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
    // If already checked and exists in cache
    if(s_cp_last_sell_time > 0 && s_cp_sell_pattern_cache[5])
        return true;

    // Check array size
    int size = ArraySize(rates);
    if(size < 3) {
        DebugPrint("Error in IsThreeBlackCrows: Array size is too small: " + IntegerToString(size));
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

    // Relatively large bodies with small shadows - with division protection
    double total0 = rates[0].high - rates[0].low;
    double total1 = rates[1].high - rates[1].low;
    double total2 = rates[2].high - rates[2].low;

    bool cond8 = (total0 > 0) && ((rates[0].open - rates[0].close) > CP_Soldiers_Body_Ratio * total0);
    bool cond9 = (total1 > 0) && ((rates[1].open - rates[1].close) > CP_Soldiers_Body_Ratio * total1);
    bool cond10 = (total2 > 0) && ((rates[2].open - rates[2].close) > CP_Soldiers_Body_Ratio * total2);

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
    s_cp_last_buy_time = 0;
    s_cp_last_sell_time = 0;
    s_cp_cached_buy_count = -1;
    s_cp_cached_sell_count = -1;

    for(int i=0; i<7; i++) {
        s_cp_buy_pattern_cache[i] = false;
        s_cp_sell_pattern_cache[i] = false;
    }

    // Notify the main file that the cache has been reset
    ResetExternalCandleCache();
}