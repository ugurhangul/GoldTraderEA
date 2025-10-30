//+------------------------------------------------------------------+
//|                                                TrendPatterns.mqh |
//|                                      Copyright 2023, Gold Trader   |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Declare external variables needed
extern ENUM_TIMEFRAMES TP_Timeframe;
input bool TP_Debug = false;  // Debug flag for TrendPatterns module (will be set programmatically)

// Constants for trend pattern detection
#define TP_MIN_DATA_SIZE 30                    // Minimum bars required for analysis
#define TP_TOLERANCE_PERCENT 0.005             // 0.5% tolerance for trend line alignment (more lenient)
#define TP_MIN_TOUCH_SEPARATION 2              // Minimum bars between touch points (reduced from 5 to allow closer touches)
#define TP_PEAK_DETECTION_RANGE 2              // Candles to check on each side for peaks
#define TP_MIN_SLOPE_THRESHOLD 0.00001         // Minimum absolute slope (reduced to allow flatter lines)
#define TP_MAX_SLOPE_THRESHOLD 100.0           // Maximum absolute slope to avoid unrealistic projections

//+------------------------------------------------------------------+
//| DebugPrint function declared extern from the main file           |
//+------------------------------------------------------------------+
#import "GoldTraderEA.mq5"
   void DebugPrint(string message);
   bool CheckArrayAccess(int index, int array_size, string function_name);
#import

//+------------------------------------------------------------------+
//| Detect Bullish Trend Breakout                                     |
//+------------------------------------------------------------------+
bool IsBullishTrendBreakout(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < TP_MIN_DATA_SIZE) {
        DebugPrint("Error in IsBullishTrendBreakout: Array size is too small: " + IntegerToString(size));
        return false;
    }

    // Find the downtrend line (resistance line with local maxima)
    double first_touch_value = 0;
    double second_touch_value = 0;
    int count_touches = 0;
    double slope = 0;
    int first_touch_idx = -1;
    int second_touch_idx = -1;

    // Search for local maxima with improved peak detection
    // Need to check TP_PEAK_DETECTION_RANGE candles on each side
    int search_start = TP_PEAK_DETECTION_RANGE + 1;
    int search_end = size - TP_PEAK_DETECTION_RANGE - 1;

    for(int i = search_start; i < search_end; i++) {
        // Validate array access for peak detection range
        bool valid_access = true;
        for(int j = -TP_PEAK_DETECTION_RANGE; j <= TP_PEAK_DETECTION_RANGE; j++) {
            if(!CheckArrayAccess(i + j, size, "IsBullishTrendBreakout")) {
                valid_access = false;
                break;
            }
        }
        if(!valid_access) continue;

        // Improved local maximum detection - check multiple candles on each side
        bool is_local_max = true;
        for(int j = 1; j <= TP_PEAK_DETECTION_RANGE; j++) {
            if(rates[i].high <= rates[i+j].high || rates[i].high <= rates[i-j].high) {
                is_local_max = false;
                break;
            }
        }

        if(!is_local_max) continue;

        // Collect trend line points with minimum separation
        if(count_touches == 0) {
            first_touch_value = rates[i].high;
            first_touch_idx = i;
            count_touches++;
        } else if(count_touches == 1) {
            // Enforce minimum separation between touch points
            if(i - first_touch_idx < TP_MIN_TOUCH_SEPARATION) continue;

            // Protection against division by zero
            if(i == first_touch_idx) continue;

            // Calculate the slope of the trend line (using actual distance between points)
            second_touch_value = rates[i].high;
            second_touch_idx = i;
            slope = (second_touch_value - first_touch_value) / (second_touch_idx - first_touch_idx);
            count_touches++;
        } else {
            // Enforce minimum separation from last accepted touch point
            if(count_touches >= 2 && i - second_touch_idx < TP_MIN_TOUCH_SEPARATION) continue;

            // Protection against division by zero
            if(i == second_touch_idx) continue;

            // Check alignment with the trend line using percentage-based tolerance
            // Project from second touch point to current position
            double expected_value = second_touch_value + (slope * (i - second_touch_idx));
            double tolerance = MathAbs(expected_value) * TP_TOLERANCE_PERCENT;

            if(MathAbs(rates[i].high - expected_value) < tolerance) {
                count_touches++;
            }
        }
    }

    // At least three touches with the trend line for validity
    if(count_touches < 3) {
        if(TP_Debug)
            DebugPrint("IsBullishTrendBreakout: Insufficient touches: " + IntegerToString(count_touches));
        return false;
    }

    // CRITICAL: Validate slope direction - downtrend line must have NEGATIVE slope
    // In AS_SERIES arrays: higher index = older, lower index = newer
    // For downtrend: newer highs should be lower than older highs
    // slope = (newer_value - older_value) / (older_index - newer_index)
    // For downtrend: newer < older, so numerator is negative, denominator is positive = negative slope
    if(slope >= 0) {
        if(TP_Debug)
            DebugPrint("IsBullishTrendBreakout: Invalid slope direction (must be negative for downtrend): " +
                      DoubleToString(slope, 5));
        return false;
    }

    // Validate slope is not too flat (horizontal) or too steep
    double abs_slope = MathAbs(slope);
    if(abs_slope < TP_MIN_SLOPE_THRESHOLD) {
        if(TP_Debug)
            DebugPrint("IsBullishTrendBreakout: Slope too flat (horizontal line): " + DoubleToString(slope, 5));
        return false;
    }
    if(abs_slope > TP_MAX_SLOPE_THRESHOLD) {
        if(TP_Debug)
            DebugPrint("IsBullishTrendBreakout: Slope too steep (unrealistic): " + DoubleToString(slope, 5));
        return false;
    }

    // Calculate the trend line value at the current point (index 0)
    // Project from the second touch point to current position (index 0)
    // Since array is series, index 0 is most recent, higher indices are older
    // Distance from second_touch_idx to 0 is: 0 - second_touch_idx = -second_touch_idx
    double trendline_value = second_touch_value + (slope * (0 - second_touch_idx));

    // Check for trend line breakout
    if(CheckArrayAccess(0, size, "IsBullishTrendBreakout") &&
       CheckArrayAccess(1, size, "IsBullishTrendBreakout"))
    {
        if(TP_Debug) {
            DebugPrint("IsBullishTrendBreakout: Trend line value: " + DoubleToString(trendline_value, 5) +
                       ", Slope: " + DoubleToString(slope, 5) +
                       ", Touches: " + IntegerToString(count_touches) +
                       ", Current price: " + DoubleToString(rates[0].close, 5) +
                       ", Previous price: " + DoubleToString(rates[1].close, 5));
        }
        return (rates[0].close > trendline_value && rates[1].close <= trendline_value);
    }

    return false;
}

//+------------------------------------------------------------------+
//| Detect Bearish Trend Breakout                                     |
//+------------------------------------------------------------------+
bool IsBearishTrendBreakout(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < TP_MIN_DATA_SIZE) {
        DebugPrint("Error in IsBearishTrendBreakout: Array size is too small: " + IntegerToString(size));
        return false;
    }

    // Find the uptrend line (support line with local minima)
    double first_touch_value = 0;
    double second_touch_value = 0;
    int count_touches = 0;
    double slope = 0;
    int first_touch_idx = -1;
    int second_touch_idx = -1;

    // Search for local minima with improved peak detection
    // Need to check TP_PEAK_DETECTION_RANGE candles on each side
    int search_start = TP_PEAK_DETECTION_RANGE + 1;
    int search_end = size - TP_PEAK_DETECTION_RANGE - 1;

    for(int i = search_start; i < search_end; i++) {
        // Validate array access for peak detection range
        bool valid_access = true;
        for(int j = -TP_PEAK_DETECTION_RANGE; j <= TP_PEAK_DETECTION_RANGE; j++) {
            if(!CheckArrayAccess(i + j, size, "IsBearishTrendBreakout")) {
                valid_access = false;
                break;
            }
        }
        if(!valid_access) continue;

        // Improved local minimum detection - check multiple candles on each side
        bool is_local_min = true;
        for(int j = 1; j <= TP_PEAK_DETECTION_RANGE; j++) {
            if(rates[i].low >= rates[i+j].low || rates[i].low >= rates[i-j].low) {
                is_local_min = false;
                break;
            }
        }

        if(!is_local_min) continue;

        // Collect trend line points with minimum separation
        if(count_touches == 0) {
            first_touch_value = rates[i].low;
            first_touch_idx = i;
            count_touches++;
        } else if(count_touches == 1) {
            // Enforce minimum separation between touch points
            if(i - first_touch_idx < TP_MIN_TOUCH_SEPARATION) continue;

            // Protection against division by zero
            if(i == first_touch_idx) continue;

            // Calculate the slope of the trend line (using actual distance between points)
            second_touch_value = rates[i].low;
            second_touch_idx = i;
            slope = (second_touch_value - first_touch_value) / (second_touch_idx - first_touch_idx);
            count_touches++;
        } else {
            // Enforce minimum separation from last accepted touch point
            if(count_touches >= 2 && i - second_touch_idx < TP_MIN_TOUCH_SEPARATION) continue;

            // Protection against division by zero
            if(i == second_touch_idx) continue;

            // Check alignment with the trend line using percentage-based tolerance
            // Project from second touch point to current position
            double expected_value = second_touch_value + (slope * (i - second_touch_idx));
            double tolerance = MathAbs(expected_value) * TP_TOLERANCE_PERCENT;

            if(MathAbs(rates[i].low - expected_value) < tolerance) {
                count_touches++;
            }
        }
    }

    // At least three touches with the trend line for validity
    if(count_touches < 3) {
        if(TP_Debug)
            DebugPrint("IsBearishTrendBreakout: Insufficient touches: " + IntegerToString(count_touches));
        return false;
    }

    // CRITICAL: Validate slope direction - uptrend line must have POSITIVE slope
    // In AS_SERIES arrays: higher index = older, lower index = newer
    // For uptrend: newer lows should be higher than older lows
    // slope = (newer_value - older_value) / (older_index - newer_index)
    // For uptrend: newer > older, so numerator is positive, denominator is positive = positive slope
    if(slope <= 0) {
        if(TP_Debug)
            DebugPrint("IsBearishTrendBreakout: Invalid slope direction (must be positive for uptrend): " +
                      DoubleToString(slope, 5));
        return false;
    }

    // Validate slope is not too flat (horizontal) or too steep
    double abs_slope = MathAbs(slope);
    if(abs_slope < TP_MIN_SLOPE_THRESHOLD) {
        if(TP_Debug)
            DebugPrint("IsBearishTrendBreakout: Slope too flat (horizontal line): " + DoubleToString(slope, 5));
        return false;
    }
    if(abs_slope > TP_MAX_SLOPE_THRESHOLD) {
        if(TP_Debug)
            DebugPrint("IsBearishTrendBreakout: Slope too steep (unrealistic): " + DoubleToString(slope, 5));
        return false;
    }

    // Calculate the trend line value at the current point (index 0)
    // Project from the second touch point to current position (index 0)
    // Since array is series, index 0 is most recent, higher indices are older
    // Distance from second_touch_idx to 0 is: 0 - second_touch_idx = -second_touch_idx
    double trendline_value = second_touch_value + (slope * (0 - second_touch_idx));

    // Check for trend line breakout
    if(CheckArrayAccess(0, size, "IsBearishTrendBreakout") &&
       CheckArrayAccess(1, size, "IsBearishTrendBreakout"))
    {
        if(TP_Debug) {
            DebugPrint("IsBearishTrendBreakout: Trend line value: " + DoubleToString(trendline_value, 5) +
                       ", Slope: " + DoubleToString(slope, 5) +
                       ", Touches: " + IntegerToString(count_touches) +
                       ", Current price: " + DoubleToString(rates[0].close, 5) +
                       ", Previous price: " + DoubleToString(rates[1].close, 5));
        }
        return (rates[0].close < trendline_value && rates[1].close >= trendline_value);
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check trend breakout patterns for buying                         |
//+------------------------------------------------------------------+
int CheckTrendPatternsBuy(MqlRates &rates[])
{
    int confirmations = 0;
    int size = ArraySize(rates);

    // Validate array has enough data for trend analysis
    if(size < TP_MIN_DATA_SIZE) {
        DebugPrint("CheckTrendPatternsBuy: Insufficient data for trend analysis. Size: " + IntegerToString(size));
        return 0;
    }

    // Bullish Trend Breakout (breaking above downtrend resistance)
    if(IsBullishTrendBreakout(rates))
        confirmations++;

    return confirmations;
}

//+------------------------------------------------------------------+
//| Check trend breakout patterns for selling                        |
//+------------------------------------------------------------------+
int CheckTrendPatternsShort(MqlRates &rates[])
{
    int confirmations = 0;
    int size = ArraySize(rates);

    // Validate array has enough data for trend analysis
    if(size < TP_MIN_DATA_SIZE) {
        DebugPrint("CheckTrendPatternsShort: Insufficient data for trend analysis. Size: " + IntegerToString(size));
        return 0;
    }

    // Bearish Trend Breakout (breaking below uptrend support)
    if(IsBearishTrendBreakout(rates))
        confirmations++;

    return confirmations;
}