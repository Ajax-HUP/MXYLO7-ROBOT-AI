const cors = (origin) => ({
  "Access-Control-Allow-Origin": origin,
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Vary": "Origin"
});

const json = (body, status, headers) => Response.json(body, { status, headers });
const hex = (bytes) => [...new Uint8Array(bytes)].map(b => b.toString(16).padStart(2, "0")).join("");
async function sha256(value) {
  return hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
}
function validKey(value) {
  return typeof value === "string" && /^TRV-[A-Z0-9]{4}(-[A-Z0-9]{4}){3}$/.test(value);
}
async function db(env, path, init = {}) {
  const response = await fetch(env.SUPABASE_URL + "/rest/v1/" + path, {
    ...init,
    headers: {
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      Authorization: "Bearer " + env.SUPABASE_SERVICE_ROLE_KEY,
      "Content-Type": "application/json",
      ...(init.headers || {})
    }
  });
  const text = await response.text();
  if (!response.ok) throw new Error("Database operation failed: " + response.status);
  return text ? JSON.parse(text) : [];
}
async function handleLicense(body, env) {
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    return { body: { error: "Licence service is not configured." }, status: 503 };
  }
  if (body.action === "activate" || body.action === "validate") {
    const key = String(body.license_key || "").trim().toUpperCase();
    const login = String(body.mt5_login || "").trim();
    const server = String(body.broker_server || "").trim();
    if (!validKey(key) || !/^\d{4,20}$/.test(login) || !server || server.length > 100) {
      return { body: { valid: false, error: "Enter a valid licence key, MT5 login and broker server." }, status: 400 };
    }
    const hash = await sha256(key);
    const rows = await db(env, "trevo_licenses?key_hash=eq." + hash + "&select=id,status,expires_at,max_accounts&limit=1");
    const license = rows[0];
    if (!license || license.status !== "active" || (license.expires_at && Date.parse(license.expires_at) <= Date.now())) {
      return { body: { valid: false, error: "Licence is invalid, expired or inactive." }, status: 403 };
    }
    const existing = await db(env, "trevo_license_activations?license_id=eq." + license.id +
      "&mt5_login=eq." + encodeURIComponent(login) + "&broker_server=eq." + encodeURIComponent(server) + "&select=id&limit=1");
    if (!existing.length) {
      const activations = await db(env, "trevo_license_activations?license_id=eq." + license.id + "&select=id");
      if (activations.length >= license.max_accounts) {
        return { body: { valid: false, error: "This licence has reached its account activation limit." }, status: 403 };
      }
      await db(env, "trevo_license_activations", {
        method: "POST",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify({ license_id: license.id, mt5_login: login, broker_server: server })
      });
    } else {
      await db(env, "trevo_license_activations?id=eq." + existing[0].id, {
        method: "PATCH",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify({ last_seen_at: new Date().toISOString() })
      });
    }
    return { body: { valid: true, status: "active", expires_at: license.expires_at, max_accounts: license.max_accounts }, status: 200 };
  }
  if (body.action === "issue") {
    if (!env.TREVO_ADMIN_SECRET || body.admin_secret !== env.TREVO_ADMIN_SECRET) {
      return { body: { error: "Not authorised." }, status: 403 };
    }
    const maxAccounts = Math.max(1, Math.min(10, Number(body.max_accounts) || 1));
    const days = Math.max(1, Math.min(3650, Number(body.valid_days) || 30));
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    let raw = "TRV-";
    for (let i = 0; i < 16; i++) {
      raw += alphabet[bytes[i] % alphabet.length];
      if (i === 3 || i === 7 || i === 11) raw += "-";
    }
    const keyHash = await sha256(raw);
    const expires = new Date(Date.now() + days * 86400000).toISOString();
    await db(env, "trevo_licenses", {
      method: "POST",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ key_hash: keyHash, max_accounts: maxAccounts, expires_at: expires, notes: "Issued by Trevo admin endpoint" })
    });
    return { body: { license_key: raw, expires_at: expires, max_accounts: maxAccounts }, status: 201 };
  }
  return { body: { error: "Unknown licence action." }, status: 400 };
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const allowed = (env.ALLOWED_ORIGIN || "").split(",").map(x => x.trim()).filter(Boolean);
    if (origin && !allowed.includes(origin)) return new Response("Origin not allowed", { status: 403 });
    const headers = cors(origin);
    if (request.method === "OPTIONS") return new Response(null, { headers });
    const url = new URL(request.url);

    // Public, read-only educational quote endpoint. Symbols are allow-listed.
    if (request.method === "GET" && url.searchParams.get("route") === "market") {
      if (!env.TWELVE_DATA_API_KEY) return json({ error: "Market data provider is not configured yet." }, 503, headers);
      const pairs = ["EUR/USD", "GBP/USD", "USD/JPY", "AUD/USD", "USD/CAD"];
      try {
        const quotes = await Promise.all(pairs.map(async pair => {
          const endpoint = "https://api.twelvedata.com/exchange_rate?symbol=" + encodeURIComponent(pair) +
            "&apikey=" + encodeURIComponent(env.TWELVE_DATA_API_KEY);
          const response = await fetch(endpoint);
          const data = await response.json();
          const price = Number(data.rate);
          if (!response.ok || !Number.isFinite(price) || price <= 0) throw new Error("Quote unavailable");
          return { pair, price, timestamp: Number(data.timestamp) || null };
        }));
        return json({ source: "Twelve Data", fetchedAt: new Date().toISOString(), quotes }, 200,
          { ...headers, "Cache-Control": "public, max-age=60" });
      } catch (_error) {
        return json({ error: "Live market data is temporarily unavailable." }, 502, headers);
      }
    }

    if (request.method !== "POST") return json({ error: "Method not allowed" }, 405, headers);
    try {
      const body = await request.json();
      if (body && ["activate", "validate", "issue"].includes(body.action)) {
        const result = await handleLicense(body, env);
        return json(result.body, result.status, headers);
      }

      // FR3DDY AI endpoint removed by product decision. Market data and TREVO licence routes remain active.
      return json({ error: "FR3DDY AI is disabled." }, 410, headers);
    } catch (_error) {
      return json({ error: "Something went wrong. Please try again later." }, 500, headers);
    }
  }
};
