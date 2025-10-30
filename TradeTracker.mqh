//+------------------------------------------------------------------+
//|                                                  TradeTracker.mqh |
//|                                      Trade Performance Tracking   |
//+------------------------------------------------------------------+
#property copyright "GoldTraderEA"
#property version   "1.00"
#property strict

#include "JSONTradeExporter.mqh"

//+------------------------------------------------------------------+
//| Trade Information Structure                                       |
//+------------------------------------------------------------------+
struct TradeInfo
{
   ulong    ticket;              // Position ticket number
   string   strategy_name;       // Strategy that generated the signal
   string   direction;           // "LONG" or "SHORT"
   datetime entry_time;          // When position was opened
   double   entry_price;         // Entry price
   double   stop_loss;           // Stop loss level
   double   take_profit;         // Take profit level
   double   lot_size;            // Position size
   double   quality_score;       // Signal quality score from filter

   // Exit information (filled when position closes)
   datetime exit_time;           // When position was closed
   double   exit_price;          // Exit price
   double   profit_usd;          // Profit/Loss in USD
   double   profit_pips;         // Profit/Loss in pips
   int      duration_seconds;    // Trade duration in seconds
   string   exit_reason;         // Why trade closed
   bool     is_closed;           // Whether trade has been closed

   // Signal consensus data (extended for JSON export)
   int      total_strategies_enabled;    // Total strategies enabled in EA settings
   int      total_strategies_checked;    // Total strategies actually evaluated for this trade
   int      strategies_buy;
   int      strategies_sell;
   int      strategies_none;
   double   consensus_percentage;
   int      total_weight_buy;
   int      total_weight_sell;
   int      gates_passed;
   string   rejection_gate;
   string   rejection_reason;

   // Strategy votes
   StrategySignal strategy_votes[20];
   int      strategy_count;

   // Market context at entry
   double   adx_value;
   double   rsi_value;
   double   macd_value;
};

//+------------------------------------------------------------------+
//| Trade Tracker Class                                               |
//+------------------------------------------------------------------+
class CTradeTracker
{
private:
   TradeInfo m_trades[];         // Array of all trades
   int       m_trade_count;      // Number of trades tracked
   int       m_file_handle;      // CSV file handle
   string    m_csv_filename;     // CSV filename

   // JSON exporter
   CJSONTradeExporter m_json_exporter;
   bool      m_json_enabled;

   // Performance statistics per strategy
   struct StrategyStats
   {
      string strategy_name;
      int    total_trades;
      int    winning_trades;
      int    losing_trades;
      double total_profit_usd;
      double total_profit_pips;
      double win_rate;
      double avg_profit_usd;
      double avg_profit_pips;
      double avg_duration_minutes;
   };

   StrategyStats m_strategy_stats[];
   int           m_stats_count;

public:
   CTradeTracker();
   ~CTradeTracker();

   // Core tracking functions
   void RecordTradeEntry(ulong ticket, string strategy, string direction, double entry_price,
                         double sl, double tp, double lot_size, double quality_score);
   void RecordTradeEntryWithConsensus(ulong ticket, string strategy, string direction,
                         double entry_price, double sl, double tp, double lot_size,
                         double quality_score, int gates_passed, string rejection_gate,
                         string rejection_reason, StrategySignal &votes[], int vote_count,
                         int total_enabled, int total_checked, int buy_count, int sell_count, int none_count,
                         int weight_buy, int weight_sell, double adx, double rsi, double macd);
   void RecordTradeExit(ulong ticket, double exit_price, double profit_usd, string exit_reason);

   // CSV logging
   bool InitializeCSV(string filename);
   void WriteTradeToCSV(TradeInfo &trade);
   void CloseCSV();

   // JSON logging
   bool InitializeJSON(string filename, string ea_version = "2.40", int ea_build = 2010, string ea_settings = "");
   void WriteTradeToJSON(TradeInfo &trade);
   void CloseJSON();

   // Performance analysis
   void CalculateStrategyPerformance();
   void PrintPerformanceSummary();
   void PrintStrategyBreakdown();

   // Utility functions
   int  FindTradeByTicket(ulong ticket);
   void UpdateExitInfo(ulong ticket, double exit_price, double profit_usd, string exit_reason);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTradeTracker::CTradeTracker()
{
   m_trade_count = 0;
   m_stats_count = 0;
   m_file_handle = INVALID_HANDLE;
   m_json_enabled = false;
   ArrayResize(m_trades, 0);
   ArrayResize(m_strategy_stats, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTradeTracker::~CTradeTracker()
{
   CloseCSV();
   CloseJSON();
}

//+------------------------------------------------------------------+
//| Initialize CSV file for trade logging                            |
//+------------------------------------------------------------------+
bool CTradeTracker::InitializeCSV(string filename)
{
   m_csv_filename = filename;
   
   // Open file for writing
   m_file_handle = FileOpen(m_csv_filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
   
   if(m_file_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create CSV file: ", m_csv_filename, " Error: ", GetLastError());
      return false;
   }
   
   // Write CSV header
   FileWrite(m_file_handle, 
             "Ticket",
             "Strategy",
             "Direction",
             "Entry Time",
             "Entry Price",
             "Stop Loss",
             "Take Profit",
             "Lot Size",
             "Quality Score",
             "Exit Time",
             "Exit Price",
             "Profit USD",
             "Profit Pips",
             "Duration (min)",
             "Exit Reason");
   
   Print("Trade tracking CSV initialized: ", m_csv_filename);
   return true;
}

//+------------------------------------------------------------------+
//| Record trade entry (simple version - backward compatible)        |
//+------------------------------------------------------------------+
void CTradeTracker::RecordTradeEntry(ulong ticket, string strategy, string direction,
                                     double entry_price, double sl, double tp,
                                     double lot_size, double quality_score)
{
   // Resize array to accommodate new trade
   ArrayResize(m_trades, m_trade_count + 1);

   // Fill trade information
   m_trades[m_trade_count].ticket = ticket;
   m_trades[m_trade_count].strategy_name = strategy;
   m_trades[m_trade_count].direction = direction;
   m_trades[m_trade_count].entry_time = TimeCurrent();
   m_trades[m_trade_count].entry_price = entry_price;
   m_trades[m_trade_count].stop_loss = sl;
   m_trades[m_trade_count].take_profit = tp;
   m_trades[m_trade_count].lot_size = lot_size;
   m_trades[m_trade_count].quality_score = quality_score;
   m_trades[m_trade_count].is_closed = false;

   // Initialize consensus data to defaults
   m_trades[m_trade_count].total_strategies_enabled = 0;
   m_trades[m_trade_count].strategies_buy = 0;
   m_trades[m_trade_count].strategies_sell = 0;
   m_trades[m_trade_count].strategies_none = 0;
   m_trades[m_trade_count].consensus_percentage = 0;
   m_trades[m_trade_count].total_weight_buy = 0;
   m_trades[m_trade_count].total_weight_sell = 0;
   m_trades[m_trade_count].gates_passed = 0;
   m_trades[m_trade_count].rejection_gate = "";
   m_trades[m_trade_count].rejection_reason = "";
   m_trades[m_trade_count].strategy_count = 0;
   m_trades[m_trade_count].adx_value = 0;
   m_trades[m_trade_count].rsi_value = 0;
   m_trades[m_trade_count].macd_value = 0;

   m_trade_count++;

   Print("TRADE TRACKER: Recorded entry for ticket #", ticket, " | Strategy: ", strategy,
         " | Direction: ", direction, " | Entry: ", DoubleToString(entry_price, 2));
}

//+------------------------------------------------------------------+
//| Record trade entry with full consensus data                      |
//+------------------------------------------------------------------+
void CTradeTracker::RecordTradeEntryWithConsensus(ulong ticket, string strategy, string direction,
                                     double entry_price, double sl, double tp, double lot_size,
                                     double quality_score, int gates_passed, string rejection_gate,
                                     string rejection_reason, StrategySignal &votes[], int vote_count,
                                     int total_enabled, int total_checked, int buy_count, int sell_count, int none_count,
                                     int weight_buy, int weight_sell, double adx_val, double rsi_val, double macd_val)
{
   // Resize array to accommodate new trade
   ArrayResize(m_trades, m_trade_count + 1);

   // Fill basic trade information
   m_trades[m_trade_count].ticket = ticket;
   m_trades[m_trade_count].strategy_name = strategy;
   m_trades[m_trade_count].direction = direction;
   m_trades[m_trade_count].entry_time = TimeCurrent();
   m_trades[m_trade_count].entry_price = entry_price;
   m_trades[m_trade_count].stop_loss = sl;
   m_trades[m_trade_count].take_profit = tp;
   m_trades[m_trade_count].lot_size = lot_size;
   m_trades[m_trade_count].quality_score = quality_score;
   m_trades[m_trade_count].is_closed = false;

   // Fill consensus data
   m_trades[m_trade_count].total_strategies_enabled = total_enabled;
   m_trades[m_trade_count].total_strategies_checked = total_checked;
   m_trades[m_trade_count].strategies_buy = buy_count;
   m_trades[m_trade_count].strategies_sell = sell_count;
   m_trades[m_trade_count].strategies_none = none_count;
   m_trades[m_trade_count].total_weight_buy = weight_buy;
   m_trades[m_trade_count].total_weight_sell = weight_sell;
   m_trades[m_trade_count].gates_passed = gates_passed;
   m_trades[m_trade_count].rejection_gate = rejection_gate;
   m_trades[m_trade_count].rejection_reason = rejection_reason;

   // Calculate consensus percentage based on all enabled strategies (not just checked)
   // This gives a conservative measure: unchecked strategies count as non-agreeing
   int agreeing = (direction == "LONG") ? buy_count : sell_count;
   m_trades[m_trade_count].consensus_percentage = (total_enabled > 0) ? (agreeing * 100.0 / total_enabled) : 0;

   // Copy strategy votes
   m_trades[m_trade_count].strategy_count = MathMin(vote_count, 20);
   for(int i = 0; i < m_trades[m_trade_count].strategy_count; i++)
   {
      m_trades[m_trade_count].strategy_votes[i] = votes[i];
   }

   // Fill market context
   m_trades[m_trade_count].adx_value = adx_val;
   m_trades[m_trade_count].rsi_value = rsi_val;
   m_trades[m_trade_count].macd_value = macd_val;

   m_trade_count++;

   Print("TRADE TRACKER: Recorded entry with consensus for ticket #", ticket,
         " | Strategy: ", strategy, " | Direction: ", direction,
         " | Consensus: ", DoubleToString(m_trades[m_trade_count-1].consensus_percentage, 1), "%",
         " | Quality: ", DoubleToString(quality_score, 1));
}

//+------------------------------------------------------------------+
//| Record trade exit                                                 |
//+------------------------------------------------------------------+
void CTradeTracker::RecordTradeExit(ulong ticket, double exit_price, double profit_usd, string exit_reason)
{
   int index = FindTradeByTicket(ticket);

   if(index < 0)
   {
      Print("WARNING: Trade tracker could not find ticket #", ticket, " for exit recording");
      return;
   }

   // Check if this trade has already been closed (prevent duplicate CSV entries)
   if(m_trades[index].is_closed)
   {
      // Trade already recorded, skip to prevent duplicates
      return;
   }

   // Calculate profit in pips
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double pip_value = point * 10;
   double profit_pips = 0;
   
   if(m_trades[index].direction == "LONG")
      profit_pips = (exit_price - m_trades[index].entry_price) / pip_value;
   else
      profit_pips = (m_trades[index].entry_price - exit_price) / pip_value;
   
   // Fill exit information
   m_trades[index].exit_time = TimeCurrent();
   m_trades[index].exit_price = exit_price;
   m_trades[index].profit_usd = profit_usd;
   m_trades[index].profit_pips = profit_pips;
   m_trades[index].duration_seconds = (int)(m_trades[index].exit_time - m_trades[index].entry_time);
   m_trades[index].exit_reason = exit_reason;
   m_trades[index].is_closed = true;
   
   // Write to CSV
   WriteTradeToCSV(m_trades[index]);

   // Write to JSON if enabled
   if(m_json_enabled)
   {
      WriteTradeToJSON(m_trades[index]);
   }

   Print("TRADE TRACKER: Recorded exit for ticket #", ticket, " | Strategy: ", m_trades[index].strategy_name,
         " | Profit: $", DoubleToString(profit_usd, 2), " (", DoubleToString(profit_pips, 1), " pips)",
         " | Reason: ", exit_reason);
}

//+------------------------------------------------------------------+
//| Write trade to CSV file                                           |
//+------------------------------------------------------------------+
void CTradeTracker::WriteTradeToCSV(TradeInfo &trade_info)
{
   if(m_file_handle == INVALID_HANDLE)
      return;

   FileWrite(m_file_handle,
             IntegerToString(trade_info.ticket),
             trade_info.strategy_name,
             trade_info.direction,
             TimeToString(trade_info.entry_time, TIME_DATE|TIME_MINUTES),
             DoubleToString(trade_info.entry_price, 2),
             DoubleToString(trade_info.stop_loss, 2),
             DoubleToString(trade_info.take_profit, 2),
             DoubleToString(trade_info.lot_size, 2),
             DoubleToString(trade_info.quality_score, 1),
             TimeToString(trade_info.exit_time, TIME_DATE|TIME_MINUTES),
             DoubleToString(trade_info.exit_price, 2),
             DoubleToString(trade_info.profit_usd, 2),
             DoubleToString(trade_info.profit_pips, 1),
             DoubleToString(trade_info.duration_seconds / 60.0, 1),
             trade_info.exit_reason);

   FileFlush(m_file_handle);  // Ensure data is written immediately
}

//+------------------------------------------------------------------+
//| Find trade by ticket number                                       |
//+------------------------------------------------------------------+
int CTradeTracker::FindTradeByTicket(ulong ticket)
{
   for(int i = 0; i < m_trade_count; i++)
   {
      if(m_trades[i].ticket == ticket)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Close CSV file                                                    |
//+------------------------------------------------------------------+
void CTradeTracker::CloseCSV()
{
   if(m_file_handle != INVALID_HANDLE)
   {
      FileClose(m_file_handle);
      m_file_handle = INVALID_HANDLE;
      Print("Trade tracking CSV closed: ", m_csv_filename);
   }
}

//+------------------------------------------------------------------+
//| Initialize JSON file for trade logging                           |
//+------------------------------------------------------------------+
bool CTradeTracker::InitializeJSON(string filename, string ea_version = "2.40", int ea_build = 2010, string ea_settings = "")
{
   m_json_enabled = m_json_exporter.InitializeJSON(filename, ea_version, ea_build, ea_settings);
   return m_json_enabled;
}

//+------------------------------------------------------------------+
//| Write trade to JSON file                                          |
//+------------------------------------------------------------------+
void CTradeTracker::WriteTradeToJSON(TradeInfo &trade_info)
{
   if(!m_json_enabled)
      return;

   // Convert TradeInfo to JSONTradeInfo
   JSONTradeInfo json_trade;

   // Trade metadata
   json_trade.ticket = trade_info.ticket;
   json_trade.entry_time = trade_info.entry_time;
   json_trade.exit_time = trade_info.exit_time;
   json_trade.entry_price = trade_info.entry_price;
   json_trade.exit_price = trade_info.exit_price;
   json_trade.stop_loss = trade_info.stop_loss;
   json_trade.take_profit = trade_info.take_profit;
   json_trade.lot_size = trade_info.lot_size;
   json_trade.profit_usd = trade_info.profit_usd;
   json_trade.profit_pips = trade_info.profit_pips;
   json_trade.duration_seconds = trade_info.duration_seconds;
   json_trade.direction = trade_info.direction;
   json_trade.exit_reason = trade_info.exit_reason;

   // Signal consensus data
   json_trade.primary_strategy = trade_info.strategy_name;
   json_trade.total_strategies_enabled = trade_info.total_strategies_enabled;
   json_trade.total_strategies_checked = trade_info.total_strategies_checked;
   json_trade.strategies_buy = trade_info.strategies_buy;
   json_trade.strategies_sell = trade_info.strategies_sell;
   json_trade.strategies_none = trade_info.strategies_none;
   json_trade.consensus_percentage = trade_info.consensus_percentage;
   json_trade.total_weight_buy = trade_info.total_weight_buy;
   json_trade.total_weight_sell = trade_info.total_weight_sell;

   // Strategy votes
   json_trade.strategy_count = trade_info.strategy_count;
   for(int i = 0; i < trade_info.strategy_count; i++)
   {
      json_trade.strategy_votes[i] = trade_info.strategy_votes[i];
   }

   // Signal filtration details
   json_trade.quality_score = trade_info.quality_score;
   json_trade.gates_passed = trade_info.gates_passed;
   json_trade.rejection_gate = trade_info.rejection_gate;
   json_trade.rejection_reason = trade_info.rejection_reason;

   // Market context
   json_trade.adx_value = trade_info.adx_value;
   json_trade.rsi_value = trade_info.rsi_value;
   json_trade.macd_value = trade_info.macd_value;

   // Write to JSON file
   m_json_exporter.WriteTradeToJSON(json_trade);
}

//+------------------------------------------------------------------+
//| Close JSON file                                                   |
//+------------------------------------------------------------------+
void CTradeTracker::CloseJSON()
{
   if(m_json_enabled)
   {
      m_json_exporter.CloseJSON();
      m_json_enabled = false;
   }
}

//+------------------------------------------------------------------+
//| Calculate performance statistics per strategy                     |
//+------------------------------------------------------------------+
void CTradeTracker::CalculateStrategyPerformance()
{
   // Clear existing stats
   ArrayResize(m_strategy_stats, 0);
   m_stats_count = 0;
   
   // Process each closed trade
   for(int i = 0; i < m_trade_count; i++)
   {
      if(!m_trades[i].is_closed)
         continue;
      
      string strategy = m_trades[i].strategy_name;
      
      // Find or create strategy stats entry
      int stats_index = -1;
      for(int j = 0; j < m_stats_count; j++)
      {
         if(m_strategy_stats[j].strategy_name == strategy)
         {
            stats_index = j;
            break;
         }
      }
      
      if(stats_index < 0)
      {
         // Create new stats entry
         ArrayResize(m_strategy_stats, m_stats_count + 1);
         m_strategy_stats[m_stats_count].strategy_name = strategy;
         m_strategy_stats[m_stats_count].total_trades = 0;
         m_strategy_stats[m_stats_count].winning_trades = 0;
         m_strategy_stats[m_stats_count].losing_trades = 0;
         m_strategy_stats[m_stats_count].total_profit_usd = 0;
         m_strategy_stats[m_stats_count].total_profit_pips = 0;
         m_strategy_stats[m_stats_count].avg_duration_minutes = 0;
         stats_index = m_stats_count;
         m_stats_count++;
      }
      
      // Update statistics
      m_strategy_stats[stats_index].total_trades++;
      m_strategy_stats[stats_index].total_profit_usd += m_trades[i].profit_usd;
      m_strategy_stats[stats_index].total_profit_pips += m_trades[i].profit_pips;
      m_strategy_stats[stats_index].avg_duration_minutes += m_trades[i].duration_seconds / 60.0;
      
      if(m_trades[i].profit_usd > 0)
         m_strategy_stats[stats_index].winning_trades++;
      else if(m_trades[i].profit_usd < 0)
         m_strategy_stats[stats_index].losing_trades++;
   }
   
   // Calculate averages and win rates
   for(int i = 0; i < m_stats_count; i++)
   {
      if(m_strategy_stats[i].total_trades > 0)
      {
         m_strategy_stats[i].win_rate = (double)m_strategy_stats[i].winning_trades / 
                                        m_strategy_stats[i].total_trades * 100.0;
         m_strategy_stats[i].avg_profit_usd = m_strategy_stats[i].total_profit_usd / 
                                              m_strategy_stats[i].total_trades;
         m_strategy_stats[i].avg_profit_pips = m_strategy_stats[i].total_profit_pips / 
                                               m_strategy_stats[i].total_trades;
         m_strategy_stats[i].avg_duration_minutes /= m_strategy_stats[i].total_trades;
      }
   }
}

//+------------------------------------------------------------------+
//| Print overall performance summary                                 |
//+------------------------------------------------------------------+
void CTradeTracker::PrintPerformanceSummary()
{
   Print("========================================");
   Print("=== TRADE PERFORMANCE SUMMARY ===");
   Print("========================================");

   int total_closed = 0;
   int total_winning = 0;
   int total_losing = 0;
   double total_profit = 0;
   double total_pips = 0;

   for(int i = 0; i < m_trade_count; i++)
   {
      if(m_trades[i].is_closed)
      {
         total_closed++;
         total_profit += m_trades[i].profit_usd;
         total_pips += m_trades[i].profit_pips;

         if(m_trades[i].profit_usd > 0)
            total_winning++;
         else if(m_trades[i].profit_usd < 0)
            total_losing++;
      }
   }

   Print("Total Trades: ", total_closed);
   Print("Winning Trades: ", total_winning);
   Print("Losing Trades: ", total_losing);

   if(total_closed > 0)
   {
      double win_rate = (double)total_winning / total_closed * 100.0;
      double avg_profit = total_profit / total_closed;
      double avg_pips = total_pips / total_closed;

      Print("Win Rate: ", DoubleToString(win_rate, 2), "%");
      Print("Total Profit: $", DoubleToString(total_profit, 2));
      Print("Total Pips: ", DoubleToString(total_pips, 1));
      Print("Average Profit per Trade: $", DoubleToString(avg_profit, 2));
      Print("Average Pips per Trade: ", DoubleToString(avg_pips, 1));
   }

   Print("========================================");
}

//+------------------------------------------------------------------+
//| Print strategy-by-strategy breakdown                              |
//+------------------------------------------------------------------+
void CTradeTracker::PrintStrategyBreakdown()
{
   CalculateStrategyPerformance();

   Print("========================================");
   Print("=== STRATEGY PERFORMANCE BREAKDOWN ===");
   Print("========================================");

   if(m_stats_count == 0)
   {
      Print("No strategy statistics available");
      return;
   }

   // Sort strategies by total profit (descending)
   for(int i = 0; i < m_stats_count - 1; i++)
   {
      for(int j = i + 1; j < m_stats_count; j++)
      {
         if(m_strategy_stats[j].total_profit_usd > m_strategy_stats[i].total_profit_usd)
         {
            StrategyStats temp = m_strategy_stats[i];
            m_strategy_stats[i] = m_strategy_stats[j];
            m_strategy_stats[j] = temp;
         }
      }
   }

   // Print each strategy's performance
   for(int i = 0; i < m_stats_count; i++)
   {
      Print("--- ", m_strategy_stats[i].strategy_name, " ---");
      Print("  Total Trades: ", m_strategy_stats[i].total_trades);
      Print("  Winning: ", m_strategy_stats[i].winning_trades,
            " | Losing: ", m_strategy_stats[i].losing_trades);
      Print("  Win Rate: ", DoubleToString(m_strategy_stats[i].win_rate, 2), "%");
      Print("  Total Profit: $", DoubleToString(m_strategy_stats[i].total_profit_usd, 2));
      Print("  Total Pips: ", DoubleToString(m_strategy_stats[i].total_profit_pips, 1));
      Print("  Avg Profit/Trade: $", DoubleToString(m_strategy_stats[i].avg_profit_usd, 2));
      Print("  Avg Pips/Trade: ", DoubleToString(m_strategy_stats[i].avg_profit_pips, 1));
      Print("  Avg Duration: ", DoubleToString(m_strategy_stats[i].avg_duration_minutes, 1), " minutes");
      Print("");
   }

   Print("========================================");
}

