"use client";

import { useEffect, useState, useCallback, useRef } from "react";
import { useAuth } from "@/contexts/AuthContext";
import Header from "@/components/layout/Header";
import TripsSidebar from "@/components/layout/TripsSidebar";
import TripDetail from "@/components/layout/TripDetail";
import MapPanel from "@/components/layout/MapPanel";
import { getTrips, createTrip, updateTrip, deleteTrip, insertTrip } from "@/lib/db";
import type { Trip, Stop } from "@/lib/types";
import { newId, nowISO } from "@/lib/types";
import { Map } from "lucide-react";

export default function AppPage() {
  const { user, loading, signIn, signOut } = useAuth();

  const [trips, setTrips] = useState<Trip[]>([]);
  const [selectedTripId, setSelectedTripId] = useState<string | null>(null);
  const [selectedStopId, setSelectedStopId] = useState<string | null>(null);
  const [tripsLoading, setTripsLoading] = useState(true);
  const [saveStatus, setSaveStatus] = useState<"idle" | "saving" | "saved">("idle");
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [mapCollapsed, setMapCollapsed] = useState(false);

  useEffect(() => {
    if (!user) return;
    setTripsLoading(true);
    getTrips(user.id)
      .then((data) => {
        setTrips(data);
        if (data.length > 0) setSelectedTripId(data[0].id);
      })
      .finally(() => setTripsLoading(false));
  }, [user]);

  const selectedTrip = trips.find((t) => t.id === selectedTripId) ?? null;
  const mapStops: Stop[] = selectedTrip ? selectedTrip.days.flatMap((d) => d.stops) : [];

  const handleCreateTrip = useCallback(async () => {
    if (!user) return;
    const trip = await createTrip(user.id);
    setTrips((prev) => [trip, ...prev]);
    setSelectedTripId(trip.id);
  }, [user]);

  const handleDeleteTrip = useCallback(async (id: string) => {
    await deleteTrip(id);
    setTrips((prev) => prev.filter((t) => t.id !== id));
    setSelectedTripId((cur) => {
      if (cur !== id) return cur;
      const remaining = trips.filter((t) => t.id !== id);
      return remaining[0]?.id ?? null;
    });
  }, [trips]);

  const handleImportTrip = useCallback(async (trip: Trip) => {
    if (!user) return;
    const tripWithUser = { ...trip, userId: user.id };
    await insertTrip(tripWithUser);
    setTrips((prev) => [tripWithUser, ...prev]);
    setSelectedTripId(trip.id);
  }, [user]);

  const handleDuplicateTrip = useCallback(async (trip: Trip) => {
    if (!user) return;
    const now = nowISO();
    const dupe: Trip = {
      ...JSON.parse(JSON.stringify(trip)),
      id: newId(),
      userId: user.id,
      name: `${trip.name} (copy)`,
      isPublic: false,
      createdAt: now,
      updatedAt: now,
    };
    dupe.days = dupe.days.map((d: Trip["days"][0]) => ({
      ...d, id: newId(),
      stops: d.stops.map((s: Stop) => ({
        ...s, id: newId(),
        todos: s.todos.map((t) => ({ ...t, id: newId() })),
        links: s.links.map((l) => ({ ...l, id: newId() })),
        comments: s.comments.map((c) => ({ ...c, id: newId() })),
      })),
    }));
    dupe.bookings = dupe.bookings.map((b: Trip["bookings"][0]) => ({ ...b, id: newId() }));
    dupe.expenses = dupe.expenses.map((e: Trip["expenses"][0]) => ({ ...e, id: newId() }));
    dupe.lists = dupe.lists.map((l: Trip["lists"][0]) => ({
      ...l, id: newId(), items: l.items.map((i) => ({ ...i, id: newId() })),
    }));
    await insertTrip(dupe);
    setTrips((prev) => [dupe, ...prev]);
    setSelectedTripId(dupe.id);
  }, [user]);

  const handleUpdateTrip = useCallback(async (changes: Partial<Trip>) => {
    if (!selectedTripId) return;
    setTrips((prev) => prev.map((t) => (t.id === selectedTripId ? { ...t, ...changes } : t)));
    setSaveStatus("saving");
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(async () => {
      try {
        await updateTrip(selectedTripId, changes);
        setSaveStatus("saved");
        setTimeout(() => setSaveStatus("idle"), 1500);
      } catch { setSaveStatus("idle"); }
    }, 600);
  }, [selectedTripId]);

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === "n") { e.preventDefault(); handleCreateTrip(); }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [handleCreateTrip]);

  // ── Auth loading ───────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="h-screen flex items-center justify-center bg-[#0c111d]">
        <div className="flex flex-col items-center gap-4">
          <div className="w-10 h-10 rounded-2xl bg-blue-600 flex items-center justify-center shadow-lg text-lg">✈</div>
          <div className="w-5 h-5 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
        </div>
      </div>
    );
  }

  // ── Sign-in screen ────────────────────────────────────────────────────────
  if (!user) {
    return (
      <div className="h-screen flex flex-col bg-[#0c111d]">
        <nav className="px-6 h-14 flex items-center border-b border-white/6 shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="w-7 h-7 rounded-xl bg-blue-600 flex items-center justify-center shadow-sm">
              <span className="text-white text-sm">✈</span>
            </div>
            <span className="text-white font-semibold text-[15px]">TripWit</span>
          </div>
        </nav>
        <div className="flex-1 flex flex-col items-center justify-center px-6 relative overflow-hidden">
          <div className="absolute inset-0 overflow-hidden pointer-events-none">
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[400px] bg-blue-600/15 rounded-full blur-[100px]" />
          </div>
          <div className="relative text-center max-w-xs">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-blue-500 to-blue-700 flex items-center justify-center mx-auto mb-6 shadow-[0_8px_32px_rgba(59,130,246,0.4)] text-3xl">
              ✈️
            </div>
            <h1 className="text-2xl font-bold text-white mb-2 tracking-tight">Welcome to TripWit</h1>
            <p className="text-slate-400 text-sm leading-relaxed mb-8">
              Sign in to start planning your trips. Your itineraries, bookings, and budget — all in one beautiful workspace.
            </p>
            <button
              onClick={signIn}
              className="inline-flex items-center gap-3 w-full justify-center px-5 py-3 bg-white text-slate-800 rounded-xl font-semibold text-sm hover:bg-slate-50 transition-colors shadow-lg"
            >
              <svg className="w-4 h-4" viewBox="0 0 24 24">
                <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
              </svg>
              Continue with Google
            </button>
            <p className="text-xs text-slate-600 mt-4">Free forever · No credit card required</p>
          </div>
        </div>
      </div>
    );
  }

  // ── Trips loading ─────────────────────────────────────────────────────────
  if (tripsLoading) {
    return (
      <div className="h-screen flex items-center justify-center bg-slate-50">
        <div className="flex flex-col items-center gap-3">
          <div className="w-5 h-5 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
          <span className="text-sm text-slate-400">Loading your trips…</span>
        </div>
      </div>
    );
  }

  // ── Main app — sidebar spans full height, header only above content ────────
  return (
    <div className="h-screen flex overflow-hidden">
      {/* Sidebar — full height */}
      <TripsSidebar
        trips={trips}
        selectedTripId={selectedTripId}
        userId={user.id}
        user={user}
        onSelectTrip={(id) => { setSelectedTripId(id); setSelectedStopId(null); }}
        onCreateTrip={handleCreateTrip}
        onDeleteTrip={handleDeleteTrip}
        onImportTrip={handleImportTrip}
        onDuplicateTrip={handleDuplicateTrip}
        onSignOut={signOut}
      />

      {/* Right panel: header + content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        <Header showAds={true} saveStatus={saveStatus} />

        <div className="flex flex-1 overflow-hidden">
          {/* Center: Trip detail or empty state */}
          {selectedTrip ? (
            <TripDetail
              trip={selectedTrip}
              showAds={true}
              onUpdateTrip={handleUpdateTrip}
              onSelectStop={setSelectedStopId}
              selectedStopId={selectedStopId}
            />
          ) : (
            <div className="flex-1 flex flex-col items-center justify-center text-center px-8 bg-slate-50">
              <div className="w-16 h-16 rounded-2xl bg-white border border-slate-200 shadow-card flex items-center justify-center text-3xl mb-4">
                🗺️
              </div>
              <h2 className="text-lg font-semibold text-slate-800 mb-1.5">
                {trips.length === 0 ? "Plan your first adventure" : "Select a trip"}
              </h2>
              <p className="text-sm text-slate-400 max-w-xs mb-5 leading-relaxed">
                {trips.length === 0
                  ? "Create a trip to start building your itinerary with days, stops, bookings, and more."
                  : "Pick a trip from the sidebar to view and edit it."}
              </p>
              {trips.length === 0 && (
                <button
                  onClick={handleCreateTrip}
                  className="inline-flex items-center gap-2 px-5 py-2.5 bg-blue-600 text-white text-sm font-semibold rounded-xl hover:bg-blue-700 transition-colors shadow-sm"
                >
                  ✈️ Create Your First Trip
                </button>
              )}
            </div>
          )}

          {/* Right: Map (collapsible) */}
          {!mapCollapsed ? (
            <div className="w-96 shrink-0 border-l border-slate-200 relative bg-slate-100">
              <button
                onClick={() => setMapCollapsed(true)}
                className="absolute top-3 left-3 z-[1000] flex items-center gap-1.5 bg-white/95 backdrop-blur-sm rounded-xl px-2.5 py-1.5 text-xs font-medium text-slate-600 hover:text-slate-900 shadow-[0_1px_4px_rgba(0,0,0,0.12)] hover:shadow-[0_2px_8px_rgba(0,0,0,0.15)] transition-all border border-slate-200/80"
              >
                <Map className="w-3 h-3" />
                Hide map
              </button>
              <MapPanel stops={mapStops} selectedStopId={selectedStopId} onSelectStop={setSelectedStopId} />
            </div>
          ) : (
            <button
              onClick={() => setMapCollapsed(false)}
              className="shrink-0 w-9 border-l border-slate-200 flex flex-col items-center justify-center gap-1.5 bg-slate-50 hover:bg-slate-100 transition-colors group"
              title="Show map"
            >
              <Map className="w-3.5 h-3.5 text-slate-400 group-hover:text-slate-600 transition-colors" />
              <span className="text-[10px] text-slate-400 group-hover:text-slate-600 font-medium transition-colors [writing-mode:vertical-lr] rotate-180 tracking-wide">
                Map
              </span>
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
