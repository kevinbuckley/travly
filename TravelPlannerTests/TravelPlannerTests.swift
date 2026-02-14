import Testing
import Foundation
import TripCore
import SwiftData

@testable import TravelPlanner

@Test func tripEntityCanBeCreated() {
    let trip = TripEntity(
        name: "Test Trip",
        destination: "Test City",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 3),
        status: .planning,
        notes: "Test notes"
    )
    #expect(trip.name == "Test Trip")
    #expect(trip.destination == "Test City")
    #expect(trip.status == .planning)
    #expect(trip.notes == "Test notes")
}

@Test func tripEntityComputedProperties() {
    let calendar = Calendar.current
    let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
    let end = calendar.date(from: DateComponents(year: 2026, month: 6, day: 5))!

    let trip = TripEntity(
        name: "Duration Test",
        destination: "Somewhere",
        startDate: start,
        endDate: end
    )
    #expect(trip.durationInDays == 5)
}

@Test func stopEntityCategoryRoundTrips() {
    let stop = StopEntity(
        name: "Test Stop",
        latitude: 35.6762,
        longitude: 139.6503,
        category: .restaurant,
        sortOrder: 0
    )
    #expect(stop.category == .restaurant)
    #expect(stop.categoryRaw == "restaurant")

    stop.category = .attraction
    #expect(stop.categoryRaw == "attraction")
}

@Test func dayEntityFormattedDate() {
    let calendar = Calendar.current
    let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
    let day = DayEntity(date: date, dayNumber: 1)
    #expect(!day.formattedDate.isEmpty)
    #expect(day.dayNumber == 1)
}

@Test func tripStatusConversion() {
    let trip = TripEntity(
        name: "Status Test",
        destination: "Nowhere",
        startDate: Date(),
        endDate: Date()
    )
    #expect(trip.status == .planning)
    #expect(trip.statusRaw == "planning")

    trip.status = .active
    #expect(trip.statusRaw == "active")

    trip.status = .completed
    #expect(trip.statusRaw == "completed")
}
