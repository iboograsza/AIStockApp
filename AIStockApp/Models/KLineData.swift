import Foundation

struct KLineData: Identifiable {
    let id = UUID()
    let date: Date
    let open: Double
    let close: Double
    let high: Double
    let low: Double
    let volume: Double

    var isGreen: Bool { close >= open }
    var bodyHigh: Double { max(open, close) }
    var bodyLow: Double { min(open, close) }
}
