# TREVOR SCALPER FX

TREVOR SCALPER FX is a demo-first MT5 Expert Advisor project with a companion web dashboard.

## Components

- `TREVOR_SCALPER_FX_MT5.mq5`: MetaTrader 5 Expert Advisor source. It can submit market BUY/SELL orders through the connected MT5 terminal when attached to a chart and trading is permitted.
- `index.html`: TREVOR SCALPER FX web dashboard and MT5 installation guide.
- `auto-trader.js`: browser-only paper-trading simulator. It does not connect to a broker and never sends orders.
- FR3DDY AI interface and account UI are separate from the MT5 execution engine.

## MT5 installation

1. Download `TREVOR_SCALPER_FX_MT5.mq5`.
2. In MetaTrader 5, choose **File → Open Data Folder**.
3. Open `MQL5/Experts` and copy the EA source there.
4. Open MetaEditor, compile the EA, then return to MT5.
5. Attach it to a chart for each symbol you intend to test.
6. Start with a broker demo account and use Strategy Tester before any live use.

The EA uses closed-bar EMA 9/21 trend, RSI and MACD momentum conditions, ATR-based stop distances, a 1:2 reward/risk target, position sizing via OrderCalcProfit, a spread filter, a maximum-position limit and a daily loss lock.

## Demo and live safety

- Demo/test accounts are the default.
- Real-account trading is blocked by default.
- Live mode requires both `InpAllowLiveTrading=true` and the exact confirmation phrase `I ACCEPT LIVE RISK` in EA inputs.
- Do not activate live trading until the source has been compiled, reviewed, backtested and forward-tested on a demo account with your broker.
- Automated trading can lose money. No profit or win rate is guaranteed.

## Important implementation limits

- The EA source is an initial build and has not yet been compiled in MetaEditor or verified against any broker.
- Test symbol suffixes, contract specifications, minimum stop distances, filling policies, spreads, commissions, swaps, slippage, market gaps and execution rejections.
- The EA's daily equity baseline is initialised when it starts and resets on the next broker-server day; restarting it intraday resets that baseline. Keep this limitation in mind during testing.
- The web dashboard is not yet connected to MT5. It cannot start/stop the EA or display broker account data. The EA must be managed in the MT5 terminal.
- The web simulator is virtual-only and is not evidence of live strategy performance.

## Web dashboard

Open the GitHub Pages site configured for this repository. The dashboard contains the TREVOR identity, FR3DDY interface, paper simulator and MT5 installation guidance.
