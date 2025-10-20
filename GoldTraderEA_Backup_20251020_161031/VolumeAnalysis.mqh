//+------------------------------------------------------------------+
//|                                               VolumeAnalysis.mqh |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property link      ""

// External variable declarations
extern ENUM_TIMEFRAMES VA_Timeframe;
extern int handle_volumes;  // Handle to the volumes indicator

// The DebugPrint function must be defined in the main file
#import "GoldTraderEA_cleaned.mq5"
   void DebugPrint(string message);
#import

// Declaration of the g_volumes variable which is defined and initialized in the main file
extern long g_volumes[];

//+------------------------------------------------------------------+
//| Volume analysis for buy signal                                    |
//+------------------------------------------------------------------+
int CheckVolumeAnalysisBuy(MqlRates &rates[])
{
    // Check if volume data is available
    if(handle_volumes == INVALID_HANDLE) {
        DebugPrint("Volume data is not available, skipping volume analysis for buy");
        return 0;
    }
    
    DebugPrint("Starting volume analysis for buy");
    
    int confirmations = 0;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 20) {
        DebugPrint("The rates array for CheckVolumeAnalysisBuy is smaller than the required size: " + IntegerToString(size));
        return 0;
    }
    
    // Check trade volume
    if(ArraySize(g_volumes) < 20) {
        DebugPrint("The g_volumes array for CheckVolumeAnalysisBuy is smaller than the required size: " + IntegerToString(ArraySize(g_volumes)));
        return 0;
    }
    
    // Calculate the average volume of the last 10 candles
    long avg_volume = 0;
    for(int i = 0; i < 10; i++) {
        avg_volume += g_volumes[i];
    }
    avg_volume /= 10;
    
    // Check for volume increase in the recent bullish candle
    if(rates[0].close > rates[0].open && g_volumes[0] > avg_volume * 1.5) {
        DebugPrint("Volume increase in the recent bullish candle: " + 
                  "Current volume: " + IntegerToString(g_volumes[0]) + 
                  " - Average volume: " + IntegerToString(avg_volume));
        confirmations++;
    }
    
    // Check for price breakout with increased volume
    // Finding the recent resistance level (highest level in the last 20 candles)
    double recent_resistance = 0;
    for(int i = 1; i < 20; i++) {
        if(rates[i].high > recent_resistance)
            recent_resistance = rates[i].high;
    }
    
    // Check for breakout of this level with high volume
    if(rates[0].close > recent_resistance && g_volumes[0] > avg_volume * 1.3) {
        DebugPrint("Breakout of resistance level " + DoubleToString(recent_resistance, 2) + 
                  " with high volume: " + IntegerToString(g_volumes[0]));
        confirmations += 2;  // More significant confirmation
    }
    
    // Check for positive volume-price divergence
    // When price decreases but volume also decreases (sign of weakness in the downtrend)
    bool price_down_volume_down = false;
    
    // Check for downtrend in price over recent candles
    bool price_downtrend = true;
    for(int i = 1; i < 5; i++) {
        if(rates[i].close > rates[i+1].close) {
            price_downtrend = false;
            break;
        }
    }
    
    // Check for volume decrease along with price decrease
    if(price_downtrend) {
        bool volume_decreasing = true;
        for(int i = 1; i < 4; i++) {
            if(g_volumes[i] > g_volumes[i+1]) {
                volume_decreasing = false;
                break;
            }
        }
        
        if(volume_decreasing) {
            DebugPrint("Positive volume-price divergence: price decrease along with volume decrease (weakness in downtrend)");
            confirmations++;
        }
    }
    
    // Check for volume squeeze pattern before bullish move
    // Decrease in volume over several consecutive candles followed by a sudden increase in volume
    bool volume_squeeze = true;
    for(int i = 3; i < 6; i++) {
        if(g_volumes[i] > avg_volume * 0.7) {
            volume_squeeze = false;
            break;
        }
    }
    
    if(volume_squeeze && g_volumes[0] > avg_volume * 1.5 && rates[0].close > rates[0].open) {
        DebugPrint("Volume squeeze pattern before bullish move detected");
        confirmations++;
    }
    
    // Check for gradual volume increase in the uptrend
    bool rising_price = true;
    for(int i = 0; i < 3; i++) {
        if(rates[i].close < rates[i+1].close) {
            rising_price = false;
            break;
        }
    }
    
    bool rising_volume = true;
    for(int i = 0; i < 3; i++) {
        if(g_volumes[i] < g_volumes[i+1]) {
            rising_volume = false;
            break;
        }
    }
    
    if(rising_price && rising_volume) {
        DebugPrint("Gradual volume increase in the uptrend (confirmation of trend strength)");
        confirmations++;
    }
    
    DebugPrint("Number of confirmations for volume analysis for buy: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Volume analysis for sell signal                                   |
//+------------------------------------------------------------------+
int CheckVolumeAnalysisShort(MqlRates &rates[])
{
    // Check if volume data is available
    if(handle_volumes == INVALID_HANDLE) {
        DebugPrint("Volume data is not available, skipping volume analysis for sell");
        return 0;
    }
    
    DebugPrint("Starting volume analysis for sell");
    
    int confirmations = 0;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 20) {
        DebugPrint("The rates array for CheckVolumeAnalysisShort is smaller than the required size: " + IntegerToString(size));
        return 0;
    }
    
    // Check trade volume
    if(ArraySize(g_volumes) < 20) {
        DebugPrint("The g_volumes array for CheckVolumeAnalysisShort is smaller than the required size: " + IntegerToString(ArraySize(g_volumes)));
        return 0;
    }
    
    // Calculate the average volume of the last 10 candles
    long avg_volume = 0;
    for(int i = 0; i < 10; i++) {
        avg_volume += g_volumes[i];
    }
    avg_volume /= 10;
    
    // Check for volume increase in the recent bearish candle
    if(rates[0].close < rates[0].open && g_volumes[0] > avg_volume * 1.5) {
        DebugPrint("Volume increase in the recent bearish candle: " + 
                  "Current volume: " + IntegerToString(g_volumes[0]) + 
                  " - Average volume: " + IntegerToString(avg_volume));
        confirmations++;
    }
    
    // Check for price breakout with increased volume
    // Finding the recent support level (lowest level in the last 20 candles)
    double recent_support = DBL_MAX;
    for(int i = 1; i < 20; i++) {
        if(rates[i].low < recent_support)
            recent_support = rates[i].low;
    }
    
    // Check for breakout of this level with high volume
    if(rates[0].close < recent_support && g_volumes[0] > avg_volume * 1.3) {
        DebugPrint("Breakout of support level " + DoubleToString(recent_support, 2) + 
                  " with high volume: " + IntegerToString(g_volumes[0]));
        confirmations += 2;  // More significant confirmation
    }
    
    // Check for negative volume-price divergence
    // When price increases but volume decreases (sign of weakness in the uptrend)
    bool price_up_volume_down = false;
    
    // Check for uptrend in price over recent candles
    bool price_uptrend = true;
    for(int i = 1; i < 5; i++) {
        if(rates[i].close < rates[i+1].close) {
            price_uptrend = false;
            break;
        }
    }
    
    // Check for volume decrease along with price increase
    if(price_uptrend) {
        bool volume_decreasing = true;
        for(int i = 1; i < 4; i++) {
            if(g_volumes[i] < g_volumes[i+1]) {
                volume_decreasing = false;
                break;
            }
        }
        
        if(volume_decreasing) {
            DebugPrint("Negative volume-price divergence: price increase along with volume decrease (weakness in uptrend)");
            confirmations++;
        }
    }
    
    // Check for volume squeeze pattern before bearish move
    // Decrease in volume over several consecutive candles followed by a sudden increase in volume
    bool volume_squeeze = true;
    for(int i = 3; i < 6; i++) {
        if(g_volumes[i] > avg_volume * 0.7) {
            volume_squeeze = false;
            break;
        }
    }
    
    if(volume_squeeze && g_volumes[0] > avg_volume * 1.5 && rates[0].close < rates[0].open) {
        DebugPrint("Volume squeeze pattern before bearish move detected");
        confirmations++;
    }
    
    // Check for gradual volume increase in the downtrend
    bool falling_price = true;
    for(int i = 0; i < 3; i++) {
        if(rates[i].close > rates[i+1].close) {
            falling_price = false;
            break;
        }
    }
    
    bool rising_volume = true;
    for(int i = 0; i < 3; i++) {
        if(g_volumes[i] < g_volumes[i+1]) {
            rising_volume = false;
            break;
        }
    }
    
    if(falling_price && rising_volume) {
        DebugPrint("Gradual volume increase in the downtrend (confirmation of trend strength)");
        confirmations++;
    }
    
    DebugPrint("Number of confirmations for volume analysis for sell: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Safe function to call CheckVolumeAnalysisBuy                     |
//+------------------------------------------------------------------+
int SafeCheckVolumeAnalysisBuy(MqlRates &rates[])
{
    if(ArraySize(rates) < 20) {
        DebugPrint("The rates array for SafeCheckVolumeAnalysisBuy is smaller than the required size: " + IntegerToString(ArraySize(rates)));
        return 0;
    }
    
    return CheckVolumeAnalysisBuy(rates);
}

//+------------------------------------------------------------------+
//| Safe function to call CheckVolumeAnalysisShort                   |
//+------------------------------------------------------------------+
int SafeCheckVolumeAnalysisShort(MqlRates &rates[])
{
    if(ArraySize(rates) < 20) {
        DebugPrint("The rates array for SafeCheckVolumeAnalysisShort is smaller than the required size: " + IntegerToString(ArraySize(rates)));
        return 0;
    }
    
    return CheckVolumeAnalysisShort(rates);
}

// Function to check for volume confirmation for bullish move
bool CheckVolumeConfirmationBuy(const MqlRates &rates[], int size)
{
    // Need at least 10 bars for analysis
    if (size < 10)
        return false;
    
    // Calculate average volume over last 10 bars (excluding current)
    double averageVolume = 0;
    for (int i = 1; i <= 10; i++)
    {
        averageVolume += (double)rates[i].tick_volume;
    }
    averageVolume /= 10;
    
    // Check if current candle is bullish
    bool currentBullish = rates[0].close > rates[0].open;
    
    // Check for significant volume
    if (!currentBullish)
        return false;
    
    // Volume increasing on price rise (above average)
    if ((double)rates[0].tick_volume > averageVolume * 1.5)
        return true;
    
    // Check for three rising candles with increasing volume
    if (size >= 4 && 
        rates[0].close > rates[1].close &&
        rates[1].close > rates[2].close &&
        rates[2].close > rates[3].close &&
        rates[0].tick_volume > rates[1].tick_volume &&
        rates[1].tick_volume > rates[2].tick_volume)
        return true;
    
    // Check for bullish reversal with volume spike
    if (size >= 3 &&
        rates[2].close < rates[2].open && // Prior bearish
        rates[1].close < rates[1].open && // Prior bearish
        rates[0].close > rates[0].open && // Current bullish
        rates[0].tick_volume > averageVolume * 1.3 && // Increased volume
        rates[0].close > rates[1].high) // Breaking previous high
        return true;
    
    return false;
}

// Function to check for volume confirmation for bearish move
bool CheckVolumeConfirmationShort(const MqlRates &rates[], int size)
{
    // Need at least 10 bars for analysis
    if (size < 10)
        return false;
    
    // Calculate average volume over last 10 bars (excluding current)
    double averageVolume = 0;
    for (int i = 1; i <= 10; i++)
    {
        averageVolume += (double)rates[i].tick_volume;
    }
    averageVolume /= 10;
    
    // Check if current candle is bearish
    bool currentBearish = rates[0].close < rates[0].open;
    
    // Check for significant volume
    if (!currentBearish)
        return false;
    
    // Volume increasing on price fall (above average)
    if ((double)rates[0].tick_volume > averageVolume * 1.5)
        return true;
    
    // Check for three falling candles with increasing volume
    if (size >= 4 && 
        rates[0].close < rates[1].close &&
        rates[1].close < rates[2].close &&
        rates[2].close < rates[3].close &&
        rates[0].tick_volume > rates[1].tick_volume &&
        rates[1].tick_volume > rates[2].tick_volume)
        return true;
    
    // Check for bearish reversal with volume spike
    if (size >= 3 &&
        rates[2].close > rates[2].open && // Prior bullish
        rates[1].close > rates[1].open && // Prior bullish
        rates[0].close < rates[0].open && // Current bearish
        rates[0].tick_volume > averageVolume * 1.3 && // Increased volume
        rates[0].close < rates[1].low) // Breaking previous low
        return true;
    
    return false;
}

// Function to check for divergence between price and volume
bool CheckVolumePriceDivergence(const MqlRates &rates[], int size, bool lookForBuy)
{
    // Need at least 20 bars for analysis
    if (size < 20)
        return false;
    
    // Check for bullish divergence (falling price, falling volume)
    if (lookForBuy)
    {
        // Check for price making lower lows but volume making higher lows
        // Find two recent lows in price
        int low1 = -1, low2 = -1;
        
        for (int i = 1; i < 10 && i < size - 1; i++)
        {
            if (rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
            {
                low1 = i;
                break;
            }
        }
        
        if (low1 == -1)
            return false;
        
        for (int i = low1 + 3; i < low1 + 15 && i < size - 1; i++)
        {
            if (rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low)
            {
                low2 = i;
                break;
            }
        }
        
        if (low2 == -1)
            return false;
        
        // Check if price is making lower lows
        if (rates[low1].low >= rates[low2].low)
            return false;
        
        // Check if volume is NOT making lower lows (bullish divergence)
        if (rates[low1].tick_volume < rates[low2].tick_volume)
            return true;
    }
    else // Check for bearish divergence
    {
        // Check for price making higher highs but volume making lower highs
        // Find two recent highs in price
        int high1 = -1, high2 = -1;
        
        for (int i = 1; i < 10 && i < size - 1; i++)
        {
            if (rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
            {
                high1 = i;
                break;
            }
        }
        
        if (high1 == -1)
            return false;
        
        for (int i = high1 + 3; i < high1 + 15 && i < size - 1; i++)
        {
            if (rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high)
            {
                high2 = i;
                break;
            }
        }
        
        if (high2 == -1)
            return false;
        
        // Check if price is making higher highs
        if (rates[high1].high <= rates[high2].high)
            return false;
        
        // Check if volume is NOT making higher highs (bearish divergence)
        if (rates[high1].tick_volume > rates[high2].tick_volume)
            return true;
    }
    
    return false;
}

// Check if the volume is increasing or decreasing over a series of candles
bool IsVolumeIncreasing(const MqlRates &rates[], int period)
{
    if (period <= 1 || ArraySize(rates) < period + 1)
        return false;
    
    double sumVolume = 0;
    for (int i = 1; i <= period; i++)
    {
        sumVolume += (double)rates[i].tick_volume;
    }
    double avgVolume = sumVolume / period;
    
    return (double)rates[0].tick_volume > avgVolume * 1.2; // 20% above average
}

// Check for price/volume divergence (price up, volume down is bearish; price down, volume up is bullish)
bool CheckVolumePriceDivergence(const MqlRates &rates[], int period, bool &isBullish)
{
    if (period <= 3 || ArraySize(rates) < period + 1)
        return false;
    
    // Calculate price direction
    bool priceUp = (double)rates[0].close > (double)rates[period].close;
    
    // Check volume direction
    double recentVolumeSum = 0;
    double olderVolumeSum = 0;
    int halfPeriod = period / 2;
    
    for (int i = 0; i < halfPeriod; i++)
        recentVolumeSum += (double)rates[i].tick_volume;
    
    for (int i = halfPeriod; i < period; i++)
        olderVolumeSum += (double)rates[i].tick_volume;
    
    double recentAvgVolume = recentVolumeSum / halfPeriod;
    double olderAvgVolume = olderVolumeSum / (period - halfPeriod);
    
    bool volumeUp = recentAvgVolume > olderAvgVolume;
    
    // Check for divergence
    if (priceUp && !volumeUp)
    {
        // Bearish divergence (price up, volume down)
        isBullish = false;
        return true;
    }
    else if (!priceUp && volumeUp)
    {
        // Bullish divergence (price down, volume up)
        isBullish = true;
        return true;
    }
    
    return false;
}

// Check for volume breakout (significantly higher volume than recent average)
bool IsVolumeBreakout(const MqlRates &rates[], int lookback)
{
    if (lookback < 5 || ArraySize(rates) < lookback + 1)
        return false;
    
    double volumeSum = 0;
    for (int i = 1; i <= lookback; i++)
    {
        volumeSum += (double)rates[i].tick_volume;
    }
    
    double avgVolume = volumeSum / lookback;
    
    // Check if current volume is significantly higher than the average
    return (double)rates[0].tick_volume > avgVolume * 1.5; // 50% higher than average
}

// Check if high volume is confirming price movement
bool IsVolumeConfirmingPrice(const MqlRates &rates[], int barsToCheck)
{
    if (barsToCheck < 3 || ArraySize(rates) < barsToCheck)
        return false;
    
    // Determine price direction
    bool isUptrend = (double)rates[0].close > (double)rates[barsToCheck-1].close;
    
    // Count bullish and bearish candles
    int bullishCount = 0;
    int bearishCount = 0;
    double bullishVolume = 0;
    double bearishVolume = 0;
    
    for (int i = 0; i < barsToCheck; i++)
    {
        if (rates[i].close > rates[i].open)
        {
            bullishCount++;
            bullishVolume += (double)rates[i].tick_volume;
        }
        else if (rates[i].close < rates[i].open)
        {
            bearishCount++;
            bearishVolume += (double)rates[i].tick_volume;
        }
    }
    
    // Calculate average volume for bullish and bearish candles
    double avgBullishVolume = (bullishCount > 0) ? bullishVolume / bullishCount : 0;
    double avgBearishVolume = (bearishCount > 0) ? bearishVolume / bearishCount : 0;
    
    // Check if volume confirms price direction
    if (isUptrend && avgBullishVolume > avgBearishVolume * 1.2)
        return true; // In uptrend, bullish candles have higher volume
    
    if (!isUptrend && avgBearishVolume > avgBullishVolume * 1.2)
        return true; // In downtrend, bearish candles have higher volume
    
    return false;
}

// Check for climactic volume (extremely high volume that might indicate a trend reversal)
bool IsClimacticVolume(const MqlRates &rates[], int lookback, bool &isExhaustion)
{
    if (lookback < 10 || ArraySize(rates) < lookback + 1)
        return false;
    
    double volumeSum = 0;
    for (int i = 1; i <= lookback; i++)
    {
        volumeSum += (double)rates[i].tick_volume;
    }
    
    double avgVolume = volumeSum / lookback;
    
    // Check for extremely high volume
    if ((double)rates[0].tick_volume > avgVolume * 2) // 100% higher than average
    {
        // Determine if this is likely an exhaustion move
        // Typically, exhaustion happens after a strong trend
        
        // Check if there was a strong trend
        bool priorUptrend = (double)rates[5].close > (double)rates[lookback].close;
        
        // For exhaustion in uptrend, we expect a high volume bar with a close below open
        // For exhaustion in downtrend, we expect a high volume bar with a close above open
        if (priorUptrend && rates[0].close < rates[0].open)
        {
            isExhaustion = true;
            return true;
        }
        else if (!priorUptrend && rates[0].close > rates[0].open)
        {
            isExhaustion = true;
            return true;
        }
        
        // Otherwise, it's just high volume without exhaustion signs
        isExhaustion = false;
        return true;
    }
    
    return false;
}

// Check for Chaikin Money Flow (CMF) - a technical indicator measuring Money Flow Volume over a period
double CalculateChaikinMoneyFlow(const MqlRates &rates[], int period)
{
    if (period < 3 || ArraySize(rates) < period)
        return 0.0;
    
    double sumMoneyFlowVolume = 0;
    double sumVolume = 0;
    
    for (int i = 0; i < period; i++)
    {
        // Calculate Money Flow Multiplier
        double high = rates[i].high;
        double low = rates[i].low;
        double close = rates[i].close;
        double range = high - low;
        
        double moneyFlowMultiplier = 0;
        if (range > 0)
            moneyFlowMultiplier = ((close - low) - (high - close)) / range;
        
        // Calculate Money Flow Volume
        double moneyFlowVolume = moneyFlowMultiplier * (double)rates[i].tick_volume;
        
        sumMoneyFlowVolume += moneyFlowVolume;
        sumVolume += (double)rates[i].tick_volume;
    }
    
    if (sumVolume > 0)
        return sumMoneyFlowVolume / sumVolume;
    else
        return 0.0;
}

// Check if Chaikin Money Flow is indicating a buy signal
bool IsChaikinMoneyFlowBuy(const MqlRates &rates[], int period)
{
    if (period < 3 || ArraySize(rates) < period * 2)
        return false;
    
    double currentCMF = CalculateChaikinMoneyFlow(rates, period);
    
    // Check if CMF is above zero (positive money flow)
    if (currentCMF > 0.05) // Threshold for significant positive money flow
        return true;
    
    // Create a temporary array to hold the shifted rates
    MqlRates temp_rates[];
    ArrayCopy(temp_rates, rates, 0, 1, ArraySize(rates)-1);
    
    // Check for CMF crossing above zero
    double previousCMF = CalculateChaikinMoneyFlow(temp_rates, period);
    if (previousCMF < 0 && currentCMF > 0)
        return true;
    
    return false;
}

// Check if Chaikin Money Flow is indicating a sell signal
bool IsChaikinMoneyFlowSell(const MqlRates &rates[], int period)
{
    if (period < 3 || ArraySize(rates) < period * 2)
        return false;
    
    double currentCMF = CalculateChaikinMoneyFlow(rates, period);
    
    // Check if CMF is below zero (negative money flow)
    if (currentCMF < -0.05) // Threshold for significant negative money flow
        return true;
    
    // Create a temporary array to hold the shifted rates
    MqlRates temp_rates[];
    ArrayCopy(temp_rates, rates, 0, 1, ArraySize(rates)-1);
    
    // Check for CMF crossing below zero
    double previousCMF = CalculateChaikinMoneyFlow(temp_rates, period);
    if (previousCMF > 0 && currentCMF < 0)
        return true;
    
    return false;
}

// Calculate Volume Moving Average
double CalculateVolumeMA(double &volume[], int ma_period, int shift = 0)
{
    // Check if we have enough data
    if (ArraySize(volume) < ma_period + shift)
        return 0.0;
    
    double sum = 0.0;
    for (int i = shift; i < ma_period + shift; i++)
    {
        sum += volume[i];
    }
    
    return sum / ma_period;
}

// Check for volume expansion (current volume significantly higher than average)
bool IsVolumeExpansion(double &volume[], int ma_period, double expansion_factor, int shift = 0)
{
    if (ArraySize(volume) <= shift)
        return false;
    
    double volume_ma = CalculateVolumeMA(volume, ma_period, shift + 1);
    
    // Check if current volume is significantly higher than the average
    return (volume[shift] > volume_ma * expansion_factor);
}

// Check for volume contraction (current volume significantly lower than average)
bool IsVolumeContraction(double &volume[], int ma_period, double contraction_factor, int shift = 0)
{
    if (ArraySize(volume) <= shift)
        return false;
    
    double volume_ma = CalculateVolumeMA(volume, ma_period, shift + 1);
    
    // Check if current volume is significantly lower than the average
    return (volume[shift] < volume_ma * contraction_factor);
}

// Check for volume climax (extremely high volume indicating potential trend exhaustion)
bool IsVolumeClimax(double &volume[], int lookback_period, double climax_factor, int shift = 0)
{
    if (ArraySize(volume) < lookback_period + shift)
        return false;
    
    // Find the maximum volume in the lookback period
    double max_volume = 0.0;
    for (int i = shift + 1; i < lookback_period + shift; i++)
    {
        if (volume[i] > max_volume)
            max_volume = volume[i];
    }
    
    // Check if current volume is extremely high compared to the maximum
    return (volume[shift] > max_volume * climax_factor);
}

// Check for volume divergence with price (price making new highs/lows but volume decreasing)
bool IsPriceVolumeDivergence(double &price_high[], double &price_low[], double &volume[], int shift = 0)
{
    if (ArraySize(price_high) < 2 + shift || ArraySize(price_low) < 2 + shift || ArraySize(volume) < 2 + shift)
        return false;
    
    // Check for price making a new high but volume decreasing
    bool price_new_high = price_high[shift] > price_high[shift + 1];
    bool volume_decreasing = volume[shift] < volume[shift + 1];
    
    // Check for price making a new low but volume decreasing
    bool price_new_low = price_low[shift] < price_low[shift + 1];
    
    // Return true if there's a divergence
    return (price_new_high && volume_decreasing) || (price_new_low && volume_decreasing);
}

// Check for volume confirmation of price movement
bool IsVolumeConfirmingPrice(double &price_open[], double &price_close[], double &volume[], 
                             int ma_period, double confirmation_factor, int shift = 0)
{
    if (ArraySize(price_open) <= shift || ArraySize(price_close) <= shift || ArraySize(volume) <= shift)
        return false;
    
    double volume_ma = CalculateVolumeMA(volume, ma_period, shift + 1);
    
    // Determine if the price is going up or down
    bool price_up = price_close[shift] > price_open[shift];
    
    // Check if volume is confirming the price movement
    // For an up move, we want higher than average volume
    // For a down move, higher volume also confirms the move
    return (price_up && volume[shift] > volume_ma * confirmation_factor) || 
           (!price_up && volume[shift] > volume_ma * confirmation_factor);
}

// Check for a churn bar (high volume with small price range, indicating potential reversal)
bool IsChurnBar(double &price_high[], double &price_low[], double &price_open[], double &price_close[], 
                double &volume[], int ma_period, double churn_range_factor, double churn_volume_factor, int shift = 0)
{
    if (ArraySize(price_high) <= shift || ArraySize(price_low) <= shift || 
        ArraySize(price_open) <= shift || ArraySize(price_close) <= shift || ArraySize(volume) <= shift)
        return false;
    
    // Calculate price range
    double price_range = price_high[shift] - price_low[shift];
    
    // Calculate average price range
    double sum_range = 0.0;
    for (int i = shift + 1; i < ma_period + shift + 1; i++)
    {
        if (i >= ArraySize(price_high) || i >= ArraySize(price_low))
            break;
        
        sum_range += (price_high[i] - price_low[i]);
    }
    double avg_range = sum_range / ma_period;
    
    // Calculate average volume
    double volume_ma = CalculateVolumeMA(volume, ma_period, shift + 1);
    
    // Check for a churn bar: small range with high volume
    return (price_range < avg_range * churn_range_factor && volume[shift] > volume_ma * churn_volume_factor);
}

// Check for volume breakout (high volume with price breaking a level)
bool IsVolumeBreakout(double &price_close[], double &volume[], double level, bool break_above, 
                     int ma_period, double breakout_factor, int shift = 0)
{
    if (ArraySize(price_close) <= shift || ArraySize(volume) <= shift)
        return false;
    
    double volume_ma = CalculateVolumeMA(volume, ma_period, shift + 1);
    
    // Check if price is breaking above or below the level with high volume
    if (break_above)
        return (price_close[shift] > level && price_close[shift + 1] <= level && 
                volume[shift] > volume_ma * breakout_factor);
    else
        return (price_close[shift] < level && price_close[shift + 1] >= level && 
                volume[shift] > volume_ma * breakout_factor);
}

// Check for decreasing volume in a trend (potential trend weakness)
bool IsDecreasingVolumeInTrend(double &price_close[], double &volume[], int trend_length, int shift = 0)
{
    if (ArraySize(price_close) < trend_length + shift || ArraySize(volume) < trend_length + shift)
        return false;
    
    // Determine if we're in an uptrend or downtrend
    bool uptrend = true;
    for (int i = shift; i < trend_length + shift - 1; i++)
    {
        if (price_close[i] < price_close[i + 1])
        {
            uptrend = false;
            break;
        }
    }
    
    bool downtrend = true;
    for (int i = shift; i < trend_length + shift - 1; i++)
    {
        if (price_close[i] > price_close[i + 1])
        {
            downtrend = false;
            break;
        }
    }
    
    // If we're not in a clear trend, return false
    if (!uptrend && !downtrend)
        return false;
    
    // Check if volume is decreasing in the trend
    bool volume_decreasing = true;
    for (int i = shift; i < trend_length + shift - 1; i++)
    {
        if (volume[i] > volume[i + 1])
        {
            volume_decreasing = false;
            break;
        }
    }
    
    return volume_decreasing;
}

// Volume-based buy signal
bool CheckVolumeBasedBuySignal(double &price_high[], double &price_low[], double &price_open[], 
                               double &price_close[], double &volume[], int ma_period, 
                               double expansion_factor, int shift = 0)
{
    // Check for bullish price action with volume expansion
    bool bullish_candle = price_close[shift] > price_open[shift];
    bool volume_expansion = IsVolumeExpansion(volume, ma_period, expansion_factor, shift);
    
    // Check for volume breakout above a resistance level (using recent high)
    double recent_high = price_high[shift + 1];
    bool volume_breakout = IsVolumeBreakout(price_close, volume, recent_high, true, ma_period, expansion_factor, shift);
    
    // Return true if we have a bullish candle with volume expansion or a volume breakout
    return (bullish_candle && volume_expansion) || volume_breakout;
}

// Volume-based sell signal
bool CheckVolumeBasedSellSignal(double &price_high[], double &price_low[], double &price_open[], 
                                double &price_close[], double &volume[], int ma_period, 
                                double expansion_factor, int shift = 0)
{
    // Check for bearish price action with volume expansion
    bool bearish_candle = price_close[shift] < price_open[shift];
    bool volume_expansion = IsVolumeExpansion(volume, ma_period, expansion_factor, shift);
    
    // Check for volume breakout below a support level (using recent low)
    double recent_low = price_low[shift + 1];
    bool volume_breakout = IsVolumeBreakout(price_close, volume, recent_low, false, ma_period, expansion_factor, shift);
    
    // Return true if we have a bearish candle with volume expansion or a volume breakout
    return (bearish_candle && volume_expansion) || volume_breakout;
}

// Calculate average volume over a specified period
double CalculateAverageVolume(MqlRates &rates[], int start_index, int period)
{
    if (start_index < 0 || period <= 0 || start_index + period > ArraySize(rates))
        return 0.0;
    
    double total_volume = 0.0;
    
    for (int i = start_index; i < start_index + period; i++) {
        total_volume += (double)rates[i].tick_volume;
    }
    
    return total_volume / period;
}

// Check if the volume is significantly above average
bool IsVolumeAboveAverage(MqlRates &rates[], int index, int period, double threshold_multiplier)
{
    if (index < period || index >= ArraySize(rates))
        return false;
    
    double avg_volume = CalculateAverageVolume(rates, index - period, period);
    
    if (avg_volume <= 0)
        return false;
    
    double current_volume = (double)rates[index].tick_volume;
    
    return (current_volume > avg_volume * threshold_multiplier);
}

// Check if the volume is significantly below average
bool IsVolumeBelowAverage(MqlRates &rates[], int index, int period, double threshold_multiplier)
{
    if (index < period || index >= ArraySize(rates))
        return false;
    
    double avg_volume = CalculateAverageVolume(rates, index - period, period);
    
    if (avg_volume <= 0)
        return false;
    
    double current_volume = (double)rates[index].tick_volume;
    
    return (current_volume < avg_volume * threshold_multiplier);
}

// Check for volume divergence from price (price rising, volume falling or vice versa)
bool IsVolumePriceDivergence(MqlRates &rates[], int index, int period)
{
    if (index < period || index >= ArraySize(rates))
        return false;
    
    // Determine price direction (using close prices)
    double first_price = rates[index - period].close;
    double last_price = rates[index].close;
    bool price_rising = (last_price > first_price);
    
    // Determine volume direction
    double first_volume = (double)rates[index - period].tick_volume;
    double last_volume = (double)rates[index].tick_volume;
    bool volume_rising = (last_volume > first_volume);
    
    // Check for divergence (price up but volume down, or price down but volume up)
    return (price_rising && !volume_rising) || (!price_rising && volume_rising);
}

// Check for volume confirmation of price movement (price and volume moving in same direction)
bool IsVolumeConfirmation(MqlRates &rates[], int index, int period)
{
    if (index < period || index >= ArraySize(rates))
        return false;
    
    // Determine price direction (using close prices)
    double first_price = rates[index - period].close;
    double last_price = rates[index].close;
    bool price_rising = (last_price > first_price);
    
    // Determine volume direction
    double first_volume = (double)rates[index - period].tick_volume;
    double last_volume = (double)rates[index].tick_volume;
    bool volume_rising = (last_volume > first_volume);
    
    // Check for confirmation (price and volume moving in same direction)
    return (price_rising && volume_rising) || (!price_rising && !volume_rising);
}

// Check for volume spike (sudden large increase in volume)
bool IsVolumeSpike(MqlRates &rates[], int index, int period, double threshold_multiplier)
{
    return IsVolumeAboveAverage(rates, index, period, threshold_multiplier);
}

// Check for volume climax (extremely high volume that might indicate exhaustion)
bool IsVolumeClimax(MqlRates &rates[], int index, int period, double threshold_multiplier)
{
    if (index < period || index >= ArraySize(rates))
        return false;
    
    // Check for extremely high volume
    if (!IsVolumeAboveAverage(rates, index, period, threshold_multiplier))
        return false;
    
    // Look for price exhaustion (small or doji candle)
    double body_size = MathAbs(rates[index].close - rates[index].open);
    double candle_size = rates[index].high - rates[index].low;
    
    // If the body is very small compared to the total candle size, it might be exhaustion
    return (body_size < candle_size * 0.3);
}

// Calculate On-Balance Volume (OBV)
double CalculateOBV(MqlRates &rates[], int index, int period)
{
    if (index < period || index >= ArraySize(rates))
        return 0.0;
    
    double obv = 0.0;
    
    for (int i = index - period + 1; i <= index; i++) {
        if (i <= 0)
            continue;
        
        double close_diff = rates[i].close - rates[i-1].close;
        
        if (close_diff > 0)
            obv += (double)rates[i].tick_volume;
        else if (close_diff < 0)
            obv -= (double)rates[i].tick_volume;
        // If close_diff == 0, OBV doesn't change
    }
    
    return obv;
}

// Check for rising OBV (potentially bullish)
bool IsOBVRising(MqlRates &rates[], int index, int period)
{
    if (index < period + 1 || index >= ArraySize(rates))
        return false;
    
    double current_obv = CalculateOBV(rates, index, period);
    double previous_obv = CalculateOBV(rates, index - 1, period);
    
    return (current_obv > previous_obv);
}

// Check for falling OBV (potentially bearish)
bool IsOBVFalling(MqlRates &rates[], int index, int period)
{
    if (index < period + 1 || index >= ArraySize(rates))
        return false;
    
    double current_obv = CalculateOBV(rates, index, period);
    double previous_obv = CalculateOBV(rates, index - 1, period);
    
    return (current_obv < previous_obv);
}

// Check for OBV divergence with price
bool IsOBVDivergence(MqlRates &rates[], int index, int period)
{
    if (index < period + 1 || index >= ArraySize(rates))
        return false;
    
    // Determine price direction (using close prices)
    double first_price = rates[index - period].close;
    double last_price = rates[index].close;
    bool price_rising = (last_price > first_price);
    
    // Determine OBV direction
    double first_obv = CalculateOBV(rates, index - period, period);
    double last_obv = CalculateOBV(rates, index, period);
    bool obv_rising = (last_obv > first_obv);
    
    // Check for divergence (price up but OBV down, or price down but OBV up)
    return (price_rising && !obv_rising) || (!price_rising && obv_rising);
}

// Calculate Money Flow Index (MFI) - a volume-weighted RSI
double CalculateMFI(MqlRates &rates[], int index, int period)
{
    if (index < period || index >= ArraySize(rates))
        return 50.0; // Return neutral value
    
    double positive_money_flow = 0.0;
    double negative_money_flow = 0.0;
    
    for (int i = index - period + 1; i <= index; i++) {
        if (i <= 0)
            continue;
        
        // Calculate typical price for current and previous bars
        double typical_price_current = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
        double typical_price_prev = (rates[i-1].high + rates[i-1].low + rates[i-1].close) / 3.0;
        
        // Calculate raw money flow
        double raw_money_flow = typical_price_current * (double)rates[i].tick_volume;
        
        // Accumulate positive or negative money flow
        if (typical_price_current > typical_price_prev)
            positive_money_flow += raw_money_flow;
        else if (typical_price_current < typical_price_prev)
            negative_money_flow += raw_money_flow;
    }
    
    // Avoid division by zero
    if (negative_money_flow == 0)
        return 100.0;
    
    if (positive_money_flow == 0)
        return 0.0;
    
    // Calculate money flow ratio and MFI
    double money_flow_ratio = positive_money_flow / negative_money_flow;
    double mfi = 100.0 - (100.0 / (1.0 + money_flow_ratio));
    
    return mfi;
}

// Check for oversold MFI condition (potentially bullish)
bool IsMFIOversold(MqlRates &rates[], int index, int period, double threshold = 20.0)
{
    if (index < period || index >= ArraySize(rates))
        return false;
    
    double mfi = CalculateMFI(rates, index, period);
    
    return (mfi < threshold);
}

// Check for overbought MFI condition (potentially bearish)
bool IsMFIOverbought(MqlRates &rates[], int index, int period, double threshold = 80.0)
{
    if (index < period || index >= ArraySize(rates))
        return false;
    
    double mfi = CalculateMFI(rates, index, period);
    
    return (mfi > threshold);
}

// Calculate Accumulation/Distribution Line
double CalculateAccumulationDistribution(MqlRates &rates[], int index, int period)
{
    if (index < period || index >= ArraySize(rates))
        return 0.0;
    
    double ad_line = 0.0;
    
    for (int i = index - period + 1; i <= index; i++) {
        if (i < 0)
            continue;
        
        // Calculate Money Flow Multiplier
        double high_low_range = rates[i].high - rates[i].low;
        
        // Avoid division by zero
        if (high_low_range == 0)
            continue;
        
        double close_loc = ((rates[i].close - rates[i].low) - (rates[i].high - rates[i].close)) / high_low_range;
        
        // Calculate Money Flow Volume
        double money_flow_volume = close_loc * (double)rates[i].tick_volume;
        
        // Add to A/D Line
        ad_line += money_flow_volume;
    }
    
    return ad_line;
}

// Check for rising A/D Line (potentially bullish)
bool IsADLineRising(MqlRates &rates[], int index, int period)
{
    if (index < period + 1 || index >= ArraySize(rates))
        return false;
    
    double current_ad = CalculateAccumulationDistribution(rates, index, period);
    double previous_ad = CalculateAccumulationDistribution(rates, index - 1, period);
    
    return (current_ad > previous_ad);
}

// Check for falling A/D Line (potentially bearish)
bool IsADLineFalling(MqlRates &rates[], int index, int period)
{
    if (index < period + 1 || index >= ArraySize(rates))
        return false;
    
    double current_ad = CalculateAccumulationDistribution(rates, index, period);
    double previous_ad = CalculateAccumulationDistribution(rates, index - 1, period);
    
    return (current_ad < previous_ad);
}

// Check for A/D Line divergence with price
bool IsADLineDivergence(MqlRates &rates[], int index, int period)
{
    if (index < period + 1 || index >= ArraySize(rates))
        return false;
    
    // Determine price direction (using close prices)
    double first_price = rates[index - period].close;
    double last_price = rates[index].close;
    bool price_rising = (last_price > first_price);
    
    // Determine A/D Line direction
    double first_ad = CalculateAccumulationDistribution(rates, index - period, period);
    double last_ad = CalculateAccumulationDistribution(rates, index, period);
    bool ad_rising = (last_ad > first_ad);
    
    // Check for divergence
    return (price_rising && !ad_rising) || (!price_rising && ad_rising);
}

// Check for volume drying up (potentially signaling a reversal)
bool IsVolumeDryingUp(MqlRates &rates[], int index, int period, int consecutive_bars)
{
    if (index < period + consecutive_bars - 1 || index >= ArraySize(rates))
        return false;
    
    // Check for a series of consecutively lower volumes
    for (int i = 1; i < consecutive_bars; i++) {
        if (rates[index - i + 1].tick_volume >= rates[index - i].tick_volume)
            return false;
    }
    
    return true;
}

// Comprehensive check for bullish volume patterns
bool CheckVolumeBuySignal(MqlRates &rates[], int index, int volume_period, 
                         double volume_threshold, bool check_divergence,
                         bool check_obv, bool check_mfi, bool check_adline)
{
    if (index < volume_period || index >= ArraySize(rates))
        return false;
    
    bool signal = false;
    
    // Check for high volume on an up bar
    if (rates[index].close > rates[index].open && 
        IsVolumeAboveAverage(rates, index, volume_period, volume_threshold)) {
        signal = true;
    }
    
    // Check for volume/price divergence (bearish to bullish)
    if (check_divergence && IsVolumePriceDivergence(rates, index, volume_period)) {
        // Make sure it's the right kind of divergence (price down, volume up)
        if (rates[index].close < rates[index - volume_period].close && 
            rates[index].tick_volume > rates[index - volume_period].tick_volume) {
            signal = true;
        }
    }
    
    // Check for bullish OBV signal
    if (check_obv && IsOBVRising(rates, index, volume_period)) {
        signal = true;
    }
    
    // Check for bullish MFI signal (oversold)
    if (check_mfi && IsMFIOversold(rates, index, volume_period)) {
        signal = true;
    }
    
    // Check for bullish A/D Line signal
    if (check_adline && IsADLineRising(rates, index, volume_period)) {
        signal = true;
    }
    
    return signal;
}

// Comprehensive check for bearish volume patterns
bool CheckVolumeSellSignal(MqlRates &rates[], int index, int volume_period, 
                          double volume_threshold, bool check_divergence,
                          bool check_obv, bool check_mfi, bool check_adline)
{
    if (index < volume_period || index >= ArraySize(rates))
        return false;
    
    bool signal = false;
    
    // Check for high volume on a down bar
    if (rates[index].close < rates[index].open && 
        IsVolumeAboveAverage(rates, index, volume_period, volume_threshold)) {
        signal = true;
    }
    
    // Check for volume/price divergence (bullish to bearish)
    if (check_divergence && IsVolumePriceDivergence(rates, index, volume_period)) {
        // Make sure it's the right kind of divergence (price up, volume down)
        if (rates[index].close > rates[index - volume_period].close && 
            rates[index].tick_volume < rates[index - volume_period].tick_volume) {
            signal = true;
        }
    }
    
    // Check for bearish OBV signal
    if (check_obv && IsOBVFalling(rates, index, volume_period)) {
        signal = true;
    }
    
    // Check for bearish MFI signal (overbought)
    if (check_mfi && IsMFIOverbought(rates, index, volume_period)) {
        signal = true;
    }
    
    // Check for bearish A/D Line signal
    if (check_adline && IsADLineFalling(rates, index, volume_period)) {
        signal = true;
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Check CMF for buy                                               |
//+------------------------------------------------------------------+
bool IsCMFBullish(MqlRates &rates[])
{
    double cmf = CalculateChaikinMoneyFlow(rates, 20);
    
    if(cmf > 0.05) {
        DebugPrint("Chaikin Money Flow is in the positive zone: " + DoubleToString(cmf, 5));
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check CMF for sell                                               |
//+------------------------------------------------------------------+
bool IsCMFBearish(MqlRates &rates[])
{
    double cmf = CalculateChaikinMoneyFlow(rates, 20);
    
    if(cmf < -0.05) {
        DebugPrint("Chaikin Money Flow is in the negative zone: " + DoubleToString(cmf, 5));
        return true;
    }
    
    return false;
} 