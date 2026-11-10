import Foundation
import SwiftData

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var estimatedMinutes: Int
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?
    var targetDate: Date?
    @Relationship(deleteRule: .cascade, inverse: \FocusBlock.task) var blocks: [FocusBlock]

    init(title: String,
         notes: String = "",
         estimatedMinutes: Int = 30,
         isCompleted: Bool = false,
         createdAt: Date = Date(),
         dueDate: Date? = nil,
         targetDate: Date? = nil,
         blocks: [FocusBlock] = []) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.estimatedMinutes = estimatedMinutes
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.targetDate = targetDate
        self.blocks = blocks
    }

    var isOverdue: Bool {
        guard let due = dueDate else { return false }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return !isCompleted && due < startOfToday
    }
}

@Model
final class FocusBlock {
    @Attribute(.unique) var id: UUID
    var start: Date
    var end: Date
    @Relationship var task: TaskItem?

    init(start: Date, end: Date, task: TaskItem? = nil) {
        self.id = UUID()
        self.start = start
        self.end = end
        self.task = task
    }

    var durationMinutes: Int {
        let mins = Calendar.current.dateComponents([.minute], from: start, to: end).minute ?? 0
        return max(mins, 0)
    }
}
@Model
final class FeedbackItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String
    var message: String
    var createdAt: Date

    init(name: String = "", email: String = "", message: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.message = message
        self.createdAt = createdAt
    }
}

