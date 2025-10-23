//+------------------------------------------------------------------+
//|                                         INTEGRATION_EXAMPLE.mq5  |
//|                          Example of integrating false positive   |
//|                          filtering into GoldTraderEA             |
//+------------------------------------------------------------------+

// This file shows how to integrate the new filtering modules
// into the existing GoldTraderEA.mq5 OnTick() function

//+------------------------------------------------------------------+
//| STEP 1: Add includes at the top of GoldTraderEA.mq5             |
//+------------------------------------------------------------------+
/*
Add these lines after the existing #include statements (around line 75):

#include "SignalQualityFilter.mqh"
#include "StrategyValidation.mqh"
*/

//+------------------------------------------------------------------+
//| STEP 2: Modify OnTick() function - Add validation after         |
//|         strategy confirmations are calculated                    |
//+------------------------------------------------------------------+

void OnTick_EXAMPLE()
{
    // ... existing code up to line 843 (after all strategy checks) ...
    
    // === NEW CODE STARTS HERE ===
    
    // PHASE 1: Strategy-Specific Validation
    // Validate each strategy that contributed confirmations
    
    string rejection_reason = "";
    
    // 1. Validate Elliott Waves (if used and has confirmations)
    if(Use_ElliottWaves && enough_buy_confirmations)
    {
        // Check if Elliott Waves contributed to buy signal
        int ew_buy = SafeCheckElliottWavesBuy(local_rates);
        if(ew_buy > 0)
        {
            if(!ValidateElliottWaveSignal(true, local_rates, rejection_reason))
            {
                buy_confirmations -= ew_buy * ElliottWaves_Weight;
                enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
                if(G_Debug) DebugPrint("Elliott Waves BUY rejected: " + rejection_reason);
            }
        }
    }
    
    if(Use_ElliottWaves && enough_sell_confirmations)
    {
        int ew_sell = SafeCheckElliottWavesShort(local_rates);
        if(ew_sell > 0)
        {
            if(!ValidateElliottWaveSignal(false, local_rates, rejection_reason))
            {
                sell_confirmations -= ew_sell * ElliottWaves_Weight;
                enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
                if(G_Debug) DebugPrint("Elliott Waves SELL rejected: " + rejection_reason);
            }
        }
    }
    
    // 2. Validate Harmonic Patterns (if used and has confirmations)
    if(Use_HarmonicPatterns && enough_buy_confirmations)
    {
        int hp_buy = SafeCheckHarmonicPatternsBuy(local_rates);
        if(hp_buy > 0)
        {
            // Note: You'd need to track which specific pattern was detected
            // For now, we'll use "Gartley" as example
            if(!ValidateHarmonicPatternSignal(true, local_rates, "Gartley", rejection_reason))
            {
                buy_confirmations -= hp_buy * HarmonicPatterns_Weight;
                enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
                if(G_Debug) DebugPrint("Harmonic Patterns BUY rejected: " + rejection_reason);
            }
        }
    }
    
    if(Use_HarmonicPatterns && enough_sell_confirmations)
    {
        int hp_sell = SafeCheckHarmonicPatternsShort(local_rates);
        if(hp_sell > 0)
        {
            if(!ValidateHarmonicPatternSignal(false, local_rates, "Gartley", rejection_reason))
            {
                sell_confirmations -= hp_sell * HarmonicPatterns_Weight;
                enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
                if(G_Debug) DebugPrint("Harmonic Patterns SELL rejected: " + rejection_reason);
            }
        }
    }
    
    // 3. Validate Divergence (if used and has confirmations)
    if(Use_Divergence && enough_buy_confirmations)
    {
        int div_buy = CheckDivergenceBuy(local_rates);
        if(div_buy > 0)
        {
            // Pass RSI values for validation
            if(!ValidateDivergenceSignal(true, local_rates, rsi, rejection_reason))
            {
                buy_confirmations -= div_buy * Divergence_Weight;
                enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
                if(G_Debug) DebugPrint("Divergence BUY rejected: " + rejection_reason);
            }
        }
    }
    
    if(Use_Divergence && enough_sell_confirmations)
    {
        int div_sell = CheckDivergenceShort(local_rates);
        if(div_sell > 0)
        {
            if(!ValidateDivergenceSignal(false, local_rates, rsi, rejection_reason))
            {
                sell_confirmations -= div_sell * Divergence_Weight;
                enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
                if(G_Debug) DebugPrint("Divergence SELL rejected: " + rejection_reason);
            }
        }
    }
    
    // 4. Validate MA Crossover (if used and has confirmations)
    if(Use_MACrossover && enough_buy_confirmations)
    {
        int mac_buy = CheckMACrossoverBuy(local_rates);
        if(mac_buy > 0)
        {
            // Need to get MA values for validation
            double fast_ma_vals[10], slow_ma_vals[10];
            // ... copy MA values ...
            
            if(!ValidateMACrossoverSignal(true, local_rates, fast_ma_vals, slow_ma_vals, rejection_reason))
            {
                buy_confirmations -= mac_buy * MACrossover_Weight;
                enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
                if(G_Debug) DebugPrint("MA Crossover BUY rejected: " + rejection_reason);
            }
        }
    }
    
    if(Use_MACrossover && enough_sell_confirmations)
    {
        int mac_sell = CheckMACrossoverShort(local_rates);
        if(mac_sell > 0)
        {
            double fast_ma_vals[10], slow_ma_vals[10];
            // ... copy MA values ...
            
            if(!ValidateMACrossoverSignal(false, local_rates, fast_ma_vals, slow_ma_vals, rejection_reason))
            {
                sell_confirmations -= mac_sell * MACrossover_Weight;
                enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
                if(G_Debug) DebugPrint("MA Crossover SELL rejected: " + rejection_reason);
            }
        }
    }
    
    // PHASE 2: Centralized Signal Quality Check
    // Only proceed if we still have enough confirmations after validation
    
    if(enough_buy_confirmations && potential_buy)
    {
        SignalQuality quality = EvaluateSignalQuality(true, local_rates, "Combined");
        
        if(!quality.is_valid)
        {
            potential_buy = false;
            if(G_Debug) DebugPrint("BUY signal quality check FAILED: " + quality.rejection_reason);
        }
        else
        {
            // Log quality scores
            if(G_Debug)
            {
                DebugPrint("BUY Signal Quality Scores:");
                DebugPrint("  Strength: " + DoubleToString(quality.strength_score, 1));
                DebugPrint("  Reliability: " + DoubleToString(quality.reliability_score, 1));
                DebugPrint("  Context: " + DoubleToString(quality.context_score, 1));
                DebugPrint("  Timing: " + DoubleToString(quality.timing_score, 1));
            }
            
            // Optional: Require minimum quality scores
            if(quality.strength_score < 60.0)
            {
                potential_buy = false;
                if(G_Debug) DebugPrint("BUY signal strength too low: " + DoubleToString(quality.strength_score, 1));
            }
        }
    }
    
    if(enough_sell_confirmations && potential_sell)
    {
        SignalQuality quality = EvaluateSignalQuality(false, local_rates, "Combined");
        
        if(!quality.is_valid)
        {
            potential_sell = false;
            if(G_Debug) DebugPrint("SELL signal quality check FAILED: " + quality.rejection_reason);
        }
        else
        {
            // Log quality scores
            if(G_Debug)
            {
                DebugPrint("SELL Signal Quality Scores:");
                DebugPrint("  Strength: " + DoubleToString(quality.strength_score, 1));
                DebugPrint("  Reliability: " + DoubleToString(quality.reliability_score, 1));
                DebugPrint("  Context: " + DoubleToString(quality.context_score, 1));
                DebugPrint("  Timing: " + DoubleToString(quality.timing_score, 1));
            }
            
            // Optional: Require minimum quality scores
            if(quality.strength_score < 60.0)
            {
                potential_sell = false;
                if(G_Debug) DebugPrint("SELL signal strength too low: " + DoubleToString(quality.strength_score, 1));
            }
        }
    }
    
    // === NEW CODE ENDS HERE ===
    
    // ... continue with existing code (position checks, trade execution, etc.) ...
}

//+------------------------------------------------------------------+
//| STEP 3: Add initialization for new modules                       |
//+------------------------------------------------------------------+

int OnInit_EXAMPLE()
{
    // ... existing OnInit code ...
    
    // Initialize filtering modules (if needed)
    // Most parameters are set via input variables
    
    Print("False Positive Filtering Modules Initialized");
    Print("Signal Quality Thresholds:");
    Print("  Min Strength: ", FP_Min_Signal_Strength);
    Print("  Min Reliability: ", FP_Min_Reliability_Score);
    Print("  Min Context: ", FP_Min_Context_Score);
    Print("  Min Timing: ", FP_Min_Timing_Score);
    
    Print("Strategy Validation Parameters:");
    Print("  EW Min Wave Ratio: ", EW_Min_Wave_Ratio);
    Print("  HP Fib Tolerance: ", HP_Fibonacci_Tolerance);
    Print("  DIV Min Swing Sep: ", DIV_Min_Swing_Separation);
    Print("  MAC Min Sep Candles: ", MAC_Min_Separation_Candles);
    
    // ... rest of OnInit ...
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| ALTERNATIVE: Simpler Integration (Minimal Changes)               |
//+------------------------------------------------------------------+

void OnTick_SIMPLE_EXAMPLE()
{
    // ... existing code up to line 1033 (before trade execution) ...
    
    // Just before opening buy position (around line 1035):
    if(buy_confirmations >= Min_Confirmations && !have_buy_position && potential_buy)
    {
        // === ADD THIS QUALITY CHECK ===
        SignalQuality quality = EvaluateSignalQuality(true, local_rates, "Combined");
        
        if(!quality.is_valid || quality.strength_score < 60.0)
        {
            if(G_Debug) DebugPrint("BUY signal rejected by quality filter: " + quality.rejection_reason);
            return; // Skip this trade
        }
        // === END QUALITY CHECK ===
        
        // Check main trend (if enabled)
        if(!Use_Main_Trend_Filter || current_close > ma_main_trend_value)
        {
            if(G_Debug) DebugPrint("Buy conditions confirmed. Attempting to open buy position...");
            bool result = SafeOpenBuyPosition();
            // ... rest of existing code ...
        }
    }
    
    // Just before opening sell position (around line 1058):
    if(sell_confirmations >= Min_Confirmations && !have_sell_position && potential_sell)
    {
        // === ADD THIS QUALITY CHECK ===
        SignalQuality quality = EvaluateSignalQuality(false, local_rates, "Combined");
        
        if(!quality.is_valid || quality.strength_score < 60.0)
        {
            if(G_Debug) DebugPrint("SELL signal rejected by quality filter: " + quality.rejection_reason);
            return; // Skip this trade
        }
        // === END QUALITY CHECK ===
        
        // Check main trend (if enabled)
        if(!Use_Main_Trend_Filter || current_close < ma_main_trend_value)
        {
            if(G_Debug) DebugPrint("Sell conditions confirmed. Attempting to open sell position...");
            bool result = SafeOpenSellPosition();
            // ... rest of existing code ...
        }
    }
}

//+------------------------------------------------------------------+
//| TESTING RECOMMENDATIONS                                          |
//+------------------------------------------------------------------+

/*
1. BACKTEST COMPARISON:
   - Run backtest WITHOUT filters (baseline)
   - Run backtest WITH filters (new version)
   - Compare:
     * Total trades
     * Win rate
     * Profit factor
     * Maximum drawdown
     * Average trade duration

2. PARAMETER OPTIMIZATION:
   - Start with CONSERVATIVE settings
   - Gradually relax thresholds if too few signals
   - Monitor false positive rate (losing trades / total trades)
   - Target: <40% losing trades (>60% win rate)

3. STRATEGY-BY-STRATEGY ANALYSIS:
   - Enable only ONE strategy at a time
   - Test with and without validation
   - Identify which strategies benefit most from filtering
   - Adjust weights accordingly

4. LIVE TESTING:
   - Start with DEMO account
   - Enable G_Debug = true for detailed logging
   - Monitor rejection reasons
   - Tune parameters based on real market conditions

5. PERFORMANCE METRICS:
   - Track rejection rate per filter type
   - Calculate filter effectiveness: (Prevented Losses / Total Rejections)
   - Monitor signal quality scores over time
   - Adjust thresholds quarterly based on performance
*/

