import Foundation

class NewsService: ObservableObject {
    static let shared = NewsService()

    // MARK: - East Money Flash News
    func fetchLatestNews(page: Int = 1) async throws -> [NewsItem] {
        // Try East Money flash news first
        if let items = try? await fetchEastMoneyNews(page: page), !items.isEmpty {
            return items
        }
        // Fallback to Sina financial live
        return (try? await fetchSinaNews()) ?? []
    }

    func fetchEastMoneyNews(page: Int = 1) async throws -> [NewsItem] {
        let urlString = "https://np-listapi.eastmoney.com/comm/web/getFastNewsList?client=web&biz=web_news_flash&page=\(page)&pagesize=20&order=1"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("https://kuaixun.eastmoney.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataObj = json["data"] as? [String: Any],
           let list = dataObj["list"] as? [[String: Any]] {
            return list.compactMap { parseEastMoneyItem($0) }
        }
        return []
    }

    func fetchSinaNews() async throws -> [NewsItem] {
        let urlString = "https://zhibo.sina.com.cn/api/zhibo/feed?zhibo_id=152&page=1&page_size=20&tag_id=0&dire=f&dpc=1"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("https://finance.sina.com.cn", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = json["result"] as? [String: Any],
           let resultData = result["data"] as? [String: Any],
           let feed = resultData["feed"] as? [String: Any],
           let list = feed["list"] as? [[String: Any]] {
            return list.compactMap { parseSinaItem($0) }
        }
        return []
    }

    func fetchStockAnnouncements(stockCode: String) async throws -> [NewsItem] {
        let code = stockCode.hasPrefix("sh") || stockCode.hasPrefix("sz") || stockCode.hasPrefix("bj")
            ? String(stockCode.dropFirst(2)) : stockCode
        let urlString = "https://np-anotice-stock.eastmoney.com/api/security/ann?sr=-1&page_size=20&page_index=1&ann_type=A&client_source=web&stock_list=\(code)"
        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataObj = json["data"] as? [String: Any],
           let list = dataObj["list"] as? [[String: Any]] {
            return list.compactMap { parseAnnouncementItem($0) }
        }
        return []
    }

    // MARK: - Parsers
    private func parseEastMoneyItem(_ dict: [String: Any]) -> NewsItem? {
        guard let title = dict["title"] as? String else { return nil }
        let id = (dict["id"] as? String) ?? (dict["id"] as? Int).map { String($0) } ?? UUID().uuidString
        let summary = dict["digest"] as? String ?? title
        let source = dict["medianame"] as? String ?? "东方财富"
        let urlStr = dict["url"] as? String ?? ""
        let timeStr = dict["showtime"] as? String ?? ""
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = formatter.date(from: timeStr) ?? Date()
        return NewsItem(id: id, title: title, summary: summary, source: source, publishTime: date, url: urlStr)
    }

    private func parseSinaItem(_ dict: [String: Any]) -> NewsItem? {
        guard let content = dict["rich_text"] as? String, !content.isEmpty else { return nil }
        let id = dict["id"] as? String ?? UUID().uuidString
        let timeStr = dict["create_time"] as? String ?? ""
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = formatter.date(from: timeStr) ?? Date()
        return NewsItem(id: id, title: content, summary: content, source: "新浪财经", publishTime: date, url: "")
    }

    private func parseAnnouncementItem(_ dict: [String: Any]) -> NewsItem? {
        guard let title = dict["NOTICETITLE"] as? String else { return nil }
        let id = dict["INFOCODE"] as? String ?? UUID().uuidString
        let timeStr = dict["NOTICEDATE"] as? String ?? ""
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = formatter.date(from: timeStr) ?? Date()
        return NewsItem(id: id, title: title, summary: title, source: "公告", publishTime: date, url: "")
    }
}
