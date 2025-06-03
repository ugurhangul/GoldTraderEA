//+------------------------------------------------------------------+
//|                                                   Indicators.mqh |
//|                                      Copyright 2023, Gold Trader   |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Declare external variables needed
extern ENUM_TIMEFRAMES IND_Timeframe;

// Public variables for indicators that must be defined in the main file
extern int handle_rsi, handle_macd, handle_adx, handle_stoch, handle_ma_fast, handle_ma_slow, handle_bbands;
extern double rsi[], macd[], macd_signal[], adx[], stoch_k[], stoch_d[], ma_fast[], ma_slow[], bb_upper[], bb_middle[], bb_lower[];

// Additional moving average variables for crossovers
extern int handle_ma_50, handle_ma_200;
extern double ma_50[], ma_200[];

// Variables related to volume analysis
extern int handle_volumes;
extern long g_volumes[];

// The DebugPrint function must be defined in the main file
#import "GoldTraderEA_cleaned.mq5"
   void DebugPrint(string message);
#import

// The CheckArrayAccess function must be defined in the main file
#import "GoldTraderEA_cleaned.mq5"
bool CheckArrayAccess(int index, int array_size, string function_name);
#import

//+------------------------------------------------------------------+
//| Check indicators for buy with error protection                    |
//+------------------------------------------------------------------+
bool SafeCheckIndicatorsBuy(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 3) {
        DebugPrint("The rates array for SafeCheckIndicatorsBuy is smaller than the required size");
        return false;
    }
    
    // Check indicator arrays size
    if(ArraySize(rsi) < 3 || ArraySize(macd) < 3) {
        DebugPrint("Some indicator arrays for SafeCheckIndicatorsBuy are smaller than the required size");
        return false;
    }
    
    bool result = false;
    
    // Execute function with error protection
    int error = 0;
    
    // Attempt to execute the function
    result = CheckIndicatorsBuy(rates);
    
    if(error != 0) {
        DebugPrint("Error executing CheckIndicatorsBuy: " + IntegerToString(error));
        return false;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Check indicators for sell with error protection                   |
//+------------------------------------------------------------------+
bool SafeCheckIndicatorsShort(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 3) {
        DebugPrint("The rates array for SafeCheckIndicatorsShort is smaller than the required size");
        return false;
    }
    
    // Check indicator arrays size
    if(ArraySize(rsi) < 3 || ArraySize(macd) < 3) {
        DebugPrint("Some indicator arrays for SafeCheckIndicatorsShort are smaller than the required size");
        return false;
    }
    
    bool result = false;
    
    // Execute function with error protection
    int error = 0;
    
    // Attempt to execute the function
    result = CheckIndicatorsShort(rates);
    
    if(error != 0) {
        DebugPrint("Error executing CheckIndicatorsShort: " + IntegerToString(error));
        return false;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Check indicators for buy signal                                   |
//+------------------------------------------------------------------+
bool CheckIndicatorsBuy(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 3) {
        DebugPrint("The rates array for CheckIndicatorsBuy is smaller than the required size");
        return false;
    }
    
    // Check indicator arrays size
    if(ArraySize(rsi) < 3 || ArraySize(macd) < 3) {
        DebugPrint("Some indicator arrays for CheckIndicatorsBuy are smaller than the required size");
        return false;
    }
    
    // Check buy conditions using indicators
    bool rsi_buy = false;
    bool macd_buy = false;
    bool stoch_buy = false;
    bool adx_buy = false;
    bool ma_buy = false;
    bool bands_buy = false;
    bool volume_buy = false;
    bool candle_pattern = false;
    bool wedge_pattern = false;
    
    // RSI
    rsi_buy = (rsi[0] > rsi[1] && rsi[1] > rsi[2] && rsi[0] < 70 && rsi[1] < 30);
    
    // MACD
    macd_buy = (macd[0] > macd_signal[0] && macd[1] < macd_signal[1]);
    
    // Stochastic
    stoch_buy = (stoch_k[0] > stoch_d[0] && stoch_k[1] < stoch_d[1] && stoch_k[0] < 80);
    
    // ADX
    adx_buy = (adx[0] > 25);
    
    // Moving Averages
    ma_buy = (ma_fast[0] > ma_slow[0] && ma_fast[1] < ma_slow[1]);
    
    // Bollinger Bands
    bands_buy = (rates[0].close < bb_lower[0] || 
                (rates[0].close > bb_middle[0] && rates[1].close < bb_middle[1]));
    
    // Volume
    if(ArraySize(g_volumes) > 2) {
        volume_buy = (g_volumes[0] > g_volumes[1] && g_volumes[1] > g_volumes[2]);
    }
    
    // Candle Pattern
    candle_pattern = (FindCandlestickPattern(rates, 1) > 0);
    
    // Check bullish wedge pattern
    wedge_pattern = IsBullishWedge(rates);
    
    // Combine various conditions
    // At least 3 out of 7 conditions must be met
    int conditions_count = 0;
    
    if(rsi_buy) conditions_count++;
    if(macd_buy) conditions_count++;
    if(stoch_buy) conditions_count++;
    if(adx_buy) conditions_count++;
    if(ma_buy) conditions_count++;
    if(bands_buy) conditions_count++;
    if(volume_buy) conditions_count++;
    if(candle_pattern) conditions_count++;
    if(wedge_pattern) conditions_count++;
    
    return (conditions_count >= 3);
}

//+------------------------------------------------------------------+
//| Check indicators for sell signal                                  |
//+------------------------------------------------------------------+
bool CheckIndicatorsShort(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 3) {
        DebugPrint("The rates array for CheckIndicatorsShort is smaller than the required size");
        return false;
    }
    
    // Check indicator arrays size
    if(ArraySize(rsi) < 3 || ArraySize(macd) < 3) {
        DebugPrint("Some indicator arrays for CheckIndicatorsShort are smaller than the required size");
        return false;
    }
    
    // Check sell conditions using indicators
    bool rsi_sell = false;
    bool macd_sell = false;
    bool stoch_sell = false;
    bool adx_sell = false;
    bool ma_sell = false;
    bool bands_sell = false;
    bool volume_sell = false;
    bool candle_pattern = false;
    bool wedge_pattern = false;
    
    // RSI
    rsi_sell = (rsi[0] < rsi[1] && rsi[1] < rsi[2] && rsi[0] > 30 && rsi[1] > 70);
    
    // MACD
    macd_sell = (macd[0] < macd_signal[0] && macd[1] > macd_signal[1]);
    
    // Stochastic
    stoch_sell = (stoch_k[0] < stoch_d[0] && stoch_k[1] > stoch_d[1] && stoch_k[0] > 20);
    
    // ADX
    adx_sell = (adx[0] > 25);
    
    // Moving Averages
    ma_sell = (ma_fast[0] < ma_slow[0] && ma_fast[1] > ma_slow[1]);
    
    // Bollinger Bands
    bands_sell = (rates[0].close > bb_upper[0] || 
                 (rates[0].close < bb_middle[0] && rates[1].close > bb_middle[1]));
    
    // Volume
    if(ArraySize(g_volumes) > 2) {
        volume_sell = (g_volumes[0] > g_volumes[1] && g_volumes[1] > g_volumes[2]);
    }
    
    // Candle Pattern
    candle_pattern = (FindCandlestickPattern(rates, 0) > 0);
    
    // Check bearish wedge pattern
    wedge_pattern = IsBearishWedge(rates);
    
    // Combine various conditions
    // At least 3 out of 7 conditions must be met
    int conditions_count = 0;
    
    if(rsi_sell) conditions_count++;
    if(macd_sell) conditions_count++;
    if(stoch_sell) conditions_count++;
    if(adx_sell) conditions_count++;
    if(ma_sell) conditions_count++;
    if(bands_sell) conditions_count++;
    if(volume_sell) conditions_count++;
    if(candle_pattern) conditions_count++;
    if(wedge_pattern) conditions_count++;
    
    return (conditions_count >= 3);
}

// Define functions that are called from other files
// These functions are defined in the respective files

// The FindCandlestickPattern function is defined in the CandlePatterns.mqh file
#import "CandlePatterns.mqh"
   int FindCandlestickPattern(MqlRates &rates[], int bullish_pattern);
#import

// The IsBullishWedge and IsBearishWedge functions are defined in the ChartPatterns.mqh file
#import "ChartPatterns.mqh"
   bool IsBullishWedge(MqlRates &rates[]);
   bool IsBearishWedge(MqlRates &rates[]);
#import 