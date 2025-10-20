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
    if(size < 50)
        return false;
    
    // Finding the 5 points needed for the Wolfe pattern
    // Point 1 (local low)
    // Point 2 (local high after point 1)
    // Point 3 (local low after point 2)
    // Point 4 (local high after point 3)
    // Point 5 (local low after point 4)
    
    int points[5] = {0};   // Points 1 to 5 of the pattern
    double values[5] = {0}; // Price values at points 1 to 5
    
    // Finding point 1 (local low)
    for(int i = 49; i > 40; i--) {
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low) {
            points[0] = i;
            values[0] = rates[i].low;
            break;
        }
    }
    
    if(points[0] == 0)
        return false;
    
    // Finding point 2 (local high after point 1)
    for(int i = points[0] - 1; i > 30; i--) {
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high) {
            points[1] = i;
            values[1] = rates[i].high;
            break;
        }
    }
    
    if(points[1] == 0 || points[1] >= points[0])
        return false;
    
    // Finding point 3 (local low after point 2)
    for(int i = points[1] - 1; i > 20; i--) {
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low) {
            points[2] = i;
            values[2] = rates[i].low;
            break;
        }
    }
    
    if(points[2] == 0 || points[2] >= points[1])
        return false;
    
    // Finding point 4 (local high after point 3)
    for(int i = points[2] - 1; i > 10; i--) {
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high) {
            points[3] = i;
            values[3] = rates[i].high;
            break;
        }
    }
    
    if(points[3] == 0 || points[3] >= points[2])
        return false;
    
    // Finding point 5 (local low after point 4)
    for(int i = points[3] - 1; i >= 0; i--) {
        if(i == 0 || (rates[i].low < rates[i+1].low && i > 0 && rates[i].low < rates[i-1].low)) {
            points[4] = i;
            values[4] = rates[i].low;
            break;
        }
    }
    
    if(points[4] == 0 && points[4] != 0) // If point 5 is not found but the other points are
        return false;
    
    // Checking conditions for the bullish Wolfe pattern
    
    // Condition 1: Points 1-3-5 must be aligned (trend line)
    double slope_1_3 = (values[2] - values[0]) / (points[0] - points[2]);
    double expected_point5 = values[0] + slope_1_3 * (points[0] - points[4]);
    double tolerance = MathAbs(values[0] - values[2]) * 0.1; // 10% tolerance
    
    if(MathAbs(values[4] - expected_point5) > tolerance)
        return false;
    
    // Condition 2: Points 2-4 must be aligned (channel line)
    double slope_2_4 = (values[3] - values[1]) / (points[1] - points[3]);
    
    // Condition 3: Point 4 must be lower than point 2 (downward trend)
    if(values[3] >= values[1])
        return false;
    
    // Condition 4: Point 3 must be higher than point 1 (otherwise it's a reverse pattern)
    if(values[2] <= values[0])
        return false;
    
    // Condition 5: The time between points must decrease (1→2 > 2→3 > 3→4 > 4→5)
    int time_1_2 = points[0] - points[1];
    int time_2_3 = points[1] - points[2];
    int time_3_4 = points[2] - points[3];
    int time_4_5 = points[3] - points[4];
    
    if(!(time_1_2 > time_2_3 && time_2_3 > time_3_4 && time_3_4 > time_4_5))
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
    if(size < 50)
        return false;
    
    // Finding the 5 points needed for the Wolfe pattern
    // Point 1 (local high)
    // Point 2 (local low after point 1)
    // Point 3 (local high after point 2)
    // Point 4 (local low after point 3)
    // Point 5 (local high after point 4)
    
    int points[5] = {0};   // Points 1 to 5 of the pattern
    double values[5] = {0}; // Price values at points 1 to 5
    
    // Finding point 1 (local high)
    for(int i = 49; i > 40; i--) {
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high) {
            points[0] = i;
            values[0] = rates[i].high;
            break;
        }
    }
    
    if(points[0] == 0)
        return false;
    
    // Finding point 2 (local low after point 1)
    for(int i = points[0] - 1; i > 30; i--) {
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low) {
            points[1] = i;
            values[1] = rates[i].low;
            break;
        }
    }
    
    if(points[1] == 0 || points[1] >= points[0])
        return false;
    
    // Finding point 3 (local high after point 2)
    for(int i = points[1] - 1; i > 20; i--) {
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high) {
            points[2] = i;
            values[2] = rates[i].high;
            break;
        }
    }
    
    if(points[2] == 0 || points[2] >= points[1])
        return false;
    
    // Finding point 4 (local low after point 3)
    for(int i = points[2] - 1; i > 10; i--) {
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low) {
            points[3] = i;
            values[3] = rates[i].low;
            break;
        }
    }
    
    if(points[3] == 0 || points[3] >= points[2])
        return false;
    
    // Finding point 5 (local high after point 4)
    for(int i = points[3] - 1; i >= 0; i--) {
        if(i == 0 || (rates[i].high > rates[i+1].high && i > 0 && rates[i].high > rates[i-1].high)) {
            points[4] = i;
            values[4] = rates[i].high;
            break;
        }
    }
    
    if(points[4] == 0 && points[4] != 0) // If point 5 is not found but the other points are
        return false;
    
    // Checking conditions for the bearish Wolfe pattern
    
    // Condition 1: Points 1-3-5 must be aligned (trend line)
    double slope_1_3 = (values[2] - values[0]) / (points[0] - points[2]);
    double expected_point5 = values[0] + slope_1_3 * (points[0] - points[4]);
    double tolerance = MathAbs(values[0] - values[2]) * 0.1; // 10% tolerance
    
    if(MathAbs(values[4] - expected_point5) > tolerance)
        return false;
    
    // Condition 2: Points 2-4 must be aligned (channel line)
    double slope_2_4 = (values[3] - values[1]) / (points[1] - points[3]);
    
    // Condition 3: Point 4 must be lower than point 2 (downward trend)
    if(values[3] <= values[1])
        return false;
    
    // Condition 4: Point 3 must be higher than point 1 (otherwise it's a reverse pattern)
    if(values[2] >= values[0])
        return false;
    
    // Condition 5: The time between points must decrease (1→2 > 2→3 > 3→4 > 4→5)
    int time_1_2 = points[0] - points[1];
    int time_2_3 = points[1] - points[2];
    int time_3_4 = points[2] - points[3];
    int time_4_5 = points[3] - points[4];
    
    if(!(time_1_2 > time_2_3 && time_2_3 > time_3_4 && time_3_4 > time_4_5))
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
    if(size < 50) {
        DebugPrint("The rates array for CheckWolfeWavesBuy is smaller than the required size: " + IntegerToString(size));
        
        // If the array is too small, try to get more data
        MqlRates local_rates[];
        ArraySetAsSeries(local_rates, true);
        int copied = CopyRates(Symbol(), WW_Timeframe, 0, 100, local_rates);
        
        if(copied < 50) {
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
    if(size < 50) {
        DebugPrint("The rates array for CheckWolfeWavesShort is smaller than the required size: " + IntegerToString(size));
        
        // If the array is too small, try to get more data
        MqlRates local_rates[];
        ArraySetAsSeries(local_rates, true);
        int copied = CopyRates(Symbol(), WW_Timeframe, 0, 100, local_rates);
        
        if(copied < 50) {
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

// Function to check for bullish Wolfe Wave pattern
bool CheckWolfeWavesBuy(const MqlRates &rates[], int size)
{
    // Need at least 30 bars to identify the pattern
    if (size < 30)
        return false;
        
    // Points for the Wolfe Wave pattern (numbered 1-5)
    int point1 = -1, point2 = -1, point3 = -1, point4 = -1, point5 = -1;
    
    // Find potential points by looking for significant pivots
    // Start from the most recent bar (excluding current bar) and look back
    
    // Find point 5 (most recent low)
    for (int i = 1; i < 15 && i < size - 1; i++)
    {
        // Check if this is a local low
        if (rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
        {
            point5 = i;
            break;
        }
    }
    
    if (point5 == -1)
        return false;
    
    // Find point 4 (high before point 5)
    for (int i = point5 + 1; i < point5 + 15 && i < size - 1; i++)
    {
        // Check if this is a local high
        if (rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
        {
            point4 = i;
            break;
        }
    }
    
    if (point4 == -1)
        return false;
    
    // Find point 3 (low before point 4)
    for (int i = point4 + 1; i < point4 + 15 && i < size - 1; i++)
    {
        // Check if this is a local low
        if (rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
        {
            point3 = i;
            break;
        }
    }
    
    if (point3 == -1)
        return false;
    
    // Find point 2 (high before point 3)
    for (int i = point3 + 1; i < point3 + 15 && i < size - 1; i++)
    {
        // Check if this is a local high
        if (rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
        {
            point2 = i;
            break;
        }
    }
    
    if (point2 == -1)
        return false;
    
    // Find point 1 (low before point 2)
    for (int i = point2 + 1; i < point2 + 15 && i < size - 1; i++)
    {
        // Check if this is a local low
        if (rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
        {
            point1 = i;
            break;
        }
    }
    
    if (point1 == -1)
        return false;
    
    // Check Wolfe Wave Pattern Rules:
    
    // 1. Points 1-2-3-4 should form a converging channel (triangular)
    double slope12 = (rates[point2].high - rates[point1].low) / (point2 - point1);
    double slope34 = (rates[point4].high - rates[point3].low) / (point4 - point3);
    
    // Check if lines are converging
    if (slope12 <= slope34)
        return false;
    
    // 2. Point 5 should break below the 3-1 trendline
    double trendline31Value = rates[point3].low - ((point5 - point3) * (rates[point1].low - rates[point3].low) / (point1 - point3));
    
    if (rates[point5].low > trendline31Value)
        return false;
    
    // 3. The time between points 3-5 should approximately equal 1-3
    double timeRatio = (double)(point3 - point5) / (point1 - point3);
    if (timeRatio < 0.5 || timeRatio > 2.0)
        return false;
    
    // 4. Current price should be above point 5, indicating a reversal
    if (rates[0].close <= rates[point5].low)
        return false;
    
    // Check if price has moved a certain percentage above point 5
    double minMove = 0.3 * (rates[point4].high - rates[point5].low);
    if (rates[0].close < rates[point5].low + minMove)
        return false;
    
    // All conditions met, bullish Wolfe Wave pattern is confirmed
    return true;
}

// Function to check for bearish Wolfe Wave pattern
bool CheckWolfeWavesShort(const MqlRates &rates[], int size)
{
    // Need at least 30 bars to identify the pattern
    if (size < 30)
        return false;
        
    // Points for the Wolfe Wave pattern (numbered 1-5)
    int point1 = -1, point2 = -1, point3 = -1, point4 = -1, point5 = -1;
    
    // Find potential points by looking for significant pivots
    // Start from the most recent bar (excluding current bar) and look back
    
    // Find point 5 (most recent high)
    for (int i = 1; i < 15 && i < size - 1; i++)
    {
        // Check if this is a local high
        if (rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
        {
            point5 = i;
            break;
        }
    }
    
    if (point5 == -1)
        return false;
    
    // Find point 4 (low before point 5)
    for (int i = point5 + 1; i < point5 + 15 && i < size - 1; i++)
    {
        // Check if this is a local low
        if (rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
        {
            point4 = i;
            break;
        }
    }
    
    if (point4 == -1)
        return false;
    
    // Find point 3 (high before point 4)
    for (int i = point4 + 1; i < point4 + 15 && i < size - 1; i++)
    {
        // Check if this is a local high
        if (rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
        {
            point3 = i;
            break;
        }
    }
    
    if (point3 == -1)
        return false;
    
    // Find point 2 (low before point 3)
    for (int i = point3 + 1; i < point3 + 15 && i < size - 1; i++)
    {
        // Check if this is a local low
        if (rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
        {
            point2 = i;
            break;
        }
    }
    
    if (point2 == -1)
        return false;
    
    // Find point 1 (high before point 2)
    for (int i = point2 + 1; i < point2 + 15 && i < size - 1; i++)
    {
        // Check if this is a local high
        if (rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
        {
            point1 = i;
            break;
        }
    }
    
    if (point1 == -1)
        return false;
    
    // Check Wolfe Wave Pattern Rules:
    
    // 1. Points 1-2-3-4 should form a converging channel (triangular)
    double slope12 = (rates[point1].high - rates[point2].low) / (point1 - point2);
    double slope34 = (rates[point3].high - rates[point4].low) / (point3 - point4);
    
    // Check if lines are converging
    if (slope12 <= slope34)
        return false;
    
    // 2. Point 5 should break above the 3-1 trendline
    double trendline31Value = rates[point3].high + ((point5 - point3) * (rates[point1].high - rates[point3].high) / (point1 - point3));
    
    if (rates[point5].high < trendline31Value)
        return false;
    
    // 3. The time between points 3-5 should approximately equal 1-3
    double timeRatio = (double)(point3 - point5) / (point1 - point3);
    if (timeRatio < 0.5 || timeRatio > 2.0)
        return false;
    
    // 4. Current price should be below point 5, indicating a reversal
    if (rates[0].close >= rates[point5].high)
        return false;
    
    // Check if price has moved a certain percentage below point 5
    double minMove = 0.3 * (rates[point5].high - rates[point4].low);
    if (rates[0].close > rates[point5].high - minMove)
        return false;
    
    // All conditions met, bearish Wolfe Wave pattern is confirmed
    return true;
} 