import Foundation

struct KLineData: Identifiable {
    let id = UUID()
    let date: Date
    let open: Double
    let close: Double
    let high: Double
    let low: Double
    let volume: Double
    
    // Moving Averages
    var ma5: Double?
    var ma10: Double?
    var ma20: Double?
    
    // MACD indicators
    var dif: Double?
    var dea: Double?
    var macd: Double?

    // KDJ indicators
    var k: Double?
    var d: Double?
    var j: Double?

    // BOLL indicators
    var bollMid: Double?
    var bollUp: Double?
    var bollDown: Double?

    var isGreen: Bool { close >= open }
    var bodyHigh: Double { max(open, close) }
    var bodyLow: Double { min(open, close) }
}

