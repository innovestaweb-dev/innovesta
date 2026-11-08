import { createClient } from "npm:@supabase/supabase-js@2";

const WHATSAPP_SOURCE = "whatsapp"; // لازم يكون مسموح في client_requests_source_check

const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "https://placeholder.pages.dev")
  .split(",")
  .map((s) => s.trim().replace(/\/$/, ""))
  .filter(Boolean);
const ALLOW_LOCALHOST = Deno.env.get("ALLOW_LOCALHOST") === "true";

const MAX_BODY_BYTES = 2048;
const PER_MINUTE_LIMIT = 15;
const PER_DAY_LIMIT = 300;
const PHONE_RE = /^\+?[0-9\s\-()]{7,20}$/;

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
  if (req.method !== "POST") return json({ success: false }, 405);

  if (origin !== null && !isAllowedOrigin(origin)) {
    console.error("Blocked origin:", origin);
    return json({ success: false }, 403);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      console.error("Missing server config");
      return json({ success: false }, 500);
    }

    const raw = await req.text();
    if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) {
      return json({ success: false }, 413);
    }

    let data: any;
    try { data = JSON.parse(raw); } catch { return json({ success: false }, 400); }
    if (!data || typeof data !== "object" || Array.isArray(data)) {
      return json({ success: false }, 400);
    }

    if (data.source !== "whatsapp") return json({ success: false }, 400);

    const name = typeof data.name === "string" && data.name.trim()
      ? data.name.replace(/[\u0000-\u001F\u007F]/g, " ").trim().slice(0, 200)
      : null;

    let phone = typeof data.phone === "string" && data.phone.trim()
      ? data.phone.trim().slice(0, 50) : null;
    if (phone && !PHONE_RE.test(phone)) phone = null;

    let pageUrl: string | null = null;
    if (typeof data.page_url === "string") {
      try {
        const u = new URL(data.page_url);
        if (isAllowedOrigin(u.origin)) pageUrl = data.page_url.slice(0, 2000);
      } catch { /* تجاهل */ }
    }

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const countSince = async (ms: number) => {
      const { count } = await supabase
        .from("client_requests")
        .select("id", { count: "exact", head: true })
        .eq("source", WHATSAPP_SOURCE)
        .gte("created_at", new Date(Date.now() - ms).toISOString());
      return count ?? 0;
    };

    if ((await countSince(60_000)) >= PER_MINUTE_LIMIT) return json({ success: false }, 429);
    if ((await countSince(86_400_000)) >= PER_DAY_LIMIT) return json({ success: false }, 429);

    const { error } = await supabase.from("client_requests").insert({
      source: WHATSAPP_SOURCE,
      name,
      phone,
      page_url: pageUrl,
      status: "new",
      services: [],
    });

    if (error) {
      console.error("DB error:", error.message);
      return json({ success: false }, 500);
    }
    return json({ success: true });
  } catch (e) {
    console.error("Function error:", e instanceof Error ? e.message : e);
    return json({ success: false }, 500);
  }
});