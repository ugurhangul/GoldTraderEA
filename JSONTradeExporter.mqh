//+------------------------------------------------------------------+
//|                                            JSONTradeExporter.mqh |
//|                          JSON Export for Trade Signal Consensus  |
//+------------------------------------------------------------------+
#property copyright "GoldTraderEA"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Strategy Signal Consensus Structure                              |
//+------------------------------------------------------------------+
struct StrategySignal
{
   string strategy_name;      // Name of the strategy
   int    signal_vote;        // 1 = BUY, -1 = SELL, 0 = NONE
   int    weight;             // Weight of this strategy
   bool   is_primary;         // Is this the primary strategy that triggered the trade?
};

//+------------------------------------------------------------------+
//| Extended Trade Information for JSON Export                       |
//+------------------------------------------------------------------+
struct JSONTradeInfo
{
   // Trade metadata
   ulong    ticket;
   datetime entry_time;
   datetime exit_time;
   double   entry_price;
   double   exit_price;
   double   stop_loss;
   double   take_profit;
   double   lot_size;
   double   profit_usd;
   double   profit_pips;
   int      duration_seconds;
   string   direction;        // "LONG" or "SHORT"
   string   exit_reason;
   
   // Signal consensus data
   string   primary_strategy;
   int      total_strategies_enabled;
   int      total_strategies_checked;
   int      strategies_buy;
   int      strategies_sell;
   int      strategies_none;
   double   consensus_percentage;
   int      total_weight_buy;
   int      total_weight_sell;
   
   // Strategy votes
   StrategySignal strategy_votes[20];  // Max 20 strategies
   int      strategy_count;
   
   // Signal filtration details
   double   quality_score;
   int      gates_passed;
   string   rejection_gate;
   string   rejection_reason;
   
   // Additional context
   double   adx_value;
   double   rsi_value;
   double   macd_value;
};

//+------------------------------------------------------------------+
//| JSON Trade Exporter Class                                        |
//+------------------------------------------------------------------+
class CJSONTradeExporter
{
private:
   int       m_file_handle;
   string    m_json_filename;
   JSONTradeInfo m_trades[];
   int       m_trade_count;
   bool      m_first_trade;
   
   // Helper methods
   string EscapeJSON(string text);
   string DoubleToJSON(double value, int digits);
   string IntToJSON(int value);
   string BoolToJSON(bool value);
   string DateTimeToJSON(datetime dt);
   
public:
   CJSONTradeExporter();
   ~CJSONTradeExporter();

   bool InitializeJSON(string filename, string ea_settings = "");
   void AddTrade(JSONTradeInfo &trade);
   void WriteTradeToJSON(JSONTradeInfo &trade);
   void CloseJSON();
   void FinalizeJSON();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CJSONTradeExporter::CJSONTradeExporter()
{
   m_file_handle = INVALID_HANDLE;
   m_trade_count = 0;
   m_first_trade = true;
   ArrayResize(m_trades, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CJSONTradeExporter::~CJSONTradeExporter()
{
   CloseJSON();
}

//+------------------------------------------------------------------+
//| Initialize JSON file                                              |
//+------------------------------------------------------------------+
bool CJSONTradeExporter::InitializeJSON(string filename, string ea_settings = "")
{
   m_json_filename = filename;

   // Open file for writing
   m_file_handle = FileOpen(m_json_filename, FILE_WRITE|FILE_TXT|FILE_ANSI);

   if(m_file_handle == INVALID_HANDLE)
   {
      int error_code = GetLastError();
      Print("ERROR: Failed to create JSON file: ", m_json_filename, " Error: ", error_code);
      Print("ERROR: File path would be: ", TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL5\\Files\\", m_json_filename);
      return false;
   }

   // Write JSON header
   FileWriteString(m_file_handle, "{\n");
   FileWriteString(m_file_handle, "  \"export_info\": {\n");
   FileWriteString(m_file_handle, "    \"ea_name\": \"GoldTraderEA\",\n");
   FileWriteString(m_file_handle, "    \"version\": \"2.20\",\n");
   FileWriteString(m_file_handle, "    \"export_date\": \"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\",\n");
   FileWriteString(m_file_handle, "    \"symbol\": \"" + Symbol() + "\",\n");
   FileWriteString(m_file_handle, "    \"timeframe\": \"" + EnumToString(Period()) + "\"");

   // Add EA settings if provided
   if(ea_settings != "")
   {
      FileWriteString(m_file_handle, ",\n");
      FileWriteString(m_file_handle, ea_settings);
   }
   else
   {
      FileWriteString(m_file_handle, "\n");
   }

   FileWriteString(m_file_handle, "  },\n");
   FileWriteString(m_file_handle, "  \"trades\": [\n");

   FileFlush(m_file_handle);  // Ensure header is written immediately
   m_first_trade = true;

   Print("JSON trade export initialized successfully!");
   Print("JSON file: ", m_json_filename);
   Print("JSON full path: ", TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL5\\Files\\", m_json_filename);
   return true;
}

//+------------------------------------------------------------------+
//| Add trade to internal array                                       |
//+------------------------------------------------------------------+
void CJSONTradeExporter::AddTrade(JSONTradeInfo &trade_info)
{
   ArrayResize(m_trades, m_trade_count + 1);
   m_trades[m_trade_count] = trade_info;
   m_trade_count++;
}

//+------------------------------------------------------------------+
//| Write single trade to JSON file                                  |
//+------------------------------------------------------------------+
void CJSONTradeExporter::WriteTradeToJSON(JSONTradeInfo &trade_info)
{
   if(m_file_handle == INVALID_HANDLE)
      return;

   // Add comma before trade if not first
   if(!m_first_trade)
   {
      FileWriteString(m_file_handle, ",\n");
   }
   m_first_trade = false;

   // Start trade object
   FileWriteString(m_file_handle, "    {\n");

   // Trade metadata
   FileWriteString(m_file_handle, "      \"trade_metadata\": {\n");
   FileWriteString(m_file_handle, "        \"ticket\": " + IntToJSON((int)trade_info.ticket) + ",\n");
   FileWriteString(m_file_handle, "        \"direction\": \"" + trade_info.direction + "\",\n");
   FileWriteString(m_file_handle, "        \"entry_time\": \"" + DateTimeToJSON(trade_info.entry_time) + "\",\n");
   FileWriteString(m_file_handle, "        \"exit_time\": \"" + DateTimeToJSON(trade_info.exit_time) + "\",\n");
   FileWriteString(m_file_handle, "        \"entry_price\": " + DoubleToJSON(trade_info.entry_price, 2) + ",\n");
   FileWriteString(m_file_handle, "        \"exit_price\": " + DoubleToJSON(trade_info.exit_price, 2) + ",\n");
   FileWriteString(m_file_handle, "        \"stop_loss\": " + DoubleToJSON(trade_info.stop_loss, 2) + ",\n");
   FileWriteString(m_file_handle, "        \"take_profit\": " + DoubleToJSON(trade_info.take_profit, 2) + ",\n");
   FileWriteString(m_file_handle, "        \"lot_size\": " + DoubleToJSON(trade_info.lot_size, 2) + ",\n");
   FileWriteString(m_file_handle, "        \"profit_usd\": " + DoubleToJSON(trade_info.profit_usd, 2) + ",\n");
   FileWriteString(m_file_handle, "        \"profit_pips\": " + DoubleToJSON(trade_info.profit_pips, 1) + ",\n");
   FileWriteString(m_file_handle, "        \"duration_minutes\": " + DoubleToJSON(trade_info.duration_seconds / 60.0, 1) + ",\n");
   FileWriteString(m_file_handle, "        \"exit_reason\": \"" + EscapeJSON(trade_info.exit_reason) + "\"\n");
   FileWriteString(m_file_handle, "      },\n");

   // Signal consensus data
   FileWriteString(m_file_handle, "      \"signal_consensus\": {\n");
   FileWriteString(m_file_handle, "        \"primary_strategy\": \"" + EscapeJSON(trade_info.primary_strategy) + "\",\n");
   FileWriteString(m_file_handle, "        \"total_strategies_enabled\": " + IntToJSON(trade_info.total_strategies_enabled) + ",\n");
   FileWriteString(m_file_handle, "        \"total_strategies_checked\": " + IntToJSON(trade_info.total_strategies_checked) + ",\n");
   FileWriteString(m_file_handle, "        \"strategies_agreeing\": " + IntToJSON(trade_info.strategies_buy + trade_info.strategies_sell) + ",\n");
   FileWriteString(m_file_handle, "        \"strategies_buy_signal\": " + IntToJSON(trade_info.strategies_buy) + ",\n");
   FileWriteString(m_file_handle, "        \"strategies_sell_signal\": " + IntToJSON(trade_info.strategies_sell) + ",\n");
   FileWriteString(m_file_handle, "        \"strategies_no_signal\": " + IntToJSON(trade_info.strategies_none) + ",\n");
   FileWriteString(m_file_handle, "        \"consensus_percentage\": " + DoubleToJSON(trade_info.consensus_percentage, 1) + ",\n");
   FileWriteString(m_file_handle, "        \"total_weight_buy\": " + IntToJSON(trade_info.total_weight_buy) + ",\n");
   FileWriteString(m_file_handle, "        \"total_weight_sell\": " + IntToJSON(trade_info.total_weight_sell) + "\n");
   FileWriteString(m_file_handle, "      },\n");

   // Strategy votes array
   FileWriteString(m_file_handle, "      \"strategy_votes\": [\n");
   for(int i = 0; i < trade_info.strategy_count; i++)
   {
      FileWriteString(m_file_handle, "        {\n");
      FileWriteString(m_file_handle, "          \"strategy\": \"" + EscapeJSON(trade_info.strategy_votes[i].strategy_name) + "\",\n");

      // Determine vote direction and count
      string vote_str = "NONE";
      int vote_count = 0;
      if(trade_info.strategy_votes[i].signal_vote > 0) {
         vote_str = "BUY";
         vote_count = trade_info.strategy_votes[i].signal_vote;
      }
      else if(trade_info.strategy_votes[i].signal_vote < 0) {
         vote_str = "SELL";
         vote_count = MathAbs(trade_info.strategy_votes[i].signal_vote);
      }

      FileWriteString(m_file_handle, "          \"vote\": \"" + vote_str + "\",\n");
      FileWriteString(m_file_handle, "          \"vote_count\": " + IntToJSON(vote_count) + ",\n");
      FileWriteString(m_file_handle, "          \"weight\": " + IntToJSON(trade_info.strategy_votes[i].weight) + ",\n");
      FileWriteString(m_file_handle, "          \"contribution\": " + IntToJSON(vote_count * trade_info.strategy_votes[i].weight) + ",\n");
      FileWriteString(m_file_handle, "          \"is_primary\": " + BoolToJSON(trade_info.strategy_votes[i].is_primary) + "\n");
      FileWriteString(m_file_handle, "        }");

      if(i < trade_info.strategy_count - 1)
         FileWriteString(m_file_handle, ",\n");
      else
         FileWriteString(m_file_handle, "\n");
   }
   FileWriteString(m_file_handle, "      ],\n");

   // Signal filtration details
   FileWriteString(m_file_handle, "      \"signal_filtration\": {\n");
   FileWriteString(m_file_handle, "        \"quality_score\": " + DoubleToJSON(trade_info.quality_score, 1) + ",\n");
   FileWriteString(m_file_handle, "        \"gates_passed\": " + IntToJSON(trade_info.gates_passed) + ",\n");
   FileWriteString(m_file_handle, "        \"rejection_gate\": \"" + EscapeJSON(trade_info.rejection_gate) + "\",\n");
   FileWriteString(m_file_handle, "        \"rejection_reason\": \"" + EscapeJSON(trade_info.rejection_reason) + "\"\n");
   FileWriteString(m_file_handle, "      },\n");

   // Market context
   FileWriteString(m_file_handle, "      \"market_context\": {\n");
   FileWriteString(m_file_handle, "        \"adx_value\": " + DoubleToJSON(trade_info.adx_value, 2) + ",\n");
   FileWriteString(m_file_handle, "        \"rsi_value\": " + DoubleToJSON(trade_info.rsi_value, 2) + ",\n");
   FileWriteString(m_file_handle, "        \"macd_value\": " + DoubleToJSON(trade_info.macd_value, 5) + "\n");
   FileWriteString(m_file_handle, "      }\n");
   
   // End trade object
   FileWriteString(m_file_handle, "    }");
   
   FileFlush(m_file_handle);
}

//+------------------------------------------------------------------+
//| Finalize and close JSON file                                     |
//+------------------------------------------------------------------+
void CJSONTradeExporter::FinalizeJSON()
{
   if(m_file_handle == INVALID_HANDLE)
      return;
   
   // Close trades array
   FileWriteString(m_file_handle, "\n  ],\n");
   
   // Add summary statistics
   FileWriteString(m_file_handle, "  \"summary\": {\n");
   FileWriteString(m_file_handle, "    \"total_trades\": " + IntToJSON(m_trade_count) + "\n");
   FileWriteString(m_file_handle, "  }\n");
   
   // Close root object
   FileWriteString(m_file_handle, "}\n");
   
   FileFlush(m_file_handle);
}

//+------------------------------------------------------------------+
//| Close JSON file                                                   |
//+------------------------------------------------------------------+
void CJSONTradeExporter::CloseJSON()
{
   if(m_file_handle != INVALID_HANDLE)
   {
      FinalizeJSON();
      FileClose(m_file_handle);
      m_file_handle = INVALID_HANDLE;
      Print("JSON trade export closed: ", m_json_filename);
   }
}

//+------------------------------------------------------------------+
//| Helper: Escape special characters for JSON                       |
//+------------------------------------------------------------------+
string CJSONTradeExporter::EscapeJSON(string text)
{
   string result = text;
   StringReplace(result, "\\", "\\\\");
   StringReplace(result, "\"", "\\\"");
   StringReplace(result, "\n", "\\n");
   StringReplace(result, "\r", "\\r");
   StringReplace(result, "\t", "\\t");
   return result;
}

//+------------------------------------------------------------------+
//| Helper: Convert double to JSON string                            |
//+------------------------------------------------------------------+
string CJSONTradeExporter::DoubleToJSON(double value, int digits)
{
   return DoubleToString(value, digits);
}

//+------------------------------------------------------------------+
//| Helper: Convert int to JSON string                               |
//+------------------------------------------------------------------+
string CJSONTradeExporter::IntToJSON(int value)
{
   return IntegerToString(value);
}

//+------------------------------------------------------------------+
//| Helper: Convert bool to JSON string                              |
//+------------------------------------------------------------------+
string CJSONTradeExporter::BoolToJSON(bool value)
{
   return value ? "true" : "false";
}

//+------------------------------------------------------------------+
//| Helper: Convert datetime to JSON string                          |
//+------------------------------------------------------------------+
string CJSONTradeExporter::DateTimeToJSON(datetime dt)
{
   return TimeToString(dt, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
}

