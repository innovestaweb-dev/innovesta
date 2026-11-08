
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  const jsonResponse = (data: object, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(
      { success: false, message: "Method not allowed" },
      405
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("servece_key_role");

    if (!supabaseUrl || !serviceRoleKey) {
      console.error("Missing Supabase server configuration");

      return jsonResponse(
        { success: false, message: "Server configuration error" },
        500
      );
    }

    const data = await req.json();

    // Accept WhatsApp inquiries only.
    if (data.source !== "whatsapp") {
      return jsonResponse(
        { success: false, message: "Invalid source" },
        400
      );
    }

    const supabase = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      }
    );

    const name =
      typeof data.name === "string"
        ? data.name.trim().slice(0, 200)
        : null;

    const phone =
      typeof data.phone === "string"
        ? data.phone.trim().slice(0, 50)
        : null;

    const pageUrl =
      typeof data.page_url === "string"
        ? data.page_url.slice(0, 2000)
        : null;

    const { error } = await supabase
      .from("client_requests")
      .insert({
        source: "whatsapp",
        name,
        phone,
        page_url: pageUrl,
        status: "new",
        services: [],
      });

    if (error) {
      console.error("WhatsApp lead database error:", error);

      return jsonResponse(
        { success: false, message: "Database save failed" },
        500
      );
    }

    console.log("WhatsApp inquiry recorded successfully");

    return jsonResponse({
      success: true,
      message: "WhatsApp inquiry recorded",
    });

  } catch (error) {
    console.error("WhatsApp function error:", error);

    return jsonResponse(
      { success: false, message: "Unable to process request" },
      500
    );
  }
});
