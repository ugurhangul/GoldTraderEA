//+------------------------------------------------------------------+
//|                                                  Divergence.mqh |
//|                                      Copyright 2023, Gold Trader   |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Declare external variables needed
extern ENUM_TIMEFRAMES DIV_Timeframe;

// Public variables for indicators
extern int handle_rsi, handle_macd;
extern double rsi[], macd[], macd_signal[];

// The DebugPrint function must be defined in the main file
#import "GoldTraderEA_cleaned.mq5"
   void DebugPrint(string message);
#import

//+------------------------------------------------------------------+
//| Check array index access                                          |
//+------------------------------------------------------------------+
// Comment out this function since it's already defined in ChartPatterns.mqh
/*
bool CheckArrayAccess(int index, int array_size, string function_name)
{
    if(index < 0 || index >= array_size) {
        DebugPrint("Error in " + function_name + ": Index " + IntegerToString(index) + 
                   " out of range (size: " + IntegerToString(array_size) + ")");
        return false;
    }
    return true;
}
*/

// Instead, use extern to reference the function from another file
#import "GoldTraderEA_cleaned.mq5"
bool CheckArrayAccess(int index, int array_size, string function_name);
#import

//+------------------------------------------------------------------+
//| Check divergences for buy                                         |
//+------------------------------------------------------------------+
int CheckDivergenceBuy(MqlRates &rates[])
{
    DebugPrint("Starting divergence check for buy");
    
    int confirmations = 0;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 30) {
        DebugPrint("Rates array for CheckDivergenceBuy is smaller than required size: " + IntegerToString(size));
        return 0;
    }
    
    DebugPrint("Number of candles received for CheckDivergenceBuy: " + IntegerToString(size));
    
    // Check bullish RSI divergences
    if(IsBullishRSIDivergence(rates)) {
        DebugPrint("Bullish RSI divergence detected");
        confirmations++;
    }
    
    // Check bullish MACD divergences
    if(IsBullishMACDDivergence(rates)) {
        DebugPrint("Bullish MACD divergence detected");
        confirmations++;
    }
    
    DebugPrint("Number of divergence confirmations for buy: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Check divergences for sell                                        |
//+------------------------------------------------------------------+
int CheckDivergenceShort(MqlRates &rates[])
{
    DebugPrint("Starting divergence check for sell");
    
    int confirmations = 0;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 30) {
        DebugPrint("Rates array for CheckDivergenceShort is smaller than required size: " + IntegerToString(size));
        return 0;
    }
    
    DebugPrint("Number of candles received for CheckDivergenceShort: " + IntegerToString(size));
    
    // Check bearish RSI divergences
    if(IsBearishRSIDivergence(rates)) {
        DebugPrint("Bearish RSI divergence detected");
        confirmations++;
    }
    
    // Check bearish MACD divergences
    if(IsBearishMACDDivergence(rates)) {
        DebugPrint("Bearish MACD divergence detected");
        confirmations++;
    }
    
    DebugPrint("Number of divergence confirmations for sell: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Detect bullish RSI divergence                                     |
//+------------------------------------------------------------------+
bool IsBullishRSIDivergence(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 30) {
        DebugPrint("Error in IsBullishRSIDivergence: Array size too small: " + IntegerToString(size));
        return false;
    }

    if(ArraySize(rsi) < size) {
        DebugPrint("Error in IsBullishRSIDivergence: RSI data size too small: " + IntegerToString(ArraySize(rsi)));
        return false;
    }

    // Minimum separation between swing points to avoid noise
    const int MIN_SWING_SEPARATION = 5;

    int low1_idx = -1, low2_idx = -1;
    double rsi_low1 = 0, rsi_low2 = 0;

    // Find two most recent significant swing lows in price and corresponding RSI values
    // Loop from recent (index 2) to older candles (size-2)
    // In time-series arrays: smaller index = newer, larger index = older
    for(int i = 2; i < size-2; i++)
    {
        // Check if this is a swing low (lower than 2 candles on each side)
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
           rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
        {
            // Store the first swing low found (most recent)
            if(low1_idx == -1)
            {
                low1_idx = i;
                rsi_low1 = rsi[i];
            }
            // Store the second swing low (older) with minimum separation
            else if(low2_idx == -1 && (i - low1_idx) >= MIN_SWING_SEPARATION)
            {
                low2_idx = i;
                rsi_low2 = rsi[i];
                break; // Found both swing lows
            }
        }
    }

    // Check divergence
    if(low1_idx != -1 && low2_idx != -1)
    {
        // In time-series arrays with ArraySetAsSeries=true:
        // Smaller index = newer (more recent), Larger index = older
        // low1_idx is always < low2_idx due to loop structure, so no need for MathMin/MathMax
        int newer_idx = low1_idx;  // Most recent swing low (found first in loop)
        int older_idx = low2_idx;  // Earlier swing low (found second in loop)

        double newer_price = rates[newer_idx].low;
        double older_price = rates[older_idx].low;

        double newer_rsi = rsi_low1;
        double older_rsi = rsi_low2;

        // Bullish divergence: price makes lower low, but RSI makes higher low
        // newer_price < older_price (price declining) AND newer_rsi > older_rsi (RSI rising)
        if(newer_price < older_price && newer_rsi > older_rsi)
            return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Detect bearish RSI divergence                                     |
//+------------------------------------------------------------------+
bool IsBearishRSIDivergence(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 30) {
        DebugPrint("Error in IsBearishRSIDivergence: Array size too small: " + IntegerToString(size));
        return false;
    }

    if(ArraySize(rsi) < size) {
        DebugPrint("Error in IsBearishRSIDivergence: RSI data size too small: " + IntegerToString(ArraySize(rsi)));
        return false;
    }

    // Minimum separation between swing points to avoid noise
    const int MIN_SWING_SEPARATION = 5;

    int high1_idx = -1, high2_idx = -1;
    double rsi_high1 = 0, rsi_high2 = 0;

    // Find two most recent significant swing highs in price and corresponding RSI values
    // Loop from recent (index 2) to older candles (size-2)
    // In time-series arrays: smaller index = newer, larger index = older
    for(int i = 2; i < size-2; i++)
    {
        // Check if this is a swing high (higher than 2 candles on each side)
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
           rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
        {
            // Store the first swing high found (most recent)
            if(high1_idx == -1)
            {
                high1_idx = i;
                rsi_high1 = rsi[i];
            }
            // Store the second swing high (older) with minimum separation
            else if(high2_idx == -1 && (i - high1_idx) >= MIN_SWING_SEPARATION)
            {
                high2_idx = i;
                rsi_high2 = rsi[i];
                break; // Found both swing highs
            }
        }
    }

    // Check divergence
    if(high1_idx != -1 && high2_idx != -1)
    {
        // In time-series arrays with ArraySetAsSeries=true:
        // Smaller index = newer (more recent), Larger index = older
        // high1_idx is always < high2_idx due to loop structure, so no need for MathMin/MathMax
        int newer_idx = high1_idx;  // Most recent swing high (found first in loop)
        int older_idx = high2_idx;  // Earlier swing high (found second in loop)

        double newer_price = rates[newer_idx].high;
        double older_price = rates[older_idx].high;

        double newer_rsi = rsi_high1;
        double older_rsi = rsi_high2;

        // Bearish divergence: price makes higher high, but RSI makes lower high
        // newer_price > older_price (price rising) AND newer_rsi < older_rsi (RSI falling)
        if(newer_price > older_price && newer_rsi < older_rsi)
            return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Detect bullish MACD divergence                                    |
//+------------------------------------------------------------------+
bool IsBullishMACDDivergence(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 30) {
        DebugPrint("Error in IsBullishMACDDivergence: Array size too small: " + IntegerToString(size));
        return false;
    }

    if(ArraySize(macd) < size || ArraySize(macd_signal) < size) {
        DebugPrint("Error in IsBullishMACDDivergence: MACD data size too small: Main=" +
                   IntegerToString(ArraySize(macd)) + ", Signal=" + IntegerToString(ArraySize(macd_signal)));
        return false;
    }

    // Minimum separation between swing points to avoid noise
    const int MIN_SWING_SEPARATION = 5;

    int low1_idx = -1, low2_idx = -1;
    double macd_low1 = 0, macd_low2 = 0;

    // Find two most recent significant swing lows in price and corresponding MACD values
    // Loop from recent (index 2) to older candles (size-2)
    // In time-series arrays: smaller index = newer, larger index = older
    for(int i = 2; i < size-2; i++)
    {
        // Check if this is a swing low (lower than 2 candles on each side)
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
           rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
        {
            // Verify array bounds for MACD access
            if(i >= ArraySize(macd)) continue;

            // Store the first swing low found (most recent)
            if(low1_idx == -1)
            {
                low1_idx = i;
                macd_low1 = macd[i];
            }
            // Store the second swing low (older) with minimum separation
            else if(low2_idx == -1 && (i - low1_idx) >= MIN_SWING_SEPARATION)
            {
                low2_idx = i;
                macd_low2 = macd[i];
                break; // Found both swing lows
            }
        }
    }

    // Check divergence
    if(low1_idx != -1 && low2_idx != -1)
    {
        // In time-series arrays with ArraySetAsSeries=true:
        // Smaller index = newer (more recent), Larger index = older
        // low1_idx is always < low2_idx due to loop structure, so no need for MathMin/MathMax
        int newer_idx = low1_idx;  // Most recent swing low (found first in loop)
        int older_idx = low2_idx;  // Earlier swing low (found second in loop)

        // Verify array bounds before access
        if(newer_idx >= ArraySize(rates) || older_idx >= ArraySize(rates) ||
           newer_idx >= ArraySize(macd) || older_idx >= ArraySize(macd))
            return false;

        double newer_price = rates[newer_idx].low;
        double older_price = rates[older_idx].low;

        double newer_macd = macd_low1;
        double older_macd = macd_low2;

        // Bullish divergence: price makes lower low, but MACD makes higher low
        // newer_price < older_price (price declining) AND newer_macd > older_macd (MACD rising)
        if(newer_price < older_price && newer_macd > older_macd)
            return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Detect bearish MACD divergence                                    |
//+------------------------------------------------------------------+
bool IsBearishMACDDivergence(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 30) {
        DebugPrint("Error in IsBearishMACDDivergence: Array size too small: " + IntegerToString(size));
        return false;
    }

    if(ArraySize(macd) < size || ArraySize(macd_signal) < size) {
        DebugPrint("Error in IsBearishMACDDivergence: MACD data size too small: Main=" +
                   IntegerToString(ArraySize(macd)) + ", Signal=" + IntegerToString(ArraySize(macd_signal)));
        return false;
    }

    // Minimum separation between swing points to avoid noise
    const int MIN_SWING_SEPARATION = 5;

    int high1_idx = -1, high2_idx = -1;
    double macd_high1 = 0, macd_high2 = 0;

    // Find two most recent significant swing highs in price and corresponding MACD values
    // Loop from recent (index 2) to older candles (size-2)
    // In time-series arrays: smaller index = newer, larger index = older
    for(int i = 2; i < size-2; i++)
    {
        // Check if this is a swing high (higher than 2 candles on each side)
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
           rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
        {
            // Verify array bounds for MACD access
            if(i >= ArraySize(macd)) continue;

            // Store the first swing high found (most recent)
            if(high1_idx == -1)
            {
                high1_idx = i;
                macd_high1 = macd[i];
            }
            // Store the second swing high (older) with minimum separation
            else if(high2_idx == -1 && (i - high1_idx) >= MIN_SWING_SEPARATION)
            {
                high2_idx = i;
                macd_high2 = macd[i];
                break; // Found both swing highs
            }
        }
    }

    // Check divergence
    if(high1_idx != -1 && high2_idx != -1)
    {
        // In time-series arrays with ArraySetAsSeries=true:
        // Smaller index = newer (more recent), Larger index = older
        // high1_idx is always < high2_idx due to loop structure, so no need for MathMin/MathMax
        int newer_idx = high1_idx;  // Most recent swing high (found first in loop)
        int older_idx = high2_idx;  // Earlier swing high (found second in loop)

        // Verify array bounds before access
        if(newer_idx >= ArraySize(rates) || older_idx >= ArraySize(rates) ||
           newer_idx >= ArraySize(macd) || older_idx >= ArraySize(macd))
            return false;

        double newer_price = rates[newer_idx].high;
        double older_price = rates[older_idx].high;

        double newer_macd = macd_high1;
        double older_macd = macd_high2;

        // Bearish divergence: price makes higher high, but MACD makes lower high
        // newer_price > older_price (price rising) AND newer_macd < older_macd (MACD falling)
        if(newer_price > older_price && newer_macd < older_macd)
            return true;
    }

    return false;
}