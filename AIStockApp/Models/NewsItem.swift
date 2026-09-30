import Foundation

struct NewsItem: Identifiable, Codable {
    let id: String
    let title: String
    let summary: String
    let source: String
    let publishTime: Date
    let url: String
    var sentiment: NewsSentiment?

    enum NewsSentiment: String, Codable {
        case positive = "利好"
        case negative = "利空"
        case neutral = "中性"
    }

    var timeAgo: String {
        let interval = Date().timeIntervalSince(publishTime)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval/60))分钟前" }
        if interval < 86400 { return "\(Int(interval/3600))小时前" }
        return "\(Int(interval/86400))天前"
    }
}
