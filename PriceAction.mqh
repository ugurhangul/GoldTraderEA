//+------------------------------------------------------------------+
//|                                                 PriceAction.mqh |
//|                                      Copyright 2023, Gold Trader   |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Include required files
#include "TrendPatterns.mqh"
#include "CandlePatterns.mqh"

// Declare external variables needed
extern ENUM_TIMEFRAMES PA_Timeframe;

// The DebugPrint function must be defined in the main file
#import "GoldTraderEA_cleaned.mq5"
   void DebugPrint(string message);
#import

//+------------------------------------------------------------------+
//| Check price action for buy                                       |
//+------------------------------------------------------------------+
int CheckPriceActionBuy()
{
    DebugPrint("Starting to check price action patterns for buy");

    int confirmations = 0;

    // Get price data - increased to 100 for trend pattern analysis
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), PA_Timeframe, 0, 100, rates);

    if(copied < 30) {
        DebugPrint("Error retrieving data for CheckPriceActionBuy: " + IntegerToString(GetLastError()));
        return 0;
    }

    DebugPrint("Number of candles retrieved for CheckPriceActionBuy: " + IntegerToString(copied));

    // Use trend breakout patterns
    confirmations += CheckTrendPatternsBuy(rates);

    // Three White Soldiers
    if(IsThreeWhiteSoldiers(rates))
        confirmations++;

    // Check breakout above resistance
    if(IsBreakoutAboveResistance(rates))
        confirmations++;

    // Check bullish price formation
    if(IsBullishPriceFormation(rates))
        confirmations++;

    // Check active support
    if(IsActiveSupportHolding(rates))
        confirmations++;

    DebugPrint("Number of price action confirmations for buy: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Check price action for sell                                       |
//+------------------------------------------------------------------+
int CheckPriceActionShort()
{
    DebugPrint("Starting to check price action patterns for sell");

    int confirmations = 0;

    // Get price data - increased to 100 for trend pattern analysis
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), PA_Timeframe, 0, 100, rates);

    if(copied < 30) {
        DebugPrint("Error retrieving data for CheckPriceActionShort: " + IntegerToString(GetLastError()));
        return 0;
    }

    DebugPrint("Number of candles retrieved for CheckPriceActionShort: " + IntegerToString(copied));

    // Use trend breakout patterns
    confirmations += CheckTrendPatternsShort(rates);

    // Three Black Crows
    if(IsThreeBlackCrows(rates))
        confirmations++;

    // Check breakout below support
    if(IsBreakoutBelowSupport(rates))
        confirmations++;

    // Check bearish price formation
    if(IsBearishPriceFormation(rates))
        confirmations++;

    // Check active resistance
    if(IsActiveResistanceHolding(rates))
        confirmations++;

    DebugPrint("Number of price action confirmations for sell: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Check breakout above resistance                                   |
//+------------------------------------------------------------------+
bool IsBreakoutAboveResistance(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 21) return false;  // Need at least 21 candles (0-20)

    // Find resistance level from candles 1-20 (excluding current candle at index 0)
    // We look at historical candles to find the resistance level that price is breaking
    double resistance = 0;
    for(int i = 1; i <= 20; i++)
    {
        if(i >= size) continue;

        // Define resistance as the highest peak in the last 20 candles (excluding current)
        if(rates[i].high > resistance)
            resistance = rates[i].high;
    }

    // Check breakout above resistance
    // Current candle's close should be above the historical resistance
    // and previous candle should have been below or at resistance
    if(resistance > 0 && rates[0].close > resistance &&
       (size < 2 || rates[1].close <= resistance))
        return true;

    return false;
}

//+------------------------------------------------------------------+
//| Check breakout below support                                      |
//+------------------------------------------------------------------+
bool IsBreakoutBelowSupport(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 21) return false;  // Need at least 21 candles (0-20)

    // Find support level from candles 1-20 (excluding current candle at index 0)
    // We look at historical candles to find the support level that price is breaking
    double support = DBL_MAX;
    for(int i = 1; i <= 20; i++)
    {
        if(i >= size) continue;

        // Define support as the lowest trough in the last 20 candles (excluding current)
        if(rates[i].low < support)
            support = rates[i].low;
    }

    // Check breakout below support
    // Current candle's close should be below the historical support
    // and previous candle should have been above or at support
    if(support < DBL_MAX && rates[0].close < support &&
       (size < 2 || rates[1].close >= support))
        return true;

    return false;
}

//+------------------------------------------------------------------+
//| Check bullish price formation                                     |
//+------------------------------------------------------------------+
bool IsBullishPriceFormation(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 10) return false;

    // Check for higher lows and higher highs over the last 10 candles
    double prev_low = rates[9].low;
    double prev_high = rates[9].high;
    int higher_lows = 0;
    int higher_highs = 0;

    // Loop through candles from oldest to newest (9 to 0), checking every 2nd candle
    for(int i = 8; i >= 0; i-=2)
    {
        if(i >= size) continue;

        // Check for higher lows
        if(rates[i].low > prev_low)
        {
            higher_lows++;
            prev_low = rates[i].low;
        }

        // Check for higher highs
        if(rates[i].high > prev_high)
        {
            higher_highs++;
            prev_high = rates[i].high;
        }
    }

    // Must have at least 3 higher lows or 3 higher highs
    return (higher_lows >= 3 || higher_highs >= 3);
}

//+------------------------------------------------------------------+
//| Check bearish price formation                                     |
//+------------------------------------------------------------------+
bool IsBearishPriceFormation(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 10) return false;

    // Check for lower lows and lower highs over the last 10 candles
    double prev_low = rates[9].low;
    double prev_high = rates[9].high;
    int lower_lows = 0;
    int lower_highs = 0;

    // Loop through candles from oldest to newest (9 to 0), checking every 2nd candle
    for(int i = 8; i >= 0; i-=2)
    {
        if(i >= size) continue;

        // Check for lower lows
        if(rates[i].low < prev_low)
        {
            lower_lows++;
            prev_low = rates[i].low;
        }

        // Check for lower highs
        if(rates[i].high < prev_high)
        {
            lower_highs++;
            prev_high = rates[i].high;
        }
    }

    // Must have at least 3 lower lows or 3 lower highs
    return (lower_lows >= 3 || lower_highs >= 3);
}

//+------------------------------------------------------------------+
//| Check active support                                             |
//+------------------------------------------------------------------+
bool IsActiveSupportHolding(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 13) return false;  // Need at least 13 candles (0-12 for i+2 when i=10)

    // Find the recent trough (local minimum) in a wider window
    // A true trough should be the lowest point within a 5-candle window
    int trough_idx = -1;
    double trough_value = DBL_MAX;

    for(int i = 3; i <= 10; i++)
    {
        if(i >= size) continue;

        // Check if this is a local minimum (lower than 2 candles on each side)
        bool is_trough = true;
        for(int j = i - 2; j <= i + 2; j++)
        {
            if(j < 0 || j >= size || j == i) continue;
            if(rates[j].low <= rates[i].low)
            {
                is_trough = false;
                break;
            }
        }

        // Take the lowest trough found
        if(is_trough && rates[i].low < trough_value)
        {
            trough_idx = i;
            trough_value = rates[i].low;
        }
    }

    if(trough_idx == -1) return false;

    // Check if price has risen after testing support
    // Current candle should be bullish and close above the trough
    return (rates[0].close > rates[trough_idx].low && rates[0].close > rates[0].open);
}

//+------------------------------------------------------------------+
//| Check active resistance                                          |
//+------------------------------------------------------------------+
bool IsActiveResistanceHolding(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 13) return false;  // Need at least 13 candles (0-12 for i+2 when i=10)

    // Find the recent peak (local maximum) in a wider window
    // A true peak should be the highest point within a 5-candle window
    int peak_idx = -1;
    double peak_value = 0;

    for(int i = 3; i <= 10; i++)
    {
        if(i >= size) continue;

        // Check if this is a local maximum (higher than 2 candles on each side)
        bool is_peak = true;
        for(int j = i - 2; j <= i + 2; j++)
        {
            if(j < 0 || j >= size || j == i) continue;
            if(rates[j].high >= rates[i].high)
            {
                is_peak = false;
                break;
            }
        }

        // Take the highest peak found
        if(is_peak && rates[i].high > peak_value)
        {
            peak_idx = i;
            peak_value = rates[i].high;
        }
    }

    if(peak_idx == -1) return false;

    // Check if price has fallen after testing resistance
    // Current candle should be bearish and close below the peak
    return (rates[0].close < rates[peak_idx].high && rates[0].close < rates[0].open);
}

// Note: IsThreeWhiteSoldiers and IsThreeBlackCrows are defined in CandlePatterns.mqh
// Note: CheckTrendPatternsBuy and CheckTrendPatternsShort are defined in TrendPatterns.mqh 