import { createClient } from "./supabase";
import type { Trip } from "./types";
import { newId, nowISO } from "./types";

// ─── Row ↔ Trip converters ────────────────────────────────────────────────────

type TripRow = Record<string, unknown>;

function rowToTrip(row: TripRow): Trip {
  return {
    id: row.id as string,
    userId: row.user_id as string,
    isPublic: row.is_public as boolean,
    name: row.name as string,
    destination: row.destination as string,
    statusRaw: row.status_raw as Trip["statusRaw"],
    notes: row.notes as string,
    hasCustomDates: row.has_custom_dates as boolean,
    budgetAmount: row.budget_amount as number,
    budgetCurrencyCode: row.budget_currency_code as string,
    startDate: row.start_date as string,
    endDate: row.end_date as string,
    createdAt: row.created_at as string,
    updatedAt: row.updated_at as string,
    days: (row.days as Trip["days"]) ?? [],
    bookings: (row.bookings as Trip["bookings"]) ?? [],
    lists: (row.lists as Trip["lists"]) ?? [],
    expenses: (row.expenses as Trip["expenses"]) ?? [],
  };
}

function tripToRow(trip: Trip): TripRow {
  return {
    id: trip.id,
    user_id: trip.userId,
    is_public: trip.isPublic,
    name: trip.name,
    destination: trip.destination,
    status_raw: trip.statusRaw,
    notes: trip.notes,
    has_custom_dates: trip.hasCustomDates,
    budget_amount: trip.budgetAmount,
    budget_currency_code: trip.budgetCurrencyCode,
    start_date: trip.startDate,
    end_date: trip.endDate,
    days: trip.days,
    bookings: trip.bookings,
    lists: trip.lists,
    expenses: trip.expenses,
  };
}

function changesToRow(changes: Partial<Trip>): TripRow {
  const row: TripRow = { updated_at: nowISO() };
  if (changes.isPublic !== undefined) row.is_public = changes.isPublic;
  if (changes.name !== undefined) row.name = changes.name;
  if (changes.destination !== undefined) row.destination = changes.destination;
  if (changes.statusRaw !== undefined) row.status_raw = changes.statusRaw;
  if (changes.notes !== undefined) row.notes = changes.notes;
  if (changes.hasCustomDates !== undefined) row.has_custom_dates = changes.hasCustomDates;
  if (changes.budgetAmount !== undefined) row.budget_amount = changes.budgetAmount;
  if (changes.budgetCurrencyCode !== undefined) row.budget_currency_code = changes.budgetCurrencyCode;
  if (changes.startDate !== undefined) row.start_date = changes.startDate;
  if (changes.endDate !== undefined) row.end_date = changes.endDate;
  if (changes.days !== undefined) row.days = changes.days;
  if (changes.bookings !== undefined) row.bookings = changes.bookings;
  if (changes.lists !== undefined) row.lists = changes.lists;
  if (changes.expenses !== undefined) row.expenses = changes.expenses;
  return row;
}

// ─── CRUD ─────────────────────────────────────────────────────────────────────

export async function getTrips(userId: string): Promise<Trip[]> {
  const supabase = createClient();
  const { data, error } = await supabase
    .from("trips")
    .select("*")
    .eq("user_id", userId)
    .order("updated_at", { ascending: false });
  if (error) throw error;
  return (data ?? []).map(rowToTrip);
}

export async function getTrip(tripId: string): Promise<Trip | null> {
  const supabase = createClient();
  const { data, error } = await supabase
    .from("trips")
    .select("*")
    .eq("id", tripId)
    .single();
  if (error) return null;
  return rowToTrip(data);
}

export async function createTrip(userId: string, partial: Partial<Trip> = {}): Promise<Trip> {
  const now = nowISO();
  const trip: Trip = {
    id: newId(),
    userId,
    isPublic: false,
    name: "New Trip",
    destination: "",
    statusRaw: "planning",
    notes: "",
    hasCustomDates: false,
    budgetAmount: 0,
    budgetCurrencyCode: "USD",
    startDate: now,
    endDate: now,
    createdAt: now,
    updatedAt: now,
    days: [],
    bookings: [],
    lists: [],
    expenses: [],
    ...partial,
  };
  const supabase = createClient();
  const { error } = await supabase.from("trips").insert(tripToRow(trip));
  if (error) throw error;
  return trip;
}

export async function insertTrip(trip: Trip): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.from("trips").upsert(tripToRow(trip));
  if (error) throw error;
}

export async function updateTrip(tripId: string, changes: Partial<Trip>): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase
    .from("trips")
    .update(changesToRow(changes))
    .eq("id", tripId);
  if (error) throw error;
}

export async function deleteTrip(tripId: string): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.from("trips").delete().eq("id", tripId);
  if (error) throw error;
}
