import Foundation
import SwiftData

@Model
final class TaskItem {
    @Attribute(.unique)
    var id: UUID
    
    var title: String
    var notes: String
    var estimatedMinutes: Int
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?
    var targetDate: Date?
    
    @Relationship(inverse: \FocusBlock.task)
    var blocks: [FocusBlock]
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        estimatedMinutes: Int = 30,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        dueDate: Date? = nil,
        targetDate: Date? = nil,
        blocks: [FocusBlock] = []
    ) {
        self.id = id
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
        return due < startOfToday && !isCompleted
    }
}

@Model
final class FocusBlock {
    @Attribute(.unique)
    var id: UUID
    
    var start: Date
    var end: Date
    
    @Relationship(inverse: \TaskItem.blocks)
    var task: TaskItem?
    
    init(
        id: UUID = UUID(),
        start: Date,
        end: Date,
        task: TaskItem? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.task = task
    }
    
    var durationMinutes: Int {
        Calendar.current.dateComponents([.minute], from: start, to: end).minute ?? 0
    }
}
