"use client";

import dynamic from "next/dynamic";
import type { Stop } from "@/lib/types";

const TripMap = dynamic(() => import("@/components/map/TripMap"), {
  ssr: false,
  loading: () => (
    <div className="h-full flex flex-col items-center justify-center gap-3 bg-[#f2f0eb]">
      <div className="w-5 h-5 border-2 border-slate-400 border-t-transparent rounded-full animate-spin opacity-40" />
    </div>
  ),
});

interface MapPanelProps {
  stops: Stop[];
  selectedStopId?: string | null;
  onSelectStop?: (id: string) => void;
}

export default function MapPanel({ stops, selectedStopId, onSelectStop }: MapPanelProps) {
  return (
    <div className="h-full w-full">
      <TripMap
        stops={stops}
        selectedStopId={selectedStopId}
        onSelectStop={onSelectStop}
      />
    </div>
  );
}
