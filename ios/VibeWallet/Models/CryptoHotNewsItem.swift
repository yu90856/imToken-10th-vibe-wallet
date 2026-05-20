import Foundation

struct CryptoHotNewsItem: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let body: String
    let publishedAt: Date
    /// 討論熱度（留言／轉發等加權，示範用）
    let discussionScore: Int
    let source: String
    let articleURL: String?

    var relativeTimeLabel: String {
        let minutes = max(1, Int(Date().timeIntervalSince(publishedAt) / 60))
        if minutes < 60 { return "\(minutes) 分鐘前" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) 小時前" }
        return "\(hours / 24) 天前"
    }
}
