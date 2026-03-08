"use client";

import { useAuth } from "@/contexts/AuthContext";
import AdUnit from "@/components/ads/AdUnit";
import { Check, Loader2 } from "lucide-react";

interface HeaderProps {
  showAds?: boolean;
  saveStatus?: "idle" | "saving" | "saved";
}

export default function Header({ showAds = false, saveStatus = "idle" }: HeaderProps) {
  const { user } = useAuth();

  return (
    <header className="flex items-center gap-4 px-5 h-14 shrink-0 bg-white border-b border-slate-200/60 shadow-[0_1px_0_rgba(0,0,0,0.04)]">
      {/* Save status — left side */}
      <div className="w-24 shrink-0">
        {user && saveStatus !== "idle" && (
          <div className="flex items-center gap-1.5 text-xs">
            {saveStatus === "saving" && (
              <>
                <Loader2 className="w-3 h-3 text-slate-400 animate-spin" />
                <span className="text-slate-400">Saving…</span>
              </>
            )}
            {saveStatus === "saved" && (
              <>
                <Check className="w-3 h-3 text-emerald-500" />
                <span className="text-emerald-600 font-medium">Saved</span>
              </>
            )}
          </div>
        )}
      </div>

      {/* Ads — center */}
      {showAds && user ? (
        <div className="flex-1 flex justify-center">
          <AdUnit slot="LEADERBOARD_SLOT" format="horizontal" style={{ width: 728, height: 90 }} />
        </div>
      ) : (
        <div className="flex-1" />
      )}

      {/* Right spacer (user moved to sidebar) */}
      <div className="w-24 shrink-0" />
    </header>
  );
}
