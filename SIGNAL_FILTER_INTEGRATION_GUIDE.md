# Signal Filtration System Integration Guide

## Overview

This guide explains how to integrate the comprehensive 6-gate signal filtration system (`SignalFilterSystem.mqh`) into the GoldTraderEA codebase.

## Architecture

The signal filtration system implements a **sequential veto-based architecture** where signals must pass through 6 gates in order:

1. **Gate 1: Regime Filter** - Validates signal type matches market regime (trending vs ranging)
2. **Gate 2: Volume Profile Context** - Validates entry location relative to VP levels
3. **Gate 3: Inter-Market Context** - Validates DXY and real yields alignment
4. **Gate 4: Confluence Filter** - Requires confirmation from different indicator category
5. **Gate 5: Advanced Qualification** - Adds quality score (does NOT veto)
6. **Gate 6: Temporal Filter** - Validates trading session and news calendar

**Critical**: If ANY gate (1-4, 6) returns FALSE, the signal is **immediately rejected**. Gate 5 only adds a quality score.

## Integration Steps

### Step 1: Add Include Statement

In `GoldTraderEA.mq5`, add the include after other strategy includes:

```mql5
#include "SignalFilterSystem.mqh"
```

### Step 2: Declare Global Filter Instance

Add after other global variables (around line 250):

```mql5
// Signal filtration system
CSignalFilter g_signal_filter;
```

### Step 3: Initialize Filter in OnInit()

Add in the `OnInit()` function after indicator initialization (around line 440):

```mql5
// Initialize signal filtration system
if(!g_signal_filter.Initialize())
{
   Print("ERROR: Failed to initialize Signal Filtration System");
   return INIT_FAILED;
}
```

### Step 4: Deinitialize Filter in OnDeinit()

Add in the `OnDeinit()` function:

```mql5
// Cleanup signal filter
g_signal_filter.Deinitialize();
```

### Step 5: Integrate Filter into Signal Processing

**CRITICAL INTEGRATION POINT**: In the `OnTick()` function, BEFORE opening positions, add the filtration check.

Find the section where buy/sell confirmations are checked (around lines 1033-1078):

**BEFORE:**
```mql5
// Buy signal
if(buy_confirmations >= Min_Confirmations && !have_buy_position && potential_buy) {
    // Check main trend (if enabled)
    if(!Use_Main_Trend_Filter || current_close > ma_main_trend_value) {
        if(G_Debug) DebugPrint("Buy conditions confirmed. Attempting to open buy position...");
        bool result = SafeOpenBuyPosition();
        // ...
    }
}
```

**AFTER:**
```mql5
// Buy signal
if(buy_confirmations >= Min_Confirmations && !have_buy_position && potential_buy) {
    // Check main trend (if enabled)
    if(!Use_Main_Trend_Filter || current_close > ma_main_trend_value) {
        
        // === APPLY SIGNAL FILTRATION SYSTEM ===
        CSignalData signal = CreateSignalData(SIGNAL_LONG, "MultiStrategy", current_close);
        
        // Populate signal with current indicator values
        signal.adx_value = adx[0];
        signal.bb_upper = bb_upper[0];
        signal.bb_middle = bb_middle[0];
        signal.bb_lower = bb_lower[0];
        signal.rsi_value = rsi[0];
        signal.macd_value = macd[0];
        signal.stoch_value = stoch_k[0];
        
        CFilterResult filter_result;
        if(!g_signal_filter.ValidateSignal(signal, filter_result))
        {
            if(G_Debug) DebugPrint("Buy signal REJECTED by filter: " + filter_result.failure_reason);
            return; // Exit without opening position
        }
        
        if(G_Debug) DebugPrint("Buy signal PASSED all filters. Quality Score: " + 
                               DoubleToString(filter_result.quality_score, 1));
        // === END FILTRATION ===
        
        if(G_Debug) DebugPrint("Buy conditions confirmed. Attempting to open buy position...");
        bool result = SafeOpenBuyPosition();
        // ...
    }
}
```

Apply the same pattern for SELL signals (around line 1058):

```mql5
// Sell signal
if(sell_confirmations >= Min_Confirmations && !have_sell_position && potential_sell) {
    if(!Use_Main_Trend_Filter || current_close < ma_main_trend_value) {
        
        // === APPLY SIGNAL FILTRATION SYSTEM ===
        CSignalData signal = CreateSignalData(SIGNAL_SHORT, "MultiStrategy", current_close);
        
        // Populate signal with current indicator values
        signal.adx_value = adx[0];
        signal.bb_upper = bb_upper[0];
        signal.bb_middle = bb_middle[0];
        signal.bb_lower = bb_lower[0];
        signal.rsi_value = rsi[0];
        signal.macd_value = macd[0];
        signal.stoch_value = stoch_k[0];
        
        CFilterResult filter_result;
        if(!g_signal_filter.ValidateSignal(signal, filter_result))
        {
            if(G_Debug) DebugPrint("Sell signal REJECTED by filter: " + filter_result.failure_reason);
            return; // Exit without opening position
        }
        
        if(G_Debug) DebugPrint("Sell signal PASSED all filters. Quality Score: " + 
                               DoubleToString(filter_result.quality_score, 1));
        // === END FILTRATION ===
        
        if(G_Debug) DebugPrint("Sell conditions confirmed. Attempting to open sell position...");
        bool result = SafeOpenSellPosition();
        // ...
    }
}
```

## Configuration Parameters

All filter parameters are configurable via input variables in `SignalFilterSystem.mqh`:

### Gate Enable/Disable
- `SF_Enable_Gate1_Regime` - Enable/disable Regime Filter (default: true)
- `SF_Enable_Gate2_VolumeProfile` - Enable/disable Volume Profile Filter (default: true)
- `SF_Enable_Gate3_InterMarket` - Enable/disable Inter-Market Filter (default: true)
- `SF_Enable_Gate4_Confluence` - Enable/disable Confluence Filter (default: true)
- `SF_Enable_Gate5_Advanced` - Enable/disable Advanced Qualification (default: true)
- `SF_Enable_Gate6_Temporal` - Enable/disable Temporal Filter (default: true)

### Gate-Specific Parameters

**Gate 1 (Regime):**
- `SF_ADX_Trend_Threshold` = 25.0 - ADX threshold for trend/range detection
- `SF_BB_Expansion_Threshold` = 1.2 - BB expansion ratio threshold

**Gate 2 (Volume Profile):**
- `SF_VP_Near_Distance_Pct` = 0.1 - "At/near" distance percentage (0.1%)
- `SF_VP_Block_Distance_Pct` = 0.2 - "Directly below/above" distance (0.2%)
- `SF_VP_Lookback_Bars` = 500 - Lookback period for VP calculation

**Gate 3 (Inter-Market):**
- `SF_DXY_Symbol` = "USDX" - DXY symbol name (adjust for your broker)
- `SF_DXY_Trend_Period` = 20 - Period for DXY trend detection
- `SF_DXY_SR_Tolerance` = 0.3 - DXY S/R tolerance percentage

**Gate 4 (Confluence):**
- `SF_Confluence_Min_Confirmations` = 1 - Minimum confirmations from different category

**Gate 6 (Temporal):**
- `SF_News_Lookforward_Hours` = 2 - Hours to look forward for news events
- `SF_Allow_Asian_Session` = false - Allow trading in Asian session

## Strategy Category Mapping

The system automatically categorizes strategies:

- **TREND**: MA Crossover, MACD, Breakout, Trend Patterns
- **MOMENTUM**: RSI, Stochastic, CCI
- **VOLATILITY**: Bollinger Bands
- **VOLUME**: Volume Analysis, Volume Profile
- **PATTERN**: Harmonic Patterns, Elliott Waves, Chart Patterns
- **SUPPORT_RESISTANCE**: S/R Levels, Pivot Points

## Testing Recommendations

1. **Initial Testing**: Disable all gates except Gate 1 to verify basic integration
2. **Progressive Enablement**: Enable one gate at a time and monitor rejection rates
3. **Parameter Tuning**: Adjust thresholds based on backtest results
4. **DXY Symbol**: Verify your broker's DXY symbol name (may be "USDX", "DXY", "US30", etc.)

## Expected Behavior

- **High Rejection Rate Initially**: Expect 60-80% of signals to be rejected initially
- **Quality Over Quantity**: The system prioritizes high-quality signals over signal frequency
- **Logging**: All rejections are logged with specific gate and reason
- **Quality Scores**: Gate 5 adds scores from 50-100 based on divergence and harmonic patterns

## Troubleshooting

### Issue: All signals rejected at Gate 3
**Solution**: Check DXY symbol name. If DXY not available, disable Gate 3.

### Issue: All signals rejected at Gate 2
**Solution**: Increase `SF_VP_Near_Distance_Pct` to 0.2% or 0.3% for more tolerance.

### Issue: No signals passing Gate 1
**Solution**: Check if `SF_ADX_Trend_Threshold` is too restrictive. Try 20.0 instead of 25.0.

### Issue: Volume Profile not updating
**Solution**: Ensure sufficient historical data. Reduce `SF_VP_Lookback_Bars` to 300.

## Performance Considerations

- Volume Profile calculation is cached for 1 hour to minimize CPU usage
- All gates use early exit (fail-fast) to minimize processing time
- Indicator handles are reused across calls for efficiency

## Future Enhancements

1. **Real Yields Integration**: Add real yields data feed for Gate 3
2. **Full Divergence Detection**: Implement complete divergence analysis for Gate 5
3. **Harmonic Pattern PRZ**: Implement full harmonic pattern detection for Gate 5
4. **Economic Calendar API**: Integrate real-time economic calendar for Gate 6
5. **Machine Learning**: Add ML-based quality scoring in Gate 5

## Support

For issues or questions, refer to the inline code comments in `SignalFilterSystem.mqh`.

