import Foundation

// MARK: - Chart Data Points

/// One bar in a "stops per day" bar chart.
public struct DayActivityPoint: Identifiable, Hashable, Sendable {
    public let id: Int            // dayNumber
    public let dayNumber: Int
    public let label: String      // "Day 1"
    public let stopCount: Int
    public let visitedCount: Int

    public init(dayNumber: Int, label: String, stopCount: Int, visitedCount: Int) {
        self.id           = dayNumber
        self.dayNumber    = dayNumber
        self.label        = label
        self.stopCount    = stopCount
        self.visitedCount = visitedCount
    }
}

/// One slice of a category breakdown pie/donut chart.
public struct CategorySlice: Identifiable, Hashable, Sendable {
    public let id: String      // StopCategory rawValue
    public let category: StopCategory
    public let count: Int
    public let fraction: Double    // 0…1 share of the total

    public init(category: StopCategory, count: Int, fraction: Double) {
        self.id       = category.rawValue
        self.category = category
        self.count    = count
        self.fraction = fraction
    }
}

/// One point in a cumulative-visited-stops area chart.
public struct CumulativeProgressPoint: Identifiable, Hashable, Sendable {
    public let id: Int        // dayNumber
    public let dayNumber: Int
    public let label: String
    public let cumulativeVisited: Int

    public init(dayNumber: Int, label: String, cumulativeVisited: Int) {
        self.id               = dayNumber
        self.dayNumber        = dayNumber
        self.label            = label
        self.cumulativeVisited = cumulativeVisited
    }
}

/// Overall visited/remaining snapshot for a gauge or donut.
public struct ProgressSnapshot: Hashable, Sendable {
    public let totalStops: Int
    public let visitedStops: Int
    public let remainingStops: Int
    /// Fraction of stops visited, clamped 0…1.
    public let visitedFraction: Double

    public init(totalStops: Int, visitedStops: Int) {
        let visited          = max(0, min(visitedStops, totalStops))
        self.totalStops      = totalStops
        self.visitedStops    = visited
        self.remainingStops  = max(0, totalStops - visited)
        self.visitedFraction = totalStops > 0 ? Double(visited) / Double(totalStops) : 0
    }
}

// MARK: - Data Source

/// Transforms ``Day`` arrays into chart-ready data points for Swift Charts.
///
/// All methods are pure functions — no side effects, safe to call from any context.
public enum TripStatsDataSource {

    // MARK: - Day Activity (bar chart: stops per day)

    /// Returns one ``DayActivityPoint`` per day, sorted by day number.
    public static func dayActivityPoints(from days: [Day]) -> [DayActivityPoint] {
        days
            .sorted { $0.dayNumber < $1.dayNumber }
            .map { day in
                DayActivityPoint(
                    dayNumber:    day.dayNumber,
                    label:        "Day \(day.dayNumber)",
                    stopCount:    day.stops.count,
                    visitedCount: 0     // visited state lives on entities, not TripCore Stop
                )
            }
    }

    // MARK: - Category Breakdown (pie / donut chart)

    /// Returns one ``CategorySlice`` per ``StopCategory`` that has at least one stop,
    /// sorted descending by count.
    public static func categoryBreakdown(from days: [Day]) -> [CategorySlice] {
        var counts: [StopCategory: Int] = [:]
        for stop in days.flatMap(\.stops) {
            counts[stop.category, default: 0] += 1
        }
        let total = counts.values.reduce(0, +)
        guard total > 0 else { return [] }

        return counts
            .map { category, count in
                CategorySlice(
                    category: category,
                    count: count,
                    fraction: Double(count) / Double(total)
                )
            }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Progress Snapshot (gauge / summary card)

    /// Returns a ``ProgressSnapshot`` counting all stops across `days`.
    ///
    /// - Note: `visitedCount` is the number of stops for which `isVisited` cannot be
    ///   read in TripCore (no Core Data here). Pass pre-computed counts using the
    ///   two-parameter overload when you have that information.
    public static func progressSnapshot(from days: [Day]) -> ProgressSnapshot {
        let total = days.flatMap(\.stops).count
        return ProgressSnapshot(totalStops: total, visitedStops: 0)
    }

    /// Returns a ``ProgressSnapshot`` with explicit visited / total counts.
    public static func progressSnapshot(totalStops: Int, visitedStops: Int) -> ProgressSnapshot {
        ProgressSnapshot(totalStops: totalStops, visitedStops: visitedStops)
    }

    // MARK: - Cumulative Progress (area / line chart)

    /// Returns one ``CumulativeProgressPoint`` per day showing how many stops
    /// have been visited up to and including that day, using the provided per-day
    /// visited counts (keyed by dayNumber).
    public static func cumulativeProgress(
        from days: [Day],
        visitedPerDay: [Int: Int] = [:]
    ) -> [CumulativeProgressPoint] {
        var running = 0
        return days
            .sorted { $0.dayNumber < $1.dayNumber }
            .map { day in
                running += visitedPerDay[day.dayNumber, default: 0]
                return CumulativeProgressPoint(
                    dayNumber:         day.dayNumber,
                    label:             "Day \(day.dayNumber)",
                    cumulativeVisited: running
                )
            }
    }

    // MARK: - Busiest Day

    /// Returns the day with the most stops, or `nil` if there are no stops.
    public static func busiestDay(from days: [Day]) -> Day? {
        days.max { $0.stops.count < $1.stops.count }
            .flatMap { $0.stops.isEmpty ? nil : $0 }
    }

    // MARK: - Average stops per day

    /// Mean stops per day across all days (including empty days).
    public static func averageStopsPerDay(from days: [Day]) -> Double {
        guard !days.isEmpty else { return 0 }
        let total = days.flatMap(\.stops).count
        return Double(total) / Double(days.count)
    }
}
