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
    if(size < 20) {
        DebugPrint("Error in IsBullishRSIDivergence: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    if(ArraySize(rsi) < size) {
        DebugPrint("Error in IsBullishRSIDivergence: RSI data size too small: " + IntegerToString(ArraySize(rsi)));
        return false;
    }
    
    int low1_idx = -1, low2_idx = -1;
    double low1_val = DBL_MAX, low2_val = DBL_MAX;
    double rsi_low1 = 0, rsi_low2 = 0;

    // Find two most recent significant swing lows in price and corresponding RSI values
    for(int i = 2; i < size-2; i++)
    {
        if(!CheckArrayAccess(i, size, "IsBullishRSIDivergence") ||
           !CheckArrayAccess(i+1, size, "IsBullishRSIDivergence") ||
           !CheckArrayAccess(i-1, size, "IsBullishRSIDivergence") ||
           !CheckArrayAccess(i+2, size, "IsBullishRSIDivergence") ||
           !CheckArrayAccess(i-2, size, "IsBullishRSIDivergence"))
            continue;

        // Check if this is a swing low (lower than 2 candles on each side)
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
           rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
        {
            // Store the two most recent swing lows
            if(low1_idx == -1)
            {
                low1_idx = i;
                low1_val = rates[i].low;
                rsi_low1 = rsi[i];
            }
            else if(low2_idx == -1)
            {
                low2_idx = i;
                low2_val = rates[i].low;
                rsi_low2 = rsi[i];
                break; // Found both swing lows
            }
        }
    }
    
    // Check divergence
    if(low1_idx != -1 && low2_idx != -1)
    {
        int earlier_idx = MathMax(low1_idx, low2_idx);
        int later_idx = MathMin(low1_idx, low2_idx);
        
        double earlier_price = rates[earlier_idx].low;
        double later_price = rates[later_idx].low;
        
        double earlier_rsi = earlier_idx == low1_idx ? rsi_low1 : rsi_low2;
        double later_rsi = later_idx == low1_idx ? rsi_low1 : rsi_low2;
        
        // Second low price is lower but RSI is higher = bullish divergence
        if(later_price < earlier_price && later_rsi > earlier_rsi)
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
    if(size < 20) {
        DebugPrint("Error in IsBearishRSIDivergence: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    if(ArraySize(rsi) < size) {
        DebugPrint("Error in IsBearishRSIDivergence: RSI data size too small: " + IntegerToString(ArraySize(rsi)));
        return false;
    }
    
    int high1_idx = -1, high2_idx = -1;
    double high1_val = -DBL_MAX, high2_val = -DBL_MAX;
    double rsi_high1 = 0, rsi_high2 = 0;

    // Find two most recent significant swing highs in price and corresponding RSI values
    for(int i = 2; i < size-2; i++)
    {
        if(!CheckArrayAccess(i, size, "IsBearishRSIDivergence") ||
           !CheckArrayAccess(i+1, size, "IsBearishRSIDivergence") ||
           !CheckArrayAccess(i-1, size, "IsBearishRSIDivergence") ||
           !CheckArrayAccess(i+2, size, "IsBearishRSIDivergence") ||
           !CheckArrayAccess(i-2, size, "IsBearishRSIDivergence"))
            continue;

        // Check if this is a swing high (higher than 2 candles on each side)
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
           rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
        {
            // Store the two most recent swing highs
            if(high1_idx == -1)
            {
                high1_idx = i;
                high1_val = rates[i].high;
                rsi_high1 = rsi[i];
            }
            else if(high2_idx == -1)
            {
                high2_idx = i;
                high2_val = rates[i].high;
                rsi_high2 = rsi[i];
                break; // Found both swing highs
            }
        }
    }
    
    // Check divergence
    if(high1_idx != -1 && high2_idx != -1)
    {
        int earlier_idx = MathMax(high1_idx, high2_idx);
        int later_idx = MathMin(high1_idx, high2_idx);
        
        double earlier_price = rates[earlier_idx].high;
        double later_price = rates[later_idx].high;
        
        double earlier_rsi = earlier_idx == high1_idx ? rsi_high1 : rsi_high2;
        double later_rsi = later_idx == high1_idx ? rsi_high1 : rsi_high2;
        
        // Second high price is higher but RSI is lower = bearish divergence
        if(later_price > earlier_price && later_rsi < earlier_rsi)
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
    if(size < 20) {
        DebugPrint("Error in IsBullishMACDDivergence: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    if(ArraySize(macd) < size || ArraySize(macd_signal) < size) {
        DebugPrint("Error in IsBullishMACDDivergence: MACD data size too small: Main=" + 
                   IntegerToString(ArraySize(macd)) + ", Signal=" + IntegerToString(ArraySize(macd_signal)));
        return false;
    }
    
    int low1_idx = -1, low2_idx = -1;
    double low1_val = DBL_MAX, low2_val = DBL_MAX;
    double macd_low1 = 0, macd_low2 = 0;

    // Find two most recent significant swing lows in price and corresponding MACD values
    for(int i = 2; i < size-2; i++)
    {
        if(!CheckArrayAccess(i, size, "IsBullishMACDDivergence") ||
           !CheckArrayAccess(i+1, size, "IsBullishMACDDivergence") ||
           !CheckArrayAccess(i-1, size, "IsBullishMACDDivergence") ||
           !CheckArrayAccess(i+2, size, "IsBullishMACDDivergence") ||
           !CheckArrayAccess(i-2, size, "IsBullishMACDDivergence"))
            continue;

        // Check if this is a swing low (lower than 2 candles on each side)
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
           rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
        {
            // Verify array bounds for MACD access
            if(i >= ArraySize(macd)) continue;

            // Store the two most recent swing lows
            if(low1_idx == -1)
            {
                low1_idx = i;
                low1_val = rates[i].low;
                macd_low1 = macd[i];
            }
            else if(low2_idx == -1)
            {
                low2_idx = i;
                low2_val = rates[i].low;
                macd_low2 = macd[i];
                break; // Found both swing lows
            }
        }
    }

    // Check divergence
    if(low1_idx != -1 && low2_idx != -1)
    {
        int earlier_idx = MathMax(low1_idx, low2_idx);
        int later_idx = MathMin(low1_idx, low2_idx);

        // Verify array bounds before access
        if(earlier_idx >= ArraySize(rates) || later_idx >= ArraySize(rates) ||
           earlier_idx >= ArraySize(macd) || later_idx >= ArraySize(macd))
            return false;

        double earlier_price = rates[earlier_idx].low;
        double later_price = rates[later_idx].low;

        double earlier_macd = earlier_idx == low1_idx ? macd_low1 : macd_low2;
        double later_macd = later_idx == low1_idx ? macd_low1 : macd_low2;
        
        // Second low price is lower but MACD is higher = bullish divergence
        if(later_price < earlier_price && later_macd > earlier_macd)
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
    if(size < 20) {
        DebugPrint("Error in IsBearishMACDDivergence: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    if(ArraySize(macd) < size || ArraySize(macd_signal) < size) {
        DebugPrint("Error in IsBearishMACDDivergence: MACD data size too small: Main=" + 
                   IntegerToString(ArraySize(macd)) + ", Signal=" + IntegerToString(ArraySize(macd_signal)));
        return false;
    }
    
    int high1_idx = -1, high2_idx = -1;
    double high1_val = -DBL_MAX, high2_val = -DBL_MAX;
    double macd_high1 = 0, macd_high2 = 0;

    // Find two most recent significant swing highs in price and corresponding MACD values
    for(int i = 2; i < size-2; i++)
    {
        if(!CheckArrayAccess(i, size, "IsBearishMACDDivergence") ||
           !CheckArrayAccess(i+1, size, "IsBearishMACDDivergence") ||
           !CheckArrayAccess(i-1, size, "IsBearishMACDDivergence") ||
           !CheckArrayAccess(i+2, size, "IsBearishMACDDivergence") ||
           !CheckArrayAccess(i-2, size, "IsBearishMACDDivergence"))
            continue;

        // Check if this is a swing high (higher than 2 candles on each side)
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
           rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
        {
            // Verify array bounds for MACD access
            if(i >= ArraySize(macd)) continue;

            // Store the two most recent swing highs
            if(high1_idx == -1)
            {
                high1_idx = i;
                high1_val = rates[i].high;
                macd_high1 = macd[i];
            }
            else if(high2_idx == -1)
            {
                high2_idx = i;
                high2_val = rates[i].high;
                macd_high2 = macd[i];
                break; // Found both swing highs
            }
        }
    }

    // Check divergence
    if(high1_idx != -1 && high2_idx != -1)
    {
        int earlier_idx = MathMax(high1_idx, high2_idx);
        int later_idx = MathMin(high1_idx, high2_idx);

        // Verify array bounds before access
        if(earlier_idx >= ArraySize(rates) || later_idx >= ArraySize(rates) ||
           earlier_idx >= ArraySize(macd) || later_idx >= ArraySize(macd))
            return false;

        double earlier_price = rates[earlier_idx].high;
        double later_price = rates[later_idx].high;

        double earlier_macd = earlier_idx == high1_idx ? macd_high1 : macd_high2;
        double later_macd = later_idx == high1_idx ? macd_high1 : macd_high2;
        
        // Second high price is higher but MACD is lower = bearish divergence
        if(later_price > earlier_price && later_macd < earlier_macd)
            return true;
    }
    
    return false;
} 