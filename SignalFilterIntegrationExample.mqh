//+------------------------------------------------------------------+
//|                                  SignalFilterIntegrationExample.mqh |
//|                     Example code showing how to integrate the     |
//|                     Signal Filtration System into GoldTraderEA    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, GoldTraderEA"
#property strict

/*
   This file contains example code snippets showing how to integrate
   the Signal Filtration System into the main GoldTraderEA.mq5 file.
   
   DO NOT compile this file directly - it's for reference only.
   
   Follow the integration steps in SIGNAL_FILTER_INTEGRATION_GUIDE.md
*/

//+------------------------------------------------------------------+
//| STEP 1: Add include statement in GoldTraderEA.mq5               |
//| Location: After other #include statements (around line 76)      |
//+------------------------------------------------------------------+
/*
#include "CandlePatterns.mqh"
#include "ChartPatterns.mqh"
#include "PriceAction.mqh"
#include "ElliottWaves.mqh"
#include "Indicators.mqh"
#include "Divergence.mqh"
#include "HarmonicPatterns.mqh"
#include "VolumeAnalysis.mqh"
#include "WolfeWaves.mqh"
#include "MultiTimeframe.mqh"
#include "TimeAnalysis.mqh"
#include "PivotPoints.mqh"
#include "SupportResistance.mqh"
#include "MACrossover.mqh"
#include "TrendPatterns.mqh"
#include "SignalFilterSystem.mqh"  // <-- ADD THIS LINE
*/

//+------------------------------------------------------------------+
//| STEP 2: Declare global filter instance                          |
//| Location: After global variable declarations (around line 250)  |
//+------------------------------------------------------------------+
/*
// Existing global variables...
CTrade trade;
CPositionInfo position_info;
CAccountInfo account_info;

// Signal filtration system
CSignalFilter g_signal_filter;  // <-- ADD THIS LINE
*/

//+------------------------------------------------------------------+
//| STEP 3: Initialize filter in OnInit()                           |
//| Location: In OnInit() after indicator initialization (~line 440)|
//+------------------------------------------------------------------+
/*
int OnInit()
{
   // ... existing initialization code ...
   
   // Initialize multi-timeframe analysis module
   if(!InitializeMultiTimeframeIndicators()) {
      DebugPrint("Error initializing multi-timeframe analysis module");
      return INIT_FAILED;
   }

   // Initialize signal filtration system
   if(!g_signal_filter.Initialize())
   {
      Print("ERROR: Failed to initialize Signal Filtration System");
      return INIT_FAILED;
   }
   Print("Signal Filtration System initialized successfully");

   return(INIT_SUCCEEDED);
}
*/

//+------------------------------------------------------------------+
//| STEP 4: Deinitialize filter in OnDeinit()                       |
//| Location: In OnDeinit() function                                |
//+------------------------------------------------------------------+
/*
void OnDeinit(const int reason)
{
   // ... existing cleanup code ...
   
   // Cleanup signal filter
   g_signal_filter.Deinitialize();
   
   Print("GoldTraderEA deinitialized. Reason: ", reason);
}
*/

//+------------------------------------------------------------------+
//| STEP 5: Integrate filter into BUY signal processing             |
//| Location: In OnTick() where buy positions are opened (~line 1033)|
//+------------------------------------------------------------------+
/*
// ORIGINAL CODE (BEFORE):
if(buy_confirmations >= Min_Confirmations && !have_buy_position && potential_buy) {
    // Check main trend (if enabled)
    if(!Use_Main_Trend_Filter || current_close > ma_main_trend_value) {
        if(G_Debug) DebugPrint("Buy conditions confirmed. Attempting to open buy position...");
        bool result = SafeOpenBuyPosition();
        
        if(G_Debug) {
            if(result)
                DebugPrint("Buy position opened successfully.");
            else
                DebugPrint("Error opening buy position.");
        }
        
        // Record last trade time
        last_trade_time = current_candle_time;
        return; // Exit after opening a position
    }
    else if(G_Debug) {
        DebugPrint("Buy signal rejected - main trend is not bullish.");
    }
}

// MODIFIED CODE (AFTER):
if(buy_confirmations >= Min_Confirmations && !have_buy_position && potential_buy) {
    // Check main trend (if enabled)
    if(!Use_Main_Trend_Filter || current_close > ma_main_trend_value) {
        
        // === APPLY SIGNAL FILTRATION SYSTEM ===
        // Create signal data structure
        CSignalData signal = CreateSignalData(SIGNAL_LONG, "MultiStrategy", current_close);
        
        // Populate signal with current indicator values
        signal.adx_value = adx[0];
        signal.bb_upper_value = bb_upper[0];
        signal.bb_middle_value = bb_middle[0];
        signal.bb_lower_value = bb_lower[0];
        signal.rsi_value = rsi[0];
        signal.macd_value = macd[0];
        signal.stoch_value = stoch_k[0];
        
        // Determine primary strategy category based on highest weighted confirmation
        // This is a simplified approach - you could track which strategy contributed most
        if(Use_MACrossover && ma_buy > 0)
            signal.strategy_name = "MACrossover";
        else if(Use_Indicators && indicator_buy)
            signal.strategy_name = "Indicators";
        else if(Use_PriceAction && pa_buy > 0)
            signal.strategy_name = "PriceAction";
        // ... add other strategies as needed
        
        // Validate signal through all gates
        CFilterResult filter_result;
        if(!g_signal_filter.ValidateSignal(signal, filter_result))
        {
            if(G_Debug) 
            {
                DebugPrint("=== BUY SIGNAL REJECTED BY FILTER ===");
                DebugPrint("Gate Failed: " + IntegerToString(filter_result.gate_failed));
                DebugPrint("Reason: " + filter_result.failure_reason);
                DebugPrint("Confirmations: " + IntegerToString(buy_confirmations));
            }
            return; // Exit without opening position
        }
        
        if(G_Debug) 
        {
            DebugPrint("=== BUY SIGNAL PASSED ALL FILTERS ===");
            DebugPrint("Quality Score: " + DoubleToString(filter_result.quality_score, 1));
            DebugPrint("Strategy: " + signal.strategy_name);
        }
        // === END FILTRATION ===
        
        if(G_Debug) DebugPrint("Buy conditions confirmed. Attempting to open buy position...");
        bool result = SafeOpenBuyPosition();
        
        if(G_Debug) {
            if(result)
                DebugPrint("Buy position opened successfully.");
            else
                DebugPrint("Error opening buy position.");
        }
        
        // Record last trade time
        last_trade_time = current_candle_time;
        return; // Exit after opening a position
    }
    else if(G_Debug) {
        DebugPrint("Buy signal rejected - main trend is not bullish.");
    }
}
*/

//+------------------------------------------------------------------+
//| STEP 6: Integrate filter into SELL signal processing            |
//| Location: In OnTick() where sell positions are opened (~line 1058)|
//+------------------------------------------------------------------+
/*
// ORIGINAL CODE (BEFORE):
if(sell_confirmations >= Min_Confirmations && !have_sell_position && potential_sell) {
    // Check main trend (if enabled)
    if(!Use_Main_Trend_Filter || current_close < ma_main_trend_value) {
        if(G_Debug) DebugPrint("Sell conditions confirmed. Attempting to open sell position...");
        bool result = SafeOpenSellPosition();
        
        if(G_Debug) {
            if(result)
                DebugPrint("Sell position opened successfully.");
            else
                DebugPrint("Error opening sell position.");
        }
        
        // Record last trade time
        last_trade_time = current_candle_time;
        return; // Exit after opening a position
    }
    else if(G_Debug) {
        DebugPrint("Sell signal rejected - main trend is not bearish.");
    }
}

// MODIFIED CODE (AFTER):
if(sell_confirmations >= Min_Confirmations && !have_sell_position && potential_sell) {
    // Check main trend (if enabled)
    if(!Use_Main_Trend_Filter || current_close < ma_main_trend_value) {
        
        // === APPLY SIGNAL FILTRATION SYSTEM ===
        // Create signal data structure
        CSignalData signal = CreateSignalData(SIGNAL_SHORT, "MultiStrategy", current_close);
        
        // Populate signal with current indicator values
        signal.adx_value = adx[0];
        signal.bb_upper_value = bb_upper[0];
        signal.bb_middle_value = bb_middle[0];
        signal.bb_lower_value = bb_lower[0];
        signal.rsi_value = rsi[0];
        signal.macd_value = macd[0];
        signal.stoch_value = stoch_k[0];
        
        // Determine primary strategy category
        if(Use_MACrossover && ma_sell > 0)
            signal.strategy_name = "MACrossover";
        else if(Use_Indicators && indicator_sell)
            signal.strategy_name = "Indicators";
        else if(Use_PriceAction && pa_sell > 0)
            signal.strategy_name = "PriceAction";
        // ... add other strategies as needed
        
        // Validate signal through all gates
        CFilterResult filter_result;
        if(!g_signal_filter.ValidateSignal(signal, filter_result))
        {
            if(G_Debug) 
            {
                DebugPrint("=== SELL SIGNAL REJECTED BY FILTER ===");
                DebugPrint("Gate Failed: " + IntegerToString(filter_result.gate_failed));
                DebugPrint("Reason: " + filter_result.failure_reason);
                DebugPrint("Confirmations: " + IntegerToString(sell_confirmations));
            }
            return; // Exit without opening position
        }
        
        if(G_Debug) 
        {
            DebugPrint("=== SELL SIGNAL PASSED ALL FILTERS ===");
            DebugPrint("Quality Score: " + DoubleToString(filter_result.quality_score, 1));
            DebugPrint("Strategy: " + signal.strategy_name);
        }
        // === END FILTRATION ===
        
        if(G_Debug) DebugPrint("Sell conditions confirmed. Attempting to open sell position...");
        bool result = SafeOpenSellPosition();
        
        if(G_Debug) {
            if(result)
                DebugPrint("Sell position opened successfully.");
            else
                DebugPrint("Error opening sell position.");
        }
        
        // Record last trade time
        last_trade_time = current_candle_time;
        return; // Exit after opening a position
    }
    else if(G_Debug) {
        DebugPrint("Sell signal rejected - main trend is not bearish.");
    }
}
*/

//+------------------------------------------------------------------+
//| OPTIONAL: Enhanced strategy tracking                            |
//| Track which strategy contributed most to the signal             |
//+------------------------------------------------------------------+
/*
// Add this helper function to determine primary strategy
string DeterminePrimaryStrategy(int buy_confirmations, int sell_confirmations, bool is_buy)
{
   string primary = "MultiStrategy";
   int max_contribution = 0;
   
   if(is_buy)
   {
      if(Use_MACrossover && ma_buy * MACrossover_Weight > max_contribution) {
         max_contribution = ma_buy * MACrossover_Weight;
         primary = "MACrossover";
      }
      if(Use_Indicators && indicator_buy && Indicators_Weight > max_contribution) {
         max_contribution = Indicators_Weight;
         primary = "Indicators";
      }
      if(Use_HarmonicPatterns && harmonic_buy * HarmonicPatterns_Weight > max_contribution) {
         max_contribution = harmonic_buy * HarmonicPatterns_Weight;
         primary = "HarmonicPatterns";
      }
      // Add other strategies...
   }
   else
   {
      // Similar logic for sell signals
   }
   
   return primary;
}
*/

