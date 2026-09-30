import SwiftUI

struct StockRowView: View {
    let stock: Stock

    var upColor: Color { Color.red }
    var downColor: Color { Color(red: 0, green: 0.78, blue: 0.2) }
    var flatColor: Color { Color.gray }

    var priceColor: Color {
        if stock.changePercent > 0 { return upColor }
        if stock.changePercent < 0 { return downColor }
        return flatColor
    }

    var body: some View {
        HStack(spacing: 8) {
            // Stock name & code
            VStack(alignment: .leading, spacing: 3) {
                Text(stock.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(stock.exchange.rawValue) \(stock.id)")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .frame(minWidth: 80, alignment: .leading)

            Spacer()

            // Volume & Turnover
            VStack(alignment: .trailing, spacing: 3) {
                Text(formatVolume(stock.volume))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Text(formatTurnover(stock.turnover))
                    .font(.system(size: 11))
                    .foregroundColor(Color.gray.opacity(0.7))
            }

            // Price change pill
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.2f", stock.currentPrice))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(priceColor)

                Text(String(format: "%+.2f%%", stock.changePercent))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(priceColor)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 5)
    }

    private func formatVolume(_ v: Double) -> String {
        let lots = v / 100 // convert shares to lots (手)
        if lots >= 100_000_000 { return String(format: "%.1f亿手", lots / 100_000_000) }
        if lots >= 10_000 { return String(format: "%.1f万手", lots / 10_000) }
        return String(format: "%.0f手", lots)
    }

    private func formatTurnover(_ t: Double) -> String {
        if t >= 100_000_000 { return String(format: "%.2f亿", t / 100_000_000) }
        if t >= 10_000 { return String(format: "%.2f万", t / 10_000) }
        return String(format: "%.0f元", t)
    }
}
