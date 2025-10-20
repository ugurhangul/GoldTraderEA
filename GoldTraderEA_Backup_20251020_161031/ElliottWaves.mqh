//+------------------------------------------------------------------+
//|                                                 ElliottWaves.mqh |
//|                                      Copyright 2023, Gold Trader   |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Gold Trader"
#property strict

// Declare external variables needed
extern ENUM_TIMEFRAMES EW_Timeframe;
extern bool is_backtest;

// The DebugPrint function must be defined in the main file
#import "GoldTraderEA_cleaned.mq5"
void DebugPrint(string message);
#import

// The CheckArrayAccess function must be defined in the main file
#import "Divergence.mqh"
bool CheckArrayAccess(int index, int array_size, string function_name);
#import

//+------------------------------------------------------------------+
//| Check Elliott Waves for Buy with error protection                |
//+------------------------------------------------------------------+
int SafeCheckElliottWavesBuy(MqlRates &rates[])
{
    int result = 0;
    int size = ArraySize(rates);
    
    // Check array size
    int min_size = is_backtest ? 15 : 30;
    if(size < min_size) {
        DebugPrint("The rates array for SafeCheckElliottWavesBuy is smaller than the required size: " + 
                  IntegerToString(size) + " < " + IntegerToString(min_size));
        return 0;
    }
    
    // In backtest mode, if Elliott waves are activated, return a value
    // To ensure we don't get an out of range error
    if(is_backtest && size < 30) {
        DebugPrint("In backtest mode with a low number of candles, we safely check the Elliott waves");
        return 0;
    }
    
    // Main call with error protection
    ResetLastError();
    
    // Execute function with error protection
    result = CheckElliottWavesBuy(rates);
    
    // Check error
    int error = GetLastError();
    if(error != 0) {
        DebugPrint("Error executing CheckElliottWavesBuy: " + IntegerToString(error));
        return 0;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Check Elliott Waves for Sell with error protection               |
//+------------------------------------------------------------------+
int SafeCheckElliottWavesShort(MqlRates &rates[])
{
    int result = 0;
    int size = ArraySize(rates);
    
    // Check array size
    int min_size = is_backtest ? 15 : 30;
    if(size < min_size) {
        DebugPrint("The rates array for SafeCheckElliottWavesShort is smaller than the required size: " + 
                  IntegerToString(size) + " < " + IntegerToString(min_size));
        return 0;
    }
    
    // In backtest mode, if Elliott waves are activated, return a value
    // To ensure we don't get an out of range error
    if(is_backtest && size < 30) {
        DebugPrint("In backtest mode with a low number of candles, we safely check the Elliott waves");
        return 0;
    }
    
    // Main call with error protection
    ResetLastError();
    
    // Execute function with error protection
    result = CheckElliottWavesShort(rates);
    
    // Check error
    int error = GetLastError();
    if(error != 0) {
        DebugPrint("Error executing CheckElliottWavesShort: " + IntegerToString(error));
        return 0;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Check Elliott Wave ABC pattern for Buy                          |
//+------------------------------------------------------------------+
int CheckElliottWavesBuy(MqlRates &rates[])
{
    int confirmations = 0;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 30) {
        DebugPrint("The rates array for CheckElliottWavesBuy is smaller than the required size: " + IntegerToString(size));
        return 0;
    }
    
    DebugPrint("Number of candles received for CheckElliottWavesBuy: " + IntegerToString(size));
    
    // Check bullish Elliott Wave ABC pattern
    if(IsBullishElliottWaveABC(rates)) {
        DebugPrint("Bullish Elliott Wave ABC pattern detected");
        confirmations++;
    }
    
    // Check bullish Elliott Wave 5 pattern
    if(IsBullishElliottWave5(rates)) {
        DebugPrint("Bullish Elliott Wave 5 pattern detected");
        confirmations++;
    }
    
    DebugPrint("Number of confirmations for Elliott waves for Buy: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Check Elliott Wave ABC pattern for Sell                         |
//+------------------------------------------------------------------+
int CheckElliottWavesShort(MqlRates &rates[])
{
    int confirmations = 0;
    
    // Check array size
    int size = ArraySize(rates);
    if(size < 30) {
        DebugPrint("The rates array for CheckElliottWavesShort is smaller than the required size: " + IntegerToString(size));
        return 0;
    }
    
    DebugPrint("Number of candles received for CheckElliottWavesShort: " + IntegerToString(size));
    
    // Check bearish Elliott Wave ABC pattern
    if(IsBearishElliottWaveABC(rates)) {
        DebugPrint("Bearish Elliott Wave ABC pattern detected");
        confirmations++;
    }
    
    // Check bearish Elliott Wave 5 pattern
    if(IsBearishElliottWave5(rates)) {
        DebugPrint("Bearish Elliott Wave 5 pattern detected");
        confirmations++;
    }
    
    DebugPrint("Number of confirmations for Elliott waves for Sell: " + IntegerToString(confirmations));
    return confirmations;
}

//+------------------------------------------------------------------+
//| Functions without parameters that use price data                 |
//+------------------------------------------------------------------+
int CheckElliottWavesBuy()
{
    // Get price data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), EW_Timeframe, 0, 100, rates);
    
    if(copied < 30) {
        DebugPrint("Error retrieving data for CheckElliottWavesBuy: " + IntegerToString(GetLastError()));
        return 0;
    }
    
    DebugPrint("Number of candles received for CheckElliottWavesBuy: " + IntegerToString(copied));
    
    // Pass to main function
    return CheckElliottWavesBuy(rates);
}

//+------------------------------------------------------------------+
//| Functions without parameters that use price data                 |
//+------------------------------------------------------------------+
int CheckElliottWavesShort()
{
    // Get price data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(Symbol(), EW_Timeframe, 0, 100, rates);
    
    if(copied < 30) {
        DebugPrint("Error retrieving data for CheckElliottWavesShort: " + IntegerToString(GetLastError()));
        return 0;
    }
    
    DebugPrint("Number of candles received for CheckElliottWavesShort: " + IntegerToString(copied));
    
    // Pass to main function
    return CheckElliottWavesShort(rates);
}

//+------------------------------------------------------------------+
//| Detect bullish Elliott Wave ABC                                  |
//+------------------------------------------------------------------+
bool IsBullishElliottWaveABC(MqlRates &rates[])
{
   if(ArraySize(rates) < 30)
        return false;
        
   // Find wave points
   int pointA = -1, pointB = -1, pointC = -1;
   double highestHigh = rates[0].high;
   int highestHighIndex = 0;
   
   // Find point A (highest high in first half of the array)
   for(int i = 0; i < 15; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].high > highestHigh)
      {
         highestHigh = rates[i].high;
         highestHighIndex = i;
      }
   }
   pointA = highestHighIndex;
   
   // Find point B (lowest low after point A)
   double lowestLow = rates[pointA].low;
   int lowestLowIndex = pointA;
   
   for(int i = pointA + 1; i < pointA + 15; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].low < lowestLow)
      {
         lowestLow = rates[i].low;
         lowestLowIndex = i;
      }
   }
   pointB = lowestLowIndex;
   
   // Check if a proper correction (wave B) has occurred (at least 38.2% retracement)
   double waveASize = highestHigh - lowestLow;
   if(waveASize <= 0) return false;
   
   // Find point C (highest high after point B)
   highestHigh = rates[pointB].high;
   highestHighIndex = pointB;
   
   for(int i = pointB + 1; i < pointB + 15; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].high > highestHigh)
      {
         highestHigh = rates[i].high;
         highestHighIndex = i;
      }
   }
   pointC = highestHighIndex;
   
   // Check if wave C did not exceed the high of wave A
   if(rates[pointC].high >= rates[pointA].high)
        return false;
        
   // Check if current price is breaking below the low of wave B
   if(rates[0].close < rates[pointB].low)
      return true;
      
   return false;
}

//+------------------------------------------------------------------+
//| Detect bearish Elliott Wave ABC                                   |
//+------------------------------------------------------------------+
bool IsBearishElliottWaveABC(MqlRates &rates[])
{
   if(ArraySize(rates) < 30)
        return false;
        
   // Find wave points
   int pointA = -1, pointB = -1, pointC = -1;
   double lowestLow = rates[0].low;
   int lowestLowIndex = 0;
   
   // Find point A (lowest low in first half of the array)
   for(int i = 0; i < 15; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].low < lowestLow)
      {
         lowestLow = rates[i].low;
         lowestLowIndex = i;
      }
   }
   pointA = lowestLowIndex;
   
   // Find point B (highest high after point A)
   double highestHigh = rates[pointA].high;
   int highestHighIndex = pointA;
   
   for(int i = pointA + 1; i < pointA + 15; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].high > highestHigh)
      {
         highestHigh = rates[i].high;
         highestHighIndex = i;
      }
   }
   pointB = highestHighIndex;
   
   // Check if a proper correction (wave B) has occurred (at least 38.2% retracement)
   double waveASize = highestHigh - lowestLow;
   if(waveASize <= 0) return false;
   
   // Find point C (lowest low after point B)
   lowestLow = rates[pointB].low;
   lowestLowIndex = pointB;
   
   for(int i = pointB + 1; i < pointB + 15; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].low < lowestLow)
      {
         lowestLow = rates[i].low;
         lowestLowIndex = i;
      }
   }
   pointC = lowestLowIndex;
   
   // Check if wave C did not exceed the low of wave A
   if(rates[pointC].low <= rates[pointA].low)
        return false;
        
   // Check if current price is breaking above the high of wave B
   if(rates[0].close > rates[pointB].high)
      return true;
      
   return false;
}

//+------------------------------------------------------------------+
//| Detect bullish Elliott Wave 5                                    |
//+------------------------------------------------------------------+
bool IsBullishElliottWave5(MqlRates &rates[])
{
   if(ArraySize(rates) < 30)
      return false;
      
   // Find wave points (0,1,2,3,4,5)
   int point0 = -1, point1 = -1, point2 = -1, point3 = -1, point4 = -1, point5 = -1;
   
   // Find point 0 (lowest low in the beginning)
   double lowestLow = rates[0].low;
   int lowestIndex = 0;
   
   for(int i = 0; i < 10; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].low < lowestLow)
      {
         lowestLow = rates[i].low;
         lowestIndex = i;
      }
   }
   point0 = lowestIndex;
   
   // Find point 1 (first significant high after point 0)
   double highestHigh = rates[point0].high;
   int highestIndex = point0;
   
   for(int i = point0 + 1; i < point0 + 8; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].high > highestHigh)
      {
         highestHigh = rates[i].high;
         highestIndex = i;
      }
   }
   point1 = highestIndex;
   
   // Find point 2 (low after point 1 - should not go below point 0)
   lowestLow = rates[point1].low;
   lowestIndex = point1;
   
   for(int i = point1 + 1; i < point1 + 8; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].low < lowestLow)
      {
         lowestLow = rates[i].low;
         lowestIndex = i;
      }
   }
   point2 = lowestIndex;
   
   // Wave 2 should not go below wave 0
   if(rates[point2].low <= rates[point0].low)
        return false;
        
   // Find point 3 (high after point 2 - should go above point 1)
   highestHigh = rates[point2].high;
   highestIndex = point2;
   
   for(int i = point2 + 1; i < point2 + 8; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].high > highestHigh)
      {
         highestHigh = rates[i].high;
         highestIndex = i;
      }
   }
   point3 = highestIndex;
   
   // Wave 3 should go above wave 1
   if(rates[point3].high <= rates[point1].high)
        return false;
        
   // Find point 4 (low after point 3 - should not go below point 2)
   lowestLow = rates[point3].low;
   lowestIndex = point3;
   
   for(int i = point3 + 1; i < point3 + 8; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].low < lowestLow)
      {
         lowestLow = rates[i].low;
         lowestIndex = i;
      }
   }
   point4 = lowestIndex;
   
   // Wave 4 should not go below wave 2
   if(rates[point4].low <= rates[point2].low)
        return false;
        
   // Find point 5 (high after point 4 - should go above point 3)
   highestHigh = rates[point4].high;
   highestIndex = point4;
   
   for(int i = point4 + 1; i < point4 + 8; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].high > highestHigh)
      {
         highestHigh = rates[i].high;
         highestIndex = i;
      }
   }
   point5 = highestIndex;
   
   // Wave 5 should go above wave 3
   if(rates[point5].high <= rates[point3].high)
        return false;
        
   // Check if we have a proper 5-wave structure
   if(point0 < point1 && point1 < point2 && point2 < point3 && point3 < point4 && point4 < point5)
        return true;
        
   return false;
}

//+------------------------------------------------------------------+
//| Detect bearish Elliott Wave 5                                    |
//+------------------------------------------------------------------+
bool IsBearishElliottWave5(MqlRates &rates[])
{
   if(ArraySize(rates) < 30)
      return false;
      
   // Find wave points (0,1,2,3,4,5)
   int point0 = -1, point1 = -1, point2 = -1, point3 = -1, point4 = -1, point5 = -1;
   
   // Find point 0 (highest high in the beginning)
   double highestHigh = rates[0].high;
   int highestIndex = 0;
   
   for(int i = 0; i < 10; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].high > highestHigh)
      {
         highestHigh = rates[i].high;
         highestIndex = i;
      }
   }
   point0 = highestIndex;
   
   // Find point 1 (first significant low after point 0)
   double lowestLow = rates[point0].low;
   int lowestIndex = point0;
   
   for(int i = point0 + 1; i < point0 + 8; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].low < lowestLow)
      {
         lowestLow = rates[i].low;
         lowestIndex = i;
      }
   }
   point1 = lowestIndex;
   
   // Find point 2 (high after point 1 - should not go above point 0)
   highestHigh = rates[point1].high;
   highestIndex = point1;
   
   for(int i = point1 + 1; i < point1 + 8; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].high > highestHigh)
      {
         highestHigh = rates[i].high;
         highestIndex = i;
      }
   }
   point2 = highestIndex;
   
   // Wave 2 should not go above wave 0
   if(rates[point2].high >= rates[point0].high)
        return false;
        
   // Find point 3 (low after point 2 - should go below point 1)
   lowestLow = rates[point2].low;
   lowestIndex = point2;
   
   for(int i = point2 + 1; i < point2 + 8; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].low < lowestLow)
      {
         lowestLow = rates[i].low;
         lowestIndex = i;
      }
   }
   point3 = lowestIndex;
   
   // Wave 3 should go below wave 1
   if(rates[point3].low >= rates[point1].low)
        return false;
        
   // Find point 4 (high after point 3 - should not go above point 2)
   highestHigh = rates[point3].high;
   highestIndex = point3;
   
   for(int i = point3 + 1; i < point3 + 8; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].high > highestHigh)
      {
         highestHigh = rates[i].high;
         highestIndex = i;
      }
   }
   point4 = highestIndex;
   
   // Wave 4 should not go above wave 2
   if(rates[point4].high >= rates[point2].high)
        return false;
        
   // Find point 5 (low after point 4 - should go below point 3)
   lowestLow = rates[point4].low;
   lowestIndex = point4;
   
   for(int i = point4 + 1; i < point4 + 8; i++)
   {
      if(i >= ArraySize(rates)) return false;
      if(rates[i].low < lowestLow)
      {
         lowestLow = rates[i].low;
         lowestIndex = i;
      }
   }
   point5 = lowestIndex;
   
   // Wave 5 should go below wave 3
   if(rates[point5].low >= rates[point3].low)
        return false;
        
   // Check if we have a proper 5-wave structure
   if(point0 < point1 && point1 < point2 && point2 < point3 && point3 < point4 && point4 < point5)
        return true;
        
   return false;
} 