//+------------------------------------------------------------------+
//|                                          SignalQualityFilter.mqh |
//|                                      Copyright 2024, Gold Trader |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Gold Trader"
#property strict

// Import DebugPrint from main EA
#import "GoldTraderEA.mq5"
   void DebugPrint(string message);
#import

//+------------------------------------------------------------------+
//| Signal Quality Metrics Structure                                 |
//+------------------------------------------------------------------+
struct SignalQuality
{
   double strength_score;        // 0-100: Overall signal strength
   double reliability_score;     // 0-100: Historical reliability
   double context_score;         // 0-100: Market context alignment
   double timing_score;          // 0-100: Entry timing quality
   bool is_valid;                // Overall validity flag
   string rejection_reason;      // Why signal was rejected (if applicable)
};

//+------------------------------------------------------------------+
//| False Positive Detection Parameters (calibrated constants)       |
//+------------------------------------------------------------------+
const double   FP_Min_Signal_Strength = 60.0;        // Minimum signal strength 0-100 (calibrated)
const double   FP_Min_Reliability_Score = 50.0;      // Minimum reliability score 0-100 (calibrated)
const double   FP_Min_Context_Score = 40.0;          // Minimum context alignment score 0-100 (calibrated)
const double   FP_Min_Timing_Score = 50.0;           // Minimum timing quality score 0-100 (calibrated)
const bool     FP_Require_Volume_Confirmation = true; // Require volume confirmation (best practice)
const bool     FP_Require_Momentum_Alignment = true;  // Require momentum alignment (best practice)
const double   FP_Max_Spread_Pips = 3.0;             // Maximum spread in pips to allow trading (calibrated)
const int      FP_Min_Candles_Since_News = 5;        // Minimum candles since major news event (calibrated)

//+------------------------------------------------------------------+
//| Evaluate Signal Quality - Main Entry Point                       |
//+------------------------------------------------------------------+
SignalQuality EvaluateSignalQuality(bool isBuy, MqlRates &rates[], string strategy_name)
{
   SignalQuality quality;
   quality.is_valid = false;
   quality.rejection_reason = "";
   
   // Initialize scores
   quality.strength_score = 0;
   quality.reliability_score = 0;
   quality.context_score = 0;
   quality.timing_score = 0;
   
   // 1. Check basic market conditions first (fast rejection)
   if(!CheckBasicMarketConditions(isBuy, rates, quality))
      return quality;
   
   // 2. Evaluate signal strength
   quality.strength_score = CalculateSignalStrength(isBuy, rates, strategy_name);
   if(quality.strength_score < FP_Min_Signal_Strength)
   {
      quality.rejection_reason = "Signal strength too low: " + DoubleToString(quality.strength_score, 1);
      return quality;
   }
   
   // 3. Evaluate market context alignment
   quality.context_score = CalculateContextScore(isBuy, rates);
   if(quality.context_score < FP_Min_Context_Score)
   {
      quality.rejection_reason = "Poor market context: " + DoubleToString(quality.context_score, 1);
      return quality;
   }
   
   // 4. Evaluate entry timing quality
   quality.timing_score = CalculateTimingScore(isBuy, rates);
   if(quality.timing_score < FP_Min_Timing_Score)
   {
      quality.rejection_reason = "Poor entry timing: " + DoubleToString(quality.timing_score, 1);
      return quality;
   }
   
   // 5. Calculate reliability based on recent performance
   quality.reliability_score = CalculateReliabilityScore(strategy_name);
   if(quality.reliability_score < FP_Min_Reliability_Score)
   {
      quality.rejection_reason = "Low strategy reliability: " + DoubleToString(quality.reliability_score, 1);
      return quality;
   }
   
   // All checks passed
   quality.is_valid = true;
   return quality;
}

//+------------------------------------------------------------------+
//| Check Basic Market Conditions (Fast Rejection)                   |
//+------------------------------------------------------------------+
bool CheckBasicMarketConditions(bool isBuy, MqlRates &rates[], SignalQuality &quality)
{
   int size = ArraySize(rates);
   if(size < 10)
   {
      quality.rejection_reason = "Insufficient data";
      return false;
   }
   
   // 1. Check spread
   double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double spread_pips = spread / (SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10);
   
   if(spread_pips > FP_Max_Spread_Pips)
   {
      quality.rejection_reason = "Spread too wide: " + DoubleToString(spread_pips, 1) + " pips";
      return false;
   }
   
   // 2. Check for extreme volatility (potential whipsaw)
   double atr_current = CalculateATR(rates, 14, 0);
   double atr_average = CalculateATR(rates, 14, 10);
   
   if(atr_current > atr_average * 2.5)
   {
      quality.rejection_reason = "Extreme volatility detected";
      return false;
   }
   
   // 3. Check for choppy/ranging market (high false positive environment)
   if(IsChoppyMarket(rates))
   {
      quality.rejection_reason = "Choppy/ranging market detected";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Signal Strength Score (0-100)                          |
//+------------------------------------------------------------------+
double CalculateSignalStrength(bool isBuy, MqlRates &rates[], string strategy_name)
{
   double score = 0;
   int size = ArraySize(rates);
   
   // 1. Pattern clarity (20 points)
   score += EvaluatePatternClarity(isBuy, rates, strategy_name);
   
   // 2. Volume confirmation (20 points)
   if(FP_Require_Volume_Confirmation)
      score += EvaluateVolumeConfirmation(isBuy, rates);
   else
      score += 20; // Give full points if not required
   
   // 3. Price action alignment (20 points)
   score += EvaluatePriceActionAlignment(isBuy, rates);
   
   // 4. Momentum strength (20 points)
   if(FP_Require_Momentum_Alignment)
      score += EvaluateMomentumStrength(isBuy, rates);
   else
      score += 20; // Give full points if not required
   
   // 5. Support/Resistance proximity (20 points)
   score += EvaluateSRProximity(isBuy, rates);
   
   return MathMin(100, score);
}

//+------------------------------------------------------------------+
//| Calculate Market Context Score (0-100)                           |
//+------------------------------------------------------------------+
double CalculateContextScore(bool isBuy, MqlRates &rates[])
{
   double score = 0;
   
   // 1. Trend alignment (30 points)
   score += EvaluateTrendAlignment(isBuy, rates);
   
   // 2. Market structure (30 points)
   score += EvaluateMarketStructure(isBuy, rates);
   
   // 3. Time of day quality (20 points)
   score += EvaluateTimeOfDay();
   
   // 4. Recent price behavior (20 points)
   score += EvaluateRecentBehavior(isBuy, rates);
   
   return MathMin(100, score);
}

//+------------------------------------------------------------------+
//| Calculate Entry Timing Score (0-100)                             |
//+------------------------------------------------------------------+
double CalculateTimingScore(bool isBuy, MqlRates &rates[])
{
   double score = 0;
   
   // 1. Candle position in pattern (30 points)
   score += EvaluateCandlePosition(isBuy, rates);
   
   // 2. Pullback quality (30 points)
   score += EvaluatePullbackQuality(isBuy, rates);
   
   // 3. Breakout confirmation (20 points)
   score += EvaluateBreakoutConfirmation(isBuy, rates);
   
   // 4. Divergence from extremes (20 points)
   score += EvaluateDistanceFromExtremes(isBuy, rates);
   
   return MathMin(100, score);
}

//+------------------------------------------------------------------+
//| Calculate Strategy Reliability Score (0-100)                     |
//+------------------------------------------------------------------+
double CalculateReliabilityScore(string strategy_name)
{
   // This would ideally track historical performance per strategy
   // For now, return a baseline score
   // TODO: Implement performance tracking system
   
   return 70.0; // Baseline reliability
}

//+------------------------------------------------------------------+
//| Helper: Calculate ATR                                            |
//+------------------------------------------------------------------+
double CalculateATR(MqlRates &rates[], int period, int shift)
{
   if(ArraySize(rates) < period + shift + 1)
      return 0;
   
   double sum = 0;
   for(int i = shift; i < period + shift; i++)
   {
      double high_low = rates[i].high - rates[i].low;
      double high_close = MathAbs(rates[i].high - rates[i+1].close);
      double low_close = MathAbs(rates[i].low - rates[i+1].close);
      
      double tr = MathMax(high_low, MathMax(high_close, low_close));
      sum += tr;
   }
   
   return sum / period;
}

//+------------------------------------------------------------------+
//| Helper: Detect Choppy Market                                     |
//+------------------------------------------------------------------+
bool IsChoppyMarket(MqlRates &rates[])
{
   int size = ArraySize(rates);
   if(size < 20) return false;
   
   // Calculate ADX-like measure
   int direction_changes = 0;
   bool last_direction = (rates[1].close > rates[2].close);
   
   for(int i = 2; i < 20; i++)
   {
      bool current_direction = (rates[i].close > rates[i+1].close);
      if(current_direction != last_direction)
         direction_changes++;
      last_direction = current_direction;
   }
   
   // If more than 12 direction changes in 20 candles, market is choppy
   return (direction_changes > 12);
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Pattern Clarity                                 |
//+------------------------------------------------------------------+
double EvaluatePatternClarity(bool isBuy, MqlRates &rates[], string strategy_name)
{
   // Pattern-specific clarity checks
   // This is a simplified version - expand based on specific patterns
   
   int size = ArraySize(rates);
   if(size < 5) return 0;
   
   double score = 10; // Base score
   
   // Check for clean price action (no excessive wicks)
   double avg_body_ratio = 0;
   for(int i = 0; i < 5; i++)
   {
      double body = MathAbs(rates[i].close - rates[i].open);
      double total = rates[i].high - rates[i].low;
      if(total > 0)
         avg_body_ratio += body / total;
   }
   avg_body_ratio /= 5;
   
   // Higher body ratio = clearer pattern
   score += avg_body_ratio * 10;
   
   return MathMin(20, score);
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Volume Confirmation                             |
//+------------------------------------------------------------------+
double EvaluateVolumeConfirmation(bool isBuy, MqlRates &rates[])
{
   int size = ArraySize(rates);
   if(size < 10) return 0;
   
   // Check if current volume is above average
   long current_volume = rates[0].tick_volume;
   long avg_volume = 0;
   
   for(int i = 1; i < 10; i++)
      avg_volume += rates[i].tick_volume;
   avg_volume /= 9;
   
   if(current_volume > avg_volume * 1.2)
      return 20; // Strong volume confirmation
   else if(current_volume > avg_volume)
      return 15; // Moderate volume confirmation
   else if(current_volume > avg_volume * 0.8)
      return 10; // Weak volume confirmation
   else
      return 0; // No volume confirmation
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Price Action Alignment                          |
//+------------------------------------------------------------------+
double EvaluatePriceActionAlignment(bool isBuy, MqlRates &rates[])
{
   int size = ArraySize(rates);
   if(size < 5) return 0;

   double score = 0;

   // For buy: Check for higher lows
   // For sell: Check for lower highs
   if(isBuy)
   {
      bool higher_lows = true;
      for(int i = 0; i < 3; i++)
      {
         if(rates[i].low >= rates[i+1].low)
            higher_lows = false;
      }
      if(higher_lows) score += 10;

      // Check for bullish candles
      int bullish_count = 0;
      for(int i = 0; i < 5; i++)
      {
         if(rates[i].close > rates[i].open)
            bullish_count++;
      }
      score += (bullish_count / 5.0) * 10;
   }
   else
   {
      bool lower_highs = true;
      for(int i = 0; i < 3; i++)
      {
         if(rates[i].high <= rates[i+1].high)
            lower_highs = false;
      }
      if(lower_highs) score += 10;

      // Check for bearish candles
      int bearish_count = 0;
      for(int i = 0; i < 5; i++)
      {
         if(rates[i].close < rates[i].open)
            bearish_count++;
      }
      score += (bearish_count / 5.0) * 10;
   }

   return MathMin(20, score);
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Momentum Strength                               |
//+------------------------------------------------------------------+
double EvaluateMomentumStrength(bool isBuy, MqlRates &rates[])
{
   int size = ArraySize(rates);
   if(size < 10) return 0;

   // Calculate price momentum over last 10 candles
   double price_change = rates[0].close - rates[9].close;
   double atr = CalculateATR(rates, 14, 0);

   if(atr == 0) return 0;

   double momentum_ratio = MathAbs(price_change) / atr;

   // Check if momentum aligns with signal direction
   if((isBuy && price_change > 0) || (!isBuy && price_change < 0))
   {
      if(momentum_ratio > 2.0)
         return 20; // Strong momentum
      else if(momentum_ratio > 1.0)
         return 15; // Moderate momentum
      else if(momentum_ratio > 0.5)
         return 10; // Weak momentum
   }

   return 0; // No momentum or opposite direction
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Support/Resistance Proximity                    |
//+------------------------------------------------------------------+
double EvaluateSRProximity(bool isBuy, MqlRates &rates[])
{
   int size = ArraySize(rates);
   if(size < 20) return 10; // Default score if can't calculate

   double current_price = rates[0].close;
   double score = 0;

   // Find nearest support/resistance
   double nearest_support = FindNearestSupport(rates, current_price);
   double nearest_resistance = FindNearestResistance(rates, current_price);

   if(isBuy)
   {
      // For buy: Want to be near support, far from resistance
      double distance_to_support = MathAbs(current_price - nearest_support) / current_price;
      double distance_to_resistance = MathAbs(nearest_resistance - current_price) / current_price;

      if(distance_to_support < 0.002) // Within 0.2%
         score += 10;
      else if(distance_to_support < 0.005) // Within 0.5%
         score += 5;

      if(distance_to_resistance > 0.01) // More than 1% away
         score += 10;
      else if(distance_to_resistance > 0.005) // More than 0.5% away
         score += 5;
   }
   else
   {
      // For sell: Want to be near resistance, far from support
      double distance_to_resistance = MathAbs(current_price - nearest_resistance) / current_price;
      double distance_to_support = MathAbs(current_price - nearest_support) / current_price;

      if(distance_to_resistance < 0.002) // Within 0.2%
         score += 10;
      else if(distance_to_resistance < 0.005) // Within 0.5%
         score += 5;

      if(distance_to_support > 0.01) // More than 1% away
         score += 10;
      else if(distance_to_support > 0.005) // More than 0.5% away
         score += 5;
   }

   return MathMin(20, score);
}

//+------------------------------------------------------------------+
//| Helper: Find Nearest Support                                     |
//+------------------------------------------------------------------+
double FindNearestSupport(MqlRates &rates[], double current_price)
{
   int size = ArraySize(rates);
   double nearest = 0;
   double min_distance = 999999;

   // Look for swing lows in last 20 candles
   for(int i = 2; i < MathMin(20, size-2); i++)
   {
      if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
         rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low)
      {
         if(rates[i].low < current_price)
         {
            double distance = current_price - rates[i].low;
            if(distance < min_distance)
            {
               min_distance = distance;
               nearest = rates[i].low;
            }
         }
      }
   }

   return (nearest > 0) ? nearest : current_price * 0.99; // Default to 1% below
}

//+------------------------------------------------------------------+
//| Helper: Find Nearest Resistance                                  |
//+------------------------------------------------------------------+
double FindNearestResistance(MqlRates &rates[], double current_price)
{
   int size = ArraySize(rates);
   double nearest = 999999;
   double min_distance = 999999;

   // Look for swing highs in last 20 candles
   for(int i = 2; i < MathMin(20, size-2); i++)
   {
      if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
         rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high)
      {
         if(rates[i].high > current_price)
         {
            double distance = rates[i].high - current_price;
            if(distance < min_distance)
            {
               min_distance = distance;
               nearest = rates[i].high;
            }
         }
      }
   }

   return (nearest < 999999) ? nearest : current_price * 1.01; // Default to 1% above
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Trend Alignment                                 |
//+------------------------------------------------------------------+
double EvaluateTrendAlignment(bool isBuy, MqlRates &rates[])
{
   int size = ArraySize(rates);
   if(size < 50) return 15; // Default score

   double score = 0;

   // Calculate simple trend using price position relative to MAs
   double current_price = rates[0].close;

   // Calculate 20-period MA
   double ma20 = 0;
   for(int i = 0; i < 20; i++)
      ma20 += rates[i].close;
   ma20 /= 20;

   // Calculate 50-period MA
   double ma50 = 0;
   for(int i = 0; i < 50; i++)
      ma50 += rates[i].close;
   ma50 /= 50;

   if(isBuy)
   {
      if(current_price > ma20 && ma20 > ma50)
         score = 30; // Strong uptrend
      else if(current_price > ma20)
         score = 20; // Moderate uptrend
      else if(current_price > ma50)
         score = 10; // Weak uptrend
   }
   else
   {
      if(current_price < ma20 && ma20 < ma50)
         score = 30; // Strong downtrend
      else if(current_price < ma20)
         score = 20; // Moderate downtrend
      else if(current_price < ma50)
         score = 10; // Weak downtrend
   }

   return score;
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Market Structure                                |
//+------------------------------------------------------------------+
double EvaluateMarketStructure(bool isBuy, MqlRates &rates[])
{
   int size = ArraySize(rates);
   if(size < 20) return 15; // Default score

   // Check for clean market structure (higher highs/higher lows or lower highs/lower lows)
   int structure_score = 0;

   if(isBuy)
   {
      // Look for higher lows pattern
      int higher_lows = 0;
      for(int i = 0; i < 15; i += 5)
      {
         if(i+5 < size && rates[i].low > rates[i+5].low)
            higher_lows++;
      }
      structure_score = higher_lows * 10;
   }
   else
   {
      // Look for lower highs pattern
      int lower_highs = 0;
      for(int i = 0; i < 15; i += 5)
      {
         if(i+5 < size && rates[i].high < rates[i+5].high)
            lower_highs++;
      }
      structure_score = lower_highs * 10;
   }

   return MathMin(30, structure_score);
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Time of Day                                     |
//+------------------------------------------------------------------+
double EvaluateTimeOfDay()
{
   MqlDateTime time;
   TimeCurrent(time);

   int hour = time.hour;

   // Best trading hours for gold: London (8-12 GMT) and NY (13-17 GMT)
   if((hour >= 8 && hour <= 12) || (hour >= 13 && hour <= 17))
      return 20; // Prime trading hours
   else if((hour >= 7 && hour < 8) || (hour > 12 && hour < 13) || (hour > 17 && hour <= 18))
      return 10; // Acceptable hours
   else
      return 0; // Poor trading hours
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Recent Behavior                                 |
//+------------------------------------------------------------------+
double EvaluateRecentBehavior(bool isBuy, MqlRates &rates[])
{
   int size = ArraySize(rates);
   if(size < 10) return 10; // Default score

   // Check for consistent behavior in recent candles
   double avg_range = 0;
   for(int i = 0; i < 10; i++)
      avg_range += (rates[i].high - rates[i].low);
   avg_range /= 10;

   double current_range = rates[0].high - rates[0].low;

   // Prefer normal-sized candles (not too small, not too large)
   if(current_range > avg_range * 0.7 && current_range < avg_range * 1.5)
      return 20;
   else if(current_range > avg_range * 0.5 && current_range < avg_range * 2.0)
      return 10;
   else
      return 0;
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Candle Position                                 |
//+------------------------------------------------------------------+
double EvaluateCandlePosition(bool isBuy, MqlRates &rates[])
{
   if(ArraySize(rates) < 1) return 0;

   double body = MathAbs(rates[0].close - rates[0].open);
   double total = rates[0].high - rates[0].low;

   if(total == 0) return 0;

   double body_ratio = body / total;

   // Prefer strong candles with good body ratio
   if(body_ratio > 0.7)
      return 30;
   else if(body_ratio > 0.5)
      return 20;
   else if(body_ratio > 0.3)
      return 10;
   else
      return 0;
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Pullback Quality                                |
//+------------------------------------------------------------------+
double EvaluatePullbackQuality(bool isBuy, MqlRates &rates[])
{
   int size = ArraySize(rates);
   if(size < 10) return 15; // Default score

   // Look for healthy pullback (not too deep, not too shallow)
   double recent_high = rates[0].high;
   double recent_low = rates[0].low;

   for(int i = 1; i < 10; i++)
   {
      if(rates[i].high > recent_high) recent_high = rates[i].high;
      if(rates[i].low < recent_low) recent_low = rates[i].low;
   }

   double range = recent_high - recent_low;
   if(range == 0) return 0;

   if(isBuy)
   {
      double pullback = (recent_high - rates[0].close) / range;
      if(pullback > 0.3 && pullback < 0.6)
         return 30; // Ideal pullback
      else if(pullback > 0.2 && pullback < 0.7)
         return 20; // Good pullback
      else if(pullback > 0.1 && pullback < 0.8)
         return 10; // Acceptable pullback
   }
   else
   {
      double pullback = (rates[0].close - recent_low) / range;
      if(pullback > 0.3 && pullback < 0.6)
         return 30; // Ideal pullback
      else if(pullback > 0.2 && pullback < 0.7)
         return 20; // Good pullback
      else if(pullback > 0.1 && pullback < 0.8)
         return 10; // Acceptable pullback
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Breakout Confirmation                           |
//+------------------------------------------------------------------+
double EvaluateBreakoutConfirmation(bool isBuy, MqlRates &rates[])
{
   int size = ArraySize(rates);
   if(size < 5) return 10; // Default score

   // Check if current candle is breaking above/below recent range
   double recent_high = rates[1].high;
   double recent_low = rates[1].low;

   for(int i = 2; i < 5; i++)
   {
      if(rates[i].high > recent_high) recent_high = rates[i].high;
      if(rates[i].low < recent_low) recent_low = rates[i].low;
   }

   if(isBuy && rates[0].close > recent_high)
      return 20; // Confirmed breakout
   else if(!isBuy && rates[0].close < recent_low)
      return 20; // Confirmed breakdown
   else if(isBuy && rates[0].high > recent_high)
      return 10; // Partial breakout
   else if(!isBuy && rates[0].low < recent_low)
      return 10; // Partial breakdown

   return 0;
}

//+------------------------------------------------------------------+
//| Helper: Evaluate Distance From Extremes                          |
//+------------------------------------------------------------------+
double EvaluateDistanceFromExtremes(bool isBuy, MqlRates &rates[])
{
   int size = ArraySize(rates);
   if(size < 20) return 10; // Default score

   // Find recent extremes
   double highest = rates[0].high;
   double lowest = rates[0].low;

   for(int i = 1; i < 20; i++)
   {
      if(rates[i].high > highest) highest = rates[i].high;
      if(rates[i].low < lowest) lowest = rates[i].low;
   }

   double range = highest - lowest;
   if(range == 0) return 0;

   double current_position = (rates[0].close - lowest) / range;

   // Prefer entries not at extremes
   if(isBuy)
   {
      // For buy, prefer 20-50% from bottom
      if(current_position > 0.2 && current_position < 0.5)
         return 20;
      else if(current_position > 0.1 && current_position < 0.6)
         return 10;
   }
   else
   {
      // For sell, prefer 50-80% from bottom (near top)
      if(current_position > 0.5 && current_position < 0.8)
         return 20;
      else if(current_position > 0.4 && current_position < 0.9)
         return 10;
   }

   return 0;
}

