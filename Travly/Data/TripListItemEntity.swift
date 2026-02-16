import SwiftData
import Foundation

@Model
final class TripListItemEntity {
    var id: UUID
    var text: String
    var isChecked: Bool
    var sortOrder: Int

    var list: TripListEntity?

    init(text: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.text = text
        self.isChecked = false
        self.sortOrder = sortOrder
    }
}
