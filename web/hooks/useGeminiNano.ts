"use client";

import { useState, useEffect, useCallback } from "react";
import type { Booking, BookingType } from "@/lib/types";

// Chrome's Prompt API lives under two namespaces depending on Chrome version.
// Chrome 130+: window.LanguageModel
// Chrome 127–129: window.ai.languageModel
function getChromeAIApi(): { availability: () => Promise<string>; create: (opts: object) => Promise<ChromeAISession> } | null {
  if (typeof window === "undefined") return null;
  return (
    (window as any).LanguageModel ??
    (window as any).ai?.languageModel ??
    null
  );
}

interface ChromeAISession {
  prompt: (text: string) => Promise<string>;
  destroy: () => void;
}

const SYSTEM_PROMPT = `You are a travel booking parser. Extract booking data from confirmation emails.
Return ONLY a valid JSON object — no markdown fences, no explanation, no extra text.
Use this exact schema (omit any field you cannot find):
{
  "typeRaw": "flight" | "hotel" | "car_rental" | "other",
  "title": "short descriptive title e.g. JFK → CDG or Hotel Le Marais",
  "confirmationCode": "booking/confirmation/PNR code",
  "airline": "airline name (flights only)",
  "flightNumber": "e.g. DL234 (flights only)",
  "departureAirport": "3-letter IATA code e.g. JFK (flights only)",
  "arrivalAirport": "3-letter IATA code e.g. CDG (flights only)",
  "departureTime": "ISO 8601 datetime e.g. 2024-06-15T14:30:00 (flights only)",
  "arrivalTime": "ISO 8601 datetime (flights only)",
  "hotelName": "hotel name (hotels only)",
  "hotelAddress": "full street address (hotels only)",
  "checkInDate": "YYYY-MM-DD (hotels only)",
  "checkOutDate": "YYYY-MM-DD (hotels only)",
  "notes": "any other useful details like seat number, meal preference, loyalty number"
}`;

// Fields that map directly from the parsed JSON to the Booking type
const BOOKING_FIELDS: (keyof Booking)[] = [
  "typeRaw", "title", "confirmationCode", "notes",
  "airline", "flightNumber", "departureAirport", "arrivalAirport",
  "departureTime", "arrivalTime",
  "hotelName", "hotelAddress", "checkInDate", "checkOutDate",
];

const VALID_TYPES: BookingType[] = ["flight", "hotel", "car_rental", "other"];

function sanitizeParsed(raw: Record<string, unknown>): Partial<Booking> {
  const out: Partial<Booking> = {};
  for (const key of BOOKING_FIELDS) {
    const val = raw[key];
    if (val === undefined || val === null || val === "") continue;
    if (typeof val === "string") {
      if (key === "typeRaw") {
        if (VALID_TYPES.includes(val as BookingType)) {
          out.typeRaw = val as BookingType;
        }
      } else {
        (out as Record<string, string>)[key] = val;
      }
    }
  }
  return out;
}

export function useGeminiNano() {
  const [available, setAvailable] = useState(false);

  useEffect(() => {
    // Dev override: run  localStorage.setItem('tripwit_debug_ai','1')  in console then reload
    if (typeof localStorage !== "undefined" && localStorage.getItem("tripwit_debug_ai") === "1") {
      setAvailable(true);
      return;
    }
    const api = getChromeAIApi();
    if (!api) return;
    api.availability().then((status) => {
      setAvailable(status !== "unavailable");
    }).catch(() => { /* silently unavailable */ });
  }, []);

  const parseBookingEmail = useCallback(async (emailText: string): Promise<Partial<Booking>> => {
    const api = getChromeAIApi();
    if (!api) throw new Error("Chrome AI not available");

    const session = await api.create({ systemPrompt: SYSTEM_PROMPT, temperature: 0.1 });
    let result: string;
    try {
      result = await session.prompt(
        `Parse this confirmation email and return JSON only:\n\n${emailText.slice(0, 8000)}`
      );
    } finally {
      session.destroy();
    }

    // Strip any accidental markdown fences the model might emit
    const cleaned = result.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
    const parsed = JSON.parse(cleaned) as Record<string, unknown>;
    return sanitizeParsed(parsed);
  }, []);

  return { available, parseBookingEmail };
}
