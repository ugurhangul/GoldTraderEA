import json

# Load the trading data
with open('20250101_000000_H1_XAUUSD_TradeSignals.json', 'r') as f:
    json_data = json.load(f)

trades = json_data.get('trades', [])

print("=" * 80)
print("EXTREME CONDITIONS & STRATEGY COMBINATIONS ANALYSIS")
print("=" * 80)
print()

# Strategy name mapping
STRATEGY_MAP = {
    "CandlePatterns": 0,
    "ChartPatterns": 1,
    "PriceAction": 2,
    "Indicators": 3,
    "SupportResistance": 4,
    "VolumeAnalysis": 5,
    "MultiTimeframe": 6
}

# Analyze extreme conditions
extreme_rsi_long = []
extreme_rsi_short = []
extreme_adx = []
extreme_macd = []
mtf_pa_only = []
mtf_pa_with_extreme = []

for trade in trades:
    metadata = trade.get('trade_metadata', {})
    market_context = trade.get('market_context', {})
    strategy_votes = trade.get('strategy_votes', [])
    
    direction = metadata.get('direction', '')
    is_buy = direction == 'LONG'
    profit = metadata.get('profit_usd', 0)
    
    rsi = market_context.get('rsi_value', 50)
    adx = market_context.get('adx_value', 25)
    macd = market_context.get('macd_value', 0)
    
    # Get voting strategies
    voting_strategies = set()
    for strat in strategy_votes:
        name = strat.get('strategy', '')
        vote = strat.get('vote', 'NONE')
        if vote != 'NONE':
            voting_strategies.add(name)
    
    has_mtf = 'MultiTimeframe' in voting_strategies
    has_pa = 'PriceAction' in voting_strategies
    has_indicators = 'Indicators' in voting_strategies
    has_sr = 'SupportResistance' in voting_strategies
    has_volume = 'VolumeAnalysis' in voting_strategies
    
    # Check extreme conditions
    rsi_extreme = (is_buy and rsi > 65) or (not is_buy and rsi < 35)
    adx_extreme = adx > 45
    macd_extreme = macd > 15 or macd < -15
    
    any_extreme = rsi_extreme or adx_extreme or macd_extreme
    
    # Track extreme conditions
    if is_buy and rsi > 65:
        extreme_rsi_long.append({
            'profit': profit,
            'rsi': rsi,
            'strategies': list(voting_strategies),
            'has_additional': has_indicators or has_sr or has_volume
        })
    
    if not is_buy and rsi < 35:
        extreme_rsi_short.append({
            'profit': profit,
            'rsi': rsi,
            'strategies': list(voting_strategies),
            'has_additional': has_indicators or has_sr or has_volume
        })
    
    if adx > 45:
        extreme_adx.append({
            'profit': profit,
            'adx': adx,
            'strategies': list(voting_strategies),
            'has_additional': has_indicators or has_sr or has_volume
        })
    
    if macd > 15 or macd < -15:
        extreme_macd.append({
            'profit': profit,
            'macd': macd,
            'strategies': list(voting_strategies),
            'has_additional': has_indicators or has_sr or has_volume
        })
    
    # Track MTF+PA only combinations
    if has_mtf and has_pa and len(voting_strategies) == 2:
        mtf_pa_only.append({
            'profit': profit,
            'rsi': rsi,
            'adx': adx,
            'macd': macd,
            'direction': direction,
            'has_extreme': any_extreme
        })
        
        if any_extreme:
            mtf_pa_with_extreme.append({
                'profit': profit,
                'rsi': rsi,
                'adx': adx,
                'macd': macd,
                'direction': direction,
                'rsi_extreme': rsi_extreme,
                'adx_extreme': adx_extreme,
                'macd_extreme': macd_extreme
            })

print(f"📊 EXTREME CONDITIONS FREQUENCY")
print(f"{'─' * 80}")
print(f"Total Trades:                     {len(trades):,}")
print()
print(f"RSI > 65 (LONG):                  {len(extreme_rsi_long):,} trades")
if extreme_rsi_long:
    losses = [t for t in extreme_rsi_long if t['profit'] < 0]
    with_additional = [t for t in extreme_rsi_long if t['has_additional']]
    print(f"  Losses:                         {len(losses):,} (${sum(t['profit'] for t in losses):,.2f})")
    print(f"  With additional confirmation:   {len(with_additional):,} ({len(with_additional)/len(extreme_rsi_long)*100:.1f}%)")
print()

print(f"RSI < 35 (SHORT):                 {len(extreme_rsi_short):,} trades")
if extreme_rsi_short:
    losses = [t for t in extreme_rsi_short if t['profit'] < 0]
    with_additional = [t for t in extreme_rsi_short if t['has_additional']]
    print(f"  Losses:                         {len(losses):,} (${sum(t['profit'] for t in losses):,.2f})")
    print(f"  With additional confirmation:   {len(with_additional):,} ({len(with_additional)/len(extreme_rsi_short)*100:.1f}%)")
print()

print(f"ADX > 45:                         {len(extreme_adx):,} trades")
if extreme_adx:
    losses = [t for t in extreme_adx if t['profit'] < 0]
    with_additional = [t for t in extreme_adx if t['has_additional']]
    print(f"  Losses:                         {len(losses):,} (${sum(t['profit'] for t in losses):,.2f})")
    print(f"  With additional confirmation:   {len(with_additional):,} ({len(with_additional)/len(extreme_adx)*100:.1f}%)")
print()

print(f"MACD > 15 or < -15:               {len(extreme_macd):,} trades")
if extreme_macd:
    losses = [t for t in extreme_macd if t['profit'] < 0]
    with_additional = [t for t in extreme_macd if t['has_additional']]
    print(f"  Losses:                         {len(losses):,} (${sum(t['profit'] for t in losses):,.2f})")
    print(f"  With additional confirmation:   {len(with_additional):,} ({len(with_additional)/len(extreme_macd)*100:.1f}%)")
print()

print(f"🎯 MTF + PA ONLY COMBINATIONS")
print(f"{'─' * 80}")
print(f"Total MTF+PA only trades:         {len(mtf_pa_only):,}")
if mtf_pa_only:
    losses = [t for t in mtf_pa_only if t['profit'] < 0]
    with_extreme = [t for t in mtf_pa_only if t['has_extreme']]
    print(f"  Losses:                         {len(losses):,} (${sum(t['profit'] for t in losses):,.2f})")
    print(f"  With extreme conditions:        {len(with_extreme):,} ({len(with_extreme)/len(mtf_pa_only)*100:.1f}%)")
print()

print(f"MTF+PA only WITH extreme:         {len(mtf_pa_with_extreme):,}")
if mtf_pa_with_extreme:
    losses = [t for t in mtf_pa_with_extreme if t['profit'] < 0]
    print(f"  Losses:                         {len(losses):,} (${sum(t['profit'] for t in losses):,.2f})")
    print(f"  Average loss:                   ${sum(t['profit'] for t in losses)/len(losses) if losses else 0:,.2f}")
    print()
    print(f"  Breakdown by extreme type:")
    rsi_ext = [t for t in mtf_pa_with_extreme if t['rsi_extreme']]
    adx_ext = [t for t in mtf_pa_with_extreme if t['adx_extreme']]
    macd_ext = [t for t in mtf_pa_with_extreme if t['macd_extreme']]
    print(f"    RSI extreme:                  {len(rsi_ext):,}")
    print(f"    ADX extreme:                  {len(adx_ext):,}")
    print(f"    MACD extreme:                 {len(macd_ext):,}")
    
    # Show some examples
    print()
    print(f"  Sample trades (first 5):")
    for i, t in enumerate(mtf_pa_with_extreme[:5], 1):
        print(f"    {i}. {t['direction']} - Profit: ${t['profit']:.2f}")
        print(f"       RSI: {t['rsi']:.2f} {'[EXTREME]' if t['rsi_extreme'] else ''}")
        print(f"       ADX: {t['adx']:.2f} {'[EXTREME]' if t['adx_extreme'] else ''}")
        print(f"       MACD: {t['macd']:.2f} {'[EXTREME]' if t['macd_extreme'] else ''}")

print()
print("=" * 80)
print("CONCLUSION")
print("=" * 80)
print()

if len(mtf_pa_with_extreme) == 0:
    print("✅ NO TRADES found with MTF+PA only during extreme conditions!")
    print()
    print("This means:")
    print("  1. When extreme conditions occurred, other strategies also voted")
    print("  2. OR MTF+PA didn't both vote during extreme conditions")
    print("  3. The filter is correctly designed but may not trigger often in this dataset")
    print()
    print("The filter will still provide protection for future trades that meet these conditions.")
else:
    print(f"⚠️ Found {len(mtf_pa_with_extreme)} trades with MTF+PA only during extreme conditions")
    losses = [t for t in mtf_pa_with_extreme if t['profit'] < 0]
    if losses:
        print(f"   These resulted in {len(losses)} losses totaling ${sum(t['profit'] for t in losses):,.2f}")
        print(f"   The filter would have prevented these losses!")

print()

