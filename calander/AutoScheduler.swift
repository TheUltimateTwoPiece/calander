import Foundation
import SwiftData

struct AutoScheduler {
    
    func schedule(
        tasks: [TaskItem],
        in calendar: Calendar,
        on day: Date,
        workdayStart: DateComponents = DateComponents(hour: 9),
        workdayEnd: DateComponents = DateComponents(hour: 17),
        slot: Int = 30,
        context: ModelContext
    ) throws -> [FocusBlock] {
        
        let dayStart = calendar.startOfDay(for: day)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart),
              let dayEnd = calendar.date(byAdding: .second, value: -1, to: nextDay)
        else { return [] }
        
        // Construct working window
        guard let workStart = calendar.date(bySettingHour: workdayStart.hour ?? 9, minute: workdayStart.minute ?? 0, second: 0, of: dayStart),
              let workEnd = calendar.date(bySettingHour: workdayEnd.hour ?? 17, minute: workdayEnd.minute ?? 0, second: 0, of: dayStart)
        else { return [] }
        
        let workingStart = max(dayStart, workStart)
        let workingEnd = min(dayEnd, workEnd)
        if workingStart >= workingEnd { return [] }
        
        // Fetch existing FocusBlocks overlapping the working window
        let existingBlocks = fetchExistingBlocks(in: context).filter {
            overlaps(start1: $0.start, end1: $0.end, start2: workingStart, end2: workingEnd)
        }
        
        // Create all possible slots (start dates) between workingStart and workingEnd with length slot minutes
        let slotDur = TimeInterval(slot * 60)
        var slots: [DateInterval] = []
        var slotCursor = workingStart
        while slotCursor.addingTimeInterval(slotDur) <= workingEnd {
            let candidate = DateInterval(start: slotCursor, duration: slotDur)
            // Skip if overlaps any existing block
            if !existingBlocks.contains(where: { overlaps(start1: $0.start, end1: $0.end, start2: candidate.start, end2: candidate.end) }) {
                slots.append(candidate)
            }
            slotCursor = slotCursor.addingTimeInterval(slotDur)
        }
        
        // Sort tasks by:
        // 1. incomplete first (completed == false)
        // 2. overdue first (dueDate < now)
        // 3. earlier due date first (non-nil first)
        // 4. shorter estimatedMinutes first
        // 5. earlier createdAt first
        
        let now = Date()
        let sortedTasks = tasks.sorted { t1, t2 in
            if t1.completed != t2.completed {
                return !t1.completed && t2.completed
            }
            let t1Overdue = (t1.dueDate ?? Date.distantFuture) < now
            let t2Overdue = (t2.dueDate ?? Date.distantFuture) < now
            if t1Overdue != t2Overdue {
                return t1Overdue && !t2Overdue
            }
            switch (t1.dueDate, t2.dueDate) {
            case (nil, nil): break
            case (nil, _): return false
            case (_, nil): return true
            case let (d1?, d2?): if d1 != d2 { return d1 < d2 }
            }
            if t1.estimatedMinutes != t2.estimatedMinutes {
                return t1.estimatedMinutes < t2.estimatedMinutes
            }
            return t1.createdAt < t2.createdAt
        }
        
        var createdBlocks: [FocusBlock] = []
        var slotIndex = 0
        
        for task in sortedTasks {
            var remainingMinutes = task.estimatedMinutes
            while remainingMinutes > 0 && slotIndex < slots.count {
                let currentSlot = slots[slotIndex]
                slotIndex += 1
                // Create FocusBlock for the slot, assign task and link
                let block = FocusBlock()
                block.start = currentSlot.start
                block.end = currentSlot.end
                block.task = task
                task.blocks.append(block)
                try context.insert(block)
                createdBlocks.append(block)
                
                remainingMinutes -= slot
            }
            if slotIndex >= slots.count {
                break
            }
        }
        
        return createdBlocks
    }
    
    // MARK: - Helpers
    
    private func fetchExistingBlocks(in context: ModelContext) -> [FocusBlock] {
        do {
            return try context.fetch(FocusBlock.fetchRequest())
        } catch {
            return []
        }
    }
    
    private func overlaps(start1: Date, end1: Date, start2: Date, end2: Date) -> Bool {
        return max(start1, start2) < min(end1, end2)
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
