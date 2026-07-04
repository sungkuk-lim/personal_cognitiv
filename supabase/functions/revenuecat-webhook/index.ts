import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (secret && req.headers.get("Authorization") !== `Bearer ${secret}`) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const payload = await req.json();
    const event = payload.event ?? payload;
    const appUserId = event.app_user_id as string | undefined;
    if (!appUserId) {
      return new Response(JSON.stringify({ ok: true, skipped: "no app_user_id" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const entitlements = event.entitlements ?? event.subscriber?.entitlements ?? {};
    const pro = entitlements.pro ?? entitlements["pro"];
    const isActive = pro?.expires_date
      ? new Date(pro.expires_date) > new Date()
      : Boolean(pro);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    await admin.rpc("upsert_user_subscription", {
      p_user_id: appUserId,
      p_tier: isActive ? "pro" : "free",
      p_status: isActive ? "active" : "expired",
      p_expires_at: pro?.expires_date ?? null,
      p_store: "revenuecat",
      p_product_id: pro?.product_identifier ?? null,
    });

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
