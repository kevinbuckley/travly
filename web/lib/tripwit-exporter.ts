/**
 * Exports a web Trip to the .tripwit JSON format compatible with the iOS app.
 * Matches TripTransfer schema v2 exactly — dates are ISO 8601 strings.
 */
import type { Trip } from "./types";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function tripToTripwit(trip: Trip): Record<string, any> {
  return {
    schemaVersion: 2,
    name: trip.name,
    destination: trip.destination,
    startDate: trip.startDate,
    endDate: trip.endDate,
    statusRaw: trip.statusRaw,
    notes: trip.notes,
    hasCustomDates: trip.hasCustomDates,
    budgetAmount: trip.budgetAmount,
    budgetCurrencyCode: trip.budgetCurrencyCode,
    days: trip.days.map((day) => ({
      date: day.date,
      dayNumber: day.dayNumber,
      notes: day.notes,
      location: day.location,
      locationLatitude: day.locationLatitude,
      locationLongitude: day.locationLongitude,
      stops: day.stops.map((stop) => ({
        name: stop.name,
        latitude: stop.latitude,
        longitude: stop.longitude,
        arrivalTime: stop.arrivalTime ?? null,
        departureTime: stop.departureTime ?? null,
        categoryRaw: stop.categoryRaw,
        notes: stop.notes,
        sortOrder: stop.sortOrder,
        isVisited: stop.isVisited,
        visitedAt: stop.visitedAt ?? null,
        rating: stop.rating,
        address: stop.address ?? null,
        phone: stop.phone ?? null,
        website: stop.website ?? null,
        comments: stop.comments.map((c) => ({
          text: c.text,
          createdAt: c.createdAt,
        })),
        links: stop.links.map((l) => ({
          title: l.title,
          url: l.url,
          sortOrder: l.sortOrder,
        })),
        todos: stop.todos.map((t) => ({
          text: t.text,
          isCompleted: t.isCompleted,
          sortOrder: t.sortOrder,
        })),
        confirmationCode: stop.confirmationCode ?? null,
        checkOutDate: stop.checkOutDate ?? null,
        airline: stop.airline ?? null,
        flightNumber: stop.flightNumber ?? null,
        departureAirport: stop.departureAirport ?? null,
        arrivalAirport: stop.arrivalAirport ?? null,
      })),
    })),
    bookings: trip.bookings.map((b) => ({
      typeRaw: b.typeRaw,
      title: b.title,
      confirmationCode: b.confirmationCode,
      notes: b.notes,
      sortOrder: b.sortOrder,
      airline: b.airline ?? null,
      flightNumber: b.flightNumber ?? null,
      departureAirport: b.departureAirport ?? null,
      arrivalAirport: b.arrivalAirport ?? null,
      departureTime: b.departureTime ?? null,
      arrivalTime: b.arrivalTime ?? null,
      hotelName: b.hotelName ?? null,
      hotelAddress: b.hotelAddress ?? null,
      checkInDate: b.checkInDate ?? null,
      checkOutDate: b.checkOutDate ?? null,
    })),
    lists: trip.lists.map((l) => ({
      name: l.name,
      icon: l.icon,
      sortOrder: l.sortOrder,
      items: l.items.map((i) => ({
        text: i.text,
        isChecked: i.isChecked,
        sortOrder: i.sortOrder,
      })),
    })),
    expenses: trip.expenses.map((e) => ({
      title: e.title,
      amount: e.amount,
      currencyCode: e.currencyCode,
      dateIncurred: e.dateIncurred,
      categoryRaw: e.categoryRaw,
      notes: e.notes,
      sortOrder: e.sortOrder,
      createdAt: e.createdAt,
    })),
  };
}

export function downloadTripwit(trip: Trip) {
  const data = tripToTripwit(trip);
  const json = JSON.stringify(data, null, 2);
  const blob = new Blob([json], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  // Sanitize trip name for filename
  const safeName = trip.name.replace(/[^a-zA-Z0-9-_ ]/g, "").trim() || "trip";
  a.download = `${safeName}.tripwit`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
