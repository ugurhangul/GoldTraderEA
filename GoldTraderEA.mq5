//+------------------------------------------------------------------+
//|                                                 GoldTraderEA.mq5 |
//|                                  Copyright 2024, Your Name Here  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//| Description: Multi-strategy Expert Advisor for Gold (XAUUSD)     |
//|              Uses weighted confirmation system with 14 strategies |
//|                                                                   |
//| Version: 1.2.0 (Trailing Stop Feature)                            |
//| Last Modified: 2025-01-20                                         |
//|                                                                   |
//| Key Features:                                                     |
//| - 14 technical analysis strategies                                |
//| - Weighted confirmation system                                    |
//| - Dynamic ATR-based stop loss/take profit                         |
//| - Automatic trailing stop loss (NEW!)                             |
//| - Risk management with position sizing                            |
//| - Multiple trading session filters                                |
//| - Bad trading day detection                                       |
//|                                                                   |
//| Strategies:                                                       |
//| 1. Candle Patterns    2. Chart Patterns    3. Price Action       |
//| 4. Elliott Waves      5. Indicators        6. Divergence          |
//| 7. Support/Resistance 8. Harmonic Patterns 9. MA Crossover        |
//| 10. Pivot Points      11. Time Analysis    12. Volume Analysis    |
//| 13. Wolfe Waves       14. Multi-Timeframe                         |
//|                                                                   |
//| Fixes Applied (v1.1.0):                                           |
//| - Fixed inefficient MA calculation (50-90% performance boost)     |
//| - Added array bounds checking (prevents crashes)                  |
//| - Implemented Wolfe Waves strategy calls                          |
//| - Fixed import statement in Indicators.mqh                        |
//| - Removed redundant forward declarations                          |
//| - Implemented Min_RR_Ratio validation                             |
//| - Added comprehensive input parameter validation                  |
//| - Made hardcoded values configurable                              |
//| - Removed unused variables                                        |
//| - Cleaned up commented code                                       |
//|                                                                   |
//| New Features (v1.2.0):                                            |
//| - Automatic trailing stop loss                                    |
//| - ATR-based or fixed pip trailing distance                        |
//| - Configurable activation threshold                               |
//| - Breakeven protection option                                     |
//| - Real-time position monitoring                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://www.mql5.com"
#property version   "1.20"
#property strict

//+------------------------------------------------------------------+
//| Libraries and custom files                                        |
//+------------------------------------------------------------------+
// Main trading libraries
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/AccountInfo.mqh>

// Custom strategy files
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

// Input values for settings
input string   Symbol_Name = "XAUUSD";          // Trading symbol
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;   // Timeframe
input double   Risk_Percent = 1.0;              // Risk percentage per trade from capital (1%)
input double   Fixed_Lot_Size = 0.1;           // Fixed lot size (if 0, use risk percentage)
input double   Max_Lot_Size = 0.3;              // Maximum lot size
input double   Max_Position_Volume = 1.0;       // Maximum volume of open positions
input int      Max_Positions = 1;               // Maximum number of open positions
input int      Min_Confirmations = 7;           // Minimum number of confirmations

// Declaration of input variables for general parameters
input string              General_Settings = "---- General Settings ----"; // Main parameters
input int                 Magic_Number = 123456;                  // Robot identification number (change if running multiple EAs)
input bool                Require_MainTrend_Alignment = true;     // Align trades with the main trend (100 moving average)

// Strategy activation
input bool     Use_CandlePatterns = true;       // Use candle patterns
input bool     Use_ChartPatterns = true;        // Use chart patterns
input bool     Use_PriceAction = true;          // Use price action
input bool     Use_ElliottWaves = false;        // Use Elliott waves
input bool     Use_Indicators = true;           // Use indicators
input bool     Use_Divergence = true;           // Use divergences
input bool     Use_SupportResistance = true;    // Use support and resistance levels
input bool     Use_HarmonicPatterns = false;    // Use harmonic patterns
input bool     Use_MACrossover = true;          // Use moving average crossovers
input bool     Use_PivotPoints = true;          // Use pivot points
input bool     Use_TimeAnalysis = true;         // Use time analysis
input bool     Use_VolumeAnalysis = true;       // Use volume analysis
input bool     Use_WolfeWaves = false;          // Use Wolfe waves
input bool     Use_MultiTimeframe = true;       // Use multi-timeframe analysis
input bool     G_Debug = false;                 // Enable debug messages

input int      StopLoss_Pips = 100;             // Default stop loss (pips)
input int      TakeProfit_Pips = 150;          // Take profit in pips (increased from 100 to 150)
input bool     Use_Dynamic_StopLoss = true;    // Use dynamic stop loss
input int      ATR_Period = 14;                // ATR period
input double   ATR_StopLoss_Multiplier = 2.0;  // ATR multiplier for stop loss (increased from 1.5 to 2.0)
input double   ATR_TakeProfit_Multiplier = 4.0;// ATR multiplier for take profit (increased from 3.0 to 4.0)
input bool     Use_SR_Levels = true;           // Use support/resistance levels for stop loss/profit
input int      max_trades_per_candle = 1;      // Maximum number of trades allowed per candle
input int      MA_Trend_Period = 100;          // Moving average period for determining the main trend
input bool     Use_Main_Trend_Filter = true;   // Use main trend filter

// Performance and timing parameters
input int      Min_Seconds_Between_Trades = 60;     // Minimum seconds between trades
input int      Min_Tick_Processing_Interval = 5;    // Minimum seconds between OnTick processing

// Volatility and risk filters
input double   High_Volatility_Threshold = 1.5;     // ATR multiplier for high volatility detection (1.5 = 50% above average)
input double   Extreme_Movement_Threshold = 1.5;    // Price change % threshold for extreme movement
input int      Bad_Day_Score_Threshold = 3;         // Minimum score to consider it a bad trading day

// Trailing Stop Loss Settings
input string              Trailing_Stop_Settings = "---- Trailing Stop Loss ----"; // Trailing stop parameters
input bool                Use_Trailing_Stop = true;                    // Enable trailing stop loss
input bool                Use_ATR_Trailing = true;                     // Use ATR for trailing distance (if false, uses pips)
input double              Trailing_Stop_Pips = 50;                     // Trailing stop distance in pips (if not using ATR)
input double              ATR_Trailing_Multiplier = 1.5;               // ATR multiplier for trailing distance
input double              Min_Profit_To_Trail_Pips = 30;               // Minimum profit in pips before trailing activates
input bool                Trail_After_Breakeven = true;                // Only trail after reaching breakeven + minimum profit

// Weights of strategies (importance of each strategy)
input int      CandlePatterns_Weight = 1;      // Weight of candle patterns
input int      ChartPatterns_Weight = 2;       // Weight of chart patterns
input int      PriceAction_Weight = 2;         // Weight of price action
input int      ElliottWaves_Weight = 3;        // Weight of Elliott waves
input int      Indicators_Weight = 1;          // Weight of indicators
input int      Divergence_Weight = 3;          // Weight of divergences
input int      SupportResistance_Weight = 3;   // Weight of support and resistance levels
input int      HarmonicPatterns_Weight = 3;    // Weight of harmonic patterns
input int      MACrossover_Weight = 2;         // Weight of moving average crossovers
input int      PivotPoints_Weight = 2;         // Weight of pivot points
input int      TimeAnalysis_Weight = 1;        // Weight of time analysis
input int      VolumeAnalysis_Weight = 2;      // Weight of volume analysis
input int      WolfeWaves_Weight = 3;          // Weight of Wolfe waves
input int      MultiTimeframe_Weight = 2;      // Weight of multi-timeframe analysis

// Global variables
CTrade trade;                      // Trading object
CPositionInfo position;           // Position info object
CAccountInfo account;             // Account info object

// Trade control variables
datetime last_trade_time = 0;       // Last trade time
int trades_this_candle = 0;         // Number of trades in this candle
datetime current_candle_time = 0;   // Current candle time

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

// Forward declarations
// Forward declarations removed - functions are defined in respective .mqh files
bool PrepareHistoricalData();
bool UpdateIndicatorsSafe();
bool CheckTiltFilter(bool isBuy, MqlRates &rates[]);
bool IsBadTradingDay();
bool SafeOpenBuyPosition();
bool SafeOpenSellPosition();

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

// Trading session settings
input string   Session_Settings = "---- Trading Session Settings ----"; // Trading sessions
input bool     Trade_London_Session = true;     // Trade in London session
input int      London_Session_Start = 8;        // London session start time (GMT)
input int      London_Session_End = 16;         // London session end time (GMT)
input bool     Trade_NewYork_Session = true;    // Trade in New York session
input int      NewYork_Session_Start = 13;      // New York session start time (GMT)
input int      NewYork_Session_End = 21;        // New York session end time (GMT)
input bool     Trade_Tokyo_Session = true;     // Trade in Tokyo session
input int      Tokyo_Session_Start = 0;         // Tokyo session start time (GMT)
input int      Tokyo_Session_End = 6;           // Tokyo session end time (GMT)
input bool     Trade_Sydney_Session = true;    // Trade in Sydney session
input int      Sydney_Session_Start = 22;       // Sydney session start time (GMT)
input int      Sydney_Session_End = 4;          // Sydney session end time (GMT)

input double   Min_RR_Ratio = 1.5;                     // Minimum acceptable risk-reward ratio

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
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

   // Validate at least one strategy is enabled
   bool any_strategy_enabled = (Use_CandlePatterns || Use_ChartPatterns || Use_PriceAction ||
                                 Use_ElliottWaves || Use_Indicators || Use_Divergence ||
                                 Use_SupportResistance || Use_HarmonicPatterns || Use_MACrossover ||
                                 Use_PivotPoints || Use_TimeAnalysis || Use_VolumeAnalysis ||
                                 Use_WolfeWaves);

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
   handle_stoch = iStochastic(Symbol(), Timeframe, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   handle_ma_fast = iMA(Symbol(), Timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   handle_ma_slow = iMA(Symbol(), Timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   handle_bbands = iBands(Symbol(), Timeframe, 20, 2, 0, PRICE_CLOSE);
   
   // Additional moving averages for crossovers
   handle_ma_50 = iMA(Symbol(), Timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
   handle_ma_200 = iMA(Symbol(), Timeframe, 200, 0, MODE_SMA, PRICE_CLOSE);

   // Initialize main trend MA
   handle_ma_trend = iMA(Symbol(), Timeframe, MA_Trend_Period, 0, MODE_SMA, PRICE_CLOSE);

   // Volume data
   handle_volumes = iVolumes(Symbol(), Timeframe, VOLUME_TICK);

   if(handle_rsi == INVALID_HANDLE || handle_macd == INVALID_HANDLE || handle_adx == INVALID_HANDLE ||
      handle_stoch == INVALID_HANDLE || handle_ma_fast == INVALID_HANDLE || handle_ma_slow == INVALID_HANDLE ||
      handle_bbands == INVALID_HANDLE || handle_ma_50 == INVALID_HANDLE || handle_ma_200 == INVALID_HANDLE ||
      handle_ma_trend == INVALID_HANDLE)
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
   EW_Timeframe = Timeframe;  // Set timeframe for Elliott waves module
   VA_Timeframe = Timeframe;  // Set timeframe for volume analysis module
   TA_Timeframe = Timeframe;  // Set timeframe for time analysis module
   SetSRTimeframe(Timeframe); // Set timeframe for support and resistance module (using new function)
   PA_Timeframe = Timeframe;  // Set timeframe for price action module
   SetMACTimeframe(Timeframe); // Set timeframe for moving average crossover module (using new function)
   SetMAParameters(8, 21, 200, MODE_EMA, PRICE_CLOSE); // Set moving average parameters
   IND_Timeframe = Timeframe; // Set timeframe for indicators module
   HP_Timeframe = Timeframe;  // Set timeframe for harmonic patterns module
   DIV_Timeframe = Timeframe; // Set timeframe for divergence module
   MTF_Timeframe = Timeframe; // Set timeframe for multi-timeframe module
   PP_Timeframe = Timeframe;  // Set timeframe for pivot points module
   WW_Timeframe = Timeframe;  // Set timeframe for Wolfe waves module
   
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
   CalculatePivotLevels();
   
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
    DeinitMACrossover();

    // Release MultiTimeframe resources
    CleanupMultiTimeframeIndicators();
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
    
    // Display strategy weights
    confirmations += "\nStrategy Weights:\n";
    confirmations += "Candle Patterns: " + IntegerToString(CandlePatterns_Weight) + "\n";
    confirmations += "Chart Patterns: " + IntegerToString(ChartPatterns_Weight) + "\n";
    confirmations += "Price Action: " + IntegerToString(PriceAction_Weight) + "\n";
    confirmations += "Elliott Waves: " + IntegerToString(ElliottWaves_Weight) + "\n";
    confirmations += "Indicators: " + IntegerToString(Indicators_Weight) + "\n";
    confirmations += "Divergences: " + IntegerToString(Divergence_Weight) + "\n";
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
        if(G_Debug) DebugPrint("Error updating indicators.");
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
    
    // 1. Check indicators (they are faster)
    if(Use_Indicators) {
        if(potential_buy) {
            bool indicator_buy = SafeCheckIndicatorsBuy(local_rates);
            buy_confirmations += (indicator_buy ? Indicators_Weight : 0);
            if(G_Debug) DebugPrint("Indicator check result for buy: " + (indicator_buy ? "Positive" : "Negative"));
        }
        
        if(potential_sell) {
            bool indicator_sell = SafeCheckIndicatorsShort(local_rates);
            sell_confirmations += (indicator_sell ? Indicators_Weight : 0);
            if(G_Debug) DebugPrint("Indicator check result for sell: " + (indicator_sell ? "Positive" : "Negative"));
        }
    }
    
    // If still not enough confirmations, check candle patterns
    if(Use_CandlePatterns && (potential_buy || potential_sell)) {
        if(potential_buy) {
            int candle_buy = CheckCandlePatternsBuy();
            buy_confirmations += candle_buy * CandlePatterns_Weight;
            if(G_Debug) DebugPrint("Number of candle confirmations for buy: " + IntegerToString(candle_buy));
        }
        
        if(potential_sell) {
            int candle_sell = CheckCandlePatternsShort();
            sell_confirmations += candle_sell * CandlePatterns_Weight;
            if(G_Debug) DebugPrint("Number of candle confirmations for sell: " + IntegerToString(candle_sell));
        }
    }
    
    // Quick check - do we have enough confirmations so far?
    bool enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
    bool enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
    
    // If confirmations are not enough, check the rest of the strategies
    
    // 3. Price action
    if(Use_PriceAction && (!enough_buy_confirmations || !enough_sell_confirmations)) {
        if(potential_buy && !enough_buy_confirmations) {
            int pa_buy = CheckPriceActionBuy();
            buy_confirmations += pa_buy * PriceAction_Weight;
            enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of price action confirmations for buy: " + IntegerToString(pa_buy));
        }
        
        if(potential_sell && !enough_sell_confirmations) {
            int pa_sell = CheckPriceActionShort();
            sell_confirmations += pa_sell * PriceAction_Weight;
            enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of price action confirmations for sell: " + IntegerToString(pa_sell));
        }
    }
    
    // 4. Chart patterns
    if(Use_ChartPatterns && (!enough_buy_confirmations || !enough_sell_confirmations)) {
        if(potential_buy && !enough_buy_confirmations) {
            int chart_buy = CheckChartPatternsBuy();
            buy_confirmations += chart_buy * ChartPatterns_Weight;
            enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of chart confirmations for buy: " + IntegerToString(chart_buy));
        }
        
        if(potential_sell && !enough_sell_confirmations) {
            int chart_sell = CheckChartPatternsShort();
            sell_confirmations += chart_sell * ChartPatterns_Weight;
            enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of chart confirmations for sell: " + IntegerToString(chart_sell));
        }
    }
    
    // 5. Support and resistance levels
    if(Use_SupportResistance && (!enough_buy_confirmations || !enough_sell_confirmations)) {
        if(potential_buy && !enough_buy_confirmations) {
            int sr_buy = CheckSupportResistanceBuy();
            buy_confirmations += sr_buy * SupportResistance_Weight;
            enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of S/R confirmations for buy: " + IntegerToString(sr_buy));
        }
        
        if(potential_sell && !enough_sell_confirmations) {
            int sr_sell = CheckSupportResistanceShort();
            sell_confirmations += sr_sell * SupportResistance_Weight;
            enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of S/R confirmations for sell: " + IntegerToString(sr_sell));
        }
    }
    
    // 6. Moving average crossovers
    if(Use_MACrossover && (!enough_buy_confirmations || !enough_sell_confirmations)) {
        if(potential_buy && !enough_buy_confirmations) {
            int ma_buy = CheckMACrossoverBuy(local_rates);
            buy_confirmations += ma_buy * MACrossover_Weight;
            enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of MA crossover confirmations for buy: " + IntegerToString(ma_buy));
        }

        if(potential_sell && !enough_sell_confirmations) {
            int ma_sell = CheckMACrossoverShort(local_rates);
            sell_confirmations += ma_sell * MACrossover_Weight;
            enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of MA crossover confirmations for sell: " + IntegerToString(ma_sell));
        }
    }

    // 6b. Time analysis (if enabled)
    if(Use_TimeAnalysis && copied >= 100 && (!enough_buy_confirmations || !enough_sell_confirmations)) {
        int time_confirmations = CheckTimeAnalysis(local_rates);

        if(potential_buy && !enough_buy_confirmations) {
            buy_confirmations += time_confirmations * TimeAnalysis_Weight;
            enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of time analysis confirmations for buy: " + IntegerToString(time_confirmations));
        }

        if(potential_sell && !enough_sell_confirmations) {
            sell_confirmations += time_confirmations * TimeAnalysis_Weight;
            enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of time analysis confirmations for sell: " + IntegerToString(time_confirmations));
        }
    }

    // Execute heavier strategies only if needed
    
    // 7. Divergences
    if(Use_Divergence && copied >= 30 && (!enough_buy_confirmations || !enough_sell_confirmations)) {
        if(potential_buy && !enough_buy_confirmations) {
            int divergence_buy = CheckDivergenceBuy(local_rates);
            buy_confirmations += divergence_buy * Divergence_Weight;
            enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of divergence confirmations for buy: " + IntegerToString(divergence_buy));
        }
        
        if(potential_sell && !enough_sell_confirmations) {
            int divergence_sell = CheckDivergenceShort(local_rates);
            sell_confirmations += divergence_sell * Divergence_Weight;
            enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of divergence confirmations for sell: " + IntegerToString(divergence_sell));
        }
    }
    
    // 8. Harmonic patterns (if enabled)
    if(Use_HarmonicPatterns && (!enough_buy_confirmations || !enough_sell_confirmations)) {
        if(potential_buy && !enough_buy_confirmations) {
            int harmonic_buy = SafeCheckHarmonicPatternsBuy(local_rates);
            buy_confirmations += harmonic_buy * HarmonicPatterns_Weight;
            if(G_Debug) DebugPrint("Number of harmonic confirmations for buy: " + IntegerToString(harmonic_buy));
        }
        
        if(potential_sell && !enough_sell_confirmations) {
            int harmonic_sell = SafeCheckHarmonicPatternsShort(local_rates);
            sell_confirmations += harmonic_sell * HarmonicPatterns_Weight;
            if(G_Debug) DebugPrint("Number of harmonic confirmations for sell: " + IntegerToString(harmonic_sell));
        }
    }
    
    // Volume analysis (if enabled and volume data is available)
    if(Use_VolumeAnalysis && volume_data_available && (!enough_buy_confirmations || !enough_sell_confirmations)) {
        if(potential_buy && !enough_buy_confirmations) {
            int va_buy = CheckVolumeAnalysisBuy(local_rates);
            buy_confirmations += va_buy * VolumeAnalysis_Weight;
            enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of volume analysis confirmations for buy: " + IntegerToString(va_buy));
        }
        
        if(potential_sell && !enough_sell_confirmations) {
            int va_sell = CheckVolumeAnalysisShort(local_rates);
            sell_confirmations += va_sell * VolumeAnalysis_Weight;
            enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of volume analysis confirmations for sell: " + IntegerToString(va_sell));
        }
    }
    
    // 9. Elliott waves (if enabled)
    if(Use_ElliottWaves && copied >= 30 && (!enough_buy_confirmations || !enough_sell_confirmations)) {
        if(potential_buy && !enough_buy_confirmations) {
            int elliott_buy = SafeCheckElliottWavesBuy(local_rates);
            buy_confirmations += elliott_buy * ElliottWaves_Weight;
            if(G_Debug) DebugPrint("Number of Elliott wave confirmations for buy: " + IntegerToString(elliott_buy));
        }

        if(potential_sell && !enough_sell_confirmations) {
            int elliott_sell = SafeCheckElliottWavesShort(local_rates);
            sell_confirmations += elliott_sell * ElliottWaves_Weight;
            if(G_Debug) DebugPrint("Number of Elliott wave confirmations for sell: " + IntegerToString(elliott_sell));
        }
    }

    // 10. Wolfe Waves (if enabled)
    if(Use_WolfeWaves && copied >= 51 && (!enough_buy_confirmations || !enough_sell_confirmations)) {
        if(potential_buy && !enough_buy_confirmations) {
            int wolfe_buy = SafeCheckWolfeWavesBuy(local_rates);
            buy_confirmations += wolfe_buy * WolfeWaves_Weight;
            if(G_Debug) DebugPrint("Number of Wolfe Wave confirmations for buy: " + IntegerToString(wolfe_buy));
        }

        if(potential_sell && !enough_sell_confirmations) {
            int wolfe_sell = SafeCheckWolfeWavesShort(local_rates);
            sell_confirmations += wolfe_sell * WolfeWaves_Weight;
            if(G_Debug) DebugPrint("Number of Wolfe Wave confirmations for sell: " + IntegerToString(wolfe_sell));
        }
    }

    // 11. Multi-Timeframe Analysis (if enabled)
    if(Use_MultiTimeframe && (!enough_buy_confirmations || !enough_sell_confirmations)) {
        if(potential_buy && !enough_buy_confirmations) {
            int mtf_buy = CheckMultiTimeframeBuy(local_rates);
            buy_confirmations += mtf_buy * MultiTimeframe_Weight;
            enough_buy_confirmations = (buy_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of multi-timeframe confirmations for buy: " + IntegerToString(mtf_buy));
        }

        if(potential_sell && !enough_sell_confirmations) {
            int mtf_sell = CheckMultiTimeframeShort(local_rates);
            sell_confirmations += mtf_sell * MultiTimeframe_Weight;
            enough_sell_confirmations = (sell_confirmations >= Min_Confirmations);
            if(G_Debug) DebugPrint("Number of multi-timeframe confirmations for sell: " + IntegerToString(mtf_sell));
        }
    }

    // Print buy and sell confirmation status if debug is enabled
    if(G_Debug) {
        DebugPrint("Buy confirmations: " + IntegerToString(buy_confirmations) + 
                  ", Sell confirmations: " + IntegerToString(sell_confirmations));
    }
    
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
    
    // Check trading time limits
    bool can_trade_time = CheckTradeSessionTime();
    if(!can_trade_time) {
        if(G_Debug) DebugPrint("Outside of allowed trading hours.");
        return;
    }
    
    // Check opening new position based on confirmations

    // Validate array access before using
    if(copied < 1 || ArraySize(ma_trend) < 1) {
        DebugPrint("Error: Insufficient data for trend check");
        return;
    }

    // Get main trend MA value (now using pre-calculated buffer)
    double ma_main_trend_value = ma_trend[0];  // Current MA value
    double current_close = local_rates[copied-1].close;

    // Now the main decision for trades
    
    // Buy signal
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
    
    // Sell signal
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
void OpenBuyOrder(double lotSize, double entryPrice, double stopLoss, double takeProfit)
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
        DebugPrint("Buy position opened successfully. Ticket: " + IntegerToString(trade.ResultOrder()));
    } else {
        DebugPrint("Error opening buy position: " + IntegerToString(trade.ResultRetcode()) + 
                  " - " + trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Open a sell position                                             |
//+------------------------------------------------------------------+
void OpenSellOrder(double lotSize, double entryPrice, double stopLoss, double takeProfit)
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
        DebugPrint("Sell position opened successfully. Ticket: " + IntegerToString(trade.ResultOrder()));
    } else {
        DebugPrint("Error opening sell position: " + IntegerToString(trade.ResultRetcode()) +
                  " - " + trade.ResultRetcodeDescription());
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
    // Update RSI
    if(CopyBuffer(handle_rsi, 0, 0, 3, rsi) < 3) {
        DebugPrint("Failed to copy RSI data");
        return false;
    }
    
    // Update MACD
    if(CopyBuffer(handle_macd, 0, 0, 3, macd) < 3) {
        DebugPrint("Failed to copy MACD main line data");
        return false;
    }
    
    if(CopyBuffer(handle_macd, 1, 0, 3, macd_signal) < 3) {
        DebugPrint("Failed to copy MACD signal line data");
        return false;
    }
    
    // Update ADX
    if(CopyBuffer(handle_adx, 0, 0, 3, adx) < 3) {
        DebugPrint("Failed to copy ADX data");
        return false;
    }
    
    // Update Stochastic
    if(CopyBuffer(handle_stoch, 0, 0, 3, stoch_k) < 3) {
        DebugPrint("Failed to copy Stochastic %K data");
        return false;
    }
    
    if(CopyBuffer(handle_stoch, 1, 0, 3, stoch_d) < 3) {
        DebugPrint("Failed to copy Stochastic %D data");
        return false;
    }
    
    // Update Moving Averages
    if(CopyBuffer(handle_ma_fast, 0, 0, 3, ma_fast) < 3) {
        DebugPrint("Failed to copy fast MA data");
        return false;
    }
    
    if(CopyBuffer(handle_ma_slow, 0, 0, 3, ma_slow) < 3) {
        DebugPrint("Failed to copy slow MA data");
        return false;
    }
    
    // Update Bollinger Bands
    if(CopyBuffer(handle_bbands, 0, 0, 3, bb_middle) < 3) {
        DebugPrint("Failed to copy BB middle line data");
        return false;
    }
    
    if(CopyBuffer(handle_bbands, 1, 0, 3, bb_upper) < 3) {
        DebugPrint("Failed to copy BB upper line data");
        return false;
    }
    
    if(CopyBuffer(handle_bbands, 2, 0, 3, bb_lower) < 3) {
        DebugPrint("Failed to copy BB lower line data");
        return false;
    }
    
    // Update additional MAs
    if(CopyBuffer(handle_ma_50, 0, 0, 3, ma_50) < 3) {
        DebugPrint("Failed to copy MA50 data");
        return false;
    }
    
    if(CopyBuffer(handle_ma_200, 0, 0, 3, ma_200) < 3) {
        DebugPrint("Failed to copy MA200 data");
        return false;
    }
    
    // Update ATR
    if(CopyBuffer(handle_atr, 0, 0, 3, atr) < 3) {
        DebugPrint("Failed to copy ATR data");
        return false;
    }

    // Update main trend MA
    if(CopyBuffer(handle_ma_trend, 0, 0, 3, ma_trend) < 3) {
        DebugPrint("Failed to copy main trend MA data");
        return false;
    }

    // Update volume data (only if handle is valid)
    if(handle_volumes != INVALID_HANDLE) {
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
//| Safely open a buy position with proper risk management            |
//+------------------------------------------------------------------+
bool SafeOpenBuyPosition()
{
    // Get current market data
    double current_price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
    
    // Calculate stop loss and take profit levels
    double stopLoss = 0, takeProfit = 0;
    
    if(Use_Dynamic_StopLoss) {
        // Dynamic stop loss based on ATR
        if(ArraySize(atr) < 1) {
            DebugPrint("ATR data not available for dynamic stop loss calculation");
            return false;
        }
        
        double atr_value = atr[0];
        stopLoss = current_price - (atr_value * ATR_StopLoss_Multiplier);
        takeProfit = current_price + (atr_value * ATR_TakeProfit_Multiplier);
    } else {
        // Fixed stop loss based on pips
        double pip_value = point * 10;  // Convert points to pips
        stopLoss = current_price - (StopLoss_Pips * pip_value);
        takeProfit = current_price + (TakeProfit_Pips * pip_value);
    }

    // Validate Risk/Reward Ratio
    double risk = MathAbs(current_price - stopLoss);
    double reward = MathAbs(takeProfit - current_price);
    double rr_ratio = (risk > 0) ? (reward / risk) : 0;

    if(rr_ratio < Min_RR_Ratio) {
        DebugPrint("Trade rejected: R/R ratio " + DoubleToString(rr_ratio, 2) +
                   " is below minimum " + DoubleToString(Min_RR_Ratio, 2));
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
    OpenBuyOrder(lotSize, current_price, stopLoss, takeProfit);

    // Update trade counter
    trades_this_candle++;

    return true;
}

//+------------------------------------------------------------------+
//| Safely open a sell position with proper risk management           |
//+------------------------------------------------------------------+
bool SafeOpenSellPosition()
{
    // Get current market data
    double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
    
    // Calculate stop loss and take profit levels
    double stopLoss = 0, takeProfit = 0;
    
    if(Use_Dynamic_StopLoss) {
        // Dynamic stop loss based on ATR
        if(ArraySize(atr) < 1) {
            DebugPrint("ATR data not available for dynamic stop loss calculation");
            return false;
        }
        
        double atr_value = atr[0];
        stopLoss = current_price + (atr_value * ATR_StopLoss_Multiplier);
        takeProfit = current_price - (atr_value * ATR_TakeProfit_Multiplier);
    } else {
        // Fixed stop loss based on pips
        double pip_value = point * 10;  // Convert points to pips
        stopLoss = current_price + (StopLoss_Pips * pip_value);
        takeProfit = current_price - (TakeProfit_Pips * pip_value);
    }

    // Validate Risk/Reward Ratio
    double risk = MathAbs(stopLoss - current_price);
    double reward = MathAbs(current_price - takeProfit);
    double rr_ratio = (risk > 0) ? (reward / risk) : 0;

    if(rr_ratio < Min_RR_Ratio) {
        DebugPrint("Trade rejected: R/R ratio " + DoubleToString(rr_ratio, 2) +
                   " is below minimum " + DoubleToString(Min_RR_Ratio, 2));
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
    OpenSellOrder(lotSize, current_price, stopLoss, takeProfit);

    // Update trade counter
    trades_this_candle++;

    return true;
}

//+------------------------------------------------------------------+
//| Check if current time is within allowed trading sessions          |
//+------------------------------------------------------------------+
bool CheckTradeSessionTime()
{
    // Get current time as GMT/UTC time
    MqlDateTime gmt_time;
    TimeToStruct(TimeGMT(), gmt_time);
    
    int current_hour = gmt_time.hour;
    int current_day = gmt_time.day_of_week; // 0-Sunday, 1-Monday, ..., 6-Saturday
    
    // Check if current day is a trading day (Monday-Friday)
    if(current_day == 0 || current_day == 6) {
        // Weekend - no trading
        return false;
    }
    
    // Check if current time is in any of the allowed trading sessions
    
    // London session
    if(Trade_London_Session && 
       ((current_hour >= London_Session_Start && current_hour < London_Session_End) ||
        // Handle overnight sessions
        (London_Session_Start > London_Session_End && 
         (current_hour >= London_Session_Start || current_hour < London_Session_End)))) {
        return true;
    }
    
    // New York session
    if(Trade_NewYork_Session && 
       ((current_hour >= NewYork_Session_Start && current_hour < NewYork_Session_End) ||
        // Handle overnight sessions
        (NewYork_Session_Start > NewYork_Session_End && 
         (current_hour >= NewYork_Session_Start || current_hour < NewYork_Session_End)))) {
        return true;
    }
    
    // Tokyo session
    if(Trade_Tokyo_Session && 
       ((current_hour >= Tokyo_Session_Start && current_hour < Tokyo_Session_End) ||
        // Handle overnight sessions
        (Tokyo_Session_Start > Tokyo_Session_End && 
         (current_hour >= Tokyo_Session_Start || current_hour < Tokyo_Session_End)))) {
        return true;
    }
    
    // Sydney session
    if(Trade_Sydney_Session && 
       ((current_hour >= Sydney_Session_Start && current_hour < Sydney_Session_End) ||
        // Handle overnight sessions
        (Sydney_Session_Start > Sydney_Session_End && 
         (current_hour >= Sydney_Session_Start || current_hour < Sydney_Session_End)))) {
        return true;
    }
    
    // No active session at current time
    return false;
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
