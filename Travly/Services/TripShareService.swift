import Foundation
import SwiftData
import TripCore

struct TripShareService {

    // MARK: - Export (Entity → .travly file)

    static func exportTrip(_ trip: TripEntity) throws -> URL {
        let transfer = TripTransfer(
            schemaVersion: TripTransfer.currentSchemaVersion,
            name: trip.name,
            destination: trip.destination,
            startDate: trip.startDate,
            endDate: trip.endDate,
            statusRaw: trip.statusRaw,
            notes: trip.notes,
            hasCustomDates: trip.hasCustomDates,
            budgetAmount: trip.budgetAmount,
            budgetCurrencyCode: trip.budgetCurrencyCode,
            days: trip.days.sorted { $0.dayNumber < $1.dayNumber }.map { day in
                DayTransfer(
                    date: day.date,
                    dayNumber: day.dayNumber,
                    notes: day.notes,
                    location: day.location,
                    locationLatitude: day.locationLatitude,
                    locationLongitude: day.locationLongitude,
                    stops: day.stops.sorted { $0.sortOrder < $1.sortOrder }.map { stop in
                        StopTransfer(
                            name: stop.name,
                            latitude: stop.latitude,
                            longitude: stop.longitude,
                            arrivalTime: stop.arrivalTime,
                            departureTime: stop.departureTime,
                            categoryRaw: stop.categoryRaw,
                            notes: stop.notes,
                            sortOrder: stop.sortOrder,
                            isVisited: stop.isVisited,
                            visitedAt: stop.visitedAt,
                            rating: stop.rating,
                            address: stop.address,
                            phone: stop.phone,
                            website: stop.website,
                            comments: stop.comments.sorted { $0.createdAt < $1.createdAt }.map { c in
                                CommentTransfer(text: c.text, createdAt: c.createdAt)
                            }
                        )
                    }
                )
            },
            bookings: trip.bookings.sorted { $0.sortOrder < $1.sortOrder }.map { b in
                BookingTransfer(
                    typeRaw: b.typeRaw,
                    title: b.title,
                    confirmationCode: b.confirmationCode,
                    notes: b.notes,
                    sortOrder: b.sortOrder,
                    airline: b.airline,
                    flightNumber: b.flightNumber,
                    departureAirport: b.departureAirport,
                    arrivalAirport: b.arrivalAirport,
                    departureTime: b.departureTime,
                    arrivalTime: b.arrivalTime,
                    hotelName: b.hotelName,
                    hotelAddress: b.hotelAddress,
                    checkInDate: b.checkInDate,
                    checkOutDate: b.checkOutDate
                )
            },
            lists: trip.lists.sorted { $0.sortOrder < $1.sortOrder }.map { list in
                ListTransfer(
                    name: list.name,
                    icon: list.icon,
                    sortOrder: list.sortOrder,
                    items: list.items.sorted { $0.sortOrder < $1.sortOrder }.map { item in
                        ListItemTransfer(text: item.text, isChecked: item.isChecked, sortOrder: item.sortOrder)
                    }
                )
            },
            expenses: trip.expenses.sorted { $0.sortOrder < $1.sortOrder }.map { e in
                ExpenseTransfer(
                    title: e.title,
                    amount: e.amount,
                    currencyCode: e.currencyCode,
                    dateIncurred: e.dateIncurred,
                    categoryRaw: e.categoryRaw,
                    notes: e.notes,
                    sortOrder: e.sortOrder,
                    createdAt: e.createdAt
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(transfer)

        let sanitized = trip.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitized).travly")
        try data.write(to: url)
        return url
    }

    // MARK: - Decode (File → Transfer struct for preview)

    static func decodeTrip(from url: URL) throws -> TripTransfer {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TripTransfer.self, from: data)
    }

    // MARK: - Import (Transfer → new Entities)

    @discardableResult
    static func importTrip(_ transfer: TripTransfer, into context: ModelContext) -> TripEntity {
        let trip = TripEntity(
            name: transfer.name,
            destination: transfer.destination,
            startDate: transfer.startDate,
            endDate: transfer.endDate,
            notes: transfer.notes
        )
        trip.hasCustomDates = transfer.hasCustomDates
        trip.budgetAmount = transfer.budgetAmount
        trip.budgetCurrencyCode = transfer.budgetCurrencyCode
        context.insert(trip)

        for dayT in transfer.days {
            let day = DayEntity(
                date: dayT.date,
                dayNumber: dayT.dayNumber,
                notes: dayT.notes,
                location: dayT.location,
                locationLatitude: dayT.locationLatitude,
                locationLongitude: dayT.locationLongitude
            )
            day.trip = trip
            context.insert(day)

            for stopT in dayT.stops {
                let stop = StopEntity(
                    name: stopT.name,
                    latitude: stopT.latitude,
                    longitude: stopT.longitude,
                    category: StopCategory(rawValue: stopT.categoryRaw) ?? .other,
                    arrivalTime: stopT.arrivalTime,
                    departureTime: stopT.departureTime,
                    sortOrder: stopT.sortOrder,
                    notes: stopT.notes,
                    isVisited: stopT.isVisited,
                    visitedAt: stopT.visitedAt,
                    address: stopT.address,
                    phone: stopT.phone,
                    website: stopT.website
                )
                stop.rating = stopT.rating
                stop.day = day
                context.insert(stop)

                for commentT in stopT.comments {
                    let comment = CommentEntity(text: commentT.text)
                    comment.createdAt = commentT.createdAt
                    comment.stop = stop
                    context.insert(comment)
                }
            }
        }

        for bkT in transfer.bookings {
            let booking = BookingEntity(
                type: BookingType(rawValue: bkT.typeRaw) ?? .other,
                title: bkT.title,
                confirmationCode: bkT.confirmationCode,
                notes: bkT.notes,
                sortOrder: bkT.sortOrder
            )
            booking.airline = bkT.airline
            booking.flightNumber = bkT.flightNumber
            booking.departureAirport = bkT.departureAirport
            booking.arrivalAirport = bkT.arrivalAirport
            booking.departureTime = bkT.departureTime
            booking.arrivalTime = bkT.arrivalTime
            booking.hotelName = bkT.hotelName
            booking.hotelAddress = bkT.hotelAddress
            booking.checkInDate = bkT.checkInDate
            booking.checkOutDate = bkT.checkOutDate
            booking.trip = trip
            context.insert(booking)
        }

        for listT in transfer.lists {
            let list = TripListEntity(name: listT.name, icon: listT.icon, sortOrder: listT.sortOrder)
            list.trip = trip
            context.insert(list)

            for itemT in listT.items {
                let item = TripListItemEntity(text: itemT.text, sortOrder: itemT.sortOrder)
                item.isChecked = itemT.isChecked
                item.list = list
                context.insert(item)
            }
        }

        for expT in transfer.expenses {
            let expense = ExpenseEntity(
                title: expT.title,
                amount: expT.amount,
                currencyCode: expT.currencyCode,
                dateIncurred: expT.dateIncurred,
                category: ExpenseCategory(rawValue: expT.categoryRaw) ?? .other,
                notes: expT.notes,
                sortOrder: expT.sortOrder
            )
            expense.trip = trip
            context.insert(expense)
        }

        try? context.save()
        return trip
    }
}
