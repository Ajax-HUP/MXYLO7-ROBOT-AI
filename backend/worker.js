const cors = (origin) => ({
  "Access-Control-Allow-Origin": origin,
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Vary": "Origin"
});

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const allowed = (env.ALLOWED_ORIGIN || "").split(",").map(x => x.trim()).filter(Boolean);
    if (!allowed.includes(origin)) return new Response("Origin not allowed", { status: 403 });
    const headers = cors(origin);
    if (request.method === "OPTIONS") return new Response(null, { headers });

    // Public, read-only educational quote endpoint. Symbols are allow-listed.
    const url = new URL(request.url);
    if (request.method === "GET" && url.searchParams.get("route") === "market") {
      if (!env.TWELVE_DATA_API_KEY) {
        return Response.json({ error: "Market data provider is not configured yet." }, { status: 503, headers });
      }
      const pairs = ["EUR/USD", "GBP/USD", "USD/JPY", "AUD/USD", "USD/CAD"];
      try {
        const quotes = await Promise.all(pairs.map(async pair => {
          const endpoint = "https://api.twelvedata.com/exchange_rate?symbol=" +
            encodeURIComponent(pair) + "&apikey=" + encodeURIComponent(env.TWELVE_DATA_API_KEY);
          const response = await fetch(endpoint);
          const data = await response.json();
          const price = Number(data.rate);
          if (!response.ok || !Number.isFinite(price) || price <= 0) {
            throw new Error("A market quote could not be retrieved.");
          }
          return { pair, price, timestamp: Number(data.timestamp) || null };
        }));
        return Response.json({
          source: "Twelve Data",
          fetchedAt: new Date().toISOString(),
          quotes
        }, { headers: { ...headers, "Cache-Control": "public, max-age=60" } });
      } catch (_error) {
        return Response.json({ error: "Live market data is temporarily unavailable. Please try again later." }, { status: 502, headers });
      }
    }
    if (request.method !== "POST") return Response.json({ error: "Method not allowed" }, { status: 405, headers });

    try {
      const auth = request.headers.get("Authorization") || "";
      if (!auth.startsWith("Bearer ")) return Response.json({ error: "Please sign in." }, { status: 401, headers });
      const token = auth.slice(7);

      // Verify the signed-in user with Supabase Auth.
      const userRes = await fetch(env.SUPABASE_URL + "/auth/v1/user", {
        headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: "Bearer " + token }
      });
      if (!userRes.ok) return Response.json({ error: "Your session is invalid. Please log in again." }, { status: 401, headers });
      const user = await userRes.json();

      // Premium access is checked on the server, never trusted from the browser.
      const membershipUrl = env.SUPABASE_URL + "/rest/v1/premium_memberships?user_id=eq." +
        encodeURIComponent(user.id) + "&active=eq.true&select=user_id&limit=1";
      const membershipRes = await fetch(membershipUrl, {
        headers: {
          apikey: env.SUPABASE_SERVICE_ROLE_KEY,
          Authorization: "Bearer " + env.SUPABASE_SERVICE_ROLE_KEY
        }
      });
      if (!membershipRes.ok) throw new Error("Could not verify membership.");
      const memberships = await membershipRes.json();
      if (!memberships.length) return Response.json({ error: "FR3DDY AI Advanced is a Premium feature." }, { status: 403, headers });

      const body = await request.json();
      const messages = Array.isArray(body.messages) ? body.messages.slice(-12) : [];
      if (!messages.length || messages.some(m => !["user", "assistant"].includes(m.role) || typeof m.content !== "string" || m.content.length > 3000)) {
        return Response.json({ error: "Please send a valid message." }, { status: 400, headers });
      }
      const input = messages.map(m => ({ role: m.role, content: m.content }));
      const aiRes = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: "Bearer " + env.OPENAI_API_KEY },
        body: JSON.stringify({
          model: env.OPENAI_MODEL || "gpt-5.5",
          instructions: "You are FR3DDY AI, a friendly, clear educational assistant inside MXYLO7 ROBOT AI. Answer a broad range of safe everyday, school, technology and general knowledge questions. Explain concepts clearly and ask a clarifying question if needed. For forex or finance topics, provide education only: do not give personalized financial advice, guaranteed predictions, trade instructions, or tell users to buy or sell. MXYLO7 has no live trading capability. Never claim to see live prices or place trades. Keep responses age-appropriate. Do not request passwords, API keys, payment details or broker credentials.",
          input
        })
      });
      const result = await aiRes.json();
      if (!aiRes.ok) return Response.json({ error: "FR3DDY is temporarily unavailable. Please try again later." }, { status: 502, headers });
      const answer = result.output?.flatMap(item => item.content || []).filter(part => part.type === "output_text").map(part => part.text).join("\n") || "";
      if (!answer) throw new Error("Empty AI response.");
      return Response.json({ answer }, { headers });
    } catch (error) {
      return Response.json({ error: "Something went wrong. Please try again later." }, { status: 500, headers });
    }
  }
};