//+------------------------------------------------------------------+
//|                                         SupportResistance.mqh |
//|                                      Copyright 2023, Gold Trader   |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Import DebugPrint function from main EA
#import "GoldTraderEA.mq5"
   void DebugPrint(string message);
#import

// Declare necessary variables (without extern)
ENUM_TIMEFRAMES SR_Timeframe = PERIOD_H1;  // Default timeframe

// Arrays for support and resistance levels
double support_levels[10];  // Up to 10 support levels
double resistance_levels[10]; // Up to 10 resistance levels
int support_count = 0;
int resistance_count = 0;

// Caching variables to avoid redundant calculations
datetime s_sr_last_calculation_time = 0;
int s_sr_cache_period_seconds = 0;

// Tolerance constant for consistent calculations
#define SR_TOLERANCE_PERCENT 0.005  // 0.5% tolerance for level proximity
#define SR_BREAKOUT_CONFIRM_PERCENT 0.003  // 0.3% for breakout confirmation zone

//+------------------------------------------------------------------+
//| Set the timeframe for this module                                 |
//+------------------------------------------------------------------+
void SetSRTimeframe(ENUM_TIMEFRAMES timeframe)
{
    SR_Timeframe = timeframe;
    s_sr_cache_period_seconds = PeriodSeconds(timeframe);
    DebugPrint("SupportResistance timeframe set to: " + EnumToString(timeframe));
}

//+------------------------------------------------------------------+
//| Check if level is duplicate (too close to existing level)         |
//+------------------------------------------------------------------+
bool IsDuplicateLevel(double level, double levels[], int count)
{
    double tolerance = level * SR_TOLERANCE_PERCENT;
    for(int i = 0; i < count; i++) {
        if(MathAbs(level - levels[i]) < tolerance) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Identify support and resistance levels                             |
//+------------------------------------------------------------------+
void IdentifySupportResistanceLevels()
{
    DebugPrint("Starting support and resistance level identification");

    // Get candle data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), SR_Timeframe, 0, 200, rates);

    if(copied < 100) {
        DebugPrint("Unable to retrieve enough data for support and resistance analysis. Copied: " + IntegerToString(copied));
        return;
    }

    // Reset counters
    support_count = 0;
    resistance_count = 0;

    // FIX: Changed loop limit from i < 100 to i < 98 to prevent array bounds violation
    // when accessing rates[i+2] (max index would be 99 when i=97)
    int max_index = MathMin(98, copied - 2);

    // Find support levels (price lows)
    for(int i = 10; i < max_index && support_count < 10; i++) {
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
           rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
        {
            // FIX: Check for duplicate levels before adding
            if(!IsDuplicateLevel(rates[i].low, support_levels, support_count)) {
                // Check validity of the level (must be tested at least 2 times)
                if(IsSupportValid(rates, rates[i].low)) {
                    support_levels[support_count] = rates[i].low;
                    support_count++;
                    DebugPrint("Found support level: " + DoubleToString(rates[i].low, 5));
                }
            }
        }
    }

    // Find resistance levels (price highs)
    for(int i = 10; i < max_index && resistance_count < 10; i++) {
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
           rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
        {
            // FIX: Check for duplicate levels before adding
            if(!IsDuplicateLevel(rates[i].high, resistance_levels, resistance_count)) {
                // Check validity of the level (must be tested at least 2 times)
                if(IsResistanceValid(rates, rates[i].high)) {
                    resistance_levels[resistance_count] = rates[i].high;
                    resistance_count++;
                    DebugPrint("Found resistance level: " + DoubleToString(rates[i].high, 5));
                }
            }
        }
    }
    
    // Sort support levels (ascending)
    if(support_count > 1) {
        for(int i = 0; i < support_count - 1; i++) {
            for(int j = i + 1; j < support_count; j++) {
                if(support_levels[i] > support_levels[j]) {
                    double temp = support_levels[i];
                    support_levels[i] = support_levels[j];
                    support_levels[j] = temp;
                }
            }
        }
    }
    
    // Sort resistance levels (descending)
    if(resistance_count > 1) {
        for(int i = 0; i < resistance_count - 1; i++) {
            for(int j = i + 1; j < resistance_count; j++) {
                if(resistance_levels[i] < resistance_levels[j]) {
                    double temp = resistance_levels[i];
                    resistance_levels[i] = resistance_levels[j];
                    resistance_levels[j] = temp;
                }
            }
        }
    }
    
    DebugPrint("Number of identified support levels: " + IntegerToString(support_count));
    DebugPrint("Number of identified resistance levels: " + IntegerToString(resistance_count));

    // Update cache timestamp
    s_sr_last_calculation_time = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Check validity of support level                                   |
//+------------------------------------------------------------------+
bool IsSupportValid(MqlRates &rates[], double level)
{
    int test_count = 0;
    // FIX: Use consistent tolerance calculation
    double tolerance = level * SR_TOLERANCE_PERCENT;
    int max_check = MathMin(200, ArraySize(rates));

    for(int i = 0; i < max_check; i++) {
        if(MathAbs(rates[i].low - level) <= tolerance) {
            test_count++;
            if(test_count >= 2) return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check validity of resistance level                                |
//+------------------------------------------------------------------+
bool IsResistanceValid(MqlRates &rates[], double level)
{
    int test_count = 0;
    // FIX: Use consistent tolerance calculation
    double tolerance = level * SR_TOLERANCE_PERCENT;
    int max_check = MathMin(200, ArraySize(rates));

    for(int i = 0; i < max_check; i++) {
        if(MathAbs(rates[i].high - level) <= tolerance) {
            test_count++;
            if(test_count >= 2) return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check price against support and resistance levels for buying     |
//+------------------------------------------------------------------+
int CheckSupportResistanceBuy()
{
    DebugPrint("Checking support/resistance levels for buy signal");

    // FIX: Implement caching to avoid redundant calculations
    datetime current_time = TimeCurrent();
    if(support_count == 0 || resistance_count == 0 ||
       (current_time - s_sr_last_calculation_time) > s_sr_cache_period_seconds) {
        IdentifySupportResistanceLevels();
        if(support_count == 0 && resistance_count == 0) {
            DebugPrint("No support or resistance levels identified");
            return 0;
        }
    }

    // Get current and previous prices
    double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), SR_Timeframe, 0, 3, rates);

    if(copied < 2) {
        DebugPrint("Unable to get recent price data for S/R check");
        return 0;
    }

    int confirmations = 0;
    double tolerance = current_price * SR_TOLERANCE_PERCENT;
    double breakout_zone = current_price * SR_BREAKOUT_CONFIRM_PERCENT;

    // FIX: Corrected proximity logic - Check if price is AT or NEAR support (bounce scenario)
    // Price should be at/near support level, not necessarily above it
    for(int i = 0; i < support_count; i++) {
        double distance = current_price - support_levels[i];

        // Check if price is near support (within tolerance) and showing bounce
        if(MathAbs(distance) <= tolerance) {
            // Additional confirmation: check if previous candle tested support
            if(rates[1].low <= support_levels[i] && rates[0].close > rates[0].open) {
                confirmations++;
                DebugPrint("Price bouncing from support level: " + DoubleToString(support_levels[i], 5) +
                          " Current: " + DoubleToString(current_price, 5));
                break;
            }
        }
    }

    // FIX: Improved breakout detection - Check for confirmed breakout above resistance
    for(int i = 0; i < resistance_count; i++) {
        // Price must be above resistance but within confirmation zone
        if(current_price > resistance_levels[i] &&
           (current_price - resistance_levels[i]) <= breakout_zone) {
            // Confirm previous candle was below resistance (actual breakout)
            if(rates[1].close <= resistance_levels[i]) {
                confirmations++;
                DebugPrint("Price breaking above resistance level: " + DoubleToString(resistance_levels[i], 5) +
                          " Current: " + DoubleToString(current_price, 5));
                break;
            }
        }
    }

    DebugPrint("S/R Buy confirmations: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Check price against support and resistance levels for selling    |
//+------------------------------------------------------------------+
int CheckSupportResistanceShort()
{
    DebugPrint("Checking support/resistance levels for sell signal");

    // FIX: Implement caching to avoid redundant calculations
    datetime current_time = TimeCurrent();
    if(support_count == 0 || resistance_count == 0 ||
       (current_time - s_sr_last_calculation_time) > s_sr_cache_period_seconds) {
        IdentifySupportResistanceLevels();
        if(support_count == 0 && resistance_count == 0) {
            DebugPrint("No support or resistance levels identified");
            return 0;
        }
    }

    // Get current and previous prices
    double current_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), SR_Timeframe, 0, 3, rates);

    if(copied < 2) {
        DebugPrint("Unable to get recent price data for S/R check");
        return 0;
    }

    int confirmations = 0;
    double tolerance = current_price * SR_TOLERANCE_PERCENT;
    double breakout_zone = current_price * SR_BREAKOUT_CONFIRM_PERCENT;

    // FIX: Corrected proximity logic - Check if price is AT or NEAR resistance (rejection scenario)
    // Price should be at/near resistance level, not necessarily below it
    for(int i = 0; i < resistance_count; i++) {
        double distance = resistance_levels[i] - current_price;

        // Check if price is near resistance (within tolerance) and showing rejection
        if(MathAbs(distance) <= tolerance) {
            // Additional confirmation: check if previous candle tested resistance
            if(rates[1].high >= resistance_levels[i] && rates[0].close < rates[0].open) {
                confirmations++;
                DebugPrint("Price rejecting from resistance level: " + DoubleToString(resistance_levels[i], 5) +
                          " Current: " + DoubleToString(current_price, 5));
                break;
            }
        }
    }

    // FIX: Improved breakout detection - Check for confirmed breakout below support
    for(int i = 0; i < support_count; i++) {
        // Price must be below support but within confirmation zone
        if(current_price < support_levels[i] &&
           (support_levels[i] - current_price) <= breakout_zone) {
            // Confirm previous candle was above support (actual breakout)
            if(rates[1].close >= support_levels[i]) {
                confirmations++;
                DebugPrint("Price breaking below support level: " + DoubleToString(support_levels[i], 5) +
                          " Current: " + DoubleToString(current_price, 5));
                break;
            }
        }
    }

    DebugPrint("S/R Sell confirmations: " + IntegerToString(confirmations));
    return confirmations;
}