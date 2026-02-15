import SwiftData
import Foundation

@Model
final class CommentEntity {

    // MARK: Stored Properties

    var id: UUID
    var text: String
    var createdAt: Date

    var stop: StopEntity?

    // MARK: Initializer

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.createdAt = Date()
    }
}
