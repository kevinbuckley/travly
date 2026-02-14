import Foundation

// MARK: - TripStats

public struct TripStats: Sendable, Equatable {
    public let totalStops: Int
    public let totalPhotos: Int
    public let totalDistanceKm: Double
    public let categoryCounts: [StopCategory: Int]

    public init(
        totalStops: Int,
        totalPhotos: Int,
        totalDistanceKm: Double,
        categoryCounts: [StopCategory: Int]
    ) {
        self.totalStops = totalStops
        self.totalPhotos = totalPhotos
        self.totalDistanceKm = totalDistanceKm
        self.categoryCounts = categoryCounts
    }
}

// MARK: - ItineraryEngine

public struct ItineraryEngine: Sendable {

    public init() {}

    /// Generate `Day` objects for a trip based on its date range.
    ///
    /// Creates one `Day` per calendar day from `trip.startDate` through `trip.endDate`,
    /// with `dayNumber` starting at 1.
    public static func generateDays(for trip: Trip) -> [Day] {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: trip.startDate)
        let startOfEnd = calendar.startOfDay(for: trip.endDate)

        var days: [Day] = []
        var currentDate = startOfStart
        var dayNumber = 1

        while currentDate <= startOfEnd {
            let day = Day(
                tripId: trip.id,
                date: currentDate,
                dayNumber: dayNumber
            )
            days.append(day)
            dayNumber += 1
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return days
    }

    /// Reorder stops within a day by moving an element from one index to another.
    ///
    /// After the move, `sortOrder` values are re-assigned sequentially starting from 0.
    public static func reorderStops(_ stops: inout [Stop], moving fromIndex: Int, to toIndex: Int) {
        guard fromIndex != toIndex,
              stops.indices.contains(fromIndex),
              stops.indices.contains(toIndex)
        else {
            return
        }

        let element = stops.remove(at: fromIndex)
        stops.insert(element, at: toIndex)

        // Re-assign sortOrder values.
        for i in stops.indices {
            stops[i].sortOrder = i
        }
    }

    /// Calculate aggregate travel statistics for a trip.
    ///
    /// Total distance is computed by summing Haversine distances between consecutive stops
    /// across all days (in the order they appear per day).
    public static func tripStats(_ trip: Trip) -> TripStats {
        var totalStops = 0
        var totalPhotos = 0
        var totalDistanceMeters: Double = 0
        var categoryCounts: [StopCategory: Int] = [:]

        for day in trip.days {
            let sortedStops = day.stops.sorted { $0.sortOrder < $1.sortOrder }
            totalStops += sortedStops.count

            for (index, stop) in sortedStops.enumerated() {
                totalPhotos += stop.matchedPhotos.count
                categoryCounts[stop.category, default: 0] += 1

                if index > 0 {
                    let previous = sortedStops[index - 1]
                    let d = GeoUtils.distance(
                        lat1: previous.latitude,
                        lon1: previous.longitude,
                        lat2: stop.latitude,
                        lon2: stop.longitude
                    )
                    totalDistanceMeters += d
                }
            }
        }

        return TripStats(
            totalStops: totalStops,
            totalPhotos: totalPhotos,
            totalDistanceKm: totalDistanceMeters / 1000.0,
            categoryCounts: categoryCounts
        )
    }
}
