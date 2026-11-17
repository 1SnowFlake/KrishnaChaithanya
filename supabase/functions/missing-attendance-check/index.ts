// ============================================================
// Edge Function: missing-attendance-check
// Runs periodically (e.g. pg_cron or hourly scheduler) to check
// if session cutoff times have passed and attendance was not submitted.
//
// Automatically dispatches in-app notifications to admins and teachers.
//
// Deploy: supabase functions deploy missing-attendance-check
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // 1. Fetch current school date and timezone
    const now = new Date();
    const todayStr = now.toISOString().split("T")[0];

    // 2. Fetch settings
    const { data: settings } = await supabase
      .from("settings")
      .select("morning_cutoff, afternoon_cutoff, weekly_off_days")
      .maybeSingle();

    const mCutoff = settings?.morning_cutoff || "10:30:00";
    const aCutoff = settings?.afternoon_cutoff || "14:30:00";

    // 3. Check if today is a holiday or weekly off
    const { data: holiday } = await supabase
      .from("holidays")
      .select("name")
      .lte("start_date", todayStr)
      .gte("end_date", todayStr)
      .maybeSingle();

    if (holiday) {
      return new Response(
        JSON.stringify({ message: "School closed today (Holiday). No alerts generated." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const dayOfWeek = now.getUTCDay(); // 0 = Sunday
    if (settings?.weekly_off_days?.includes(dayOfWeek)) {
      return new Response(
        JSON.stringify({ message: "School closed today (Weekly off). No alerts generated." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Determine if morning or afternoon cutoffs have passed
    const currentTimeStr = now.toTimeString().split(" ")[0];
    const isMorningPast = currentTimeStr >= mCutoff;
    const isAfternoonPast = currentTimeStr >= aCutoff;

    if (!isMorningPast && !isAfternoonPast) {
      return new Response(
        JSON.stringify({ message: "Cutoffs have not yet passed. No alerts needed." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Fetch all classes
    const { data: classes } = await supabase
      .from("classes")
      .select("id, name, primary_teacher_id");

    // 6. Fetch today's submitted attendance
    const { data: attendance } = await supabase
      .from("attendance")
      .select("class_id, session")
      .eq("date", todayStr);

    const submittedSet = new Set(
      attendance?.map((a: any) => `${a.class_id}_${a.session}`) || []
    );

    // 7. Check existing notifications to prevent duplicate spam
    const { data: existingNotifs } = await supabase
      .from("notifications")
      .select("message")
      .eq("type", "missing_attendance")
      .gte("created_at", `${todayStr}T00:00:00`);

    const existingMessages = new Set(existingNotifs?.map((n: any) => n.message) || []);
    const newAlerts: any[] = [];

    for (const cls of classes || []) {
      // Check Morning session
      if (isMorningPast && !submittedSet.has(`${cls.id}_morning`)) {
        const msg = `Morning attendance for ${cls.name} was not submitted before cutoff (${mCutoff}).`;
        if (!existingMessages.has(msg)) {
          existingMessages.add(msg);
          newAlerts.push({
            user_id: null, // Admin broadcast
            type: "missing_attendance",
            message: msg,
            is_read: false,
            metadata: {
              title: `Missing Attendance: ${cls.name} (Morning)`,
              class_id: cls.id,
              session: "morning",
              date: todayStr,
            },
          });

          if (cls.primary_teacher_id) {
            newAlerts.push({
              user_id: cls.primary_teacher_id,
              type: "missing_attendance",
              message: `You have not submitted Morning attendance for ${cls.name}.`,
              is_read: false,
              metadata: {
                title: "Action Required: Morning Attendance Pending",
                class_id: cls.id,
                session: "morning",
                date: todayStr,
              },
            });
          }
        }
      }

      // Check Afternoon session
      if (isAfternoonPast && !submittedSet.has(`${cls.id}_afternoon`)) {
        const msg = `Afternoon attendance for ${cls.name} was not submitted before cutoff (${aCutoff}).`;
        if (!existingMessages.has(msg)) {
          existingMessages.add(msg);
          newAlerts.push({
            user_id: null,
            type: "missing_attendance",
            message: msg,
            is_read: false,
            metadata: {
              title: `Missing Attendance: ${cls.name} (Afternoon)`,
              class_id: cls.id,
              session: "afternoon",
              date: todayStr,
            },
          });

          if (cls.primary_teacher_id) {
            newAlerts.push({
              user_id: cls.primary_teacher_id,
              type: "missing_attendance",
              message: `You have not submitted Afternoon attendance for ${cls.name}.`,
              is_read: false,
              metadata: {
                title: "Action Required: Afternoon Attendance Pending",
                class_id: cls.id,
                session: "afternoon",
                date: todayStr,
              },
            });
          }
        }
      }
    }

    if (newAlerts.length > 0) {
      await supabase.from("notifications").insert(newAlerts);
    }

    return new Response(
      JSON.stringify({ success: true, alertsDispatched: newAlerts.length }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
