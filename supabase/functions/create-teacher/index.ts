// ============================================================
// Edge Function: create-teacher
// Called by the admin screen to create a new teacher account.
//
// WHY an Edge Function?
//   Creating auth users requires the service_role key, which
//   must NEVER be shipped in the mobile app. This function
//   runs server-side and uses the service_role key safely.
//
// Flow:
//   1. Verify the caller's JWT is an active admin.
//   2. Create a new auth user with email + password.
//   3. The DB trigger (handle_new_user) auto-creates the
//      profile row with role = 'teacher'.
//   4. Return the new user's id.
//
// Deploy: supabase functions deploy create-teacher
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CORS headers so the Flutter app can call this function.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle preflight CORS request
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. Read environment variables ──────────────────────
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // ── 2. Verify the caller is an admin ───────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Create a client using the caller's JWT to check their role
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user: caller },
      error: authError,
    } = await userClient.auth.getUser();

    if (authError || !caller) {
      return new Response(
        JSON.stringify({ error: "Invalid token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check caller's role in the profiles table
    const { data: profile, error: profileError } = await userClient
      .from("profiles")
      .select("role, is_active")
      .eq("id", caller.id)
      .single();

    if (
      profileError ||
      !profile ||
      String(profile.role).toLowerCase() !== "admin" ||
      !profile.is_active
    ) {
      return new Response(
        JSON.stringify({ error: "Forbidden: admin access required" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 3. Parse the request body ──────────────────────────
    const { email, password, name, role } = await req.json();

    if (!email || !password || !name) {
      return new Response(
        JSON.stringify({ error: "email, password, and name are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 4. Create the teacher using the service role key ───
    //    The service role key has full access and bypasses RLS.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: newUser, error: createError } =
      await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true, // Skip email verification for school accounts
        user_metadata: { name, role: role ?? "teacher" },
      });

    if (createError) {
      return new Response(
        JSON.stringify({ error: createError.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 5. Return the new user's id ────────────────────────
    //    The profile row was auto-created by the DB trigger.
    return new Response(
      JSON.stringify({
        message: "Teacher created successfully",
        user_id: newUser.user.id,
        email: newUser.user.email,
      }),
      {
        status: 201,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

