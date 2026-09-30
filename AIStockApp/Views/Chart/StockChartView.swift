import SwiftUI

/// A simple sparkline chart showing recent price movement
struct StockChartView: View {
    let data: [KLineData]
    let isPositive: Bool

    private var prices: [Double] {
        data.suffix(30).map { $0.close }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let count = prices.count

            guard count > 1 else {
                return AnyView(EmptyView())
            }

            let minPrice = prices.min() ?? 0
            let maxPrice = prices.max() ?? 1
            let priceRange = maxPrice - minPrice > 0 ? maxPrice - minPrice : 1

            func xPos(_ index: Int) -> CGFloat {
                CGFloat(index) / CGFloat(count - 1) * width
            }

            func yPos(_ price: Double) -> CGFloat {
                height - CGFloat((price - minPrice) / priceRange) * height
            }

            return AnyView(
                Canvas { context, _ in
                    // Draw line path
                    var path = Path()
                    path.move(to: CGPoint(x: xPos(0), y: yPos(prices[0])))
                    for i in 1..<count {
                        path.addLine(to: CGPoint(x: xPos(i), y: yPos(prices[i])))
                    }

                    let lineColor: Color = isPositive ? .red : Color(red: 0, green: 0.78, blue: 0.2)
                    context.stroke(path, with: .color(lineColor), lineWidth: 1.5)

                    // Draw fill area
                    var fillPath = path
                    fillPath.addLine(to: CGPoint(x: xPos(count - 1), y: height))
                    fillPath.addLine(to: CGPoint(x: xPos(0), y: height))
                    fillPath.closeSubpath()
                    context.fill(fillPath, with: .color(lineColor.opacity(0.15)))
                }
            )
        }
    }
}
