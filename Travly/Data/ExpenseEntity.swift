import SwiftData
import SwiftUI
import Foundation

/// Represents an expense tied to a trip for budget tracking.
@Model
final class ExpenseEntity {

    // MARK: Stored Properties

    var id: UUID
    var title: String
    var amount: Double
    var currencyCode: String
    var dateIncurred: Date
    var categoryRaw: String
    var notes: String
    var sortOrder: Int
    var createdAt: Date

    var trip: TripEntity?

    // MARK: Computed Properties

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    // MARK: Initializer

    init(
        title: String,
        amount: Double,
        currencyCode: String = "USD",
        dateIncurred: Date = Date(),
        category: ExpenseCategory = .other,
        notes: String = "",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode
        self.dateIncurred = dateIncurred
        self.categoryRaw = category.rawValue
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

// MARK: - ExpenseCategory

enum ExpenseCategory: String, Codable, CaseIterable {
    case accommodation
    case food
    case transport
    case activity
    case shopping
    case other

    var label: String {
        switch self {
        case .accommodation: "Accommodation"
        case .food: "Food & Drink"
        case .transport: "Transport"
        case .activity: "Activities"
        case .shopping: "Shopping"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .accommodation: "bed.double.fill"
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .activity: "ticket.fill"
        case .shopping: "bag.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .accommodation: .purple
        case .food: .orange
        case .transport: .blue
        case .activity: .green
        case .shopping: .pink
        case .other: .gray
        }
    }
}
