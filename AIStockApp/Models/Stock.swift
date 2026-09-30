import Foundation

struct Stock: Identifiable, Codable {
    let id: String // stock code like "600519"
    let name: String
    var currentPrice: Double
    var change: Double // price change
    var changePercent: Double // percentage change
    var open: Double
    var high: Double
    var low: Double
    var volume: Double // in lots (手)
    var turnover: Double // in yuan
    var marketCap: Double?
    var pe: Double?
    var exchange: StockExchange // .sh or .sz
    var isFavorite: Bool = false

    enum StockExchange: String, Codable {
        case sh = "SH"
        case sz = "SZ"
        case bj = "BJ"
    }

    var fullCode: String {
        return exchange.rawValue.lowercased() + id
    }

    var isPositive: Bool { changePercent >= 0 }
}

struct StockQuote: Codable {
    let code: String
    let name: String
    let price: Double
    let open: Double
    let high: Double
    let low: Double
    let prevClose: Double
    let volume: Double
    let amount: Double
    let change: Double
    let changePercent: Double
}
