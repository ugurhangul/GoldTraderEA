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

// Fibonacci constants for Gartley pattern
#define GARTLEY_POINT_B_RETRACEMENT  0.618  // B is 0.618 retracement of XA
#define GARTLEY_POINT_C_MIN          0.382  // C is 0.382-0.886 retracement of AB
#define GARTLEY_POINT_C_MAX          0.886
#define GARTLEY_POINT_D_RETRACEMENT  0.786  // D is 0.786 retracement of XA

// Fibonacci constants for Butterfly pattern
#define BUTTERFLY_POINT_B_RETRACEMENT 0.786 // B is 0.786 retracement of XA
#define BUTTERFLY_POINT_C_MIN         0.382 // C is 0.382-0.886 retracement of AB
#define BUTTERFLY_POINT_C_MAX         0.886
#define BUTTERFLY_POINT_D_MIN         1.272 // D is 1.272 or 1.618 extension of XA
#define BUTTERFLY_POINT_D_MAX         1.618

// Fibonacci constants for Bat pattern
#define BAT_POINT_B_MIN              0.382  // B is 0.382-0.500 retracement of XA
#define BAT_POINT_B_MAX              0.500
#define BAT_POINT_C_MIN              0.382  // C is 0.382-0.886 retracement of AB
#define BAT_POINT_C_MAX              0.886
#define BAT_POINT_D_RETRACEMENT      0.886  // D is 0.886 retracement of XA

// FIXED: Increased tolerance from 2% to 5% for more flexible pattern detection
#define TOLERANCE_LEVEL 0.05 // Tolerance level for pattern detection (5 percent)

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
    
    // FIXED: Reduced minimum bars from 40 to 25 for earlier signal generation
    // Check array size
    int min_size = is_backtest ? 20 : 25;
    if(size < min_size) {
        DebugPrint("The rates array for SafeCheckHarmonicPatternsBuy is smaller than the required size: " +
                  IntegerToString(size) + " < " + IntegerToString(min_size));
        return 0;
    }

    // In backtest mode, if harmonic patterns are activated, return a value
    // To ensure we don't get an out of range error
    if(is_backtest && size < 25) {
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

    // Find important pivot points in the last 40 candles with improved detection
    int pivotIndices[20];
    double pivotValues[20];
    bool pivotIsLow[20];  // Track if pivot is a low or high
    int pivotCount = 0;

    // Improved pivot detection - look for swing highs and lows with 2-bar confirmation
    for(int i = 39; i > 2 && pivotCount < 20; i--) {
        if(!CheckArrayAccess(i, size, "FindXABCDPoints") ||
           !CheckArrayAccess(i+1, size, "FindXABCDPoints") ||
           !CheckArrayAccess(i+2, size, "FindXABCDPoints") ||
           !CheckArrayAccess(i-1, size, "FindXABCDPoints") ||
           !CheckArrayAccess(i-2, size, "FindXABCDPoints"))
            continue;

        // Check for swing low (lower than 2 bars on each side)
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low &&
           rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low) {
            pivotIndices[pivotCount] = i;
            pivotValues[pivotCount] = rates[i].low;
            pivotIsLow[pivotCount] = true;
            pivotCount++;
        }
        // Check for swing high (higher than 2 bars on each side)
        else if(rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high &&
                rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high) {
            pivotIndices[pivotCount] = i;
            pivotValues[pivotCount] = rates[i].high;
            pivotIsLow[pivotCount] = false;
            pivotCount++;
        }
    }

    // Need at least 5 pivot points
    if(pivotCount < 5) return false;

    // Find valid XABCD sequence with alternating highs and lows
    for(int start = 0; start <= pivotCount - 5; start++) {
        // For bullish pattern: X=low, A=high, B=low, C=high, D=low
        // For bearish pattern: X=high, A=low, B=high, C=low, D=high

        bool validSequence = true;
        if(isBullish) {
            // Check alternating pattern: low-high-low-high-low
            if(!pivotIsLow[start] || pivotIsLow[start+1] || !pivotIsLow[start+2] ||
               pivotIsLow[start+3] || !pivotIsLow[start+4]) {
                validSequence = false;
            }
        } else {
            // Check alternating pattern: high-low-high-low-high
            if(pivotIsLow[start] || !pivotIsLow[start+1] || pivotIsLow[start+2] ||
               !pivotIsLow[start+3] || pivotIsLow[start+4]) {
                validSequence = false;
            }
        }

        if(validSequence) {
            dIndex = pivotIndices[start];     // most recent point
            cIndex = pivotIndices[start+1];
            bIndex = pivotIndices[start+2];
            aIndex = pivotIndices[start+3];
            xIndex = pivotIndices[start+4];
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Detect bullish Gartley pattern                                    |
//+------------------------------------------------------------------+
bool IsBullishGartley(MqlRates &rates[])
{
    // FIXED: Reduced minimum bars from 40 to 25
    int size = ArraySize(rates);
    if(size < 25) return false;

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

    // Time sequence must be correct
    if(!(xIndex > aIndex && aIndex > bIndex && bIndex > cIndex && cIndex > dIndex))
        return false;

    // Prevent division by zero
    if(xaMove <= 0 || abMove <= 0) return false;

    // Calculate Fibonacci ratios correctly for Gartley pattern
    // B is retracement of XA
    double abRatio = abMove / xaMove;

    // C is retracement of AB (how much AB retraced from B to C)
    double bcRetracement = (cPoint - bPoint) / abMove;

    // D is retracement of XA (how much XA retraced from X to D)
    double xdRetracement = (aPoint - dPoint) / xaMove;

    // Check Fibonacci ratios with tolerance
    bool validAB = MathAbs(abRatio - GARTLEY_POINT_B_RETRACEMENT) <= TOLERANCE_LEVEL;
    bool validBC = (bcRetracement >= GARTLEY_POINT_C_MIN - TOLERANCE_LEVEL) &&
                   (bcRetracement <= GARTLEY_POINT_C_MAX + TOLERANCE_LEVEL);
    bool validXD = MathAbs(xdRetracement - GARTLEY_POINT_D_RETRACEMENT) <= TOLERANCE_LEVEL;

    if(validAB && validBC && validXD) {
        DebugPrint("Bullish Gartley pattern: XA=" + DoubleToString(xaMove, 5) +
                   ", AB Ratio=" + DoubleToString(abRatio, 3) +
                   ", BC Retracement=" + DoubleToString(bcRetracement, 3) +
                   ", XD Retracement=" + DoubleToString(xdRetracement, 3));
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Detect bearish Gartley pattern                                    |
//+------------------------------------------------------------------+
bool IsBearishGartley(MqlRates &rates[])
{
    // FIXED: Reduced minimum bars from 40 to 25
    int size = ArraySize(rates);
    if(size < 25) return false;

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

    // Time sequence must be correct
    if(!(xIndex > aIndex && aIndex > bIndex && bIndex > cIndex && cIndex > dIndex))
        return false;

    // Prevent division by zero
    if(xaMove <= 0 || abMove <= 0) return false;

    // Calculate Fibonacci ratios correctly for Gartley pattern
    // B is retracement of XA
    double abRatio = abMove / xaMove;

    // C is retracement of AB (how much AB retraced from B to C)
    double bcRetracement = (bPoint - cPoint) / abMove;

    // D is retracement of XA (how much XA retraced from X to D)
    double xdRetracement = (xPoint - dPoint) / xaMove;

    // Check Fibonacci ratios with tolerance
    bool validAB = MathAbs(abRatio - GARTLEY_POINT_B_RETRACEMENT) <= TOLERANCE_LEVEL;
    bool validBC = (bcRetracement >= GARTLEY_POINT_C_MIN - TOLERANCE_LEVEL) &&
                   (bcRetracement <= GARTLEY_POINT_C_MAX + TOLERANCE_LEVEL);
    bool validXD = MathAbs(xdRetracement - GARTLEY_POINT_D_RETRACEMENT) <= TOLERANCE_LEVEL;

    if(validAB && validBC && validXD) {
        DebugPrint("Bearish Gartley pattern: XA=" + DoubleToString(xaMove, 5) +
                   ", AB Ratio=" + DoubleToString(abRatio, 3) +
                   ", BC Retracement=" + DoubleToString(bcRetracement, 3) +
                   ", XD Retracement=" + DoubleToString(xdRetracement, 3));
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Detect bullish Butterfly pattern                                  |
//+------------------------------------------------------------------+
bool IsBullishButterfly(MqlRates &rates[])
{
    // FIXED: Reduced minimum bars from 40 to 25
    int size = ArraySize(rates);
    if(size < 25) return false;

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

    // Time sequence must be correct
    if(!(xIndex > aIndex && aIndex > bIndex && bIndex > cIndex && cIndex > dIndex))
        return false;

    // Prevent division by zero
    if(xaMove <= 0 || abMove <= 0) return false;

    // Calculate Fibonacci ratios correctly for Butterfly pattern
    // B is retracement of XA
    double abRatio = abMove / xaMove;

    // C is retracement of AB
    double bcRetracement = (cPoint - bPoint) / abMove;

    // D is extension of XA (beyond X)
    double xdExtension = MathAbs(xPoint - dPoint) / xaMove;

    // Check Fibonacci ratios with tolerance
    bool validAB = MathAbs(abRatio - BUTTERFLY_POINT_B_RETRACEMENT) <= TOLERANCE_LEVEL;
    bool validBC = (bcRetracement >= BUTTERFLY_POINT_C_MIN - TOLERANCE_LEVEL) &&
                   (bcRetracement <= BUTTERFLY_POINT_C_MAX + TOLERANCE_LEVEL);

    // For Butterfly, D should be 1.272 or 1.618 extension of XA
    bool validXD = (MathAbs(xdExtension - BUTTERFLY_POINT_D_MIN) <= TOLERANCE_LEVEL) ||
                   (MathAbs(xdExtension - BUTTERFLY_POINT_D_MAX) <= TOLERANCE_LEVEL);

    // D should be below X for bullish pattern
    bool dBeyondX = dPoint < xPoint;

    if(validAB && validBC && validXD && dBeyondX) {
        DebugPrint("Bullish Butterfly pattern: XA=" + DoubleToString(xaMove, 5) +
                   ", AB Ratio=" + DoubleToString(abRatio, 3) +
                   ", BC Retracement=" + DoubleToString(bcRetracement, 3) +
                   ", XD Extension=" + DoubleToString(xdExtension, 3));
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Detect bearish Butterfly pattern                                  |
//+------------------------------------------------------------------+
bool IsBearishButterfly(MqlRates &rates[])
{
    // FIXED: Reduced minimum bars from 40 to 25
    int size = ArraySize(rates);
    if(size < 25) return false;

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

    // Time sequence must be correct
    if(!(xIndex > aIndex && aIndex > bIndex && bIndex > cIndex && cIndex > dIndex))
        return false;

    // Prevent division by zero
    if(xaMove <= 0 || abMove <= 0) return false;

    // Calculate Fibonacci ratios correctly for Butterfly pattern
    // B is retracement of XA
    double abRatio = abMove / xaMove;

    // C is retracement of AB
    double bcRetracement = (bPoint - cPoint) / abMove;

    // D is extension of XA (beyond X)
    double xdExtension = MathAbs(dPoint - xPoint) / xaMove;

    // Check Fibonacci ratios with tolerance
    bool validAB = MathAbs(abRatio - BUTTERFLY_POINT_B_RETRACEMENT) <= TOLERANCE_LEVEL;
    bool validBC = (bcRetracement >= BUTTERFLY_POINT_C_MIN - TOLERANCE_LEVEL) &&
                   (bcRetracement <= BUTTERFLY_POINT_C_MAX + TOLERANCE_LEVEL);

    // For Butterfly, D should be 1.272 or 1.618 extension of XA
    bool validXD = (MathAbs(xdExtension - BUTTERFLY_POINT_D_MIN) <= TOLERANCE_LEVEL) ||
                   (MathAbs(xdExtension - BUTTERFLY_POINT_D_MAX) <= TOLERANCE_LEVEL);

    // D should be above X for bearish pattern
    bool dBeyondX = dPoint > xPoint;

    if(validAB && validBC && validXD && dBeyondX) {
        DebugPrint("Bearish Butterfly pattern: XA=" + DoubleToString(xaMove, 5) +
                   ", AB Ratio=" + DoubleToString(abRatio, 3) +
                   ", BC Retracement=" + DoubleToString(bcRetracement, 3) +
                   ", XD Extension=" + DoubleToString(xdExtension, 3));
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Detect bullish Bat pattern                                       |
//+------------------------------------------------------------------+
bool IsBullishBat(MqlRates &rates[])
{
    // FIXED: Reduced minimum bars from 40 to 25
    int size = ArraySize(rates);
    if(size < 25) return false;

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

    // Time sequence must be correct
    if(!(xIndex > aIndex && aIndex > bIndex && bIndex > cIndex && cIndex > dIndex))
        return false;

    // Prevent division by zero
    if(xaMove <= 0 || abMove <= 0) return false;

    // Calculate Fibonacci ratios correctly for Bat pattern
    // B is retracement of XA (should be 0.382 to 0.500)
    double abRatio = abMove / xaMove;

    // C is retracement of AB (should be 0.382 to 0.886)
    double bcRetracement = (cPoint - bPoint) / abMove;

    // D is retracement of XA (should be 0.886)
    double xdRetracement = (aPoint - dPoint) / xaMove;

    // Check Fibonacci ratios with tolerance
    bool validAB = (abRatio >= BAT_POINT_B_MIN - TOLERANCE_LEVEL) &&
                   (abRatio <= BAT_POINT_B_MAX + TOLERANCE_LEVEL);
    bool validBC = (bcRetracement >= BAT_POINT_C_MIN - TOLERANCE_LEVEL) &&
                   (bcRetracement <= BAT_POINT_C_MAX + TOLERANCE_LEVEL);
    bool validXD = MathAbs(xdRetracement - BAT_POINT_D_RETRACEMENT) <= TOLERANCE_LEVEL;

    // D should be between X and A for bullish Bat pattern (not beyond X)
    bool dBetweenXandA = (dPoint > xPoint) && (dPoint < aPoint);

    if(validAB && validBC && validXD && dBetweenXandA) {
        DebugPrint("Bullish Bat pattern: XA=" + DoubleToString(xaMove, 5) +
                   ", AB Ratio=" + DoubleToString(abRatio, 3) +
                   ", BC Retracement=" + DoubleToString(bcRetracement, 3) +
                   ", XD Retracement=" + DoubleToString(xdRetracement, 3));
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Detect bearish Bat pattern                                       |
//+------------------------------------------------------------------+
bool IsBearishBat(MqlRates &rates[])
{
    // FIXED: Reduced minimum bars from 40 to 25
    int size = ArraySize(rates);
    if(size < 25) return false;

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

    // Time sequence must be correct
    if(!(xIndex > aIndex && aIndex > bIndex && bIndex > cIndex && cIndex > dIndex))
        return false;

    // Prevent division by zero
    if(xaMove <= 0 || abMove <= 0) return false;

    // Calculate Fibonacci ratios correctly for Bat pattern
    // B is retracement of XA (should be 0.382 to 0.500)
    double abRatio = abMove / xaMove;

    // C is retracement of AB (should be 0.382 to 0.886)
    double bcRetracement = (bPoint - cPoint) / abMove;

    // D is retracement of XA (should be 0.886)
    double xdRetracement = (xPoint - dPoint) / xaMove;

    // Check Fibonacci ratios with tolerance
    bool validAB = (abRatio >= BAT_POINT_B_MIN - TOLERANCE_LEVEL) &&
                   (abRatio <= BAT_POINT_B_MAX + TOLERANCE_LEVEL);
    bool validBC = (bcRetracement >= BAT_POINT_C_MIN - TOLERANCE_LEVEL) &&
                   (bcRetracement <= BAT_POINT_C_MAX + TOLERANCE_LEVEL);
    bool validXD = MathAbs(xdRetracement - BAT_POINT_D_RETRACEMENT) <= TOLERANCE_LEVEL;

    // D should be between X and A for bearish Bat pattern (not beyond X)
    bool dBetweenXandA = (dPoint < xPoint) && (dPoint > aPoint);

    if(validAB && validBC && validXD && dBetweenXandA) {
        DebugPrint("Bearish Bat pattern: XA=" + DoubleToString(xaMove, 5) +
                   ", AB Ratio=" + DoubleToString(abRatio, 3) +
                   ", BC Retracement=" + DoubleToString(bcRetracement, 3) +
                   ", XD Retracement=" + DoubleToString(xdRetracement, 3));
        return true;
    }

    return false;
}