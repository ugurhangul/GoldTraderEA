//+------------------------------------------------------------------+
//|                                              MACrossover.mqh |
//|                                      Copyright 2023, Gold Trader   |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Adding import to use G_Debug variable
#import "GoldTraderEA_cleaned.mq5"
    void DebugPrint(string message);
    bool GetDebugMode();
#import

// Declare necessary variables (without extern) with different names to avoid conflicts
ENUM_TIMEFRAMES g_MAC_Timeframe = PERIOD_H1;

// Moving average settings
int FastMAperiod = 8;       // Fast moving average period
int SlowMAperiod = 21;      // Slow moving average period
int LongMAperiod = 200;     // Long-term moving average period (overall trend)
ENUM_MA_METHOD MAtype = MODE_EMA; // Type of moving average (EMA)
ENUM_APPLIED_PRICE MAappliedPrice = PRICE_CLOSE; // Price used for calculation

// Default values for moving averages set in OnInit
int DefaultFastMAperiod = 8;
int DefaultSlowMAperiod = 21;
int DefaultLongMAperiod = 200;
ENUM_MA_METHOD DefaultMAtype = MODE_EMA;
ENUM_APPLIED_PRICE DefaultMAappliedPrice = PRICE_CLOSE;

// Remove circular reference
// #import "GoldTraderEA_cleaned.mq5"
//    void DebugPrint(string message);
// #import

//+------------------------------------------------------------------+
//| Set the timeframe for this module                                 |
//+------------------------------------------------------------------+
void SetMACTimeframe(ENUM_TIMEFRAMES timeframe)
{
    g_MAC_Timeframe = timeframe;
}

//+------------------------------------------------------------------+
//| Set moving average parameters                                      |
//+------------------------------------------------------------------+
void SetMAParameters(int fastPeriod, int slowPeriod, int longPeriod, ENUM_MA_METHOD maMethod, ENUM_APPLIED_PRICE appliedPrice)
{
    FastMAperiod = fastPeriod;
    SlowMAperiod = slowPeriod;
    LongMAperiod = longPeriod;
    MAtype = maMethod;
    MAappliedPrice = appliedPrice;
}

//+------------------------------------------------------------------+
//| Check moving average crossover for buy signal                    |
//+------------------------------------------------------------------+
int CheckMACrossoverBuy(MqlRates &rates[])
{
    // Ensure access to minimum required data
    int size = ArraySize(rates);
    if(size < LongMAperiod + 10) {
        if(GetDebugMode()) 
            DebugPrint("Not enough historical data to check moving average crossover");
        return 0;
    }
    
    // Calculate moving average values
    double fastMA[3];  // Fast moving average values for the last 3 candles
    double slowMA[3];  // Slow moving average values for the last 3 candles
    double longMA[3];  // Long-term moving average values for the last 3 candles
    
    // Access indicators through handles
    int handle_fast = iMA(Symbol(), g_MAC_Timeframe, FastMAperiod, 0, MAtype, MAappliedPrice);
    int handle_slow = iMA(Symbol(), g_MAC_Timeframe, SlowMAperiod, 0, MAtype, MAappliedPrice);
    int handle_long = iMA(Symbol(), g_MAC_Timeframe, LongMAperiod, 0, MAtype, MAappliedPrice);
    
    // Fast moving average
    for(int i = 0; i < 3; i++) {
        double temp_buf[1];
        if(CopyBuffer(handle_fast, 0, i, 1, temp_buf) <= 0) {
            if(GetDebugMode()) DebugPrint("Error retrieving fast moving average values");
            return 0;
        }
        fastMA[i] = temp_buf[0];
    }
    
    // Slow moving average
    for(int i = 0; i < 3; i++) {
        double temp_buf[1];
        if(CopyBuffer(handle_slow, 0, i, 1, temp_buf) <= 0) {
            if(GetDebugMode()) DebugPrint("Error retrieving slow moving average values");
            return 0;
        }
        slowMA[i] = temp_buf[0];
    }
    
    // Long-term moving average
    for(int i = 0; i < 3; i++) {
        double temp_buf[1];
        if(CopyBuffer(handle_long, 0, i, 1, temp_buf) <= 0) {
            if(GetDebugMode()) DebugPrint("Error retrieving long-term moving average values");
            return 0;
        }
        longMA[i] = temp_buf[0];
    }
    
    int confirmations = 0;
    
    // Check crossover of fast and slow moving averages (golden cross)
    if(fastMA[0] > slowMA[0] && fastMA[1] <= slowMA[1]) {
        confirmations++;
        if(GetDebugMode()) DebugPrint("Golden cross of fast and slow moving averages detected");
    }
    
    // Check if price is above long-term moving average (uptrend)
    if(rates[0].close > longMA[0]) {
        confirmations++;
        if(GetDebugMode()) DebugPrint("Price is above the long-term moving average (uptrend)");
    }
    
    // Check if the slope of the fast moving average is upward
    if(fastMA[0] > fastMA[1] && fastMA[1] > fastMA[2]) {
        confirmations++;
        if(GetDebugMode()) DebugPrint("Slope of the fast moving average is upward");
    }
    
    return confirmations;
}

//+------------------------------------------------------------------+
//| Check moving average crossover for sell signal                    |
//+------------------------------------------------------------------+
int CheckMACrossoverShort(MqlRates &rates[])
{
    // Ensure access to minimum required data
    int size = ArraySize(rates);
    if(size < LongMAperiod + 10) {
        if(GetDebugMode()) 
            DebugPrint("Not enough historical data to check moving average crossover");
        return 0;
    }
    
    // Calculate moving average values
    double fastMA[3];  // Fast moving average values for the last 3 candles
    double slowMA[3];  // Slow moving average values for the last 3 candles
    double longMA[3];  // Long-term moving average values for the last 3 candles
    
    // Access indicators through handles
    int handle_fast = iMA(Symbol(), g_MAC_Timeframe, FastMAperiod, 0, MAtype, MAappliedPrice);
    int handle_slow = iMA(Symbol(), g_MAC_Timeframe, SlowMAperiod, 0, MAtype, MAappliedPrice);
    int handle_long = iMA(Symbol(), g_MAC_Timeframe, LongMAperiod, 0, MAtype, MAappliedPrice);
    
    // Fast moving average
    for(int i = 0; i < 3; i++) {
        double temp_buf[1];
        if(CopyBuffer(handle_fast, 0, i, 1, temp_buf) <= 0) {
            if(GetDebugMode()) DebugPrint("Error retrieving fast moving average values");
            return 0;
        }
        fastMA[i] = temp_buf[0];
    }
    
    // Slow moving average
    for(int i = 0; i < 3; i++) {
        double temp_buf[1];
        if(CopyBuffer(handle_slow, 0, i, 1, temp_buf) <= 0) {
            if(GetDebugMode()) DebugPrint("Error retrieving slow moving average values");
            return 0;
        }
        slowMA[i] = temp_buf[0];
    }
    
    // Long-term moving average
    for(int i = 0; i < 3; i++) {
        double temp_buf[1];
        if(CopyBuffer(handle_long, 0, i, 1, temp_buf) <= 0) {
            if(GetDebugMode()) DebugPrint("Error retrieving long-term moving average values");
            return 0;
        }
        longMA[i] = temp_buf[0];
    }
    
    int confirmations = 0;
    
    // Check crossover of fast and slow moving averages (death cross)
    if(fastMA[0] < slowMA[0] && fastMA[1] >= slowMA[1]) {
        confirmations++;
        if(GetDebugMode()) DebugPrint("Death cross of fast and slow moving averages detected");
    }
    
    // Check if price is below long-term moving average (downtrend)
    if(rates[0].close < longMA[0]) {
        confirmations++;
        if(GetDebugMode()) DebugPrint("Price is below the long-term moving average (downtrend)");
    }
    
    // Check if the slope of the fast moving average is downward
    if(fastMA[0] < fastMA[1] && fastMA[1] < fastMA[2]) {
        confirmations++;
        if(GetDebugMode()) DebugPrint("Slope of the fast moving average is downward");
    }
    
    return confirmations;
}

//+------------------------------------------------------------------+
//| Check moving average divergence                                    |
//+------------------------------------------------------------------+
bool IsMaDivergence()
{
    // Retrieve moving averages with different periods
    int handle_ma8 = iMA(Symbol(), g_MAC_Timeframe, 8, 0, MAtype, MAappliedPrice);
    int handle_ma13 = iMA(Symbol(), g_MAC_Timeframe, 13, 0, MAtype, MAappliedPrice);
    int handle_ma21 = iMA(Symbol(), g_MAC_Timeframe, 21, 0, MAtype, MAappliedPrice);
    int handle_ma55 = iMA(Symbol(), g_MAC_Timeframe, 55, 0, MAtype, MAappliedPrice);
    
    double ma8_buf[1], ma13_buf[1], ma21_buf[1], ma55_buf[1];
    
    if(CopyBuffer(handle_ma8, 0, 0, 1, ma8_buf) <= 0 ||
       CopyBuffer(handle_ma13, 0, 0, 1, ma13_buf) <= 0 ||
       CopyBuffer(handle_ma21, 0, 0, 1, ma21_buf) <= 0 ||
       CopyBuffer(handle_ma55, 0, 0, 1, ma55_buf) <= 0) {
        if(GetDebugMode()) 
            DebugPrint("Error retrieving moving average values for divergence check");
        return false;
    }
    
    double ma8 = ma8_buf[0];
    double ma13 = ma13_buf[0];
    double ma21 = ma21_buf[0];
    double ma55 = ma55_buf[0];
    
    // Calculate distances
    double diff8_21 = MathAbs(ma8 - ma21);
    double diff13_55 = MathAbs(ma13 - ma55);
    
    // Calculate normalization (relative distance)
    double normalized_diff = diff8_21 / diff13_55;
    
    // If the distance is large, divergence exists
    return (normalized_diff > 1.5);
}

//+------------------------------------------------------------------+
//| Check price action in moving average                              |
//+------------------------------------------------------------------+
bool IsMASupport(MqlRates &rates[])
{
    // Retrieve recent prices
    if(ArraySize(rates) < 1) return false;
    
    double close_price = rates[0].close;
    double low_price = rates[0].low;
    
    // Retrieve reference moving average
    int handle_ma = iMA(Symbol(), g_MAC_Timeframe, SlowMAperiod, 0, MAtype, MAappliedPrice);
    double ma_buf[1];
    
    if(CopyBuffer(handle_ma, 0, 0, 1, ma_buf) <= 0) {
        if(GetDebugMode()) 
            DebugPrint("Error retrieving moving average values for support check");
        return false;
    }
    
    double ma_support = ma_buf[0];
    
    // If price is close to the moving average and the candle closes upwards
    if(low_price <= ma_support && low_price > ma_support * 0.995 && close_price > ma_support) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check moving average resistance                                     |
//+------------------------------------------------------------------+
bool IsMAResistance(MqlRates &rates[])
{
    // Retrieve recent prices
    if(ArraySize(rates) < 1) return false;
    
    double close_price = rates[0].close;
    double high_price = rates[0].high;
    
    // Retrieve reference moving average
    int handle_ma = iMA(Symbol(), g_MAC_Timeframe, SlowMAperiod, 0, MAtype, MAappliedPrice);
    double ma_buf[1];
    
    if(CopyBuffer(handle_ma, 0, 0, 1, ma_buf) <= 0) {
        if(GetDebugMode()) 
            DebugPrint("Error retrieving moving average values for resistance check");
        return false;
    }
    
    double ma_resistance = ma_buf[0];
    
    // If price is close to the moving average and the candle closes downwards
    if(high_price >= ma_resistance && high_price < ma_resistance * 1.005 && close_price < ma_resistance) {
        return true;
    }
    
    return false;
} 