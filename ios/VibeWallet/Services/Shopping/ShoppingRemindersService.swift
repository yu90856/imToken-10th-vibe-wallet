import EventKit
import Foundation

struct ShoppingReminderItem: Sendable, Identifiable {
    let id: String
    let title: String
    let notes: String?

    var searchQuery: String {
        let titlePart = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesPart = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if notesPart.isEmpty { return titlePart }
        if titlePart.isEmpty { return notesPart }
        return "\(titlePart) \(notesPart)"
    }
}

enum ShoppingRemindersError: LocalizedError {
    case accessDenied
    case listNotFound

    private static let listTitle = "Vibe 購物"

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "請在 iPhone「設定 → 隱私權 → 提醒事項」允許 Vibe Wallet 存取。"
        case .listNotFound:
            return "找不到「\(Self.listTitle)」清單。請在「提醒事項」App 建立同名清單並加入購物項目。"
        }
    }
}

@MainActor
enum ShoppingRemindersService {
    static let listTitle = "Vibe 購物"

    static func requestAccessIfNeeded() async -> Bool {
        let store = EKEventStore()
        return await withCheckedContinuation { continuation in
            store.requestFullAccessToReminders { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    static func fetchIncompleteItems() async throws -> [ShoppingReminderItem] {
        let store = EKEventStore()
        guard let list = store.calendars(for: .reminder).first(where: { $0.title == listTitle }) else {
            throw ShoppingRemindersError.listNotFound
        }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: [list]
        )

        return try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let items = (reminders ?? [])
                    .filter { !$0.isCompleted }
                    .sorted {
                        ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
                    }
                    .prefix(5)
                    .map {
                        ShoppingReminderItem(
                            id: $0.calendarItemIdentifier,
                            title: $0.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                                ? ($0.title ?? "未命名")
                                : "未命名",
                            notes: $0.notes
                        )
                    }
                continuation.resume(returning: Array(items))
            }
        }
    }

    /// 通知監控用：回傳清單內所有未完成項目（不截斷筆數）
    static func fetchAllIncompleteItems() async throws -> [ShoppingReminderItem] {
        let store = EKEventStore()
        guard let list = store.calendars(for: .reminder).first(where: { $0.title == listTitle }) else {
            throw ShoppingRemindersError.listNotFound
        }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: [list]
        )

        return try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let items = (reminders ?? [])
                    .filter { !$0.isCompleted }
                    .sorted {
                        ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
                    }
                    .map {
                        ShoppingReminderItem(
                            id: $0.calendarItemIdentifier,
                            title: $0.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                                ? ($0.title ?? "未命名")
                                : "未命名",
                            notes: $0.notes
                        )
                    }
                continuation.resume(returning: items)
            }
        }
    }
}
