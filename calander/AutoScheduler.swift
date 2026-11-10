import Foundation
import SwiftData

struct AutoScheduler {
    func schedule(tasks: [TaskItem], in calendar: Calendar, on day: Date, workdayStart: DateComponents = DateComponents(hour: 9), workdayEnd: DateComponents = DateComponents(hour: 17), slot: Int = 30, context: ModelContext) throws -> [FocusBlock] {
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)

//main window
        let start = calendar.date(bySettingHour: workdayStart.hour ?? 9, minute: workdayStart.minute ?? 0, second: 0, of: startOfDay) ?? startOfDay
        let end = calendar.date(bySettingHour: workdayEnd.hour ?? 17, minute: workdayEnd.minute ?? 0, second: 0, of: startOfDay) ?? endOfDay
        let workingStart = max(start, startOfDay)
        let workingEnd = min(end, endOfDay)
        guard workingStart < workingEnd else { return [] }

//overlapping thingies
        var existing: [FocusBlock] = []
        do {
            let descriptor = FetchDescriptor<FocusBlock>()
            let fetched = try context.fetch(descriptor)
            existing = fetched.filter { blk in blk.start < workingEnd && blk.end > workingStart }
        } catch {
            existing = []
        }


        let slotSeconds: TimeInterval = TimeInterval(slot * 60)
        var cursor = workingStart
        var slots: [(Date, Date)] = []
        while cursor.addingTimeInterval(slotSeconds) <= workingEnd {
            let next = cursor.addingTimeInterval(slotSeconds)
            let blocked = existing.contains { blk in (cursor < blk.end) && (next > blk.start) }
            if !blocked { slots.append((cursor, next)) }
            cursor = next
        }

// sorting stuff
        let sortedTasks: [TaskItem] = tasks.sorted(by: { (lhs: TaskItem, rhs: TaskItem) -> Bool in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?) where l != r: return l < r
            case (nil, .some): return false
            case (.some, nil): return true
            default: break
            }
            if lhs.estimatedMinutes != rhs.estimatedMinutes { return lhs.estimatedMinutes < rhs.estimatedMinutes }
            return lhs.createdAt < rhs.createdAt
        })

        var created: [FocusBlock] = []
        var slotIndex = 0

        for task in sortedTasks where !task.isCompleted {
            var remaining = max(task.estimatedMinutes, 0)
            while remaining > 0 && slotIndex < slots.count {
                let (s, e) = slots[slotIndex]
                slotIndex += 1
                let block = FocusBlock(start: s, end: e, task: task)
                task.blocks.append(block)
                context.insert(block)
                created.append(block)
                remaining -= slot
            }
        }

        return created
    }
}

private extension Calendar {
    func date(bySettingHour hour: Int, minute: Int, second: Int, of baseDate: Date) -> Date? {
        var comps = dateComponents([.year, .month, .day], from: baseDate)
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        return self.date(from: comps)
    }
}
