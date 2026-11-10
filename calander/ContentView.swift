//
//  ContentView.swift
//  calander
//
//  Created by Kakarla Hemanth Reddy on 10/11/26.
//

import SwiftUI
import SwiftData

struct SmartCalendarView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\TaskItem.createdAt, order: .reverse)]) private var tasks: [TaskItem]
    @Query(sort: [SortDescriptor(\FocusBlock.start)]) private var blocks: [FocusBlock]

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

//search bar
    enum SearchScope: String, CaseIterable, Identifiable {
        case all = "All"
        case tasks = "Tasks"
        case events = "Events"
        var id: Self { self }
    }

    @State private var searchText: String = ""
    @State private var searchScope: SearchScope = .all
    @State private var themeColor: Color = .accentColor
    @State private var showFeedbackSheet: Bool = false
    @State private var showFeedbackList: Bool = false
    @State private var didRandomizeTheme: Bool = false

    private let calendar = Calendar.current

    init() {}

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                header
                weekdayHeader
                monthGrid
                Divider().padding(.top, 4)
                dayDetail
            }
            .padding()
            .navigationTitle("Smart Focus Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search tasks and events")
            .searchScopes($searchScope) {
                Text("All").tag(SearchScope.all)
                Text("Tasks").tag(SearchScope.tasks)
                Text("Events").tag(SearchScope.events)
            }
            .tint(themeColor)
            .sheet(isPresented: $showFeedbackSheet) {
                FeedbackSheet(themeColor: themeColor)
            }
            .sheet(isPresented: $showFeedbackList) {
                FeedbackListSheet(themeColor: themeColor)
            }
            .onAppear { if !didRandomizeTheme { randomizeThemeColor(); didRandomizeTheme = true } }
        }
    }

//header
    private var header: some View {
        HStack(alignment: .center) {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.title3.weight(.semibold))
            }
            Spacer()
            VStack(spacing: 2) {
                Text(monthYearString(for: displayedMonth))
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Button("Today") { jumpToToday() }
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").font(.title3.weight(.semibold))
            }
        }
        .padding(.horizontal, 4)
    }

//header2
    private var weekdayHeader: some View {
        let symbols = calendar.shortWeekdaySymbols
        let shifted = shiftWeekdaySymbols(symbols, firstWeekday: calendar.firstWeekday)
        return HStack {
            ForEach(shifted, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(symbol)
            }
        }
    }

//grid
    private var monthGrid: some View {
        let days = daysForMonthGrid(containing: displayedMonth)
        let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(days, id: \.self) { day in
                let isInMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
                let isToday = calendar.isDateInToday(day)
                let intensity = heatForDay(day)
                DayCell(date: day,
                        isInDisplayedMonth: isInMonth,
                        isToday: isToday,
                        heat: intensity,
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                        themeColor: themeColor)
                .onTapGesture { selectedDate = day }
                .accessibilityElement(children: .combine)
            }
        }
    }


    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(fullDateString(selectedDate))
                    .font(.headline)
                Spacer()
                Button("Auto-schedule") { autoScheduleSelectedDay() }
                    .buttonStyle(.borderedProminent)
            }

            if searchScope != .tasks {
                let dayBlocks = filteredBlocksForDay(selectedDate)
                if dayBlocks.isEmpty {
                    ContentUnavailableView(isSearching ? "No matching events" : "No focus blocks", systemImage: "calendar.badge.exclamationmark", description: Text(isSearching ? "Try a different search term or scope." : "Auto-schedule to fill your day with focus sessions."))
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(dayBlocks, id: \.id) { block in
                        FocusBlockRow(block: block, themeColor: themeColor)
                    }
                }
                Divider().padding(.vertical, 4)
            }

//targeting
            if searchScope != .events {
                let dayTasks = filteredTasksForDay(selectedDate)
                if dayTasks.isEmpty {
                    ContentUnavailableView(isSearching ? "No matching tasks" : "No tasks", systemImage: "list.bullet", description: Text(isSearching ? "Try a different search term or scope." : "Add tasks below and auto-schedule them."))
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(dayTasks, id: \.id) { task in
                        TaskRow(task: task)
                    }
                }
            }

            AddTaskRow(targetDate: selectedDate)
        }
    }

//toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                try? seedDemoData()
            } label: {
                Label("Seed", systemImage: "wand.and.stars")
            }
            Menu {
                Button {
                    showFeedbackSheet = true
                } label: {
                    Label("Send Feedback", systemImage: "square.and.pencil")
                }
                Button {
                    showFeedbackList = true
                } label: {
                    Label("View Feedback", systemImage: "tray.full")
                }
            } label: {
                Label("Feedback", systemImage: "bubble.left.and.bubble.right")
            }
        }
    }

//layout
    private func monthYearString(for date: Date) -> String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("MMMM y")
        return df.string(from: date)
    }

    private func fullDateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = .current
        df.dateStyle = .full
        return df.string(from: date)
    }

    private func shiftWeekdaySymbols(_ symbols: [String], firstWeekday: Int) -> [String] {
        let idx = (firstWeekday - 1) % symbols.count
        let left = Array(symbols[idx...])
        let right = Array(symbols[..<idx])
        return left + right
    }

    private func startOfMonth(for date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private func endOfMonth(for date: Date) -> Date {
        let start = startOfMonth(for: date)
        let comps = DateComponents(month: 1, day: -1)
        return calendar.date(byAdding: comps, to: start) ?? date
    }

    private func daysForMonthGrid(containing date: Date) -> [Date] {
        let start = startOfMonth(for: date)
        let end = endOfMonth(for: date)
        let weekdayOfStart = calendar.component(.weekday, from: start)
        let distanceToFirstWeekday = (weekdayOfStart - calendar.firstWeekday + 7) % 7
        let firstCell = calendar.date(byAdding: .day, value: -distanceToFirstWeekday, to: start) ?? start
        let weekdayOfEnd = calendar.component(.weekday, from: end)
        let distanceToEndOfWeek = (calendar.firstWeekday + 6 - weekdayOfEnd + 7) % 7
        let lastCell = calendar.date(byAdding: .day, value: distanceToEndOfWeek, to: end) ?? end
        var days: [Date] = []
        var cursor = firstCell
        while cursor <= lastCell {
            days.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            if days.count > 42 { break }
        }
        return days
    }

//heatmap
    private func heatForDay(_ day: Date) -> Double {
        // Normalize to [0, 1] by mapping total scheduled minutes in day to 0..1 across 0..480 minutes (8h)
        let total = blocksForDay(day).reduce(0) { $0 + $1.durationMinutes }
        let clamped = min(Double(total) / 480.0, 1.0)
        return clamped
    }

    private func blocksForDay(_ day: Date) -> [FocusBlock] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return blocks.filter { $0.start < end && $0.end > start }
            .sorted { $0.start < $1.start }
    }

    private func tasksForDay(_ day: Date) -> [TaskItem] {
        tasks.filter { task in
            if let target = task.targetDate { return calendar.isDate(target, inSameDayAs: day) }
            if let due = task.dueDate { return calendar.isDate(due, inSameDayAs: day) }
            return false
        }
        .sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue }
            if let l = lhs.dueDate, let r = rhs.dueDate, l != r { return l < r }
            return lhs.createdAt < rhs.createdAt
        }
    }

//filtering :<
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func matches(_ text: String) -> Bool {
        if !isSearching { return true }
        return text.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private func filteredTasksForDay(_ day: Date) -> [TaskItem] {
        let base = tasksForDay(day)
        if searchScope == .events { return [] }
        guard isSearching else { return base }
        return base.filter { task in
            matches(task.title) || (!task.notes.isEmpty && matches(task.notes))
        }
    }

    private func filteredBlocksForDay(_ day: Date) -> [FocusBlock] {
        let base = blocksForDay(day)
        if searchScope == .tasks { return [] }
        guard isSearching else { return base }
        return base.filter { block in
            let title = block.task?.title ?? "Unassigned"
            return matches(title)
        }
    }

//themes cuz we were forced to ;-;
    private func randomizeThemeColor() {
        let palette: [Color] = [.pink, .orange, .mint, .teal, .indigo, .purple, .cyan, .red]
        if let pick = palette.randomElement() {
            themeColor = pick
        }
    }

//actions
    private func shiftMonth(_ delta: Int) { displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth }
    private func jumpToToday() { selectedDate = calendar.startOfDay(for: Date()); displayedMonth = Date() }

    private func autoScheduleSelectedDay() {
        let pending = tasksForDay(selectedDate).filter { !$0.isCompleted }
        guard !pending.isEmpty else { return }
        do {
            let scheduler = AutoScheduler()
            let _ = try scheduler.schedule(tasks: pending, in: calendar, on: selectedDate, context: context)
            try context.save()
        } catch {
            print("Auto-schedule error: \(error)")
        }
    }

    private func seedDemoData() throws {
        if tasks.isEmpty {
            let today = calendar.startOfDay(for: Date())
            let samples: [TaskItem] = [
                TaskItem(title: "Write proposal", notes: "Competitor analysis + value prop", estimatedMinutes: 90, dueDate: calendar.date(byAdding: .day, value: 1, to: today), targetDate: today),
                TaskItem(title: "Design mockups", notes: "Calendar heatmap variations", estimatedMinutes: 120, dueDate: calendar.date(byAdding: .day, value: 3, to: today), targetDate: calendar.date(byAdding: .day, value: 1, to: today)),
                TaskItem(title: "Implement autoscheduler", estimatedMinutes: 150, dueDate: calendar.date(byAdding: .day, value: 2, to: today), targetDate: today),
                TaskItem(title: "Team sync", estimatedMinutes: 30, dueDate: today, targetDate: today)
            ]
            samples.forEach { context.insert($0) }
            try context.save()
        }
    }
}


private struct DayCell: View {
    let date: Date
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let heat: Double
    let isSelected: Bool
    let themeColor: Color

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if heat > 0 {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeColor.opacity(0.12 + heat * 0.35))
                }
                Text(dayNumber(date))
                    .font(.body.weight(isToday ? .bold : .regular))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeColor, lineWidth: 1)
                }
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .foregroundStyle(isInDisplayedMonth ? Color.primary : Color.secondary.opacity(0.5))
        .overlay(alignment: .bottom) {
            if isSelected {
                Capsule().fill(themeColor).frame(height: 3).padding(.horizontal, 8)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private func dayNumber(_ date: Date) -> String { String(calendar.component(.day, from: date)) }

    private var accessibilityLabel: String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = .current
        df.dateStyle = .full
        return df.string(from: date)
    }
}

//rows
private struct TaskRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var task: TaskItem

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Button { task.isCompleted.toggle(); try? context.save() } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .strikethrough(task.isCompleted, color: .secondary)
                if !task.notes.isEmpty {
                    Text(task.notes).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    if let due = task.dueDate {
                        Text(due, style: .date).font(.caption2).foregroundStyle(task.isOverdue ? .red : .secondary)
                    }
                    Text("~\(task.estimatedMinutes)m").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Menu {
                Button("Schedule for today") { task.targetDate = Calendar.current.startOfDay(for: Date()); try? context.save() }
                Button("Clear target date") { task.targetDate = nil; try? context.save() }
                Button("Delete", role: .destructive) { context.delete(task); try? context.save() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct FocusBlockRow: View {
    let block: FocusBlock
    let themeColor: Color

    var body: some View {
        HStack {
            Label("", systemImage: "hourglass")
                .labelStyle(.iconOnly)
                .foregroundStyle(themeColor)
            VStack(alignment: .leading) {
                Text(timeRange(block.start, block.end))
                    .font(.subheadline.weight(.semibold))
                Text(block.task?.title ?? "Unassigned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(block.durationMinutes)m").font(.caption).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(themeColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func timeRange(_ start: Date, _ end: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        return "\(df.string(from: start)) – \(df.string(from: end))"
    }
}

//adding of the tasks
private struct AddTaskRow: View {
    @Environment(\.modelContext) private var context
    @State private var title: String = ""
    @State private var minutes: Int = 30
    var targetDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Task").font(.headline)
            HStack {
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                Stepper("\(minutes)m", value: $minutes, in: 15...240, step: 15)
                    .labelsHidden()
            }
            HStack {
                Button("Add") { add() }
                    .buttonStyle(.borderedProminent)
                Button("Clear") { title = ""; minutes = 30 }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func add() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let item = TaskItem(title: title, estimatedMinutes: minutes, targetDate: Calendar.current.startOfDay(for: targetDate))
        context.insert(item)
        try? context.save()
        title = ""; minutes = 30
    }
}

private struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var context
    let themeColor: Color

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var message: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name (optional)", text: $name)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                Section("Feedback") {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Send Feedback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .tint(themeColor)
        }
    }

    private func send() {
        let subject = "App Feedback"
        var bodyParts: [String] = []
        if !name.isEmpty { bodyParts.append("Name: \(name)") }
        if !email.isEmpty { bodyParts.append("Email: \(email)") }
        bodyParts.append("Message:\n\(message)")
        let body = bodyParts.joined(separator: "\n\n")
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Save locally so it can be viewed in the inbox
        let item = FeedbackItem(name: name, email: email, message: message, createdAt: Date())
        context.insert(item)
        try? context.save()

        if let url = URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)") {
            openURL(url)
        }
        dismiss()
    }
}

private struct FeedbackListSheet: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\FeedbackItem.createdAt, order: .reverse)]) private var feedbacks: [FeedbackItem]
    let themeColor: Color

    var body: some View {
        NavigationStack {
            Group {
                if feedbacks.isEmpty {
                    ContentUnavailableView("No feedback yet", systemImage: "tray", description: Text("Feedback you or your users send will appear here."))
                } else {
                    List {
                        ForEach(feedbacks, id: \.id) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.name.isEmpty ? "Anonymous" : item.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(item.createdAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !item.email.isEmpty {
                                    Text(item.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(item.message)
                                    .font(.body)
                            }
                            .padding(.vertical, 6)
                        }
                        .onDelete { indexSet in
                            for index in indexSet { context.delete(feedbacks[index]) }
                            try? context.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Feedback Inbox")
            .tint(themeColor)
            .toolbar { EditButton() }
        }
    }
}

#Preview {
    SmartCalendarView()
        .modelContainer(for: [TaskItem.self, FocusBlock.self, FeedbackItem.self], inMemory: true)
}
