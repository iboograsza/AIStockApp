import Foundation
import SwiftUI
import Combine

@MainActor
class WatchlistViewModel: ObservableObject {
    @Published var stocks: [Stock] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var lastUpdated: Date?

    // Default watchlist: major indices + popular stocks
    private var watchlistCodes: [String] {
        get {
            let saved = UserDefaults.standard.stringArray(forKey: "watchlist_codes")
            return saved ?? [
                "sh000001",  // 上证指数
                "sh000300",  // 沪深300
                "sh000016",  // 上证50
                "sh000905",  // 中证500
                "sh600519",  // 贵州茅台
                "sz000858",  // 五粮液
                "sz300750",  // 宁德时代
                "sh601318",  // 中国平安
                "sz000002",  // 万科A
                "sh601166"   // 兴业银行
            ]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "watchlist_codes")
        }
    }

    var indices: [Stock] {
        stocks.filter { isIndexStock($0) }
    }

    var regularStocks: [Stock] {
        stocks.filter { !isIndexStock($0) }
    }

    private var refreshTimer: Timer?

    init() {
        Task { await loadStocks() }
        startAutoRefresh()
    }

    func loadStocks() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let codes = watchlistCodes
            let fetched = try await StockService.shared.fetchQuote(codes: codes)
            stocks = fetched
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addStock(_ result: SearchResult) {
        var codes = watchlistCodes
        let fullCode = result.fullCode
        guard !codes.contains(fullCode) else { return }
        codes.append(fullCode)
        watchlistCodes = codes
        Task { await loadStocks() }
    }

    func removeStock(at offsets: IndexSet) {
        var codes = watchlistCodes
        let toRemove = offsets.compactMap { index -> String? in
            guard index < regularStocks.count else { return nil }
            return regularStocks[index].fullCode
        }
        codes.removeAll { toRemove.contains($0) }
        watchlistCodes = codes
        stocks.removeAll { toRemove.contains($0.fullCode) }
    }

    func searchStock(keyword: String) async {
        guard !keyword.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        do {
            searchResults = try await StockService.shared.searchStock(keyword: keyword)
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    func startAutoRefresh() {
        refreshTimer?.invalidate()
        // Only refresh during trading hours
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.isMarketOpen {
                    await self.loadStocks()
                }
            }
        }
    }

    var isMarketOpen: Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let totalMinutes = hour * 60 + minute
        let isWeekday = weekday >= 2 && weekday <= 6 // Mon-Fri
        let isMorningSession = totalMinutes >= 9 * 60 + 30 && totalMinutes <= 11 * 60 + 30
        let isAfternoonSession = totalMinutes >= 13 * 60 && totalMinutes <= 15 * 60
        return isWeekday && (isMorningSession || isAfternoonSession)
    }

    var marketStatusText: String {
        isMarketOpen ? "交易中" : "已收盘"
    }

    private func isIndexStock(_ stock: Stock) -> Bool {
        stock.id.hasPrefix("0000") || stock.id.hasPrefix("0003") || stock.id.hasPrefix("3990")
    }

    deinit {
        refreshTimer?.invalidate()
    }
}
