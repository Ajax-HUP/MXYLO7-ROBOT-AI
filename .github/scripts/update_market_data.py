import json
import os
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone

api_key = os.environ.get("TWELVE_DATA_API_KEY")
if not api_key:
    raise SystemExit("Missing TWELVE_DATA_API_KEY repository secret")

symbols = ["EUR/USD", "GBP/USD", "USD/JPY", "USD/CHF", "AUD/USD", "USD/CAD", "NZD/USD"]
quotes = []

for symbol in symbols:
    params = urllib.parse.urlencode({"symbol": symbol, "apikey": api_key})
    url = "https://api.twelvedata.com/quote?" + params
    request = urllib.request.Request(url, headers={"User-Agent": "MXYLO7-Robot-AI/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            payload = json.loads(response.read().decode("utf-8"))
        if payload.get("status") == "error" or "close" not in payload:
            raise RuntimeError(payload.get("message", "Provider returned no quote"))
        quotes.append({
            "symbol": symbol,
            "price": float(payload["close"]),
            "provider_time": payload.get("datetime"),
            "status": "Latest provider quote"
        })
    except Exception as exc:
        print(f"Quote failed for {symbol}: {exc}")
    time.sleep(8)

if not quotes:
    raise SystemExit("No market quotes were returned; keeping the previous published file.")

output = {
    "source": "Twelve Data",
    "updated_at": datetime.now(timezone.utc).isoformat(),
    "quotes": quotes,
    "notice": "Read-only quotes. Provider update frequency and delays depend on the data plan."
}
os.makedirs("data", exist_ok=True)
with open("data/market.json", "w", encoding="utf-8") as file:
    json.dump(output, file, indent=2)
print(f"Wrote {len(quotes)} quotes.")
