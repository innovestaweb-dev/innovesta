// supabase/functions/login-alert/index.ts
//
// Receives a call from the database trigger (03_login_alerts.sql) and sends
// the alert to Telegram (and optionally to email through Resend).
//
// Secrets (set with `supabase secrets set`):
//   ALERT_SECRET         same value used in the SQL file
//   TELEGRAM_BOT_TOKEN   from @BotFather
//   TELEGRAM_CHAT_ID     your chat id
//   ADMIN_EMAIL          your admin email (anything else is flagged as suspicious)
// Email (Resend):
//   RESEND_API_KEY, ALERT_EMAIL_TO, ALERT_EMAIL_FROM
// WhatsApp (CallMeBot):
//   WHATSAPP_PHONE (e.g. +201203450806), CALLMEBOT_APIKEY

const ALERT_SECRET = Deno.env.get("ALERT_SECRET") ?? "";
const TG_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const TG_CHAT = Deno.env.get("TELEGRAM_CHAT_ID") ?? "";
const ADMIN_EMAIL = (Deno.env.get("ADMIN_EMAIL") ?? "").toLowerCase();

const RESEND_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const MAIL_TO = Deno.env.get("ALERT_EMAIL_TO") ?? "";
const MAIL_FROM = Deno.env.get("ALERT_EMAIL_FROM") ?? "";

const WA_PHONE = Deno.env.get("WHATSAPP_PHONE") ?? "";
const WA_KEY = Deno.env.get("CALLMEBOT_APIKEY") ?? "";

function esc(value: unknown): string {
  return String(value ?? "-")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function plain(html: string): string {
  return html
    .replace(/<[^>]+>/g, "")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&amp;", "&");
}

async function sendWhatsApp(text: string) {
  if (!WA_PHONE || !WA_KEY) return;

  const url =
    "https://api.callmebot.com/whatsapp.php" +
    `?phone=${encodeURIComponent(WA_PHONE)}` +
    `&text=${encodeURIComponent(text)}` +
    `&apikey=${encodeURIComponent(WA_KEY)}`;

  const res = await fetch(url);

  if (!res.ok) console.error("WhatsApp error:", res.status, await res.text());
}

async function sendTelegram(html: string) {
  if (!TG_TOKEN || !TG_CHAT) return;

  const res = await fetch(`https://api.telegram.org/bot${TG_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: TG_CHAT,
      text: html,
      parse_mode: "HTML",
      disable_web_page_preview: true,
    }),
  });

  if (!res.ok) console.error("Telegram error:", res.status, await res.text());
}

async function sendEmail(subject: string, html: string) {
  if (!RESEND_KEY || !MAIL_TO || !MAIL_FROM) return;

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${RESEND_KEY}`,
    },
    body: JSON.stringify({
      from: MAIL_FROM,
      to: [MAIL_TO],
      subject,
      html: html.replaceAll("\n", "<br>"),
    }),
  });

  if (!res.ok) console.error("Resend error:", res.status, await res.text());
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (!ALERT_SECRET || req.headers.get("x-alert-secret") !== ALERT_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  let payload: Record<string, string | null>;
  try {
    payload = await req.json();
  } catch {
    return new Response("Bad request", { status: 400 });
  }

  const event = payload.event ?? "";
  const email = (payload.email ?? "").toLowerCase();
  const isAdmin = ADMIN_EMAIL !== "" && email === ADMIN_EMAIL;

  const when = payload.at
    ? new Date(payload.at).toLocaleString("ar-EG", { timeZone: "Africa/Cairo" })
    : "-";

  let title: string;
  if (!isAdmin) {
    title = "🚨 تسجيل دخول بحساب غير الأدمن";
  } else if (event === "mfa_ok") {
    title = "✅ تم الدخول للوحة التحكم (الباسورد + الكود)";
  } else {
    title = "🔐 تم إدخال الباسورد الصحيح للأدمن (في انتظار الكود)";
  }

  const hint = isAdmin && event === "password_ok"
    ? "\n\nلو ده مش إنت: غيّر الباسورد فورًا من Supabase وراجع الـ Sessions."
    : !isAdmin
    ? "\n\nراجع Authentication ← Users في Supabase فورًا."
    : "";

  const text =
    `<b>${title}</b>\n\n` +
    `الإيميل: ${esc(email)}\n` +
    `IP: ${esc(payload.ip)}\n` +
    `الجهاز: ${esc(payload.user_agent)}\n` +
    `الوقت: ${esc(when)}` +
    hint;

  const plainText = plain(text);

  // allSettled: one failing channel must not stop the others.
  await Promise.allSettled([
    sendTelegram(text),
    sendWhatsApp(plainText),
    sendEmail(plain(title), plainText),
  ]);

  return new Response("ok");
});