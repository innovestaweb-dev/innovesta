import { createClient } from "npm:@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Secrets المطلوبة:
//   HCAPTCHA_SECRET   -> hCaptcha dashboard -> Settings -> Secret key
// اختيارية:
//   ALLOWED_ORIGINS   -> دومينات إضافية مفصولة بفاصلة (مثلا https://your-domain.com)
//                        الدومين الأساسي (workers.dev) متضاف في الكود تلقائيا
//   ALLOW_LOCALHOST=true  (للتجربة من جهازك فقط، وتتمسح بعد كده)
//   RESEND_API_KEY + NOTIFY_EMAIL (+ NOTIFY_FROM) -> إيميل إشعار
//
// مهم: Enforce JWT verification لازم يكون مطفي للـ function دي.
// الحماية هنا: الـ Origin + hCaptcha على السيرفر + validation + throttle.
// ---------------------------------------------------------------------------
const HCAPTCHA_SITEKEY = "5d4888e2-3484-4486-9e66-8f1e050002f2"; // public
const FORM_SOURCE = "form"; // لازم يكون مسموح في client_requests_source_check

// الدومينات الثابتة المسموحة (بتتدمج مع Secret ALLOWED_ORIGINS لو موجود)
const BUILTIN_ORIGINS = [
  "https://innovesta.innovestaweb.workers.dev",
];

const ALLOW_LOCALHOST = Deno.env.get("ALLOW_LOCALHOST") === "true";

const ALLOWED_ORIGINS = [
  ...new Set([
    ...BUILTIN_ORIGINS,
    ...(Deno.env.get("ALLOWED_ORIGINS") ?? "")
      .split(",")
      .map((s) => s.trim().replace(/\/$/, ""))
      .filter(Boolean),
  ]),
];

const ALLOWED_HOSTNAMES = ALLOWED_ORIGINS.map((o) => {
  try { return new URL(o).hostname; } catch { return ""; }
}).filter(Boolean);

const MAX_BODY_BYTES = 16 * 1024;
const PER_10_MIN_LIMIT = 20;
const PER_DAY_LIMIT = 200;
const FETCH_TIMEOUT_MS = 8000;

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const PHONE_RE = /^\+?[0-9\s\-()]+$/;

const PROJECT_TYPES = ["Villa / Residential", "Apartment", "Commercial / Retail", "Office", "Hospitality", "Landscape", "Other"];
const PROJECT_STAGES = ["Concept Design", "Design Development", "Ready for Visualization", "Under Construction", "Existing Space Renovation"];
const AREAS = ["Under 100 m²", "100–250 m²", "250–500 m²", "500–1,000 m²", "Over 1,000 m²", "Not determined"];
const TIMELINES = ["As soon as possible", "Within 2 weeks", "Within a month", "Flexible"];
const MOODS = ["Warm & Inviting", "Luxury & Sophisticated", "Minimal & Calm", "Bright & Natural", "Dark & Dramatic", "Bold & Contemporary", "Not sure yet"];
const SERVICES = ["Interior Still Renders", "Exterior Still Renders", "Architectural Animation", "Interactive Walkthrough", "VR Experience"];
const STYLES = ["Modern", "Minimalist", "Luxury", "Classic", "Neoclassical", "Contemporary", "Industrial", "Not sure yet"];
const CONTACT_METHODS = ["WhatsApp", "Email", "Phone"];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function isAllowedOrigin(origin: string) {
  return ALLOWED_ORIGINS.includes(origin) ||
    (ALLOW_LOCALHOST && /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin));
}

// hCaptcha ساعات بترجّع الدومين الأب (زي workers.dev) بدل الهوست الكامل،
// فبنقبل الهوست لو هو نفسه أو أب لأي دومين مسموح.
function isAllowedHostname(host: string) {
  const h = host.toLowerCase();
  return ALLOWED_HOSTNAMES.some((a) => a === h || a.endsWith("." + h)) ||
    (ALLOW_LOCALHOST && (h === "localhost" || h === "127.0.0.1"));
}

// يشيل control characters (بيسيب \n \r \t)
const clean = (v: unknown, max: number) =>
  typeof v === "string"
    ? v.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "").trim().slice(0, max)
    : "";

// حقول السطر الواحد: يمنع newline injection
const line = (v: unknown, max: number) =>
  clean(v, max).replace(/[\r\n\t]+/g, " ");

const pick = (v: unknown, allowed: string[]) =>
  typeof v === "string" && allowed.includes(v) ? v : "";

const pickMany = (v: unknown, allowed: string[]) =>
  typeof v === "string"
    ? [...new Set(v.split(",").map((s) => s.trim()).filter((s) => allowed.includes(s)))]
    : [];

async function verifyHCaptcha(token: string, secret: string): Promise<boolean> {
  try {
    const res = await fetch("https://api.hcaptcha.com/siteverify", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ secret, response: token, sitekey: HCAPTCHA_SITEKEY }),
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
    });
    const v = await res.json();
    if (!v?.success) {
      console.error("hCaptcha failed:", JSON.stringify(v?.["error-codes"] ?? []));
      return false;
    }
    if (v.hostname && !isAllowedHostname(String(v.hostname))) {
      console.error("hCaptcha hostname mismatch:", v.hostname);
      return false;
    }
    return true;
  } catch (e) {
    console.error("hCaptcha verify error:", e instanceof Error ? e.message : e);
    return false;
  }
}

// إيميل إشعار اختياري عن طريق Resend (نص عادي فقط)
async function sendNotification(lead: Record<string, unknown>): Promise<boolean> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  const to = Deno.env.get("NOTIFY_EMAIL");
  if (!apiKey || !to) return false;

  const from = Deno.env.get("NOTIFY_FROM") ?? "INNOVISTA <onboarding@resend.dev>";

  const text = Object.entries(lead)
    .filter(([, v]) => v !== "" && v !== null && v !== undefined)
    .map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(", ") : v}`)
    .join("\n");

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from,
        to: [to],
        subject: "New INNOVISTA Project Request",
        text,
        reply_to: String(lead.email ?? ""),
      }),
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
    });
    if (!res.ok) console.error("Resend rejected:", res.status, await res.text());
    return res.ok;
  } catch (e) {
    console.error("Resend error:", e instanceof Error ? e.message : e);
    return false;
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------
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
    console.error("Blocked origin:", origin, "| allowed:", ALLOWED_ORIGINS.join(", "));
    return json({ success: false, message: "origin" }, 403);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const hcaptchaSecret = Deno.env.get("HCAPTCHA_SECRET");

    if (!supabaseUrl || !serviceKey || !hcaptchaSecret || ALLOWED_ORIGINS.length === 0) {
      console.error("Missing server config", {
        supabaseUrl: !!supabaseUrl,
        serviceKey: !!serviceKey,
        hcaptchaSecret: !!hcaptchaSecret,
        allowedOrigins: ALLOWED_ORIGINS.length,
      });
      return json({ success: false, message: "server_config" }, 500);
    }

    const declared = Number(req.headers.get("content-length") ?? 0);
    if (declared > MAX_BODY_BYTES) return json({ success: false }, 413);
    const raw = await req.text();
    if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) {
      return json({ success: false }, 413);
    }

    let d: any;
    try { d = JSON.parse(raw); } catch { return json({ success: false }, 400); }
    if (!d || typeof d !== "object" || Array.isArray(d)) {
      return json({ success: false }, 400);
    }

    // ---- Validation على السيرفر ----
    const captchaToken = line(d["h-captcha-response"], 4000);
    if (!captchaToken) return json({ success: false, message: "captcha" }, 400);

    const name = line(d.name, 100);
    const company = line(d.company, 120);
    const country = line(d.country, 80);
    const location = line(d.location, 80);
    const whatsapp = line(d.whatsapp, 25);
    const email = line(d.email, 254).toLowerCase();
    const budget = line(d.estimated_budget, 60);
    const currency = line(d.budget_currency, 10);
    const description = clean(d.project_description, 3000);
    const notes = clean(d.additional_notes, 2000);
    const refs = clean(d.reference_links, 1000);

    const projectType = pick(d.project_type, PROJECT_TYPES);
    const projectStage = pick(d.project_stage, PROJECT_STAGES);
    const projectArea = pick(d.project_area, AREAS);
    const timeline = pick(d.timeline, TIMELINES);
    const mood = pick(d.overall_mood, MOODS);
    const preferred = pick(d.preferred_contact, CONTACT_METHODS) || "WhatsApp";
    const services = pickMany(d.services, SERVICES);
    const styles = pickMany(d.design_styles, STYLES);

    const digits = whatsapp.replace(/\D/g, "");
    if (
      !name || !country || !location || !description ||
      !projectType || !projectStage || !projectArea || !timeline ||
      services.length === 0 ||
      !EMAIL_RE.test(email) ||
      !PHONE_RE.test(whatsapp) || digits.length < 7 || digits.length > 15
    ) {
      return json({ success: false, message: "validation" }, 400);
    }

    // روابط المراجع بتتعرض في صفحة الأدمن
    if (/\b(javascript|data|vbscript|file|blob)\s*:/i.test(refs)) {
      return json({ success: false, message: "validation" }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // ---- Throttle (قبل أي استدعاء خارجي) ----
    const countSince = async (ms: number, byEmail?: string) => {
      let q = supabase
        .from("client_requests")
        .select("id", { count: "exact", head: true })
        .eq("source", FORM_SOURCE)
        .gte("created_at", new Date(Date.now() - ms).toISOString());
      if (byEmail) q = q.eq("email", byEmail);
      const { count } = await q;
      return count ?? 0;
    };

    if ((await countSince(600_000)) >= PER_10_MIN_LIMIT) return json({ success: false, message: "rate_limited" }, 429);
    if ((await countSince(86_400_000)) >= PER_DAY_LIMIT) return json({ success: false, message: "rate_limited" }, 429);

    // نفس الإيميل في آخر 10 دقايق: تجاهل هادي (ضغطة مزدوجة أو سبام)
    if ((await countSince(600_000, email)) > 0) return json({ success: true });

    // ---- 1) تحقق hCaptcha على السيرفر ----
    if (!(await verifyHCaptcha(captchaToken, hcaptchaSecret))) {
      return json({ success: false, message: "verification_failed" }, 400);
    }

    // ---- 2) حفظ الطلب (مايضيعش) ----
    const row = {
      source: FORM_SOURCE,
      status: "new",
      name,
      company,
      country,
      location,
      phone: whatsapp,
      email,
      preferred_contact: preferred,
      project_type: projectType,
      project_stage: projectStage,
      project_area: projectArea,
      area: projectArea,
      timeline,
      services,                         // jsonb
      details: description,
      design_styles: styles.join(", "), // text
      overall_mood: mood,
      reference_links: refs,
      estimated_budget: budget,
      budget,
      budget_currency: currency,
      additional_notes: notes,
    };

    const { error } = await supabase.from("client_requests").insert(row);
    if (error) {
      console.error("DB insert error:", error.message);
      return json({ success: false, message: "save_failed" }, 500);
    }

    // ---- 3) إيميل إشعار اختياري (فشله مبيفشلش الطلب) ----
    const mailed = await sendNotification({
      name, email, company, country, location, whatsapp,
      preferred_contact: preferred,
      project_type: projectType,
      project_stage: projectStage,
      project_area: projectArea,
      timeline,
      services,
      project_description: description,
      design_styles: styles.join(", "),
      overall_mood: mood,
      reference_links: refs,
      estimated_budget: budget,
      budget_currency: currency,
      additional_notes: notes,
    });
    if (!mailed) console.log("Lead saved. Email notification skipped or failed.");

    return json({ success: true });
  } catch (e) {
    console.error("Function error:", e instanceof Error ? e.message : e);
    return json({ success: false, message: "server_error" }, 500);
  }
});