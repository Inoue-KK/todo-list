//
//  TodoList.swift
//  todo-list
//
//  Created by 井上京佳 on 2026/03/26.
//

import Foundation
import SwiftData

@Model
class TodoList {
    var title: String
    var createdAt: Date
    var sortOrder: Int
    @Relationship(deleteRule: .cascade) var todos: [Todo] = []

    var reminderEnabled: Bool = false
    var reminderTime: Date? = nil
    var reminderRepeatInterval: RepeatInterval? = nil
    var reminderRepeatIntervalCount: Int = 1
    /// Weekly 時の曜日指定（Calendar weekday 番号 1=日〜7=土）
    var reminderWeekdays: [Int] = []
    var reminderRepeatEndCondition: RepeatEndCondition? = nil
    var reminderRepeatEndCount: Int = 3
    var reminderRepeatEndDate: Date? = nil
    var reminderOccurrenceCount: Int = 0
    var reminderLastScheduledCount: Int = 0

    init(title: String, sortOrder: Int = 0) {
        self.title = title
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }
}

// MARK: - Schema Versioning

/// リリース済みアプリの現行スキーマをV1として定義する。
/// 今後 TodoList / Todo のプロパティ追加・型変更・リネームを行う際は、
/// 新しい VersionedSchema（TaskTuneSchemaV2 など）を追加し、
/// TaskTuneMigrationPlan.stages に変換ルール（MigrationStage）を追加すること。
/// これにより端末上のデータを保持したまま安全にスキーマを移行できる
/// （ストアの削除・再作成は行わない）。
enum TaskTuneSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [TodoList.self, Todo.self] }
}

enum TaskTuneMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [TaskTuneSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
