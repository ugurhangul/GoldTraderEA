//+------------------------------------------------------------------+
//|                                           SignalFilterSystem.mqh |
//|                          Comprehensive 6-Gate Signal Filtration  |
//|                                   For XAU/USD Trading Signals    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, GoldTraderEA"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters for Signal Filter System                        |
//+------------------------------------------------------------------+
// Gate enable/disable controls
input bool     SF_Enable_Gate1_Regime = true;           // Enable Gate 1: Regime Filter
input bool     SF_Enable_Gate2_VolumeProfile = true;    // Enable Gate 2: Volume Profile Context
input bool     SF_Enable_Gate3_InterMarket = true;      // Enable Gate 3: Inter-Market Context
input bool     SF_Enable_Gate4_Confluence = true;       // Enable Gate 4: Confluence Filter
input bool     SF_Enable_Gate5_Advanced = true;         // Enable Gate 5: Advanced Qualification
input bool     SF_Enable_Gate6_Temporal = true;         // Enable Gate 6: Temporal Filter

// Gate 1: Regime Filter Parameters
input double   SF_ADX_Trend_Threshold = 25.0;           // ADX threshold for trend/range detection
input double   SF_BB_Expansion_Threshold = 1.2;         // BB expansion ratio threshold

// Gate 2: Volume Profile Parameters
input double   SF_VP_Near_Distance_Pct = 0.1;           // "At/near" distance percentage (0.1%)
input double   SF_VP_Block_Distance_Pct = 0.2;          // "Directly below/above" distance percentage (0.2%)
input int      SF_VP_Lookback_Bars = 500;               // Lookback period for Volume Profile calculation

// Gate 3: Inter-Market Parameters
input string   SF_DXY_Symbol = "USDX";                  // DXY symbol name
input int      SF_DXY_Trend_Period = 20;                // Period for DXY trend detection
input double   SF_DXY_SR_Tolerance = 0.3;               // DXY S/R tolerance percentage

// Gate 4: Confluence Parameters
input int      SF_Confluence_Min_Confirmations = 1;     // Minimum confirmations from different category

// Gate 6: Temporal Filter Parameters
input int      SF_News_Lookforward_Hours = 2;           // Hours to look forward for news events
input bool     SF_Allow_Asian_Session = false;          // Allow trading in Asian session

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_TYPE
{
   SIGNAL_LONG,
   SIGNAL_SHORT
};

enum ENUM_STRATEGY_CATEGORY
{
   CATEGORY_TREND,           // MA, MACD, Trend Patterns
   CATEGORY_MOMENTUM,        // RSI, Stochastic, CCI
   CATEGORY_VOLATILITY,      // Bollinger Bands
   CATEGORY_VOLUME,          // Volume Profile, Volume Analysis
   CATEGORY_PATTERN,         // Harmonic, Elliott, Chart Patterns
   CATEGORY_SUPPORT_RESISTANCE  // S/R, Pivot Points
};

enum ENUM_MARKET_REGIME
{
   REGIME_TRENDING,
   REGIME_RANGING,
   REGIME_UNKNOWN
};

//+------------------------------------------------------------------+
//| Signal Data Structure                                            |
//+------------------------------------------------------------------+
struct CSignalData
{
   ENUM_SIGNAL_TYPE signal_type;           // LONG or SHORT
   string strategy_name;                    // Primary strategy generating signal
   ENUM_STRATEGY_CATEGORY strategy_category; // Category of primary strategy
   double entry_price;                      // Proposed entry price
   datetime signal_time;                    // Time of signal generation

   // Additional context
   double adx_value;                        // Current ADX value
   double bb_upper_value;                   // Bollinger Band upper
   double bb_middle_value;                  // Bollinger Band middle
   double bb_lower_value;                   // Bollinger Band lower
   double rsi_value;                        // Current RSI
   double macd_value;                       // Current MACD
   double stoch_value;                      // Current Stochastic

   // Quality metrics
   double quality_score;                    // Overall quality score (0-100)
   int gates_passed;                        // Number of gates passed
   string rejection_gate;                   // Which gate rejected (if any)
   string rejection_reason;                 // Detailed rejection reason
};

//+------------------------------------------------------------------+
//| Volume Profile Data Structure                                    |
//+------------------------------------------------------------------+
struct CVolumeProfileData
{
   double poc;              // Point of Control (price with highest volume)
   double vah;              // Value Area High
   double val;              // Value Area Low
   double hvn_levels[10];   // High Volume Nodes
   double lvn_levels[10];   // Low Volume Nodes
   int hvn_count;           // Number of HVNs
   int lvn_count;           // Number of LVNs
};

//+------------------------------------------------------------------+
//| Filter Result Structure                                          |
//+------------------------------------------------------------------+
struct CFilterResult
{
   bool passed;                // Did signal pass all gates?
   int gate_failed;            // Which gate failed (1-6, 0 if passed)
   string failure_reason;      // Reason for failure
   double quality_score;       // Quality score from Gate 5
};

//+------------------------------------------------------------------+
//| Signal Filter Class                                              |
//+------------------------------------------------------------------+
class CSignalFilter
{
private:
   // Indicator handles
   int m_handle_adx;
   int m_handle_bbands;
   int m_handle_rsi;
   int m_handle_macd;
   int m_handle_stoch;
   int m_handle_dxy;
   
   // Cached data
   CVolumeProfileData m_volume_profile;
   datetime m_vp_last_update;
   
   // Helper methods
   ENUM_MARKET_REGIME DetectMarketRegime(double adx_val, double bb_up, double bb_mid, double bb_low, MqlRates &rates[]);
   bool IsBollingerBandsExpanding(double bb_up, double bb_mid, double bb_low, MqlRates &rates[]);
   bool CalculateVolumeProfile(MqlRates &rates[], CVolumeProfileData &vp_data);
   bool CheckDXYContext(ENUM_SIGNAL_TYPE signal_type, bool &dxy_favorable);
   bool CheckRealYieldsContext(ENUM_SIGNAL_TYPE signal_type);
   bool CheckConfluenceFromOtherCategories(CSignalData &signal, ENUM_STRATEGY_CATEGORY primary_category);
   bool CheckDivergenceConfirmation(ENUM_SIGNAL_TYPE signal_type, MqlRates &rates[]);
   bool CheckHarmonicPRZ(ENUM_SIGNAL_TYPE signal_type, double entry_price);
   bool IsHighLiquiditySession();
   bool IsHighImpactNewsNear(int hours_forward);

public:
   // Constructor/Destructor
   CSignalFilter();
   ~CSignalFilter();
   
   // Initialization
   bool Initialize();
   void Deinitialize();
   
   // Main validation method
   bool ValidateSignal(CSignalData &signal, CFilterResult &result);
   
   // Individual gate methods
   bool Gate1_RegimeFilter(CSignalData &signal, string &rejection_reason);
   bool Gate2_VolumeProfileContext(CSignalData &signal, string &rejection_reason);
   bool Gate3_InterMarketContext(CSignalData &signal, string &rejection_reason);
   bool Gate4_ConfluenceFilter(CSignalData &signal, string &rejection_reason);
   bool Gate5_AdvancedQualification(CSignalData &signal, double &quality_score);
   bool Gate6_TemporalFilter(CSignalData &signal, string &rejection_reason);
   
   // Utility methods
   void UpdateVolumeProfile();
   void LogFilterResult(CSignalData &signal, CFilterResult &result);
   ENUM_STRATEGY_CATEGORY GetStrategyCategory(string strategy_name);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSignalFilter::CSignalFilter()
{
   m_handle_adx = INVALID_HANDLE;
   m_handle_bbands = INVALID_HANDLE;
   m_handle_rsi = INVALID_HANDLE;
   m_handle_macd = INVALID_HANDLE;
   m_handle_stoch = INVALID_HANDLE;
   m_handle_dxy = INVALID_HANDLE;
   m_vp_last_update = 0;
   
   // Initialize volume profile data
   m_volume_profile.poc = 0;
   m_volume_profile.vah = 0;
   m_volume_profile.val = 0;
   m_volume_profile.hvn_count = 0;
   m_volume_profile.lvn_count = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSignalFilter::~CSignalFilter()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize indicator handles                                     |
//+------------------------------------------------------------------+
bool CSignalFilter::Initialize()
{
   // Create indicator handles
   m_handle_adx = iADX(Symbol(), PERIOD_CURRENT, 14);
   m_handle_bbands = iBands(Symbol(), PERIOD_CURRENT, 20, 2, 0, PRICE_CLOSE);
   m_handle_rsi = iRSI(Symbol(), PERIOD_CURRENT, 14, PRICE_CLOSE);
   m_handle_macd = iMACD(Symbol(), PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
   m_handle_stoch = iStochastic(Symbol(), PERIOD_CURRENT, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   
   // Try to create DXY handle (may fail if symbol not available)
   if(SF_Enable_Gate3_InterMarket)
   {
      m_handle_dxy = iMA(SF_DXY_Symbol, PERIOD_CURRENT, SF_DXY_Trend_Period, 0, MODE_SMA, PRICE_CLOSE);
      if(m_handle_dxy == INVALID_HANDLE)
      {
         Print("Warning: DXY symbol '", SF_DXY_Symbol, "' not available. Gate 3 will be disabled.");
      }
   }
   
   // Validate critical handles
   if(m_handle_adx == INVALID_HANDLE || m_handle_bbands == INVALID_HANDLE)
   {
      Print("Error: Failed to create required indicator handles for Signal Filter");
      return false;
   }
   
   Print("Signal Filter System initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Release indicator handles                                        |
//+------------------------------------------------------------------+
void CSignalFilter::Deinitialize()
{
   if(m_handle_adx != INVALID_HANDLE) IndicatorRelease(m_handle_adx);
   if(m_handle_bbands != INVALID_HANDLE) IndicatorRelease(m_handle_bbands);
   if(m_handle_rsi != INVALID_HANDLE) IndicatorRelease(m_handle_rsi);
   if(m_handle_macd != INVALID_HANDLE) IndicatorRelease(m_handle_macd);
   if(m_handle_stoch != INVALID_HANDLE) IndicatorRelease(m_handle_stoch);
   if(m_handle_dxy != INVALID_HANDLE) IndicatorRelease(m_handle_dxy);
}

//+------------------------------------------------------------------+
//| Main Signal Validation - Sequential Gate Processing             |
//+------------------------------------------------------------------+
bool CSignalFilter::ValidateSignal(CSignalData &signal, CFilterResult &result)
{
   result.passed = false;
   result.gate_failed = 0;
   result.failure_reason = "";
   result.quality_score = 0;

   string rejection_reason = "";

   // GATE 1: Regime Filter
   if(SF_Enable_Gate1_Regime)
   {
      if(!Gate1_RegimeFilter(signal, rejection_reason))
      {
         result.gate_failed = 1;
         result.failure_reason = "Gate 1 (Regime): " + rejection_reason;
         LogFilterResult(signal, result);
         return false;
      }
   }

   // GATE 2: Volume Profile Context Filter
   if(SF_Enable_Gate2_VolumeProfile)
   {
      if(!Gate2_VolumeProfileContext(signal, rejection_reason))
      {
         result.gate_failed = 2;
         result.failure_reason = "Gate 2 (Volume Profile): " + rejection_reason;
         LogFilterResult(signal, result);
         return false;
      }
   }

   // GATE 3: Inter-Market Context Filter
   if(SF_Enable_Gate3_InterMarket)
   {
      if(!Gate3_InterMarketContext(signal, rejection_reason))
      {
         result.gate_failed = 3;
         result.failure_reason = "Gate 3 (Inter-Market): " + rejection_reason;
         LogFilterResult(signal, result);
         return false;
      }
   }

   // GATE 4: Confluence Filter
   if(SF_Enable_Gate4_Confluence)
   {
      if(!Gate4_ConfluenceFilter(signal, rejection_reason))
      {
         result.gate_failed = 4;
         result.failure_reason = "Gate 4 (Confluence): " + rejection_reason;
         LogFilterResult(signal, result);
         return false;
      }
   }

   // GATE 5: Advanced Qualification (does not veto, adds quality score)
   double quality_score = 0;
   if(SF_Enable_Gate5_Advanced)
   {
      Gate5_AdvancedQualification(signal, quality_score);
      result.quality_score = quality_score;
      signal.quality_score = quality_score;
   }

   // GATE 6: Temporal Filter
   if(SF_Enable_Gate6_Temporal)
   {
      if(!Gate6_TemporalFilter(signal, rejection_reason))
      {
         result.gate_failed = 6;
         result.failure_reason = "Gate 6 (Temporal): " + rejection_reason;
         LogFilterResult(signal, result);
         return false;
      }
   }

   // All gates passed
   result.passed = true;
   signal.gates_passed = 6;
   LogFilterResult(signal, result);
   return true;
}

//+------------------------------------------------------------------+
//| GATE 1: Regime Filter                                           |
//| Validates signal type matches market regime                     |
//+------------------------------------------------------------------+
bool CSignalFilter::Gate1_RegimeFilter(CSignalData &signal, string &rejection_reason)
{
   // Get current market data
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(Symbol(), PERIOD_CURRENT, 0, 50, rates) < 50)
   {
      rejection_reason = "Insufficient data for regime detection";
      return false;
   }

   // Get ADX value
   double adx_buffer[];
   ArraySetAsSeries(adx_buffer, true);
   if(CopyBuffer(m_handle_adx, 0, 0, 3, adx_buffer) < 3)
   {
      rejection_reason = "Failed to retrieve ADX data";
      return false;
   }
   double adx_current = adx_buffer[0];
   signal.adx_value = adx_current;

   // Get Bollinger Bands
   double bb_up_arr[], bb_mid_arr[], bb_low_arr[];
   ArraySetAsSeries(bb_up_arr, true);
   ArraySetAsSeries(bb_mid_arr, true);
   ArraySetAsSeries(bb_low_arr, true);

   if(CopyBuffer(m_handle_bbands, 0, 0, 3, bb_mid_arr) < 3 ||
      CopyBuffer(m_handle_bbands, 1, 0, 3, bb_up_arr) < 3 ||
      CopyBuffer(m_handle_bbands, 2, 0, 3, bb_low_arr) < 3)
   {
      rejection_reason = "Failed to retrieve Bollinger Bands data";
      return false;
   }

   signal.bb_upper_value = bb_up_arr[0];
   signal.bb_middle_value = bb_mid_arr[0];
   signal.bb_lower_value = bb_low_arr[0];

   // Detect market regime
   ENUM_MARKET_REGIME regime = DetectMarketRegime(adx_current, bb_up_arr[0], bb_mid_arr[0], bb_low_arr[0], rates);
   bool bb_expanding = IsBollingerBandsExpanding(bb_up_arr[0], bb_mid_arr[0], bb_low_arr[0], rates);

   // Determine if signal strategy is trend-following or mean-reversion
   bool is_trend_strategy = false;
   string strat = signal.strategy_name;

   if(StringFind(strat, "MA") >= 0 || StringFind(strat, "Breakout") >= 0 ||
      StringFind(strat, "Donchian") >= 0 || StringFind(strat, "SAR") >= 0 ||
      StringFind(strat, "Trend") >= 0)
   {
      is_trend_strategy = true;
   }

   // Apply regime filter logic
   if(is_trend_strategy)
   {
      // Trend-following signals require trending regime
      if(adx_current <= SF_ADX_Trend_Threshold)
      {
         rejection_reason = StringFormat("Trend strategy in ranging market (ADX=%.1f <= %.1f)", adx_current, SF_ADX_Trend_Threshold);
         return false;
      }

      if(!bb_expanding)
      {
         rejection_reason = "Trend strategy but Bollinger Bands not expanding";
         return false;
      }
   }
   else
   {
      // Mean-reversion signals require ranging regime
      if(adx_current > SF_ADX_Trend_Threshold)
      {
         rejection_reason = StringFormat("Mean-reversion strategy in trending market (ADX=%.1f > %.1f)", adx_current, SF_ADX_Trend_Threshold);
         return false;
      }

      if(bb_expanding)
      {
         rejection_reason = "Mean-reversion strategy but Bollinger Bands expanding";
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| GATE 2: Volume Profile Context Filter                           |
//| Validates entry location relative to Volume Profile levels      |
//+------------------------------------------------------------------+
bool CSignalFilter::Gate2_VolumeProfileContext(CSignalData &signal, string &rejection_reason)
{
   // Update Volume Profile if needed (cache for 1 hour)
   datetime current_time = TimeCurrent();
   if(current_time - m_vp_last_update > 3600 || m_volume_profile.poc == 0)
   {
      UpdateVolumeProfile();
   }

   // Check if Volume Profile data is valid
   if(m_volume_profile.poc == 0)
   {
      rejection_reason = "Volume Profile data not available";
      return false;
   }

   double entry_price = signal.entry_price;
   double near_distance = entry_price * (SF_VP_Near_Distance_Pct / 100.0);
   double block_distance = entry_price * (SF_VP_Block_Distance_Pct / 100.0);

   if(signal.signal_type == SIGNAL_LONG)
   {
      // For LONG signals: Entry should be at/near support (VAL or minor HVN)
      bool at_support = false;

      // Check if near VAL
      if(MathAbs(entry_price - m_volume_profile.val) <= near_distance)
      {
         at_support = true;
      }

      // Check if near any HVN (minor support)
      for(int i = 0; i < m_volume_profile.hvn_count; i++)
      {
         if(MathAbs(entry_price - m_volume_profile.hvn_levels[i]) <= near_distance)
         {
            at_support = true;
            break;
         }
      }

      if(!at_support)
      {
         rejection_reason = StringFormat("LONG entry (%.2f) not at/near support (VAL=%.2f)", entry_price, m_volume_profile.val);
         return false;
      }

      // Check NOT directly below major resistance (VAH, POC, or major HVN)
      bool blocked_by_resistance = false;

      // Check VAH
      if(entry_price < m_volume_profile.vah && (m_volume_profile.vah - entry_price) <= block_distance)
      {
         blocked_by_resistance = true;
         rejection_reason = StringFormat("LONG entry (%.2f) directly below VAH resistance (%.2f)", entry_price, m_volume_profile.vah);
      }

      // Check POC
      if(!blocked_by_resistance && entry_price < m_volume_profile.poc && (m_volume_profile.poc - entry_price) <= block_distance)
      {
         blocked_by_resistance = true;
         rejection_reason = StringFormat("LONG entry (%.2f) directly below POC resistance (%.2f)", entry_price, m_volume_profile.poc);
      }

      if(blocked_by_resistance)
         return false;
   }
   else // SIGNAL_SHORT
   {
      // For SHORT signals: Entry should be at/near resistance (VAH or minor HVN)
      bool at_resistance = false;

      // Check if near VAH
      if(MathAbs(entry_price - m_volume_profile.vah) <= near_distance)
      {
         at_resistance = true;
      }

      // Check if near any HVN (minor resistance)
      for(int i = 0; i < m_volume_profile.hvn_count; i++)
      {
         if(MathAbs(entry_price - m_volume_profile.hvn_levels[i]) <= near_distance)
         {
            at_resistance = true;
            break;
         }
      }

      if(!at_resistance)
      {
         rejection_reason = StringFormat("SHORT entry (%.2f) not at/near resistance (VAH=%.2f)", entry_price, m_volume_profile.vah);
         return false;
      }

      // Check NOT directly above major support (VAL, POC, or major HVN)
      bool blocked_by_support = false;

      // Check VAL
      if(entry_price > m_volume_profile.val && (entry_price - m_volume_profile.val) <= block_distance)
      {
         blocked_by_support = true;
         rejection_reason = StringFormat("SHORT entry (%.2f) directly above VAL support (%.2f)", entry_price, m_volume_profile.val);
      }

      // Check POC
      if(!blocked_by_support && entry_price > m_volume_profile.poc && (entry_price - m_volume_profile.poc) <= block_distance)
      {
         blocked_by_support = true;
         rejection_reason = StringFormat("SHORT entry (%.2f) directly above POC support (%.2f)", entry_price, m_volume_profile.poc);
      }

      if(blocked_by_support)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| GATE 3: Inter-Market Context Filter                             |
//| Validates DXY and real yields context                           |
//+------------------------------------------------------------------+
bool CSignalFilter::Gate3_InterMarketContext(CSignalData &signal, string &rejection_reason)
{
   // Check if DXY handle is available
   if(m_handle_dxy == INVALID_HANDLE)
   {
      // If DXY not available, skip this gate (don't veto)
      return true;
   }

   bool dxy_favorable = false;
   if(!CheckDXYContext(signal.signal_type, dxy_favorable))
   {
      rejection_reason = "Failed to retrieve DXY data";
      return false;
   }

   // For now, we'll implement DXY check only
   // Real yields would require additional data feed integration
   bool yields_favorable = true; // Placeholder - would need real yields data

   if(signal.signal_type == SIGNAL_LONG)
   {
      if(!dxy_favorable)
      {
         rejection_reason = "LONG signal but DXY showing strength (unfavorable for gold)";
         return false;
      }
   }
   else // SIGNAL_SHORT
   {
      if(!dxy_favorable)
      {
         rejection_reason = "SHORT signal but DXY showing weakness (unfavorable for gold short)";
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| GATE 4: Confluence Filter                                       |
//| Requires confirmation from different indicator category         |
//+------------------------------------------------------------------+
bool CSignalFilter::Gate4_ConfluenceFilter(CSignalData &signal, string &rejection_reason)
{
   ENUM_STRATEGY_CATEGORY primary_category = signal.strategy_category;

   // Check for confirmation from at least one different category
   if(!CheckConfluenceFromOtherCategories(signal, primary_category))
   {
      rejection_reason = "No confirmation from different indicator category";
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| GATE 5: Advanced Qualification Filter                           |
//| Adds quality score based on divergence and harmonic patterns    |
//| NOTE: This gate does NOT veto - it only adds conviction score   |
//+------------------------------------------------------------------+
bool CSignalFilter::Gate5_AdvancedQualification(CSignalData &signal, double &quality_score)
{
   quality_score = 50.0; // Base score

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(Symbol(), PERIOD_CURRENT, 0, 100, rates) < 100)
   {
      return true; // Don't fail, just return base score
   }

   // Check for divergence confirmation
   if(CheckDivergenceConfirmation(signal.signal_type, rates))
   {
      quality_score += 25.0;
   }

   // Check for harmonic pattern PRZ
   if(CheckHarmonicPRZ(signal.signal_type, signal.entry_price))
   {
      quality_score += 25.0;
   }

   return true; // This gate never vetoes
}

//+------------------------------------------------------------------+
//| GATE 6: Temporal Filter                                         |
//| Validates trading session and news calendar                     |
//+------------------------------------------------------------------+
bool CSignalFilter::Gate6_TemporalFilter(CSignalData &signal, string &rejection_reason)
{
   // Check if in high-liquidity session
   if(!IsHighLiquiditySession())
   {
      rejection_reason = "Not in high-liquidity session (London or New York)";
      return false;
   }

   // Check for high-impact news within next 2 hours
   if(IsHighImpactNewsNear(SF_News_Lookforward_Hours))
   {
      rejection_reason = StringFormat("High-impact news event within next %d hours", SF_News_Lookforward_Hours);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Helper: Detect Market Regime                                    |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME CSignalFilter::DetectMarketRegime(double adx_val, double bb_up, double bb_mid,
                                                      double bb_low, MqlRates &rates[])
{
   if(adx_val > SF_ADX_Trend_Threshold)
      return REGIME_TRENDING;
   else if(adx_val < SF_ADX_Trend_Threshold)
      return REGIME_RANGING;
   else
      return REGIME_UNKNOWN;
}

//+------------------------------------------------------------------+
//| Helper: Check if Bollinger Bands are expanding                  |
//+------------------------------------------------------------------+
bool CSignalFilter::IsBollingerBandsExpanding(double bb_up, double bb_mid, double bb_low,
                                               MqlRates &rates[])
{
   // Get previous BB values
   double bb_upper_prev[], bb_middle_prev[], bb_lower_prev[];
   ArraySetAsSeries(bb_upper_prev, true);
   ArraySetAsSeries(bb_middle_prev, true);
   ArraySetAsSeries(bb_lower_prev, true);

   if(CopyBuffer(m_handle_bbands, 0, 0, 5, bb_middle_prev) < 5 ||
      CopyBuffer(m_handle_bbands, 1, 0, 5, bb_upper_prev) < 5 ||
      CopyBuffer(m_handle_bbands, 2, 0, 5, bb_lower_prev) < 5)
   {
      return false;
   }

   // Calculate current and previous bandwidth
   double current_bandwidth = bb_up - bb_low;
   double prev_bandwidth = bb_upper_prev[1] - bb_lower_prev[1];

   // Check if expanding
   if(prev_bandwidth == 0) return false;

   double expansion_ratio = current_bandwidth / prev_bandwidth;
   return (expansion_ratio >= SF_BB_Expansion_Threshold);
}

//+------------------------------------------------------------------+
//| Helper: Calculate Volume Profile                                |
//+------------------------------------------------------------------+
bool CSignalFilter::CalculateVolumeProfile(MqlRates &rates[], CVolumeProfileData &vp_data)
{
   int bars = ArraySize(rates);
   if(bars < 100) return false;

   // Find price range
   double highest = rates[0].high;
   double lowest = rates[0].low;

   for(int i = 1; i < bars; i++)
   {
      if(rates[i].high > highest) highest = rates[i].high;
      if(rates[i].low < lowest) lowest = rates[i].low;
   }

   // Create price bins (100 bins)
   const int num_bins = 100;
   double bin_size = (highest - lowest) / num_bins;
   if(bin_size == 0) return false;

   double volume_bins[100];
   ArrayInitialize(volume_bins, 0);

   // Accumulate volume in bins
   for(int i = 0; i < bars; i++)
   {
      double price = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      int bin_index = (int)((price - lowest) / bin_size);
      if(bin_index >= num_bins) bin_index = num_bins - 1;
      if(bin_index < 0) bin_index = 0;

      volume_bins[bin_index] += (double)rates[i].tick_volume;
   }

   // Find POC (Point of Control - highest volume bin)
   double max_volume = 0;
   int poc_bin = 0;
   for(int i = 0; i < num_bins; i++)
   {
      if(volume_bins[i] > max_volume)
      {
         max_volume = volume_bins[i];
         poc_bin = i;
      }
   }

   vp_data.poc = lowest + (poc_bin + 0.5) * bin_size;

   // Calculate total volume
   double total_volume = 0;
   for(int i = 0; i < num_bins; i++)
      total_volume += volume_bins[i];

   // Find Value Area (70% of volume around POC)
   double value_area_volume = total_volume * 0.70;
   double accumulated_volume = volume_bins[poc_bin];
   int va_low_bin = poc_bin;
   int va_high_bin = poc_bin;

   while(accumulated_volume < value_area_volume && (va_low_bin > 0 || va_high_bin < num_bins - 1))
   {
      double vol_below = (va_low_bin > 0) ? volume_bins[va_low_bin - 1] : 0;
      double vol_above = (va_high_bin < num_bins - 1) ? volume_bins[va_high_bin + 1] : 0;

      if(vol_below > vol_above && va_low_bin > 0)
      {
         va_low_bin--;
         accumulated_volume += volume_bins[va_low_bin];
      }
      else if(va_high_bin < num_bins - 1)
      {
         va_high_bin++;
         accumulated_volume += volume_bins[va_high_bin];
      }
      else
         break;
   }

   vp_data.val = lowest + (va_low_bin + 0.5) * bin_size;
   vp_data.vah = lowest + (va_high_bin + 0.5) * bin_size;

   // Identify HVNs and LVNs (simplified - top 5 peaks and bottom 5 valleys)
   vp_data.hvn_count = 0;
   vp_data.lvn_count = 0;

   // Find local peaks (HVNs)
   for(int i = 1; i < num_bins - 1 && vp_data.hvn_count < 10; i++)
   {
      if(volume_bins[i] > volume_bins[i-1] && volume_bins[i] > volume_bins[i+1] &&
         volume_bins[i] > total_volume / num_bins * 1.5) // Above average
      {
         vp_data.hvn_levels[vp_data.hvn_count] = lowest + (i + 0.5) * bin_size;
         vp_data.hvn_count++;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Helper: Check DXY Context                                       |
//+------------------------------------------------------------------+
bool CSignalFilter::CheckDXYContext(ENUM_SIGNAL_TYPE signal_type, bool &dxy_favorable)
{
   dxy_favorable = false;

   if(m_handle_dxy == INVALID_HANDLE)
      return false;

   // Get DXY MA values
   double dxy_ma[];
   ArraySetAsSeries(dxy_ma, true);
   if(CopyBuffer(m_handle_dxy, 0, 0, 3, dxy_ma) < 3)
      return false;

   // Get current DXY price
   double dxy_price = SymbolInfoDouble(SF_DXY_Symbol, SYMBOL_BID);
   if(dxy_price == 0)
   {
      // Try to get from rates if direct price not available
      MqlRates dxy_rates[];
      ArraySetAsSeries(dxy_rates, true);
      if(CopyRates(SF_DXY_Symbol, PERIOD_CURRENT, 0, 1, dxy_rates) > 0)
         dxy_price = dxy_rates[0].close;
      else
         return false;
   }

   // Determine DXY trend
   bool dxy_falling = (dxy_price < dxy_ma[0] && dxy_ma[0] < dxy_ma[1]);
   bool dxy_rising = (dxy_price > dxy_ma[0] && dxy_ma[0] > dxy_ma[1]);

   if(signal_type == SIGNAL_LONG)
   {
      // For LONG gold: DXY should be weak/falling
      dxy_favorable = dxy_falling;
   }
   else // SIGNAL_SHORT
   {
      // For SHORT gold: DXY should be strong/rising
      dxy_favorable = dxy_rising;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Helper: Get Strategy Category                                   |
//+------------------------------------------------------------------+
ENUM_STRATEGY_CATEGORY CSignalFilter::GetStrategyCategory(string strategy_name)
{
   // Trend category
   if(StringFind(strategy_name, "MA") >= 0 || StringFind(strategy_name, "MACD") >= 0 ||
      StringFind(strategy_name, "Trend") >= 0 || StringFind(strategy_name, "Breakout") >= 0)
      return CATEGORY_TREND;

   // Momentum category
   if(StringFind(strategy_name, "RSI") >= 0 || StringFind(strategy_name, "Stochastic") >= 0 ||
      StringFind(strategy_name, "CCI") >= 0 || StringFind(strategy_name, "Momentum") >= 0)
      return CATEGORY_MOMENTUM;

   // Volatility category
   if(StringFind(strategy_name, "Bollinger") >= 0 || StringFind(strategy_name, "BB") >= 0)
      return CATEGORY_VOLATILITY;

   // Volume category
   if(StringFind(strategy_name, "Volume") >= 0)
      return CATEGORY_VOLUME;

   // Pattern category
   if(StringFind(strategy_name, "Harmonic") >= 0 || StringFind(strategy_name, "Elliott") >= 0 ||
      StringFind(strategy_name, "Chart") >= 0 || StringFind(strategy_name, "Pattern") >= 0)
      return CATEGORY_PATTERN;

   // Support/Resistance category
   if(StringFind(strategy_name, "Support") >= 0 || StringFind(strategy_name, "Resistance") >= 0 ||
      StringFind(strategy_name, "Pivot") >= 0 || StringFind(strategy_name, "S/R") >= 0)
      return CATEGORY_SUPPORT_RESISTANCE;

   // Default to pattern
   return CATEGORY_PATTERN;
}

//+------------------------------------------------------------------+
//| Helper: Check Confluence from Other Categories                  |
//+------------------------------------------------------------------+
bool CSignalFilter::CheckConfluenceFromOtherCategories(CSignalData &signal, ENUM_STRATEGY_CATEGORY primary_category)
{
   int confirmations = 0;

   // Get indicator values
   double rsi_buffer[], macd_buffer[], stoch_buffer[];
   ArraySetAsSeries(rsi_buffer, true);
   ArraySetAsSeries(macd_buffer, true);
   ArraySetAsSeries(stoch_buffer, true);

   bool rsi_ok = (CopyBuffer(m_handle_rsi, 0, 0, 1, rsi_buffer) > 0);
   bool macd_ok = (CopyBuffer(m_handle_macd, 0, 0, 1, macd_buffer) > 0);
   bool stoch_ok = (CopyBuffer(m_handle_stoch, 0, 0, 1, stoch_buffer) > 0);

   // Check momentum confirmation (if primary is not momentum)
   if(primary_category != CATEGORY_MOMENTUM)
   {
      if(signal.signal_type == SIGNAL_LONG && rsi_ok && rsi_buffer[0] > 50)
         confirmations++;
      else if(signal.signal_type == SIGNAL_SHORT && rsi_ok && rsi_buffer[0] < 50)
         confirmations++;
   }

   // Check trend confirmation (if primary is not trend)
   if(primary_category != CATEGORY_TREND)
   {
      if(signal.signal_type == SIGNAL_LONG && macd_ok && macd_buffer[0] > 0)
         confirmations++;
      else if(signal.signal_type == SIGNAL_SHORT && macd_ok && macd_buffer[0] < 0)
         confirmations++;
   }

   // Check volatility confirmation (if primary is not volatility)
   if(primary_category != CATEGORY_VOLATILITY)
   {
      double bb_up_buf[], bb_mid_buf[], bb_low_buf[];
      ArraySetAsSeries(bb_up_buf, true);
      ArraySetAsSeries(bb_mid_buf, true);
      ArraySetAsSeries(bb_low_buf, true);

      if(CopyBuffer(m_handle_bbands, 0, 0, 1, bb_mid_buf) > 0 &&
         CopyBuffer(m_handle_bbands, 1, 0, 1, bb_up_buf) > 0 &&
         CopyBuffer(m_handle_bbands, 2, 0, 1, bb_low_buf) > 0)
      {
         double current_price = signal.entry_price;
         if(signal.signal_type == SIGNAL_LONG && current_price < bb_mid_buf[0])
            confirmations++;
         else if(signal.signal_type == SIGNAL_SHORT && current_price > bb_mid_buf[0])
            confirmations++;
      }
   }

   return (confirmations >= SF_Confluence_Min_Confirmations);
}

//+------------------------------------------------------------------+
//| Helper: Check Divergence Confirmation                           |
//+------------------------------------------------------------------+
bool CSignalFilter::CheckDivergenceConfirmation(ENUM_SIGNAL_TYPE signal_type, MqlRates &rates[])
{
   // Simplified divergence check - would need full implementation
   // This is a placeholder that returns false for now
   // Full implementation would check RSI/MACD divergence with price
   return false;
}

//+------------------------------------------------------------------+
//| Helper: Check Harmonic PRZ                                      |
//+------------------------------------------------------------------+
bool CSignalFilter::CheckHarmonicPRZ(ENUM_SIGNAL_TYPE signal_type, double entry_price)
{
   // Simplified harmonic pattern check - would need full implementation
   // This is a placeholder that returns false for now
   // Full implementation would check if entry is at PRZ of valid harmonic pattern
   return false;
}

//+------------------------------------------------------------------+
//| Helper: Check if High Liquidity Session                         |
//+------------------------------------------------------------------+
bool CSignalFilter::IsHighLiquiditySession()
{
   MqlDateTime gmt_time;
   TimeToStruct(TimeGMT(), gmt_time);

   int current_hour = gmt_time.hour;

   // London session: 08:00-17:00 GMT
   bool london_session = (current_hour >= 8 && current_hour < 17);

   // New York session: 13:00-22:00 GMT
   bool newyork_session = (current_hour >= 13 && current_hour < 22);

   // Asian session: 00:00-08:00 GMT (only if allowed)
   bool asian_session = (current_hour >= 0 && current_hour < 8) && SF_Allow_Asian_Session;

   return (london_session || newyork_session || asian_session);
}

//+------------------------------------------------------------------+
//| Helper: Check if High Impact News Near                          |
//+------------------------------------------------------------------+
bool CSignalFilter::IsHighImpactNewsNear(int hours_forward)
{
   // Get current time
   MqlDateTime current_time;
   TimeToStruct(TimeCurrent(), current_time);

   // Check for known high-impact events (simplified calendar)
   // In production, this would integrate with an economic calendar API

   // NFP (Non-Farm Payroll) - First Friday of month at 13:30 GMT
   if(current_time.day_of_week == 5 && current_time.day <= 7)
   {
      if(current_time.hour >= 11 && current_time.hour <= 15) // 2 hours before/after NFP
         return true;
   }

   // FOMC announcements - typically mid-month Wednesday at 18:00 GMT
   if(current_time.day_of_week == 3 && current_time.day >= 14 && current_time.day <= 17)
   {
      if(current_time.hour >= 16 && current_time.hour <= 20)
         return true;
   }

   // CPI release - typically mid-month at 13:30 GMT
   if(current_time.day >= 12 && current_time.day <= 15)
   {
      if(current_time.hour >= 11 && current_time.hour <= 15)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Update Volume Profile Data                                      |
//+------------------------------------------------------------------+
void CSignalFilter::UpdateVolumeProfile()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int bars_to_copy = MathMin(SF_VP_Lookback_Bars, 1000);
   if(CopyRates(Symbol(), PERIOD_CURRENT, 0, bars_to_copy, rates) < 100)
   {
      Print("Warning: Failed to update Volume Profile - insufficient data");
      return;
   }

   if(CalculateVolumeProfile(rates, m_volume_profile))
   {
      m_vp_last_update = TimeCurrent();
      Print("Volume Profile updated: POC=", m_volume_profile.poc,
            " VAH=", m_volume_profile.vah, " VAL=", m_volume_profile.val);
   }
}

//+------------------------------------------------------------------+
//| Log Filter Result                                                |
//+------------------------------------------------------------------+
void CSignalFilter::LogFilterResult(CSignalData &signal, CFilterResult &result)
{
   string signal_dir = (signal.signal_type == SIGNAL_LONG) ? "LONG" : "SHORT";

   if(result.passed)
   {
      Print("SIGNAL FILTER: ", signal_dir, " signal from ", signal.strategy_name,
            " PASSED all gates. Quality Score: ", DoubleToString(result.quality_score, 1));
   }
   else
   {
      Print("SIGNAL FILTER: ", signal_dir, " signal from ", signal.strategy_name,
            " REJECTED at Gate ", result.gate_failed, ": ", result.failure_reason);
   }
}

//+------------------------------------------------------------------+
//| Helper function to create signal data from strategy output      |
//+------------------------------------------------------------------+
CSignalData CreateSignalData(ENUM_SIGNAL_TYPE type, string strategy, double entry_price)
{
   CSignalData signal;
   signal.signal_type = type;
   signal.strategy_name = strategy;
   signal.entry_price = entry_price;
   signal.signal_time = TimeCurrent();
   signal.quality_score = 0;
   signal.gates_passed = 0;
   signal.rejection_gate = "";
   signal.rejection_reason = "";

   // Determine strategy category
   CSignalFilter temp_filter;
   signal.strategy_category = temp_filter.GetStrategyCategory(strategy);

   return signal;
}

