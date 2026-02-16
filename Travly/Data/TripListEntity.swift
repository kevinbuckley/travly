import SwiftData
import Foundation

@Model
final class TripListEntity {
    var id: UUID
    var name: String
    var icon: String
    var sortOrder: Int

    var trip: TripEntity?

    @Relationship(deleteRule: .cascade, inverse: \TripListItemEntity.list)
    var items: [TripListItemEntity]

    init(name: String, icon: String = "list.bullet", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
        self.items = []
    }
}
