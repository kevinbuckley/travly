import { ImageResponse } from "next/og";
import { createClient } from "@supabase/supabase-js";

export const runtime = "edge";
export const alt = "TripWit — Trip";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

interface Props {
  params: Promise<{ id: string }>;
}

function getServerSupabase() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return null;
  return createClient(url, key);
}

function formatDateRange(start?: string, end?: string): string {
  if (!start) return "";
  try {
    const s = new Date(start + "T12:00:00");
    const e = end ? new Date(end + "T12:00:00") : null;
    const opts: Intl.DateTimeFormatOptions = { month: "short", day: "numeric", year: "numeric" };
    if (!e || start === end) return s.toLocaleDateString("en-US", opts);
    return `${s.toLocaleDateString("en-US", { month: "short", day: "numeric" })} – ${e.toLocaleDateString("en-US", opts)}`;
  } catch { return ""; }
}

export default async function OGImage({ params }: Props) {
  const { id } = await params;
  const supabase = getServerSupabase();

  let name = "Trip";
  let destination = "";
  let statusRaw = "planning";
  let startDate = "";
  let endDate = "";
  let dayCount = 0;
  let stopCount = 0;

  if (supabase) {
    try {
      const { data } = await supabase
        .from("trips")
        .select("name, destination, status_raw, start_date, end_date, days")
        .eq("id", id)
        .eq("is_public", true)
        .single();

      if (data) {
        name = data.name || "Trip";
        destination = data.destination || "";
        statusRaw = data.status_raw || "planning";
        startDate = data.start_date || "";
        endDate = data.end_date || "";
        const days = data.days ?? [];
        dayCount = days.length;
        stopCount = days.reduce((c: number, d: { stops?: unknown[] }) => c + (d.stops?.length ?? 0), 0);
      }
    } catch { /* use defaults */ }
  }

  const statusLabel = statusRaw === "active" ? "Active" : statusRaw === "completed" ? "Completed" : "Planning";
  const statusColor = statusRaw === "active" ? "#10b981" : statusRaw === "completed" ? "#64748b" : "#3b82f6";
  const dateRange = formatDateRange(startDate, endDate);

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          background: "linear-gradient(135deg, #0c111d 0%, #0f172a 50%, #0c111d 100%)",
          fontFamily: "system-ui, -apple-system, sans-serif",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* Background glow orbs */}
        <div style={{
          position: "absolute", top: -100, left: "20%",
          width: 600, height: 400,
          background: "radial-gradient(circle, rgba(59,130,246,0.12) 0%, transparent 70%)",
          borderRadius: "50%",
        }} />
        <div style={{
          position: "absolute", bottom: -80, right: "10%",
          width: 500, height: 350,
          background: "radial-gradient(circle, rgba(99,102,241,0.08) 0%, transparent 70%)",
          borderRadius: "50%",
        }} />

        {/* Main content */}
        <div style={{ display: "flex", flexDirection: "column", flex: 1, padding: "64px 72px", justifyContent: "space-between" }}>

          {/* Top: Logo + status badge */}
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
              <div style={{
                width: 40, height: 40, borderRadius: 10,
                background: "linear-gradient(135deg, #3b82f6, #2563eb)",
                display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 20,
              }}>✈</div>
              <span style={{ color: "white", fontSize: 20, fontWeight: 700, letterSpacing: "-0.02em" }}>TripWit</span>
            </div>
            <div style={{
              background: `${statusColor}22`, border: `1px solid ${statusColor}44`,
              borderRadius: 20, padding: "6px 14px",
              color: statusColor, fontSize: 13, fontWeight: 600,
            }}>
              {statusLabel}
            </div>
          </div>

          {/* Center: Trip name + destination */}
          <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            <div style={{
              color: "white",
              fontSize: name.length > 30 ? 52 : name.length > 20 ? 62 : 72,
              fontWeight: 900, lineHeight: 1.05,
              letterSpacing: "-0.03em",
            }}>
              {name}
            </div>
            {destination && (
              <div style={{ display: "flex", alignItems: "center", gap: 8, color: "#94a3b8", fontSize: 22 }}>
                <span>📍</span>
                <span>{destination}</span>
              </div>
            )}
            {dateRange && (
              <div style={{ color: "#64748b", fontSize: 18, marginTop: 4 }}>
                {dateRange}
              </div>
            )}
          </div>

          {/* Bottom: Stats strip */}
          <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
            {dayCount > 0 && (
              <div style={{
                display: "flex", flexDirection: "column", alignItems: "center",
                background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)",
                borderRadius: 12, padding: "12px 20px", minWidth: 80,
              }}>
                <span style={{ color: "white", fontSize: 28, fontWeight: 900 }}>{dayCount}</span>
                <span style={{ color: "#64748b", fontSize: 12, marginTop: 2 }}>day{dayCount !== 1 ? "s" : ""}</span>
              </div>
            )}
            {stopCount > 0 && (
              <div style={{
                display: "flex", flexDirection: "column", alignItems: "center",
                background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)",
                borderRadius: 12, padding: "12px 20px", minWidth: 80,
              }}>
                <span style={{ color: "white", fontSize: 28, fontWeight: 900 }}>{stopCount}</span>
                <span style={{ color: "#64748b", fontSize: 12, marginTop: 2 }}>stop{stopCount !== 1 ? "s" : ""}</span>
              </div>
            )}
            <div style={{ flex: 1 }} />
            <div style={{ color: "#334155", fontSize: 14 }}>
              tripwit.app
            </div>
          </div>
        </div>
      </div>
    ),
    { ...size }
  );
}
