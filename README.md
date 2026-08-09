# TaskTune

SwiftUI と SwiftData で構築した iOS 向け Todo リストアプリです。  
複数リストの管理・繰り返し Todo・ローカル通知・ホーム画面ウィジェットなど、日々のタスク管理に必要な機能を備えています。

A to-do list app for iOS built with SwiftUI and SwiftData, featuring multiple lists, repeating tasks, local notifications, and customizable home screen widgets.

**App Store**: [TaskTune on the App Store](https://apps.apple.com/jp/app/tasktune/id6776622457)

---

## 機能 / Features

- **Todo管理 / Todo management**  
追加・編集・完了・削除・並び替え。未完了／完了セクションに自動振り分け。  
Add, edit, complete, delete, and reorder todos with automatic pending/completed grouping.
- **複数リスト管理 / Multiple lists**  
リストの作成・名前変更・並び替え・削除。  
Create, rename, reorder, and delete lists.
- **検索 / Search**  
全リスト・全Todoを横断検索。  
Cross-list search across all todos.
- **期日と通知 / Due dates & notifications**  
期日設定時にローカル通知をスケジュール。通知バナーから直接完了操作が可能。  
Schedule local notifications on due dates; complete tasks directly from the banner.
- **繰り返し Todo / Repeating todos**  
日・週（曜日指定）・月・年単位の繰り返しに対応。終了条件（なし／N回後／指定日）も設定可能。  
Daily, weekly (by weekday), monthly, and yearly recurrence with end conditions.
- **リストリマインダー / List reminders**  
未完了件数がある場合のみ発火するリスト単位のリマインダー通知。  
Per-list reminder notifications that fire only when incomplete tasks exist.
- **ホーム画面ウィジェット / Home screen widgets**  
Small・Medium・Large の3サイズ。タップで完了できるインタラクティブモードと読み取り専用モードを選択可能。  
Three widget sizes with interactive tap-to-complete or read-only mode.
- **ウィジェットテーマ / Widget themes**  
アクセントカラー・背景色・テキスト色・チェックボックスデザインなどを自由にカスタマイズしたテーマを複数保存可能。  
Create and save multiple themes with custom colors, fonts, and checkbox styles.
- **サウンド & ハプティクス / Sound & haptics**  
Todo完了時のサウンドとハプティクスをそれぞれ設定でON/OFF可能。  
Configurable sound and haptic feedback on task completion.
- **日英ローカライズ / Localization**  
日本語・英語に対応。  
Japanese and English supported.

---

## 実装の工夫 / Implementation Highlights

1. インタラクティブウィジェット / Interactive Widgets (iOS 17+)

   WidgetKitのインタラクティブ機能を活用し、ホーム画面からアプリを開かずにTodoを完了できる。  
   Leverages WidgetKit Interactive Widgets so users can complete tasks directly from the home screen.

   - **チェックボックス領域のみ受付 / Tap target scoped to checkbox**  
     誤タップを防ぐため、完了トグルの受け付けはチェックボックス領域のみに限定している。  
     The interactive tap target is scoped to the checkbox area only, preventing accidental completions.
   - **フラッシュアニメーション / Flash animation on completion**  
     タップ後にチェックマークのフラッシュアニメーションを表示してからデータを更新し、操作の応答を明示する。  
     A checkmark flash animation plays before the data update to give immediate visual feedback.

1. 繰り返し通知の先読みスケジューリング / Lookahead Notification Scheduling

   アプリを長期間起動しなくても通知が継続発火するよう、以下の仕組みを実装している。  
   To ensure repeating notifications fire reliably even without frequent app launches:

   - **先読み登録 / Pre-scheduling**  
     繰り返しTodoの通知を最大7件分まとめて事前登録し、次回起動時に不足分を補充（top-up）する。  
     Up to 7 future occurrences are scheduled at once and topped up on each foreground resume.
   - **完了時の現サイクル抑止 / Cycle suppression on completion**  
     Todo完了時に現サイクルの通知のみキャンセルし、未来サイクルの先読み通知はそのまま維持する。  
     Only the current-cycle notification is cancelled on completion; future pre-scheduled notifications remain intact.
   - **過ぎたサイクルの自動前進 / Auto-advance of overdue cycles**  
     フォアグラウンド復帰時に期日超過した繰り返しTodoをスキャンし、未完了は `missedCount` を加算して次周期へ前進させる。  
     On foreground resume, overdue repeating todos are scanned; incomplete ones increment `missedCount` and advance to the next cycle.

1. AVAudioEngine による合成サウンド / Synthesized Audio via AVAudioEngine

   サウンドのデザイン自体をコードで完結させるため、音声ファイルを使わず波形をコードで生成する設計を採用している。  
   To keep sound design entirely within code, sounds are synthesized via waveform generation rather than bundled audio files.

   - **波形生成 / Waveform synthesis**  
     サイン波・矩形波などを組み合わせた波形をリアルタイムで生成し、`AVAudioPlayerNode` で再生する。  
     Waveforms combining sine and square waves are synthesized at runtime and played via `AVAudioPlayerNode`.
   - **メディアボリューム連動 / Media volume integration**  
     `AVAudioSession` カテゴリを `.ambient` に設定することで、システムのメディアボリュームに連動させる。  
     The session category is set to `.ambient` so volume follows the system media level.

---

## 技術スタック / Tech Stack

| Category | Technology |
|---|---|
| Language | Swift |
| UI | SwiftUI |
| Persistence | SwiftData |
| Notifications | UserNotifications |
| Widgets | WidgetKit (Interactive, iOS 17+) |
| Audio | AVAudioEngine |
| Data sharing | App Groups |
| Platform | iOS 26.0+ |

---

## セットアップ / Setup

### 1. リポジトリをクローン / Clone the repository

```bash
git clone https://github.com/inoue-kk/todo-list.git
cd todo-list
```

### 2. 識別子を設定 / Configure your identifiers

以下のプレースホルダーを自分の値に置き換えてください。  
Replace the following placeholders with your own values.

| Placeholder | 置き換え先 / Replace with | ファイル / File |
|---|---|---|
| `com.yourname.tasktune` | Your Bundle ID | `project.pbxproj` |
| `com.yourname.tasktune.TodoListWidget` | Widget Bundle ID | `project.pbxproj` |
| `group.com.yourname.tasktune` | Your App Group ID | `*.entitlements`, `todo_listApp.swift`, `WidgetTheme.swift`, `TodoListWidget.swift` |

Xcodeで各ターゲットの「Signing & Capabilities」からTeamとBundle Identifierを設定してください。App GroupはApple Developer Portalで作成・登録が必要です。

Open `todo-list.xcodeproj` in Xcode, set your Team and Bundle Identifier under Signing & Capabilities for each target. Register the App Group at [developer.apple.com](https://developer.apple.com).

### 3. ビルド / Build & Run

`todo-list.xcodeproj` をXcodeで開き、シミュレータまたは実機でビルドしてください。  
ウィジェットとプッシュ通知は実機が必要です。

Open `todo-list.xcodeproj` and run on a simulator or device. Widgets and push notifications require a physical device.
