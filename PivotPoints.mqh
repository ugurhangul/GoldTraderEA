//+------------------------------------------------------------------+
//|                                      PivotPoints.mqh |
//|                                                             |
//|                                                             |
//+------------------------------------------------------------------+

// Timeframe for this module
extern ENUM_TIMEFRAMES PP_Timeframe;

// Structure to hold pivot point levels
struct PivotLevels
{
    double pivot;      // Main pivot point
    double r1, r2, r3; // Resistance levels
    double s1, s2, s3; // Support levels
};

// Calculate Standard Pivot Points based on previous day's high, low, and close
PivotLevels CalculatePivotPoints(double prevHigh, double prevLow, double prevClose)
{
    PivotLevels levels;
    
    // Calculate main pivot point
    levels.pivot = (prevHigh + prevLow + prevClose) / 3;
    
    // Calculate resistance levels
    levels.r1 = (2 * levels.pivot) - prevLow;
    levels.r2 = levels.pivot + (prevHigh - prevLow);
    levels.r3 = prevHigh + 2 * (levels.pivot - prevLow);
    
    // Calculate support levels
    levels.s1 = (2 * levels.pivot) - prevHigh;
    levels.s2 = levels.pivot - (prevHigh - prevLow);
    levels.s3 = prevLow - 2 * (prevHigh - levels.pivot);
    
    return levels;
}

// Function to check for pivot point support (buy signal)
bool CheckPivotSupportBuy(const MqlRates &rates[], int size, ENUM_TIMEFRAMES pivotTimeframe = PERIOD_D1)
{
    if (size < 3)
        return false;
    
    // Get the most recent daily candle that's completed
    MqlRates dailyRates[];
    int copied = CopyRates(Symbol(), pivotTimeframe, 1, 2, dailyRates);
    
    if (copied != 2)
        return false;
    
    // Calculate pivot points using the previous completed daily candle
    PivotLevels levels = CalculatePivotPoints(dailyRates[1].high, dailyRates[1].low, dailyRates[1].close);
    
    // Current price
    double currentPrice = rates[0].close;
    
    // Check if price is near support levels
    double nearThreshold = (levels.r1 - levels.s1) * 0.05; // 5% of range as "near" threshold
    
    // Check if price bounced from support levels
    if ((MathAbs(rates[1].low - levels.s1) < nearThreshold && currentPrice > rates[1].close) ||
        (MathAbs(rates[1].low - levels.s2) < nearThreshold && currentPrice > rates[1].close) ||
        (MathAbs(rates[1].low - levels.s3) < nearThreshold && currentPrice > rates[1].close) ||
        (MathAbs(rates[1].low - levels.pivot) < nearThreshold && currentPrice > rates[1].close))
    {
        return true;
    }
    
    // Check if price breaks above pivot after testing support
    if (rates[1].close < levels.pivot && currentPrice > levels.pivot)
    {
        return true;
    }
    
    return false;
}

// Function to check for pivot point resistance (sell signal)
bool CheckPivotResistanceShort(const MqlRates &rates[], int size, ENUM_TIMEFRAMES pivotTimeframe = PERIOD_D1)
{
    if (size < 3)
        return false;
    
    // Get the most recent daily candle that's completed
    MqlRates dailyRates[];
    int copied = CopyRates(Symbol(), pivotTimeframe, 1, 2, dailyRates);
    
    if (copied != 2)
        return false;
    
    // Calculate pivot points using the previous completed daily candle
    PivotLevels levels = CalculatePivotPoints(dailyRates[1].high, dailyRates[1].low, dailyRates[1].close);
    
    // Current price
    double currentPrice = rates[0].close;
    
    // Check if price is near resistance levels
    double nearThreshold = (levels.r1 - levels.s1) * 0.05; // 5% of range as "near" threshold
    
    // Check if price bounced from resistance levels
    if ((MathAbs(rates[1].high - levels.r1) < nearThreshold && currentPrice < rates[1].close) ||
        (MathAbs(rates[1].high - levels.r2) < nearThreshold && currentPrice < rates[1].close) ||
        (MathAbs(rates[1].high - levels.r3) < nearThreshold && currentPrice < rates[1].close) ||
        (MathAbs(rates[1].high - levels.pivot) < nearThreshold && currentPrice < rates[1].close))
    {
        return true;
    }
    
    // Check if price breaks below pivot after testing resistance
    if (rates[1].close > levels.pivot && currentPrice < levels.pivot)
    {
        return true;
    }
    
    return false;
}

// Check if price is between two pivot levels (consolidation)
bool IsBetweenPivotLevels(double price, double levelAbove, double levelBelow)
{
    return (price < levelAbove && price > levelBelow);
}

// Function to detect breakout from pivot level consolidation
bool CheckPivotBreakout(const MqlRates &rates[], int size, bool lookForBuy, ENUM_TIMEFRAMES pivotTimeframe = PERIOD_D1)
{
    if (size < 5)
        return false;
    
    // Get the most recent daily candle that's completed
    MqlRates dailyRates[];
    int copied = CopyRates(Symbol(), pivotTimeframe, 1, 2, dailyRates);
    
    if (copied != 2)
        return false;
    
    // Calculate pivot points using the previous completed daily candle
    PivotLevels levels = CalculatePivotPoints(dailyRates[1].high, dailyRates[1].low, dailyRates[1].close);
    
    // Determine which levels to check
    double upperLevel = 0, lowerLevel = 0;
    
    // Find the two levels price has been consolidating between
    if (lookForBuy)
    {
        // For buy signals, check for breakout above resistance
        if (IsBetweenPivotLevels(rates[1].close, levels.r1, levels.pivot))
        {
            upperLevel = levels.r1;
            lowerLevel = levels.pivot;
        }
        else if (IsBetweenPivotLevels(rates[1].close, levels.pivot, levels.s1))
        {
            upperLevel = levels.pivot;
            lowerLevel = levels.s1;
        }
        
        // Check if at least 3 bars were between these levels and now we break above
        if (upperLevel > 0 && lowerLevel > 0)
        {
            bool wasConsolidating = true;
            for (int i = 1; i < 4 && i < size; i++)
            {
                if (!IsBetweenPivotLevels(rates[i].close, upperLevel, lowerLevel))
                {
                    wasConsolidating = false;
                    break;
                }
            }
            
            // Check for breakout above upper level
            if (wasConsolidating && rates[0].close > upperLevel)
                return true;
        }
    }
    else // Looking for sell signals
    {
        // For sell signals, check for breakout below support
        if (IsBetweenPivotLevels(rates[1].close, levels.r1, levels.pivot))
        {
            upperLevel = levels.r1;
            lowerLevel = levels.pivot;
        }
        else if (IsBetweenPivotLevels(rates[1].close, levels.pivot, levels.s1))
        {
            upperLevel = levels.pivot;
            lowerLevel = levels.s1;
        }
        
        // Check if at least 3 bars were between these levels and now we break below
        if (upperLevel > 0 && lowerLevel > 0)
        {
            bool wasConsolidating = true;
            for (int i = 1; i < 4 && i < size; i++)
            {
                if (!IsBetweenPivotLevels(rates[i].close, upperLevel, lowerLevel))
                {
                    wasConsolidating = false;
                    break;
                }
            }
            
            // Check for breakout below lower level
            if (wasConsolidating && rates[0].close < lowerLevel)
                return true;
        }
    }
    
    return false;
}

// Calculate Standard Pivot Points
void CalculateStandardPivotPoints(double high, double low, double close,
                                  double &pivot, double &r1, double &r2, double &r3,
                                  double &s1, double &s2, double &s3)
{
    // Calculate the pivot point
    pivot = (high + low + close) / 3.0;
    
    // Calculate resistance levels
    r1 = (2.0 * pivot) - low;
    r2 = pivot + (high - low);
    r3 = high + 2.0 * (pivot - low);
    
    // Calculate support levels
    s1 = (2.0 * pivot) - high;
    s2 = pivot - (high - low);
    s3 = low - 2.0 * (high - pivot);
}

// Calculate Fibonacci Pivot Points
void CalculateFibonacciPivotPoints(double high, double low, double close,
                                  double &pivot, double &r1, double &r2, double &r3,
                                  double &s1, double &s2, double &s3)
{
    // Calculate the pivot point
    pivot = (high + low + close) / 3.0;
    
    // Calculate resistance levels using Fibonacci ratios
    r1 = pivot + 0.382 * (high - low);
    r2 = pivot + 0.618 * (high - low);
    r3 = pivot + 1.000 * (high - low);
    
    // Calculate support levels using Fibonacci ratios
    s1 = pivot - 0.382 * (high - low);
    s2 = pivot - 0.618 * (high - low);
    s3 = pivot - 1.000 * (high - low);
}

// Calculate Camarilla Pivot Points
void CalculateCamarillaPivotPoints(double high, double low, double close,
                                  double &pivot, double &r1, double &r2, double &r3, double &r4,
                                  double &s1, double &s2, double &s3, double &s4)
{
    // Calculate the pivot point
    pivot = (high + low + close) / 3.0;
    
    // Calculate resistance levels
    r1 = close + ((high - low) * 1.1 / 12.0);
    r2 = close + ((high - low) * 1.1 / 6.0);
    r3 = close + ((high - low) * 1.1 / 4.0);
    r4 = close + ((high - low) * 1.1 / 2.0);
    
    // Calculate support levels
    s1 = close - ((high - low) * 1.1 / 12.0);
    s2 = close - ((high - low) * 1.1 / 6.0);
    s3 = close - ((high - low) * 1.1 / 4.0);
    s4 = close - ((high - low) * 1.1 / 2.0);
}

// Calculate Woodie's Pivot Points
void CalculateWoodiePivotPoints(double high, double low, double close, double open,
                                double &pivot, double &r1, double &r2, double &r3,
                                double &s1, double &s2, double &s3)
{
    // Calculate the pivot point (using today's open)
    pivot = (high + low + 2.0 * open) / 4.0;
    
    // Calculate resistance levels
    r1 = (2.0 * pivot) - low;
    r2 = pivot + (high - low);
    r3 = high + 2.0 * (pivot - low);
    
    // Calculate support levels
    s1 = (2.0 * pivot) - high;
    s2 = pivot - (high - low);
    s3 = low - 2.0 * (high - pivot);
}

// Calculate DeMark's Pivot Points
void CalculateDeMarkPivotPoints(double high, double low, double open, double close,
                                double &pivot, double &r1, double &s1)
{
    // Determine X based on open and close
    double x;
    if (close < open)
        x = high + (2.0 * low) + close;
    else if (close > open)
        x = (2.0 * high) + low + close;
    else // close = open
        x = high + low + (2.0 * close);
    
    // Calculate the pivot point
    pivot = x / 4.0;
    
    // Calculate resistance and support levels
    r1 = (x / 2.0) - low;
    s1 = (x / 2.0) - high;
}

// Check for price near pivot levels (for buy signals)
bool IsPriceNearPivotSupport(double price, double s1, double s2, double s3, double pip_threshold)
{
    // Check if price is within the threshold of any support level
    return (MathAbs(price - s1) <= pip_threshold ||
            MathAbs(price - s2) <= pip_threshold ||
            MathAbs(price - s3) <= pip_threshold);
}

// Check for price near pivot levels (for sell signals)
bool IsPriceNearPivotResistance(double price, double r1, double r2, double r3, double pip_threshold)
{
    // Check if price is within the threshold of any resistance level
    return (MathAbs(price - r1) <= pip_threshold ||
            MathAbs(price - r2) <= pip_threshold ||
            MathAbs(price - r3) <= pip_threshold);
}

// Check for price breaking through pivot levels (for buy signals)
bool IsPriceBreakingPivotResistance(double current_price, double previous_price, double r1, double r2, double r3)
{
    // Check if price is breaking through any resistance level
    return (previous_price < r1 && current_price >= r1) ||
           (previous_price < r2 && current_price >= r2) ||
           (previous_price < r3 && current_price >= r3);
}

// Check for price breaking through pivot levels (for sell signals)
bool IsPriceBreakingPivotSupport(double current_price, double previous_price, double s1, double s2, double s3)
{
    // Check if price is breaking through any support level
    return (previous_price > s1 && current_price <= s1) ||
           (previous_price > s2 && current_price <= s2) ||
           (previous_price > s3 && current_price <= s3);
}

// Check for pivot point reversal (for buy signals)
bool IsPivotReversalBuy(double &close[], double s1, double s2, double s3, int shift = 0)
{
    if (ArraySize(close) < 3 + shift)
        return false;
    
    // Check for a downward movement followed by a reversal at a support level
    return (close[shift + 2] > close[shift + 1] && // Price was going down
            (MathAbs(close[shift + 1] - s1) <= 0.0001 || // Price reached a support level
             MathAbs(close[shift + 1] - s2) <= 0.0001 ||
             MathAbs(close[shift + 1] - s3) <= 0.0001) &&
            close[shift] > close[shift + 1]); // Price reversed up
}

// Check for pivot point reversal (for sell signals)
bool IsPivotReversalSell(double &close[], double r1, double r2, double r3, int shift = 0)
{
    if (ArraySize(close) < 3 + shift)
        return false;
    
    // Check for an upward movement followed by a reversal at a resistance level
    return (close[shift + 2] < close[shift + 1] && // Price was going up
            (MathAbs(close[shift + 1] - r1) <= 0.0001 || // Price reached a resistance level
             MathAbs(close[shift + 1] - r2) <= 0.0001 ||
             MathAbs(close[shift + 1] - r3) <= 0.0001) &&
            close[shift] < close[shift + 1]); // Price reversed down
}

// Check for pivot range breakout (for buy signals)
bool IsPivotRangeBreakoutBuy(double &high[], double pivot, double r1, int shift = 0)
{
    if (ArraySize(high) < 2 + shift)
        return false;
    
    // Check if the price has been trading between the pivot and R1, 
    // and then breaks above R1
    return (high[shift + 1] > pivot && high[shift + 1] < r1 && high[shift] > r1);
}

// Check for pivot range breakout (for sell signals)
bool IsPivotRangeBreakoutSell(double &low[], double pivot, double s1, int shift = 0)
{
    if (ArraySize(low) < 2 + shift)
        return false;
    
    // Check if the price has been trading between the pivot and S1,
    // and then breaks below S1
    return (low[shift + 1] < pivot && low[shift + 1] > s1 && low[shift] < s1);
}

// Check for pivot-based buy signal
bool CheckPivotBuySignal(double &high[], double &low[], double &close[], double &open[], 
                         double pivot, double r1, double r2, double r3, 
                         double s1, double s2, double s3, int shift = 0)
{
    // Check for various pivot-based buy signals
    bool price_bounced_from_support = IsPivotReversalBuy(close, s1, s2, s3, shift);
    bool price_broke_resistance = IsPriceBreakingPivotResistance(close[shift], close[shift + 1], r1, r2, r3);
    bool range_breakout = IsPivotRangeBreakoutBuy(high, pivot, r1, shift);
    
    // Return true if any of the pivot-based buy signals are triggered
    return price_bounced_from_support || price_broke_resistance || range_breakout;
}

// Check for pivot-based sell signal
bool CheckPivotSellSignal(double &high[], double &low[], double &close[], double &open[], 
                         double pivot, double r1, double r2, double r3, 
                         double s1, double s2, double s3, int shift = 0)
{
    // Check for various pivot-based sell signals
    bool price_bounced_from_resistance = IsPivotReversalSell(close, r1, r2, r3, shift);
    bool price_broke_support = IsPriceBreakingPivotSupport(close[shift], close[shift + 1], s1, s2, s3);
    bool range_breakout = IsPivotRangeBreakoutSell(low, pivot, s1, shift);
    
    // Return true if any of the pivot-based sell signals are triggered
    return price_bounced_from_resistance || price_broke_support || range_breakout;
}

//+------------------------------------------------------------------+
//| General pivot variables                                          |
//+------------------------------------------------------------------+
extern double daily_pivot, weekly_pivot, monthly_pivot;
extern double daily_s1, daily_s2, daily_s3, daily_r1, daily_r2, daily_r3;
extern double weekly_s1, weekly_s2, weekly_s3, weekly_r1, weekly_r2, weekly_r3;

// The DebugPrint function should be defined in the main file
#import "GoldTraderEA_cleaned.mq5"
   void DebugPrint(string message);
#import

//+------------------------------------------------------------------+
//| Calculate daily, weekly, and monthly pivot levels                |
//+------------------------------------------------------------------+
void CalculatePivotLevels()
{
    MqlRates daily_rates[];
    MqlRates weekly_rates[];
    MqlRates monthly_rates[];
    
    // Get daily data
    ArraySetAsSeries(daily_rates, true);
    int copied = CopyRates(Symbol(), PERIOD_D1, 0, 2, daily_rates);
    if(copied < 2) {
        DebugPrint("Error retrieving daily data for pivot calculation: " + IntegerToString(GetLastError()));
        return;
    }
    
    // Get weekly data
    ArraySetAsSeries(weekly_rates, true);
    copied = CopyRates(Symbol(), PERIOD_W1, 0, 2, weekly_rates);
    if(copied < 2) {
        DebugPrint("Error retrieving weekly data for pivot calculation: " + IntegerToString(GetLastError()));
        return;
    }
    
    // Get monthly data
    ArraySetAsSeries(monthly_rates, true);
    copied = CopyRates(Symbol(), PERIOD_MN1, 0, 2, monthly_rates);
    if(copied < 2) {
        DebugPrint("Error retrieving monthly data for pivot calculation: " + IntegerToString(GetLastError()));
        return;
    }
    
    // Calculate daily pivot
    double daily_high = daily_rates[1].high;
    double daily_low = daily_rates[1].low;
    double daily_close = daily_rates[1].close;
    
    daily_pivot = (daily_high + daily_low + daily_close) / 3;
    daily_s1 = (2 * daily_pivot) - daily_high;
    daily_s2 = daily_pivot - (daily_high - daily_low);
    daily_s3 = daily_low - 2 * (daily_high - daily_pivot);
    daily_r1 = (2 * daily_pivot) - daily_low;
    daily_r2 = daily_pivot + (daily_high - daily_low);
    daily_r3 = daily_high + 2 * (daily_pivot - daily_low);
    
    // Calculate weekly pivot
    double weekly_high = weekly_rates[1].high;
    double weekly_low = weekly_rates[1].low;
    double weekly_close = weekly_rates[1].close;
    
    weekly_pivot = (weekly_high + weekly_low + weekly_close) / 3;
    weekly_s1 = (2 * weekly_pivot) - weekly_high;
    weekly_s2 = weekly_pivot - (weekly_high - weekly_low);
    weekly_s3 = weekly_low - 2 * (weekly_high - weekly_pivot);
    weekly_r1 = (2 * weekly_pivot) - weekly_low;
    weekly_r2 = weekly_pivot + (weekly_high - weekly_low);
    weekly_r3 = weekly_high + 2 * (weekly_pivot - weekly_low);
    
    // Calculate monthly pivot
    double monthly_high = monthly_rates[1].high;
    double monthly_low = monthly_rates[1].low;
    double monthly_close = monthly_rates[1].close;
    
    monthly_pivot = (monthly_high + monthly_low + monthly_close) / 3;
    
    DebugPrint("Daily pivot: " + DoubleToString(daily_pivot, 2) + 
               ", S1: " + DoubleToString(daily_s1, 2) + 
               ", R1: " + DoubleToString(daily_r1, 2));
    DebugPrint("Weekly pivot: " + DoubleToString(weekly_pivot, 2) + 
               ", S1: " + DoubleToString(weekly_s1, 2) + 
               ", R1: " + DoubleToString(weekly_r1, 2));
    DebugPrint("Monthly pivot: " + DoubleToString(monthly_pivot, 2));
}

//+------------------------------------------------------------------+
//| Check pivot levels for buy signal                                 |
//+------------------------------------------------------------------+
int CheckPivotPointsBuy(MqlRates &rates[])
{
    DebugPrint("Starting to check pivot levels for buy");
    
    int confirmations = 0;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 3) {
        DebugPrint("Rates array for CheckPivotPointsBuy is smaller than required size: " + IntegerToString(size));
        return 0;
    }
    
    double current_close = rates[0].close;
    double current_open = rates[0].open;
    double previous_close = rates[1].close;
    
    // Check for bounce from daily support level
    if(previous_close < daily_s1 && current_close > daily_s1 && current_close > current_open) {
        DebugPrint("Bullish bounce from daily support S1");
        confirmations++;
    }
    
    if(previous_close < daily_s2 && current_close > daily_s2 && current_close > current_open) {
        DebugPrint("Bullish bounce from daily support S2");
        confirmations++;
    }
    
    // Check for breakout above daily resistance level
    if(previous_close < daily_pivot && current_close > daily_pivot) {
        DebugPrint("Bullish breakout above daily pivot");
        confirmations++;
    }
    
    if(previous_close < daily_r1 && current_close > daily_r1) {
        DebugPrint("Bullish breakout above daily resistance R1");
        confirmations++;
    }
    
    // Check weekly pivot levels (more weight)
    if(previous_close < weekly_s1 && current_close > weekly_s1 && current_close > current_open) {
        DebugPrint("Bullish bounce from weekly support S1");
        confirmations += 2;
    }
    
    if(previous_close < weekly_pivot && current_close > weekly_pivot) {
        DebugPrint("Bullish breakout above weekly pivot");
        confirmations += 2;
    }
    
    // Check proximity to pivot levels
    double pip_size = 10 * _Point; // Size of 10 pips
    
    if(MathAbs(current_close - daily_pivot) < pip_size && current_close > previous_close) {
        DebugPrint("Price near daily pivot level and increasing");
        confirmations++;
    }
    
    if(MathAbs(current_close - weekly_pivot) < pip_size && current_close > previous_close) {
        DebugPrint("Price near weekly pivot level and increasing");
        confirmations += 2;
    }
    
    DebugPrint("Number of pivot confirmations for buy: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Check pivot levels for sell signal                                 |
//+------------------------------------------------------------------+
int CheckPivotPointsShort(MqlRates &rates[])
{
    DebugPrint("Starting to check pivot levels for sell");
    
    int confirmations = 0;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 3) {
        DebugPrint("Rates array for CheckPivotPointsShort is smaller than required size: " + IntegerToString(size));
        return 0;
    }
    
    double current_close = rates[0].close;
    double current_open = rates[0].open;
    double previous_close = rates[1].close;
    
    // Check for bounce from daily resistance level
    if(previous_close > daily_r1 && current_close < daily_r1 && current_close < current_open) {
        DebugPrint("Bearish bounce from daily resistance R1");
        confirmations++;
    }
    
    if(previous_close > daily_r2 && current_close < daily_r2 && current_close < current_open) {
        DebugPrint("Bearish bounce from daily resistance R2");
        confirmations++;
    }
    
    // Check for breakout below daily support level
    if(previous_close > daily_pivot && current_close < daily_pivot) {
        DebugPrint("Bearish breakout below daily pivot");
        confirmations++;
    }
    
    if(previous_close > daily_s1 && current_close < daily_s1) {
        DebugPrint("Bearish breakout below daily support S1");
        confirmations++;
    }
    
    // Check weekly pivot levels (more weight)
    if(previous_close > weekly_r1 && current_close < weekly_r1 && current_close < current_open) {
        DebugPrint("Bearish bounce from weekly resistance R1");
        confirmations += 2;
    }
    
    if(previous_close > weekly_pivot && current_close < weekly_pivot) {
        DebugPrint("Bearish breakout below weekly pivot");
        confirmations += 2;
    }
    
    // Check proximity to pivot levels
    double pip_size = 10 * _Point; // Size of 10 pips
    
    if(MathAbs(current_close - daily_pivot) < pip_size && current_close < previous_close) {
        DebugPrint("Price near daily pivot level and decreasing");
        confirmations++;
    }
    
    if(MathAbs(current_close - weekly_pivot) < pip_size && current_close < previous_close) {
        DebugPrint("Price near weekly pivot level and decreasing");
        confirmations += 2;
    }
    
    DebugPrint("Number of pivot confirmations for sell: " + IntegerToString(confirmations));
    return confirmations;
} 