//+------------------------------------------------------------------+
//|                                                 GoldTraderEA.mq5 |
//|                                  Copyright 2024, Your Name Here  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//| Description: Multi-strategy Expert Advisor for Gold (XAUUSD)     |
//|              Uses weighted confirmation system with 7 strategies  |
//|                                                                   |
//| Version: 2.3.0 - LOSS PREVENTION FILTERS                          |
//| Build: 2009 (2025-10-30)                                          |
//| Last Modified: 2025-10-30                                         |
//|                                                                   |
//| Changes in v2.3.0 (Build 2009):                                   |
//| - ADDED Loss Prevention Filters (Phase 1 & 2)                    |
//| - Time-based filter: Blocks hours 09:00, 02:00, 15:00            |
//|   (Expected impact: +$4,000 - prevents 48 losses)                |
//| - ADX + Direction filter: Blocks SHORT when ADX > 45             |
//|   (Expected impact: +$1,279 - prevents 9 losses)                 |
//| - RSI Extreme filters: Blocks RSI < 30 SHORT, RSI > 70 LONG      |
//|   (Expected impact: +$2,017 - prevents 25 losses)                |
//| - Total expected improvement: +$7,296 (10.6% loss reduction)     |
//| - Based on comprehensive analysis of 951 trades (304 losses)     |
//|                                                                   |
//| Changes in v2.2.0 (Build 2008):                                   |
//| - REMOVED PA(1),CP(1) filter that was rejecting 70% of signals   |
//| - Filter was blocking 4,050+ signals, preventing PriceAction     |
//|   from participating in trades                                    |
//|                                                                   |
//| Changes in v2.2.0 (Build 2007):                                   |
//| - REMOVED 9 silent strategies that generated ZERO signals in     |
//|   8.7-year backtest (2017-2025):                                  |
//|   * Divergence, ElliottWaves, HarmonicPatterns, MACrossover      |
//|   * PivotPoints, TimeAnalysis, WolfeWaves                         |
//|   * Plus: Bollinger, Fibonacci, Ichimoku, Momentum, VolumeProfile|
//|     (these were not separately implemented)                       |
//| - Reduced from 14 strategies to 7 ACTIVE strategies only          |
//| - Cleaned up all related code, includes, and parameters           |
//| - Improved code maintainability and performance                   |
//|                                                                   |
//| Previous Builds:                                                  |
//| - Build 2006: PriceAction weight boost + time filter             |
//| - Build 2004: Baseline restored ($992.14, 307 trades)            |
//| - Build 2002/2003: Failed optimizations (reverted)               |
//| - Build 2001: Strategy combination filters                        |
//|                                                                   |
//| Key Features:                                                     |
//| - 7 proven technical analysis strategies                          |
//| - Weighted confirmation system                                    |
//| - Dynamic ATR-based stop loss/take profit                         |
//| - Automatic trailing stop loss                                    |
//| - Risk management with position sizing                            |
//| - 24/7 trading (no session restrictions)                          |
//| - Bad trading day detection                                       |
//|                                                                   |
//| ACTIVE Strategies (7):                                            |
//| 1. Candle Patterns    - 93.3% win rate, +$19.89 (8.7 years)      |
//| 2. Chart Patterns     - 85.2% win rate, -$14.13 (8.7 years)      |
//| 3. Price Action       - 84.0% win rate, +$15.57 (8.7 years)      |
//| 4. Indicators         - 83.6% win rate, -$749.49 (8.7 years)     |
//| 5. Support/Resistance - 84.7% win rate, -$272.52 (8.7 years)     |
//| 6. Volume Analysis    - 86.0% win rate, -$377.40 (8.7 years)     |
//| 7. Multi-Timeframe    - 83.4% win rate, -$629.25 (8.7 years)     |
//|                                                                   |
//| REMOVED Silent Strategies (9):                                    |
//| - Divergence, ElliottWaves, HarmonicPatterns, MACrossover        |
//| - PivotPoints, TimeAnalysis, WolfeWaves                           |
//| - Bollinger, Fibonacci, Ichimoku, Momentum, VolumeProfile        |
//|   (These generated ZERO signals in 8.7-year backtest)            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://www.mql5.com"
#property version   "2.30"
#property strict

//+------------------------------------------------------------------+
//| Libraries and custom files                                        |
//+------------------------------------------------------------------+
// Main trading libraries
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/AccountInfo.mqh>

// Custom strategy files - ACTIVE STRATEGIES ONLY (7 strategies)
// Removed 9 silent strategies that generated zero signals in 8.7-year backtest (2017-2025):
// - Divergence, ElliottWaves, HarmonicPatterns, MACrossover, WolfeWaves, PivotPoints, TimeAnalysis
// - Plus: Bollinger, Fibonacci, Ichimoku, Momentum, VolumeProfile (not separately implemented)
#include "CandlePatterns.mqh"
#include "ChartPatterns.mqh"
#include "PriceAction.mqh"
#include "Indicators.mqh"
#include "VolumeAnalysis.mqh"
#include "MultiTimeframe.mqh"
#include "SupportResistance.mqh"
#include "TrendPatterns.mqh"
// #include "SignalFilterSystem.mqh"  // REMOVED: 6-Gate Filter System disabled
#include "TradeTracker.mqh"

// Version and Build Information
#define EA_VERSION "2.3.0"
#define EA_BUILD 2009
#define EA_BUILD_DATE "2025-10-30"

// Input values for settings
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;   // Timeframe
input double   Risk_Percent = 3.5;              // Risk percentage per trade from capital (3.5%)
input double   Fixed_Lot_Size = 0.1;           // Fixed lot size (if 0, use risk percentage)
input double   Max_Lot_Size = 0.3;              // Maximum lot size
input double   Max_Position_Volume = 1.0;       // Maximum volume of open positions
input int      Max_Positions = 1;               // Maximum number of open positions
input int      Min_Confirmations = 7;           // Minimum number of confirmations

// Declaration of input variables for general parameters
input string              General_Settings = "---- General Settings ----"; // Main parameters
input int                 Magic_Number = 123456;                  // Robot identification number (change if running multiple EAs)
const bool                Require_MainTrend_Alignment = true;     // Align with main trend (core strategy, always enabled)

// Strategy activation - ACTIVE STRATEGIES ONLY (7 strategies)
// Removed silent strategies: ElliottWaves, Divergence, HarmonicPatterns, MACrossover, PivotPoints, TimeAnalysis, WolfeWaves
input bool     Use_CandlePatterns = true;       // Use candle patterns
input bool     Use_ChartPatterns = true;        // Use chart patterns
input bool     Use_PriceAction = true;          // Use price action
input bool     Use_Indicators = true;           // Use indicators
input bool     Use_SupportResistance = true;    // Use support and resistance levels
input bool     Use_VolumeAnalysis = true;       // Use volume analysis
input bool     Use_MultiTimeframe = true;       // Use multi-timeframe analysis
input bool     G_Debug = false;                 // Enable debug messages

input int      StopLoss_Pips = 100;             // Default stop loss (pips)
input int      TakeProfit_Pips = 150;          // Take profit in pips (increased from 100 to 150)
input bool     Use_Dynamic_StopLoss = true;    // Use dynamic stop loss
const int      ATR_Period = 14;                // ATR period (standard, do not change)
input double   ATR_StopLoss_Multiplier = 2.0;  // ATR multiplier for stop loss (increased from 1.5 to 2.0)
input double   ATR_TakeProfit_Multiplier = 4.0;// ATR multiplier for take profit (increased from 3.0 to 4.0)
input bool     Use_SR_Levels = true;           // Use support/resistance levels for stop loss/profit
const int      max_trades_per_candle = 1;      // Maximum trades per candle (risk control, do not change)
const int      MA_Trend_Period = 100;          // MA period for main trend (optimized, do not change)
const bool     Use_Main_Trend_Filter = true;   // Use main trend filter (core strategy, always enabled)

// Dynamic TP/SL based on signal strength
input string              Signal_Strength_Settings = "---- Signal Strength TP/SL ----"; // Signal strength parameters
input bool                Use_Signal_Strength_TPSL = true;                    // Enable dynamic TP/SL based on signal strength
const int                 Signal_Strength_High_Threshold = 10;                // High confidence threshold (calibrated, do not change)
const int                 Signal_Strength_Low_Threshold = 5;                  // Low confidence threshold (calibrated, do not change)
input double              TP_Multiplier_High_Signal = 1.5;                    // TP multiplier for high signal strength (wider TP)
input double              TP_Multiplier_Low_Signal = 0.8;                     // TP multiplier for low signal strength (tighter TP)
input double              SL_Multiplier_High_Signal = 0.8;                    // SL multiplier for high signal strength (tighter SL)
input double              SL_Multiplier_Low_Signal = 1.2;                     // SL multiplier for low signal strength (wider SL)
const double              TP_Multiplier_Min = 0.5;                            // Minimum TP multiplier (safety bound, do not change)
const double              TP_Multiplier_Max = 2.0;                            // Maximum TP multiplier (safety bound, do not change)
const double              SL_Multiplier_Min = 0.5;                            // Minimum SL multiplier (safety bound, do not change)
const double              SL_Multiplier_Max = 1.5;                            // Maximum SL multiplier (safety bound, do not change)

// Performance and timing parameters
const int      Min_Seconds_Between_Trades = 60;     // Minimum seconds between trades (risk control, do not change)
const int      Min_Tick_Processing_Interval = 5;    // Performance optimization (do not change)

// Volatility and risk filters
const double   High_Volatility_Threshold = 1.5;     // ATR multiplier for high volatility (calibrated for gold, do not change)
const double   Extreme_Movement_Threshold = 1.5;    // Price change % threshold (calibrated for gold, do not change)
const int      Bad_Day_Score_Threshold = 3;         // Bad day score threshold (calibrated, do not change)

// Trailing Stop Loss Settings
input string              Trailing_Stop_Settings = "---- Trailing Stop Loss ----"; // Trailing stop parameters
input bool                Use_Trailing_Stop = true;                    // Enable trailing stop loss
input bool                Use_ATR_Trailing = true;                     // Use ATR for trailing distance (if false, uses pips)
input double              Trailing_Stop_Pips = 50;                     // Trailing stop distance in pips (if not using ATR)
input double              ATR_Trailing_Multiplier = 1.2;               // ATR multiplier for trailing distance (reduced from 1.5 to allow tighter trailing)
input double              Min_Profit_To_Trail_Pips = 60;               // Minimum profit in pips before trailing activates (increased from 30 to let trades breathe)
const bool                Trail_After_Breakeven = true;                // Only trail after breakeven (best practice, always enabled)

// Loss Prevention Filters (Phase 1 & 2)
input string              Loss_Prevention_Settings = "---- Loss Prevention Filters ----"; // Loss prevention parameters
input bool                Use_Time_Based_Filter = true;                // Enable time-based filters (hours 09:00, 02:00, 15:00)
input bool                Use_ADX_Direction_Filter = true;             // Enable ADX + direction filters
input bool                Use_RSI_Extreme_Filter = true;               // Enable RSI extreme filters
input int                 Filter_Hour_1 = 9;                           // First hour to filter (default: 09:00)
input int                 Filter_Hour_2 = 2;                           // Second hour to filter (default: 02:00)
input int                 Filter_Hour_3 = 15;                          // Third hour to filter (default: 15:00)
input double              ADX_Short_Threshold = 45.0;                  // ADX threshold for SHORT trades (default: 45)
input double              RSI_Short_Oversold = 30.0;                   // RSI oversold threshold for SHORT (default: 30)
input double              RSI_Long_Overbought = 70.0;                  // RSI overbought threshold for LONG (default: 70)

// Weights of strategies (importance of each strategy) - ACTIVE STRATEGIES ONLY (7 strategies)
// Removed weights for silent strategies: ElliottWaves, Divergence, HarmonicPatterns, MACrossover, PivotPoints, TimeAnalysis, WolfeWaves
// OPTIMIZED WEIGHTS: Balanced to encourage MultiStrategy trades (91.49% win rate, $4.04 avg profit)
// Strategy: Reduce individual weights so no single strategy can reach Min_Confirmations=7 alone
// This forces multiple strategies to contribute, creating more profitable MultiStrategy signals
input int      CandlePatterns_Weight = 2;      // Weight of candle patterns (increased from 1)
input int      ChartPatterns_Weight = 3;       // Weight of chart patterns (increased from 2)
input int      PriceAction_Weight = 2;         // Weight of price action (kept at 2 - was dominating)
input int      Indicators_Weight = 2;          // Weight of indicators (increased from 1)
input int      SupportResistance_Weight = 3;   // Weight of support and resistance levels
input int      VolumeAnalysis_Weight = 2;      // Weight of volume analysis
input int      MultiTimeframe_Weight = 2;      // Weight of multi-timeframe analysis

// Global variables
CTrade trade;                      // Trading object
CPositionInfo position;           // Position info object
CAccountInfo account;             // Account info object

// Signal filtration system - REMOVED
// CSignalFilter g_signal_filter;    // Signal filter instance (6-Gate Filter System disabled)

// Trade control variables
datetime last_trade_time = 0;       // Last trade time
int trades_this_candle = 0;         // Number of trades in this candle
datetime current_candle_time = 0;   // Current candle time
string g_last_error_reason = "";    // Last error reason for failed position opening

// Global variables for indicators
int handle_rsi, handle_macd, handle_adx, handle_stoch, handle_ma_fast, handle_ma_slow, handle_bbands;
double rsi[], macd[], macd_signal[], adx[], stoch_k[], stoch_d[], ma_fast[], ma_slow[], bb_upper[], bb_middle[], bb_lower[];

// Additional moving average variables for crossovers
int handle_ma_50, handle_ma_200;
double ma_50[], ma_200[];

// Main trend MA variables
int handle_ma_trend;      // Handle for main trend MA
double ma_trend[];        // Buffer for main trend MA values

// Volume analysis variables
int handle_volumes;
double hist_volumes[];    // For internal use with CopyBuffer
long g_volumes[];        // To satisfy the extern in Indicators.mqh

// Global variables for pivot points are defined in PivotPoints.mqh

// Arrays for support and resistance levels are defined in SupportResistance.mqh

// System variables
int bars_total;
datetime last_candle_time; // Last processed candle time
bool is_backtest = false; // Are we in backtest mode?
int Min_Candles_For_Analysis = 100; // Minimum number of candles required for analysis
bool indicators_warmup_warning_shown = false; // Flag to show warmup warning only once

// Forward declarations
// Forward declarations removed - functions are defined in respective .mqh files
bool PrepareHistoricalData();
bool UpdateIndicatorsSafe();
bool CheckTiltFilter(bool isBuy, MqlRates &rates[]);
bool IsBadTradingDay();
bool SafeOpenBuyPosition(int signal_strength = 0);
bool SafeOpenSellPosition(int signal_strength = 0);
void CalculateTPSLMultipliers(int signal_strength, double &tp_multiplier, double &sl_multiplier);

// Constants
#define ERR_ARRAY_INDEX_OUT_OF_RANGE 4002  // Define the error code for array index out of range

// Global variables for historical data
MqlRates g_rates[];  // Renamed from rates to g_rates to avoid conflicts

// Timeframe variables for modules
ENUM_TIMEFRAMES CP_Timeframe;  // For CandlePatterns module
ENUM_TIMEFRAMES CHP_Timeframe; // For ChartPatterns module
ENUM_TIMEFRAMES TP_Timeframe;  // For TrendPatterns module
ENUM_TIMEFRAMES EW_Timeframe;  // For ElliottWaves module
ENUM_TIMEFRAMES VA_Timeframe;  // For VolumeAnalysis module
ENUM_TIMEFRAMES TA_Timeframe;  // For TimeAnalysis module
ENUM_TIMEFRAMES PA_Timeframe;  // For PriceAction module
ENUM_TIMEFRAMES IND_Timeframe; // For Indicators module
ENUM_TIMEFRAMES HP_Timeframe;  // For HarmonicPatterns module
ENUM_TIMEFRAMES DIV_Timeframe; // For Divergence module
ENUM_TIMEFRAMES MTF_Timeframe; // For MultiTimeframe module
ENUM_TIMEFRAMES PP_Timeframe;  // For PivotPoints module
ENUM_TIMEFRAMES WW_Timeframe;  // For WolfeWaves module

// Array for allowed trading days in TimeAnalysis module 
// Additional variables needed
int handle_atr;
double atr[];

// Trade tracking
CTradeTracker g_trade_tracker;
string g_current_strategy_name = "MultiStrategy";  // Current strategy generating signal

// Global strategy vote tracking for JSON export - ACTIVE STRATEGIES ONLY (7 strategies)
int g_strategy_votes[7];  // Stores votes for 7 active strategies (was 14)
// Gate filter variables removed - 6-Gate Filter System disabled
// double g_current_quality_score = 0;
// int g_current_gates_passed = 0;
// string g_current_rejection_gate = "";
// string g_current_rejection_reason = "";

// Filter statistics
int g_filter_rejections_pa1cp1 = 0;
int g_filter_rejections_cp2 = 0;
int g_filter_rejections_pa1cp2 = 0;
// int g_filter_rejections_pa_solo = 0;  // REMOVED in Build 2003 - too aggressive

input double   Min_RR_Ratio = 1.5;                     // Minimum acceptable risk-reward ratio

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // === PRINT VERSION AND BUILD INFO ===
   Print("========================================");
   Print("GoldTraderEA Version: ", EA_VERSION);
   Print("Build Number: ", EA_BUILD);
   Print("Build Date: ", EA_BUILD_DATE);
   Print("Risk Percent: ", Risk_Percent, "%");
   Print("Filters Active: CP(2), PA(1),CP(2)");
   Print("Filters REMOVED: PA(1),CP(1) - was rejecting 70% of signals");
   Print("========================================");

   // === Input Parameter Validation ===

   // Validate risk parameters
   if(Risk_Percent <= 0 || Risk_Percent > 10) {
      Print("ERROR: Risk_Percent must be between 0 and 10. Current value: ", Risk_Percent);
      return INIT_PARAMETERS_INCORRECT;
   }

   if(Max_Lot_Size <= 0 || Max_Lot_Size > 100) {
      Print("ERROR: Max_Lot_Size must be between 0 and 100. Current value: ", Max_Lot_Size);
      return INIT_PARAMETERS_INCORRECT;
   }

   if(Min_Confirmations < 1 || Min_Confirmations > 50) {
      Print("ERROR: Min_Confirmations must be between 1 and 50. Current value: ", Min_Confirmations);
      return INIT_PARAMETERS_INCORRECT;
   }

   // Validate stop loss/take profit
   if(StopLoss_Pips < 10 || StopLoss_Pips > 1000) {
      Print("ERROR: StopLoss_Pips must be between 10 and 1000. Current value: ", StopLoss_Pips);
      return INIT_PARAMETERS_INCORRECT;
   }

   if(TakeProfit_Pips < 10 || TakeProfit_Pips > 2000) {
      Print("ERROR: TakeProfit_Pips must be between 10 and 2000. Current value: ", TakeProfit_Pips);
      return INIT_PARAMETERS_INCORRECT;
   }

   // Validate ATR multipliers
   if(ATR_StopLoss_Multiplier <= 0 || ATR_StopLoss_Multiplier > 10) {
      Print("ERROR: ATR_StopLoss_Multiplier must be between 0 and 10. Current value: ", ATR_StopLoss_Multiplier);
      return INIT_PARAMETERS_INCORRECT;
   }

   if(ATR_TakeProfit_Multiplier <= 0 || ATR_TakeProfit_Multiplier > 20) {
      Print("ERROR: ATR_TakeProfit_Multiplier must be between 0 and 20. Current value: ", ATR_TakeProfit_Multiplier);
      return INIT_PARAMETERS_INCORRECT;
   }

   // Validate trailing stop parameters
   if(Use_Trailing_Stop) {
      if(Trailing_Stop_Pips < 5 || Trailing_Stop_Pips > 500) {
         Print("ERROR: Trailing_Stop_Pips must be between 5 and 500. Current value: ", Trailing_Stop_Pips);
         return INIT_PARAMETERS_INCORRECT;
      }

      if(ATR_Trailing_Multiplier <= 0 || ATR_Trailing_Multiplier > 10) {
         Print("ERROR: ATR_Trailing_Multiplier must be between 0 and 10. Current value: ", ATR_Trailing_Multiplier);
         return INIT_PARAMETERS_INCORRECT;
      }

      if(Min_Profit_To_Trail_Pips < 0 || Min_Profit_To_Trail_Pips > 500) {
         Print("ERROR: Min_Profit_To_Trail_Pips must be between 0 and 500. Current value: ", Min_Profit_To_Trail_Pips);
         return INIT_PARAMETERS_INCORRECT;
      }
   }

   // Validate at least one strategy is enabled (7 active strategies only)
   bool any_strategy_enabled = (Use_CandlePatterns || Use_ChartPatterns || Use_PriceAction ||
                                 Use_Indicators || Use_SupportResistance || Use_VolumeAnalysis ||
                                 Use_MultiTimeframe);

   if(!any_strategy_enabled) {
      Print("ERROR: At least one strategy must be enabled!");
      return INIT_PARAMETERS_INCORRECT;
   }

   Print("Input parameters validated successfully");

   // === Continue with existing initialization ===
   // Initialize historical data
   if(!PrepareHistoricalData()) {
      return INIT_FAILED;
   }
   
   // Initialize indicators
   handle_rsi = iRSI(Symbol(), Timeframe, 14, PRICE_CLOSE);
   handle_macd = iMACD(Symbol(), Timeframe, 12, 26, 9, PRICE_CLOSE);
   handle_adx = iADX(Symbol(), Timeframe, 14);
   handle_stoch = iStochastic(Symbol(), Timeframe, 14, 3, 3, MODE_SMA, STO_LOWHIGH);  // Changed from 5,3,3 (fast) to 14,3,3 (standard/slow) for more reliable signals
   handle_ma_fast = iMA(Symbol(), Timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   handle_ma_slow = iMA(Symbol(), Timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   handle_bbands = iBands(Symbol(), Timeframe, 20, 2, 0, PRICE_CLOSE);

   // Additional moving averages for crossovers
   handle_ma_50 = iMA(Symbol(), Timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
   handle_ma_200 = iMA(Symbol(), Timeframe, 200, 0, MODE_SMA, PRICE_CLOSE);

   // Initialize main trend MA
   handle_ma_trend = iMA(Symbol(), Timeframe, MA_Trend_Period, 0, MODE_SMA, PRICE_CLOSE);

   // Initialize ATR
   handle_atr = iATR(Symbol(), Timeframe, ATR_Period);

   // Volume data
   handle_volumes = iVolumes(Symbol(), Timeframe, VOLUME_TICK);

   if(handle_rsi == INVALID_HANDLE || handle_macd == INVALID_HANDLE || handle_adx == INVALID_HANDLE ||
      handle_stoch == INVALID_HANDLE || handle_ma_fast == INVALID_HANDLE || handle_ma_slow == INVALID_HANDLE ||
      handle_bbands == INVALID_HANDLE || handle_ma_50 == INVALID_HANDLE || handle_ma_200 == INVALID_HANDLE ||
      handle_ma_trend == INVALID_HANDLE || handle_atr == INVALID_HANDLE)
   {
       Print("Error creating indicator handles");
       return(INIT_FAILED);
   }
   
   // Print warning if volume data is not available
   if(handle_volumes == INVALID_HANDLE) {
       Print("Warning: Volume data is not available for this symbol. Volume-based strategies will be disabled.");
   }
   
   // Set timeframe for different modules
   CP_Timeframe = Timeframe;  // Set timeframe for candle patterns module
   CHP_Timeframe = Timeframe; // Set timeframe for chart patterns module
   TP_Timeframe = Timeframe;  // Set timeframe for trend module
   EW_Timeframe = Timeframe;  // Set timeframe for Elliott waves module (legacy variable, not used)
   VA_Timeframe = Timeframe;  // Set timeframe for volume analysis module
   TA_Timeframe = Timeframe;  // Set timeframe for time analysis module (legacy variable, not used)
   SetSRTimeframe(Timeframe); // Set timeframe for support and resistance module (using new function)
   PA_Timeframe = Timeframe;  // Set timeframe for price action module
   // SetMACTimeframe(Timeframe); // REMOVED - MACrossover strategy removed in v2.2.0
   // SetMAParameters(8, 21, 200, MODE_EMA, PRICE_CLOSE); // REMOVED - MACrossover strategy removed in v2.2.0
   IND_Timeframe = Timeframe; // Set timeframe for indicators module
   HP_Timeframe = Timeframe;  // Set timeframe for harmonic patterns module (legacy variable, not used)
   DIV_Timeframe = Timeframe; // Set timeframe for divergence module (legacy variable, not used)
   MTF_Timeframe = Timeframe; // Set timeframe for multi-timeframe module
   PP_Timeframe = Timeframe;  // Set timeframe for pivot points module (legacy variable, not used)
   WW_Timeframe = Timeframe;  // Set timeframe for Wolfe waves module (legacy variable, not used)
   
   // Initialize extern variables in SupportResistance.mqh
   // This section is no longer needed as the variables are no longer extern and have been initialized in the file
   
   // Allocate arrays
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(macd, true);
   ArraySetAsSeries(macd_signal, true);
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(stoch_k, true);
   ArraySetAsSeries(stoch_d, true);
   ArraySetAsSeries(ma_fast, true);
   ArraySetAsSeries(ma_slow, true);
   ArraySetAsSeries(bb_upper, true);
   ArraySetAsSeries(bb_middle, true);
   ArraySetAsSeries(bb_lower, true);
   ArraySetAsSeries(ma_50, true);
   ArraySetAsSeries(ma_200, true);
   ArraySetAsSeries(ma_trend, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(hist_volumes, true);
   ArraySetAsSeries(g_volumes, true);
   
   // Trading object settings
   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetDeviationInPoints(5); // Allowed price deviation
   trade.LogLevel(1);           // Log level for detailed view
   trade.SetAsyncMode(false);    // Synchronous mode
   
   // Save last candle time
   last_candle_time = iTime(Symbol(), Timeframe, 0);
   DebugPrint("Last candle time at start: " + TimeToString(last_candle_time));
   
   // Backtest settings
   is_backtest = MQLInfoInteger(MQL_TESTER);
   if(is_backtest) {
       DebugPrint("Running in backtest mode detected");
       // In backtest mode, reduce the number of required candles
       Min_Candles_For_Analysis = 20; // Fewer candles for analysis in backtest
   } else {
       Min_Candles_For_Analysis = 100; // Standard number of candles for analysis in live mode
   }
   DebugPrint("Minimum number of candles required for analysis: " + IntegerToString(Min_Candles_For_Analysis));

   // Initial calculation of daily/weekly pivot levels
   // CalculatePivotLevels(); // REMOVED - PivotPoints strategy removed in v2.2.0

   // Identify support and resistance levels
   IdentifySupportResistanceLevels();
   
   // Define ATR handle
   handle_atr = iATR(Symbol(), Timeframe, ATR_Period);
   if(handle_atr == INVALID_HANDLE) {
       Print("Error creating ATR indicator handle");
       return(INIT_FAILED);
   }
   ArraySetAsSeries(atr, true);

   // Initialize multi-timeframe analysis module
   if(!InitializeMultiTimeframeIndicators()) {
      DebugPrint("Error initializing multi-timeframe analysis module");
      return INIT_FAILED;
   }

   // Signal filtration system removed - 6-Gate Filter System disabled
   // if(!g_signal_filter.Initialize())
   // {
   //    Print("ERROR: Failed to initialize Signal Filtration System");
   //    return INIT_FAILED;
   // }
   // Print("Signal Filtration System initialized successfully");

   // Initialize trade tracker with CSV file
   datetime current_time = TimeCurrent();

   // Create timestamp in format YYYYMMDD_HHMMSS
   MqlDateTime dt;
   TimeToStruct(current_time, dt);
   string timestamp = StringFormat("%04d%02d%02d_%02d%02d%02d",
                                    dt.year, dt.mon, dt.day,
                                    dt.hour, dt.min, dt.sec);

   // Get timeframe string (e.g., "H1", "M15", "D1")
   string timeframe_str = EnumToString(Period());
   // Remove "PERIOD_" prefix if present
   StringReplace(timeframe_str, "PERIOD_", "");

   // Get symbol (e.g., "XAUUSD", "EURUSD")
   string symbol_str = Symbol();

   // Build filenames with new convention: timestamp_timeframe_symbol_basename.extension
   string csv_filename = timestamp + "_" + timeframe_str + "_" + symbol_str + "_TradePerformance.csv";
   string json_filename = timestamp + "_" + timeframe_str + "_" + symbol_str + "_TradeSignals.json";

   if(!g_trade_tracker.InitializeCSV(csv_filename))
   {
      Print("WARNING: Failed to initialize trade tracker CSV. Continuing without trade tracking.");
   }
   else
   {
      Print("Trade tracker initialized: ", csv_filename);
   }

   // Build EA settings string for JSON export
   string ea_settings = "";
   ea_settings += "    \"ea_settings\": {\n";
   ea_settings += "      \"risk_percent\": " + DoubleToString(Risk_Percent, 2) + ",\n";
   ea_settings += "      \"fixed_lot_size\": " + DoubleToString(Fixed_Lot_Size, 2) + ",\n";
   ea_settings += "      \"max_lot_size\": " + DoubleToString(Max_Lot_Size, 2) + ",\n";
   ea_settings += "      \"max_positions\": " + IntegerToString(Max_Positions) + ",\n";
   ea_settings += "      \"min_confirmations\": " + IntegerToString(Min_Confirmations) + ",\n";
   ea_settings += "      \"magic_number\": " + IntegerToString(Magic_Number) + ",\n";
   ea_settings += "      \"require_main_trend_alignment\": " + (Require_MainTrend_Alignment ? "true" : "false") + ",\n";
   ea_settings += "      \"strategies\": {\n";
   ea_settings += "        \"use_candle_patterns\": " + (Use_CandlePatterns ? "true" : "false") + ",\n";
   ea_settings += "        \"use_chart_patterns\": " + (Use_ChartPatterns ? "true" : "false") + ",\n";
   ea_settings += "        \"use_price_action\": " + (Use_PriceAction ? "true" : "false") + ",\n";
   ea_settings += "        \"use_indicators\": " + (Use_Indicators ? "true" : "false") + ",\n";
   ea_settings += "        \"use_support_resistance\": " + (Use_SupportResistance ? "true" : "false") + ",\n";
   ea_settings += "        \"use_volume_analysis\": " + (Use_VolumeAnalysis ? "true" : "false") + ",\n";
   ea_settings += "        \"use_multi_timeframe\": " + (Use_MultiTimeframe ? "true" : "false") + "\n";
   ea_settings += "      },\n";
   ea_settings += "      \"strategy_weights\": {\n";
   ea_settings += "        \"candle_patterns\": " + IntegerToString(CandlePatterns_Weight) + ",\n";
   ea_settings += "        \"chart_patterns\": " + IntegerToString(ChartPatterns_Weight) + ",\n";
   ea_settings += "        \"price_action\": " + IntegerToString(PriceAction_Weight) + ",\n";
   ea_settings += "        \"indicators\": " + IntegerToString(Indicators_Weight) + ",\n";
   ea_settings += "        \"support_resistance\": " + IntegerToString(SupportResistance_Weight) + ",\n";
   ea_settings += "        \"volume_analysis\": " + IntegerToString(VolumeAnalysis_Weight) + ",\n";
   ea_settings += "        \"multi_timeframe\": " + IntegerToString(MultiTimeframe_Weight) + "\n";
   ea_settings += "      },\n";
   ea_settings += "      \"stop_loss_take_profit\": {\n";
   ea_settings += "        \"stop_loss_pips\": " + IntegerToString(StopLoss_Pips) + ",\n";
   ea_settings += "        \"take_profit_pips\": " + IntegerToString(TakeProfit_Pips) + ",\n";
   ea_settings += "        \"use_dynamic_stop_loss\": " + (Use_Dynamic_StopLoss ? "true" : "false") + ",\n";
   ea_settings += "        \"atr_period\": " + IntegerToString(ATR_Period) + ",\n";
   ea_settings += "        \"atr_stop_loss_multiplier\": " + DoubleToString(ATR_StopLoss_Multiplier, 2) + ",\n";
   ea_settings += "        \"atr_take_profit_multiplier\": " + DoubleToString(ATR_TakeProfit_Multiplier, 2) + ",\n";
   ea_settings += "        \"use_sr_levels\": " + (Use_SR_Levels ? "true" : "false") + "\n";
   ea_settings += "      },\n";
   ea_settings += "      \"signal_strength\": {\n";
   ea_settings += "        \"use_signal_strength_tpsl\": " + (Use_Signal_Strength_TPSL ? "true" : "false") + ",\n";
   ea_settings += "        \"high_threshold\": " + IntegerToString(Signal_Strength_High_Threshold) + ",\n";
   ea_settings += "        \"low_threshold\": " + IntegerToString(Signal_Strength_Low_Threshold) + ",\n";
   ea_settings += "        \"tp_multiplier_high\": " + DoubleToString(TP_Multiplier_High_Signal, 2) + ",\n";
   ea_settings += "        \"tp_multiplier_low\": " + DoubleToString(TP_Multiplier_Low_Signal, 2) + ",\n";
   ea_settings += "        \"sl_multiplier_high\": " + DoubleToString(SL_Multiplier_High_Signal, 2) + ",\n";
   ea_settings += "        \"sl_multiplier_low\": " + DoubleToString(SL_Multiplier_Low_Signal, 2) + "\n";
   ea_settings += "      },\n";
   ea_settings += "      \"trailing_stop\": {\n";
   ea_settings += "        \"use_trailing_stop\": " + (Use_Trailing_Stop ? "true" : "false") + ",\n";
   ea_settings += "        \"use_atr_trailing\": " + (Use_ATR_Trailing ? "true" : "false") + ",\n";
   ea_settings += "        \"trailing_stop_pips\": " + DoubleToString(Trailing_Stop_Pips, 1) + ",\n";
   ea_settings += "        \"atr_trailing_multiplier\": " + DoubleToString(ATR_Trailing_Multiplier, 2) + ",\n";
   ea_settings += "        \"min_profit_to_trail_pips\": " + DoubleToString(Min_Profit_To_Trail_Pips, 1) + ",\n";
   ea_settings += "        \"trail_after_breakeven\": " + (Trail_After_Breakeven ? "true" : "false") + "\n";
   ea_settings += "      },\n";
   ea_settings += "      \"risk_management\": {\n";
   ea_settings += "        \"min_rr_ratio\": " + DoubleToString(Min_RR_Ratio, 2) + ",\n";
   ea_settings += "        \"min_seconds_between_trades\": " + IntegerToString(Min_Seconds_Between_Trades) + ",\n";
   ea_settings += "        \"max_trades_per_candle\": " + IntegerToString(max_trades_per_candle) + ",\n";
   ea_settings += "        \"high_volatility_threshold\": " + DoubleToString(High_Volatility_Threshold, 2) + ",\n";
   ea_settings += "        \"extreme_movement_threshold\": " + DoubleToString(Extreme_Movement_Threshold, 2) + ",\n";
   ea_settings += "        \"bad_day_score_threshold\": " + IntegerToString(Bad_Day_Score_Threshold) + "\n";
   ea_settings += "      },\n";
   ea_settings += "      \"trend_filter\": {\n";
   ea_settings += "        \"use_main_trend_filter\": " + (Use_Main_Trend_Filter ? "true" : "false") + ",\n";
   ea_settings += "        \"ma_trend_period\": " + IntegerToString(MA_Trend_Period) + "\n";
   ea_settings += "      }\n";
   ea_settings += "    }\n";

   // Initialize JSON trade export
   if(!g_trade_tracker.InitializeJSON(json_filename, ea_settings))
   {
      Print("WARNING: Failed to initialize JSON trade export. Continuing without JSON tracking.");
   }
   else
   {
      Print("JSON trade export initialized: ", json_filename);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator resources
    IndicatorRelease(handle_rsi);
    IndicatorRelease(handle_macd);
    IndicatorRelease(handle_adx);
    IndicatorRelease(handle_stoch);
    IndicatorRelease(handle_ma_fast);
    IndicatorRelease(handle_ma_slow);
    IndicatorRelease(handle_bbands);
    IndicatorRelease(handle_atr);
    IndicatorRelease(handle_ma_50);
    IndicatorRelease(handle_ma_200);
    IndicatorRelease(handle_ma_trend);

    // Release volume indicator handle
    if(handle_volumes != INVALID_HANDLE)
        IndicatorRelease(handle_volumes);

    // Release MACrossover module resources
    // DeinitMACrossover(); // REMOVED - MACrossover strategy removed in v2.2.0

    // Release MultiTimeframe resources
    CleanupMultiTimeframeIndicators();

    // Cleanup signal filter - REMOVED (6-Gate Filter System disabled)
    // g_signal_filter.Deinitialize();

    // Print trade performance summary
    g_trade_tracker.PrintPerformanceSummary();
    g_trade_tracker.PrintStrategyBreakdown();
    g_trade_tracker.CloseCSV();
    g_trade_tracker.CloseJSON();

    // Print filter statistics
    Print("========================================");
    Print("FILTER STATISTICS [Build ", EA_BUILD, "]:");
    Print("  PA(1),CP(1) rejected: ", g_filter_rejections_pa1cp1);
    Print("  CP(2) rejected: ", g_filter_rejections_cp2);
    Print("  PA(1),CP(2) rejected: ", g_filter_rejections_pa1cp2);
    // Print("  PA-Solo rejected: ", g_filter_rejections_pa_solo);  // REMOVED in Build 2003
    Print("  Total filtered: ", g_filter_rejections_pa1cp1 + g_filter_rejections_cp2 + g_filter_rejections_pa1cp2);
    Print("========================================");

    Print("GoldTraderEA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Check if extreme market conditions require additional confirmation|
//| Returns true if signal should be rejected                         |
//+------------------------------------------------------------------+
bool RequiresAdditionalConfirmation(bool is_buy, int &votes[])
{
   // Get current market indicator values
   double current_rsi = (ArraySize(rsi) > 0) ? rsi[0] : 50.0;
   double current_adx = (ArraySize(adx) > 0) ? adx[0] : 25.0;
   double current_macd = (ArraySize(macd) > 0) ? macd[0] : 0.0;

   // Check if we're in extreme zones
   bool rsi_extreme = false;
   bool adx_extreme = false;
   bool macd_extreme = false;

   // RSI extreme zones
   if(is_buy && current_rsi > 65.0) {
      rsi_extreme = true;
      if(G_Debug) DebugPrint("EXTREME ZONE: RSI overbought (" + DoubleToString(current_rsi, 2) + ") for LONG trade");
   }
   else if(!is_buy && current_rsi < 35.0) {
      rsi_extreme = true;
      if(G_Debug) DebugPrint("EXTREME ZONE: RSI oversold (" + DoubleToString(current_rsi, 2) + ") for SHORT trade");
   }

   // ADX extreme zone (strong trend, potential exhaustion)
   if(current_adx > 45.0) {
      adx_extreme = true;
      if(G_Debug) DebugPrint("EXTREME ZONE: ADX high (" + DoubleToString(current_adx, 2) + ") - potential trend exhaustion");
   }

   // MACD extreme zones
   if(current_macd > 15.0 || current_macd < -15.0) {
      macd_extreme = true;
      if(G_Debug) DebugPrint("EXTREME ZONE: MACD extreme (" + DoubleToString(current_macd, 2) + ") - extreme momentum");
   }

   // If no extreme conditions, no additional confirmation needed
   if(!rsi_extreme && !adx_extreme && !macd_extreme) {
      return false;
   }

   // We're in extreme conditions - check if only MTF and PA are voting
   // Index mapping: 0=Candle, 1=Chart, 2=PA, 3=Indicator, 4=SR, 5=Volume, 6=MTF
   bool has_mtf = (votes[6] != 0);  // MultiTimeframe
   bool has_pa = (votes[2] != 0);   // PriceAction

   // Check if we have confirmation from Indicators, SupportResistance, or VolumeAnalysis
   bool has_indicators = (votes[3] != 0);      // Indicators
   bool has_sr = (votes[4] != 0);              // SupportResistance
   bool has_volume = (votes[5] != 0);          // VolumeAnalysis

   bool has_additional_confirmation = has_indicators || has_sr || has_volume;

   // Count total strategies voting
   int strategies_voting = 0;
   for(int i = 0; i < 7; i++) {
      if(votes[i] != 0) strategies_voting++;
   }

   // If only MTF and PA are voting (or just one of them), and we're in extreme conditions
   if(strategies_voting <= 2 && has_mtf && has_pa && !has_additional_confirmation) {
      if(G_Debug) {
         DebugPrint("EXTREME MARKET FILTER REJECT: Only MTF+PA voting in extreme conditions");
         DebugPrint("  RSI: " + DoubleToString(current_rsi, 2) + (rsi_extreme ? " [EXTREME]" : ""));
         DebugPrint("  ADX: " + DoubleToString(current_adx, 2) + (adx_extreme ? " [EXTREME]" : ""));
         DebugPrint("  MACD: " + DoubleToString(current_macd, 2) + (macd_extreme ? " [EXTREME]" : ""));
         DebugPrint("  Strategies voting: " + IntegerToString(strategies_voting));
         DebugPrint("  Need at least one of: Indicators, SupportResistance, or VolumeAnalysis");
      }
      return true;  // Reject the signal
   }

   // Additional confirmation present or not just MTF+PA
   if(G_Debug && (rsi_extreme || adx_extreme || macd_extreme)) {
      DebugPrint("EXTREME MARKET: Additional confirmation present - signal allowed");
      DebugPrint("  Indicators: " + (has_indicators ? "YES" : "NO"));
      DebugPrint("  SupportResistance: " + (has_sr ? "YES" : "NO"));
      DebugPrint("  VolumeAnalysis: " + (has_volume ? "YES" : "NO"));
   }

   return false;  // Allow the signal
}

//+------------------------------------------------------------------+
//| Loss Prevention Filter (Phase 1 & 2)                             |
//| Returns true if signal should be rejected based on historical    |
//| loss patterns. Filters based on time, ADX+direction, RSI extremes|
//+------------------------------------------------------------------+
bool ShouldFilterTrade(bool is_buy, double current_rsi, double current_adx)
{
   // Get current hour
   MqlDateTime time_struct;
   TimeToStruct(TimeCurrent(), time_struct);
   int current_hour = time_struct.hour;

   // PHASE 1: Time-based filters
   // Hours 09:00, 02:00, 15:00 show poor historical performance
   // Impact: +$4,000 combined
   if(Use_Time_Based_Filter) {
      if(current_hour == Filter_Hour_1 || current_hour == Filter_Hour_2 || current_hour == Filter_Hour_3) {
         if(G_Debug) {
            Print("LOSS PREVENTION FILTER REJECT [Build ", EA_BUILD, "]: Hour ", current_hour, ":00");
            Print("  Historical data shows poor performance during this hour");
            Print("  Expected impact: Prevents high-loss trades");
         }
         return true;  // Reject the signal
      }
   }

   // PHASE 1: ADX + Direction filter
   // ADX > 45 + SHORT shows 61.3% win rate (below 68% average)
   // Impact: +$1,279
   if(Use_ADX_Direction_Filter) {
      if(!is_buy && current_adx > ADX_Short_Threshold) {
         if(G_Debug) {
            Print("LOSS PREVENTION FILTER REJECT [Build ", EA_BUILD, "]: ADX > ", ADX_Short_Threshold, " for SHORT");
            Print("  ADX: ", DoubleToString(current_adx, 2));
            Print("  Reason: Strong trend exhaustion risk for SHORT trades");
            Print("  Expected impact: +$1,279 improvement");
         }
         return true;  // Reject the signal
      }
   }

   // PHASE 2: RSI Extreme filters
   // RSI < 30 + SHORT: 53.3% win rate (worst performing pattern)
   // RSI > 70 + LONG: 69.1% win rate (marginal)
   // Combined impact: +$2,017
   if(Use_RSI_Extreme_Filter) {
      // RSI < 30 for SHORT trades (oversold bounce risk)
      if(!is_buy && current_rsi < RSI_Short_Oversold) {
         if(G_Debug) {
            Print("LOSS PREVENTION FILTER REJECT [Build ", EA_BUILD, "]: RSI < ", RSI_Short_Oversold, " for SHORT");
            Print("  RSI: ", DoubleToString(current_rsi, 2));
            Print("  Reason: Oversold bounce risk - market may reverse up");
            Print("  Expected impact: +$1,144 improvement");
         }
         return true;  // Reject the signal
      }

      // RSI > 70 for LONG trades (overbought reversal risk)
      if(is_buy && current_rsi > RSI_Long_Overbought) {
         if(G_Debug) {
            Print("LOSS PREVENTION FILTER REJECT [Build ", EA_BUILD, "]: RSI > ", RSI_Long_Overbought, " for LONG");
            Print("  RSI: ", DoubleToString(current_rsi, 2));
            Print("  Reason: Overbought reversal risk - market may reverse down");
            Print("  Expected impact: +$873 improvement");
         }
         return true;  // Reject the signal
      }
   }

   return false;  // Don't filter - trade is acceptable
}

//+------------------------------------------------------------------+
//| Build strategy consensus data for trade tracking                 |
//+------------------------------------------------------------------+
void BuildStrategyConsensus(bool is_buy, int &votes[], StrategySignal &strategy_votes[],
                           int &vote_count, int &buy_count, int &sell_count, int &none_count,
                           int &total_weight_buy, int &total_weight_sell, int &total_enabled, int &total_checked)
{
   vote_count = 0;
   buy_count = 0;
   sell_count = 0;
   none_count = 0;
   total_weight_buy = 0;
   total_weight_sell = 0;
   total_enabled = 0;
   total_checked = 0;

   // votes[] array: [candle, chart, pa, indicator, sr, volume, mtf]
   // Index mapping for ACTIVE STRATEGIES ONLY (7 strategies):
   // 0=CandlePatterns, 1=ChartPatterns, 2=PriceAction, 3=Indicators
   // 4=SupportResistance, 5=VolumeAnalysis, 6=MultiTimeframe
   // REMOVED: ElliottWaves, Divergence, HarmonicPatterns, MACrossover, PivotPoints, TimeAnalysis, WolfeWaves

   string strategy_names[] = {"CandlePatterns", "ChartPatterns", "PriceAction", "Indicators",
                              "SupportResistance", "VolumeAnalysis", "MultiTimeframe"};
   int strategy_weights[] = {CandlePatterns_Weight, ChartPatterns_Weight, PriceAction_Weight, Indicators_Weight,
                            SupportResistance_Weight, VolumeAnalysis_Weight, MultiTimeframe_Weight};
   bool strategy_enabled[] = {Use_CandlePatterns, Use_ChartPatterns, Use_PriceAction, Use_Indicators,
                              Use_SupportResistance, Use_VolumeAnalysis, Use_MultiTimeframe};

   for(int i = 0; i < 7; i++)
   {
      // Count all enabled strategies (regardless of whether they were checked)
      if(strategy_enabled[i])
         total_enabled++;

      // Skip disabled strategies
      if(!strategy_enabled[i])
         continue;

      // Skip strategies that were not checked (vote = 0)
      // Note: Due to early-exit optimization, not all enabled strategies are always checked
      if(votes[i] == 0)
         continue;

      // Count only strategies that were actually checked (non-zero votes)
      total_checked++;

      strategy_votes[vote_count].strategy_name = strategy_names[i];
      strategy_votes[vote_count].weight = strategy_weights[i];
      strategy_votes[vote_count].is_primary = false;

      // Determine vote based on signal value
      if(votes[i] > 0)
      {
         // Store the actual vote count, preserving original sign for JSON export
         // Positive votes always mean BUY signal (regardless of trade direction)
         strategy_votes[vote_count].signal_vote = votes[i];
         if(is_buy)
         {
            // For BUY trades: positive vote = BUY signal (agreeing)
            buy_count++;
            total_weight_buy += votes[i] * strategy_weights[i];
         }
         else
         {
            // For SELL trades: positive vote = conflicting BUY signal
            buy_count++;
            total_weight_buy += votes[i] * strategy_weights[i];
         }
      }
      else if(votes[i] < 0)
      {
         // Store the actual vote count, preserving original sign for JSON export
         // Negative votes always mean SELL signal (regardless of trade direction)
         strategy_votes[vote_count].signal_vote = votes[i];
         if(is_buy)
         {
            // For BUY trades: negative vote = conflicting SELL signal
            sell_count++;
            total_weight_sell += MathAbs(votes[i]) * strategy_weights[i];
         }
         else
         {
            // For SELL trades: negative vote = SELL signal (agreeing)
            sell_count++;
            total_weight_sell += MathAbs(votes[i]) * strategy_weights[i];
         }
      }

      vote_count++;
   }
}

//+------------------------------------------------------------------+
//| Trade event handler - tracks position closures                    |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Check for closed positions in history
    HistorySelect(0, TimeCurrent());

    int total_deals = HistoryDealsTotal();

    for(int i = total_deals - 1; i >= MathMax(0, total_deals - 10); i--)  // Check last 10 deals
    {
        ulong deal_ticket = HistoryDealGetTicket(i);

        if(deal_ticket == 0) continue;

        // Only process exit deals (OUT)
        if(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;

        // Only process deals for this EA's magic number
        if(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != Magic_Number)
            continue;

        // Only process deals for this symbol
        if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != Symbol())
            continue;

        // Get deal information
        ulong position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
        double exit_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
        double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);

        // Determine exit reason based on deal comment
        string comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
        string exit_reason = "Unknown";

        if(StringFind(comment, "sl") >= 0 || StringFind(comment, "stop loss") >= 0)
            exit_reason = "Stop Loss";
        else if(StringFind(comment, "tp") >= 0 || StringFind(comment, "take profit") >= 0)
            exit_reason = "Take Profit";
        else if(StringFind(comment, "trailing") >= 0)
            exit_reason = "Trailing Stop";
        else if(StringFind(comment, "close") >= 0)
            exit_reason = "Manual Close";
        else
            exit_reason = "Market Close";

        // Record the exit in trade tracker
        g_trade_tracker.RecordTradeExit(position_id, exit_price, profit, exit_reason);
    }
}

//+------------------------------------------------------------------+
//| Debugging and displaying information                               |
//+------------------------------------------------------------------+
void DebugPrint(string message)
{
    // If in backtest or optimization, suppress messages
    if(MQLInfoInteger(MQL_OPTIMIZATION))
        return;
        
    // If in testing mode, only show error messages
    if(MQLInfoInteger(MQL_TESTER) && StringFind(message, "Error") < 0)
        return;
        
    // If debug is enabled, display the message
    if(G_Debug)
        Print(message);
}

//+------------------------------------------------------------------+
//| Print indicator status                                            |
//+------------------------------------------------------------------+
bool PrintIndicatorStatus()
{
    string status = "Indicator Status:\n";
    
    // Check array sizes before accessing
    if(ArraySize(rsi) >= 2) {
        status += "RSI(0): " + DoubleToString(rsi[0], 2) + "\n";
        status += "RSI(1): " + DoubleToString(rsi[1], 2) + "\n";
    } else {
        status += "RSI: Array is smaller than required\n";
        // Ensure the array has values
        if(ArraySize(rsi) < 2) ArrayResize(rsi, 2);
    }
    
    if(ArraySize(macd) >= 1) {
        status += "MACD(0): " + DoubleToString(macd[0], 5) + "\n";
    } else {
        status += "MACD: Array is smaller than required\n";
        // Ensure the array has values
        if(ArraySize(macd) < 1) ArrayResize(macd, 1);
    }
    
    if(ArraySize(macd_signal) >= 1) {
        status += "MACD Signal(0): " + DoubleToString(macd_signal[0], 5) + "\n";
    } else {
        status += "MACD Signal: Array is smaller than required\n";
        // Ensure the array has values
        if(ArraySize(macd_signal) < 1) ArrayResize(macd_signal, 1);
    }
    
    if(ArraySize(ma_fast) >= 1) {
        status += "MA Fast(0): " + DoubleToString(ma_fast[0], 5) + "\n";
    } else {
        status += "MA Fast: Array is smaller than required\n";
        // Ensure the array has values
        if(ArraySize(ma_fast) < 1) ArrayResize(ma_fast, 1);
    }
    
    if(ArraySize(ma_slow) >= 1) {
        status += "MA Slow(0): " + DoubleToString(ma_slow[0], 5) + "\n";
    } else {
        status += "MA Slow: Array is smaller than required\n";
        // Ensure the array has values
        if(ArraySize(ma_slow) < 1) ArrayResize(ma_slow, 1);
    }
    
    DebugPrint(status);
    return true;
}

//+------------------------------------------------------------------+
//| Print trading confirmations                                        |
//+------------------------------------------------------------------+
void PrintConfirmations(int buy_confirmations, int sell_confirmations)
{
    string confirmations = "Confirmations with weighting:\n";
    confirmations += "Buy: " + IntegerToString(buy_confirmations) + "/" + IntegerToString(Min_Confirmations) + "\n";
    confirmations += "Sell: " + IntegerToString(sell_confirmations) + "/" + IntegerToString(Min_Confirmations) + "\n";
    
    // Display strategy weights (ACTIVE STRATEGIES ONLY - 7 strategies)
    confirmations += "\nStrategy Weights:\n";
    confirmations += "Candle Patterns: " + IntegerToString(CandlePatterns_Weight) + "\n";
    confirmations += "Chart Patterns: " + IntegerToString(ChartPatterns_Weight) + "\n";
    confirmations += "Price Action: " + IntegerToString(PriceAction_Weight) + "\n";
    confirmations += "Indicators: " + IntegerToString(Indicators_Weight) + "\n";
    confirmations += "Support/Resistance: " + IntegerToString(SupportResistance_Weight) + "\n";
    confirmations += "Volume Analysis: " + IntegerToString(VolumeAnalysis_Weight) + "\n";
    confirmations += "Multi-Timeframe Analysis: " + IntegerToString(MultiTimeframe_Weight);
    
    DebugPrint(confirmations);
}

//+------------------------------------------------------------------+
//| Check array size to prevent errors                                 |
//+------------------------------------------------------------------+
bool CheckArraySize(MqlRates &rates[], int min_size, string function_name)
{
    int size = ArraySize(rates);
    if(size < min_size) {
        DebugPrint(function_name + ": Array is smaller than required - Size: " + IntegerToString(size) + ", Required: " + IntegerToString(min_size));
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Check array to prevent out of range errors                        |
//+------------------------------------------------------------------+
bool CheckArrayAccess(int index, int array_size, string function_name)
{
    if(index < 0 || index >= array_size) {
        if(G_Debug) {
            Print("Error in " + function_name + ": Index " + IntegerToString(index) + 
                   " out of range (Size: " + IntegerToString(array_size) + ")");
        }
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Quick check for computation needs
    static datetime last_processed_time = 0;
    datetime current_time = TimeCurrent();
    
    // If too much time has passed since the last analysis, exit early (speed optimization)
    if(current_time - last_processed_time < Min_Tick_Processing_Interval && last_processed_time > 0 && !is_backtest) {
        return;
    }
    
    // Only if debug is enabled, display the message
    if(G_Debug) DebugPrint("Starting OnTick execution");

    // Check rates array - only get the current candle
    MqlRates current_candle[];
    ArraySetAsSeries(current_candle, true);
    int copied = CopyRates(Symbol(), Timeframe, 0, 1, current_candle);
    
    if(copied <= 0) {
        if(G_Debug) DebugPrint("Error retrieving current candle data - Code: " + IntegerToString(GetLastError()));
        return;
    }

    // Quick check - has a new candle formed or is the previous candle still ongoing
    bool is_new_candle = (current_candle_time != current_candle[0].time);
    
    // If it's the first execution or a new candle has formed
    if(current_candle_time == 0 || is_new_candle) {
        // First execution or new candle
        current_candle_time = current_candle[0].time;
        trades_this_candle = 0;
        if(G_Debug) DebugPrint(current_candle_time == 0 ? "First execution of EA" : "New candle formed");
    } else {
        // Same previous candle - quick check of limits
        if(trades_this_candle >= max_trades_per_candle) {
            // Reached maximum trades in this candle
            return;
        }
        
        // Check time interval since the last trade
        if(current_time - last_trade_time < Min_Seconds_Between_Trades) {
            // Still not reached the allowed time interval
            return;
        }
    }
    
    // Note the last processed time
    last_processed_time = current_time;

    // Manage trailing stop for existing positions (runs on every tick)
    ManageTrailingStop();

    // Check if volume data is available
    bool volume_data_available = (handle_volumes != INVALID_HANDLE);
    // If VolumeAnalysis is requested but no volume data is available, show a warning
    if(Use_VolumeAnalysis && !volume_data_available && G_Debug) {
        DebugPrint("Volume data is not available. Volume-based strategies are disabled.");
    }
    
    // Now retrieve all necessary data
    MqlRates local_rates[];
    ArraySetAsSeries(local_rates, true);
    copied = CopyRates(Symbol(), Timeframe, 0, Min_Candles_For_Analysis, local_rates);

    if(copied <= 0) {
        if(G_Debug) DebugPrint("Error retrieving candle data - Code: " + IntegerToString(GetLastError()));
        return;
    }

    // Critical: Validate sufficient data was copied
    if(copied < 10) {
        DebugPrint("Error: Failed to copy sufficient rate data. Copied: " + IntegerToString(copied));
        return;
    }

    if(copied < Min_Candles_For_Analysis && G_Debug) {
        DebugPrint("Warning: Number of candles retrieved is less than required.");
    }

    // Check if there is enough data for initial analysis
    int min_candles = is_backtest ? 10 : 30;
    if(copied < min_candles) {
        return;
    }

    if(G_Debug) DebugPrint("Successfully copied " + IntegerToString(copied) + " candles");
    
    // Update indicator data - only if needed
    if(!UpdateIndicatorsSafe()) {
        Print(">>> Error updating indicators at " + TimeToString(TimeCurrent()) + " <<<");
        return;
    }
    
    // Only if debug is enabled, print the indicator status
    if(G_Debug) PrintIndicatorStatus();
    
    // Quick check of the overall market trend - initial filter
    bool potential_buy = true;
    bool potential_sell = true;
    
    // Quick initial filter for buy/sell using moving average
    if(Require_MainTrend_Alignment && ArraySize(ma_200) > 0) {
        double current_price = local_rates[0].close;
        
        // Check price position relative to MA200
        bool price_above_ma200 = current_price > ma_200[0];
        
        // Only check for buy if price is above MA200
        potential_buy = price_above_ma200;
        potential_sell = !price_above_ma200;
    }
    
    // Check market tilt to filter out unsuitable trades - only if needed
    bool tilt_ok = true;
    if(potential_buy) {
        tilt_ok = CheckTiltFilter(true, local_rates);
        if(!tilt_ok) {
            potential_buy = false;
            if(G_Debug) DebugPrint("Buy signal rejected: Market tilt filter");
        }
    }
    
    if(potential_sell && tilt_ok) { // If tilt has been checked, don't check again
        tilt_ok = CheckTiltFilter(false, local_rates);
        if(!tilt_ok) {
            potential_sell = false;
            if(G_Debug) DebugPrint("Sell signal rejected: Market tilt filter");
        }
    }
    
    // If no trading positions are possible, exit early
    if(!potential_buy && !potential_sell) {
        return;
    }
    
    // Check if today is a bad trading day, do not open new trades
    if(IsBadTradingDay()) {
        if(G_Debug) DebugPrint("Inappropriate trading day, no new trades will be opened.");
        return;
    }
    
    // Check conditions and confirmations
    int buy_confirmations = 0;
    int sell_confirmations = 0;

    // Declare strategy signal variables at function scope for later use in signal filter
    // ACTIVE STRATEGIES ONLY (7 strategies) - removed ma_buy/sell, harmonic_buy/sell
    bool indicator_buy = false, indicator_sell = false;
    int pa_buy = 0, pa_sell = 0;
    int chart_buy = 0, chart_sell = 0;

    // Initialize global strategy votes array for JSON export
    // Index mapping for ACTIVE STRATEGIES (7): 0=Candle, 1=Chart, 2=PA, 3=Indicator, 4=SR, 5=Volume, 6=MTF
    // REMOVED silent strategies: Elliott, Divergence, Harmonic, MA, Pivot, Time, Wolfe
    ArrayInitialize(g_strategy_votes, 0);

    // 1. Check indicators (they are faster)
    if(Use_Indicators) {
        if(potential_buy) {
            indicator_buy = SafeCheckIndicatorsBuy(local_rates);
            buy_confirmations += (indicator_buy ? Indicators_Weight : 0);
            g_strategy_votes[3] = indicator_buy ? 1 : 0;  // Index 3 = Indicators
            if(G_Debug) DebugPrint("Indicator check result for buy: " + (indicator_buy ? "Positive" : "Negative"));
        }

        if(potential_sell) {
            indicator_sell = SafeCheckIndicatorsShort(local_rates);
            sell_confirmations += (indicator_sell ? Indicators_Weight : 0);
            g_strategy_votes[3] = indicator_sell ? -1 : 0;  // Index 3 = Indicators
            if(G_Debug) DebugPrint("Indicator check result for sell: " + (indicator_sell ? "Positive" : "Negative"));
        }
    }

    // 2. Check candle patterns
    if(Use_CandlePatterns && (potential_buy || potential_sell)) {
        if(potential_buy) {
            int candle_buy = CheckCandlePatternsBuy();
            buy_confirmations += candle_buy * CandlePatterns_Weight;
            g_strategy_votes[0] = candle_buy;  // Index 0 = CandlePatterns
            if(G_Debug) DebugPrint("Number of candle confirmations for buy: " + IntegerToString(candle_buy));
        }

        if(potential_sell) {
            int candle_sell = CheckCandlePatternsShort();
            sell_confirmations += candle_sell * CandlePatterns_Weight;
            g_strategy_votes[0] = -candle_sell;  // Index 0 = CandlePatterns (negative for sell)
            if(G_Debug) DebugPrint("Number of candle confirmations for sell: " + IntegerToString(candle_sell));
        }
    }

    // === BUILD 2007: BEST SIGNAL WINS - Calculate both directions fully for fair comparison ===
    // Removed early exit optimization to ensure both buy and sell get full evaluation

    // 3. Price action
    if(Use_PriceAction && (potential_buy || potential_sell)) {
        if(potential_buy) {
            pa_buy = CheckPriceActionBuy();
            buy_confirmations += pa_buy * PriceAction_Weight;
            g_strategy_votes[2] = pa_buy;  // Index 2 = PriceAction
            if(G_Debug) DebugPrint("Number of price action confirmations for buy: " + IntegerToString(pa_buy));
        }

        if(potential_sell) {
            pa_sell = CheckPriceActionShort();
            sell_confirmations += pa_sell * PriceAction_Weight;
            g_strategy_votes[2] = -pa_sell;  // Index 2 = PriceAction (negative for sell)
            if(G_Debug) DebugPrint("Number of price action confirmations for sell: " + IntegerToString(pa_sell));
        }
    }

    // 4. Chart patterns
    if(Use_ChartPatterns && (potential_buy || potential_sell)) {
        if(potential_buy) {
            chart_buy = CheckChartPatternsBuy();
            buy_confirmations += chart_buy * ChartPatterns_Weight;
            g_strategy_votes[1] = chart_buy;  // Index 1 = ChartPatterns
            if(G_Debug) DebugPrint("Number of chart confirmations for buy: " + IntegerToString(chart_buy));
        }

        if(potential_sell) {
            chart_sell = CheckChartPatternsShort();
            sell_confirmations += chart_sell * ChartPatterns_Weight;
            g_strategy_votes[1] = -chart_sell;  // Index 1 = ChartPatterns (negative for sell)
            if(G_Debug) DebugPrint("Number of chart confirmations for sell: " + IntegerToString(chart_sell));
        }
    }

    // 5. Support and resistance levels
    if(Use_SupportResistance && (potential_buy || potential_sell)) {
        if(potential_buy) {
            int sr_buy = CheckSupportResistanceBuy();
            buy_confirmations += sr_buy * SupportResistance_Weight;
            g_strategy_votes[4] = sr_buy;  // Index 4 = SupportResistance
            if(G_Debug) DebugPrint("Number of S/R confirmations for buy: " + IntegerToString(sr_buy));
        }

        if(potential_sell) {
            int sr_sell = CheckSupportResistanceShort();
            sell_confirmations += sr_sell * SupportResistance_Weight;
            g_strategy_votes[4] = -sr_sell;  // Index 4 = SupportResistance (negative for sell)
            if(G_Debug) DebugPrint("Number of S/R confirmations for sell: " + IntegerToString(sr_sell));
        }
    }

    // 6. Volume analysis (if enabled and volume data is available)
    if(Use_VolumeAnalysis && volume_data_available && (potential_buy || potential_sell)) {
        if(potential_buy) {
            int va_buy = CheckVolumeAnalysisBuy(local_rates);
            buy_confirmations += va_buy * VolumeAnalysis_Weight;
            g_strategy_votes[5] = va_buy;  // Index 5 = VolumeAnalysis
            if(G_Debug) DebugPrint("Number of volume analysis confirmations for buy: " + IntegerToString(va_buy));
        }

        if(potential_sell) {
            int va_sell = CheckVolumeAnalysisShort(local_rates);
            sell_confirmations += va_sell * VolumeAnalysis_Weight;
            g_strategy_votes[5] = -va_sell;  // Index 5 = VolumeAnalysis (negative for sell)
            if(G_Debug) DebugPrint("Number of volume analysis confirmations for sell: " + IntegerToString(va_sell));
        }
    }

    // 7. Multi-Timeframe Analysis (if enabled)
    if(Use_MultiTimeframe && (potential_buy || potential_sell)) {
        if(potential_buy) {
            int mtf_buy = CheckMultiTimeframeBuy(local_rates);
            buy_confirmations += mtf_buy * MultiTimeframe_Weight;
            g_strategy_votes[6] = mtf_buy;  // Index 6 = MultiTimeframe
            if(G_Debug) DebugPrint("Number of multi-timeframe confirmations for buy: " + IntegerToString(mtf_buy));
        }

        if(potential_sell) {
            int mtf_sell = CheckMultiTimeframeShort(local_rates);
            sell_confirmations += mtf_sell * MultiTimeframe_Weight;
            g_strategy_votes[6] = -mtf_sell;  // Index 6 = MultiTimeframe (negative for sell)
            if(G_Debug) DebugPrint("Number of multi-timeframe confirmations for sell: " + IntegerToString(mtf_sell));
        }
    }

    // Print buy and sell confirmation status if debug is enabled
    if(G_Debug) {
        DebugPrint("Buy confirmations: " + IntegerToString(buy_confirmations) +
                  ", Sell confirmations: " + IntegerToString(sell_confirmations));
    }

    // === BUILD 2004: MULTISTRATEGY BOOST REMOVED (caused -99.8% profit loss) ===
    // Reverted to Build 2001 baseline - no confirmation manipulation

    // If we have no confirmations, stop processing
    if(buy_confirmations < Min_Confirmations && sell_confirmations < Min_Confirmations) {
        if(G_Debug) DebugPrint("Not enough confirmations, exiting processing.");
        return;
    }
    
    // From here, continue only if we have at least one signal
    
    // Check open positions
    double current_volume = 0;
    bool have_buy_position = false;
    bool have_sell_position = false;
    
    // Efficiently check open positions
    if(PositionsTotal() > 0) {
        for(int i=0; i<PositionsTotal(); i++) {
            if(position.SelectByIndex(i)) {
                if(position.Symbol() == Symbol()) {
                    current_volume += position.Volume();
                    
                    if(position.PositionType() == POSITION_TYPE_BUY)
                        have_buy_position = true;
                    else if(position.PositionType() == POSITION_TYPE_SELL)
                        have_sell_position = true;
                        
                    // If both types of positions are found, we can exit the loop early
                    if(have_buy_position && have_sell_position)
                        break;
                }
            }
        }
    }
    
    // Initial check of maximum volume
    if(current_volume >= Max_Position_Volume) {
        if(G_Debug) DebugPrint("Current volume has reached the maximum allowed: " + DoubleToString(current_volume, 2));
        return;
    }
    
    // Check trading limits
    
    // Current position count
    if(PositionsTotal() >= Max_Positions) {
        if(G_Debug) DebugPrint("Reached maximum number of positions: " + IntegerToString(PositionsTotal()));
        return;
    }
    
    // EA is always active (24/7 trading) - no session restrictions

    // Check opening new position based on confirmations

    // Validate array access before using
    if(copied < 1 || ArraySize(ma_trend) < 1) {
        DebugPrint("Error: Insufficient data for trend check");
        return;
    }

    // Get main trend MA value (now using pre-calculated buffer)
    double ma_main_trend_value = ma_trend[0];  // Current MA value
    double current_close = local_rates[copied-1].close;

    // === BUILD 2007: BEST SIGNAL WINS - Compare both directions and choose stronger signal ===
    // Determine which signal to act on based on strength comparison

    bool should_open_buy = false;
    bool should_open_sell = false;

    // Check if both signals are above threshold
    if(buy_confirmations >= Min_Confirmations && sell_confirmations >= Min_Confirmations) {
        // Both signals are valid - choose the STRONGER one
        if(buy_confirmations > sell_confirmations) {
            should_open_buy = true;
            if(G_Debug) DebugPrint("=== SIGNAL COMPARISON: BUY WINS (Buy: " + IntegerToString(buy_confirmations) +
                                  " vs Sell: " + IntegerToString(sell_confirmations) + ") ===");
        }
        else if(sell_confirmations > buy_confirmations) {
            should_open_sell = true;
            if(G_Debug) DebugPrint("=== SIGNAL COMPARISON: SELL WINS (Sell: " + IntegerToString(sell_confirmations) +
                                  " vs Buy: " + IntegerToString(buy_confirmations) + ") ===");
        }
        else {
            // Equal strength - default to buy (or could skip trade entirely)
            should_open_buy = true;
            if(G_Debug) DebugPrint("=== SIGNAL COMPARISON: EQUAL STRENGTH (Both: " + IntegerToString(buy_confirmations) +
                                  ") - Defaulting to BUY ===");
        }
    }
    else if(buy_confirmations >= Min_Confirmations) {
        // Only buy signal is valid
        should_open_buy = true;
        if(G_Debug) DebugPrint("=== SIGNAL: BUY ONLY (Buy: " + IntegerToString(buy_confirmations) +
                              ", Sell: " + IntegerToString(sell_confirmations) + ") ===");
    }
    else if(sell_confirmations >= Min_Confirmations) {
        // Only sell signal is valid
        should_open_sell = true;
        if(G_Debug) DebugPrint("=== SIGNAL: SELL ONLY (Sell: " + IntegerToString(sell_confirmations) +
                              ", Buy: " + IntegerToString(buy_confirmations) + ") ===");
    }

    // Now execute the chosen signal

    // Buy signal
    if(should_open_buy && !have_buy_position && potential_buy) {
        // Check main trend (if enabled)
        if(!Use_Main_Trend_Filter || current_close > ma_main_trend_value) {

            // === 6-GATE FILTER SYSTEM REMOVED ===
            // Signal filtration system disabled for maximum trading opportunities

            // Set strategy name for tracking (use global variable)
            g_current_strategy_name = "MultiStrategy";

            // === FILTER OUT UNPROFITABLE STRATEGY COMBINATIONS ===
            // === BUILD 2008: PA(1),CP(1) filter REMOVED - Testing if PriceAction performs better ===
            // Previous filter was rejecting 4,050+ signals (70% of all signals)
            // if(pa_buy == 1 && chart_buy == 1) {
            //     g_filter_rejections_pa1cp1++;
            //     Print("FILTER REJECT [Build ", EA_BUILD, "]: PA(1),CP(1) - Total rejected: ", g_filter_rejections_pa1cp1);
            //     return;
            // }

            // Filter all CP(2) combinations - consistently unprofitable
            if(chart_buy == 2) {
                g_filter_rejections_cp2++;
                Print("FILTER REJECT [Build ", EA_BUILD, "]: CP(2) - Total rejected: ", g_filter_rejections_cp2);
                return;
            }

            // Filter PA(1),CP(2) - barely profitable ($0.23 on 26 trades)
            if(pa_buy == 1 && chart_buy == 2) {
                g_filter_rejections_pa1cp2++;
                Print("FILTER REJECT [Build ", EA_BUILD, "]: PA(1),CP(2) - Total rejected: ", g_filter_rejections_pa1cp2);
                return;
            }

            // === BUILD 2003: PA-Solo filter REMOVED (was too aggressive, lost $443) ===
            // Solo PriceAction with high confirmations is actually profitable
            // if(pa_buy > 0 && chart_buy == 0 && !indicator_buy && ma_buy == 0 && harmonic_buy == 0) {
            //     g_filter_rejections_pa_solo++;
            //     Print("FILTER REJECT [Build ", EA_BUILD, "]: PA-Solo (no confirmation) - Total rejected: ", g_filter_rejections_pa_solo);
            //     return;
            // }

            // === EXTREME MARKET CONDITIONS FILTER ===
            // When RSI/ADX/MACD are in extreme zones and only MTF+PA are voting,
            // require additional confirmation from Indicators, SupportResistance, or VolumeAnalysis
            if(RequiresAdditionalConfirmation(true, g_strategy_votes)) {
                Print("FILTER REJECT [Build ", EA_BUILD, "]: Extreme market conditions - MTF+PA only, need additional confirmation");
                return;
            }

            // === LOSS PREVENTION FILTER (PHASE 1 & 2) ===
            // Filter trades based on historical loss patterns:
            // - Time-based: Hours 09:00, 02:00, 15:00 (poor performance)
            // - ADX + Direction: ADX > 45 for SHORT trades
            // - RSI Extremes: RSI > 70 for LONG, RSI < 30 for SHORT
            double current_rsi_value = (ArraySize(rsi) > 0) ? rsi[0] : 50.0;
            double current_adx_value = (ArraySize(adx) > 0) ? adx[0] : 25.0;

            if(ShouldFilterTrade(true, current_rsi_value, current_adx_value)) {
                // Filter already printed debug message
                return;
            }

            if(G_Debug) DebugPrint("Buy conditions confirmed. Attempting to open buy position...");
            // Pass signal strength (buy_confirmations) to enable dynamic TP/SL
            bool result = SafeOpenBuyPosition(buy_confirmations);

            if(G_Debug) {
                if(result)
                    DebugPrint("Buy position opened successfully.");
                else
                    DebugPrint("Error opening buy position. Reason: " + g_last_error_reason);
            }

            // Record last trade time (use actual time, not candle time)
            last_trade_time = TimeCurrent();
            // === BUILD 2007: Don't return immediately - allow sell signal to be evaluated if buy failed ===
            // Only return if position was actually opened
            if(result) return;
        }
        else if(G_Debug) {
            DebugPrint("Buy signal rejected - main trend is not bullish.");
        }
    }

    // Sell signal
    if(should_open_sell && !have_sell_position && potential_sell) {
        // Check main trend (if enabled)
        if(!Use_Main_Trend_Filter || current_close < ma_main_trend_value) {

            // === 6-GATE FILTER SYSTEM REMOVED ===
            // Signal filtration system disabled for maximum trading opportunities

            // Set strategy name for tracking (use global variable)
            g_current_strategy_name = "MultiStrategy";

            // === FILTER OUT UNPROFITABLE STRATEGY COMBINATIONS ===
            // === BUILD 2008: PA(1),CP(1) filter REMOVED - Testing if PriceAction performs better ===
            // Previous filter was rejecting 4,050+ signals (70% of all signals)
            // if(pa_sell == 1 && chart_sell == 1) {
            //     g_filter_rejections_pa1cp1++;
            //     Print("FILTER REJECT [Build ", EA_BUILD, "]: PA(1),CP(1) - Total rejected: ", g_filter_rejections_pa1cp1);
            //     return;
            // }

            // Filter all CP(2) combinations - consistently unprofitable
            if(chart_sell == 2) {
                g_filter_rejections_cp2++;
                Print("FILTER REJECT [Build ", EA_BUILD, "]: CP(2) - Total rejected: ", g_filter_rejections_cp2);
                return;
            }

            // Filter PA(1),CP(2) - barely profitable ($0.23 on 26 trades)
            if(pa_sell == 1 && chart_sell == 2) {
                g_filter_rejections_pa1cp2++;
                Print("FILTER REJECT [Build ", EA_BUILD, "]: PA(1),CP(2) - Total rejected: ", g_filter_rejections_pa1cp2);
                return;
            }

            // === BUILD 2003: PA-Solo filter REMOVED (was too aggressive, lost $443) ===
            // Solo PriceAction with high confirmations is actually profitable
            // if(pa_sell > 0 && chart_sell == 0 && !indicator_sell && ma_sell == 0 && harmonic_sell == 0) {
            //     g_filter_rejections_pa_solo++;
            //     Print("FILTER REJECT [Build ", EA_BUILD, "]: PA-Solo (no confirmation) - Total rejected: ", g_filter_rejections_pa_solo);
            //     return;
            // }

            // === EXTREME MARKET CONDITIONS FILTER ===
            // When RSI/ADX/MACD are in extreme zones and only MTF+PA are voting,
            // require additional confirmation from Indicators, SupportResistance, or VolumeAnalysis
            if(RequiresAdditionalConfirmation(false, g_strategy_votes)) {
                Print("FILTER REJECT [Build ", EA_BUILD, "]: Extreme market conditions - MTF+PA only, need additional confirmation");
                return;
            }

            // === LOSS PREVENTION FILTER (PHASE 1 & 2) ===
            // Filter trades based on historical loss patterns:
            // - Time-based: Hours 09:00, 02:00, 15:00 (poor performance)
            // - ADX + Direction: ADX > 45 for SHORT trades
            // - RSI Extremes: RSI > 70 for LONG, RSI < 30 for SHORT
            double current_rsi_value = (ArraySize(rsi) > 0) ? rsi[0] : 50.0;
            double current_adx_value = (ArraySize(adx) > 0) ? adx[0] : 25.0;

            if(ShouldFilterTrade(false, current_rsi_value, current_adx_value)) {
                // Filter already printed debug message
                return;
            }

            if(G_Debug) DebugPrint("Sell conditions confirmed. Attempting to open sell position...");
            // Pass signal strength (sell_confirmations) to enable dynamic TP/SL
            bool result = SafeOpenSellPosition(sell_confirmations);

            if(G_Debug) {
                if(result)
                    DebugPrint("Sell position opened successfully.");
                else
                    DebugPrint("Error opening sell position. Reason: " + g_last_error_reason);
            }

            // Record last trade time (use actual time, not candle time)
            last_trade_time = TimeCurrent();
            // === BUILD 2007: Return after successful position opening ===
            if(result) return;
        }
        else if(G_Debug) {
            DebugPrint("Sell signal rejected - main trend is not bearish.");
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                             |
//+------------------------------------------------------------------+
double CalculatePositionSize(double entryPrice, double stopLoss)
{
    // Calculate desired risk based on risk percentage from capital
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * Risk_Percent / 100.0;
    
    // Calculate distance from stop loss to entry price in pips
    double pipDistance = MathAbs(entryPrice - stopLoss) / (SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10);
    
    // Calculate the value of one pip for a standard lot
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double pipValue = tickValue * 10;  // Convert tick value to pip value
    
    // Calculate position size
    double positionSize = riskAmount / (pipDistance * pipValue);
    
    // Limit position size to broker limits and EA settings
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    // Normalize position size based on trading steps
    positionSize = MathFloor(positionSize / lotStep) * lotStep;
    
    // Limit to minimum and maximum allowed
    if(positionSize < minLot) positionSize = minLot;
    if(positionSize > maxLot) positionSize = maxLot;
    
    // Limit to maximum allowed in EA
    if(positionSize > Max_Lot_Size) positionSize = Max_Lot_Size;
    
    return positionSize;
}

//+------------------------------------------------------------------+
//| Open a buy position                                              |
//+------------------------------------------------------------------+
bool OpenBuyOrder(double lotSize, double entryPrice, double stopLoss, double takeProfit)
{
    DebugPrint("Attempting to open buy position:");
    DebugPrint("Volume: " + DoubleToString(lotSize, 2));
    DebugPrint("Entry Price: " + DoubleToString(entryPrice, _Digits));
    DebugPrint("Stop Loss: " + DoubleToString(stopLoss, _Digits));
    DebugPrint("Take Profit: " + DoubleToString(takeProfit, _Digits));

    // Use Trade class to open position
    trade.SetExpertMagicNumber(Magic_Number);

    // Open buy position
    bool result = trade.Buy(lotSize, Symbol(), 0, stopLoss, takeProfit, "GoldTrader Buy");

    if(result) {
        ulong ticket = trade.ResultOrder();
        DebugPrint("Buy position opened successfully. Ticket: " + IntegerToString(ticket));

        // Build strategy consensus data
        StrategySignal strategy_votes[20];
        int vote_count, buy_count, sell_count, none_count, total_weight_buy, total_weight_sell, total_enabled, total_checked;
        BuildStrategyConsensus(true, g_strategy_votes, strategy_votes, vote_count, buy_count, sell_count,
                              none_count, total_weight_buy, total_weight_sell, total_enabled, total_checked);

        // Get current indicator values for market context
        double current_adx = (ArraySize(adx) > 0) ? adx[0] : 0;
        double current_rsi = (ArraySize(rsi) > 0) ? rsi[0] : 0;
        double current_macd = (ArraySize(macd) > 0) ? macd[0] : 0;

        // Record trade entry with full consensus data
        g_trade_tracker.RecordTradeEntryWithConsensus(
            ticket,
            g_current_strategy_name,  // Use global variable for strategy name
            "LONG",
            entryPrice,
            stopLoss,
            takeProfit,
            lotSize,
            0.0,  // quality_score (removed - was g_current_quality_score)
            0,    // gates_passed (removed - was g_current_gates_passed)
            "",   // rejection_gate (removed - was g_current_rejection_gate)
            "",   // rejection_reason (removed - was g_current_rejection_reason)
            strategy_votes,
            vote_count,
            total_enabled,
            total_checked,
            buy_count,
            sell_count,
            none_count,
            total_weight_buy,
            total_weight_sell,
            current_adx,
            current_rsi,
            current_macd
        );
        return true;
    } else {
        g_last_error_reason = "MT5 Error " + IntegerToString(trade.ResultRetcode()) + ": " + trade.ResultRetcodeDescription();
        DebugPrint("Error opening buy position: " + g_last_error_reason);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Open a sell position                                             |
//+------------------------------------------------------------------+
bool OpenSellOrder(double lotSize, double entryPrice, double stopLoss, double takeProfit)
{
    DebugPrint("Attempting to open sell position:");
    DebugPrint("Volume: " + DoubleToString(lotSize, 2));
    DebugPrint("Entry Price: " + DoubleToString(entryPrice, _Digits));
    DebugPrint("Stop Loss: " + DoubleToString(stopLoss, _Digits));
    DebugPrint("Take Profit: " + DoubleToString(takeProfit, _Digits));

    // Use Trade class to open position
    trade.SetExpertMagicNumber(Magic_Number);

    // Open sell position
    bool result = trade.Sell(lotSize, Symbol(), 0, stopLoss, takeProfit, "GoldTrader Sell");

    if(result) {
        ulong ticket = trade.ResultOrder();
        DebugPrint("Sell position opened successfully. Ticket: " + IntegerToString(ticket));

        // Build strategy consensus data
        StrategySignal strategy_votes[20];
        int vote_count, buy_count, sell_count, none_count, total_weight_buy, total_weight_sell, total_enabled, total_checked;
        BuildStrategyConsensus(false, g_strategy_votes, strategy_votes, vote_count, buy_count, sell_count,
                              none_count, total_weight_buy, total_weight_sell, total_enabled, total_checked);

        // Get current indicator values for market context
        double current_adx = (ArraySize(adx) > 0) ? adx[0] : 0;
        double current_rsi = (ArraySize(rsi) > 0) ? rsi[0] : 0;
        double current_macd = (ArraySize(macd) > 0) ? macd[0] : 0;

        // Record trade entry with full consensus data
        g_trade_tracker.RecordTradeEntryWithConsensus(
            ticket,
            g_current_strategy_name,  // Use global variable for strategy name
            "SHORT",
            entryPrice,
            stopLoss,
            takeProfit,
            lotSize,
            0.0,  // quality_score (removed - was g_current_quality_score)
            0,    // gates_passed (removed - was g_current_gates_passed)
            "",   // rejection_gate (removed - was g_current_rejection_gate)
            "",   // rejection_reason (removed - was g_current_rejection_reason)
            strategy_votes,
            vote_count,
            total_enabled,
            total_checked,
            buy_count,
            sell_count,
            none_count,
            total_weight_buy,
            total_weight_sell,
            current_adx,
            current_rsi,
            current_macd
        );
        return true;
    } else {
        g_last_error_reason = "MT5 Error " + IntegerToString(trade.ResultRetcode()) + ": " + trade.ResultRetcodeDescription();
        DebugPrint("Error opening sell position: " + g_last_error_reason);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Trailing Stop Loss Management                                     |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    if(!Use_Trailing_Stop) return;

    // Get current price information
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    double pip_value = point * 10;  // Convert points to pips

    // Calculate trailing distance
    double trailing_distance = 0;

    if(Use_ATR_Trailing) {
        // Use ATR-based trailing distance
        if(ArraySize(atr) < 1) {
            DebugPrint("ATR data not available for trailing stop");
            return;
        }
        trailing_distance = atr[0] * ATR_Trailing_Multiplier;
    } else {
        // Use fixed pip-based trailing distance
        trailing_distance = Trailing_Stop_Pips * pip_value;
    }

    // Calculate minimum profit threshold
    double min_profit_distance = Min_Profit_To_Trail_Pips * pip_value;

    // Loop through all open positions
    for(int i = 0; i < PositionsTotal(); i++) {
        if(!position.SelectByIndex(i)) continue;

        // Only manage positions for this symbol and magic number
        if(position.Symbol() != Symbol() || position.Magic() != Magic_Number) continue;

        ulong ticket = position.Ticket();
        double position_open_price = position.PriceOpen();
        double current_sl = position.StopLoss();
        double current_tp = position.TakeProfit();
        ENUM_POSITION_TYPE pos_type = position.PositionType();

        double new_sl = 0;
        bool should_modify = false;

        if(pos_type == POSITION_TYPE_BUY) {
            // BUY position trailing stop logic
            double current_profit = bid - position_open_price;

            // Check if minimum profit threshold is reached
            if(current_profit < min_profit_distance) {
                continue;  // Not enough profit yet to start trailing
            }

            // Check breakeven requirement
            if(Trail_After_Breakeven && current_profit < min_profit_distance) {
                continue;  // Wait for breakeven + minimum profit
            }

            // Calculate new stop loss (price - trailing distance)
            new_sl = bid - trailing_distance;

            // Ensure new SL is above entry price (lock in profit)
            if(new_sl <= position_open_price) {
                new_sl = position_open_price + (min_profit_distance * 0.5);  // Set to small profit above entry
            }

            // Only move SL up, never down
            if(current_sl == 0 || new_sl > current_sl) {
                // Normalize the price
                new_sl = NormalizeDouble(new_sl, _Digits);
                should_modify = true;

                if(G_Debug) {
                    DebugPrint("BUY Trailing Stop - Ticket: " + IntegerToString(ticket) +
                              " | Current SL: " + DoubleToString(current_sl, _Digits) +
                              " | New SL: " + DoubleToString(new_sl, _Digits) +
                              " | Profit: " + DoubleToString(current_profit / pip_value, 1) + " pips");
                }
            }
        }
        else if(pos_type == POSITION_TYPE_SELL) {
            // SELL position trailing stop logic
            double current_profit = position_open_price - ask;

            // Check if minimum profit threshold is reached
            if(current_profit < min_profit_distance) {
                continue;  // Not enough profit yet to start trailing
            }

            // Check breakeven requirement
            if(Trail_After_Breakeven && current_profit < min_profit_distance) {
                continue;  // Wait for breakeven + minimum profit
            }

            // Calculate new stop loss (price + trailing distance)
            new_sl = ask + trailing_distance;

            // Ensure new SL is below entry price (lock in profit)
            if(new_sl >= position_open_price) {
                new_sl = position_open_price - (min_profit_distance * 0.5);  // Set to small profit below entry
            }

            // Only move SL down, never up
            if(current_sl == 0 || new_sl < current_sl) {
                // Normalize the price
                new_sl = NormalizeDouble(new_sl, _Digits);
                should_modify = true;

                if(G_Debug) {
                    DebugPrint("SELL Trailing Stop - Ticket: " + IntegerToString(ticket) +
                              " | Current SL: " + DoubleToString(current_sl, _Digits) +
                              " | New SL: " + DoubleToString(new_sl, _Digits) +
                              " | Profit: " + DoubleToString(current_profit / pip_value, 1) + " pips");
                }
            }
        }

        // Modify the position if needed
        if(should_modify) {
            // Additional check: Only modify if values actually changed
            double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            bool sl_changed = (current_sl == 0 || MathAbs(new_sl - current_sl) > point * 10);
            bool tp_changed = (current_tp != 0 && MathAbs(new_sl - current_sl) > point * 10);

            if(!sl_changed && !tp_changed) {
                // No actual change - skip modification to avoid "Invalid stops" error
                continue;
            }

            // CRITICAL FIX: Select position by ticket before modifying
            // PositionModify requires the position to be selected
            if(!PositionSelectByTicket(ticket)) {
                DebugPrint("ERROR: Failed to select position by ticket: " + IntegerToString(ticket));
                continue;
            }

            // Validate SL/TP levels meet broker requirements
            double min_stop_level = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * point;
            double current_price = (pos_type == POSITION_TYPE_BUY) ? bid : ask;

            // Check minimum distance from current price
            if(pos_type == POSITION_TYPE_BUY) {
                if(new_sl > 0 && (current_price - new_sl) < min_stop_level) {
                    if(G_Debug) {
                        DebugPrint("Skipping modification: SL too close to current price. Distance: " +
                                  DoubleToString((current_price - new_sl) / point, 0) + " points, Min: " +
                                  DoubleToString(min_stop_level / point, 0) + " points");
                    }
                    continue;
                }
            } else {
                if(new_sl > 0 && (new_sl - current_price) < min_stop_level) {
                    if(G_Debug) {
                        DebugPrint("Skipping modification: SL too close to current price. Distance: " +
                                  DoubleToString((new_sl - current_price) / point, 0) + " points, Min: " +
                                  DoubleToString(min_stop_level / point, 0) + " points");
                    }
                    continue;
                }
            }

            trade.SetExpertMagicNumber(Magic_Number);

            if(trade.PositionModify(ticket, new_sl, current_tp)) {
                if(G_Debug) {
                    DebugPrint("Trailing stop updated successfully for ticket: " + IntegerToString(ticket));
                }
            } else {
                DebugPrint("ERROR: Failed to update trailing stop for ticket: " + IntegerToString(ticket) +
                          " | Error: " + IntegerToString(trade.ResultRetcode()) +
                          " - " + trade.ResultRetcodeDescription());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Initialize historical data                                        |
//+------------------------------------------------------------------+
bool PrepareHistoricalData()
{
    // Initialize rates array
    ArraySetAsSeries(g_rates, true);
    int copied = CopyRates(Symbol(), Timeframe, 0, Min_Candles_For_Analysis, g_rates);
    
    if(copied < Min_Candles_For_Analysis) {
        DebugPrint("Failed to copy enough historical data: " + IntegerToString(copied) + " out of " + 
                    IntegerToString(Min_Candles_For_Analysis));
        return false;
    }
    
    // Initialize volume data if needed
    ArraySetAsSeries(hist_volumes, true);
    ArraySetAsSeries(g_volumes, true);
    handle_volumes = iVolumes(Symbol(), Timeframe, VOLUME_TICK);
    
    if(handle_volumes == INVALID_HANDLE) {
        DebugPrint("Warning: Failed to create volumes indicator handle. Volume-based strategies will be disabled.");
        // Initialize arrays with zeros so we can still run without volume data
        ArrayResize(hist_volumes, Min_Candles_For_Analysis);
        ArrayResize(g_volumes, Min_Candles_For_Analysis);
        ArrayInitialize(hist_volumes, 0);
        ArrayInitialize(g_volumes, 0);
        return true; // Continue even without volume data
    }
    
    int volumes_copied = CopyBuffer(handle_volumes, 0, 0, Min_Candles_For_Analysis, hist_volumes);
    
    if(volumes_copied < Min_Candles_For_Analysis) {
        DebugPrint("Warning: Failed to copy enough volume data: " + IntegerToString(volumes_copied) + 
                  ". Volume-based strategies will use limited data or be disabled.");
        // Fill the remaining elements with zeros
        if(volumes_copied > 0) {
            ArrayResize(hist_volumes, Min_Candles_For_Analysis);
            for(int i=volumes_copied; i<Min_Candles_For_Analysis; i++) {
                hist_volumes[i] = 0;
            }
        } else {
            // No volume data at all
            ArrayResize(hist_volumes, Min_Candles_For_Analysis);
            ArrayInitialize(hist_volumes, 0);
        }
    }
    
    // Copy volume data from hist_volumes (double) to g_volumes (long)
    ArrayResize(g_volumes, ArraySize(hist_volumes));
    for(int i=0; i<ArraySize(hist_volumes); i++) {
        g_volumes[i] = (long)hist_volumes[i];
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Update indicators data safely                                     |
//+------------------------------------------------------------------+
bool UpdateIndicatorsSafe()
{
    // Check if indicators have calculated enough bars before copying
    // This prevents errors at the start when indicators are still calculating

    // Update RSI
    if(handle_rsi == INVALID_HANDLE) {
        Print("ERROR: RSI handle is INVALID");
        return false;
    }
    int rsi_bars = BarsCalculated(handle_rsi);
    if(rsi_bars < 3) {
        Print("INDICATOR NOT READY: RSI - Bars calculated: " + IntegerToString(rsi_bars));
        return false;
    }
    if(CopyBuffer(handle_rsi, 0, 0, 3, rsi) < 3) {
        Print("ERROR: Failed to copy RSI data");
        return false;
    }

    // Update MACD
    if(handle_macd == INVALID_HANDLE) {
        Print("ERROR: MACD handle is INVALID");
        return false;
    }
    int macd_bars = BarsCalculated(handle_macd);
    if(macd_bars < 3) {
        Print("INDICATOR NOT READY: MACD - Bars calculated: " + IntegerToString(macd_bars));
        return false;
    }
    if(CopyBuffer(handle_macd, 0, 0, 3, macd) < 3) {
        Print("ERROR: Failed to copy MACD main line data");
        return false;
    }
    if(CopyBuffer(handle_macd, 1, 0, 3, macd_signal) < 3) {
        Print("ERROR: Failed to copy MACD signal line data");
        return false;
    }

    // Update ADX
    if(handle_adx == INVALID_HANDLE) {
        Print("ERROR: ADX handle is INVALID");
        return false;
    }
    int adx_bars = BarsCalculated(handle_adx);
    if(adx_bars < 3) {
        Print("INDICATOR NOT READY: ADX - Bars calculated: " + IntegerToString(adx_bars));
        return false;
    }
    if(CopyBuffer(handle_adx, 0, 0, 3, adx) < 3) {
        Print("ERROR: Failed to copy ADX data");
        return false;
    }

    // Update Stochastic
    if(handle_stoch == INVALID_HANDLE) {
        Print("ERROR: Stochastic handle is INVALID");
        return false;
    }
    int stoch_bars = BarsCalculated(handle_stoch);
    if(stoch_bars < 3) {
        Print("INDICATOR NOT READY: Stochastic - Bars calculated: " + IntegerToString(stoch_bars));
        return false;
    }
    if(CopyBuffer(handle_stoch, 0, 0, 3, stoch_k) < 3) {
        Print("ERROR: Failed to copy Stochastic %K data");
        return false;
    }
    if(CopyBuffer(handle_stoch, 1, 0, 3, stoch_d) < 3) {
        Print("ERROR: Failed to copy Stochastic %D data");
        return false;
    }

    // Update Moving Averages
    if(handle_ma_fast == INVALID_HANDLE) {
        Print("ERROR: Fast MA handle is INVALID");
        return false;
    }
    int ma_fast_bars = BarsCalculated(handle_ma_fast);
    if(ma_fast_bars < 3) {
        Print("INDICATOR NOT READY: Fast MA - Bars calculated: " + IntegerToString(ma_fast_bars));
        return false;
    }
    if(CopyBuffer(handle_ma_fast, 0, 0, 3, ma_fast) < 3) {
        Print("ERROR: Failed to copy fast MA data");
        return false;
    }

    if(handle_ma_slow == INVALID_HANDLE) {
        Print("ERROR: Slow MA handle is INVALID");
        return false;
    }
    int ma_slow_bars = BarsCalculated(handle_ma_slow);
    if(ma_slow_bars < 3) {
        Print("INDICATOR NOT READY: Slow MA - Bars calculated: " + IntegerToString(ma_slow_bars));
        return false;
    }
    if(CopyBuffer(handle_ma_slow, 0, 0, 3, ma_slow) < 3) {
        Print("ERROR: Failed to copy slow MA data");
        return false;
    }

    // Update Bollinger Bands
    if(handle_bbands == INVALID_HANDLE) {
        Print("ERROR: Bollinger Bands handle is INVALID");
        return false;
    }
    int bb_bars = BarsCalculated(handle_bbands);
    if(bb_bars < 3) {
        Print("INDICATOR NOT READY: Bollinger Bands - Bars calculated: " + IntegerToString(bb_bars));
        return false;
    }
    if(CopyBuffer(handle_bbands, 0, 0, 3, bb_middle) < 3) {
        Print("ERROR: Failed to copy BB middle line data");
        return false;
    }
    if(CopyBuffer(handle_bbands, 1, 0, 3, bb_upper) < 3) {
        Print("ERROR: Failed to copy BB upper line data");
        return false;
    }
    if(CopyBuffer(handle_bbands, 2, 0, 3, bb_lower) < 3) {
        Print("ERROR: Failed to copy BB lower line data");
        return false;
    }

    // Update additional MAs
    if(handle_ma_50 == INVALID_HANDLE) {
        Print("ERROR: MA50 handle is INVALID");
        return false;
    }
    int ma_50_bars = BarsCalculated(handle_ma_50);
    if(ma_50_bars < 3) {
        Print("INDICATOR NOT READY: MA50 - Bars calculated: " + IntegerToString(ma_50_bars));
        return false;
    }
    if(CopyBuffer(handle_ma_50, 0, 0, 3, ma_50) < 3) {
        Print("ERROR: Failed to copy MA50 data");
        return false;
    }

    if(handle_ma_200 == INVALID_HANDLE) {
        Print("ERROR: MA200 handle is INVALID");
        return false;
    }
    int ma_200_bars = BarsCalculated(handle_ma_200);
    if(ma_200_bars < 3) {
        Print("INDICATOR NOT READY: MA200 - Bars calculated: " + IntegerToString(ma_200_bars));
        return false;
    }
    if(CopyBuffer(handle_ma_200, 0, 0, 3, ma_200) < 3) {
        Print("ERROR: Failed to copy MA200 data");
        return false;
    }

    // Update ATR
    if(handle_atr == INVALID_HANDLE) {
        Print("ERROR: ATR handle is INVALID");
        return false;
    }
    int atr_bars = BarsCalculated(handle_atr);
    if(atr_bars < 3) {
        Print("INDICATOR NOT READY: ATR - Bars calculated: " + IntegerToString(atr_bars));
        return false;
    }
    if(CopyBuffer(handle_atr, 0, 0, 3, atr) < 3) {
        Print("ERROR: Failed to copy ATR data");
        return false;
    }

    // Update main trend MA
    if(handle_ma_trend == INVALID_HANDLE) {
        Print("ERROR: Main Trend MA handle is INVALID");
        return false;
    }
    int ma_trend_bars = BarsCalculated(handle_ma_trend);
    if(ma_trend_bars < 3) {
        Print("INDICATOR NOT READY: Main Trend MA - Bars calculated: " + IntegerToString(ma_trend_bars));
        return false;
    }
    if(CopyBuffer(handle_ma_trend, 0, 0, 3, ma_trend) < 3) {
        Print("ERROR: Failed to copy main trend MA data");
        return false;
    }

    // Update volume data (only if handle is valid)
    if(handle_volumes != INVALID_HANDLE) {
        if(BarsCalculated(handle_volumes) < 10) {
            // Volume indicator not ready yet
            ArrayInitialize(hist_volumes, 0);
            ArrayResize(g_volumes, 10);
            ArrayInitialize(g_volumes, 0);
        } else {
            int copied = CopyBuffer(handle_volumes, 0, 0, 10, hist_volumes);
            if(copied < 10) {
                DebugPrint("Warning: Failed to copy volume data: " + IntegerToString(copied) +
                           ". Using zeros for missing data.");

                // If we got some data, use it and fill the rest with zeros
                if(copied > 0) {
                    for(int i=copied; i<10; i++) {
                        hist_volumes[i] = 0;
                    }
                } else {
                    // No volume data at all
                    ArrayInitialize(hist_volumes, 0);
                }
            }

            // Copy volume data from hist_volumes (double) to g_volumes (long)
            ArrayResize(g_volumes, ArraySize(hist_volumes));
            for(int i=0; i<ArraySize(hist_volumes); i++) {
                g_volumes[i] = (long)hist_volumes[i];
            }
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check tilt filter - market bias indicator                         |
//+------------------------------------------------------------------+
bool CheckTiltFilter(bool isBuy, MqlRates &rates[])
{
    // A simple tilt filter based on the last several candles
    if(ArraySize(rates) < 5) return true; // Not enough data
    
    int bullish_count = 0;
    int bearish_count = 0;
    
    // Count bullish and bearish candles in the last 5 candles
    for(int i = 0; i < 5; i++) {
        if(rates[i].close > rates[i].open)
            bullish_count++;
        else if(rates[i].close < rates[i].open)
            bearish_count++;
    }
    
    // Check if the market has a strong bias
    if(isBuy && bullish_count >= 3)
        return true; // Market has bullish bias for buy signals
    else if(!isBuy && bearish_count >= 3)
        return true; // Market has bearish bias for sell signals
    else if(bullish_count == bearish_count) 
        return true; // No strong bias, allow trading
        
    // Market has opposite bias
    return false;
}

//+------------------------------------------------------------------+
//| Check if today is a bad trading day based on historical performance |
//+------------------------------------------------------------------+
bool IsBadTradingDay()
{
    // Get current date/time
    MqlDateTime time;
    TimeCurrent(time);
    datetime current_time = TimeCurrent();
    
    // === 1. Day of week filter ===
    // Monday (1) and Friday (5) can be more volatile and unpredictable
    bool is_volatile_day = (time.day_of_week == 1 || time.day_of_week == 5);
    
    // === 2. Month-end/Month-beginning effects ===
    // First 2 days or last 2 days of month can have unusual volatility
    bool is_month_boundary = (time.day <= 2 || time.day >= 28);
    
    // === 3. Holiday proximity check ===
    // Check for major holidays (simplified example)
    bool near_holiday = false;
    
    // Christmas and New Year period
    if (time.mon == 12 && time.day >= 23)
        near_holiday = true;
        
    // First week of January
    if (time.mon == 1 && time.day <= 5)
        near_holiday = true;
    
    // === 4. Check market volatility ===
    bool high_volatility = false;
    
    // Use ATR to measure recent volatility if available
    if (ArraySize(atr) > 0) {
        // Compare current ATR with recent average (e.g., last 5 days)
        double avg_atr = 0;
        int atr_count = 0;
        
        for (int i = 1; i < MathMin(6, ArraySize(atr)); i++) {
            avg_atr += atr[i];
            atr_count++;
        }
        
        if (atr_count > 0) {
            avg_atr /= atr_count;
            // If current ATR is above threshold, market is too volatile
            high_volatility = (atr[0] > avg_atr * High_Volatility_Threshold);
        }
    }
    
    // === 5. Check for recent extreme movement ===
    bool extreme_movement = false;
    
    // If rates array is available, check for recent large moves
    if (ArraySize(g_rates) >= 3) {
        // Calculate recent price change percentage
        double price_change_pct = MathAbs(g_rates[0].close - g_rates[2].close) / g_rates[2].close * 100.0;

        // If price moved more than threshold in the last 3 candles, consider it extreme
        extreme_movement = (price_change_pct > Extreme_Movement_Threshold);
    }
    
    // === 6. Check for NFP (Non-Farm Payroll) days ===
    bool is_nfp_day = false;
    
    // NFP is typically released on the first Friday of each month
    if (time.day_of_week == 5 && time.day <= 7) {
        is_nfp_day = true;
    }
    
    // === 7. Check for important central bank announcement days ===
    // This would require an economic calendar API integration for a full implementation
    // Simplified example for demonstration
    bool central_bank_day = false;
    
    // FOMC announcement days (simplified approximation)
    if ((time.mon == 1 || time.mon == 3 || time.mon == 5 || 
         time.mon == 6 || time.mon == 7 || time.mon == 9 || 
         time.mon == 11) && time.day >= 15 && time.day <= 17) {
        central_bank_day = true;
    }
    
    // === 8. Use TimeAnalysis functions if available ===
    // We could use functions from TimeAnalysis.mqh if needed
    
    // === 9. Calculate total score to determine if it's a bad trading day ===
    int bad_day_score = 0;
    
    if (is_volatile_day) bad_day_score += 1;
    if (is_month_boundary) bad_day_score += 1;
    if (near_holiday) bad_day_score += 2;
    if (high_volatility) bad_day_score += 3;
    if (extreme_movement) bad_day_score += 2;
    if (is_nfp_day) bad_day_score += 3;
    if (central_bank_day) bad_day_score += 2;
    
    // If we have more than threshold points in our bad day score, avoid trading
    bool is_bad_day = (bad_day_score >= Bad_Day_Score_Threshold);
    
    if (G_Debug && is_bad_day) {
        string reason = "Bad trading day detected (score: " + IntegerToString(bad_day_score) + "):";
        if (is_volatile_day) reason += " Volatile day of week;";
        if (is_month_boundary) reason += " Month boundary;";
        if (near_holiday) reason += " Near holiday;";
        if (high_volatility) reason += " High volatility;";
        if (extreme_movement) reason += " Extreme recent movement;";
        if (is_nfp_day) reason += " NFP day;";
        if (central_bank_day) reason += " Central bank announcement day;";
        
        DebugPrint(reason);
    }
    
    return is_bad_day;
}

//+------------------------------------------------------------------+
//| Calculate TP/SL multipliers based on signal strength             |
//+------------------------------------------------------------------+
void CalculateTPSLMultipliers(int signal_strength, double &tp_multiplier, double &sl_multiplier)
{
    // Initialize with default values (no adjustment)
    tp_multiplier = 1.0;
    sl_multiplier = 1.0;

    // If feature is disabled, return default multipliers
    if(!Use_Signal_Strength_TPSL) {
        return;
    }

    // Calculate multipliers based on signal strength thresholds
    if(signal_strength >= Signal_Strength_High_Threshold) {
        // High signal strength: wider TP, tighter SL (more aggressive, confident in direction)
        tp_multiplier = TP_Multiplier_High_Signal;
        sl_multiplier = SL_Multiplier_High_Signal;

        if(G_Debug) {
            DebugPrint("Signal Strength: HIGH (" + IntegerToString(signal_strength) +
                      ") - TP Multiplier: " + DoubleToString(tp_multiplier, 2) +
                      ", SL Multiplier: " + DoubleToString(sl_multiplier, 2));
        }
    }
    else if(signal_strength <= Signal_Strength_Low_Threshold) {
        // Low signal strength: tighter TP, wider SL (more conservative, less confident)
        tp_multiplier = TP_Multiplier_Low_Signal;
        sl_multiplier = SL_Multiplier_Low_Signal;

        if(G_Debug) {
            DebugPrint("Signal Strength: LOW (" + IntegerToString(signal_strength) +
                      ") - TP Multiplier: " + DoubleToString(tp_multiplier, 2) +
                      ", SL Multiplier: " + DoubleToString(sl_multiplier, 2));
        }
    }
    else {
        // Medium signal strength: linear interpolation between low and high
        double range = Signal_Strength_High_Threshold - Signal_Strength_Low_Threshold;

        // FIX: Prevent division by zero if thresholds are equal
        if(range <= 0) {
            range = 1.0;
            if(G_Debug) {
                DebugPrint("WARNING: Signal strength thresholds are equal or invalid. Using default range.");
            }
        }

        double interpolation_factor = (signal_strength - Signal_Strength_Low_Threshold) / range;

        // Interpolate TP multiplier (from low to high)
        tp_multiplier = TP_Multiplier_Low_Signal +
                       (TP_Multiplier_High_Signal - TP_Multiplier_Low_Signal) * interpolation_factor;

        // Interpolate SL multiplier (from high to low - inverse relationship)
        sl_multiplier = SL_Multiplier_Low_Signal +
                       (SL_Multiplier_High_Signal - SL_Multiplier_Low_Signal) * interpolation_factor;

        if(G_Debug) {
            DebugPrint("Signal Strength: MEDIUM (" + IntegerToString(signal_strength) +
                      ") - TP Multiplier: " + DoubleToString(tp_multiplier, 2) +
                      ", SL Multiplier: " + DoubleToString(sl_multiplier, 2));
        }
    }

    // Apply min/max limits to prevent extreme values
    tp_multiplier = MathMax(TP_Multiplier_Min, MathMin(TP_Multiplier_Max, tp_multiplier));
    sl_multiplier = MathMax(SL_Multiplier_Min, MathMin(SL_Multiplier_Max, sl_multiplier));
}

//+------------------------------------------------------------------+
//| Safely open a buy position with proper risk management            |
//+------------------------------------------------------------------+
bool SafeOpenBuyPosition(int signal_strength = 0)
{
    // Get current market data
    double current_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
    
    // Calculate TP/SL multipliers based on signal strength
    double tp_multiplier = 1.0;
    double sl_multiplier = 1.0;
    CalculateTPSLMultipliers(signal_strength, tp_multiplier, sl_multiplier);

    // Calculate stop loss and take profit levels
    double stopLoss = 0, takeProfit = 0;

    if(Use_Dynamic_StopLoss) {
        // Dynamic stop loss based on ATR
        if(ArraySize(atr) < 1) {
            g_last_error_reason = "ATR data not available for dynamic stop loss calculation";
            DebugPrint(g_last_error_reason);
            return false;
        }

        double atr_value = atr[0];
        // Apply signal strength multipliers to ATR-based TP/SL
        stopLoss = current_price - (atr_value * ATR_StopLoss_Multiplier * sl_multiplier);
        takeProfit = current_price + (atr_value * ATR_TakeProfit_Multiplier * tp_multiplier);
    } else {
        // Fixed stop loss based on pips
        double pip_value = point * 10;  // Convert points to pips
        // Apply signal strength multipliers to fixed pip-based TP/SL
        stopLoss = current_price - (StopLoss_Pips * pip_value * sl_multiplier);
        takeProfit = current_price + (TakeProfit_Pips * pip_value * tp_multiplier);
    }

    // Validate Risk/Reward Ratio
    double risk = MathAbs(current_price - stopLoss);
    double reward = MathAbs(takeProfit - current_price);
    double rr_ratio = (risk > 0) ? (reward / risk) : 0;

    if(rr_ratio < Min_RR_Ratio) {
        g_last_error_reason = "R/R ratio " + DoubleToString(rr_ratio, 2) + " is below minimum " + DoubleToString(Min_RR_Ratio, 2);
        DebugPrint("Trade rejected: " + g_last_error_reason);
        return false;
    }

    if(G_Debug) DebugPrint("R/R Ratio: " + DoubleToString(rr_ratio, 2));

    // Calculate position size based on risk management
    double lotSize = 0;
    
    if(Fixed_Lot_Size > 0) {
        // Use fixed lot size if specified
        lotSize = Fixed_Lot_Size;
    } else {
        // Calculate based on risk percentage
        lotSize = CalculatePositionSize(current_price, stopLoss);
    }
    
    // Check minimum volume
    double minVolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    if(lotSize < minVolume) {
        DebugPrint("Calculated lot size is below minimum allowed: " + DoubleToString(lotSize, 2) + 
                  " < " + DoubleToString(minVolume, 2));
        lotSize = minVolume;
    }
    
    // Print trade details
    DebugPrint("Attempting to open BUY position:");
    DebugPrint("Entry price: " + DoubleToString(current_price, digits));
    DebugPrint("Stop Loss: " + DoubleToString(stopLoss, digits));
    DebugPrint("Take Profit: " + DoubleToString(takeProfit, digits));
    DebugPrint("Lot Size: " + DoubleToString(lotSize, 2));

    // Open the buy order
    bool result = OpenBuyOrder(lotSize, current_price, stopLoss, takeProfit);

    // Update trade counter only if successful
    if(result) {
        trades_this_candle++;
    }

    return result;
}

//+------------------------------------------------------------------+
//| Safely open a sell position with proper risk management           |
//+------------------------------------------------------------------+
bool SafeOpenSellPosition(int signal_strength = 0)
{
    // Get current market data
    double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);

    // Calculate TP/SL multipliers based on signal strength
    double tp_multiplier = 1.0;
    double sl_multiplier = 1.0;
    CalculateTPSLMultipliers(signal_strength, tp_multiplier, sl_multiplier);

    // Calculate stop loss and take profit levels
    double stopLoss = 0, takeProfit = 0;

    if(Use_Dynamic_StopLoss) {
        // Dynamic stop loss based on ATR
        if(ArraySize(atr) < 1) {
            g_last_error_reason = "ATR data not available for dynamic stop loss calculation";
            DebugPrint(g_last_error_reason);
            return false;
        }

        double atr_value = atr[0];
        // Apply signal strength multipliers to ATR-based TP/SL
        stopLoss = current_price + (atr_value * ATR_StopLoss_Multiplier * sl_multiplier);
        takeProfit = current_price - (atr_value * ATR_TakeProfit_Multiplier * tp_multiplier);
    } else {
        // Fixed stop loss based on pips
        double pip_value = point * 10;  // Convert points to pips
        // Apply signal strength multipliers to fixed pip-based TP/SL
        stopLoss = current_price + (StopLoss_Pips * pip_value * sl_multiplier);
        takeProfit = current_price - (TakeProfit_Pips * pip_value * tp_multiplier);
    }

    // Validate Risk/Reward Ratio
    double risk = MathAbs(stopLoss - current_price);
    double reward = MathAbs(current_price - takeProfit);
    double rr_ratio = (risk > 0) ? (reward / risk) : 0;

    if(rr_ratio < Min_RR_Ratio) {
        g_last_error_reason = "R/R ratio " + DoubleToString(rr_ratio, 2) + " is below minimum " + DoubleToString(Min_RR_Ratio, 2);
        DebugPrint("Trade rejected: " + g_last_error_reason);
        return false;
    }

    if(G_Debug) DebugPrint("R/R Ratio: " + DoubleToString(rr_ratio, 2));

    // Calculate position size based on risk management
    double lotSize = 0;
    
    if(Fixed_Lot_Size > 0) {
        // Use fixed lot size if specified
        lotSize = Fixed_Lot_Size;
    } else {
        // Calculate based on risk percentage
        lotSize = CalculatePositionSize(current_price, stopLoss);
    }
    
    // Check minimum volume
    double minVolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    if(lotSize < minVolume) {
        DebugPrint("Calculated lot size is below minimum allowed: " + DoubleToString(lotSize, 2) + 
                  " < " + DoubleToString(minVolume, 2));
        lotSize = minVolume;
    }
    
    // Print trade details
    DebugPrint("Attempting to open SELL position:");
    DebugPrint("Entry price: " + DoubleToString(current_price, digits));
    DebugPrint("Stop Loss: " + DoubleToString(stopLoss, digits));
    DebugPrint("Take Profit: " + DoubleToString(takeProfit, digits));
    DebugPrint("Lot Size: " + DoubleToString(lotSize, 2));

    // Open the sell order
    bool result = OpenSellOrder(lotSize, current_price, stopLoss, takeProfit);

    // Update trade counter only if successful
    if(result) {
        trades_this_candle++;
    }

    return result;
}

//+------------------------------------------------------------------+
//| Function to check debug status                                    |
//+------------------------------------------------------------------+
bool GetDebugMode()
{
    // In backtest mode, we limit debug for speed improvement
    if(MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_TESTER))
        return false;
    
    return G_Debug;
}
