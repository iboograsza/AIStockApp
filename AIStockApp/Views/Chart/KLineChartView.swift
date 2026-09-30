import SwiftUI

struct KLineChartView: View {
    let data: [KLineData]

    // Show last 60 candles
    private var displayData: [KLineData] {
        Array(data.suffix(60))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Candlestick
            CandlestickView(data: displayData)
                .frame(height: 180)

            // Volume bars
            VolumeBarView(data: displayData)
                .frame(height: 50)

            // Date labels
            if let first = displayData.first, let last = displayData.last {
                HStack {
                    Text(dateLabel(first.date))
                    Spacer()
                    Text(dateLabel(last.date))
                }
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.6))
                .padding(.horizontal, 4)
            }
        }
        .background(Color.black)
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f.string(from: date)
    }
}

// MARK: - Candlestick Canvas
struct CandlestickView: View {
    let data: [KLineData]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = data.count
            guard count > 0 else { return AnyView(EmptyView()) }

            let minP = (data.map { $0.low }.min() ?? 0) * 0.999
            let maxP = (data.map { $0.high }.max() ?? 1) * 1.001
            let priceRange = maxP - minP
            let slotW = w / CGFloat(count)
            let barW = max(1.5, slotW * 0.65)

            func yPos(_ price: Double) -> CGFloat {
                h - CGFloat((price - minP) / priceRange) * h
            }

            return AnyView(
                Canvas { ctx, _ in
                    // Draw price grid lines
                    for i in 1...3 {
                        let y = h * CGFloat(i) / 4
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                        ctx.stroke(path, with: .color(.gray.opacity(0.15)), lineWidth: 0.5)
                    }

                    // Draw candles
                    for (i, candle) in data.enumerated() {
                        let cx = slotW * CGFloat(i) + slotW / 2
                        let color: Color = candle.isGreen ? .red : Color(red: 0, green: 0.78, blue: 0.2)

                        // Wick
                        var wick = Path()
                        wick.move(to: CGPoint(x: cx, y: yPos(candle.high)))
                        wick.addLine(to: CGPoint(x: cx, y: yPos(candle.low)))
                        ctx.stroke(wick, with: .color(color), lineWidth: 0.8)

                        // Body
                        let bodyTop = yPos(max(candle.open, candle.close))
                        let bodyBot = yPos(min(candle.open, candle.close))
                        let bodyH = max(1.5, bodyBot - bodyTop)
                        let bodyRect = CGRect(x: cx - barW / 2, y: bodyTop, width: barW, height: bodyH)

                        if candle.open == candle.close {
                            // Doji: just wick
                        } else {
                            ctx.fill(Path(bodyRect), with: .color(color))
                        }
                    }
                }
            )
        }
    }
}

// MARK: - Volume Bars
struct VolumeBarView: View {
    let data: [KLineData]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = data.count
            guard count > 0 else { return AnyView(EmptyView()) }

            let maxVol = data.map { $0.volume }.max() ?? 1
            let slotW = w / CGFloat(count)
            let barW = max(1.5, slotW * 0.65)

            return AnyView(
                Canvas { ctx, _ in
                    for (i, candle) in data.enumerated() {
                        let cx = slotW * CGFloat(i) + slotW / 2
                        let barH = CGFloat(candle.volume / maxVol) * h
                        let color: Color = candle.isGreen
                            ? Color.red.opacity(0.65)
                            : Color(red: 0, green: 0.78, blue: 0.2, opacity: 0.65)
                        let rect = CGRect(x: cx - barW / 2, y: h - barH, width: barW, height: barH)
                        ctx.fill(Path(rect), with: .color(color))
                    }
                }
            )
        }
    }
}
