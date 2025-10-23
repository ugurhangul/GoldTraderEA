//+------------------------------------------------------------------+
//|                                           MultiTimeframe.mqh |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property link      ""

// Timeframe for this module
extern ENUM_TIMEFRAMES MTF_Timeframe;

// Forward declaration of DebugPrint function
void DebugPrint(string message);

// Timeframes used for analysis
ENUM_TIMEFRAMES higher_timeframes[] = {PERIOD_H4, PERIOD_D1, PERIOD_W1};

// Variable to control maximum confirmations
int max_mtf_confirmations = 3; // Maximum allowed confirmations from this module

// Confirmation weight constants
const int CONF_WEIGHT_H4 = 1;
const int CONF_WEIGHT_D1 = 1;
const int CONF_WEIGHT_W1 = 2;

// Indicator handles for each timeframe (to prevent memory leaks)
int handle_ma20_h4 = INVALID_HANDLE;
int handle_ma50_h4 = INVALID_HANDLE;
int handle_ma20_d1 = INVALID_HANDLE;
int handle_ma50_d1 = INVALID_HANDLE;
int handle_ma20_w1 = INVALID_HANDLE;
int handle_ma50_w1 = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Initialize multi-timeframe indicator handles                     |
//+------------------------------------------------------------------+
bool InitializeMultiTimeframeIndicators()
{
    // Create indicator handles for H4 timeframe
    handle_ma20_h4 = iMA(Symbol(), PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE);
    handle_ma50_h4 = iMA(Symbol(), PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);

    // Create indicator handles for D1 timeframe
    handle_ma20_d1 = iMA(Symbol(), PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE);
    handle_ma50_d1 = iMA(Symbol(), PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE);

    // Create indicator handles for W1 timeframe
    handle_ma20_w1 = iMA(Symbol(), PERIOD_W1, 20, 0, MODE_EMA, PRICE_CLOSE);
    handle_ma50_w1 = iMA(Symbol(), PERIOD_W1, 50, 0, MODE_EMA, PRICE_CLOSE);

    // Check if all handles were created successfully
    if(handle_ma20_h4 == INVALID_HANDLE || handle_ma50_h4 == INVALID_HANDLE ||
       handle_ma20_d1 == INVALID_HANDLE || handle_ma50_d1 == INVALID_HANDLE ||
       handle_ma20_w1 == INVALID_HANDLE || handle_ma50_w1 == INVALID_HANDLE) {
        DebugPrint("Error creating multi-timeframe indicator handles: " + IntegerToString(GetLastError()));
        return false;
    }

    DebugPrint("Multi-timeframe indicator handles initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Release multi-timeframe indicator handles                        |
//+------------------------------------------------------------------+
void CleanupMultiTimeframeIndicators()
{
    if(handle_ma20_h4 != INVALID_HANDLE) IndicatorRelease(handle_ma20_h4);
    if(handle_ma50_h4 != INVALID_HANDLE) IndicatorRelease(handle_ma50_h4);
    if(handle_ma20_d1 != INVALID_HANDLE) IndicatorRelease(handle_ma20_d1);
    if(handle_ma50_d1 != INVALID_HANDLE) IndicatorRelease(handle_ma50_d1);
    if(handle_ma20_w1 != INVALID_HANDLE) IndicatorRelease(handle_ma20_w1);
    if(handle_ma50_w1 != INVALID_HANDLE) IndicatorRelease(handle_ma50_w1);

    DebugPrint("Multi-timeframe indicator handles released");
}

//+------------------------------------------------------------------+
//| Check higher timeframe confirmations for buy                      |
//+------------------------------------------------------------------+
int CheckMultiTimeframeBuy(MqlRates &current_tf_rates[])
{
    DebugPrint("Starting multi-timeframe check for buy");

    int confirmations = 0;
    int failed_timeframes = 0;

    // Check trend in higher timeframes
    for(int i = 0; i < ArraySize(higher_timeframes); i++) {
        // If we reached the maximum allowed confirmations, exit the loop
        if(confirmations >= max_mtf_confirmations) {
            DebugPrint("Reached maximum allowed confirmations (" + IntegerToString(max_mtf_confirmations) + ") in MultiTimeframe module");
            break;
        }

        // Get higher timeframe data
        MqlRates higher_rates[];
        ArraySetAsSeries(higher_rates, true);
        int copied = CopyRates(Symbol(), higher_timeframes[i], 0, 10, higher_rates);

        if(copied < 10) {
            DebugPrint("Error retrieving data for timeframe " +
                      EnumToString(higher_timeframes[i]) +
                      ": " + IntegerToString(GetLastError()));
            failed_timeframes++;
            continue;
        }

        // Get the appropriate indicator handles for this timeframe
        int handle_ma_20, handle_ma_50;
        if(higher_timeframes[i] == PERIOD_H4) {
            handle_ma_20 = handle_ma20_h4;
            handle_ma_50 = handle_ma50_h4;
        }
        else if(higher_timeframes[i] == PERIOD_D1) {
            handle_ma_20 = handle_ma20_d1;
            handle_ma_50 = handle_ma50_d1;
        }
        else if(higher_timeframes[i] == PERIOD_W1) {
            handle_ma_20 = handle_ma20_w1;
            handle_ma_50 = handle_ma50_w1;
        }
        else {
            DebugPrint("Unknown timeframe: " + EnumToString(higher_timeframes[i]));
            failed_timeframes++;
            continue;
        }

        // Check if handles are valid
        if(handle_ma_20 == INVALID_HANDLE || handle_ma_50 == INVALID_HANDLE) {
            DebugPrint("Invalid MA handles for timeframe " + EnumToString(higher_timeframes[i]));
            failed_timeframes++;
            continue;
        }

        // Prepare arrays for MA data
        double ma_higher_20[];
        double ma_higher_50[];
        ArrayResize(ma_higher_20, 10);
        ArrayResize(ma_higher_50, 10);
        ArraySetAsSeries(ma_higher_20, true);
        ArraySetAsSeries(ma_higher_50, true);

        // Copy MA data
        if(CopyBuffer(handle_ma_20, 0, 0, 10, ma_higher_20) < 10 ||
           CopyBuffer(handle_ma_50, 0, 0, 10, ma_higher_50) < 10) {
            DebugPrint("Error copying MA data for timeframe " +
                      EnumToString(higher_timeframes[i]) +
                      ": " + IntegerToString(GetLastError()));
            failed_timeframes++;
            continue;
        }

        // Limit the number of conditions in each timeframe to one confirmation
        bool timeframe_confirmation = false;
        int timeframe_weight = (higher_timeframes[i] == PERIOD_H4) ? CONF_WEIGHT_H4 :
                              (higher_timeframes[i] == PERIOD_D1) ? CONF_WEIGHT_D1 : CONF_WEIGHT_W1;

        // Check uptrend in higher timeframe
        bool uptrend_ma = ma_higher_20[0] > ma_higher_50[0];
        bool higher_close_above_ma = higher_rates[0].close > ma_higher_20[0];

        if(uptrend_ma && higher_close_above_ma) {
            DebugPrint("Uptrend confirmed in timeframe " + EnumToString(higher_timeframes[i]));
            confirmations += timeframe_weight;
            timeframe_confirmation = true;
        }

        // Check candlestick pattern in higher timeframe - only if we haven't received confirmation from this timeframe yet
        if(!timeframe_confirmation) {
            bool bullish_candle = higher_rates[0].close > higher_rates[0].open &&
                                (higher_rates[0].close - higher_rates[0].open) > 0.7 * (higher_rates[0].high - higher_rates[0].low);

            if(bullish_candle) {
                DebugPrint("Strong bullish candle in timeframe " + EnumToString(higher_timeframes[i]));
                confirmations += timeframe_weight;
                timeframe_confirmation = true;
            }
        }

        // Check support levels in higher timeframe - only if we haven't received confirmation from this timeframe yet
        if(!timeframe_confirmation) {
            // Initialize to first candle's low instead of DBL_MAX
            double recent_support = higher_rates[1].low;
            for(int j = 2; j < 10; j++) {
                if(higher_rates[j].low < recent_support)
                    recent_support = higher_rates[j].low;
            }

            // If the current price is close to the higher timeframe support
            if(MathAbs(current_tf_rates[0].close - recent_support) < (higher_rates[0].high - higher_rates[0].low) * 0.2 &&
               current_tf_rates[0].close > recent_support) {
                DebugPrint("Price close to support level in timeframe " + EnumToString(higher_timeframes[i]));
                confirmations += timeframe_weight;
                timeframe_confirmation = true;
            }
        }
    }

    // Warn if all timeframes failed
    if(failed_timeframes == ArraySize(higher_timeframes)) {
        DebugPrint("WARNING: All higher timeframes failed to load data for multi-timeframe analysis");
    }

    DebugPrint("Number of multi-timeframe confirmations for buy: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Check higher timeframe confirmations for sell                     |
//+------------------------------------------------------------------+
int CheckMultiTimeframeShort(MqlRates &current_tf_rates[])
{
    DebugPrint("Starting multi-timeframe check for sell");

    int confirmations = 0;
    int failed_timeframes = 0;

    // Check trend in higher timeframes
    for(int i = 0; i < ArraySize(higher_timeframes); i++) {
        // If we reached the maximum allowed confirmations, exit the loop
        if(confirmations >= max_mtf_confirmations) {
            DebugPrint("Reached maximum allowed confirmations (" + IntegerToString(max_mtf_confirmations) + ") in MultiTimeframe module");
            break;
        }

        // Get higher timeframe data
        MqlRates higher_rates[];
        ArraySetAsSeries(higher_rates, true);
        int copied = CopyRates(Symbol(), higher_timeframes[i], 0, 10, higher_rates);

        if(copied < 10) {
            DebugPrint("Error retrieving data for timeframe " +
                      EnumToString(higher_timeframes[i]) +
                      ": " + IntegerToString(GetLastError()));
            failed_timeframes++;
            continue;
        }

        // Get the appropriate indicator handles for this timeframe
        int handle_ma_20, handle_ma_50;
        if(higher_timeframes[i] == PERIOD_H4) {
            handle_ma_20 = handle_ma20_h4;
            handle_ma_50 = handle_ma50_h4;
        }
        else if(higher_timeframes[i] == PERIOD_D1) {
            handle_ma_20 = handle_ma20_d1;
            handle_ma_50 = handle_ma50_d1;
        }
        else if(higher_timeframes[i] == PERIOD_W1) {
            handle_ma_20 = handle_ma20_w1;
            handle_ma_50 = handle_ma50_w1;
        }
        else {
            DebugPrint("Unknown timeframe: " + EnumToString(higher_timeframes[i]));
            failed_timeframes++;
            continue;
        }

        // Check if handles are valid
        if(handle_ma_20 == INVALID_HANDLE || handle_ma_50 == INVALID_HANDLE) {
            DebugPrint("Invalid MA handles for timeframe " + EnumToString(higher_timeframes[i]));
            failed_timeframes++;
            continue;
        }

        // Prepare arrays for MA data
        double ma_higher_20[];
        double ma_higher_50[];
        ArrayResize(ma_higher_20, 10);
        ArrayResize(ma_higher_50, 10);
        ArraySetAsSeries(ma_higher_20, true);
        ArraySetAsSeries(ma_higher_50, true);

        // Copy MA data
        if(CopyBuffer(handle_ma_20, 0, 0, 10, ma_higher_20) < 10 ||
           CopyBuffer(handle_ma_50, 0, 0, 10, ma_higher_50) < 10) {
            DebugPrint("Error copying MA data for timeframe " +
                      EnumToString(higher_timeframes[i]) +
                      ": " + IntegerToString(GetLastError()));
            failed_timeframes++;
            continue;
        }

        // Limit the number of conditions in each timeframe to one confirmation
        bool timeframe_confirmation = false;
        int timeframe_weight = (higher_timeframes[i] == PERIOD_H4) ? CONF_WEIGHT_H4 :
                              (higher_timeframes[i] == PERIOD_D1) ? CONF_WEIGHT_D1 : CONF_WEIGHT_W1;

        // Check downtrend in higher timeframe
        bool downtrend_ma = ma_higher_20[0] < ma_higher_50[0];
        bool higher_close_below_ma = higher_rates[0].close < ma_higher_20[0];

        if(downtrend_ma && higher_close_below_ma) {
            DebugPrint("Downtrend confirmed in timeframe " + EnumToString(higher_timeframes[i]));
            confirmations += timeframe_weight;
            timeframe_confirmation = true;
        }

        // Check candlestick pattern in higher timeframe - only if we haven't received confirmation from this timeframe yet
        if(!timeframe_confirmation) {
            bool bearish_candle = higher_rates[0].close < higher_rates[0].open &&
                                (higher_rates[0].open - higher_rates[0].close) > 0.7 * (higher_rates[0].high - higher_rates[0].low);

            if(bearish_candle) {
                DebugPrint("Strong bearish candle in timeframe " + EnumToString(higher_timeframes[i]));
                confirmations += timeframe_weight;
                timeframe_confirmation = true;
            }
        }

        // Check resistance levels in higher timeframe - only if we haven't received confirmation from this timeframe yet
        if(!timeframe_confirmation) {
            // Initialize to first candle's high instead of 0
            double recent_resistance = higher_rates[1].high;
            for(int j = 2; j < 10; j++) {
                if(higher_rates[j].high > recent_resistance)
                    recent_resistance = higher_rates[j].high;
            }

            // If the current price is close to the higher timeframe resistance
            if(MathAbs(current_tf_rates[0].close - recent_resistance) < (higher_rates[0].high - higher_rates[0].low) * 0.2 &&
               current_tf_rates[0].close < recent_resistance) {
                DebugPrint("Price close to resistance level in timeframe " + EnumToString(higher_timeframes[i]));
                confirmations += timeframe_weight;
                timeframe_confirmation = true;
            }
        }
    }

    // Warn if all timeframes failed
    if(failed_timeframes == ArraySize(higher_timeframes)) {
        DebugPrint("WARNING: All higher timeframes failed to load data for multi-timeframe analysis");
    }

    DebugPrint("Number of multi-timeframe confirmations for sell: " + IntegerToString(confirmations));
    return confirmations;
}
