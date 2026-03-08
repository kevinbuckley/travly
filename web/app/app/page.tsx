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

export default function AppPage() {
  const { user, loading } = useAuth();

  const [trips, setTrips] = useState<Trip[]>([]);
  const [selectedTripId, setSelectedTripId] = useState<string | null>(null);
  const [selectedStopId, setSelectedStopId] = useState<string | null>(null);
  const [tripsLoading, setTripsLoading] = useState(true);
  const [saveStatus, setSaveStatus] = useState<"idle" | "saving" | "saved">("idle");
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [mapCollapsed, setMapCollapsed] = useState(false);

  // Load trips
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

  const mapStops: Stop[] = selectedTrip
    ? selectedTrip.days.flatMap((d) => d.stops)
    : [];

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
    // Assign new IDs to all nested entities
    dupe.days = dupe.days.map((d: Trip["days"][0]) => ({
      ...d,
      id: newId(),
      stops: d.stops.map((s: Stop) => ({
        ...s,
        id: newId(),
        todos: s.todos.map((t) => ({ ...t, id: newId() })),
        links: s.links.map((l) => ({ ...l, id: newId() })),
        comments: s.comments.map((c) => ({ ...c, id: newId() })),
      })),
    }));
    dupe.bookings = dupe.bookings.map((b: Trip["bookings"][0]) => ({ ...b, id: newId() }));
    dupe.expenses = dupe.expenses.map((e: Trip["expenses"][0]) => ({ ...e, id: newId() }));
    dupe.lists = dupe.lists.map((l: Trip["lists"][0]) => ({
      ...l,
      id: newId(),
      items: l.items.map((i) => ({ ...i, id: newId() })),
    }));

    await insertTrip(dupe);
    setTrips((prev) => [dupe, ...prev]);
    setSelectedTripId(dupe.id);
  }, [user]);

  // Debounced save with status indicator
  const handleUpdateTrip = useCallback(async (changes: Partial<Trip>) => {
    if (!selectedTripId) return;
    // Optimistic update
    setTrips((prev) =>
      prev.map((t) => (t.id === selectedTripId ? { ...t, ...changes } : t))
    );
    // Show saving indicator
    setSaveStatus("saving");
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(async () => {
      try {
        await updateTrip(selectedTripId, changes);
        setSaveStatus("saved");
        setTimeout(() => setSaveStatus("idle"), 1500);
      } catch {
        setSaveStatus("idle");
      }
    }, 600);
  }, [selectedTripId]);

  // Keyboard shortcuts
  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      // Cmd/Ctrl+N = new trip
      if ((e.metaKey || e.ctrlKey) && e.key === "n") {
        e.preventDefault();
        handleCreateTrip();
      }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [handleCreateTrip]);

  if (loading) {
    return (
      <div className="h-screen flex items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <div className="w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
          <span className="text-sm text-slate-400">Loading…</span>
        </div>
      </div>
    );
  }

  // Not signed in
  if (!user) {
    return (
      <div className="h-screen flex flex-col">
        <Header showAds={false} />
        <div className="flex-1 flex flex-col items-center justify-center gap-6 px-4">
          <div className="text-5xl">✈️</div>
          <div className="text-center">
            <h1 className="text-2xl font-bold text-slate-800 mb-2">Welcome to TripWit</h1>
            <p className="text-slate-500 text-sm max-w-xs">
              Sign in with Google to start planning your trips and access them from any device.
            </p>
          </div>
        </div>
      </div>
    );
  }

  if (tripsLoading) {
    return (
      <div className="h-screen flex items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <div className="w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
          <span className="text-sm text-slate-400">Loading trips…</span>
        </div>
      </div>
    );
  }

  return (
    <div className="h-screen flex flex-col overflow-hidden">
      <Header showAds={true} saveStatus={saveStatus} />
      <div className="flex flex-1 overflow-hidden">
        {/* Left: Trips sidebar */}
        <TripsSidebar
          trips={trips}
          selectedTripId={selectedTripId}
          userId={user.id}
          onSelectTrip={(id) => {
            setSelectedTripId(id);
            setSelectedStopId(null);
          }}
          onCreateTrip={handleCreateTrip}
          onDeleteTrip={handleDeleteTrip}
          onImportTrip={handleImportTrip}
          onDuplicateTrip={handleDuplicateTrip}
        />

        {/* Center: Trip detail */}
        {selectedTrip ? (
          <TripDetail
            trip={selectedTrip}
            showAds={true}
            onUpdateTrip={handleUpdateTrip}
            onSelectStop={setSelectedStopId}
            selectedStopId={selectedStopId}
          />
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center text-center px-8">
            <div className="text-5xl mb-4">🗺️</div>
            <h2 className="text-lg font-semibold text-slate-700 mb-1">
              {trips.length === 0 ? "Plan your first adventure" : "Select a trip"}
            </h2>
            <p className="text-sm text-slate-400 max-w-sm mb-4">
              {trips.length === 0
                ? "Create a trip to start building your itinerary with days, stops, bookings, and more."
                : "Pick a trip from the sidebar to view and edit it."}
            </p>
            {trips.length === 0 && (
              <button
                onClick={handleCreateTrip}
                className="inline-flex items-center gap-2 px-5 py-2.5 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors"
              >
                Create Your First Trip
              </button>
            )}
          </div>
        )}

        {/* Right: Map (collapsible) */}
        {!mapCollapsed && (
          <div className="w-96 shrink-0 border-l border-slate-200 relative">
            <button
              onClick={() => setMapCollapsed(true)}
              className="absolute top-2 left-2 z-[1000] bg-white rounded-md shadow-md px-2 py-1 text-xs text-slate-500 hover:text-slate-800 hover:bg-slate-50 transition-colors"
              title="Hide map"
            >
              ✕ Map
            </button>
            <MapPanel
              stops={mapStops}
              selectedStopId={selectedStopId}
              onSelectStop={setSelectedStopId}
            />
          </div>
        )}
        {mapCollapsed && (
          <button
            onClick={() => setMapCollapsed(false)}
            className="shrink-0 w-10 border-l border-slate-200 flex items-center justify-center bg-slate-50 hover:bg-slate-100 transition-colors"
            title="Show map"
          >
            <span className="text-xs text-slate-500 [writing-mode:vertical-lr] rotate-180">🗺️ Map</span>
          </button>
        )}
      </div>
    </div>
  );
}
