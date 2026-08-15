//
//  TodoListWidget.swift
//  TodoListWidget
//
//  Created by 井上京佳 on 2026/03/28.
//

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - App Group

private let appGroupID = "group.com.yourname.tasktune"

private func makeModelContainer() throws -> ModelContainer? {
    guard let groupURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return nil }
    let storeURL = groupURL.appendingPathComponent("tasktune.store")

    // マイグレーションでは復旧できないほどストアが壊れている場合のみ、
    // 削除せず退避（リネーム）してから空のストアを作り直す
    func quarantineCorruptedStore() {
        let timestamp = Int(Date().timeIntervalSince1970)
        for suffix in ["", "-shm", "-wal"] {
            let url = groupURL.appendingPathComponent("tasktune.store\(suffix)")
            let backupURL = groupURL.appendingPathComponent("tasktune-corrupted-\(timestamp).store\(suffix)")
            try? FileManager.default.moveItem(at: url, to: backupURL)
        }
    }

    let config = ModelConfiguration(url: storeURL)
    do {
        return try ModelContainer(for: TodoList.self, migrationPlan: TaskTuneMigrationPlan.self, configurations: config)
    } catch {
        quarantineCorruptedStore()
        return try ModelContainer(for: TodoList.self, migrationPlan: TaskTuneMigrationPlan.self, configurations: config)
    }
}

private struct JustCompletedInfo: Codable {
    let listTitle: String
    let todoTitle: String
    let timestamp: Date
}
private let justCompletedKey = "justCompleted"

// MARK: - Complete Todo Intent

struct CompleteTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Todo"

    @Parameter(title: "List Title")
    var listTitle: String

    @Parameter(title: "Todo Title")
    var todoTitle: String

    init() {}

    init(listTitle: String, todoTitle: String) {
        self.listTitle = listTitle
        self.todoTitle = todoTitle
    }

    func perform() async throws -> some IntentResult {
        guard let container = try makeModelContainer() else { return .result() }
        let context = ModelContext(container)
        let lists = try context.fetch(FetchDescriptor<TodoList>())
        if let list = lists.first(where: { $0.title == listTitle }),
           let todo = list.todos.first(where: { $0.title == todoTitle && !$0.isCompleted }) {
            todo.isCompleted = true
            todo.missedCount = 0
            try context.save()
            // Save just-completed info for brief visual feedback
            let info = JustCompletedInfo(listTitle: listTitle, todoTitle: todoTitle, timestamp: Date())
            if let data = try? JSONEncoder().encode(info) {
                UserDefaults(suiteName: appGroupID)?.set(data, forKey: justCompletedKey)
            }
        }
        return .result()
    }
}

// MARK: - List Names Provider

struct ListNamesProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        guard let container = try makeModelContainer() else { return [] }
        let context = ModelContext(container)
        let lists = try context.fetch(FetchDescriptor<TodoList>(sortBy: [SortDescriptor(\.sortOrder)]))
        return lists.map(\.title)
    }
}

// MARK: - Widget Theme Entity

extension WidgetTheme: AppEntity {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Theme"

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    public static var defaultQuery = WidgetThemeEntityQuery()
}

struct WidgetThemeEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [WidgetTheme] {
        let all = WidgetThemeStore.loadAll()
        return identifiers.compactMap { id in all.first { $0.id == id } }
    }

    func suggestedEntities() async throws -> [WidgetTheme] {
        WidgetThemeStore.loadAll()
    }
}

// MARK: - Widget Interaction Mode

enum WidgetInteractionMode: String, AppEnum {
    case interactive
    case readOnly

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Interaction Mode"
    static var caseDisplayRepresentations: [WidgetInteractionMode: DisplayRepresentation] = [
        .interactive: "Tap to Complete",
        .readOnly: "Read Only",
    ]
}

// MARK: - Widget Configuration Intent

struct SelectListIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Settings"
    static var description = IntentDescription("Select a list and theme.")

    @Parameter(title: "List", optionsProvider: ListNamesProvider())
    var listTitle: String?

    @Parameter(title: "Theme")
    var theme: WidgetTheme?

    @Parameter(title: "Interaction Mode", default: .interactive)
    var interactionMode: WidgetInteractionMode
}

// MARK: - Entry

struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let listTitle: String
    let pendingTodos: [String]
    let completedTodos: [String]
    let theme: WidgetTheme
    var showCheckbox: Bool = true
    var justCompletedTitle: String? = nil
    var isSetup: Bool = false

    var totalPending: Int { pendingTodos.count }
    var totalCompleted: Int { completedTodos.count }
}

// MARK: - Provider

struct TodoWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(
            date: Date(),
            listTitle: "Shopping",
            pendingTodos: ["Milk", "Eggs", "Bread", "Apples", "Butter", "Cheese"],
            completedTodos: ["Juice"],
            theme: .default
        )
    }

    func snapshot(for configuration: SelectListIntent, in context: Context) async -> TodoWidgetEntry {
        fetchEntry(for: configuration)
    }

    func timeline(for configuration: SelectListIntent, in context: Context) async -> Timeline<TodoWidgetEntry> {
        let now = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: now)!

        let defaults = UserDefaults(suiteName: appGroupID)
        if let data = defaults?.data(forKey: justCompletedKey),
           let info = try? JSONDecoder().decode(JustCompletedInfo.self, from: data),
           now.timeIntervalSince(info.timestamp) < 5 {
            defaults?.removeObject(forKey: justCompletedKey)
            // Entry 1: show just-completed item as checked in its original position
            let flashEntry = fetchEntry(for: configuration, date: now, justCompleted: info)
            // Entry 2: normal state
            let normalEntry = fetchEntry(for: configuration, date: now.addingTimeInterval(1.5))
            return Timeline(entries: [flashEntry, normalEntry], policy: .after(nextUpdate))
        }

        return Timeline(entries: [fetchEntry(for: configuration, date: now)], policy: .after(nextUpdate))
    }

    private func fetchEntry(for configuration: SelectListIntent, date: Date = Date(), justCompleted: JustCompletedInfo? = nil) -> TodoWidgetEntry {
        let theme = configuration.theme ?? WidgetThemeStore.loadAll().first ?? .default
        guard let listTitle = configuration.listTitle else {
            var setupTheme = theme
            setupTheme.showRemainingCount = false
            setupTheme.showCompletedCount = false
            return TodoWidgetEntry(
                date: date,
                listTitle: "Todo List",
                pendingTodos: [
                    "① Long press the widget",
                    "② Tap \"Edit Widget\"",
                    "③ Set list & theme",
                    "Themes can be created in Settings",
                ],
                completedTodos: [],
                theme: setupTheme,
                showCheckbox: false,
                isSetup: true
            )
        }
        do {
            guard let container = try makeModelContainer() else { throw NSError(domain: "Widget", code: 0) }
            let context = ModelContext(container)
            let lists = try context.fetch(FetchDescriptor<TodoList>(sortBy: [SortDescriptor(\.sortOrder)]))
            let list = lists.first(where: { $0.title == listTitle }) ?? lists.first
            if let list {
                let sorted = list.todos.sorted { $0.sortOrder < $1.sortOrder }

                if let jc = justCompleted,
                   jc.listTitle == list.title,
                   let jcTodo = sorted.first(where: { $0.title == jc.todoTitle && $0.isCompleted }) {
                    // Re-insert the just-completed item at its original sort position
                    var pending = sorted.filter { !$0.isCompleted }.map(\.title)
                    let insertIdx = sorted.prefix(while: { $0.sortOrder < jcTodo.sortOrder }).filter { !$0.isCompleted }.count
                    pending.insert(jc.todoTitle, at: min(insertIdx, pending.count))
                    let completed = sorted.filter { $0.isCompleted && $0.title != jc.todoTitle }.map(\.title)
                    return TodoWidgetEntry(
                        date: date,
                        listTitle: list.title,
                        pendingTodos: pending,
                        completedTodos: completed,
                        theme: theme,
                        showCheckbox: configuration.interactionMode == .interactive,
                        justCompletedTitle: jc.todoTitle
                    )
                }

                return TodoWidgetEntry(
                    date: date,
                    listTitle: list.title,
                    pendingTodos: sorted.filter { !$0.isCompleted }.map(\.title),
                    completedTodos: sorted.filter { $0.isCompleted }.map(\.title),
                    theme: theme,
                    showCheckbox: configuration.interactionMode == .interactive
                )
            }
        } catch {
            print("[TodoListWidget] fetchEntry failed: \(error)")
        }
        return TodoWidgetEntry(
            date: date,
            listTitle: "Todo",
            pendingTodos: [],
            completedTodos: [],
            theme: theme,
            showCheckbox: configuration.interactionMode == .interactive
        )
    }
}

// MARK: - Todo Row View

struct TodoRowView: View {
    let title: String
    let listTitle: String
    let isCompleted: Bool
    let theme: WidgetTheme
    var showCheckbox: Bool = true

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        rowContent
    }

    private var checkbox: some View {
        Image(systemName: isCompleted ? theme.checkboxStyle.completedIcon : theme.checkboxStyle.pendingIcon)
            .font(theme.iconFont)
            .foregroundStyle(isCompleted ? checkboxCompletedColor : checkboxPendingColor)
    }

    private var interactiveCheckbox: some View {
        Button(intent: CompleteTodoIntent(listTitle: listTitle, todoTitle: title)) {
            checkbox
        }
        .buttonStyle(.plain)
    }

    private var checkboxPendingColor: Color {
        renderingMode == .accented ? .primary : theme.accentColor
    }
    private var checkboxCompletedColor: Color {
        renderingMode == .accented ? .secondary : theme.secondaryTextColor
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            if showCheckbox && theme.checkboxPosition == .leading {
                isCompleted ? AnyView(checkbox) : AnyView(interactiveCheckbox)
            }
            Text(title)
                .font(theme.itemFont)
                .lineLimit(1)
                .foregroundStyle(isCompleted
                    ? (renderingMode == .accented ? Color.secondary : theme.secondaryTextColor)
                    : (renderingMode == .accented ? Color.primary : theme.textColor))
                .strikethrough(isCompleted)
            Spacer()
            if showCheckbox && theme.checkboxPosition == .trailing {
                isCompleted ? AnyView(checkbox) : AnyView(interactiveCheckbox)
            }
        }
        .padding(.vertical, theme.rowHeight.verticalPadding)
    }
}

// MARK: - Widget Header View

struct WidgetHeaderView: View {
    let entry: TodoWidgetEntry

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetFamily) private var widgetFamily

    var body: some View {
        HStack {
            Text(entry.listTitle)
                .font(entry.theme.headerFont)
                .foregroundStyle(renderingMode == .accented ? Color.primary : entry.theme.textColor)
                .lineLimit(1)
            Spacer()
            if widgetFamily == .systemSmall {
                compactCountView
            } else {
                fullCountView
            }
        }
        .padding(.bottom, 1)
    }

    @ViewBuilder
    private var compactCountView: some View {
        HStack(spacing: 4) {
            if entry.theme.showRemainingCount {
                HStack(spacing: 2) {
                    Image(systemName: entry.theme.checkboxStyle.pendingIcon)
                    Text("\(entry.totalPending)")
                }
                .font(.caption2)
                .foregroundStyle(renderingMode == .accented ? Color.secondary : entry.theme.secondaryTextColor)
            }
            if entry.theme.showCompletedCount {
                HStack(spacing: 2) {
                    Image(systemName: entry.theme.checkboxStyle.completedIcon)
                    Text("\(entry.totalCompleted)")
                }
                .font(.caption2)
                .foregroundStyle(renderingMode == .accented ? Color(.tertiaryLabel) : entry.theme.tertiaryTextColor)
            }
        }
    }

    @ViewBuilder
    private var fullCountView: some View {
        HStack(spacing: 6) {
            if entry.theme.showRemainingCount {
                Text("\(entry.totalPending) left")
                    .font(.caption)
                    .foregroundStyle(renderingMode == .accented ? Color.secondary : entry.theme.secondaryTextColor)
            }
            if entry.theme.showCompletedCount {
                Text("\(entry.totalCompleted) done")
                    .font(.caption)
                    .foregroundStyle(renderingMode == .accented ? Color(.tertiaryLabel) : entry.theme.tertiaryTextColor)
            }
        }
    }
}

// MARK: - Widget Layout Constants

private enum WidgetItemAreaHeight {
    // Usable item area heights after subtracting padding, header, and divider
    // Small:  ~155 - 24 (v-padding) - 18 (header) - 2 (divider) ≈ 111
    // Medium: ~158 - 24 (v-padding) - 14 (header) - 3 (divider) ≈ 114 (note: system height differs from preview)
    static let small: CGFloat = 111
    static let medium: CGFloat = 114
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: TodoWidgetEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var maxItemCount: Int {
        max(1, Int(WidgetItemAreaHeight.small / entry.theme.estimatedRowHeight))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeaderView(entry: entry)
            Divider().padding(.bottom, 1)
            pendingList
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .containerBackground(for: .widget) {
            entry.theme.backgroundColor
        }
    }

    @ViewBuilder
    private var pendingList: some View {
        if entry.isSetup {
            setupMessageView
        } else {
            normalPendingList
        }
    }

    private var setupMessageView: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(entry.pendingTodos.enumerated()), id: \.offset) { index, line in
                let isHint = index == entry.pendingTodos.count - 1
                Text(LocalizedStringKey(line))
                    .font(isHint ? .caption2 : .caption)
                    .foregroundStyle(isHint
                        ? (renderingMode == .accented ? Color.secondary : entry.theme.secondaryTextColor)
                        : (renderingMode == .accented ? Color.primary : entry.theme.textColor))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var normalPendingList: some View {
        let toShow = Array(entry.pendingTodos.prefix(maxItemCount))
        let remaining = entry.totalPending - toShow.count
        return VStack(alignment: .leading, spacing: 0) {
            if entry.pendingTodos.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(entry.theme.accentColor)
                    Text("All done!").font(.caption).foregroundStyle(entry.theme.secondaryTextColor)
                }
            } else {
                ForEach(Array(toShow.enumerated()), id: \.offset) { _, title in
                    TodoRowView(title: title, listTitle: entry.listTitle, isCompleted: title == entry.justCompletedTitle, theme: entry.theme, showCheckbox: entry.showCheckbox)
                }
                if remaining > 0 {
                    Text("+ \(remaining) more")
                        .font(.caption2)
                        .foregroundStyle(renderingMode == .accented ? Color(.tertiaryLabel) : entry.theme.tertiaryTextColor)
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: TodoWidgetEntry

    private var maxItemCount: Int {
        max(1, Int(WidgetItemAreaHeight.medium / entry.theme.estimatedRowHeight))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeaderView(entry: entry)
            Divider().padding(.bottom, 1)
            pendingList
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .containerBackground(for: .widget) {
            entry.theme.backgroundColor
        }
    }

    @ViewBuilder
    private var pendingList: some View {
        if entry.isSetup {
            setupMessageView
        } else {
            normalPendingList
        }
    }

    private var setupMessageView: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(entry.pendingTodos.enumerated()), id: \.offset) { index, line in
                let isHint = index == entry.pendingTodos.count - 1
                Text(LocalizedStringKey(line))
                    .font(isHint ? .caption : .subheadline)
                    .foregroundStyle(isHint ? entry.theme.secondaryTextColor : entry.theme.textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var normalPendingList: some View {
        let toShow = Array(entry.pendingTodos.prefix(maxItemCount))
        let remaining = entry.totalPending - toShow.count

        VStack(alignment: .leading, spacing: 0) {
            if entry.pendingTodos.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(entry.theme.accentColor)
                    Text("All done!").font(.subheadline).foregroundStyle(entry.theme.secondaryTextColor)
                }
            } else {
                ForEach(Array(toShow.enumerated()), id: \.offset) { _, title in
                    TodoRowView(title: title, listTitle: entry.listTitle, isCompleted: title == entry.justCompletedTitle, theme: entry.theme, showCheckbox: entry.showCheckbox)
                }
                if remaining > 0 {
                    Text("+ \(remaining) more")
                        .font(.caption)
                        .foregroundStyle(entry.theme.tertiaryTextColor)
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeaderView(entry: entry)
            Divider().padding(.bottom, 8)
            if entry.isSetup {
                setupMessageView
            } else {
                GeometryReader { proxy in
                    normalTodoList(availableHeight: proxy.size.height)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            entry.theme.backgroundColor
        }
    }

    private var setupMessageView: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(entry.pendingTodos.enumerated()), id: \.offset) { index, line in
                let isHint = index == entry.pendingTodos.count - 1
                Text(LocalizedStringKey(line))
                    .font(isHint ? .caption : .subheadline)
                    .foregroundStyle(isHint ? entry.theme.secondaryTextColor : entry.theme.textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func normalTodoList(availableHeight: CGFloat) -> some View {
        let showCompletedSection = entry.theme.showCompleted && !entry.completedTodos.isEmpty
        let rowH = entry.theme.estimatedRowHeight
        let pendingHeight = entry.theme.showCompleted ? availableHeight * 0.6 : availableHeight
        let completedHeight = availableHeight * 0.4
        let pendingCount = max(1, Int(pendingHeight / rowH))
        let completedCount = max(1, Int(completedHeight / rowH))
        let pendingToShow = Array(entry.pendingTodos.prefix(pendingCount))
        let remaining = entry.totalPending - pendingToShow.count

        VStack(alignment: .leading, spacing: 0) {
            if entry.pendingTodos.isEmpty && !showCompletedSection {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(entry.theme.accentColor)
                    Text("All done!").font(.subheadline).foregroundStyle(entry.theme.secondaryTextColor)
                }
            } else {
                ForEach(Array(pendingToShow.enumerated()), id: \.offset) { _, title in
                    TodoRowView(title: title, listTitle: entry.listTitle, isCompleted: title == entry.justCompletedTitle, theme: entry.theme, showCheckbox: entry.showCheckbox)
                }
                if remaining > 0 {
                    Text("+ \(remaining) more")
                        .font(.caption)
                        .foregroundStyle(entry.theme.tertiaryTextColor)
                        .padding(.top, 2)
                }
                if entry.theme.showCompleted {
                    Divider().padding(.vertical, 8)
                    if showCompletedSection {
                        ForEach(Array(entry.completedTodos.prefix(completedCount).enumerated()), id: \.offset) { _, title in
                            TodoRowView(title: title, listTitle: entry.listTitle, isCompleted: true, theme: entry.theme, showCheckbox: entry.showCheckbox)
                        }
                    } else {
                        Text("No completed tasks")
                            .font(.caption)
                            .foregroundStyle(entry.theme.tertiaryTextColor)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Entry View

struct TodoWidgetEntryView: View {
    var entry: TodoWidgetEntry
    @Environment(\.widgetFamily) var family

    private var widgetURL: URL {
        let encoded = entry.listTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        return URL(string: "tasktune://list/\(encoded)")!
    }

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
                .widgetURL(widgetURL)
        case .systemLarge:
            LargeWidgetView(entry: entry)
                .widgetURL(widgetURL)
        default:
            MediumWidgetView(entry: entry)
                .widgetURL(widgetURL)
        }
    }
}

// MARK: - Widget

struct TodoListWidget: Widget {
    let kind = "TodoListWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectListIntent.self, provider: TodoWidgetProvider()) { entry in
            TodoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TaskTune")
        .description("Customize the list and theme.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
