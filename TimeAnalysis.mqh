//+------------------------------------------------------------------+
//|                                      TimeAnalysis.mqh |
//|                                                             |
//|                                                             |
//+------------------------------------------------------------------+

// Declare external variables needed
extern ENUM_TIMEFRAMES TA_Timeframe;

// The DebugPrint function must be defined in the main file
#import "GoldTraderEA_cleaned.mq5"
   void DebugPrint(string message);
   int CheckTimeAnalysis(MqlRates &rates[]);
#import

// Check if current time is within a specified trading session
bool IsWithinTradingSession(datetime current_time, int session_start_hour, int session_start_minute,
                           int session_end_hour, int session_end_minute)
{
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    // Calculate minutes from midnight for all times
    int current_minutes = time_struct.hour * 60 + time_struct.min;
    int session_start_minutes = session_start_hour * 60 + session_start_minute;
    int session_end_minutes = session_end_hour * 60 + session_end_minute;
    
    // Check if current time is within session
    if (session_start_minutes <= session_end_minutes) {
        // Session does not cross midnight
        return (current_minutes >= session_start_minutes && current_minutes <= session_end_minutes);
    } else {
        // Session crosses midnight
        return (current_minutes >= session_start_minutes || current_minutes <= session_end_minutes);
    }
}

// Check if current time is near market open
bool IsNearMarketOpen(datetime current_time, int minutes_before_open, int minutes_after_open, 
                     int market_open_hour, int market_open_minute)
{
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    // Calculate minutes from midnight for all times
    int current_minutes = time_struct.hour * 60 + time_struct.min;
    int market_open_minutes = market_open_hour * 60 + market_open_minute;
    
    // Calculate range around market open
    int range_start = market_open_minutes - minutes_before_open;
    int range_end = market_open_minutes + minutes_after_open;
    
    // Handle overnight cases
    if (range_start < 0)
        range_start += 24 * 60;
    if (range_end >= 24 * 60)
        range_end -= 24 * 60;
    
    // Check if current time is near market open
    if (range_start <= range_end) {
        // Range does not cross midnight
        return (current_minutes >= range_start && current_minutes <= range_end);
    } else {
        // Range crosses midnight
        return (current_minutes >= range_start || current_minutes <= range_end);
    }
}

// Check if current time is near market close
bool IsNearMarketClose(datetime current_time, int minutes_before_close, int minutes_after_close, 
                      int market_close_hour, int market_close_minute)
{
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    // Calculate minutes from midnight for all times
    int current_minutes = time_struct.hour * 60 + time_struct.min;
    int market_close_minutes = market_close_hour * 60 + market_close_minute;
    
    // Calculate range around market close
    int range_start = market_close_minutes - minutes_before_close;
    int range_end = market_close_minutes + minutes_after_close;
    
    // Handle overnight cases
    if (range_start < 0)
        range_start += 24 * 60;
    if (range_end >= 24 * 60)
        range_end -= 24 * 60;
    
    // Check if current time is near market close
    if (range_start <= range_end) {
        // Range does not cross midnight
        return (current_minutes >= range_start && current_minutes <= range_end);
    } else {
        // Range crosses midnight
        return (current_minutes >= range_start || current_minutes <= range_end);
    }
}

// Check if current day is a specified day of the week
bool IsSpecificDayOfWeek(datetime current_time, int target_day)
{
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    // Check if current day equals target day (0=Sunday, 1=Monday, etc.)
    return (time_struct.day_of_week == target_day);
}

// Check if we are in the first half of the month
bool IsFirstHalfOfMonth(datetime current_time)
{
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    // Check if day is in first half of month (days 1-15)
    return (time_struct.day <= 15);
}

// Check if we are in the second half of the month
bool IsSecondHalfOfMonth(datetime current_time)
{
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    // Check if day is in second half of month (days 16-31)
    return (time_struct.day > 15);
}

// Check if the current time is historically volatile (based on hourly analysis)
bool IsVolatileTimeOfDay(datetime current_time, double &volatility_by_hour[])
{
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    // Check if we have volatility data for all hours
    if (ArraySize(volatility_by_hour) != 24)
        return false;
    
    // Get current hour's volatility value and check if it's above threshold
    double current_hour_volatility = volatility_by_hour[time_struct.hour];
    double threshold = 1.5; // Threshold for considering an hour volatile
    
    return (current_hour_volatility > threshold);
}

// Check if near a high-impact news event
bool IsNearNewsEvent(datetime current_time, datetime news_time, int minutes_before, int minutes_after)
{
    // Validate news_time is initialized
    if(news_time == 0)
        return false;

    // Calculate the time difference in seconds
    long time_diff = current_time - news_time;

    // Convert minutes to seconds
    long before_seconds = minutes_before * 60;
    long after_seconds = minutes_after * 60;

    // Check if current time is within the range around the news event
    return (time_diff >= -before_seconds && time_diff <= after_seconds);
}

// Calculate average volatility by hour over a period
void CalculateHourlyVolatility(MqlRates &rates[], double &volatility_by_hour[])
{
    // Initialize array to store volatility by hour
    ArrayResize(volatility_by_hour, 24);
    ArrayInitialize(volatility_by_hour, 0);
    
    // Arrays to keep track of how many observations per hour
    int counts[24];
    ArrayInitialize(counts, 0);
    
    int total_bars = ArraySize(rates);
    
    // Calculate volatility for each bar and accumulate by hour
    for (int i = 0; i < total_bars; i++) {
        // Validate data integrity
        if(rates[i].close <= 0 || rates[i].high < rates[i].low)
            continue;

        MqlDateTime time_struct;
        TimeToStruct(rates[i].time, time_struct);

        // Calculate high-low range as percentage of close price
        double volatility = (rates[i].high - rates[i].low) / rates[i].close * 100.0;

        // Add to hourly accumulator
        volatility_by_hour[time_struct.hour] += volatility;
        counts[time_struct.hour]++;
    }
    
    // Calculate average volatility for each hour
    for (int hour = 0; hour < 24; hour++) {
        if (counts[hour] > 0) {
            volatility_by_hour[hour] /= counts[hour];
        }
    }
}

// Check if the current bar formed at a time frame change (hour, day, week, month)
bool IsTimeframeChangeBar(MqlRates &prev_rate, MqlRates &curr_rate, int timeframe_type)
{
    MqlDateTime prev_time, curr_time;
    TimeToStruct(prev_rate.time, prev_time);
    TimeToStruct(curr_rate.time, curr_time);
    
    switch (timeframe_type) {
        case 1: // Hour change
            return (prev_time.hour != curr_time.hour);
            
        case 2: // Day change
            return (prev_time.day != curr_time.day);
            
        case 3: // Week change
            // Week changes when we transition to Monday (day 1) from a higher day number
            // or when the day of week decreases (wrapping from Saturday to Sunday/Monday)
            return (curr_time.day_of_week < prev_time.day_of_week ||
                    (prev_time.day_of_week >= 5 && curr_time.day_of_week <= 1));
            
        case 4: // Month change
            return (prev_time.mon != curr_time.mon);
            
        default:
            return false;
    }
}

// Check for seasonal patterns (month-based)
bool IsSeasonallyBullishPeriod(datetime current_time, int bullish_month_start, int bullish_month_end)
{
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    int current_month = time_struct.mon; // 1-12 for Jan-Dec
    
    if (bullish_month_start <= bullish_month_end) {
        // Period does not cross year boundary
        return (current_month >= bullish_month_start && current_month <= bullish_month_end);
    } else {
        // Period crosses year boundary (e.g., Nov-Feb)
        return (current_month >= bullish_month_start || current_month <= bullish_month_end);
    }
}

// Check for end-of-period effects
bool IsEndOfPeriodEffect(datetime current_time, int days_before_end)
{
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    // Get days in current month
    int days_in_month;
    switch (time_struct.mon) {
        case 2: // February
            days_in_month = (time_struct.year % 4 == 0 && 
                             (time_struct.year % 100 != 0 || time_struct.year % 400 == 0)) ? 29 : 28;
            break;
        case 4: case 6: case 9: case 11: // Apr, Jun, Sep, Nov
            days_in_month = 30;
            break;
        default: // Jan, Mar, May, Jul, Aug, Oct, Dec
            days_in_month = 31;
            break;
    }
    
    // Check if we're within 'days_before_end' days of the end of the month
    return (time_struct.day > (days_in_month - days_before_end));
}

// Is day a valid trading day (1-5 = Monday-Friday)
bool IsTradingDay(datetime current_time)
{
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    // Valid trading days are Monday through Friday (1-5)
    return (time_struct.day_of_week >= 1 && time_struct.day_of_week <= 5);
}

// Check for time-based trading opportunities based on multiple criteria
bool CheckTimeAnalysisBuySignal(datetime current_time,
                               bool use_session_filter, int session_start_hour, int session_start_minute,
                               int session_end_hour, int session_end_minute,
                               bool use_day_filter,
                               bool use_volatility_filter, double &volatility_by_hour[])
{
    // First check if we're within trading session (if filter is enabled)
    if (use_session_filter && !IsWithinTradingSession(current_time, session_start_hour, session_start_minute,
                                                    session_end_hour, session_end_minute)) {
        return false;
    }

    // Check day of week filter (if enabled)
    if (use_day_filter && !IsTradingDay(current_time)) {
        return false;
    }

    // Check volatility filter (if enabled)
    if (use_volatility_filter && !IsVolatileTimeOfDay(current_time, volatility_by_hour)) {
        return false;
    }

    // If all filters pass, return true
    return true;
}

// Similar function for sell signals
bool CheckTimeAnalysisSellSignal(datetime current_time,
                                bool use_session_filter, int session_start_hour, int session_start_minute,
                                int session_end_hour, int session_end_minute,
                                bool use_day_filter,
                                bool use_volatility_filter, double &volatility_by_hour[])
{
    // First check if we're within trading session (if filter is enabled)
    if (use_session_filter && !IsWithinTradingSession(current_time, session_start_hour, session_start_minute,
                                                    session_end_hour, session_end_minute)) {
        return false;
    }

    // Check day of week filter (if enabled)
    if (use_day_filter && !IsTradingDay(current_time)) {
        return false;
    }

    // Check volatility filter (if enabled)
    if (use_volatility_filter && !IsVolatileTimeOfDay(current_time, volatility_by_hour)) {
        return false;
    }

    // If all filters pass, return true
    return true;
}

// Check time analysis for potential reversal points
int CheckTimeAnalysis(MqlRates &rates[])
{
    DebugPrint("Starting time analysis");
    
    int confirmations = 0;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 100) {
        DebugPrint("The rates array for CheckTimeAnalysis is smaller than the required size: " + IntegerToString(size));
        return 0;
    }
    
    // Finding significant points in the last 100 candles
    int swing_high_indices[10];  // Indices of the last 10 peaks
    int swing_low_indices[10];   // Indices of the last 10 troughs
    datetime swing_high_times[10]; // Times of the last 10 peaks
    datetime swing_low_times[10];  // Times of the last 10 troughs

    // Initialize arrays to prevent undefined behavior
    ArrayInitialize(swing_high_indices, 0);
    ArrayInitialize(swing_low_indices, 0);
    ArrayInitialize(swing_high_times, 0);
    ArrayInitialize(swing_low_times, 0);

    int swing_high_count = 0;
    int swing_low_count = 0;
    
    // Identifying significant peaks and troughs
    for(int i = 1; i < size - 1; i++) {
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high) {
            // Local peak
            if(swing_high_count < 10) {
                swing_high_indices[swing_high_count] = i;
                swing_high_times[swing_high_count] = rates[i].time;
                swing_high_count++;
            }
        }
        
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low) {
            // Local trough
            if(swing_low_count < 10) {
                swing_low_indices[swing_low_count] = i;
                swing_low_times[swing_low_count] = rates[i].time;
                swing_low_count++;
            }
        }
        
        // If enough points are reached, exit the loop
        if(swing_high_count >= 10 && swing_low_count >= 10)
            break;
    }
    
    // If not enough points found
    if(swing_high_count < 3 || swing_low_count < 3) {
        DebugPrint("Not enough points found for time analysis");
        return 0;
    }
    
    // Calculate time intervals between peaks
    long high_time_deltas[9];  // Time intervals between peaks
    for(int i = 0; i < swing_high_count - 1; i++) {
        high_time_deltas[i] = swing_high_times[i] - swing_high_times[i+1];
    }
    
    // Calculate time intervals between troughs
    long low_time_deltas[9];  // Time intervals between troughs
    for(int i = 0; i < swing_low_count - 1; i++) {
        low_time_deltas[i] = swing_low_times[i] - swing_low_times[i+1];
    }
    
    // Analyze periodic patterns (time cycles)
    // Check if the time interval between two recent peaks/troughs matches previous patterns
    for(int i = 0; i < swing_high_count - 2; i++) {
        // Compare the time interval of the two recent peaks with previous peak intervals
        if(MathAbs(high_time_deltas[0] - high_time_deltas[i+1]) < 3600) {  // Difference less than 1 hour
            DebugPrint("Repeated time pattern found in peaks: " + 
                       TimeToString(swing_high_times[0], TIME_DATE|TIME_MINUTES) + " ~ " + 
                       TimeToString(swing_high_times[i+2], TIME_DATE|TIME_MINUTES));
            confirmations++;
            break;
        }
    }
    
    for(int i = 0; i < swing_low_count - 2; i++) {
        // Compare the time interval of the two recent troughs with previous trough intervals
        if(MathAbs(low_time_deltas[0] - low_time_deltas[i+1]) < 3600) {  // Difference less than 1 hour
            DebugPrint("Repeated time pattern found in troughs: " + 
                       TimeToString(swing_low_times[0], TIME_DATE|TIME_MINUTES) + " ~ " + 
                       TimeToString(swing_low_times[i+2], TIME_DATE|TIME_MINUTES));
            confirmations++;
            break;
        }
    }
    
    // Fibonacci time analysis
    // Check Fibonacci time ratios between significant points
    double fib_levels[] = {0.382, 0.5, 0.618, 1.0, 1.618, 2.0, 2.618};

    datetime current_time = rates[0].time;
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    int significant_points = 0;
    
    // Check if the current time is near one of the Fibonacci time points from previous significant points
    for(int i = 0; i < swing_high_count - 1; i++) {
        long base_time_span = swing_high_times[i] - swing_high_times[i+1];
        
        for(int j = 0; j < ArraySize(fib_levels); j++) {
            long proj_time_span = (long)(base_time_span * fib_levels[j]);
            datetime projected_time = swing_high_times[i] + (datetime)proj_time_span;
            
            // If the current time is close to the projected Fibonacci time
            if(MathAbs(current_time - projected_time) < 3600) {  // Difference less than 1 hour
                DebugPrint("Current time is close to a Fibonacci time point from a peak: " + 
                          TimeToString(projected_time, TIME_DATE|TIME_MINUTES) + 
                          " (Ratio: " + DoubleToString(fib_levels[j], 3) + ")");
                significant_points++;
            }
        }
        
        if(i >= 2) break;  // Only check the last three points
    }
    
    for(int i = 0; i < swing_low_count - 1; i++) {
        long base_time_span = swing_low_times[i] - swing_low_times[i+1];
        
        for(int j = 0; j < ArraySize(fib_levels); j++) {
            long proj_time_span = (long)(base_time_span * fib_levels[j]);
            datetime projected_time = swing_low_times[i] + (datetime)proj_time_span;
            
            // If the current time is close to the projected Fibonacci time
            if(MathAbs(current_time - projected_time) < 3600) {  // Difference less than 1 hour
                DebugPrint("Current time is close to a Fibonacci time point from a trough: " + 
                          TimeToString(projected_time, TIME_DATE|TIME_MINUTES) + 
                          " (Ratio: " + DoubleToString(fib_levels[j], 3) + ")");
                significant_points++;
            }
        }
        
        if(i >= 2) break;  // Only check the last three points
    }
    
    if(significant_points > 0) {
        DebugPrint("A total of " + IntegerToString(significant_points) + " significant Fibonacci time points identified");
        confirmations += significant_points;
    }

    // Check important trading days and hours (time_struct already initialized above)
    // Important trading hours
    int key_hours[] = {8, 12, 14, 16, 20};  // Important hours in GMT
    bool is_key_hour = false;
    
    for(int i = 0; i < ArraySize(key_hours); i++) {
        if(time_struct.hour == key_hours[i]) {
            is_key_hour = true;
            break;
        }
    }
    
    if(is_key_hour) {
        DebugPrint("Important trading hour: " + IntegerToString(time_struct.hour) + ":00");
        confirmations++;
    }
    
    // Important days of the week (Monday and Friday are usually important days)
    if(time_struct.day_of_week == 1 || time_struct.day_of_week == 5) {
        DebugPrint("Important trading day of the week: " + IntegerToString(time_struct.day_of_week));
        confirmations++;
    }
    
    DebugPrint("Number of confirmations from time analysis: " + IntegerToString(confirmations));
    return confirmations;
} 