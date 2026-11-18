# MXYLO7 ROBOT AI

Starter build 0.1.0 — mobile-friendly educational forex analysis simulator.

## Run
Open the repository's GitHub Pages site after enabling Pages in Settings → Pages (deploy from the main branch, root folder). You can also open `index.html` locally in a browser.

## Included
- Dashboard, sample signal board, sample scanner, FR3DDY AI educational Q&A, settings.
- Midnight Navy / Deep Blue / Electric Cyan / White / small red accent.
- Responsive layout and basic offline caching when hosted over HTTPS.

## Important limitations
- All displayed signal labels and scores are fictional sample data.
- No live prices, AI API, authentication, broker connection, MT5 integration, payments, licensing, or push notifications are implemented.
- No real-money order execution or automated trading is included.
- This is an educational interface prototype, not financial advice.


## Balanced auto-trader simulator
- Open the **Auto Bot** tab inside the dashboard to run the balanced scalping paper-trading prototype.
- Virtual risk controls: 0.5% risk per trade, 1:2 risk/reward, maximum 3 concurrent positions, and a 2% daily loss lock including open P/L.
- The rule set studies rolling EMA, RSI, MACD and ATR approximations from periodic quote snapshots.
- The current market endpoint provides periodic spot quotes, not historical M5/M15 OHLC candles, bid/ask spreads or execution-quality data. Indicator output is therefore a prototype for software testing, not a validated trading strategy.
- All positions and results are in-memory browser simulation only. No broker connection, real orders, or guaranteed returns.
