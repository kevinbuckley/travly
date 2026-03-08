"use client";

import { useState, useCallback } from "react";
import { Plus, Plane, MapPin, Trash2, Upload, Download, Copy } from "lucide-react";
import type { Trip } from "@/lib/types";
import { cn } from "@/components/ui/cn";
import { parseTripwitFile } from "@/lib/tripwit-parser";
import { downloadTripwit } from "@/lib/tripwit-exporter";

interface TripsSidebarProps {
  trips: Trip[];
  selectedTripId: string | null;
  userId: string;
  onSelectTrip: (id: string) => void;
  onCreateTrip: () => void;
  onDeleteTrip: (id: string) => void;
  onImportTrip: (trip: Trip) => void;
  onDuplicateTrip?: (trip: Trip) => void;
}

const STATUS_COLORS: Record<string, string> = {
  planning: "bg-blue-100 text-blue-700",
  active: "bg-green-100 text-green-700",
  completed: "bg-slate-100 text-slate-600",
};

const STATUS_ICONS: Record<string, string> = {
  planning: "📝",
  active: "🧭",
  completed: "✅",
};

function formatTripDates(start: string, end: string): string {
  if (!start) return "";
  try {
    const s = new Date(start + "T12:00:00");
    const e = new Date(end + "T12:00:00");
    const opts: Intl.DateTimeFormatOptions = { month: "short", day: "numeric" };
    if (start === end) return s.toLocaleDateString(undefined, opts);
    return `${s.toLocaleDateString(undefined, opts)} – ${e.toLocaleDateString(undefined, opts)}`;
  } catch {
    return "";
  }
}

export default function TripsSidebar({
  trips,
  selectedTripId,
  userId,
  onSelectTrip,
  onCreateTrip,
  onDeleteTrip,
  onImportTrip,
  onDuplicateTrip,
}: TripsSidebarProps) {
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);
  const [importError, setImportError] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);

  async function handleImport(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    await importFile(file);
    e.target.value = "";
  }

  async function importFile(file: File) {
    try {
      const text = await file.text();
      const json = JSON.parse(text);
      const trip = parseTripwitFile(json, userId);
      onImportTrip(trip);
      setImportError(null);
    } catch {
      setImportError("Could not read .tripwit file.");
      setTimeout(() => setImportError(null), 3000);
    }
  }

  // Drag-and-drop .tripwit import
  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragOver(true);
  }, []);

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragOver(false);
  }, []);

  const handleDrop = useCallback(async (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragOver(false);
    const file = e.dataTransfer.files?.[0];
    if (file && (file.name.endsWith(".tripwit") || file.name.endsWith(".json"))) {
      await importFile(file);
    } else {
      setImportError("Drop a .tripwit file to import.");
      setTimeout(() => setImportError(null), 3000);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId, onImportTrip]);

  const selectedTrip = trips.find((t) => t.id === selectedTripId);

  return (
    <aside
      className={cn(
        "w-64 shrink-0 border-r border-slate-200 bg-white flex flex-col h-full transition-colors",
        dragOver && "bg-blue-50 border-blue-300"
      )}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      {/* Header */}
      <div className="px-3 py-3 border-b border-slate-100 flex items-center justify-between">
        <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
          My Trips
        </span>
        <div className="flex gap-0.5">
          {/* Export selected trip */}
          {selectedTrip && (
            <button
              onClick={() => downloadTripwit(selectedTrip)}
              title="Export as .tripwit"
              className="p-1.5 rounded-md hover:bg-slate-100 cursor-pointer text-slate-400 hover:text-slate-700 transition-colors"
            >
              <Download className="w-4 h-4" />
            </button>
          )}
          {/* Duplicate trip */}
          {selectedTrip && onDuplicateTrip && (
            <button
              onClick={() => onDuplicateTrip(selectedTrip)}
              title="Duplicate trip"
              className="p-1.5 rounded-md hover:bg-slate-100 cursor-pointer text-slate-400 hover:text-slate-700 transition-colors"
            >
              <Copy className="w-4 h-4" />
            </button>
          )}
          {/* Import .tripwit */}
          <label
            title="Import .tripwit file"
            className="p-1.5 rounded-md hover:bg-slate-100 cursor-pointer text-slate-400 hover:text-slate-700 transition-colors"
          >
            <Upload className="w-4 h-4" />
            <input
              type="file"
              accept=".tripwit,.json"
              className="hidden"
              onChange={handleImport}
            />
          </label>
          <button
            onClick={onCreateTrip}
            title="New trip"
            className="p-1.5 rounded-md hover:bg-blue-50 text-blue-500 hover:text-blue-700 transition-colors"
          >
            <Plus className="w-4 h-4" />
          </button>
        </div>
      </div>

      {importError && (
        <div className="mx-3 mt-2 px-2 py-1.5 bg-red-50 text-red-600 text-xs rounded animate-in fade-in">
          {importError}
        </div>
      )}

      {/* Drag overlay */}
      {dragOver && (
        <div className="mx-3 mt-2 px-4 py-6 border-2 border-dashed border-blue-400 rounded-xl bg-blue-50 text-center">
          <Upload className="w-6 h-6 mx-auto mb-1 text-blue-500" />
          <p className="text-xs font-medium text-blue-600">Drop .tripwit file here</p>
        </div>
      )}

      {/* Trip list */}
      <div className="flex-1 overflow-y-auto">
        {trips.length === 0 && !dragOver && (
          <div className="px-4 py-10 text-center">
            <div className="text-4xl mb-3">🗺️</div>
            <Plane className="w-6 h-6 mx-auto mb-2 text-slate-300" />
            <p className="text-sm font-medium text-slate-500 mb-1">No trips yet</p>
            <p className="text-xs text-slate-400 mb-4">
              Create a new trip or drop a .tripwit file here to get started.
            </p>
            <button
              onClick={onCreateTrip}
              className="inline-flex items-center gap-1.5 px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors"
            >
              <Plus className="w-4 h-4" />
              Create Trip
            </button>
          </div>
        )}
        {trips.map((trip) => (
          <div
            key={trip.id}
            className={cn(
              "group flex items-start gap-2.5 px-3 py-3 cursor-pointer border-b border-slate-50 hover:bg-slate-50 transition-colors",
              selectedTripId === trip.id && "bg-blue-50 hover:bg-blue-50 border-l-2 border-l-blue-500"
            )}
            onClick={() => {
              setConfirmDelete(null);
              onSelectTrip(trip.id);
            }}
          >
            <div className="text-base mt-0.5 shrink-0">
              {STATUS_ICONS[trip.statusRaw] ?? "📝"}
            </div>
            <div className="flex-1 min-w-0">
              <div
                className={cn(
                  "text-sm font-medium truncate",
                  selectedTripId === trip.id ? "text-blue-700" : "text-slate-800"
                )}
              >
                {trip.name}
              </div>
              {trip.destination && (
                <div className="text-xs text-slate-400 truncate flex items-center gap-1">
                  <MapPin className="w-3 h-3 shrink-0" />
                  {trip.destination}
                </div>
              )}
              <div className="flex items-center gap-2 mt-1">
                <span
                  className={cn(
                    "text-[10px] px-1.5 py-0.5 rounded-full font-medium capitalize",
                    STATUS_COLORS[trip.statusRaw]
                  )}
                >
                  {trip.statusRaw}
                </span>
                {trip.startDate && (
                  <span className="text-[10px] text-slate-400">
                    {formatTripDates(trip.startDate, trip.endDate)}
                  </span>
                )}
              </div>
              {/* Trip stats */}
              {(trip.days.length > 0 || trip.bookings.length > 0) && (
                <div className="flex items-center gap-2 mt-1 text-[10px] text-slate-400">
                  {trip.days.length > 0 && (
                    <span>{trip.days.length} {trip.days.length === 1 ? "day" : "days"}</span>
                  )}
                  {trip.days.reduce((c, d) => c + d.stops.length, 0) > 0 && (
                    <span>· {trip.days.reduce((c, d) => c + d.stops.length, 0)} stops</span>
                  )}
                </div>
              )}
            </div>
            {/* Delete */}
            {confirmDelete === trip.id ? (
              <div className="flex flex-col gap-0.5 shrink-0">
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    onDeleteTrip(trip.id);
                    setConfirmDelete(null);
                  }}
                  className="text-[10px] text-red-600 font-medium hover:underline"
                >
                  Delete
                </button>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    setConfirmDelete(null);
                  }}
                  className="text-[10px] text-slate-400 hover:underline"
                >
                  Cancel
                </button>
              </div>
            ) : (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setConfirmDelete(trip.id);
                }}
                className="opacity-0 group-hover:opacity-100 p-1 rounded hover:bg-red-50 text-slate-300 hover:text-red-500 transition-all"
              >
                <Trash2 className="w-3.5 h-3.5" />
              </button>
            )}
          </div>
        ))}
      </div>
    </aside>
  );
}
