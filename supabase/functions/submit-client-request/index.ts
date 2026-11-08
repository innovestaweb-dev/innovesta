import { createClient } from "npm:@supabase/supabase-js@2";

const WHATSAPP_SOURCE = "whatsapp";
const MAX_PER_MINUTE = 15;
const MAX_PER_DAY = 300;

const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);
const allowLocalhost = Deno.env.get("ALLOW_LOCALHOST") === "true";

function isAllowedOrigin(origin: string | null): boolean {
  if (!origin) return false;
  if (allowedOrigins.includes(origin)) return true;
  if (allowLocalhost && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
    return true;
  }
  return false;
}

function corsFor(origin: string | null): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": origin ?? "null",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  const json = (data: object, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...corsFor(origin), "Content-Type": "application/json" },
    });

  if (allowedOrigins.length === 0 && !allowLocalhost) {
    console.error("Missing server config: ALLOWED_ORIGINS");
    return json({ success: false, message: "Server configuration error" }, 500);
  }

  if (!isAllowedOrigin(origin)) {
    return new Response(JSON.stringify({ success: false, message: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsFor(origin) });
  }

  if (req.method !== "POST") {
    return json({ success: false, message: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      console.error("Missing Supabase server configuration");
      return json({ success: false, message: "Server configuration error" }, 500);
    }

    const raw = await req.text();
    if (raw.length > 5000) {
      return json({ success: false, message: "Payload too large" }, 413);
    }

    let data: Record<string, unknown>;
    try {
      data = JSON.parse(raw);
    } catch {
      return json({ success: false, message: "Invalid JSON" }, 400);
    }

    if (data.source !== WHATSAPP_SOURCE) {
      return json({ success: false, message: "Invalid source" }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Throttle: per minute and per day (global for WhatsApp leads)
    const now = Date.now();
    const minuteAgo = new Date(now - 60_000).toISOString();
    const dayAgo = new Date(now - 86_400_000).toISOString();

    const { count: lastMinute } = await supabase
      .from("client_requests")
      .select("id", { count: "exact", head: true })
      .eq("source", WHATSAPP_SOURCE)
      .gte("created_at", minuteAgo);

    if ((lastMinute ?? 0) >= MAX_PER_MINUTE) {
      return json({ success: false, message: "Too many requests" }, 429);
    }

    const { count: lastDay } = await supabase
      .from("client_requests")
      .select("id", { count: "exact", head: true })
      .eq("source", WHATSAPP_SOURCE)
      .gte("created_at", dayAgo);

    if ((lastDay ?? 0) >= MAX_PER_DAY) {
      return json({ success: false, message: "Too many requests" }, 429);
    }

    const name =
      typeof data.name === "string" ? data.name.trim().slice(0, 200) : null;
    const phone =
      typeof data.phone === "string" ? data.phone.trim().slice(0, 50) : null;
    const pageUrl =
      typeof data.page_url === "string" ? data.page_url.slice(0, 2000) : null;

    const { error } = await supabase.from("client_requests").insert({
      source: WHATSAPP_SOURCE,
      name,
      phone,
      page_url: pageUrl,
      status: "new",
      services: [],
    });

    if (error) {
      console.error("WhatsApp lead database error:", error);
      return json({ success: false, message: "Database save failed" }, 500);
    }

    return json({ success: true, message: "WhatsApp inquiry recorded" });
  } catch (error) {
    console.error("WhatsApp function error:", error);
    return json({ success: false, message: "Unable to process request" }, 500);
  }
});