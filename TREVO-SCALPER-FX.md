# TREVO SCALPER FX

TREVO SCALPER FX is an original MetaTrader 5 Expert Advisor project. It is inspired by common automated-scalping product capabilities (automatic entries, TP/SL, trailing stops, risk controls and an on-chart control panel), not copied from Scalper X or any proprietary source.

## Current EA build: 0.1.0

- MT5 Expert Advisor source: `mt5/TREVO_SCALPER_FX.mq5`
- Original EMA(9/21) cross + RSI confirmation entry framework.
- ATR-based Stop Loss and Take Profit.
- ATR trailing stop.
- Risk-based volume calculation.
- Spread filter, broker-server trading hours, maximum position count.
- Daily equity-loss guard blocks new entries.
- On-chart status panel.
- **Demo-account-only gate.** Initial version refuses to initialise on a real/live account.
- **Auto trading is OFF by default** and requires the user to explicitly enable the EA input.

## Install and test

1. Install MetaTrader 5 desktop from your broker.
2. Open MetaEditor from MT5, then open `TREVO_SCALPER_FX.mq5`.
3. Compile and resolve any broker/build-specific warnings before use.
4. Attach to one demo-account chart at a time; use Strategy Tester first.
5. Review the broker's symbol contract size, tick values, minimum stop distance, spread and server time.
6. Keep `EnableTrading=false` during initial testing. Only enable on a demo account after reviewing the strategy and risk settings.
7. Use a VPS only after successful forward testing.

## Not implemented yet

- Secure online licence-key validation and admin issuance/revocation.
- Web/mobile dashboard command bridge and live account/position telemetry.
- Broker-specific FP Markets acceptance and account authorisation.
- News calendar filter, multi-symbol scanner orchestration, advanced trade management and hardened reconnect logic.
- Independent backtests, forward-test evidence, and production security review.

The EA does not guarantee profit. Scalping is sensitive to spread, slippage, execution latency, commission, market conditions and broker rules. This code is an initial demo-only engineering build, not a verified profitable system and not ready for customer or live-money deployment.
