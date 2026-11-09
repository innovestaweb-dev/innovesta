import { createClient } from "npm:@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// track-visit: records one page view (no personal data).
// Secrets (same ones used by the other functions):
//   ALLOWED_ORIGINS   -> https://xxx.pages.dev,https://your-domain.com
//   ALLOW_LOCALHOST=true (testing only)
// "Enforce JWT verification" must be OFF for this function.
// ---------------------------------------------------------------------------

const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "https://placeholder.pages.dev")
  .split(",")
  .map((s) => s.trim().replace(/\/$/, ""))
  .filter(Boolean);
const ALLOW_LOCALHOST = Deno.env.get("ALLOW_LOCALHOST") === "true";

const MAX_BODY_BYTES = 1024;
const PER_VISITOR_PER_MINUTE = 30;
const GLOBAL_PER_10_MIN = 3000;

const VISITOR_RE = /^[A-Za-z0-9_-]{16,64}$/;
const PATH_RE = /^\/[A-Za-z0-9\-_\/.%]*$/;

function isAllowedOrigin(origin: string) {
  return ALLOWED_ORIGINS.includes(origin) ||
    (ALLOW_LOCALHOST && /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin));
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  const cors = {
    ...(origin && isAllowedOrigin(origin) ? { "Access-Control-Allow-Origin": origin } : {}),
    "Vary": "Origin",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  const json = (data: object, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...cors, "Content-Type": "application/json" },
    });

  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return json({ ok: false }, 405);

  // Browsers always send Origin on a cross-site POST: require an allowed one.
  if (!origin || !isAllowedOrigin(origin)) {
    console.error("Blocked origin:", origin);
    return json({ ok: false }, 403);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      console.error("Missing server config");
      return json({ ok: false }, 500);
    }

    const raw = await req.text();
    if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) {
      return json({ ok: false }, 413);
    }

    let data: any;
    try { data = JSON.parse(raw); } catch { return json({ ok: false }, 400); }
    if (!data || typeof data !== "object" || Array.isArray(data)) {
      return json({ ok: false }, 400);
    }

    const visitorId = typeof data.visitor_id === "string" ? data.visitor_id : "";
    if (!VISITOR_RE.test(visitorId)) return json({ ok: false }, 400);

    let path = typeof data.path === "string" ? data.path.trim() : "";
    if (path.length > 200 || !PATH_RE.test(path)) return json({ ok: false }, 400);
    if (path.length > 1) path = path.replace(/\/+$/, "");

    // Private / technical pages are never counted.
    if (path.startsWith("/admin") || path === "/404") return json({ ok: true });

    // Referrer: keep only the host, and ignore our own site.
    let referrer: string | null = null;
    if (typeof data.referrer === "string" && data.referrer.trim()) {
      try {
        const host = new URL(data.referrer).hostname.toLowerCase().slice(0, 100);
        const ownHost = new URL(origin).hostname.toLowerCase();
        if (host && host !== ownHost) referrer = host;
      } catch { /* ignore bad referrer */ }
    }

    // Country code from Cloudflare (2 letters), when available.
    const cc = (req.headers.get("cf-ipcountry") ?? "").toUpperCase();
    const country = /^[A-Z]{2}$/.test(cc) ? cc : null;

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const countSince = async (ms: number, visitor?: string) => {
      let q = supabase
        .from("site_visits")
        .select("id", { count: "exact", head: true })
        .gte("created_at", new Date(Date.now() - ms).toISOString());
      if (visitor) q = q.eq("visitor_id", visitor);
      const { count } = await q;
      return count ?? 0;
    };

    if ((await countSince(60_000, visitorId)) >= PER_VISITOR_PER_MINUTE) {
      return json({ ok: false }, 429);
    }
    if ((await countSince(600_000)) >= GLOBAL_PER_10_MIN) {
      return json({ ok: false }, 429);
    }

    const { error } = await supabase.from("site_visits").insert({
      visitor_id: visitorId,
      path,
      referrer,
      country,
    });

    if (error) {
      console.error("DB error:", error.message);
      return json({ ok: false }, 500);
    }
    return json({ ok: true });
  } catch (e) {
    console.error("Function error:", e instanceof Error ? e.message : e);
    return json({ ok: false }, 500);
  }
});