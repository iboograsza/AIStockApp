import SwiftUI

enum SubIndicatorType: String, CaseIterable {
    case volume = "成交量"
    case macd = "MACD"
}

struct KLineChartView: View {
    let data: [KLineData]
    
    @State private var subIndicator: SubIndicatorType = .volume
    @State private var dragOffset: CGFloat = 0
    @State private var accumulatedOffset: CGFloat = 0
    @State private var selectedIndex: Int? = nil
    
    private let candleCount: Int = 50
    
    // Calculate visible range based on pan/drag offset
    private var visibleData: [KLineData] {
        guard !data.isEmpty else { return [] }
        let totalCount = data.count
        if totalCount <= candleCount { return data }
        
        let candleWidth: CGFloat = 7.0
        let shiftCandles = Int((accumulatedOffset + dragOffset) / candleWidth)
        let endIndex = max(candleCount, min(totalCount, totalCount + shiftCandles))
        let startIndex = max(0, endIndex - candleCount)
        
        return Array(data[startIndex..<endIndex])
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Selected Candle Info Bar (Crosshair inspector)
            if let idx = selectedIndex, idx < visibleData.count {
                let candle = visibleData[idx]
                HStack(spacing: 8) {
                    Text(dateLabel(candle.date, format: "yyyy/MM/dd"))
                        .foregroundColor(.gray)
                    Text("开:\(String(format: "%.2f", candle.open))")
                        .foregroundColor(.white)
                    Text("高:\(String(format: "%.2f", candle.high))")
                        .foregroundColor(.red)
                    Text("低:\(String(format: "%.2f", candle.low))")
                        .foregroundColor(Color(red: 0, green: 0.78, blue: 0.2))
                    Text("收:\(String(format: "%.2f", candle.close))")
                        .foregroundColor(candle.isGreen ? .red : Color(red: 0, green: 0.78, blue: 0.2))
                }
                .font(.system(size: 10, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            } else if let last = visibleData.last {
                // Moving average values header
                HStack(spacing: 10) {
                    if let ma5 = last.ma5 {
                        Text("MA5:\(String(format: "%.2f", ma5))").foregroundColor(.yellow)
                    }
                    if let ma10 = last.ma10 {
                        Text("MA10:\(String(format: "%.2f", ma10))").foregroundColor(.cyan)
                    }
                    if let ma20 = last.ma20 {
                        Text("MA20:\(String(format: "%.2f", ma20))").foregroundColor(.purple)
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }

            // Main K-Line Candlestick & MA Lines
            InteractiveCandlestickView(
                data: visibleData,
                selectedIndex: $selectedIndex
            )
            .frame(height: 200)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        accumulatedOffset += value.translation.width
                        dragOffset = 0
                    }
            )

            // Sub-indicator Selector (Volume / MACD)
            HStack(spacing: 12) {
                ForEach(SubIndicatorType.allCases, id: \.self) { type in
                    Button(action: { subIndicator = type }) {
                        Text(type.rawValue)
                            .font(.system(size: 10, weight: subIndicator == type ? .bold : .regular))
                            .foregroundColor(subIndicator == type ? .red : .gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(subIndicator == type ? Color(white: 0.18) : Color.clear)
                            .cornerRadius(4)
                    }
                }
                Spacer()
                if subIndicator == .macd, let last = visibleData.last,
                   let dif = last.dif, let dea = last.dea, let macd = last.macd {
                    Text("DIF:\(String(format: "%.2f", dif)) DEA:\(String(format: "%.2f", dea)) MACD:\(String(format: "%.2f", macd))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 4)

            // Sub-chart View (Volume / MACD)
            Group {
                if subIndicator == .volume {
                    VolumeBarView(data: visibleData)
                } else {
                    MACDChartView(data: visibleData)
                }
            }
            .frame(height: 65)

            // Date Range Bar
            if let first = visibleData.first, let last = visibleData.last {
                HStack {
                    Text(dateLabel(first.date, format: "MM-dd"))
                    Spacer()
                    Text("滑动可查看历史行情")
                        .foregroundColor(.gray.opacity(0.4))
                    Spacer()
                    Text(dateLabel(last.date, format: "MM-dd"))
                }
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.6))
                .padding(.horizontal, 4)
            }
        }
        .background(Color.black)
    }

    private func dateLabel(_ date: Date, format: String) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: date)
    }
}

// MARK: - Interactive Candlestick + MA Lines View
struct InteractiveCandlestickView: View {
    let data: [KLineData]
    @Binding var selectedIndex: Int?

    private func calcYPos(price: Double, minP: Double, range: Double, h: CGFloat) -> CGFloat {
        h - CGFloat((price - minP) / range) * h
    }

    private func drawMALine(ctx: GraphicsContext, data: [KLineData], keyPath: KeyPath<KLineData, Double?>, minP: Double, range: Double, h: CGFloat, slotW: CGFloat, color: Color) {
        var maPath = Path()
        var started = false
        for (i, c) in data.enumerated() {
            if let val = c[keyPath: keyPath] {
                let y = calcYPos(price: val, minP: minP, range: range, h: h)
                let pt = CGPoint(x: slotW * CGFloat(i) + slotW / 2, y: y)
                if !started {
                    maPath.move(to: pt)
                    started = true
                } else {
                    maPath.addLine(to: pt)
                }
            }
        }
        if started {
            ctx.stroke(maPath, with: .color(color), lineWidth: 1.2)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = data.count

            if count > 0 {
                let minP = (data.map { $0.low }.min() ?? 0) * 0.998
                let maxP = (data.map { $0.high }.max() ?? 1) * 1.002
                let priceRange = max(maxP - minP, 0.001)
                let slotW = w / CGFloat(count)
                let barW = max(2.0, slotW * 0.7)

                ZStack {
                    Canvas { ctx, _ in
                        // Background Grid
                        for i in 1...3 {
                            let y = h * CGFloat(i) / 4.0
                            var line = Path()
                            line.move(to: CGPoint(x: 0, y: y))
                            line.addLine(to: CGPoint(x: w, y: y))
                            ctx.stroke(line, with: .color(Color(white: 0.12)), lineWidth: 0.5)
                        }

                        // Candles
                        for (i, candle) in data.enumerated() {
                            let cx = slotW * CGFloat(i) + slotW / 2
                            let color: Color = candle.isGreen ? .red : Color(red: 0, green: 0.78, blue: 0.2)

                            // High-Low Wick
                            let yH = calcYPos(price: candle.high, minP: minP, range: priceRange, h: h)
                            let yL = calcYPos(price: candle.low, minP: minP, range: priceRange, h: h)
                            var wick = Path()
                            wick.move(to: CGPoint(x: cx, y: yH))
                            wick.addLine(to: CGPoint(x: cx, y: yL))
                            ctx.stroke(wick, with: .color(color), lineWidth: 1.0)

                            // Open-Close Body
                            let top = calcYPos(price: max(candle.open, candle.close), minP: minP, range: priceRange, h: h)
                            let bot = calcYPos(price: min(candle.open, candle.close), minP: minP, range: priceRange, h: h)
                            let bodyH = max(2.0, bot - top)
                            let rect = CGRect(x: cx - barW / 2, y: top, width: barW, height: bodyH)
                            ctx.fill(Path(rect), with: .color(color))
                        }

                        // Draw MA lines
                        drawMALine(ctx: ctx, data: data, keyPath: \.ma5, minP: minP, range: priceRange, h: h, slotW: slotW, color: .yellow)
                        drawMALine(ctx: ctx, data: data, keyPath: \.ma10, minP: minP, range: priceRange, h: h, slotW: slotW, color: .cyan)
                        drawMALine(ctx: ctx, data: data, keyPath: \.ma20, minP: minP, range: priceRange, h: h, slotW: slotW, color: .purple)

                        // Crosshair highlight
                        if let sel = selectedIndex, sel < count {
                            let cx = slotW * CGFloat(sel) + slotW / 2
                            let cy = calcYPos(price: data[sel].close, minP: minP, range: priceRange, h: h)
                            var vLine = Path()
                            vLine.move(to: CGPoint(x: cx, y: 0))
                            vLine.addLine(to: CGPoint(x: cx, y: h))
                            ctx.stroke(vLine, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))

                            var hLine = Path()
                            hLine.move(to: CGPoint(x: 0, y: cy))
                            hLine.addLine(to: CGPoint(x: w, y: cy))
                            ctx.stroke(hLine, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                        }
                    }

                    // Touch inspection detector
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { val in
                                    let idx = Int(val.location.x / slotW)
                                    if idx >= 0 && idx < count {
                                        selectedIndex = idx
                                    }
                                }
                                .onEnded { _ in
                                    selectedIndex = nil
                                }
                        )
                }
            }
        }
    }
}

// MARK: - MACD Chart View
struct MACDChartView: View {
    let data: [KLineData]

    private func calcMacdYPos(val: Double, maxVal: Double, h: CGFloat) -> CGFloat {
        h / 2.0 - CGFloat(val / maxVal) * (h / 2.0)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = data.count

            if count > 0 {
                let slotW = w / CGFloat(count)
                let barW = max(1.5, slotW * 0.6)

                let allDifs = data.compactMap { $0.dif }
                let allDeas = data.compactMap { $0.dea }
                let allMacds = data.compactMap { $0.macd }
                let allVals = allDifs + allDeas + allMacds
                let maxVal = max(abs(allVals.max() ?? 1), abs(allVals.min() ?? -1), 0.001)

                Canvas { ctx, _ in
                    // Zero line
                    var zeroLine = Path()
                    zeroLine.move(to: CGPoint(x: 0, y: h / 2.0))
                    zeroLine.addLine(to: CGPoint(x: w, y: h / 2.0))
                    ctx.stroke(zeroLine, with: .color(Color(white: 0.2)), lineWidth: 0.5)

                    // MACD Bars
                    for (i, item) in data.enumerated() {
                        if let macd = item.macd {
                            let cx = slotW * CGFloat(i) + slotW / 2
                            let yTop = min(calcMacdYPos(val: macd, maxVal: maxVal, h: h), h / 2.0)
                            let yBot = max(calcMacdYPos(val: macd, maxVal: maxVal, h: h), h / 2.0)
                            let barH = max(1.0, yBot - yTop)
                            let color: Color = macd >= 0 ? .red : Color(red: 0, green: 0.78, blue: 0.2)
                            let rect = CGRect(x: cx - barW / 2, y: yTop, width: barW, height: barH)
                            ctx.fill(Path(rect), with: .color(color))
                        }
                    }

                    // DIF Line (White)
                    var difPath = Path()
                    var difStarted = false
                    for (i, item) in data.enumerated() {
                        if let dif = item.dif {
                            let pt = CGPoint(x: slotW * CGFloat(i) + slotW / 2, y: calcMacdYPos(val: dif, maxVal: maxVal, h: h))
                            if !difStarted { difPath.move(to: pt); difStarted = true }
                            else { difPath.addLine(to: pt) }
                        }
                    }
                    ctx.stroke(difPath, with: .color(.white), lineWidth: 1.0)

                    // DEA Line (Yellow)
                    var deaPath = Path()
                    var deaStarted = false
                    for (i, item) in data.enumerated() {
                        if let dea = item.dea {
                            let pt = CGPoint(x: slotW * CGFloat(i) + slotW / 2, y: calcMacdYPos(val: dea, maxVal: maxVal, h: h))
                            if !deaStarted { deaPath.move(to: pt); deaStarted = true }
                            else { deaPath.addLine(to: pt) }
                        }
                    }
                    ctx.stroke(deaPath, with: .color(.yellow), lineWidth: 1.0)
                }
            }
        }
    }
}

// MARK: - Volume Bar View
struct VolumeBarView: View {
    let data: [KLineData]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = data.count

            if count > 0 {
                let maxVol = max(data.map { $0.volume }.max() ?? 1, 1)
                let slotW = w / CGFloat(count)
                let barW = max(2.0, slotW * 0.7)

                Canvas { ctx, _ in
                    for (i, candle) in data.enumerated() {
                        let cx = slotW * CGFloat(i) + slotW / 2
                        let barH = max(CGFloat(candle.volume / maxVol) * h, 1.0)
                        let color: Color = candle.isGreen
                            ? Color.red.opacity(0.85)
                            : Color(red: 0, green: 0.78, blue: 0.2, opacity: 0.85)
                        let rect = CGRect(x: cx - barW / 2, y: h - barH, width: barW, height: barH)
                        ctx.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
}
