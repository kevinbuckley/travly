import SwiftData
import Foundation
import TripCore

@Model
final class WishlistItemEntity {
    var id: UUID
    var name: String
    var destination: String
    var latitude: Double
    var longitude: Double
    var categoryRaw: String
    var notes: String
    var address: String?
    var phone: String?
    var website: String?
    var createdAt: Date

    var category: StopCategory {
        get { StopCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        name: String,
        destination: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        category: StopCategory = .attraction,
        notes: String = "",
        address: String? = nil,
        phone: String? = nil,
        website: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.destination = destination
        self.latitude = latitude
        self.longitude = longitude
        self.categoryRaw = category.rawValue
        self.notes = notes
        self.address = address
        self.phone = phone
        self.website = website
        self.createdAt = Date()
    }
}
