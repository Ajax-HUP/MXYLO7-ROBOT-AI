# TREVO SCALPER FX backend setup

This Worker serves public read-only quote data, Premium FR3DDY requests, and licence issuance/activation. It does not route live orders.

## Deploy

1. Run `supabase-premium.sql` in the Supabase SQL editor. This creates the Premium membership table and the Trevo licence/activation tables with RLS enabled and no browser policies.
2. Deploy `worker.js` to Cloudflare Workers.
3. Configure Worker variables/secrets:
   - `SUPABASE_URL` — Supabase project URL
   - `SUPABASE_ANON_KEY` — public Supabase anon/publishable key
   - `SUPABASE_SERVICE_ROLE_KEY` — secret, Worker-only
   - `TREVO_ADMIN_SECRET` — long random secret, Worker-only, used for licence issuance
   - `ALLOWED_ORIGIN=https://ajax-hup.github.io`
   - `TWELVE_DATA_API_KEY` — optional market-data secret
   - `OPENAI_API_KEY` — optional FR3DDY secret
   - `OPENAI_MODEL` — optional model override
4. In MT5 desktop, add the Worker domain under Tools → Options → Expert Advisors → Allow WebRequest for listed URL.
5. Compile `mt5/TREVO_SCALPER_FX.mq5` in MetaEditor. Attach it to a demo chart. Enter the customer licence key and keep `EnableTrading=false` for initial connection validation.
6. Run Strategy Tester and demo forward tests before enabling entries.

## Licence API

- Activate / validate: POST JSON `{ "action":"activate", "license_key":"TRV-....", "mt5_login":"12345678", "broker_server":"Broker-Demo" }`.
- Issue: POST JSON `{ "action":"issue", "admin_secret":"...", "valid_days":30, "max_accounts":1 }`.
- The issue response contains the one-time plaintext key. Store it securely and give it to the customer. The database stores only its SHA-256 hash.
- Licence activation binds a key to an MT5 login and exact broker server, subject to the activation limit. The EA rechecks the Worker periodically.

Do not call the issue endpoint from a public browser/admin page. Use a trusted administrator's secure environment. Never commit the admin secret or Supabase service-role key.

## Current limitations

- The EA currently refuses live/real accounts and is demo-only.
- The EA is an initial EMA/RSI/ATR framework, not a clone of Scalper X and not proven profitable.
- The website dashboard can activate licences but is not yet a live MT5 telemetry/control bridge.
- Licence validation requires Worker deployment, SQL migration, internet access and the MT5 WebRequest allow-list.
- No FP Markets commercial integration approval, backtest/forward-test report, production hardening, or regulatory review has been completed.
- No live trade execution should be enabled or advertised. Scalping carries substantial loss risk; execution quality, spreads, commission and slippage can change results.
