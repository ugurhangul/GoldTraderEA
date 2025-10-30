//+------------------------------------------------------------------+
//|                                                CandlePatterns.mqh |
//|                                       Copyright 2023, Gold Trader |
//|                                  REDESIGNED FOR MARKET CONTEXT    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Declare external variables needed
extern ENUM_TIMEFRAMES CP_Timeframe;

// Pattern recognition constants (calibrated values, do not change)
const double CP_PinBar_Shadow_Body_Ratio = 2.0;      // Pin Bar: Shadow to body ratio (technical constant)
const double CP_PinBar_Shadow_Length_Ratio = 0.6;    // Pin Bar: Shadow to total length ratio (technical constant)
const double CP_Hammer_Shadow_Body_Ratio = 2.0;      // Hammer: Shadow to body ratio (technical constant)
const double CP_Hammer_Shadow_Length_Ratio = 0.6;    // Hammer: Shadow to total length ratio (technical constant)
const double CP_Star_Small_Body_Ratio = 0.5;         // Morning/Evening Star: Small body ratio (technical constant)
const double CP_Star_Recovery_Ratio = 0.5;           // Morning/Evening Star: Recovery ratio (technical constant)
const double CP_Engulfing_Min_Size_Ratio = 0.8;      // Engulfing: Minimum size ratio (technical constant)
const double CP_Soldiers_Body_Ratio = 0.7;           // Three Soldiers/Crows: Body to total ratio (technical constant)
input bool CP_Use_Three_Soldiers_Crows = true;       // Use Three White Soldiers/Black Crows patterns

// Market context validation constants (calibrated values, do not change)
const double CP_Min_ADX_Trend = 25.0;                // Minimum ADX for established trend (calibrated)
const bool CP_Require_Trend_Context = true;          // Require trend for reversal patterns (best practice)
const bool CP_Require_SR_Confirmation = true;        // Require S/R level confirmation (best practice)
const double CP_SR_Proximity_Percent = 0.01;         // S/R proximity tolerance 1% (calibrated)
const bool CP_Require_Volume_Confirmation = true;    // Require volume confirmation for engulfing (best practice)
const double CP_Volume_Multiplier = 1.2;             // Volume must be X times average (calibrated)
const bool CP_Use_Pattern_Specific_SL = true;        // Use pattern-specific stop loss (best practice)
const int CP_Min_Confluence_Count = 2;               // Minimum confirmations required (calibrated)

// Static variables for caching - separate for buy and sell
static datetime s_cp_last_buy_time = 0;
static datetime s_cp_last_sell_time = 0;
static int s_cp_cached_buy_count = -1;
static int s_cp_cached_sell_count = -1;
static bool s_cp_buy_pattern_cache[7] = {false, false, false, false, false, false, false};
static bool s_cp_sell_pattern_cache[7] = {false, false, false, false, false, false, false};
static double s_cp_pattern_stop_loss[7] = {0, 0, 0, 0, 0, 0, 0};

// Import functions from main EA file
#import "GoldTraderEA.mq5"
   void DebugPrint(string message);
   bool GetDebugMode();
   void ResetExternalCandleCache();
#import

// External indicator arrays and handles from main EA
// These are declared as extern to access global variables from the main EA
extern int handle_adx;
extern int handle_ma_fast;
extern int handle_ma_slow;
extern int handle_atr;
extern double adx[];
extern double ma_fast[];
extern double ma_slow[];
extern double atr[];
extern long g_volumes[];

// Note: support_levels[], resistance_levels[], support_count, resistance_count
// are defined in SupportResistance.mqh which is included in the main EA
// They are globally available and don't need extern declaration here

//+------------------------------------------------------------------+
//| Helper: Validate trend context for reversal patterns             |
//+------------------------------------------------------------------+
bool ValidateTrendContext(bool is_bullish_reversal)
{
    if(!CP_Require_Trend_Context)
        return true;

    // Check if we have enough indicator data
    if(ArraySize(adx) < 1 || ArraySize(ma_fast) < 1 || ArraySize(ma_slow) < 1) {
        if(GetDebugMode()) DebugPrint("CP: Insufficient indicator data for trend validation");
        return false;
    }

    // Check ADX for trend strength - must have established trend to reverse
    if(adx[0] < CP_Min_ADX_Trend) {
        if(GetDebugMode()) DebugPrint("CP: ADX too low (ranging market): " + DoubleToString(adx[0], 2));
        return false;
    }

    // For bullish reversal, we need a downtrend (MA_fast < MA_slow)
    // For bearish reversal, we need an uptrend (MA_fast > MA_slow)
    bool current_trend_down = ma_fast[0] < ma_slow[0];
    bool trend_correct = (is_bullish_reversal && current_trend_down) || (!is_bullish_reversal && !current_trend_down);

    if(!trend_correct && GetDebugMode()) {
        DebugPrint("CP: No trend to reverse - Pattern: " + (is_bullish_reversal ? "Bullish" : "Bearish") +
                   ", Trend: " + (current_trend_down ? "Down" : "Up"));
    }

    return trend_correct;
}

//+------------------------------------------------------------------+
//| Helper: Check if pattern is at key S/R level                     |
//+------------------------------------------------------------------+
bool IsPatternAtSRLevel(MqlRates &rates[], bool is_support)
{
    if(!CP_Require_SR_Confirmation)
        return true;

    if(ArraySize(rates) < 1)
        return false;

    double pattern_level = is_support ? rates[0].low : rates[0].high;
    double tolerance = pattern_level * CP_SR_Proximity_Percent;

    if(is_support) {
        // Check if pattern is forming near support
        if(support_count == 0) return false;
        for(int i = 0; i < support_count; i++) {
            if(MathAbs(pattern_level - support_levels[i]) <= tolerance)
                return true;
        }
    } else {
        // Check if pattern is forming near resistance
        if(resistance_count == 0) return false;
        for(int i = 0; i < resistance_count; i++) {
            if(MathAbs(pattern_level - resistance_levels[i]) <= tolerance)
                return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Helper: Check volume confirmation for engulfing patterns         |
//+------------------------------------------------------------------+
bool HasVolumeConfirmation(MqlRates &rates[])
{
    if(!CP_Require_Volume_Confirmation)
        return true;

    if(ArraySize(g_volumes) < 10)
        return true;  // Can't validate, allow pattern

    // Calculate average volume over last 10 candles (excluding current)
    double avg_volume = 0;
    for(int i = 1; i < 10; i++) {
        avg_volume += (double)g_volumes[i];
    }
    avg_volume /= 9.0;

    // Current candle volume should be above average
    double current_volume = (double)g_volumes[0];
    bool has_volume = current_volume >= avg_volume * CP_Volume_Multiplier;

    if(!has_volume && GetDebugMode()) {
        DebugPrint("CP: Insufficient volume - Current: " + DoubleToString(current_volume, 0) +
                   ", Avg: " + DoubleToString(avg_volume, 0));
    }

    return has_volume;
}

//+------------------------------------------------------------------+
//| Helper: Calculate pattern-specific stop loss                     |
//+------------------------------------------------------------------+
double CalculateCandlePatternStopLoss(MqlRates &rates[], int pattern_index, bool is_buy)
{
    if(!CP_Use_Pattern_Specific_SL || ArraySize(rates) < 1)
        return 0;

    double stop_loss = 0;

    if(is_buy) {
        // For bullish patterns, place stop below pattern extreme
        switch(pattern_index) {
            case 0:  // Pin Bar
            case 2:  // Hammer
                // Stop below the pin bar/hammer wick
                stop_loss = rates[0].low * 0.9995;  // 0.05% buffer
                break;
            case 1:  // Inside Bar
                // Stop below the mother bar (previous candle)
                if(ArraySize(rates) >= 2)
                    stop_loss = rates[1].low * 0.9995;
                break;
            case 3:  // Bullish Engulfing
            case 4:  // Morning Star
                // Stop below the pattern low
                if(ArraySize(rates) >= 3) {
                    double pattern_low = MathMin(rates[0].low, MathMin(rates[1].low, rates[2].low));
                    stop_loss = pattern_low * 0.9995;
                }
                break;
            case 5:  // Three White Soldiers
                // Stop below the first soldier
                if(ArraySize(rates) >= 3)
                    stop_loss = rates[2].low * 0.9995;
                break;
        }
    } else {
        // For bearish patterns, place stop above pattern extreme
        switch(pattern_index) {
            case 0:  // Pin Bar
            case 2:  // Shooting Star
                // Stop above the pin bar/shooting star wick
                stop_loss = rates[0].high * 1.0005;  // 0.05% buffer
                break;
            case 1:  // Inside Bar
                // Stop above the mother bar
                if(ArraySize(rates) >= 2)
                    stop_loss = rates[1].high * 1.0005;
                break;
            case 3:  // Bearish Engulfing
            case 4:  // Evening Star
                // Stop above the pattern high
                if(ArraySize(rates) >= 3) {
                    double pattern_high = MathMax(rates[0].high, MathMax(rates[1].high, rates[2].high));
                    stop_loss = pattern_high * 1.0005;
                }
                break;
            case 5:  // Three Black Crows
                // Stop above the first crow
                if(ArraySize(rates) >= 3)
                    stop_loss = rates[2].high * 1.0005;
                break;
        }
    }

    return stop_loss;
}

//+------------------------------------------------------------------+
//| Check candlestick patterns for buying - REDESIGNED               |
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
        if(GetDebugMode()) DebugPrint("CP Buy: Not enough data copied. Copied: " + IntegerToString(copied));
        s_cp_last_buy_time = current_time;
        s_cp_cached_buy_count = 0;
        return 0;
    }

    // Validate trend context first (must have downtrend to reverse)
    if(!ValidateTrendContext(true)) {
        if(GetDebugMode()) DebugPrint("CP Buy: Trend context validation failed");
        s_cp_last_buy_time = current_time;
        s_cp_cached_buy_count = 0;
        return 0;
    }

    // Reset pattern cache
    for(int i=0; i<7; i++) {
        s_cp_buy_pattern_cache[i] = false;
        s_cp_pattern_stop_loss[i] = 0;
    }

    int confluence_count = 0;

    // Pin Bar (Bullish) - reversal pattern
    if(IsBullishPinBar(rates)) {
        if(IsPatternAtSRLevel(rates, true)) {  // Must be at support
            s_cp_buy_pattern_cache[0] = true;
            s_cp_pattern_stop_loss[0] = CalculateCandlePatternStopLoss(rates, 0, true);
            confirmations++;
            confluence_count++;
            if(GetDebugMode()) DebugPrint("CP: Bullish Pin Bar at support");
        }
    }

    // Inside Bar (Bullish)
    if(IsBullishInsideBar(rates)) {
        if(IsPatternAtSRLevel(rates, true)) {
            s_cp_buy_pattern_cache[1] = true;
            s_cp_pattern_stop_loss[1] = CalculateCandlePatternStopLoss(rates, 1, true);
            confirmations++;
            confluence_count++;
            if(GetDebugMode()) DebugPrint("CP: Bullish Inside Bar at support");
        }
    }

    // Hammer - reversal pattern
    if(IsHammer(rates)) {
        if(IsPatternAtSRLevel(rates, true)) {
            s_cp_buy_pattern_cache[2] = true;
            s_cp_pattern_stop_loss[2] = CalculateCandlePatternStopLoss(rates, 2, true);
            confirmations++;
            confluence_count++;
            if(GetDebugMode()) DebugPrint("CP: Hammer at support");
        }
    }

    // Bullish Engulfing - requires volume confirmation
    if(IsBullishEngulfing(rates)) {
        if(IsPatternAtSRLevel(rates, true) && HasVolumeConfirmation(rates)) {
            s_cp_buy_pattern_cache[3] = true;
            s_cp_pattern_stop_loss[3] = CalculateCandlePatternStopLoss(rates, 3, true);
            confirmations++;
            confluence_count++;
            if(GetDebugMode()) DebugPrint("CP: Bullish Engulfing at support with volume");
        }
    }

    // Morning Star
    if(IsMorningStar(rates)) {
        if(IsPatternAtSRLevel(rates, true)) {
            s_cp_buy_pattern_cache[4] = true;
            s_cp_pattern_stop_loss[4] = CalculateCandlePatternStopLoss(rates, 4, true);
            confirmations++;
            confluence_count++;
            if(GetDebugMode()) DebugPrint("CP: Morning Star at support");
        }
    }

    // Three White Soldiers (if enabled)
    if(CP_Use_Three_Soldiers_Crows && IsThreeWhiteSoldiers(rates)) {
        if(IsPatternAtSRLevel(rates, true)) {
            s_cp_buy_pattern_cache[5] = true;
            s_cp_pattern_stop_loss[5] = CalculateCandlePatternStopLoss(rates, 5, true);
            confirmations++;
            confluence_count++;
            if(GetDebugMode()) DebugPrint("CP: Three White Soldiers at support");
        }
    }

    // Check confluence requirement
    if(confluence_count < CP_Min_Confluence_Count) {
        if(GetDebugMode()) DebugPrint("CP Buy: Insufficient confluence - " + IntegerToString(confluence_count) +
                                      " < " + IntegerToString(CP_Min_Confluence_Count));
        confirmations = 0;  // Reset if not enough confluence
    }

    // Store result in cache
    s_cp_last_buy_time = current_time;
    s_cp_cached_buy_count = confirmations;

    if(confirmations > 0 && GetDebugMode()) {
        DebugPrint("CP Buy: Total confirmations = " + IntegerToString(confirmations) +
                   ", Confluence = " + IntegerToString(confluence_count));
    }

    return confirmations;
}

//+------------------------------------------------------------------+
//| Check candlestick patterns for selling - REDESIGNED              |
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
        if(GetDebugMode()) DebugPrint("CP Short: Not enough data copied. Copied: " + IntegerToString(copied));
        s_cp_last_sell_time = current_time;
        s_cp_cached_sell_count = 0;
        return 0;
    }

    // Validate trend context first (must have uptrend to reverse)
    if(!ValidateTrendContext(false)) {
        if(GetDebugMode()) DebugPrint("CP Short: Trend context validation failed");
        s_cp_last_sell_time = current_time;
        s_cp_cached_sell_count = 0;
        return 0;
    }

    // Reset pattern cache
    for(int i=0; i<7; i++) {
        s_cp_sell_pattern_cache[i] = false;
        s_cp_pattern_stop_loss[i] = 0;
    }

    int confluence_count = 0;

    // Pin Bar (Bearish) - reversal pattern
    if(IsBearishPinBar(rates)) {
        if(IsPatternAtSRLevel(rates, false)) {  // Must be at resistance
            s_cp_sell_pattern_cache[0] = true;
            s_cp_pattern_stop_loss[0] = CalculateCandlePatternStopLoss(rates, 0, false);
            confirmations++;
            confluence_count++;
            if(GetDebugMode()) DebugPrint("CP: Bearish Pin Bar at resistance");
        }
    }

    // Inside Bar (Bearish)
    if(IsBearishInsideBar(rates)) {
        if(IsPatternAtSRLevel(rates, false)) {
            s_cp_sell_pattern_cache[1] = true;
            s_cp_pattern_stop_loss[1] = CalculateCandlePatternStopLoss(rates, 1, false);
            confirmations++;
            confluence_count++;
            if(GetDebugMode()) DebugPrint("CP: Bearish Inside Bar at resistance");
        }
    }

    // Shooting Star - reversal pattern
    if(IsShootingStar(rates)) {
        if(IsPatternAtSRLevel(rates, false)) {
            s_cp_sell_pattern_cache[2] = true;
            s_cp_pattern_stop_loss[2] = CalculateCandlePatternStopLoss(rates, 2, false);
            confirmations++;
            confluence_count++;
            if(GetDebugMode()) DebugPrint("CP: Shooting Star at resistance");
        }
    }

    // Bearish Engulfing - requires volume confirmation
    if(IsBearishEngulfing(rates)) {
        if(IsPatternAtSRLevel(rates, false) && HasVolumeConfirmation(rates)) {
            s_cp_sell_pattern_cache[3] = true;
            s_cp_pattern_stop_loss[3] = CalculateCandlePatternStopLoss(rates, 3, false);
            confirmations++;
            confluence_count++;
            if(GetDebugMode()) DebugPrint("CP: Bearish Engulfing at resistance with volume");
        }
    }

    // Evening Star
    if(IsEveningStar(rates)) {
        if(IsPatternAtSRLevel(rates, false)) {
            s_cp_sell_pattern_cache[4] = true;
            s_cp_pattern_stop_loss[4] = CalculateCandlePatternStopLoss(rates, 4, false);
            confirmations++;
            confluence_count++;
            if(GetDebugMode()) DebugPrint("CP: Evening Star at resistance");
        }
    }

    // Three Black Crows (if enabled)
    if(CP_Use_Three_Soldiers_Crows && IsThreeBlackCrows(rates)) {
        if(IsPatternAtSRLevel(rates, false)) {
            s_cp_sell_pattern_cache[5] = true;
            s_cp_pattern_stop_loss[5] = CalculateCandlePatternStopLoss(rates, 5, false);
            confirmations++;
            confluence_count++;
            if(GetDebugMode()) DebugPrint("CP: Three Black Crows at resistance");
        }
    }

    // Check confluence requirement
    if(confluence_count < CP_Min_Confluence_Count) {
        if(GetDebugMode()) DebugPrint("CP Short: Insufficient confluence - " + IntegerToString(confluence_count) +
                                      " < " + IntegerToString(CP_Min_Confluence_Count));
        confirmations = 0;  // Reset if not enough confluence
    }

    // Store result in cache
    s_cp_last_sell_time = current_time;
    s_cp_cached_sell_count = confirmations;

    if(confirmations > 0 && GetDebugMode()) {
        DebugPrint("CP Short: Total confirmations = " + IntegerToString(confirmations) +
                   ", Confluence = " + IntegerToString(confluence_count));
    }

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
        s_cp_pattern_stop_loss[i] = 0;
    }

    // Notify the main file that the cache has been reset
    ResetExternalCandleCache();
}

//+------------------------------------------------------------------+
//| Get pattern-specific stop loss for specific pattern              |
//+------------------------------------------------------------------+
double GetCandlePatternStopLoss(int pattern_index)
{
    if(pattern_index >= 0 && pattern_index < 7)
        return s_cp_pattern_stop_loss[pattern_index];
    return 0;
}