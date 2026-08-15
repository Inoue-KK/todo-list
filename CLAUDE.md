# todo-list

## Claude へのルール

- **コミット前に必ず CLAUDE.md を更新すること。** 機能追加・変更・UI改修を行った場合、対応する記述をコードと同じコミットに含める。
- コミットメッセージは英語・Conventional Commits 形式・1行のみ（本文・箇条書き不可）
- コミット粒度は機能単位で細かく。複数の独立した変更は別コミットにする
- 実機動作確認の返答があるまでコミットしない

シンプルでモダンなデザインのiOS向けTodoリストアプリ。アプリ名は **TaskTune**。

## 技術スタック

- **言語:** Swift
- **UI:** SwiftUI
- **データ永続化:** SwiftData
- **対象プラットフォーム:** iOS 26.0+
- **最小構成:** Xcodeデフォルトテンプレートをベースに構築

## ファイル構成

```
todo-list/
├── todo_listApp.swift        # エントリポイント（App Group対応・WidgetKit連携）
├── TodoList.swift            # リストモデル（@Model）
├── Todo.swift                # Todoモデル（@Model、TodoListと親子関係）
├── WidgetTheme.swift         # ウィジェットテーマモデル（両ターゲット共通）
├── ListsView.swift           # ホーム画面（リスト一覧・ディープリンク対応）
├── ContentView.swift         # リスト詳細画面（Todo一覧・セクション分け）
├── SettingsView.swift        # 設定画面（Form・push遷移）
├── AddListView.swift         # リスト追加シート
├── AddTodoView.swift         # Todo追加シート（期日・繰り返し設定トグル付き）
├── EditTodoView.swift        # Todo編集シート（タイトル・期日・繰り返し変更）
├── NotificationManager.swift # UserNotifications管理（スケジュール・キャンセル・権限）
├── WeekdaySelectorView.swift # 曜日選択UI（Weekly繰り返し時に表示）
├── RenameListView.swift      # リスト名変更シート
├── ListReminderView.swift    # リストリマインダー設定シート
├── WidgetThemeListView.swift # ウィジェットテーマ一覧（Settingsからpush遷移）
├── WidgetThemeEditView.swift # ウィジェットテーマ編集（ColorPicker・プレビュー）
├── WidgetPreviewViews.swift  # ウィジェットプレビュー用ビュー（WidgetKit非依存）
├── en.lproj/
│   └── Localizable.strings   # 英語ローカライズ文字列
└── ja.lproj/
    └── Localizable.strings   # 日本語ローカライズ文字列

TodoListWidget/
├── TodoListWidgetBundle.swift  # ウィジェットのエントリポイント（@main）
├── TodoListWidget.swift        # ウィジェット実装（Small/Medium/Large・インタラクティブ対応）
├── en.lproj/
│   └── Localizable.strings   # ウィジェット Extension 用英語ローカライズ
└── ja.lproj/
    └── Localizable.strings   # ウィジェット Extension 用日本語ローカライズ

design/                   # アイコン制作用素材（Xcodeビルド対象外）
```

## 主な機能

- 複数のTodoリストを作成・管理（タイトル付き）
- リスト名の変更（一覧画面のスワイプ or 詳細画面のタイトルタップ）
- 検索（ホーム画面の `.searchable` バー）：リスト名と全Todoのタイトルを横断検索。結果は「Lists」「Todos」セクションに分けて表示し、Todo結果には親リスト名を併記。Todo結果タップで該当リストへ遷移（検索文字列はクリア）。完了済みTodoも検索対象に含む。検索中は + ボタンを非表示
- Todoの追加（シートUI）。「Notify on due date」トグルで期日（日時）と通知を同時に設定。期日設定時に「Repeat」トグルで繰り返しをON/OFFし、ONの場合に間隔（Daily/Weekly/Monthly/Yearly）を選択可能。Daily/Monthly/Yearly は N 日/月/年ごとの Stepper で間隔指定可能。Weekly 選択時は曜日ボタン（WeekdaySelectorView）で複数曜日を指定可能。繰り返し設定時は「End Repeat」ピッカーで終了条件（Never / After N repeats / On Date）を選択可能。期日設定時に「完了済みの場合は通知されません。」の注釈を表示
- Todo行タップで編集シートを表示（タイトル・期日・繰り返しを変更可能）
- タップでチェックON/OFF（アニメーション付き）。完了時にサウンド・ハプティクスを発火（設定でON/OFF可能）。完了/未完了切替時は `NotificationManager.schedule(for:)` を呼び出し、繰り返しTodoは現サイクル分だけ抑止して未来サイクルの先読み通知は維持される
- 期日（dueDate）の表示：未完了Todoの行に期日ラベルを表示（期限切れ=赤、当日=オレンジ、将来=グレー）
- 繰り返しTodoの表示：行に🔁アイコンを表示。未達成回数が1以上の場合は「Missed ×N」ラベルを赤で表示
- 期日通知：UserNotifications（ローカル通知）。期日到達時にバナー通知。通知から「Mark Complete」アクションで直接完了可能。バナータップで該当リストへ遷移。アプリ起動時に通知権限を要求
- 繰り返しTodoの通知先読み：`NotificationManager.maxScheduledOccurrences`（デフォルト7）件分の未来サイクル通知を一度に登録。アプリを長期間開かなくても N サイクル分は通知が継続発火する。アプリを `.active` 復帰した際に未来サイクル分を補充（top-up）する
- 繰り返しTodoの自動前進：アプリがフォアグラウンドに戻ったとき（scenePhase == .active）に期日超過した繰り返しTodoをスキャン。未完了は missedCount を加算して次周期へ前進、完了済みはリセットして次周期へ前進（Pending に戻す）
- リストリマインダー：各リストに未達成件数を通知するリマインダーを設定可能（`ListReminderView`）。「Notify incomplete tasks」トグルでON/OFF。繰り返し間隔（Daily/Weekly/Monthly/Yearly）・N単位ごと指定・曜日選択（Weekly時）・「End Repeat」ピッカーで終了条件（Never/After N/On Date）を提供。未達成件数がゼロの場合は通知しない。ContentView ツールバーのベルアイコンから設定（有効時は `bell.fill`+アクセントカラー）。Todo完了・削除時およびフォアグラウンド復帰時に自動再スケジュール
- 「未完了」「完了」セクションへの自動振り分け
- スワイプで削除（リスト・Todo両対応）。リスト削除時は確認ダイアログを表示（全Todoが cascade delete されるため）
- ドラッグで並び替え（リスト一覧・Pending/Completedセクション内のTodo）
- エンプティステート表示
- ホーム画面ウィジェット（Small/Medium/Large）
  - 表示するリストをウィジェット設定で選択可能
  - ウィジェット設定でテーマを選択（アプリ内で作成したテーマを適用）
  - ウィジェット設定で操作モードを選択（「タップで完了」／「読み取り専用」）。全サイズ共通
  - 「タップで完了」モード時はチェックボックスをタップしてTodoを完了にできる（iOS 17 Interactive Widgets）
  - Todo完了タップはチェックボックス領域のみ受け付ける（誤タップ防止）
  - Todo完了時にチェックマークのフラッシュアニメーションを表示してからデータ更新
  - Smallウィジェットはヘッダー＋Todoリスト表示（Medium/Largeと同様のレイアウト、横パディング12pt）
  - 未設定時（`listTitle` が nil）は先頭リストにフォールバックせず、操作案内テキストを表示（`isSetup: true`）。Smallは `.caption` フォント＋折り返し、Medium/Largeは通常フォントで表示
  - ウィジェットタップで該当リストを直接開く（ディープリンク）
  - アプリがバックグラウンドに移行したタイミングでウィジェットを自動更新
  - iOS 26 Liquid Glass（Accented rendering mode）対応
  - ウィジェット設定に `.contentMarginsDisabled()` を適用し、システム自動マージンを無効化。プレビューとの表示一致を保証
  - Smallのヘッダー件数表示はコンパクト形式（チェックボックスアイコン＋数字）。Medium/Largeは `%lld left` / `%lld done` のテキスト形式。`WidgetHeaderView` が `@Environment(\.widgetFamily)` で分岐
- 設定画面（ListsView右上のギアアイコン → push遷移）
  - Appearance セクション：アクセントカラーを `UIColorPickerButton`（ポップオーバーピッカー）で設定。`@AppStorage("accentColor")` に hex 文字列（例: `#007AFF`）で保存
  - Sound・Haptic Feedbackのトグル（`@AppStorage` で永続化）
  - Sound有効時にSound Effect選択画面へのNavigationLink表示（タップでプレビュー再生）
  - About（バージョン情報）
- ウィジェットテーマ管理（設定画面 → Widget Themes）
  - アプリ内でテーマを作成・編集・削除
  - Small/Medium/Largeのリアルタイムプレビュー付き
  - アクセントカラー・背景色・テキスト色をColorPickerで自由に設定
  - 文字サイズ・行の高さ・チェックボックス位置・表示設定も編集可能
  - チェックボックスのデザインを10種類から選択可能（`WidgetCheckboxStyleValue`）
  - 複数テーマを保存し、ウィジェットごとに使い分け可能

## 設計方針

- SwiftDataで永続化。`TodoList` が `@Relationship(deleteRule: .cascade)` で `Todo` を管理
- リスト削除時にTodoも自動削除される
- `TodoList.sortOrder` と `Todo.sortOrder` で並び順を永続管理（ドラッグ並び替え時に更新）
- システムカラーを使用してダーク/ライトモードに自動対応
- ローカライズは英語（en）・日本語（ja）に対応済み。`Text("literal")` は `LocalizedStringKey` として自動ローカライズ。変数文字列は `Text(LocalizedStringKey(variable))` または `NSLocalizedString` を使用
- iCloud同期（CloudKit連携）は **Apple Developer Program（年間$99）への加入が必須** のため、現時点では対応しない。リリース時に有料契約が整っていれば対応を検討する
- 不要な抽象化を避け、最小限のコードで実装する
- App Group（`group.com.inoue-kk.tasktune`）経由でメインアプリとウィジェットがSwiftDataストアを共有
- ウィジェットとのディープリンクはURLスキーム `tasktune://list/{リスト名}` を使用
- `ListsView` は `NavigationPath` でプログラマティックナビゲーションに対応。`.toolbarTitleDisplayMode(.inline)` でタイトルを常に中央固定
- 設定画面（`SettingsView`）は `ListsView` の `NavigationStack` 内に push 遷移。独自の `NavigationStack` を持たない
- `WidgetThemeListView` は `SettingsView` からの push 遷移先。独自の `NavigationStack` を持たない
- サウンドは `AVAudioEngine` + `AVAudioPlayerNode` で波形を生成して再生（`AVAudioSession` カテゴリ `.ambient` でメディアボリューム連動）。ハプティクスは `.sensoryFeedback(.success)` を使用。どちらも Todo 完了時のみ発火
- サウンドの種類は `CompletionSound` enum（`SettingsView.swift`）で管理。設定画面の「Sound Effect」から選択・プレビュー可能
- 設定値は `@AppStorage`（`soundEnabled`・`hapticEnabled`・`selectedSound`・`accentColor`）で永続化
- アクセントカラー（`accentColor`）は hex 文字列で保存。`Color(hex:)` / `.hexString` / `.isLight` 拡張（`SettingsView.swift`）で変換・明度判定。適用箇所：+ ボタン（`.glassEffect` tint・アイコン色）・Todoチェックマーク（`.symbolRenderingMode(.palette)` で丸とチェックを独立指定）・各種トグルスイッチ（Sound / Haptic / Due Date）・Add/Save/Add List ボタン背景・WeekdaySelectorView の選択曜日。歯車アイコンはシステムデフォルト色（淡い色を選んだ際の視認性確保のため）。テキストへのグローバル tint は使わない
- アクセントカラーが明色（`isLight == true`）の場合、前景色は `Color(white: 0.3)`（濃いグレー）を使用。暗色の場合は `Color.white`。`isLight` は BT.601 輝度式（`0.299R + 0.587G + 0.114B > 0.6`）で判定。ダークモードに左右されない固定色を使うことで一貫したコントラストを確保
- `UIColorPickerButton`（`WidgetThemeEditView.swift`）はウィジェットテーマ編集と `SettingsView` の両方から使用するため `internal`（非 `private`）
- `WidgetThemeEditView` の Display セクションのトグルは `.tint(theme.accentColor)` で編集中テーマのアクセントカラーを反映
- `TodoList.swift`・`Todo.swift`・`WidgetTheme.swift` はメインアプリ（`todo-list`）・ウィジェット（`TodoListWidgetExtension`）両ターゲットに含める
- ウィジェットテーマは `WidgetTheme`（`Codable & Sendable`）として App Group の UserDefaults（キー: `widgetThemes`）に JSON 保存
- テーマの色は `ColorComponents`（RGBA）で保存。`nil` の場合はシステムカラー（自動）を使用
- チェックボックスのデザインは `WidgetCheckboxStyleValue` enum（10種類）で管理し、テーマに含めて保存
- ウィジェットは `@Environment(\.widgetRenderingMode)` で `.accented` モードを検出し、iOS 26 Liquid Glass に対応
- ウィジェットプレビュー用ビュー（`WidgetPreviewViews.swift`）は WidgetKit 専用 API を使わず、メインアプリのみのターゲットに含める。`WidgetPreviewData` のサンプルデータは `NSLocalizedString` でローカライズ済み
- ウィジェット Extension は独自バンドルを持つため、`todo-list/` の `Localizable.strings` とは別に `TodoListWidget/en.lproj/` と `TodoListWidget/ja.lproj/` を管理する。同じキー（`"%lld left"` など）はプレビュー用に `todo-list/` 側にも重複して定義する必要がある
- `Todo` モデルは `dueDate: Date?`・`notificationID: String`・`repeatInterval: RepeatInterval?`・`repeatIntervalCount: Int`・`repeatWeekdays: [Int]`・`missedCount: Int`・`repeatEndCondition: RepeatEndCondition?`・`repeatEndCount: Int`・`repeatEndDate: Date?`・`repeatOccurrenceCount: Int` を持つ。SwiftData は optional / デフォルト値付きプロパティのライトウェイトマイグレーションを自動処理する
- スキーマバージョン管理は `TodoList.swift` 末尾の `TaskTuneSchemaV1`（`VersionedSchema`）・`TaskTuneMigrationPlan`（`SchemaMigrationPlan`）で行う。`todo_listApp.swift`・`TodoListWidget.swift` の `ModelContainer` 初期化時に `migrationPlan:` として渡している。**型変更・リネームなどライトウェイトマイグレーションで自動対応できない変更を行う場合は、新しい `TaskTuneSchemaV2` を追加し `TaskTuneMigrationPlan.stages` に `MigrationStage` を追加すること（ストアの削除・再作成は行わない）**。過去にあった「スキーマバージョン不一致時にストアを削除して再作成する」ロジックは、既存ユーザーのデータを丸ごと消失させる重大なリスクがあったため撤去済み。`ModelContainer` の作成自体が失敗する回復不能なケースのみ、ストアを削除せず `tasktune-corrupted-<timestamp>.store` にリネーム退避してから空のストアを作り直す
- `RepeatInterval` enum（`Todo.swift` に定義）は `String, Codable, CaseIterable`。`calendarComponent` プロパティで Calendar.Component に変換。`unitLabel(count:)` で単数/複数形のラベルを返す
- `RepeatEndCondition` enum（`Todo.swift` に定義）は `String, Codable`。`.afterCount`（N回繰り返し後に終了）と `.onDate`（特定日以降の次サイクルを停止）の2ケース。終了条件到達時は `todo_listApp.swift` の `stopRepeating` で `repeatInterval` をクリアして非繰り返しTodoに変換する
- `repeatWeekdays` は Calendar の weekday 番号（1=日〜7=土）の配列。Weekly かつ非空の場合に曜日指定繰り返しとして扱う
- `nextWeekdayOccurrence(after:weekdays:time:)` は `Todo.swift` に定義された自由関数。指定曜日リストの次回最近日時を返す
- `nextCycleDate(after:for:)`・`upcomingCycleDates(for:count:)` も `Todo.swift` の自由関数。前者は次サイクル日時、後者は終了条件・完了状態を尊重して未来サイクル日時を最大 N 件返す（通知の先読みスケジュールに使用）
- 通知は `NotificationManager`（`@MainActor` シングルトン）が一元管理。`UNUserNotificationCenterDelegate` を実装してフォアグラウンド時もバナー表示。通知の `userInfo` に `notificationID`・`listTitle` を埋め込み。「Mark Complete」アクション（カテゴリ `TODO_DUE`）で通知から直接完了し、再 `schedule(for:)` で現サイクルを抑止
- 繰り返しTodoの通知IDスキームは `"\(notificationID)_\(index)"`（index は 0..N-1 のサイクル先読み順）。`cancel(for:)` は新旧スキーム互換のため `_0..N-1` と旧曜日番号 `_1..7` を両方キャンセル
- 繰り返しTodoの自動前進ロジックは `todo_listApp.swift` の `advanceOverdueRepeatingTodos(in:)` 関数で実装。`nextCycleDate` を使い曜日指定/インターバル両対応で過ぎたサイクル数を `cycles` としてカウント。dueDate が未来でも各 todo について `schedule(for:)` を呼び出し、発火済み通知の補充（top-up）を行う
- `WeekdaySelectorView` は曜日選択 UI コンポーネント。各曜日を `.glassEffect(in: Circle())` で Liquid Glass スタイルで表示。選択時は `.regular.tint(.blue)` で青いガラス。`DragGesture` でプレス状態を管理し、プレス中は `scaleEffect(1.18)` + `spring(bounce: 0.6)` でバウンス
- `AddTodoView`・`EditTodoView` のシート高さはともに内部の `selectedDetent` で動的に切り替え（340pt / 600pt / 700pt）。期日なし=340、期日あり=600、繰り返し+終了条件値あり=700
- `TodoList` モデルはリマインダー用プロパティ（`reminderEnabled`・`reminderTime`・`reminderRepeatInterval`・`reminderRepeatIntervalCount`・`reminderWeekdays`・`reminderRepeatEndCondition`・`reminderRepeatEndCount`・`reminderRepeatEndDate`・`reminderOccurrenceCount`・`reminderLastScheduledCount`）を持つ。SwiftData のライトウェイトマイグレーションで自動対応
- リストリマインダーの通知IDスキームは `"list_reminder_\(list.id)"`（単発）・`"list_reminder_\(list.id)_\(index)"`（繰り返し）・`"list_reminder_\(list.id)_\(weekday)_\(index)"`（Weekly曜日指定）。`cancelListReminder` は全パターンを一括キャンセル。`reminderLastScheduledCount` で前回スケジュール件数を記録し、フォアグラウンド復帰時に発火済み件数を算出して `reminderOccurrenceCount` を更新（After N 終了条件の追跡に使用）
- `WeekdaySelectorView` を使うシートは `.presentationBackground(.background)` が必須（省略すると Liquid Glass が描画されずジェスチャーも正常動作しない）

## シートUI共通仕様

- `presentationDetents([.height(280)])` で固定高さ
- `presentationCornerRadius(20)` で角丸
- Add/Saveボタン：青のフルボタン（未入力時は `Color.primary.opacity(0.06)` 背景 + secondary テキストで控えめに非活性表示）
- Cancelボタン：セカンダリカラーのテキストボタン
