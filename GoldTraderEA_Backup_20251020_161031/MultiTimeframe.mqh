//+------------------------------------------------------------------+
//|                                           MultiTimeframe.mqh |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property link      ""

// Timeframe for this module
extern ENUM_TIMEFRAMES MTF_Timeframe;

// Include debug print function
#import "GoldTraderEA_cleaned.mq5"
   void DebugPrint(string message);
#import

// Timeframes used for analysis
ENUM_TIMEFRAMES higher_timeframes[] = {PERIOD_H4, PERIOD_D1, PERIOD_W1};

// Variable to control maximum confirmations (new)
int max_mtf_confirmations = 3; // Maximum allowed confirmations from this module

// Variables to store multi-timeframe data
MqlRates rates_m5[], rates_m15[], rates_h1[], rates_h4[], rates_d1[];

//+------------------------------------------------------------------+
//| Check higher timeframe confirmations for buy                      |
//+------------------------------------------------------------------+
int CheckMultiTimeframeBuy(MqlRates &current_tf_rates[])
{
    DebugPrint("Starting multi-timeframe check for buy");
    
    int confirmations = 0;
    
    // Check trend in higher timeframes
    for(int i = 0; i < ArraySize(higher_timeframes); i++) {
        // If we reached the maximum allowed confirmations, exit the loop (new)
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
            continue;
        }
        
        // Check moving average in higher timeframe
        double ma_higher_20[];
        double ma_higher_50[];
        ArrayResize(ma_higher_20, 10);
        ArrayResize(ma_higher_50, 10);
        ArraySetAsSeries(ma_higher_20, true);
        ArraySetAsSeries(ma_higher_50, true);
        
        int handle_ma_higher_20 = iMA(Symbol(), higher_timeframes[i], 20, 0, MODE_EMA, PRICE_CLOSE);
        int handle_ma_higher_50 = iMA(Symbol(), higher_timeframes[i], 50, 0, MODE_EMA, PRICE_CLOSE);
        
        if(handle_ma_higher_20 == INVALID_HANDLE || handle_ma_higher_50 == INVALID_HANDLE) {
            DebugPrint("Error creating MA handle for timeframe " + 
                      EnumToString(higher_timeframes[i]) + 
                      ": " + IntegerToString(GetLastError()));
            continue;
        }
        
        // Copy MA data
        if(CopyBuffer(handle_ma_higher_20, 0, 0, 10, ma_higher_20) < 10 ||
           CopyBuffer(handle_ma_higher_50, 0, 0, 10, ma_higher_50) < 10) {
            DebugPrint("Error copying MA data for timeframe " + 
                      EnumToString(higher_timeframes[i]) + 
                      ": " + IntegerToString(GetLastError()));
            continue;
        }
        
        // Release handles
        IndicatorRelease(handle_ma_higher_20);
        IndicatorRelease(handle_ma_higher_50);
        
        // Limit the number of conditions in each timeframe to one confirmation (modified)
        bool timeframe_confirmation = false;
        
        // Check uptrend in higher timeframe
        bool uptrend_ma = ma_higher_20[0] > ma_higher_50[0];
        bool higher_close_above_ma = higher_rates[0].close > ma_higher_20[0];
        
        if(uptrend_ma && higher_close_above_ma) {
            DebugPrint("Uptrend confirmed in timeframe " + EnumToString(higher_timeframes[i]));
            
            // Add one confirmation with proportional weight in each timeframe
            if(!timeframe_confirmation) {
                if(higher_timeframes[i] == PERIOD_H4)
                    confirmations += 1;
                else if(higher_timeframes[i] == PERIOD_D1)
                    confirmations += 1;
                else if(higher_timeframes[i] == PERIOD_W1)
                    confirmations += 2;
                
                timeframe_confirmation = true;
            }
        }
        
        // Check candlestick pattern in higher timeframe - only if we haven't received confirmation from this timeframe yet
        if(!timeframe_confirmation) {
            bool bullish_candle = higher_rates[0].close > higher_rates[0].open && 
                                (higher_rates[0].close - higher_rates[0].open) > 0.7 * (higher_rates[0].high - higher_rates[0].low);
            
            if(bullish_candle) {
                DebugPrint("Strong bullish candle in timeframe " + EnumToString(higher_timeframes[i]));
                
                if(higher_timeframes[i] == PERIOD_H4)
                    confirmations += 1;
                else if(higher_timeframes[i] == PERIOD_D1)
                    confirmations += 1;
                else if(higher_timeframes[i] == PERIOD_W1)
                    confirmations += 2;
                
                timeframe_confirmation = true;
            }
        }
        
        // Check support levels in higher timeframe - only if we haven't received confirmation from this timeframe yet
        if(!timeframe_confirmation) {
            double recent_support = DBL_MAX;
            for(int j = 1; j < 10; j++) {
                if(higher_rates[j].low < recent_support)
                    recent_support = higher_rates[j].low;
            }
            
            // If the current price is close to the higher timeframe support
            if(MathAbs(current_tf_rates[0].close - recent_support) < (higher_rates[0].high - higher_rates[0].low) * 0.2 && 
               current_tf_rates[0].close > recent_support) {
                DebugPrint("Price close to support level in timeframe " + EnumToString(higher_timeframes[i]));
                
                if(higher_timeframes[i] == PERIOD_H4)
                    confirmations += 1;
                else if(higher_timeframes[i] == PERIOD_D1)
                    confirmations += 1;
                else if(higher_timeframes[i] == PERIOD_W1)
                    confirmations += 2;
            }
        }
    }
    
    // Ensure the number of confirmations is limited to the maximum allowed (new)
    if(confirmations > max_mtf_confirmations) {
        confirmations = max_mtf_confirmations;
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
    
    // Check trend in higher timeframes
    for(int i = 0; i < ArraySize(higher_timeframes); i++) {
        // If we reached the maximum allowed confirmations, exit the loop (new)
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
            continue;
        }
        
        // Check moving average in higher timeframe
        double ma_higher_20[];
        double ma_higher_50[];
        ArrayResize(ma_higher_20, 10);
        ArrayResize(ma_higher_50, 10);
        ArraySetAsSeries(ma_higher_20, true);
        ArraySetAsSeries(ma_higher_50, true);
        
        int handle_ma_higher_20 = iMA(Symbol(), higher_timeframes[i], 20, 0, MODE_EMA, PRICE_CLOSE);
        int handle_ma_higher_50 = iMA(Symbol(), higher_timeframes[i], 50, 0, MODE_EMA, PRICE_CLOSE);
        
        if(handle_ma_higher_20 == INVALID_HANDLE || handle_ma_higher_50 == INVALID_HANDLE) {
            DebugPrint("Error creating MA handle for timeframe " + 
                      EnumToString(higher_timeframes[i]) + 
                      ": " + IntegerToString(GetLastError()));
            continue;
        }
        
        // Copy MA data
        if(CopyBuffer(handle_ma_higher_20, 0, 0, 10, ma_higher_20) < 10 ||
           CopyBuffer(handle_ma_higher_50, 0, 0, 10, ma_higher_50) < 10) {
            DebugPrint("Error copying MA data for timeframe " + 
                      EnumToString(higher_timeframes[i]) + 
                      ": " + IntegerToString(GetLastError()));
            continue;
        }
        
        // Release handles
        IndicatorRelease(handle_ma_higher_20);
        IndicatorRelease(handle_ma_higher_50);
        
        // Limit the number of conditions in each timeframe to one confirmation (modified)
        bool timeframe_confirmation = false;
        
        // Check downtrend in higher timeframe
        bool downtrend_ma = ma_higher_20[0] < ma_higher_50[0];
        bool higher_close_below_ma = higher_rates[0].close < ma_higher_20[0];
        
        if(downtrend_ma && higher_close_below_ma) {
            DebugPrint("Downtrend confirmed in timeframe " + EnumToString(higher_timeframes[i]));
            
            // Add one confirmation with proportional weight in each timeframe
            if(!timeframe_confirmation) {
                if(higher_timeframes[i] == PERIOD_H4)
                    confirmations += 1;
                else if(higher_timeframes[i] == PERIOD_D1)
                    confirmations += 1;
                else if(higher_timeframes[i] == PERIOD_W1)
                    confirmations += 2;
                
                timeframe_confirmation = true;
            }
        }
        
        // Check candlestick pattern in higher timeframe - only if we haven't received confirmation from this timeframe yet
        if(!timeframe_confirmation) {
            bool bearish_candle = higher_rates[0].close < higher_rates[0].open && 
                                (higher_rates[0].open - higher_rates[0].close) > 0.7 * (higher_rates[0].high - higher_rates[0].low);
            
            if(bearish_candle) {
                DebugPrint("Strong bearish candle in timeframe " + EnumToString(higher_timeframes[i]));
                
                if(higher_timeframes[i] == PERIOD_H4)
                    confirmations += 1;
                else if(higher_timeframes[i] == PERIOD_D1)
                    confirmations += 1;
                else if(higher_timeframes[i] == PERIOD_W1)
                    confirmations += 2;
                
                timeframe_confirmation = true;
            }
        }
        
        // Check resistance levels in higher timeframe - only if we haven't received confirmation from this timeframe yet
        if(!timeframe_confirmation) {
            double recent_resistance = 0;
            for(int j = 1; j < 10; j++) {
                if(higher_rates[j].high > recent_resistance)
                    recent_resistance = higher_rates[j].high;
            }
            
            // If the current price is close to the higher timeframe resistance
            if(MathAbs(current_tf_rates[0].close - recent_resistance) < (higher_rates[0].high - higher_rates[0].low) * 0.2 && 
               current_tf_rates[0].close < recent_resistance) {
                DebugPrint("Price close to resistance level in timeframe " + EnumToString(higher_timeframes[i]));
                
                if(higher_timeframes[i] == PERIOD_H4)
                    confirmations += 1;
                else if(higher_timeframes[i] == PERIOD_D1)
                    confirmations += 1;
                else if(higher_timeframes[i] == PERIOD_W1)
                    confirmations += 2;
            }
        }
    }
    
    // Ensure the number of confirmations is limited to the maximum allowed (new)
    if(confirmations > max_mtf_confirmations) {
        confirmations = max_mtf_confirmations;
    }
    
    DebugPrint("Number of multi-timeframe confirmations for sell: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Initialize multi-timeframe data                                  |
//+------------------------------------------------------------------+
bool InitializeMultiTimeframeData()
{
    // Initialize arrays
    ArrayResize(rates_m5, 100);
    ArrayResize(rates_m15, 100);
    ArrayResize(rates_h1, 100);
    ArrayResize(rates_h4, 100);
    ArrayResize(rates_d1, 100);
    
    // Set arrays as series
    ArraySetAsSeries(rates_m5, true);
    ArraySetAsSeries(rates_m15, true);
    ArraySetAsSeries(rates_h1, true);
    ArraySetAsSeries(rates_h4, true);
    ArraySetAsSeries(rates_d1, true);
    
    // Load initial data
    if(!LoadMultiTimeframeData()) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Load data for multiple timeframes                                 |
//+------------------------------------------------------------------+
bool LoadMultiTimeframeData()
{
    // Load data for each timeframe
    if(CopyRates(Symbol(), PERIOD_M5, 0, 100, rates_m5) <= 0) {
        DebugPrint("Error loading M5 data: " + IntegerToString(GetLastError()));
        return false;
    }
    
    if(CopyRates(Symbol(), PERIOD_M15, 0, 100, rates_m15) <= 0) {
        DebugPrint("Error loading M15 data: " + IntegerToString(GetLastError()));
        return false;
    }
    
    if(CopyRates(Symbol(), PERIOD_H1, 0, 100, rates_h1) <= 0) {
        DebugPrint("Error loading H1 data: " + IntegerToString(GetLastError()));
        return false;
    }
    
    if(CopyRates(Symbol(), PERIOD_H4, 0, 100, rates_h4) <= 0) {
        DebugPrint("Error loading H4 data: " + IntegerToString(GetLastError()));
        return false;
    }
    
    if(CopyRates(Symbol(), PERIOD_D1, 0, 100, rates_d1) <= 0) {
        DebugPrint("Error loading D1 data: " + IntegerToString(GetLastError()));
        return false;
    }
    
    return true;
} 