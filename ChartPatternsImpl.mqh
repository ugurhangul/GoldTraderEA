//+------------------------------------------------------------------+
//|                                             ChartPatternsImpl.mqh |
//|                                      Copyright 2023, Gold Trader   |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Declare external variables needed
#import "GoldTraderEA_cleaned.mq5"
   void DebugPrint(string message);
   bool CheckArrayAccess(int index, int array_size, string function_name);
   bool GetDebugMode();
   void ResetExternalPatternCache();
#import

// Static variables for caching results
static datetime s_last_pattern_check_time = 0;
static int s_cached_pattern_results[10] = {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1};
static datetime s_chart_candle_time = 0;

// Helper function to check whether to use cache or not
bool ShouldUseCache(MqlRates &rates[], int pattern_type)
{
   if(ArraySize(rates) < 1) return false;
   
   // If the current candle time hasn't changed and this pattern has been checked before
   if(rates[0].time == s_chart_candle_time && s_cached_pattern_results[pattern_type] != -1)
      return true;
      
   // Update current time
   s_chart_candle_time = rates[0].time;
   return false;
}

// Reset cache
void ResetPatternCache()
{
   for(int i=0; i<10; i++)
      s_cached_pattern_results[i] = -1;
   s_chart_candle_time = 0;
   
   // Notify the main file that the cache has been reset
   ResetExternalPatternCache();
}

//+------------------------------------------------------------------+
//| Detect Double Top                                                |
//+------------------------------------------------------------------+
bool IsDoubleTop(MqlRates &rates[])
{
    // Use cache
    if(ShouldUseCache(rates, 0))
        return s_cached_pattern_results[0] == 1;
    
    // Check array size - quick exit
    int size = ArraySize(rates);
    if(size < 20) {
        s_cached_pattern_results[0] = 0;
        return false;
    }
    
    // To detect Double Top, we need to find two peaks with similar heights
    int peak1_pos = -1, peak2_pos = -1;
    double peak1_val = 0, peak2_val = 0;
    
    // Find the first peak - strict limits are applied for indices
    int max_i = MathMin(90, size-4); // Ensure that i+3 is in range
    for(int i = 10; i < max_i; i++)
    {
        // Safe array range check
        if(i < 3 || i+1 >= size) continue;
        
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high && 
           rates[i].high > rates[i-2].high && rates[i].high > rates[i-3].high)
        {
            peak1_pos = i;
            peak1_val = rates[i].high;
            break;
        }
    }
    
    // Quick exit if the first peak is not found
    if(peak1_pos == -1) {
        s_cached_pattern_results[0] = 0;
        return false;
    }
    
    // Find the second peak
    int min_i = MathMax(3, peak1_pos-10); // Minimum 3 to ensure access to i-3
    for(int i = min_i; i >= 3; i--)
    {
        // Check array range
        if(i+3 >= size || i < 3)
            continue;
            
        // Recheck array range - reducing operations
        if(!CheckArrayAccess(i, size, "IsDoubleTop"))
           continue;
           
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high && 
           rates[i].high > rates[i-2].high && rates[i].high > rates[i-3].high)
        {
            peak2_pos = i;
            peak2_val = rates[i].high;
            break;
        }
    }
    
    // Quick exit if the second peak is not found
    if(peak2_pos == -1) {
        s_cached_pattern_results[0] = 0;
        return false;
    }
    
    // Check Double Top conditions
    bool result = false;
    
    // Peaks must have similar heights
    if(MathAbs(peak1_val - peak2_val) < 0.01 * peak1_val)
    {
        // Peaks must be sufficiently far apart
        if(peak1_pos - peak2_pos > 10)
        {
            // Check for bearish breakout
            double neckline = 0;
            for(int i = peak2_pos; i < peak1_pos; i++)
            {
                if(i < 0 || i >= size)
                    continue;
                    
                neckline = MathMin(rates[i].low, (neckline == 0) ? rates[i].low : neckline);
            }
            
            if(neckline > 0 && CheckArrayAccess(0, size, "IsDoubleTop"))
                result = (rates[0].close < neckline);
        }
    }
    
    // Store result in cache
    s_cached_pattern_results[0] = result ? 1 : 0;
    return result;
}

//+------------------------------------------------------------------+
//| Detect Double Bottom                                             |
//+------------------------------------------------------------------+
bool IsDoubleBottom(MqlRates &rates[])
{
    // FIX: Add cache support matching IsDoubleTop pattern
    if(ShouldUseCache(rates, 1))
        return s_cached_pattern_results[1] == 1;

    // Check array size
    int size = ArraySize(rates);
    if(size < 20) {
        s_cached_pattern_results[1] = 0;
        DebugPrint("Error in IsDoubleBottom: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    // Find two price bottoms with a middle peak
    double first_bottom = DBL_MAX;
    double second_bottom = DBL_MAX;
    double middle_peak = 0;
    
    int first_bottom_idx = -1;
    int second_bottom_idx = -1;
    int middle_peak_idx = -1;
    
    // Find the first bottom
    for(int i = MathMin(19, size-1); i >= 15; i--)
    {
        if(!CheckArrayAccess(i, size, "IsDoubleBottom") || 
           !CheckArrayAccess(i+1, size, "IsDoubleBottom") || 
           !CheckArrayAccess(i-1, size, "IsDoubleBottom"))
            continue;
            
        if(rates[i].low < first_bottom && rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
        {
            first_bottom = rates[i].low;
            first_bottom_idx = i;
        }
    }
    
    if(first_bottom_idx == -1) {
        s_cached_pattern_results[1] = 0;
        return false;
    }
    
    // Find the middle peak after the first bottom
    for(int i = first_bottom_idx-1; i >= 10; i--)
    {
        if(!CheckArrayAccess(i, size, "IsDoubleBottom") || 
           !CheckArrayAccess(i+1, size, "IsDoubleBottom") || 
           !CheckArrayAccess(i-1, size, "IsDoubleBottom"))
            continue;
            
        if(rates[i].high > middle_peak && rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            middle_peak = rates[i].high;
            middle_peak_idx = i;
            break;
        }
    }
    
    if(middle_peak_idx == -1) {
        s_cached_pattern_results[1] = 0;
        return false;
    }
    
    // Find the second bottom after the middle peak
    for(int i = middle_peak_idx-1; i >= 3; i--)
    {
        if(!CheckArrayAccess(i, size, "IsDoubleBottom") || 
           !CheckArrayAccess(i+1, size, "IsDoubleBottom") || 
           !CheckArrayAccess(i-1, size, "IsDoubleBottom"))
            continue;
            
        if(rates[i].low < second_bottom && rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
        {
            second_bottom = rates[i].low;
            second_bottom_idx = i;
            break;
        }
    }
    
    if(second_bottom_idx == -1) {
        s_cached_pattern_results[1] = 0;
        return false;
    }

    // Confirm Double Bottom pattern
    bool result = false;
    if(first_bottom_idx > middle_peak_idx && middle_peak_idx > second_bottom_idx)
    {
        // Two bottoms must be approximately at the same level
        if(MathAbs(first_bottom - second_bottom) < 0.01 * first_bottom)
        {
            // Current price must be above the middle peak
            if(CheckArrayAccess(0, size, "IsDoubleBottom") && rates[0].close > middle_peak)
                result = true;
        }
    }

    // Store result in cache
    s_cached_pattern_results[1] = result ? 1 : 0;
    return result;
}

//+------------------------------------------------------------------+
//| More pattern detection functions go here                          |
//+------------------------------------------------------------------+ 

//+------------------------------------------------------------------+
//| Detect Head and Shoulders                                        |
//+------------------------------------------------------------------+
bool IsHeadAndShoulders(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 30) {
        DebugPrint("Error in IsHeadAndShoulders: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    // Find three peaks where the middle peak is taller
    double left_shoulder = 0;
    double head = 0;
    double right_shoulder = 0;
    
    int left_shoulder_idx = -1;
    int head_idx = -1;
    int right_shoulder_idx = -1;
    
    // Find left shoulder (first peak)
    for(int i = MathMin(29, size-1); i >= 24; i--)
    {
        if(!CheckArrayAccess(i, size, "IsHeadAndShoulders") || 
           !CheckArrayAccess(i+1, size, "IsHeadAndShoulders") || 
           !CheckArrayAccess(i-1, size, "IsHeadAndShoulders"))
            continue;
            
        if(rates[i].high > left_shoulder && rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            left_shoulder = rates[i].high;
            left_shoulder_idx = i;
        }
    }
    
    if(left_shoulder_idx == -1)
        return false;
    
    // Find head (second and taller peak)
    for(int i = left_shoulder_idx-1; i >= 15; i--)
    {
        if(!CheckArrayAccess(i, size, "IsHeadAndShoulders") || 
           !CheckArrayAccess(i+1, size, "IsHeadAndShoulders") || 
           !CheckArrayAccess(i-1, size, "IsHeadAndShoulders"))
            continue;
            
        if(rates[i].high > head && rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            head = rates[i].high;
            head_idx = i;
        }
    }
    
    if(head_idx == -1 || head <= left_shoulder)
        return false;
    
    // Find right shoulder (third peak)
    for(int i = head_idx-1; i >= 1; i--)
    {
        if(!CheckArrayAccess(i, size, "IsHeadAndShoulders") || 
           !CheckArrayAccess(i+1, size, "IsHeadAndShoulders") || 
           !CheckArrayAccess(i-1, size, "IsHeadAndShoulders"))
            continue;
            
        if(rates[i].high > right_shoulder && rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            right_shoulder = rates[i].high;
            right_shoulder_idx = i;
        }
    }
    
    if(right_shoulder_idx == -1)
        return false;
    
    // Find neckline by connecting valleys between shoulders and head
    double neckline = 0;
    int left_valley_idx = -1;
    int right_valley_idx = -1;
    double left_valley = DBL_MAX;
    double right_valley = DBL_MAX;
    
    // Valley between left shoulder and head
    for(int i = left_shoulder_idx-1; i > head_idx; i--)
    {
        if(!CheckArrayAccess(i, size, "IsHeadAndShoulders"))
            continue;
            
        if(rates[i].low < left_valley)
        {
            left_valley = rates[i].low;
            left_valley_idx = i;
        }
    }
    
    // Valley between head and right shoulder
    for(int i = head_idx-1; i > right_shoulder_idx; i--)
    {
        if(!CheckArrayAccess(i, size, "IsHeadAndShoulders"))
            continue;
            
        if(rates[i].low < right_valley)
        {
            right_valley = rates[i].low;
            right_valley_idx = i;
        }
    }
    
    if(left_valley_idx == -1 || right_valley_idx == -1)
    return false;

    // FIX: Prevent division by zero and correct neckline projection
    // Calculate neckline slope
    if(left_valley_idx == right_valley_idx) {
        // Horizontal neckline
        if(CheckArrayAccess(0, size, "IsHeadAndShoulders")) {
            bool breakout = rates[0].close < left_valley;
            bool shoulders_similar = MathAbs(left_shoulder - right_shoulder) <= 0.01 * left_shoulder;
            return (head > left_shoulder && head > right_shoulder && shoulders_similar && breakout);
        }
        return false;
    }

    // Slope = (price_change) / (time_change)
    // In AS_SERIES: right_valley_idx < left_valley_idx (right is more recent)
    double neckline_slope = (right_valley - left_valley) / (left_valley_idx - right_valley_idx);

    // FIX: Project neckline to current bar (index 0)
    // Use left valley as reference point and project to current position
    double current_neckline = left_valley + neckline_slope * (left_valley_idx - 0);

    // Check for bearish breakout
    bool breakout = false;
    if(CheckArrayAccess(0, size, "IsHeadAndShoulders") && rates[0].close < current_neckline)
        breakout = true;

    // Confirm pattern: head taller than shoulders and neckline breakout
    bool shoulders_similar = MathAbs(left_shoulder - right_shoulder) <= 0.01 * left_shoulder;

    return (head > left_shoulder && head > right_shoulder && shoulders_similar && breakout);
}

//+------------------------------------------------------------------+
//| Detect Inverse Head and Shoulders                                |
//+------------------------------------------------------------------+
bool IsInverseHeadAndShoulders(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 30) {
        DebugPrint("Error in IsInverseHeadAndShoulders: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    // Find three valleys where the middle valley is deeper
    double left_shoulder = DBL_MAX;
    double head = DBL_MAX;
    double right_shoulder = DBL_MAX;
    
    int left_shoulder_idx = -1;
    int head_idx = -1;
    int right_shoulder_idx = -1;
    
    // Find left shoulder (first valley)
    for(int i = MathMin(29, size-1); i >= 24; i--)
    {
        if(!CheckArrayAccess(i, size, "IsInverseHeadAndShoulders") || 
           !CheckArrayAccess(i+1, size, "IsInverseHeadAndShoulders") || 
           !CheckArrayAccess(i-1, size, "IsInverseHeadAndShoulders"))
            continue;
            
        if(rates[i].low < left_shoulder && rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
        {
            left_shoulder = rates[i].low;
            left_shoulder_idx = i;
        }
    }
    
    if(left_shoulder_idx == -1)
        return false;
    
    // Find head (second and deeper valley)
    for(int i = left_shoulder_idx-1; i >= 15; i--)
    {
        if(!CheckArrayAccess(i, size, "IsInverseHeadAndShoulders") || 
           !CheckArrayAccess(i+1, size, "IsInverseHeadAndShoulders") || 
           !CheckArrayAccess(i-1, size, "IsInverseHeadAndShoulders"))
            continue;
            
        if(rates[i].low < head && rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
        {
            head = rates[i].low;
            head_idx = i;
        }
    }
    
    if(head_idx == -1 || head >= left_shoulder)
        return false;
    
    // Find right shoulder (third valley)
    for(int i = head_idx-1; i >= 1; i--)
    {
        if(!CheckArrayAccess(i, size, "IsInverseHeadAndShoulders") || 
           !CheckArrayAccess(i+1, size, "IsInverseHeadAndShoulders") || 
           !CheckArrayAccess(i-1, size, "IsInverseHeadAndShoulders"))
            continue;
            
        if(rates[i].low < right_shoulder && rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
        {
            right_shoulder = rates[i].low;
            right_shoulder_idx = i;
        }
    }
    
    if(right_shoulder_idx == -1)
        return false;
    
    // Find neckline by connecting peaks between shoulders and head
    double neckline = 0;
    int left_peak_idx = -1;
    int right_peak_idx = -1;
    double left_peak = 0;
    double right_peak = 0;
    
    // Peak between left shoulder and head
    for(int i = left_shoulder_idx-1; i > head_idx; i--)
    {
        if(!CheckArrayAccess(i, size, "IsInverseHeadAndShoulders"))
            continue;
            
        if(rates[i].high > left_peak)
        {
            left_peak = rates[i].high;
            left_peak_idx = i;
        }
    }
    
    // Peak between head and right shoulder
    for(int i = head_idx-1; i > right_shoulder_idx; i--)
    {
        if(!CheckArrayAccess(i, size, "IsInverseHeadAndShoulders"))
            continue;
            
        if(rates[i].high > right_peak)
        {
            right_peak = rates[i].high;
            right_peak_idx = i;
        }
    }
    
    if(left_peak_idx == -1 || right_peak_idx == -1)
    return false;

    // FIX: Prevent division by zero and correct neckline projection
    // Calculate neckline slope
    if(left_peak_idx == right_peak_idx) {
        // Horizontal neckline
        if(CheckArrayAccess(0, size, "IsInverseHeadAndShoulders")) {
            bool breakout = rates[0].close > left_peak;
            bool shoulders_similar = MathAbs(left_shoulder - right_shoulder) <= 0.01 * left_shoulder;
            return (head < left_shoulder && head < right_shoulder && shoulders_similar && breakout);
        }
        return false;
    }

    // Slope = (price_change) / (time_change)
    // In AS_SERIES: right_peak_idx < left_peak_idx (right is more recent)
    double neckline_slope = (right_peak - left_peak) / (left_peak_idx - right_peak_idx);

    // FIX: Project neckline to current bar (index 0)
    // Use left peak as reference point and project to current position
    double current_neckline = left_peak + neckline_slope * (left_peak_idx - 0);

    // Check for bullish breakout
    bool breakout = false;
    if(CheckArrayAccess(0, size, "IsInverseHeadAndShoulders") && rates[0].close > current_neckline)
        breakout = true;

    // Confirm pattern: head lower than shoulders and neckline breakout
    bool shoulders_similar = MathAbs(left_shoulder - right_shoulder) <= 0.01 * left_shoulder;

    return (head < left_shoulder && head < right_shoulder && shoulders_similar && breakout);
}

//+------------------------------------------------------------------+
//| Detect Bullish Flag                                             |
//+------------------------------------------------------------------+
bool IsBullishFlag(MqlRates &rates[])
{
    // Use cache
    if(ShouldUseCache(rates, 4))
        return s_cached_pattern_results[4] == 1;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 30) {
        s_cached_pattern_results[4] = 0;
        if(GetDebugMode()) DebugPrint("Error in IsBullishFlag: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    // A simple and faster implementation for the bullish flag pattern
    
    // Adjust based on available data - calculate once
    int min_size = MathMin(30, size-1);
    int mid_size = MathMin(20, size-1);
    int small_size = MathMin(5, size-1);
    
    // Quick check of array range conditions
    if(small_size >= size || min_size >= size) {
        s_cached_pattern_results[4] = 0;
        return false;
    }
    
    // Check for strong upward trend - optimizing the loop
    bool strong_uptrend = true;
    for(int i = mid_size; i < min_size && strong_uptrend; i++)
    {
        if(i+1 >= size)
            continue;
            
        if(rates[i].close <= rates[i+1].close)
        {
            strong_uptrend = false;
        }
    }
    
    if(!strong_uptrend) {
        s_cached_pattern_results[4] = 0;
        return false;
    }

    // FIX: Properly calculate flag pattern retracement
    // Calculate the range of the uptrend
    if(min_size >= size || small_size >= size) {
        s_cached_pattern_results[4] = 0;
        return false;
    }

    double trend_high = rates[small_size].high;
    double trend_low = rates[min_size].low;
    double trend_range = trend_high - trend_low;

    if(trend_range <= 0) {
        s_cached_pattern_results[4] = 0;
        return false;
    }

    // Check for downward correction (flag) - should retrace 33-66% of the trend
    bool flag_pattern = true;
    double flag_low = DBL_MAX;
    double flag_high = 0;

    for(int i = small_size; i < mid_size && flag_pattern; i++)
    {
        if(i >= size)
            continue;

        if(rates[i].low < flag_low) flag_low = rates[i].low;
        if(rates[i].high > flag_high) flag_high = rates[i].high;
    }

    // Calculate retracement percentage
    double retracement = (trend_high - flag_low) / trend_range;

    // Flag should retrace between 33% and 66% of the trend
    if(retracement < 0.33 || retracement > 0.66) {
        flag_pattern = false;
    }

    // Check for bullish breakout from the flag
    bool result = (flag_pattern && rates[0].close > rates[small_size].high);
    
    // Store result in cache
    s_cached_pattern_results[4] = result ? 1 : 0;
    return result;
}

//+------------------------------------------------------------------+
//| Detect Bearish Flag                                             |
//+------------------------------------------------------------------+
bool IsBearishFlag(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 30) {
        if(GetDebugMode()) DebugPrint("Error in IsBearishFlag: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    // A simple implementation for the bearish flag pattern
    // Requires a strong downward trend followed by an upward correction
    
    // Adjust based on available data
    int min_size = MathMin(30, size-1);
    int mid_size = MathMin(20, size-1);
    int small_size = MathMin(5, size-1);
    
    // Check for strong downward trend
    bool strong_downtrend = true;
    for(int i = mid_size; i < min_size; i++)
    {
        if(i+1 >= size)
            continue;
            
        if(rates[i].close >= rates[i+1].close)
        {
            strong_downtrend = false;
            break;
        }
    }
    
    if(!strong_downtrend)
        return false;
        
    // Check for upward correction (flag)
    bool flag_pattern = true;
    for(int i = small_size; i < mid_size; i++)
    {
        if(i >= size || small_size >= size || min_size >= size)
            continue;
            
        // Correction must be within 1/3 to 2/3 of the main trend
        if(rates[i].low < rates[small_size].low || rates[i].high > rates[min_size].high)
        {
            flag_pattern = false;
            break;
        }
    }
    
    // Check for bearish breakout from the flag
    if(flag_pattern && size > small_size && rates[0].close < rates[small_size].low)
        return true;
        
    return false;
}

//+------------------------------------------------------------------+
//| Detect Cup and Handle                                           |
//+------------------------------------------------------------------+
bool IsCupAndHandle(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 80) {
        DebugPrint("Error in IsCupAndHandle: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    // A simple implementation for the cup and handle pattern
    // This pattern requires a longer data check
    
    // Find the first peak point
    int peak1 = -1;
    double peak1_val = 0;
    
    int max_i = MathMin(99, size-2);
    for(int i = 80; i < max_i; i++)
    {
        if(i+1 >= size || i-1 < 0)
            continue;
            
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            peak1 = i;
            peak1_val = rates[i].high;
            break;
        }
    }
    
    if(peak1 == -1)
        return false;
        
    // Find the second peak point
    int peak2 = -1;
    double peak2_val = 0;
    
    for(int i = 10; i < 30 && i < size-1; i++)
    {
        if(i+1 >= size || i-1 < 0)
            continue;
            
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            peak2 = i;
            peak2_val = rates[i].high;
            break;
        }
    }
    
    if(peak2 == -1)
        return false;

    // FIX: Validate that there's enough space between peaks for cup formation
    if(peak2 + 5 >= peak1 - 5) {
        return false;
    }

    // Find the middle point (cup)
    int cup_bottom = -1;
    double cup_val = 999999;

    for(int i = peak2 + 5; i < peak1 - 5; i++)
    {
        if(i < 0 || i >= size)
            continue;

        if(rates[i].low < cup_val)
        {
            cup_bottom = i;
            cup_val = rates[i].low;
        }
    }

    if(cup_bottom == -1)
        return false;
        
    // Check Cup and Handle conditions
    // Peaks must be approximately at the same height
    if(MathAbs(peak1_val - peak2_val) > 0.1 * peak1_val)
        return false;
        
    // Handle must be shorter than the cup
    if(peak2 > (peak1 - cup_bottom) / 2)
        return false;
        
    // Check for breakout above the peak levels
    double breakout_level = MathMax(peak1_val, peak2_val);
    
    return (rates[0].close > breakout_level);
}

//+------------------------------------------------------------------+
//| Detect Ascending Triangle                                        |
//+------------------------------------------------------------------+
bool IsAscendingTriangle(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 50) {
        DebugPrint("Error in IsAscendingTriangle: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    // A simple implementation for the ascending triangle pattern
    // Requires a horizontal resistance line above and a support line with a positive slope
    
    // Find horizontal resistance line
    double resistance = 0;
    int resistance_touches = 0;
    
    // Find the first peak
    int max_i = MathMin(90, size-2);
    for(int i = 50; i < max_i; i++)
    {
        if(i+1 >= size || i-1 < 0)
            continue;
            
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            resistance = rates[i].high;
            break;
        }
    }
    
    if(resistance == 0)
        return false;
        
    // Count the number of touches on the resistance line
    int max_j = MathMin(50, size);
    for(int i = 5; i < max_j; i++)
    {
        if(i < 0 || i >= size)
            continue;
            
        if(MathAbs(rates[i].high - resistance) < 0.001 * resistance)
            resistance_touches++;
    }
    
    if(resistance_touches < 2)
        return false;
        
    // FIX: Find support line with a positive slope
    // Loop goes from i=50 (old) to i=5 (recent) in AS_SERIES mode
    // For ascending support: recent valleys should be HIGHER than old valleys
    bool ascending_support = true;
    double prev_low = 0;

    for(int i = 50; i > 5; i--)
    {
        if(i >= size || i+1 >= size || i-1 < 0)
            continue;

        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
        {
            // FIX: Since we're going from old to recent, check if current valley >= previous
            // This ensures ascending support (higher lows)
            if(prev_low != 0 && rates[i].low < prev_low)
            {
                ascending_support = false;
                break;
            }

            prev_low = rates[i].low;
        }
    }

    if(!ascending_support)
        return false;
        
    // Check for breakout above the resistance line
    return (rates[0].close > resistance);
}

//+------------------------------------------------------------------+
//| Detect Descending Triangle                                       |
//+------------------------------------------------------------------+
bool IsDescendingTriangle(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 50) {
        DebugPrint("Error in IsDescendingTriangle: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    // A simple implementation for the descending triangle pattern
    // Requires a horizontal support line below and a resistance line with a negative slope
    
    // Find horizontal support line
    double support = 999999;
    int support_touches = 0;
    
    // Find the first valley
    int max_i = MathMin(90, size-2);
    for(int i = 50; i < max_i; i++)
    {
        if(i+1 >= size || i-1 < 0)
            continue;
            
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
        {
            support = rates[i].low;
            break;
        }
    }
    
    if(support == 999999)
        return false;
        
    // Count the number of touches on the support line
    int max_j = MathMin(50, size);
    for(int i = 5; i < max_j; i++)
    {
        if(i < 0 || i >= size)
            continue;
            
        if(MathAbs(rates[i].low - support) < 0.001 * support)
            support_touches++;
    }
    
    if(support_touches < 2)
        return false;
        
    // FIX: Find resistance line with a negative slope
    // Loop goes from i=50 (old) to i=5 (recent) in AS_SERIES mode
    // For descending resistance: recent peaks should be LOWER than old peaks
    bool descending_resistance = true;
    double prev_high = 0;

    for(int i = 50; i > 5; i--)
    {
        if(i >= size || i+1 >= size || i-1 < 0)
            continue;

        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            // FIX: Since we're going from old to recent, check if current peak <= previous
            // This ensures descending resistance (lower highs)
            if(prev_high != 0 && rates[i].high > prev_high)
            {
                descending_resistance = false;
                break;
            }

            prev_high = rates[i].high;
        }
    }

    if(!descending_resistance)
        return false;
        
    // Check for breakout below the support line
    return (rates[0].close < support);
}

//+------------------------------------------------------------------+
//| Detect Bullish Wedge                                            |
//+------------------------------------------------------------------+
bool IsBullishWedge(MqlRates &rates[])
{
    // Use cache
    if(ShouldUseCache(rates, 8))
        return s_cached_pattern_results[8] == 1;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 20) {
        s_cached_pattern_results[8] = 0;
        if(GetDebugMode()) DebugPrint("Error in IsBullishWedge: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    // Optimize calculations by storing intermediate results
    int max_lookback = MathMin(size-1, 49);
    int min_lookback = MathMin(10, max_lookback/2);
    
    // Increase efficiency by pre-allocating arrays
    double lows[3] = {0, 0, 0};
    int low_indices[3] = {-1, -1, -1};
    int low_count = 0;
    
    double highs[3] = {0, 0, 0};
    int high_indices[3] = {-1, -1, -1};
    int high_count = 0;
    
    // Find low and high points in one loop to reduce iterations
    for(int i = max_lookback; i >= min_lookback; i--)
    {
        if(i+1 >= size || i-1 < 0)
            continue;
        
        // Check valleys
        if(low_count < 3 && rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
        {
            lows[low_count] = rates[i].low;
            low_indices[low_count] = i;
            low_count++;
        }
        
        // Check peaks
        if(high_count < 3 && rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            highs[high_count] = rates[i].high;
            high_indices[high_count] = i;
            high_count++;
        }
        
        // If both are found sufficiently, exit the loop
        if(low_count >= 2 && high_count >= 2)
            break;
    }
    
    // Quick exit if conditions are not met
    if(low_count < 2 || high_count < 2) {
        s_cached_pattern_results[8] = 0;
        return false;
    }

    // FIX: Bullish/Falling Wedge should have ASCENDING lines (rising lows and rising highs)
    // In AS_SERIES mode: lows[0] is recent, lows[1] is older
    // Ascending means: recent > older
    bool lower_line_ascending = lows[0] > lows[1];
    bool upper_line_ascending = highs[0] > highs[1];

    if(!lower_line_ascending || !upper_line_ascending) {
        s_cached_pattern_results[8] = 0;
        return false;
    }

    // FIX: Correct slope calculation for AS_SERIES arrays
    // Slope = (price_change) / (time_change)
    // In AS_SERIES: indices[0] < indices[1], so we need to handle negative denominator
    // Correct formula: slope = (recent_price - old_price) / (old_index - recent_index)
    double lower_slope = (lows[0] - lows[1]) / (low_indices[1] - low_indices[0]);
    double upper_slope = (highs[0] - highs[1]) / (high_indices[1] - high_indices[0]);

    // For convergence in falling wedge: lower line slope should be steeper (more positive) than upper line
    if(lower_slope <= upper_slope) {
        s_cached_pattern_results[8] = 0;
        return false;
    }

    // FIX: Correct trendline projection to current bar (index 0)
    // Project from point 0 to current position: value = point_value + slope * (current_index - point_index)
    double current_lower_line = lows[0] + lower_slope * (0 - low_indices[0]);
    double current_upper_line = highs[0] + upper_slope * (0 - high_indices[0]);

    bool result = (rates[0].close > current_upper_line);
    
    // Store result in cache
    s_cached_pattern_results[8] = result ? 1 : 0;
    return result;
}

//+------------------------------------------------------------------+
//| Detect Bearish Wedge                                            |
//+------------------------------------------------------------------+
bool IsBearishWedge(MqlRates &rates[])
{
    // Check array size
    int size = ArraySize(rates);
    if(size < 20) {
        if(GetDebugMode()) DebugPrint("Error in IsBearishWedge: Array size too small: " + IntegerToString(size));
        return false;
    }
    
    // Descending wedge: two converging lines that are both bullish, but the upper line has a lower slope
    // and the price eventually breaks down
    
    // Adjust the required number of candles based on available data
    int max_lookback = MathMin(size-1, 49);  // Use whatever we have, up to 49 candles
    
    // Find valleys for the lower line
    double lows[3] = {0, 0, 0};
    int low_indices[3] = {-1, -1, -1};
    int low_count = 0;
    
    for(int i = max_lookback; i >= MathMin(10, max_lookback/2) && low_count < 3; i--)
    {
        if(i+1 >= size || i-1 < 0)
            continue;
            
        if(rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
        {
            lows[low_count] = rates[i].low;
            low_indices[low_count] = i;
            low_count++;
        }
    }
    
    if(low_count < 2)
        return false;
    
    // Find peaks for the upper line
    double highs[3] = {0, 0, 0};
    int high_indices[3] = {-1, -1, -1};
    int high_count = 0;
    
    for(int i = max_lookback; i >= MathMin(10, max_lookback/2) && high_count < 3; i--)
    {
        if(i+1 >= size || i-1 < 0)
            continue;
            
        if(rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            highs[high_count] = rates[i].high;
            high_indices[high_count] = i;
            high_count++;
        }
    }
    
    if(high_count < 2)
        return false;
    
    // Check line slopes - Bearish/Rising Wedge has ascending lines (correct as-is)
    bool lower_line_ascending = lows[0] > lows[1];
    bool upper_line_ascending = highs[0] > highs[1];

    if(!lower_line_ascending || !upper_line_ascending)
        return false;

    // FIX: Correct slope calculation for AS_SERIES arrays
    // Slope = (price_change) / (time_change)
    // Correct formula: slope = (recent_price - old_price) / (old_index - recent_index)
    double lower_slope = (lows[0] - lows[1]) / (low_indices[1] - low_indices[0]);
    double upper_slope = (highs[0] - highs[1]) / (high_indices[1] - high_indices[0]);

    // For convergence in rising wedge: upper line slope should be steeper (more positive) than lower line
    if(upper_slope <= lower_slope)
        return false;

    // FIX: Correct trendline projection to current bar (index 0)
    // Project from point 0 to current position: value = point_value + slope * (current_index - point_index)
    double current_lower_line = lows[0] + lower_slope * (0 - low_indices[0]);
    double current_upper_line = highs[0] + upper_slope * (0 - high_indices[0]);

    return (rates[0].close < current_lower_line);
} 