//+------------------------------------------------------------------+
//|                                             HarmonicPatterns.mqh |
//|                                      Copyright 2023, Gold Trader   |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Declare external variables needed
extern ENUM_TIMEFRAMES HP_Timeframe;
extern bool is_backtest;

// Fibonacci constants
#define GARTLEY_POINT_B_RETRACEMENT  0.618  // Fibonacci ratio for point B in the Gartley pattern
#define GARTLEY_POINT_C_EXTENSION    0.382  // Fibonacci ratio for point C in the Gartley pattern
#define GARTLEY_POINT_D_RETRACEMENT  0.786  // Fibonacci ratio for point D in the Gartley pattern

#define BUTTERFLY_POINT_B_RETRACEMENT 0.786 // Fibonacci ratio for point B in the Butterfly pattern
#define BUTTERFLY_POINT_C_EXTENSION   1.618 // Fibonacci ratio for point C in the Butterfly pattern
#define BUTTERFLY_POINT_D_EXTENSION   1.272 // Fibonacci ratio for point D in the Butterfly pattern

#define BAT_POINT_B_RETRACEMENT      0.382 // Fibonacci ratio for point B in the Bat pattern
#define BAT_POINT_C_RETRACEMENT      0.886 // Fibonacci ratio for point C in the Bat pattern
#define BAT_POINT_D_EXTENSION        1.618 // Fibonacci ratio for point D in the Bat pattern

#define TOLERANCE_LEVEL 0.03 // Tolerance level for pattern detection (3 percent)

// DebugPrint and CheckArrayAccess functions must be defined in the main file
#import "GoldTraderEA_cleaned.mq5"
   void DebugPrint(string message);
   bool CheckArrayAccess(int index, int array_size, string function_name);
#import

//+------------------------------------------------------------------+
//| Safely check harmonic patterns for buy                            |
//+------------------------------------------------------------------+
int SafeCheckHarmonicPatternsBuy(MqlRates &rates[])
{
    int result = 0;
    int size = ArraySize(rates);
    
    // Check array size
    int min_size = is_backtest ? 20 : 40;
    if(size < min_size) {
        DebugPrint("The rates array for SafeCheckHarmonicPatternsBuy is smaller than the required size: " + 
                  IntegerToString(size) + " < " + IntegerToString(min_size));
        return 0;
    }
    
    // In backtest mode, if harmonic patterns are activated, return a value
    // To ensure we don't get an out of range error
    if(is_backtest && size < 40) {
        DebugPrint("In backtest mode with low candle count, we safely check harmonic patterns");
        return 0;
    }
    
    // Main call with error protection
    ResetLastError();
    
    // Execute function with error protection
    result = CheckHarmonicPatternsBuy(rates);
    
    // Check error
    int error = GetLastError();
    if(error != 0) {
        DebugPrint("Error executing CheckHarmonicPatternsBuy: " + IntegerToString(error));
        return 0;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Safely check harmonic patterns for sell                            |
//+------------------------------------------------------------------+
int SafeCheckHarmonicPatternsShort(MqlRates &rates[])
{
    int result = 0;
    int size = ArraySize(rates);
    
    // Check array size
    int min_size = is_backtest ? 20 : 40;
    if(size < min_size) {
        DebugPrint("The rates array for SafeCheckHarmonicPatternsShort is smaller than the required size: " + 
                  IntegerToString(size) + " < " + IntegerToString(min_size));
        return 0;
    }
    
    // In backtest mode, if harmonic patterns are activated, return a value
    // To ensure we don't get an out of range error
    if(is_backtest && size < 40) {
        DebugPrint("In backtest mode with low candle count, we safely check harmonic patterns");
        return 0;
    }
    
    // Main call with error protection
    ResetLastError();
    
    // Execute function with error protection
    result = CheckHarmonicPatternsShort(rates);
    
    // Check error
    int error = GetLastError();
    if(error != 0) {
        DebugPrint("Error executing CheckHarmonicPatternsShort: " + IntegerToString(error));
        return 0;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Check harmonic patterns for buy                                   |
//+------------------------------------------------------------------+
int CheckHarmonicPatternsBuy(MqlRates &rates[])
{
    DebugPrint("Starting to check harmonic patterns for buy");
    
    int confirmations = 0;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 40) {
        DebugPrint("The rates array for CheckHarmonicPatternsBuy is smaller than the required size: " + IntegerToString(size));
        return 0;
    }
    
    DebugPrint("Number of candles received for CheckHarmonicPatternsBuy: " + IntegerToString(size));
    
    // Check bullish Gartley pattern
    ResetLastError();
    if(IsBullishGartley(rates)) {
        DebugPrint("Bullish Gartley pattern detected");
        confirmations++;
    }
    
    // Check bullish Butterfly pattern
    ResetLastError();
    if(IsBullishButterfly(rates)) {
        DebugPrint("Bullish Butterfly pattern detected");
        confirmations++;
    }
    
    // Check bullish Bat pattern
    ResetLastError();
    if(IsBullishBat(rates)) {
        DebugPrint("Bullish Bat pattern detected");
        confirmations++;
    }
    
    DebugPrint("Number of confirmations for harmonic patterns for buy: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Check harmonic patterns for sell                                  |
//+------------------------------------------------------------------+
int CheckHarmonicPatternsShort(MqlRates &rates[])
{
    DebugPrint("Starting to check harmonic patterns for sell");
    
    int confirmations = 0;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 40) {
        DebugPrint("The rates array for CheckHarmonicPatternsShort is smaller than the required size: " + IntegerToString(size));
        return 0;
    }
    
    DebugPrint("Number of candles received for CheckHarmonicPatternsShort: " + IntegerToString(size));
    
    // Check bearish Gartley pattern
    ResetLastError();
    if(IsBearishGartley(rates)) {
        DebugPrint("Bearish Gartley pattern detected");
        confirmations++;
    }
    
    // Check bearish Butterfly pattern
    ResetLastError();
    if(IsBearishButterfly(rates)) {
        DebugPrint("Bearish Butterfly pattern detected");
        confirmations++;
    }
    
    // Check bearish Bat pattern
    ResetLastError();
    if(IsBearishBat(rates)) {
        DebugPrint("Bearish Bat pattern detected");
        confirmations++;
    }
    
    DebugPrint("Number of confirmations for harmonic patterns for sell: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Find XABCD points for harmonic patterns                           |
//+------------------------------------------------------------------+
bool FindXABCDPoints(MqlRates &rates[], int &xIndex, int &aIndex, int &bIndex, int &cIndex, int &dIndex, bool isBullish)
{
    int size = ArraySize(rates);
    if(size < 40) return false;
    
    // Find important pivot points in the last 40 candles
    int pivotIndices[10];
    double pivotValues[10];
    int pivotCount = 0;
    
    // For bullish pattern, look for lows and for bearish pattern, look for highs
    if(isBullish) {
        // Find important lows
        for(int i = 39; i > 1 && pivotCount < 10; i--) {
            if(!CheckArrayAccess(i, size, "FindXABCDPoints") || 
               !CheckArrayAccess(i+1, size, "FindXABCDPoints") || 
               !CheckArrayAccess(i-1, size, "FindXABCDPoints"))
                continue;
            
            if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low) {
                pivotIndices[pivotCount] = i;
                pivotValues[pivotCount] = rates[i].low;
                pivotCount++;
            }
        }
    } else {
        // Find important highs
        for(int i = 39; i > 1 && pivotCount < 10; i--) {
            if(!CheckArrayAccess(i, size, "FindXABCDPoints") || 
               !CheckArrayAccess(i+1, size, "FindXABCDPoints") || 
               !CheckArrayAccess(i-1, size, "FindXABCDPoints"))
                continue;
            
            if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high) {
                pivotIndices[pivotCount] = i;
                pivotValues[pivotCount] = rates[i].high;
                pivotCount++;
            }
        }
    }
    
    // At least 5 pivot points are needed (X, A, B, C, D)
    if(pivotCount < 5) return false;
    
    // Determine XABCD points
    dIndex = pivotIndices[0]; // most recent point
    cIndex = pivotIndices[1];
    bIndex = pivotIndices[2];
    aIndex = pivotIndices[3];
    xIndex = pivotIndices[4];
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect bullish Gartley pattern                                    |
//+------------------------------------------------------------------+
bool IsBullishGartley(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 40) return false;
    
    int xIndex, aIndex, bIndex, cIndex, dIndex;
    if(!FindXABCDPoints(rates, xIndex, aIndex, bIndex, cIndex, dIndex, true))
        return false;
    
    // Extract price points
    double xPoint = rates[xIndex].low;
    double aPoint = rates[aIndex].high;
    double bPoint = rates[bIndex].low;
    double cPoint = rates[cIndex].high;
    double dPoint = rates[dIndex].low;
    
    // Calculate absolute movements
    double xaMove = aPoint - xPoint;
    double abMove = aPoint - bPoint;
    double bcMove = cPoint - bPoint;
    double cdMove = cPoint - dPoint;
    double xdMove = dPoint - xPoint;
    
    // Calculate Fibonacci ratios
    double abRatio = abMove / xaMove;                  // Ratio of AB to XA (should be approximately 0.618)
    double bcRatio = bcMove / abMove;                  // Ratio of BC to AB (should be approximately 0.382)
    double cdRatio = cdMove / bcMove;                  // Ratio of CD to BC (should be approximately 0.786)
    
    // Time sequence must be correct
    if(!(xIndex > aIndex && aIndex > bIndex && bIndex > cIndex && cIndex > dIndex))
        return false;
    
    // Check Fibonacci ratios with tolerance
    bool validAB = MathAbs(abRatio - GARTLEY_POINT_B_RETRACEMENT) <= TOLERANCE_LEVEL;
    bool validBC = MathAbs(bcRatio - GARTLEY_POINT_C_EXTENSION) <= TOLERANCE_LEVEL;
    bool validCD = MathAbs(cdRatio - GARTLEY_POINT_D_RETRACEMENT) <= TOLERANCE_LEVEL;
    
    // For bullish pattern, point D should be approximately at level of point X
    bool validXD = MathAbs(dPoint - xPoint) <= TOLERANCE_LEVEL * xaMove;
    
    if(validAB && validBC && validCD && validXD) {
        DebugPrint("Bullish Gartley pattern: XA=" + DoubleToString(xaMove, 2) + 
                   ", AB Ratio=" + DoubleToString(abRatio, 3) + 
                   ", BC Ratio=" + DoubleToString(bcRatio, 3) + 
                   ", CD Ratio=" + DoubleToString(cdRatio, 3));
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Other harmonic pattern detection functions (IsBearishGartley, IsBullishButterfly, ...) |
//+------------------------------------------------------------------+
bool IsBearishGartley(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 40) return false;
    
    int xIndex, aIndex, bIndex, cIndex, dIndex;
    if(!FindXABCDPoints(rates, xIndex, aIndex, bIndex, cIndex, dIndex, false))
        return false;
    
    // Extract price points
    double xPoint = rates[xIndex].high;
    double aPoint = rates[aIndex].low;
    double bPoint = rates[bIndex].high;
    double cPoint = rates[cIndex].low;
    double dPoint = rates[dIndex].high;
    
    // Calculate absolute movements
    double xaMove = xPoint - aPoint;
    double abMove = bPoint - aPoint;
    double bcMove = bPoint - cPoint;
    double cdMove = dPoint - cPoint;
    double xdMove = xPoint - dPoint;
    
    // Calculate Fibonacci ratios
    double abRatio = abMove / xaMove;                  // Ratio of AB to XA (should be approximately 0.618)
    double bcRatio = bcMove / abMove;                  // Ratio of BC to AB (should be approximately 0.382)
    double cdRatio = cdMove / bcMove;                  // Ratio of CD to BC (should be approximately 0.786)
    
    // Time sequence must be correct
    if(!(xIndex > aIndex && aIndex > bIndex && bIndex > cIndex && cIndex > dIndex))
        return false;
    
    // Check Fibonacci ratios with tolerance
    bool validAB = MathAbs(abRatio - GARTLEY_POINT_B_RETRACEMENT) <= TOLERANCE_LEVEL;
    bool validBC = MathAbs(bcRatio - GARTLEY_POINT_C_EXTENSION) <= TOLERANCE_LEVEL;
    bool validCD = MathAbs(cdRatio - GARTLEY_POINT_D_RETRACEMENT) <= TOLERANCE_LEVEL;
    
    // For bearish pattern, point D should be approximately at level of point X
    bool validXD = MathAbs(dPoint - xPoint) <= TOLERANCE_LEVEL * xaMove;
    
    if(validAB && validBC && validCD && validXD) {
        DebugPrint("Bearish Gartley pattern: XA=" + DoubleToString(xaMove, 2) + 
                   ", AB Ratio=" + DoubleToString(abRatio, 3) + 
                   ", BC Ratio=" + DoubleToString(bcRatio, 3) + 
                   ", CD Ratio=" + DoubleToString(cdRatio, 3));
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect bullish Butterfly pattern                                  |
//+------------------------------------------------------------------+
bool IsBullishButterfly(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 40) return false;
    
    int xIndex, aIndex, bIndex, cIndex, dIndex;
    if(!FindXABCDPoints(rates, xIndex, aIndex, bIndex, cIndex, dIndex, true))
        return false;
    
    // Extract price points
    double xPoint = rates[xIndex].low;
    double aPoint = rates[aIndex].high;
    double bPoint = rates[bIndex].low;
    double cPoint = rates[cIndex].high;
    double dPoint = rates[dIndex].low;
    
    // Calculate absolute movements
    double xaMove = aPoint - xPoint;
    double abMove = aPoint - bPoint;
    double bcMove = cPoint - bPoint;
    double cdMove = cPoint - dPoint;
    double xdMove = dPoint - xPoint; // Compare D with X
    
    // Calculate Fibonacci ratios
    double abRatio = abMove / xaMove;                  // Ratio of AB to XA (should be approximately 0.786)
    double bcRatio = bcMove / abMove;                  // Ratio of BC to AB (should be approximately 1.618)
    double cdRatio = cdMove / bcMove;                  // Ratio of CD to BC (should be approximately 1.272)
    double xdRatio = xdMove / xaMove;                  // D should be beyond X
    
    // Time sequence must be correct
    if(!(xIndex > aIndex && aIndex > bIndex && bIndex > cIndex && cIndex > dIndex))
        return false;
    
    // Check Fibonacci ratios with tolerance
    bool validAB = MathAbs(abRatio - BUTTERFLY_POINT_B_RETRACEMENT) <= TOLERANCE_LEVEL;
    bool validBC = MathAbs(bcRatio - BUTTERFLY_POINT_C_EXTENSION) <= TOLERANCE_LEVEL;
    bool validCD = MathAbs(cdRatio - BUTTERFLY_POINT_D_EXTENSION) <= TOLERANCE_LEVEL;
    
    // For Butterfly pattern, point D should be beyond X
    bool validXD = dPoint < xPoint;
    
    if(validAB && validBC && validCD && validXD) {
        DebugPrint("Bullish Butterfly pattern: XA=" + DoubleToString(xaMove, 2) + 
                   ", AB Ratio=" + DoubleToString(abRatio, 3) + 
                   ", BC Ratio=" + DoubleToString(bcRatio, 3) + 
                   ", CD Ratio=" + DoubleToString(cdRatio, 3));
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect bearish Butterfly pattern                                  |
//+------------------------------------------------------------------+
bool IsBearishButterfly(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 40) return false;
    
    int xIndex, aIndex, bIndex, cIndex, dIndex;
    if(!FindXABCDPoints(rates, xIndex, aIndex, bIndex, cIndex, dIndex, false))
        return false;
    
    // Extract price points
    double xPoint = rates[xIndex].high;
    double aPoint = rates[aIndex].low;
    double bPoint = rates[bIndex].high;
    double cPoint = rates[cIndex].low;
    double dPoint = rates[dIndex].high;
    
    // Calculate absolute movements
    double xaMove = xPoint - aPoint;
    double abMove = bPoint - aPoint;
    double bcMove = bPoint - cPoint;
    double cdMove = dPoint - cPoint;
    double xdMove = dPoint - xPoint; // Compare D with X
    
    // Calculate Fibonacci ratios
    double abRatio = abMove / xaMove;                  // Ratio of AB to XA (should be approximately 0.786)
    double bcRatio = bcMove / abMove;                  // Ratio of BC to AB (should be approximately 1.618)
    double cdRatio = cdMove / bcMove;                  // Ratio of CD to BC (should be approximately 1.272)
    double xdRatio = xdMove / xaMove;                  // D should be beyond X
    
    // Time sequence must be correct
    if(!(xIndex > aIndex && aIndex > bIndex && bIndex > cIndex && cIndex > dIndex))
        return false;
    
    // Check Fibonacci ratios with tolerance
    bool validAB = MathAbs(abRatio - BUTTERFLY_POINT_B_RETRACEMENT) <= TOLERANCE_LEVEL;
    bool validBC = MathAbs(bcRatio - BUTTERFLY_POINT_C_EXTENSION) <= TOLERANCE_LEVEL;
    bool validCD = MathAbs(cdRatio - BUTTERFLY_POINT_D_EXTENSION) <= TOLERANCE_LEVEL;
    
    // For Butterfly pattern, point D should be beyond X
    bool validXD = dPoint > xPoint;
    
    if(validAB && validBC && validCD && validXD) {
        DebugPrint("Bearish Butterfly pattern: XA=" + DoubleToString(xaMove, 2) + 
                   ", AB Ratio=" + DoubleToString(abRatio, 3) + 
                   ", BC Ratio=" + DoubleToString(bcRatio, 3) + 
                   ", CD Ratio=" + DoubleToString(cdRatio, 3));
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect bullish Bat pattern                                       |
//+------------------------------------------------------------------+
bool IsBullishBat(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 40) return false;
    
    int xIndex, aIndex, bIndex, cIndex, dIndex;
    if(!FindXABCDPoints(rates, xIndex, aIndex, bIndex, cIndex, dIndex, true))
        return false;
    
    // Extract price points
    double xPoint = rates[xIndex].low;
    double aPoint = rates[aIndex].high;
    double bPoint = rates[bIndex].low;
    double cPoint = rates[cIndex].high;
    double dPoint = rates[dIndex].low;
    
    // Calculate absolute movements
    double xaMove = aPoint - xPoint;
    double abMove = aPoint - bPoint;
    double bcMove = cPoint - bPoint;
    double cdMove = cPoint - dPoint;
    
    // Calculate Fibonacci ratios
    double abRatio = abMove / xaMove;                  // Ratio of AB to XA (should be approximately 0.382)
    double bcRatio = bcMove / abMove;                  // Ratio of BC to AB (should be approximately 0.886)
    double cdRatio = cdMove / bcMove;                  // Ratio of CD to BC (should be approximately 1.618)
    
    // Time sequence must be correct
    if(!(xIndex > aIndex && aIndex > bIndex && bIndex > cIndex && cIndex > dIndex))
        return false;
    
    // Check Fibonacci ratios with tolerance
    bool validAB = MathAbs(abRatio - BAT_POINT_B_RETRACEMENT) <= TOLERANCE_LEVEL;
    bool validBC = MathAbs(bcRatio - BAT_POINT_C_RETRACEMENT) <= TOLERANCE_LEVEL;
    bool validCD = MathAbs(cdRatio - BAT_POINT_D_EXTENSION) <= TOLERANCE_LEVEL;
    
    // For Bat pattern, point D should be slightly beyond X but not excessively
    bool validXD = dPoint < xPoint && MathAbs(dPoint - xPoint) <= 0.2 * xaMove;
    
    if(validAB && validBC && validCD && validXD) {
        DebugPrint("Bullish Bat pattern: XA=" + DoubleToString(xaMove, 2) + 
                   ", AB Ratio=" + DoubleToString(abRatio, 3) + 
                   ", BC Ratio=" + DoubleToString(bcRatio, 3) + 
                   ", CD Ratio=" + DoubleToString(cdRatio, 3));
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect bearish Bat pattern                                       |
//+------------------------------------------------------------------+
bool IsBearishBat(MqlRates &rates[])
{
    int size = ArraySize(rates);
    if(size < 40) return false;
    
    int xIndex, aIndex, bIndex, cIndex, dIndex;
    if(!FindXABCDPoints(rates, xIndex, aIndex, bIndex, cIndex, dIndex, false))
        return false;
    
    // Extract price points
    double xPoint = rates[xIndex].high;
    double aPoint = rates[aIndex].low;
    double bPoint = rates[bIndex].high;
    double cPoint = rates[cIndex].low;
    double dPoint = rates[dIndex].high;
    
    // Calculate absolute movements
    double xaMove = xPoint - aPoint;
    double abMove = bPoint - aPoint;
    double bcMove = bPoint - cPoint;
    double cdMove = dPoint - cPoint;
    
    // Calculate Fibonacci ratios
    double abRatio = abMove / xaMove;                  // Ratio of AB to XA (should be approximately 0.382)
    double bcRatio = bcMove / abMove;                  // Ratio of BC to AB (should be approximately 0.886)
    double cdRatio = cdMove / bcMove;                  // Ratio of CD to BC (should be approximately 1.618)
    
    // Time sequence must be correct
    if(!(xIndex > aIndex && aIndex > bIndex && bIndex > cIndex && cIndex > dIndex))
        return false;
    
    // Check Fibonacci ratios with tolerance
    bool validAB = MathAbs(abRatio - BAT_POINT_B_RETRACEMENT) <= TOLERANCE_LEVEL;
    bool validBC = MathAbs(bcRatio - BAT_POINT_C_RETRACEMENT) <= TOLERANCE_LEVEL;
    bool validCD = MathAbs(cdRatio - BAT_POINT_D_EXTENSION) <= TOLERANCE_LEVEL;
    
    // For Bat pattern, point D should be slightly beyond X but not excessively
    bool validXD = dPoint > xPoint && MathAbs(dPoint - xPoint) <= 0.2 * xaMove;
    
    if(validAB && validBC && validCD && validXD) {
        DebugPrint("Bearish Bat pattern: XA=" + DoubleToString(xaMove, 2) + 
                   ", AB Ratio=" + DoubleToString(abRatio, 3) + 
                   ", BC Ratio=" + DoubleToString(bcRatio, 3) + 
                   ", CD Ratio=" + DoubleToString(cdRatio, 3));
        return true;
    }
    
    return false;
} 