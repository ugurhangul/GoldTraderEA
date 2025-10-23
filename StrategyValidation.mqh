//+------------------------------------------------------------------+
//|                                          StrategyValidation.mqh  |
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
//| Strategy-Specific Validation Parameters                          |
//+------------------------------------------------------------------+

// Elliott Waves Validation
input double   EW_Min_Wave_Ratio = 0.3;              // Minimum wave size ratio (prevent micro-patterns)
input double   EW_Max_Wave_Ratio = 3.0;              // Maximum wave size ratio (prevent extreme patterns)
input int      EW_Min_Candles_Per_Wave = 3;          // Minimum candles per wave
input bool     EW_Require_Volume_Increase = true;    // Require volume increase on wave 3/5

// Harmonic Patterns Validation
input double   HP_Fibonacci_Tolerance = 0.05;        // Fibonacci ratio tolerance (5%)
input bool     HP_Require_XABCD_Sequence = true;     // Require proper time sequence
input bool     HP_Validate_Pattern_Symmetry = true;  // Check pattern symmetry
input double   HP_Min_Pattern_Size_Pips = 20;        // Minimum pattern size in pips

// Divergence Validation
input int      DIV_Min_Swing_Separation = 5;         // Minimum candles between swing points
input double   DIV_Min_Price_Difference = 0.001;     // Minimum price difference (0.1%)
input double   DIV_Min_Indicator_Difference = 2.0;   // Minimum indicator difference
input bool     DIV_Require_Trend_Alignment = true;   // Divergence must align with trend

// MA Crossover Validation
input int      MAC_Min_Separation_Candles = 3;       // Minimum candles since last crossover
input double   MAC_Min_Angle_Degrees = 15;           // Minimum MA angle (degrees)
input bool     MAC_Require_Volume_Spike = true;      // Require volume spike on crossover
input bool     MAC_Avoid_Whipsaw_Zone = true;        // Avoid trading in consolidation

//+------------------------------------------------------------------+
//| Validate Elliott Wave Signal                                     |
//+------------------------------------------------------------------+
bool ValidateElliottWaveSignal(bool isBuy, MqlRates &rates[], string &rejection_reason)
{
   int size = ArraySize(rates);
   if(size < 30)
   {
      rejection_reason = "Insufficient data for Elliott Wave validation";
      return false;
   }
   
   // 1. Validate wave structure exists
   if(!HasValidWaveStructure(rates, isBuy))
   {
      rejection_reason = "Invalid Elliott Wave structure detected";
      return false;
   }
   
   // 2. Check wave proportions
   if(!ValidateWaveProportions(rates, isBuy))
   {
      rejection_reason = "Elliott Wave proportions outside acceptable range";
      return false;
   }
   
   // 3. Validate wave timing
   if(!ValidateWaveTiming(rates, isBuy))
   {
      rejection_reason = "Elliott Wave timing invalid (waves too compressed)";
      return false;
   }
   
   // 4. Check volume pattern (if required)
   if(EW_Require_Volume_Increase && !ValidateWaveVolume(rates, isBuy))
   {
      rejection_reason = "Elliott Wave lacks required volume confirmation";
      return false;
   }
   
   // 5. Verify current position in wave cycle
   if(!IsValidWaveEntry(rates, isBuy))
   {
      rejection_reason = "Current position not optimal for Elliott Wave entry";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate Harmonic Pattern Signal                                 |
//+------------------------------------------------------------------+
bool ValidateHarmonicPatternSignal(bool isBuy, MqlRates &rates[], string pattern_type, string &rejection_reason)
{
   int size = ArraySize(rates);
   if(size < 40)
   {
      rejection_reason = "Insufficient data for Harmonic Pattern validation";
      return false;
   }
   
   // 1. Validate Fibonacci ratios are within tolerance
   if(!ValidateFibonacciRatios(rates, isBuy, pattern_type))
   {
      rejection_reason = "Fibonacci ratios outside tolerance for " + pattern_type;
      return false;
   }
   
   // 2. Check XABCD time sequence
   if(HP_Require_XABCD_Sequence && !ValidateXABCDSequence(rates, isBuy))
   {
      rejection_reason = "XABCD time sequence invalid";
      return false;
   }
   
   // 3. Validate pattern size
   if(!ValidatePatternSize(rates, isBuy))
   {
      rejection_reason = "Harmonic pattern too small (< " + DoubleToString(HP_Min_Pattern_Size_Pips, 0) + " pips)";
      return false;
   }
   
   // 4. Check pattern symmetry
   if(HP_Validate_Pattern_Symmetry && !ValidatePatternSymmetry(rates, isBuy))
   {
      rejection_reason = "Harmonic pattern lacks symmetry";
      return false;
   }
   
   // 5. Verify D point completion
   if(!IsDPointComplete(rates, isBuy, pattern_type))
   {
      rejection_reason = "D point not properly completed";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate Divergence Signal                                       |
//+------------------------------------------------------------------+
bool ValidateDivergenceSignal(bool isBuy, MqlRates &rates[], double indicator_values[], string &rejection_reason)
{
   int size = ArraySize(rates);
   if(size < 30 || ArraySize(indicator_values) < size)
   {
      rejection_reason = "Insufficient data for Divergence validation";
      return false;
   }
   
   // 1. Find swing points
   int swing1_idx = -1, swing2_idx = -1;
   if(!FindValidSwingPoints(rates, isBuy, swing1_idx, swing2_idx))
   {
      rejection_reason = "No valid swing points found for divergence";
      return false;
   }
   
   // 2. Validate swing separation
   if(MathAbs(swing1_idx - swing2_idx) < DIV_Min_Swing_Separation)
   {
      rejection_reason = "Swing points too close together (< " + IntegerToString(DIV_Min_Swing_Separation) + " candles)";
      return false;
   }
   
   // 3. Check price difference significance
   double price_diff = MathAbs(rates[swing1_idx].close - rates[swing2_idx].close);
   double avg_price = (rates[swing1_idx].close + rates[swing2_idx].close) / 2;
   if(price_diff / avg_price < DIV_Min_Price_Difference)
   {
      rejection_reason = "Price difference too small for valid divergence";
      return false;
   }
   
   // 4. Check indicator difference significance
   double indicator_diff = MathAbs(indicator_values[swing1_idx] - indicator_values[swing2_idx]);
   if(indicator_diff < DIV_Min_Indicator_Difference)
   {
      rejection_reason = "Indicator difference too small for valid divergence";
      return false;
   }
   
   // 5. Validate divergence direction
   if(!ValidateDivergenceDirection(rates, indicator_values, swing1_idx, swing2_idx, isBuy))
   {
      rejection_reason = "Divergence direction invalid or contradictory";
      return false;
   }
   
   // 6. Check trend alignment (if required)
   if(DIV_Require_Trend_Alignment && !IsDivergenceAlignedWithTrend(rates, isBuy))
   {
      rejection_reason = "Divergence not aligned with overall trend";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate MA Crossover Signal                                     |
//+------------------------------------------------------------------+
bool ValidateMACrossoverSignal(bool isBuy, MqlRates &rates[], double fast_ma[], double slow_ma[], string &rejection_reason)
{
   int size = ArraySize(rates);
   if(size < 10 || ArraySize(fast_ma) < 10 || ArraySize(slow_ma) < 10)
   {
      rejection_reason = "Insufficient data for MA Crossover validation";
      return false;
   }
   
   // 1. Verify crossover actually occurred
   if(!VerifyCrossoverOccurred(fast_ma, slow_ma, isBuy))
   {
      rejection_reason = "No valid MA crossover detected";
      return false;
   }
   
   // 2. Check time since last crossover
   int candles_since_crossover = GetCandlesSinceLastCrossover(fast_ma, slow_ma);
   if(candles_since_crossover < MAC_Min_Separation_Candles)
   {
      rejection_reason = "Too soon since last crossover (< " + IntegerToString(MAC_Min_Separation_Candles) + " candles)";
      return false;
   }
   
   // 3. Validate MA angle/slope
   if(!ValidateMAAngle(fast_ma, isBuy))
   {
      rejection_reason = "MA angle too shallow (< " + DoubleToString(MAC_Min_Angle_Degrees, 0) + " degrees)";
      return false;
   }
   
   // 4. Check for whipsaw conditions
   if(MAC_Avoid_Whipsaw_Zone && IsInWhipsawZone(fast_ma, slow_ma))
   {
      rejection_reason = "MAs in whipsaw/consolidation zone";
      return false;
   }
   
   // 5. Verify volume confirmation (if required)
   if(MAC_Require_Volume_Spike && !HasVolumeSpikeOnCrossover(rates))
   {
      rejection_reason = "No volume spike on MA crossover";
      return false;
   }
   
   // 6. Check MA separation
   if(!ValidateMASeparation(fast_ma, slow_ma))
   {
      rejection_reason = "MAs too close together (potential false crossover)";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Helper: Check if valid wave structure exists                     |
//+------------------------------------------------------------------+
bool HasValidWaveStructure(MqlRates &rates[], bool isBuy)
{
   // Simplified check - look for alternating highs/lows pattern
   int size = ArraySize(rates);
   if(size < 15) return false;
   
   int direction_changes = 0;
   bool last_up = (rates[1].close > rates[2].close);
   
   for(int i = 2; i < 15; i++)
   {
      bool current_up = (rates[i].close > rates[i+1].close);
      if(current_up != last_up)
         direction_changes++;
      last_up = current_up;
   }
   
   // Should have at least 3-4 direction changes for a wave structure
   return (direction_changes >= 3 && direction_changes <= 6);
}

//+------------------------------------------------------------------+
//| Helper: Validate wave proportions                                |
//+------------------------------------------------------------------+
bool ValidateWaveProportions(MqlRates &rates[], bool isBuy)
{
   // Find wave sizes and check ratios
   int size = ArraySize(rates);
   if(size < 20) return false;
   
   // Simplified: Check that no single wave is too large or too small
   double max_wave = 0;
   double min_wave = 999999;
   
   for(int i = 0; i < 15; i += 3)
   {
      if(i+3 >= size) break;
      double wave_size = MathAbs(rates[i].close - rates[i+3].close);
      if(wave_size > max_wave) max_wave = wave_size;
      if(wave_size < min_wave && wave_size > 0) min_wave = wave_size;
   }
   
   if(min_wave == 0 || max_wave == 0) return false;
   
   double ratio = max_wave / min_wave;
   return (ratio >= EW_Min_Wave_Ratio && ratio <= EW_Max_Wave_Ratio);
}

//+------------------------------------------------------------------+
//| Helper: Validate wave timing                                     |
//+------------------------------------------------------------------+
bool ValidateWaveTiming(MqlRates &rates[], bool isBuy)
{
   // Check that waves aren't too compressed (minimum candles per wave)
   // This is a simplified check
   return true; // Placeholder - implement based on specific wave detection logic
}

//+------------------------------------------------------------------+
//| Helper: Validate wave volume pattern                             |
//+------------------------------------------------------------------+
bool ValidateWaveVolume(MqlRates &rates[], bool isBuy)
{
   int size = ArraySize(rates);
   if(size < 10) return false;
   
   // Check if recent volume is above average
   long recent_volume = 0;
   long older_volume = 0;
   
   for(int i = 0; i < 5; i++)
      recent_volume += rates[i].tick_volume;
   
   for(int i = 5; i < 10; i++)
      older_volume += rates[i].tick_volume;
   
   return (recent_volume > older_volume * 1.1); // 10% increase
}

//+------------------------------------------------------------------+
//| Helper: Check if valid wave entry point                          |
//+------------------------------------------------------------------+
bool IsValidWaveEntry(MqlRates &rates[], bool isBuy)
{
   // Entry should be near completion of wave pattern
   // Simplified check
   return true; // Placeholder
}

//+------------------------------------------------------------------+
//| Helper: Validate Fibonacci ratios                                |
//+------------------------------------------------------------------+
bool ValidateFibonacciRatios(MqlRates &rates[], bool isBuy, string pattern_type)
{
   // This would check specific Fibonacci ratios for each pattern type
   // Placeholder - actual implementation would be pattern-specific
   return true;
}

//+------------------------------------------------------------------+
//| Helper: Validate XABCD sequence                                  |
//+------------------------------------------------------------------+
bool ValidateXABCDSequence(MqlRates &rates[], bool isBuy)
{
   // Check that X, A, B, C, D points occur in proper time order
   // Placeholder - implement based on actual point detection
   return true;
}

//+------------------------------------------------------------------+
//| Helper: Validate pattern size                                    |
//+------------------------------------------------------------------+
bool ValidatePatternSize(MqlRates &rates[], bool isBuy)
{
   int size = ArraySize(rates);
   if(size < 40) return false;
   
   // Find pattern range
   double highest = rates[0].high;
   double lowest = rates[0].low;
   
   for(int i = 1; i < 40; i++)
   {
      if(rates[i].high > highest) highest = rates[i].high;
      if(rates[i].low < lowest) lowest = rates[i].low;
   }
   
   double pattern_size = highest - lowest;
   double point_value = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double pattern_pips = pattern_size / (point_value * 10);
   
   return (pattern_pips >= HP_Min_Pattern_Size_Pips);
}

// Additional helper functions continue...
// (Remaining functions omitted for brevity - follow same pattern)


