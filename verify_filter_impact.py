import json
from datetime import datetime

# Load the trading data
with open('20250101_000000_H1_XAUUSD_TradeSignals.json', 'r') as f:
    json_data = json.load(f)

# Extract trades array
trades = json_data.get('trades', [])

print("=" * 80)
print("EXTREME MARKET CONDITIONS FILTER - VERIFICATION ANALYSIS")
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

STRATEGY_NAMES = {v: k for k, v in STRATEGY_MAP.items()}

def check_extreme_conditions(trade, is_buy):
    """Check if trade meets extreme market conditions"""
    market_context = trade.get('market_context', {})
    rsi = market_context.get('rsi_value', 50)
    adx = market_context.get('adx_value', 25)
    macd = market_context.get('macd_value', 0)
    
    rsi_extreme = False
    adx_extreme = False
    macd_extreme = False
    
    # RSI extreme zones
    if is_buy and rsi > 65:
        rsi_extreme = True
    elif not is_buy and rsi < 35:
        rsi_extreme = True
    
    # ADX extreme zone
    if adx > 45:
        adx_extreme = True
    
    # MACD extreme zones
    if macd > 15 or macd < -15:
        macd_extreme = True
    
    return rsi_extreme or adx_extreme or macd_extreme, rsi_extreme, adx_extreme, macd_extreme

def check_strategy_votes(trade):
    """Check which strategies voted and if additional confirmation exists"""
    strategy_votes = trade.get('strategy_votes', [])

    # Count votes by strategy
    votes = {i: 0 for i in range(7)}
    for strategy in strategy_votes:
        name = strategy.get('strategy', '')
        vote_str = strategy.get('vote', 'NONE')
        vote_count = strategy.get('vote_count', 0)

        # Map strategy name to index
        if name in STRATEGY_MAP:
            idx = STRATEGY_MAP[name]
            # Convert vote string to number (BUY=1, SELL=-1, NONE=0)
            if vote_str == 'BUY':
                votes[idx] = vote_count
            elif vote_str == 'SELL':
                votes[idx] = -vote_count
    
    has_mtf = votes[6] != 0
    has_pa = votes[2] != 0
    has_indicators = votes[3] != 0
    has_sr = votes[4] != 0
    has_volume = votes[5] != 0
    
    strategies_voting = sum(1 for v in votes.values() if v != 0)
    has_additional_confirmation = has_indicators or has_sr or has_volume
    
    return has_mtf, has_pa, has_additional_confirmation, strategies_voting, votes

# Analyze all trades
total_trades = len(trades)
total_losses = sum(1 for t in trades if t.get('trade_metadata', {}).get('profit_usd', 0) < 0)
total_loss_amount = sum(t.get('trade_metadata', {}).get('profit_usd', 0) for t in trades if t.get('trade_metadata', {}).get('profit_usd', 0) < 0)

# Filter analysis
would_be_filtered = []
filtered_losses = []
filtered_wins = []

for trade in trades:
    metadata = trade.get('trade_metadata', {})
    direction = metadata.get('direction', '')
    is_buy = direction == 'LONG'
    profit = metadata.get('profit_usd', 0)
    
    # Check extreme conditions
    has_extreme, rsi_ext, adx_ext, macd_ext = check_extreme_conditions(trade, is_buy)
    
    if not has_extreme:
        continue
    
    # Check strategy votes
    has_mtf, has_pa, has_additional, strategies_voting, votes = check_strategy_votes(trade)
    
    # Would this trade be filtered?
    # Filter if: extreme conditions AND only MTF+PA voting AND no additional confirmation
    if strategies_voting <= 2 and has_mtf and has_pa and not has_additional:
        would_be_filtered.append(trade)
        if profit < 0:
            filtered_losses.append({
                'trade': trade,
                'rsi_extreme': rsi_ext,
                'adx_extreme': adx_ext,
                'macd_extreme': macd_ext,
                'votes': votes
            })
        else:
            filtered_wins.append({
                'trade': trade,
                'rsi_extreme': rsi_ext,
                'adx_extreme': adx_ext,
                'macd_extreme': macd_ext,
                'votes': votes
            })

# Calculate impact
filtered_loss_count = len(filtered_losses)
filtered_win_count = len(filtered_wins)
filtered_loss_amount = sum(t['trade'].get('trade_metadata', {}).get('profit_usd', 0) for t in filtered_losses)
filtered_win_amount = sum(t['trade'].get('trade_metadata', {}).get('profit_usd', 0) for t in filtered_wins)
net_impact = filtered_loss_amount + filtered_win_amount

print(f"📊 OVERALL STATISTICS")
print(f"{'─' * 80}")
print(f"Total Trades:                {total_trades:,}")
print(f"Total Losses:                {total_losses:,} ({total_losses/total_trades*100:.1f}%)")
print(f"Total Loss Amount:           ${total_loss_amount:,.2f}")
print()

print(f"🎯 FILTER IMPACT ANALYSIS")
print(f"{'─' * 80}")
print(f"Trades That Would Be Filtered:  {len(would_be_filtered):,} ({len(would_be_filtered)/total_trades*100:.1f}% of all trades)")
print()
print(f"  Filtered Losses:              {filtered_loss_count:,}")
print(f"  Filtered Loss Amount:         ${filtered_loss_amount:,.2f}")
print(f"  Average Filtered Loss:        ${filtered_loss_amount/filtered_loss_count if filtered_loss_count > 0 else 0:,.2f}")
print()
print(f"  Filtered Wins:                {filtered_win_count:,}")
print(f"  Filtered Win Amount:          ${filtered_win_amount:,.2f}")
print(f"  Average Filtered Win:         ${filtered_win_amount/filtered_win_count if filtered_win_count > 0 else 0:,.2f}")
print()
print(f"  NET IMPACT:                   ${net_impact:,.2f}")
print(f"  {'✅ POSITIVE' if net_impact > 0 else '❌ NEGATIVE'} (Filtering {'saves' if net_impact > 0 else 'costs'} money)")
print()

# Percentage of losses prevented
if total_losses > 0:
    loss_prevention_rate = (filtered_loss_count / total_losses) * 100
    amount_prevention_rate = (abs(filtered_loss_amount) / abs(total_loss_amount)) * 100
    print(f"📉 LOSS PREVENTION")
    print(f"{'─' * 80}")
    print(f"Losses Prevented:             {filtered_loss_count}/{total_losses} ({loss_prevention_rate:.1f}%)")
    print(f"Loss Amount Prevented:        ${abs(filtered_loss_amount):,.2f} / ${abs(total_loss_amount):,.2f} ({amount_prevention_rate:.1f}%)")
    print()

# Breakdown by extreme condition type
print(f"🔍 FILTERED LOSSES BY EXTREME CONDITION TYPE")
print(f"{'─' * 80}")

rsi_extreme_losses = [t for t in filtered_losses if t['rsi_extreme']]
adx_extreme_losses = [t for t in filtered_losses if t['adx_extreme']]
macd_extreme_losses = [t for t in filtered_losses if t['macd_extreme']]

print(f"RSI Extreme:                  {len(rsi_extreme_losses):,} losses, ${sum(t['trade'].get('trade_metadata', {}).get('profit_usd', 0) for t in rsi_extreme_losses):,.2f}")
print(f"ADX Extreme:                  {len(adx_extreme_losses):,} losses, ${sum(t['trade'].get('trade_metadata', {}).get('profit_usd', 0) for t in adx_extreme_losses):,.2f}")
print(f"MACD Extreme:                 {len(macd_extreme_losses):,} losses, ${sum(t['trade'].get('trade_metadata', {}).get('profit_usd', 0) for t in macd_extreme_losses):,.2f}")
print()

# Show some examples
print(f"📋 SAMPLE FILTERED LOSING TRADES (First 10)")
print(f"{'─' * 80}")
for i, item in enumerate(filtered_losses[:10], 1):
    trade = item['trade']
    metadata = trade.get('trade_metadata', {})
    market_context = trade.get('market_context', {})

    print(f"\n{i}. {metadata.get('direction', 'N/A')} - Profit: ${metadata.get('profit_usd', 0):.2f}")
    print(f"   Entry: {metadata.get('entry_time', 'N/A')}")
    print(f"   RSI: {market_context.get('rsi_value', 0):.2f} {'[EXTREME]' if item['rsi_extreme'] else ''}")
    print(f"   ADX: {market_context.get('adx_value', 0):.2f} {'[EXTREME]' if item['adx_extreme'] else ''}")
    print(f"   MACD: {market_context.get('macd_value', 0):.2f} {'[EXTREME]' if item['macd_extreme'] else ''}")

    # Show which strategies voted
    voting_strategies = [STRATEGY_NAMES[idx] for idx, vote in item['votes'].items() if vote != 0]
    print(f"   Strategies: {', '.join(voting_strategies)}")

print()
print("=" * 80)
print("CONCLUSION")
print("=" * 80)
print()
if net_impact > 0:
    print(f"✅ The filter would have IMPROVED performance by ${net_impact:,.2f}")
    print(f"   - Prevented {filtered_loss_count} losing trades (${abs(filtered_loss_amount):,.2f})")
    print(f"   - Sacrificed {filtered_win_count} winning trades (${filtered_win_amount:,.2f})")
    print(f"   - Net benefit: ${net_impact:,.2f}")
    print()
    print(f"💡 This represents a {amount_prevention_rate:.1f}% reduction in total losses!")
else:
    print(f"⚠️ The filter would have REDUCED performance by ${abs(net_impact):,.2f}")
    print(f"   - The filtered wins (${filtered_win_amount:,.2f}) exceed filtered losses (${abs(filtered_loss_amount):,.2f})")
    print(f"   - Consider adjusting the extreme zone thresholds")

print()

