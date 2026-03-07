import Foundation
import Testing

@testable import TripCore

// MARK: - Helpers

private func makeDay(number: Int, stops: Int = 0, category: StopCategory = .attraction) -> Day {
    let tripId = UUID()
    let dayId  = UUID()
    let date   = Calendar.current.date(
        byAdding: .day, value: number - 1,
        to: Calendar.current.startOfDay(for: Date())
    ) ?? Date()

    let stopList = (0..<stops).map { i in
        Stop(dayId: dayId, name: "Stop \(i)", latitude: 0, longitude: 0, category: category, sortOrder: i)
    }
    return Day(id: dayId, tripId: tripId, date: date, dayNumber: number, stops: stopList)
}

@Suite("TripStatsDataSource Tests")
struct TripStatsDataSourceTests {

    // MARK: - dayActivityPoints

    @Test("Empty days returns empty activity points")
    func activityPointsEmpty() {
        #expect(TripStatsDataSource.dayActivityPoints(from: []).isEmpty)
    }

    @Test("Activity points count equals number of days")
    func activityPointsCount() {
        let days = [makeDay(number: 1, stops: 2),
                    makeDay(number: 2, stops: 0),
                    makeDay(number: 3, stops: 5)]
        let points = TripStatsDataSource.dayActivityPoints(from: days)
        #expect(points.count == 3)
    }

    @Test("Activity points are sorted by day number")
    func activityPointsSorted() {
        let days = [makeDay(number: 3), makeDay(number: 1), makeDay(number: 2)]
        let points = TripStatsDataSource.dayActivityPoints(from: days)
        #expect(points.map(\.dayNumber) == [1, 2, 3])
    }

    @Test("Activity point stopCount matches day stops")
    func activityPointStopCount() {
        let days = [makeDay(number: 1, stops: 4)]
        let point = TripStatsDataSource.dayActivityPoints(from: days)[0]
        #expect(point.stopCount == 4)
        #expect(point.label == "Day 1")
    }

    // MARK: - categoryBreakdown

    @Test("Empty days returns empty category slices")
    func categoryBreakdownEmpty() {
        #expect(TripStatsDataSource.categoryBreakdown(from: []).isEmpty)
    }

    @Test("Single category gets fraction 1.0")
    func categoryBreakdownSingleCategory() {
        let days = [makeDay(number: 1, stops: 3, category: .restaurant)]
        let slices = TripStatsDataSource.categoryBreakdown(from: days)
        #expect(slices.count == 1)
        #expect(slices[0].category == .restaurant)
        #expect(slices[0].count == 3)
        #expect(abs(slices[0].fraction - 1.0) < 0.0001)
    }

    @Test("Two equal categories each get fraction 0.5")
    func categoryBreakdownEqualSplit() {
        let day1 = makeDay(number: 1, stops: 2, category: .attraction)
        let day2 = makeDay(number: 2, stops: 2, category: .restaurant)
        let slices = TripStatsDataSource.categoryBreakdown(from: [day1, day2])
        #expect(slices.count == 2)
        for slice in slices { #expect(abs(slice.fraction - 0.5) < 0.0001) }
    }

    @Test("Category breakdown sorted descending by count")
    func categoryBreakdownSortOrder() {
        let days = [
            makeDay(number: 1, stops: 1, category: .transport),
            makeDay(number: 2, stops: 3, category: .attraction),
            makeDay(number: 3, stops: 2, category: .restaurant)
        ]
        let slices = TripStatsDataSource.categoryBreakdown(from: days)
        #expect(slices.map(\.count) == slices.map(\.count).sorted(by: >))
    }

    // MARK: - progressSnapshot

    @Test("Progress snapshot zero when no stops")
    func progressSnapshotEmpty() {
        let snap = TripStatsDataSource.progressSnapshot(totalStops: 0, visitedStops: 0)
        #expect(snap.visitedFraction == 0)
        #expect(snap.remainingStops == 0)
    }

    @Test("Progress snapshot half-complete")
    func progressSnapshotHalf() {
        let snap = TripStatsDataSource.progressSnapshot(totalStops: 10, visitedStops: 5)
        #expect(abs(snap.visitedFraction - 0.5) < 0.0001)
        #expect(snap.remainingStops == 5)
    }

    @Test("Progress snapshot clamps over-visited count")
    func progressSnapshotClamps() {
        let snap = TripStatsDataSource.progressSnapshot(totalStops: 5, visitedStops: 999)
        #expect(snap.visitedFraction == 1.0)
        #expect(snap.visitedStops == 5)
        #expect(snap.remainingStops == 0)
    }

    // MARK: - cumulativeProgress

    @Test("Cumulative progress with no visits all zero")
    func cumulativeProgressAllZero() {
        let days = [makeDay(number: 1, stops: 2), makeDay(number: 2, stops: 3)]
        let points = TripStatsDataSource.cumulativeProgress(from: days)
        #expect(points.allSatisfy { $0.cumulativeVisited == 0 })
    }

    @Test("Cumulative progress accumulates across days")
    func cumulativeProgressAccumulates() {
        let days = [makeDay(number: 1), makeDay(number: 2), makeDay(number: 3)]
        let visited = [1: 2, 2: 3, 3: 1]
        let points = TripStatsDataSource.cumulativeProgress(from: days, visitedPerDay: visited)
        #expect(points[0].cumulativeVisited == 2)
        #expect(points[1].cumulativeVisited == 5)
        #expect(points[2].cumulativeVisited == 6)
    }

    @Test("Cumulative progress sorted by day number")
    func cumulativeProgressSorted() {
        let days = [makeDay(number: 3), makeDay(number: 1), makeDay(number: 2)]
        let points = TripStatsDataSource.cumulativeProgress(from: days)
        #expect(points.map(\.dayNumber) == [1, 2, 3])
    }

    // MARK: - busiestDay

    @Test("Busiest day returns day with most stops")
    func busiestDay() {
        let days = [makeDay(number: 1, stops: 1),
                    makeDay(number: 2, stops: 5),
                    makeDay(number: 3, stops: 2)]
        #expect(TripStatsDataSource.busiestDay(from: days)?.dayNumber == 2)
    }

    @Test("Busiest day returns nil for empty days")
    func busiestDayEmpty() {
        #expect(TripStatsDataSource.busiestDay(from: []) == nil)
    }

    @Test("Busiest day returns nil when all days are empty")
    func busiestDayAllEmpty() {
        let days = [makeDay(number: 1), makeDay(number: 2)]
        #expect(TripStatsDataSource.busiestDay(from: days) == nil)
    }

    // MARK: - averageStopsPerDay

    @Test("Average stops per day is zero for empty input")
    func averageStopsEmpty() {
        #expect(TripStatsDataSource.averageStopsPerDay(from: []) == 0)
    }

    @Test("Average stops per day computes correctly")
    func averageStopsComputed() {
        let days = [makeDay(number: 1, stops: 4),
                    makeDay(number: 2, stops: 2),
                    makeDay(number: 3, stops: 0)]
        let avg = TripStatsDataSource.averageStopsPerDay(from: days)
        #expect(abs(avg - 2.0) < 0.0001)
    }
}
