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
// FIXED: Use PERIOD_CURRENT instead of hardcoded H1 to match EA's timeframe
ENUM_TIMEFRAMES g_MAC_Timeframe = PERIOD_CURRENT;

// Moving average settings
int FastMAperiod = 8;       // Fast moving average period
int SlowMAperiod = 21;      // Slow moving average period
// FIXED: Reduced from 200 to 100 to allow earlier signal generation
int LongMAperiod = 100;     // Long-term moving average period (overall trend)
ENUM_MA_METHOD MAtype = MODE_EMA; // Type of moving average (EMA)
ENUM_APPLIED_PRICE MAappliedPrice = PRICE_CLOSE; // Price used for calculation

// Default values for moving averages set in OnInit
int DefaultFastMAperiod = 8;
int DefaultSlowMAperiod = 21;
// FIXED: Reduced from 200 to 100 to match LongMAperiod
int DefaultLongMAperiod = 100;
ENUM_MA_METHOD DefaultMAtype = MODE_EMA;
ENUM_APPLIED_PRICE DefaultMAappliedPrice = PRICE_CLOSE;

// Constants for support/resistance tolerance
const double MA_SUPPORT_TOLERANCE = 0.995;      // 0.5% below MA for support detection
const double MA_RESISTANCE_TOLERANCE = 1.005;   // 0.5% above MA for resistance detection
const double MIN_DIVERGENCE_RATIO = 1.5;        // Minimum ratio for MA divergence detection
const double MIN_DIVISOR_VALUE = 0.00001;       // Minimum value to avoid division by zero

// Global indicator handles (to prevent memory leaks)
int g_handle_fast_ma = INVALID_HANDLE;
int g_handle_slow_ma = INVALID_HANDLE;
int g_handle_long_ma = INVALID_HANDLE;
int g_handle_ma8 = INVALID_HANDLE;
int g_handle_ma13 = INVALID_HANDLE;
int g_handle_ma21 = INVALID_HANDLE;
int g_handle_ma55 = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Initialize MA Crossover module                                     |
//+------------------------------------------------------------------+
bool InitMACrossover()
{
    // Create all handles in temporary variables first (atomic initialization)
    ResetLastError();
    int temp_fast_ma = iMA(Symbol(), g_MAC_Timeframe, FastMAperiod, 0, MAtype, MAappliedPrice);
    int temp_slow_ma = iMA(Symbol(), g_MAC_Timeframe, SlowMAperiod, 0, MAtype, MAappliedPrice);
    int temp_long_ma = iMA(Symbol(), g_MAC_Timeframe, LongMAperiod, 0, MAtype, MAappliedPrice);
    int temp_ma8 = iMA(Symbol(), g_MAC_Timeframe, 8, 0, MAtype, MAappliedPrice);
    int temp_ma13 = iMA(Symbol(), g_MAC_Timeframe, 13, 0, MAtype, MAappliedPrice);
    int temp_ma21 = iMA(Symbol(), g_MAC_Timeframe, 21, 0, MAtype, MAappliedPrice);
    int temp_ma55 = iMA(Symbol(), g_MAC_Timeframe, 55, 0, MAtype, MAappliedPrice);

    // Validate all handles before committing
    if(temp_fast_ma == INVALID_HANDLE || temp_slow_ma == INVALID_HANDLE ||
       temp_long_ma == INVALID_HANDLE || temp_ma8 == INVALID_HANDLE ||
       temp_ma13 == INVALID_HANDLE || temp_ma21 == INVALID_HANDLE ||
       temp_ma55 == INVALID_HANDLE) {
        Print("ERROR: Failed to create one or more MA Crossover indicator handles.");
        Print("  Symbol: ", Symbol(), " Timeframe: ", EnumToString(g_MAC_Timeframe));
        Print("  Fast MA (", FastMAperiod, "): ", (temp_fast_ma == INVALID_HANDLE ? "FAILED" : "OK"));
        Print("  Slow MA (", SlowMAperiod, "): ", (temp_slow_ma == INVALID_HANDLE ? "FAILED" : "OK"));
        Print("  Long MA (", LongMAperiod, "): ", (temp_long_ma == INVALID_HANDLE ? "FAILED" : "OK"));
        Print("  MA8: ", (temp_ma8 == INVALID_HANDLE ? "FAILED" : "OK"));
        Print("  MA13: ", (temp_ma13 == INVALID_HANDLE ? "FAILED" : "OK"));
        Print("  MA21: ", (temp_ma21 == INVALID_HANDLE ? "FAILED" : "OK"));
        Print("  MA55: ", (temp_ma55 == INVALID_HANDLE ? "FAILED" : "OK"));

        // Release any successfully created handles
        if(temp_fast_ma != INVALID_HANDLE) IndicatorRelease(temp_fast_ma);
        if(temp_slow_ma != INVALID_HANDLE) IndicatorRelease(temp_slow_ma);
        if(temp_long_ma != INVALID_HANDLE) IndicatorRelease(temp_long_ma);
        if(temp_ma8 != INVALID_HANDLE) IndicatorRelease(temp_ma8);
        if(temp_ma13 != INVALID_HANDLE) IndicatorRelease(temp_ma13);
        if(temp_ma21 != INVALID_HANDLE) IndicatorRelease(temp_ma21);
        if(temp_ma55 != INVALID_HANDLE) IndicatorRelease(temp_ma55);

        return false;
    }

    // All handles created successfully - now release old handles and commit new ones
    DeinitMACrossover();

    g_handle_fast_ma = temp_fast_ma;
    g_handle_slow_ma = temp_slow_ma;
    g_handle_long_ma = temp_long_ma;
    g_handle_ma8 = temp_ma8;
    g_handle_ma13 = temp_ma13;
    g_handle_ma21 = temp_ma21;
    g_handle_ma55 = temp_ma55;

    if(GetDebugMode())
        DebugPrint("MA Crossover module initialized successfully");

    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize MA Crossover module                                   |
//+------------------------------------------------------------------+
void DeinitMACrossover()
{
    // Release all indicator handles
    if(g_handle_fast_ma != INVALID_HANDLE) {
        IndicatorRelease(g_handle_fast_ma);
        g_handle_fast_ma = INVALID_HANDLE;
    }
    if(g_handle_slow_ma != INVALID_HANDLE) {
        IndicatorRelease(g_handle_slow_ma);
        g_handle_slow_ma = INVALID_HANDLE;
    }
    if(g_handle_long_ma != INVALID_HANDLE) {
        IndicatorRelease(g_handle_long_ma);
        g_handle_long_ma = INVALID_HANDLE;
    }
    if(g_handle_ma8 != INVALID_HANDLE) {
        IndicatorRelease(g_handle_ma8);
        g_handle_ma8 = INVALID_HANDLE;
    }
    if(g_handle_ma13 != INVALID_HANDLE) {
        IndicatorRelease(g_handle_ma13);
        g_handle_ma13 = INVALID_HANDLE;
    }
    if(g_handle_ma21 != INVALID_HANDLE) {
        IndicatorRelease(g_handle_ma21);
        g_handle_ma21 = INVALID_HANDLE;
    }
    if(g_handle_ma55 != INVALID_HANDLE) {
        IndicatorRelease(g_handle_ma55);
        g_handle_ma55 = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Set the timeframe for this module                                 |
//+------------------------------------------------------------------+
void SetMACTimeframe(ENUM_TIMEFRAMES timeframe)
{
    g_MAC_Timeframe = timeframe;
    // Reinitialize handles with new timeframe
    InitMACrossover();
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
    // Reinitialize handles with new parameters
    InitMACrossover();
}

//+------------------------------------------------------------------+
//| Check moving average crossover for buy signal                    |
//+------------------------------------------------------------------+
int CheckMACrossoverBuy(MqlRates &rates[])
{
    // Validate handles are initialized
    if(g_handle_fast_ma == INVALID_HANDLE || g_handle_slow_ma == INVALID_HANDLE ||
       g_handle_long_ma == INVALID_HANDLE) {
        if(GetDebugMode())
            DebugPrint("MA Crossover handles not initialized. Call InitMACrossover() first.");
        return 0;
    }

    // Ensure access to minimum required data
    // FIXED: Reduced from LongMAperiod + 10 to just LongMAperiod
    int size = ArraySize(rates);
    if(size < LongMAperiod) {
        if(GetDebugMode())
            DebugPrint("Not enough historical data to check moving average crossover");
        return 0;
    }

    // Calculate moving average values
    // FIXED: Increased from 3 to 5 candles to allow crossover detection within 2-3 candles
    double fastMA[5];  // Fast moving average values for the last 5 candles
    double slowMA[5];  // Slow moving average values for the last 5 candles
    double longMA[5];  // Long-term moving average values for the last 5 candles

    // Note: ArraySetAsSeries cannot be used on statically allocated arrays
    // CopyBuffer already returns data in the correct order (index 0 = most recent)

    // Copy all 5 values at once (more efficient than loop)
    if(CopyBuffer(g_handle_fast_ma, 0, 0, 5, fastMA) != 5) {
        if(GetDebugMode())
            DebugPrint("Error retrieving fast moving average values. Error: " + IntegerToString(GetLastError()));
        return 0;
    }

    if(CopyBuffer(g_handle_slow_ma, 0, 0, 5, slowMA) != 5) {
        if(GetDebugMode())
            DebugPrint("Error retrieving slow moving average values. Error: " + IntegerToString(GetLastError()));
        return 0;
    }

    if(CopyBuffer(g_handle_long_ma, 0, 0, 5, longMA) != 5) {
        if(GetDebugMode())
            DebugPrint("Error retrieving long-term moving average values. Error: " + IntegerToString(GetLastError()));
        return 0;
    }

    int confirmations = 0;

    // FIXED: Check crossover of fast and slow moving averages (golden cross)
    // Allow crossover detection within last 3 candles (not just exact candle)
    bool golden_cross = false;
    for(int i = 0; i < 3; i++) {
        if(fastMA[i] > slowMA[i] && fastMA[i+1] <= slowMA[i+1]) {
            golden_cross = true;
            break;
        }
    }
    if(golden_cross) {
        confirmations++;
        if(GetDebugMode()) DebugPrint("Golden cross of fast and slow moving averages detected");
    }

    // Check if price is above long-term moving average (uptrend)
    if(rates[0].close > longMA[0]) {
        confirmations++;
        if(GetDebugMode()) DebugPrint("Price is above the long-term moving average (uptrend)");
    }

    // FIXED: Relaxed slope requirement - only need current > previous (not strict 3-candle uptrend)
    if(fastMA[0] > fastMA[1]) {
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
    // Validate handles are initialized
    if(g_handle_fast_ma == INVALID_HANDLE || g_handle_slow_ma == INVALID_HANDLE ||
       g_handle_long_ma == INVALID_HANDLE) {
        if(GetDebugMode())
            DebugPrint("MA Crossover handles not initialized. Call InitMACrossover() first.");
        return 0;
    }

    // Ensure access to minimum required data
    // FIXED: Reduced from LongMAperiod + 10 to just LongMAperiod
    int size = ArraySize(rates);
    if(size < LongMAperiod) {
        if(GetDebugMode())
            DebugPrint("Not enough historical data to check moving average crossover");
        return 0;
    }

    // Calculate moving average values
    // FIXED: Increased from 3 to 5 candles to allow crossover detection within 2-3 candles
    double fastMA[5];  // Fast moving average values for the last 5 candles
    double slowMA[5];  // Slow moving average values for the last 5 candles
    double longMA[5];  // Long-term moving average values for the last 5 candles

    // Note: ArraySetAsSeries cannot be used on statically allocated arrays
    // CopyBuffer already returns data in the correct order (index 0 = most recent)

    // Copy all 5 values at once (more efficient than loop)
    if(CopyBuffer(g_handle_fast_ma, 0, 0, 5, fastMA) != 5) {
        if(GetDebugMode())
            DebugPrint("Error retrieving fast moving average values. Error: " + IntegerToString(GetLastError()));
        return 0;
    }

    if(CopyBuffer(g_handle_slow_ma, 0, 0, 5, slowMA) != 5) {
        if(GetDebugMode())
            DebugPrint("Error retrieving slow moving average values. Error: " + IntegerToString(GetLastError()));
        return 0;
    }

    if(CopyBuffer(g_handle_long_ma, 0, 0, 5, longMA) != 5) {
        if(GetDebugMode())
            DebugPrint("Error retrieving long-term moving average values. Error: " + IntegerToString(GetLastError()));
        return 0;
    }

    int confirmations = 0;

    // FIXED: Check crossover of fast and slow moving averages (death cross)
    // Allow crossover detection within last 3 candles (not just exact candle)
    bool death_cross = false;
    for(int i = 0; i < 3; i++) {
        if(fastMA[i] < slowMA[i] && fastMA[i+1] >= slowMA[i+1]) {
            death_cross = true;
            break;
        }
    }
    if(death_cross) {
        confirmations++;
        if(GetDebugMode()) DebugPrint("Death cross of fast and slow moving averages detected");
    }

    // Check if price is below long-term moving average (downtrend)
    if(rates[0].close < longMA[0]) {
        confirmations++;
        if(GetDebugMode()) DebugPrint("Price is below the long-term moving average (downtrend)");
    }

    // FIXED: Relaxed slope requirement - only need current < previous (not strict 3-candle downtrend)
    if(fastMA[0] < fastMA[1]) {
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
    // Validate handles are initialized
    if(g_handle_ma8 == INVALID_HANDLE || g_handle_ma13 == INVALID_HANDLE ||
       g_handle_ma21 == INVALID_HANDLE || g_handle_ma55 == INVALID_HANDLE) {
        if(GetDebugMode())
            DebugPrint("MA Divergence handles not initialized. Call InitMACrossover() first.");
        return false;
    }

    double ma8_buf[1], ma13_buf[1], ma21_buf[1], ma55_buf[1];

    // Copy buffer values
    if(CopyBuffer(g_handle_ma8, 0, 0, 1, ma8_buf) <= 0 ||
       CopyBuffer(g_handle_ma13, 0, 0, 1, ma13_buf) <= 0 ||
       CopyBuffer(g_handle_ma21, 0, 0, 1, ma21_buf) <= 0 ||
       CopyBuffer(g_handle_ma55, 0, 0, 1, ma55_buf) <= 0) {
        if(GetDebugMode())
            DebugPrint("Error retrieving moving average values for divergence check. Error: " + IntegerToString(GetLastError()));
        return false;
    }

    double ma8 = ma8_buf[0];
    double ma13 = ma13_buf[0];
    double ma21 = ma21_buf[0];
    double ma55 = ma55_buf[0];

    // Calculate distances
    double diff8_21 = MathAbs(ma8 - ma21);
    double diff13_55 = MathAbs(ma13 - ma55);

    // Prevent division by zero or very small numbers
    if(diff13_55 < MIN_DIVISOR_VALUE) {
        if(GetDebugMode())
            DebugPrint("MA13-MA55 difference too small for divergence calculation");
        return false;
    }

    // Calculate normalization (relative distance)
    double normalized_diff = diff8_21 / diff13_55;

    // If the distance is large, divergence exists
    return (normalized_diff > MIN_DIVERGENCE_RATIO);
}

//+------------------------------------------------------------------+
//| Check price action in moving average                              |
//+------------------------------------------------------------------+
bool IsMASupport(MqlRates &rates[])
{
    // Validate handles are initialized
    if(g_handle_slow_ma == INVALID_HANDLE) {
        if(GetDebugMode())
            DebugPrint("MA Support handle not initialized. Call InitMACrossover() first.");
        return false;
    }

    // Retrieve recent prices
    if(ArraySize(rates) < 1) return false;

    double close_price = rates[0].close;
    double low_price = rates[0].low;

    // Retrieve reference moving average
    double ma_buf[1];

    if(CopyBuffer(g_handle_slow_ma, 0, 0, 1, ma_buf) <= 0) {
        if(GetDebugMode())
            DebugPrint("Error retrieving moving average values for support check. Error: " + IntegerToString(GetLastError()));
        return false;
    }

    double ma_support = ma_buf[0];

    // If price is close to the moving average and the candle closes upwards
    // Using constant for tolerance instead of magic number
    if(low_price <= ma_support && low_price > ma_support * MA_SUPPORT_TOLERANCE && close_price > ma_support) {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check moving average resistance                                     |
//+------------------------------------------------------------------+
bool IsMAResistance(MqlRates &rates[])
{
    // Validate handles are initialized
    if(g_handle_slow_ma == INVALID_HANDLE) {
        if(GetDebugMode())
            DebugPrint("MA Resistance handle not initialized. Call InitMACrossover() first.");
        return false;
    }

    // Retrieve recent prices
    if(ArraySize(rates) < 1) return false;

    double close_price = rates[0].close;
    double high_price = rates[0].high;

    // Retrieve reference moving average
    double ma_buf[1];

    if(CopyBuffer(g_handle_slow_ma, 0, 0, 1, ma_buf) <= 0) {
        if(GetDebugMode())
            DebugPrint("Error retrieving moving average values for resistance check. Error: " + IntegerToString(GetLastError()));
        return false;
    }

    double ma_resistance = ma_buf[0];

    // If price is close to the moving average and the candle closes downwards
    // Using constant for tolerance instead of magic number
    if(high_price >= ma_resistance && high_price < ma_resistance * MA_RESISTANCE_TOLERANCE && close_price < ma_resistance) {
        return true;
    }

    return false;
}