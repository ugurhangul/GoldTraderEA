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
    
    // Get price data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), PA_Timeframe, 0, 50, rates);
    
    if(copied < 20) {
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
    
    // Get price data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), PA_Timeframe, 0, 50, rates);
    
    if(copied < 20) {
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
    if(size < 20) return false;
    
    // Find resistance level from the last 10 candles
    double resistance = 0;
    for(int i = 10; i > 0; i--)
    {
        if(i >= size) continue;
        
        // Define resistance as the highest peak in the last 10 candles
        if(rates[i].high > resistance)
            resistance = rates[i].high;
    }
    
    // Check breakout above resistance
    if(resistance > 0 && rates[0].close > resistance)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Check breakout below support                                      |
//+------------------------------------------------------------------+
bool IsBreakoutBelowSupport(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 20) return false;
    
    // Find support level from the last 10 candles
    double support = DBL_MAX;
    for(int i = 10; i > 0; i--)
    {
        if(i >= size) continue;
        
        // Define support as the lowest trough in the last 10 candles
        if(rates[i].low < support)
            support = rates[i].low;
    }
    
    // Check breakout below support
    if(support < DBL_MAX && rates[0].close < support)
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
    
    // Check for higher lows and higher highs
    double prev_low = rates[9].low;
    double prev_high = rates[9].high;
    int higher_lows = 0;
    int higher_highs = 0;
    
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
        if(i > 0 && i < size)
        {
            if(rates[i-1].high > prev_high)
            {
                higher_highs++;
                prev_high = rates[i-1].high;
            }
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
    
    // Check for lower lows and lower highs
    double prev_low = rates[9].low;
    double prev_high = rates[9].high;
    int lower_lows = 0;
    int lower_highs = 0;
    
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
        if(i > 0 && i < size)
        {
            if(rates[i-1].high < prev_high)
            {
                lower_highs++;
                prev_high = rates[i-1].high;
            }
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
    if(size < 20) return false;
    
    // Find the recent trough
    int trough_idx = -1;
    for(int i = 5; i >= 1; i--)
    {
        if(i+1 >= size || i-1 < 0) continue;
        
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
        {
            trough_idx = i;
            break;
        }
    }
    
    if(trough_idx == -1) return false;
    
    // Check if price has risen after testing support
    return (rates[0].close > rates[trough_idx].low && rates[0].close > rates[0].open);
}

//+------------------------------------------------------------------+
//| Check active resistance                                          |
//+------------------------------------------------------------------+
bool IsActiveResistanceHolding(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 20) return false;
    
    // Find the recent peak
    int peak_idx = -1;
    for(int i = 5; i >= 1; i--)
    {
        if(i+1 >= size || i-1 < 0) continue;
        
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            peak_idx = i;
            break;
        }
    }
    
    if(peak_idx == -1) return false;
    
    // Check if price has fallen after testing resistance
    return (rates[0].close < rates[peak_idx].high && rates[0].close < rates[0].open);
}

// Note: IsThreeWhiteSoldiers and IsThreeBlackCrows are defined in CandlePatterns.mqh
// Note: CheckTrendPatternsBuy and CheckTrendPatternsShort are defined in TrendPatterns.mqh 