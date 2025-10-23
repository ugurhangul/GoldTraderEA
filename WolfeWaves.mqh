//+------------------------------------------------------------------+
//|                                                 WolfeWaves.mqh |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property link      ""

// Timeframe for this module
extern ENUM_TIMEFRAMES WW_Timeframe;

// Import DebugPrint function from main file
#import "GoldTraderEA_cleaned.mq5"
   void DebugPrint(string message);
#import

//+------------------------------------------------------------------+
//| Detecting Bullish Wolfe Wave Pattern                              |
//+------------------------------------------------------------------+
bool IsBullishWolfeWave(MqlRates &rates[])
{
    int size = ArraySize(rates);
    // Need at least 51 elements to safely access rates[50] (when i=49, we access rates[i+1])
    if(size < 51)
        return false;

    // Finding the 5 points needed for the Wolfe pattern
    // Point 1 (local low)
    // Point 2 (local high after point 1)
    // Point 3 (local low after point 2)
    // Point 4 (local high after point 3)
    // Point 5 (local low after point 4)

    int points[5] = {-1, -1, -1, -1, -1};   // Points 1 to 5 of the pattern (initialized to -1)
    double values[5] = {0}; // Price values at points 1 to 5

    // Finding point 1 (local low)
    for(int i = 49; i > 40; i--) {
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low) {
            points[0] = i;
            values[0] = rates[i].low;
            break;
        }
    }

    if(points[0] == -1)
        return false;

    // Finding point 2 (local high after point 1)
    for(int i = points[0] - 1; i > 30; i--) {
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high) {
            points[1] = i;
            values[1] = rates[i].high;
            break;
        }
    }

    if(points[1] == -1 || points[1] >= points[0])
        return false;

    // Finding point 3 (local low after point 2)
    for(int i = points[1] - 1; i > 20; i--) {
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low) {
            points[2] = i;
            values[2] = rates[i].low;
            break;
        }
    }

    if(points[2] == -1 || points[2] >= points[1])
        return false;

    // Finding point 4 (local high after point 3)
    for(int i = points[2] - 1; i > 10; i--) {
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high) {
            points[3] = i;
            values[3] = rates[i].high;
            break;
        }
    }

    if(points[3] == -1 || points[3] >= points[2])
        return false;

    // Finding point 5 (local low after point 4)
    // Start from 1 to avoid accessing rates[-1]
    for(int i = points[3] - 1; i >= 1; i--) {
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low) {
            points[4] = i;
            values[4] = rates[i].low;
            break;
        }
    }

    // If point 5 is not found, pattern is invalid
    if(points[4] == -1)
        return false;

    // Checking conditions for the bullish Wolfe pattern

    // Protection against division by zero
    if(points[0] == points[2] || points[1] == points[3])
        return false;

    // Condition 1: Points 1-3-5 must be aligned (trend line)
    double slope_1_3 = (values[2] - values[0]) / (points[0] - points[2]);
    double expected_point5 = values[0] + slope_1_3 * (points[0] - points[4]);
    double tolerance = MathAbs(values[0] - values[2]) * 0.1; // 10% tolerance

    if(MathAbs(values[4] - expected_point5) > tolerance)
        return false;

    // Condition 2: Points 2-4 must form a channel line (validate alignment)
    double slope_2_4 = (values[3] - values[1]) / (points[1] - points[3]);
    // The slopes should be roughly parallel (within tolerance)
    double slope_diff = MathAbs(slope_1_3 - slope_2_4);
    double slope_tolerance = MathAbs(slope_1_3) * 0.5; // 50% tolerance for slope difference

    if(slope_diff > slope_tolerance && slope_tolerance > 0)
        return false;

    // Condition 3: Point 4 must be lower than point 2 (weakening upward momentum)
    if(values[3] >= values[1])
        return false;

    // Condition 4: Point 3 must be higher than point 1 (higher low pattern)
    if(values[2] <= values[0])
        return false;

    // Condition 5: Time symmetry check (relaxed - allow some variation)
    // Instead of strict decreasing, check that pattern completes in reasonable time
    int time_1_2 = points[0] - points[1];
    int time_2_3 = points[1] - points[2];
    int time_3_4 = points[2] - points[3];
    int time_4_5 = points[3] - points[4];

    // Total time should be reasonable (not too compressed or too extended)
    int total_time = points[0] - points[4];
    if(total_time < 10 || total_time > 45)
        return false;

    // Calculate target price (intersection of line 1-3-5 with vertical line from point 1)
    double target_price = values[0] + slope_1_3 * (points[0] - 0);

    DebugPrint("Bullish Wolfe Wave pattern identified with target price: " + DoubleToString(target_price, 2));
    return true;
}

//+------------------------------------------------------------------+
//| Detecting Bearish Wolfe Wave Pattern                              |
//+------------------------------------------------------------------+
bool IsBearishWolfeWave(MqlRates &rates[])
{
    int size = ArraySize(rates);
    // Need at least 51 elements to safely access rates[50] (when i=49, we access rates[i+1])
    if(size < 51)
        return false;

    // Finding the 5 points needed for the Wolfe pattern
    // Point 1 (local high)
    // Point 2 (local low after point 1)
    // Point 3 (local high after point 2)
    // Point 4 (local low after point 3)
    // Point 5 (local high after point 4)

    int points[5] = {-1, -1, -1, -1, -1};   // Points 1 to 5 of the pattern (initialized to -1)
    double values[5] = {0}; // Price values at points 1 to 5

    // Finding point 1 (local high)
    for(int i = 49; i > 40; i--) {
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high) {
            points[0] = i;
            values[0] = rates[i].high;
            break;
        }
    }

    if(points[0] == -1)
        return false;

    // Finding point 2 (local low after point 1)
    for(int i = points[0] - 1; i > 30; i--) {
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low) {
            points[1] = i;
            values[1] = rates[i].low;
            break;
        }
    }

    if(points[1] == -1 || points[1] >= points[0])
        return false;

    // Finding point 3 (local high after point 2)
    for(int i = points[1] - 1; i > 20; i--) {
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high) {
            points[2] = i;
            values[2] = rates[i].high;
            break;
        }
    }

    if(points[2] == -1 || points[2] >= points[1])
        return false;

    // Finding point 4 (local low after point 3)
    for(int i = points[2] - 1; i > 10; i--) {
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low) {
            points[3] = i;
            values[3] = rates[i].low;
            break;
        }
    }

    if(points[3] == -1 || points[3] >= points[2])
        return false;

    // Finding point 5 (local high after point 4)
    // Start from 1 to avoid accessing rates[-1]
    for(int i = points[3] - 1; i >= 1; i--) {
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high) {
            points[4] = i;
            values[4] = rates[i].high;
            break;
        }
    }

    // If point 5 is not found, pattern is invalid
    if(points[4] == -1)
        return false;

    // Checking conditions for the bearish Wolfe pattern

    // Protection against division by zero
    if(points[0] == points[2] || points[1] == points[3])
        return false;

    // Condition 1: Points 1-3-5 must be aligned (trend line)
    double slope_1_3 = (values[2] - values[0]) / (points[0] - points[2]);
    double expected_point5 = values[0] + slope_1_3 * (points[0] - points[4]);
    double tolerance = MathAbs(values[0] - values[2]) * 0.1; // 10% tolerance

    if(MathAbs(values[4] - expected_point5) > tolerance)
        return false;

    // Condition 2: Points 2-4 must form a channel line (validate alignment)
    double slope_2_4 = (values[3] - values[1]) / (points[1] - points[3]);
    // The slopes should be roughly parallel (within tolerance)
    double slope_diff = MathAbs(slope_1_3 - slope_2_4);
    double slope_tolerance = MathAbs(slope_1_3) * 0.5; // 50% tolerance for slope difference

    if(slope_diff > slope_tolerance && slope_tolerance > 0)
        return false;

    // Condition 3: Point 4 must be higher than point 2 (weakening downward momentum)
    if(values[3] <= values[1])
        return false;

    // Condition 4: Point 3 must be lower than point 1 (lower high pattern)
    if(values[2] >= values[0])
        return false;

    // Condition 5: Time symmetry check (relaxed - allow some variation)
    // Instead of strict decreasing, check that pattern completes in reasonable time
    int time_1_2 = points[0] - points[1];
    int time_2_3 = points[1] - points[2];
    int time_3_4 = points[2] - points[3];
    int time_4_5 = points[3] - points[4];

    // Total time should be reasonable (not too compressed or too extended)
    int total_time = points[0] - points[4];
    if(total_time < 10 || total_time > 45)
        return false;

    // Calculate target price (intersection of line 1-3-5 with vertical line from point 1)
    double target_price = values[0] + slope_1_3 * (points[0] - 0);

    DebugPrint("Bearish Wolfe Wave pattern identified with target price: " + DoubleToString(target_price, 2));
    return true;
}

//+------------------------------------------------------------------+
//| Checking Wolfe Waves for Buy Signal                               |
//+------------------------------------------------------------------+
int CheckWolfeWavesBuy(MqlRates &rates[])
{
    DebugPrint("Starting to check Wolfe Wave patterns for buy");

    int confirmations = 0;

    // Check the size of the rates array
    int size = ArraySize(rates);
    if(size < 51) {
        DebugPrint("The rates array for CheckWolfeWavesBuy is smaller than the required size: " + IntegerToString(size));

        // If the array is too small, try to get more data
        MqlRates local_rates[];
        ArraySetAsSeries(local_rates, true);
        int copied = CopyRates(Symbol(), WW_Timeframe, 0, 100, local_rates);

        if(copied < 51) {
            DebugPrint("Not enough data to detect bullish Wolfe pattern");
            return 0;
        }

        // Check for the existence of a bullish Wolfe Wave pattern with new data
        if(IsBullishWolfeWave(local_rates)) {
            DebugPrint("Bullish Wolfe Wave pattern found");
            confirmations += 3;  // Higher weight for this important pattern
        }

        return confirmations;
    }

    // Check for the existence of a bullish Wolfe Wave pattern
    if(IsBullishWolfeWave(rates)) {
        DebugPrint("Bullish Wolfe Wave pattern found");
        confirmations += 3;  // Higher weight for this important pattern
    }

    return confirmations;
}

//+------------------------------------------------------------------+
//| Checking Wolfe Waves for Sell Signal                              |
//+------------------------------------------------------------------+
int CheckWolfeWavesShort(MqlRates &rates[])
{
    DebugPrint("Starting to check Wolfe Wave patterns for sell");

    int confirmations = 0;

    // Check the size of the rates array
    int size = ArraySize(rates);
    if(size < 51) {
        DebugPrint("The rates array for CheckWolfeWavesShort is smaller than the required size: " + IntegerToString(size));

        // If the array is too small, try to get more data
        MqlRates local_rates[];
        ArraySetAsSeries(local_rates, true);
        int copied = CopyRates(Symbol(), WW_Timeframe, 0, 100, local_rates);

        if(copied < 51) {
            DebugPrint("Not enough data to detect bearish Wolfe pattern");
            return 0;
        }

        // Check for the existence of a bearish Wolfe Wave pattern with new data
        if(IsBearishWolfeWave(local_rates)) {
            DebugPrint("Bearish Wolfe Wave pattern found");
            confirmations += 3;  // Higher weight for this important pattern
        }

        return confirmations;
    }

    // Check for the existence of a bearish Wolfe Wave pattern
    if(IsBearishWolfeWave(rates)) {
        DebugPrint("Bearish Wolfe Wave pattern found");
        confirmations += 3;  // Higher weight for this important pattern
    }

    return confirmations;
}

//+------------------------------------------------------------------+
//| Safe wrapper for Wolfe Waves Buy check                           |
//+------------------------------------------------------------------+
int SafeCheckWolfeWavesBuy(MqlRates &rates[])
{
    // Use the int-returning version (line 252)
    return CheckWolfeWavesBuy(rates);
}

//+------------------------------------------------------------------+
//| Safe wrapper for Wolfe Waves Short check                         |
//+------------------------------------------------------------------+
int SafeCheckWolfeWavesShort(MqlRates &rates[])
{
    // Use the int-returning version
    return CheckWolfeWavesShort(rates);
}