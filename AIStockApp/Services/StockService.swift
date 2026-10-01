import Foundation
import Combine

class StockService: ObservableObject {
    static let shared = StockService()

    // MARK: - Real-time Quote (Sina Finance API)
    func fetchQuote(codes: [String]) async throws -> [Stock] {
        let codeString = codes.joined(separator: ",")
        let urlString = "https://hq.sinajs.cn/list=\(codeString)"
        guard let url = URL(string: urlString) else { throw StockError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("https://finance.sina.com.cn", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)
        // Try GBK first (Sina returns GBK encoding)
        let responseString = String(data: data, encoding: .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))))
            ?? String(data: data, encoding: .utf8)
            ?? ""
        return parseSinaResponse(responseString, codes: codes)
    }

    // MARK: - K-Line Data (East Money API)
    func fetchKLine(code: String, period: KLinePeriod = .daily) async throws -> [KLineData] {
        let secid: String
        if code.hasPrefix("sh") {
            secid = "1.\(code.dropFirst(2))"
        } else if code.hasPrefix("bj") {
            secid = "0.\(code.dropFirst(2))"
        } else {
            secid = "0.\(code.dropFirst(2))"
        }
        let urlString = "https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=\(secid)&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61&klt=\(period.rawValue)&fqt=1&end=20500101&lmt=120"

        guard let url = URL(string: urlString) else { throw StockError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(EastMoneyKLineResponse.self, from: data)
        return parseKLineData(response)
    }

    // MARK: - Search Stocks
    func searchStock(keyword: String) async throws -> [SearchResult] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        // 1. Try Tencent smartbox API (supports Chinese names, pinyin, and codes)
        if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://smartbox.gtimg.cn/s3/?q=\(encoded)&t=all") {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 5
            
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let text = String(data: data, encoding: .utf8) {
                let results = parseTencentSearch(text)
                if !results.isEmpty {
                    return results
                }
            }
        }
        
        // 2. Fallback to Eastmoney suggest API
        if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://searchapi.eastmoney.com/api/suggest/get?input=\(encoded)&type=14") {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let table = json["QuotationCodeTable"] as? [String: Any],
               let list = table["Data"] as? [[String: Any]] {
                return list.compactMap { item -> SearchResult? in
                    guard let code = item["Code"] as? String,
                          let name = item["Name"] as? String else { return nil }
                    let jys = "\(item["JYS"] ?? "1")"
                    let exchange = (jys == "1" || code.hasPrefix("6")) ? "sh" : "sz"
                    return SearchResult(name: name, code: code, exchange: exchange)
                }
            }
        }
        
        return []
    }


    // MARK: - Parsers
    private func parseSinaResponse(_ response: String, codes: [String]) -> [Stock] {
        var stocks: [Stock] = []
        let lines = response.components(separatedBy: "\n").filter { $0.contains("=") }

        for (index, line) in lines.enumerated() {
            guard index < codes.count else { break }
            let code = codes[index]

            if let rangeStart = line.range(of: "=\""),
               let rangeEnd = line.range(of: "\"", range: rangeStart.upperBound..<line.endIndex) {
                let dataString = String(line[rangeStart.upperBound..<rangeEnd.lowerBound])
                let parts = dataString.components(separatedBy: ",")

                if parts.count >= 33 {
                    let exchange: Stock.StockExchange
                    if code.hasPrefix("sh") { exchange = .sh }
                    else if code.hasPrefix("bj") { exchange = .bj }
                    else { exchange = .sz }

                    let stockCode = String(code.dropFirst(2))
                    let currentPrice = Double(parts[3]) ?? 0
                    let prevClose = Double(parts[2]) ?? 0
                    let change = currentPrice - prevClose
                    let changePercent = prevClose > 0 ? (change / prevClose * 100) : 0

                    let stock = Stock(
                        id: stockCode,
                        name: parts[0],
                        currentPrice: currentPrice,
                        change: change,
                        changePercent: changePercent,
                        open: Double(parts[1]) ?? 0,
                        high: Double(parts[4]) ?? 0,
                        low: Double(parts[5]) ?? 0,
                        volume: Double(parts[8]) ?? 0,
                        turnover: Double(parts[9]) ?? 0,
                        exchange: exchange
                    )
                    stocks.append(stock)
                }
            }
        }
        return stocks
    }

    private func parseKLineData(_ response: EastMoneyKLineResponse) -> [KLineData] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")

        var rawList: [KLineData] = (response.data?.klines ?? []).compactMap { line in
            let parts = line.components(separatedBy: ",")
            guard parts.count >= 6,
                  let date = formatter.date(from: parts[0]),
                  let open = Double(parts[1]),
                  let close = Double(parts[2]),
                  let high = Double(parts[3]),
                  let low = Double(parts[4]),
                  let volume = Double(parts[5]) else { return nil }
            return KLineData(date: date, open: open, close: close, high: high, low: low, volume: volume)
        }

        // Calculate MA5, MA10, MA20
        for i in 0..<rawList.count {
            if i >= 4 {
                let sum5 = rawList[(i-4)...i].reduce(0) { $0 + $1.close }
                rawList[i].ma5 = sum5 / 5.0
            }
            if i >= 9 {
                let sum10 = rawList[(i-9)...i].reduce(0) { $0 + $1.close }
                rawList[i].ma10 = sum10 / 10.0
            }
            if i >= 19 {
                let sum20 = rawList[(i-19)...i].reduce(0) { $0 + $1.close }
                rawList[i].ma20 = sum20 / 20.0
            }
        }

        // Calculate MACD (EMA12, EMA26, DIF, DEA, MACD)
        var ema12: Double = 0
        var ema26: Double = 0
        var dea: Double = 0
        for i in 0..<rawList.count {
            let close = rawList[i].close
            if i == 0 {
                ema12 = close
                ema26 = close
                dea = 0
            } else {
                ema12 = (2.0 * close + 11.0 * ema12) / 13.0
                ema26 = (2.0 * close + 25.0 * ema26) / 27.0
            }
            let dif = ema12 - ema26
            dea = (2.0 * dif + 8.0 * dea) / 10.0
            let macdBar = (dif - dea) * 2.0
            rawList[i].dif = dif
            rawList[i].dea = dea
            rawList[i].macd = macdBar
        }

        // Calculate KDJ (9, 3, 3)
        var prevK: Double = 50.0
        var prevD: Double = 50.0
        for i in 0..<rawList.count {
            let startIdx = max(0, i - 8)
            let window = rawList[startIdx...i]
            let low9 = window.map { $0.low }.min() ?? rawList[i].low
            let high9 = window.map { $0.high }.max() ?? rawList[i].high
            let rsv: Double
            if high9 > low9 {
                rsv = ((rawList[i].close - low9) / (high9 - low9)) * 100.0
            } else {
                rsv = 50.0
            }
            let currK = (2.0 * prevK + rsv) / 3.0
            let currD = (2.0 * prevD + currK) / 3.0
            let currJ = 3.0 * currK - 2.0 * currD
            rawList[i].k = currK
            rawList[i].d = currD
            rawList[i].j = currJ
            prevK = currK
            prevD = currD
        }

        // Calculate BOLL (20, 2)
        for i in 0..<rawList.count {
            if i >= 19 {
                let window = rawList[(i-19)...i]
                let mid = window.reduce(0) { $0 + $1.close } / 20.0
                let variance = window.reduce(0) { $0 + pow($1.close - mid, 2) } / 20.0
                let std = sqrt(variance)
                rawList[i].bollMid = mid
                rawList[i].bollUp = mid + 2.0 * std
                rawList[i].bollDown = mid - 2.0 * std
            }
        }

        return rawList
    }

    private func parseTencentSearch(_ text: String) -> [SearchResult] {
        var results: [SearchResult] = []
        guard let start = text.range(of: "\""),
              let end = text.range(of: "\"", range: start.upperBound..<text.endIndex) else {
            return results
        }
        let data = String(text[start.upperBound..<end.lowerBound])
        let items = data.components(separatedBy: "^")
        for item in items {
            let parts = item.components(separatedBy: "~")
            // Format: ex~code~name~pinyin~type
            if parts.count >= 3 {
                let ex = parts[0].lowercased()
                let code = parts[1]
                let name = parts[2]
                if !name.isEmpty && !code.isEmpty {
                    results.append(SearchResult(name: name, code: code, exchange: ex))
                }
            }
        }
        return results
    }

    private func parseSinaSearch(_ text: String) -> [SearchResult] {
        var results: [SearchResult] = []
        if let start = text.range(of: "\""),
           let end = text.range(of: "\"", range: start.upperBound..<text.endIndex) {
            let data = String(text[start.upperBound..<end.lowerBound])
            let items = data.components(separatedBy: ";")
            for item in items.prefix(15) {
                let parts = item.components(separatedBy: ",")
                if parts.count >= 5, !parts[0].isEmpty {
                    results.append(SearchResult(name: parts[0], code: parts[3], exchange: parts[4]))
                }
            }
        }
        return results
    }

    // MARK: - Types
    enum StockError: Error, LocalizedError {
        case invalidURL
        case networkError
        case decodingError
        case noData

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效的URL"
            case .networkError: return "网络错误"
            case .decodingError: return "数据解析错误"
            case .noData: return "无数据"
            }
        }
    }

    enum KLinePeriod: Int {
        case minute5 = 5
        case minute15 = 15
        case minute30 = 30
        case minute60 = 60
        case daily = 101
        case weekly = 102
        case monthly = 103

        var label: String {
            switch self {
            case .minute5: return "5分"
            case .minute15: return "15分"
            case .minute30: return "30分"
            case .minute60: return "60分"
            case .daily: return "日K"
            case .weekly: return "周K"
            case .monthly: return "月K"
            }
        }
    }
}

// MARK: - Supporting Types
struct SearchResult: Identifiable {
    let id = UUID()
    let name: String
    let code: String
    let exchange: String

    var fullCode: String {
        let exLower = exchange.lowercased()
        if exLower.contains("sh") || exchange == "1" { return "sh" + code }
        else if exLower.contains("bj") || exchange == "9" { return "bj" + code }
        else { return "sz" + code }
    }
}

struct EastMoneyKLineResponse: Codable {
    let data: KLineDataContainer?
    struct KLineDataContainer: Codable {
        let klines: [String]?
    }
}
