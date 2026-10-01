import SwiftUI

enum MainIndicatorType: String, CaseIterable {
    case ma = "MA均线"
    case boll = "BOLL布林"
}

enum SubIndicatorType: String, CaseIterable {
    case volume = "成交量"
    case macd = "MACD"
    case kdj = "KDJ"
}

struct KLineChartView: View {
    let data: [KLineData]
    
    @State private var mainIndicator: MainIndicatorType = .ma
    @State private var subIndicator: SubIndicatorType = .volume
    @State private var dragOffset: CGFloat = 0
    @State private var accumulatedOffset: CGFloat = 0
    @State private var selectedIndex: Int? = nil
    
    private let candleCount: Int = 45
    
    // Calculate visible range based on pan/drag offset
    private var visibleData: [KLineData] {
        guard !data.isEmpty else { return [] }
        let totalCount = data.count
        if totalCount <= candleCount { return data }
        
        let candleWidth: CGFloat = 7.5
        let shiftCandles = Int((accumulatedOffset + dragOffset) / candleWidth)
        let endIndex = max(candleCount, min(totalCount, totalCount + shiftCandles))
        let startIndex = max(0, endIndex - candleCount)
        
        return Array(data[startIndex..<endIndex])
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // MARK: 1. Main Indicator Selector Bar (Tonghuashun Style)
            HStack(spacing: 8) {
                Text("主图:")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                ForEach(MainIndicatorType.allCases, id: \.self) { type in
                    Button(action: { mainIndicator = type }) {
                        Text(type.rawValue)
                            .font(.system(size: 11, weight: mainIndicator == type ? .bold : .regular))
                            .foregroundColor(mainIndicator == type ? .white : .gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(mainIndicator == type ? Color.red.opacity(0.8) : Color(white: 0.12))
                            .cornerRadius(4)
                    }
                }
                Spacer()
                Text("左右拖拽查看历史")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.horizontal, 4)

            // MARK: 2. Real-time Inspector / Indicator Values Header
            if let idx = selectedIndex, idx < visibleData.count {
                let c = visibleData[idx]
                HStack(spacing: 6) {
                    Text(dateLabel(c.date, format: "MM/dd"))
                        .foregroundColor(.gray)
                    Text("开:\(String(format: "%.2f", c.open))")
                        .foregroundColor(.white)
                    Text("高:\(String(format: "%.2f", c.high))")
                        .foregroundColor(.red)
                    Text("低:\(String(format: "%.2f", c.low))")
                        .foregroundColor(Color(red: 0, green: 0.78, blue: 0.2))
                    Text("收:\(String(format: "%.2f", c.close))")
                        .foregroundColor(c.isGreen ? .red : Color(red: 0, green: 0.78, blue: 0.2))
                }
                .font(.system(size: 10, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            } else if let last = visibleData.last {
                HStack(spacing: 8) {
                    if mainIndicator == .ma {
                        if let ma5 = last.ma5 { Text("MA5:\(String(format: "%.2f", ma5))").foregroundColor(.yellow) }
                        if let ma10 = last.ma10 { Text("MA10:\(String(format: "%.2f", ma10))").foregroundColor(.cyan) }
                        if let ma20 = last.ma20 { Text("MA20:\(String(format: "%.2f", ma20))").foregroundColor(.purple) }
                    } else {
                        if let mid = last.bollMid { Text("MID:\(String(format: "%.2f", mid))").foregroundColor(.yellow) }
                        if let up = last.bollUp { Text("UP:\(String(format: "%.2f", up))").foregroundColor(.cyan) }
                        if let down = last.bollDown { Text("DN:\(String(format: "%.2f", down))").foregroundColor(.purple) }
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }

            // MARK: 3. Main K-Line Candlestick View (Height 210)
            InteractiveCandlestickView(
                data: visibleData,
                mainIndicator: mainIndicator,
                selectedIndex: $selectedIndex
            )
            .frame(height: 210)
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

            // MARK: 4. Sub-indicator Selector Bar (Tonghuashun Style: VOL, MACD, KDJ)
            HStack(spacing: 8) {
                Text("副图:")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                ForEach(SubIndicatorType.allCases, id: \.self) { type in
                    Button(action: { subIndicator = type }) {
                        Text(type.rawValue)
                            .font(.system(size: 11, weight: subIndicator == type ? .bold : .regular))
                            .foregroundColor(subIndicator == type ? .white : .gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(subIndicator == type ? Color.red.opacity(0.8) : Color(white: 0.12))
                            .cornerRadius(4)
                    }
                }
                Spacer()
                // Current sub-indicator value readout
                if let last = visibleData.last {
                    if subIndicator == .macd, let dif = last.dif, let dea = last.dea, let macd = last.macd {
                        Text("DIF:\(String(format: "%.2f", dif)) DEA:\(String(format: "%.2f", dea)) MACD:\(String(format: "%.2f", macd))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                    } else if subIndicator == .kdj, let k = last.k, let d = last.d, let j = last.j {
                        Text("K:\(String(format: "%.1f", k)) D:\(String(format: "%.1f", d)) J:\(String(format: "%.1f", j))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            // MARK: 5. Sub-indicator Graph (Volume / MACD / KDJ)
            Group {
                switch subIndicator {
                case .volume:
                    VolumeBarView(data: visibleData)
                case .macd:
                    MACDChartView(data: visibleData)
                case .kdj:
                    KDJChartView(data: visibleData)
                }
            }
            .frame(height: 75)

            // MARK: 6. Date Range Axis
            if let first = visibleData.first, let last = visibleData.last {
                HStack {
                    Text(dateLabel(first.date, format: "yyyy-MM-dd"))
                    Spacer()
                    Text(dateLabel(last.date, format: "yyyy-MM-dd"))
                }
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.6))
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 4)
        .background(Color(white: 0.04))
        .cornerRadius(8)
    }

    private func dateLabel(_ date: Date, format: String) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: date)
    }
}

// MARK: - Interactive Candlestick + MA/BOLL View
struct InteractiveCandlestickView: View {
    let data: [KLineData]
    let mainIndicator: MainIndicatorType
    @Binding var selectedIndex: Int?

    private func calcYPos(price: Double, minP: Double, range: Double, h: CGFloat) -> CGFloat {
        h - CGFloat((price - minP) / range) * h
    }

    private func drawLine(ctx: GraphicsContext, data: [KLineData], keyPath: KeyPath<KLineData, Double?>, minP: Double, range: Double, h: CGFloat, slotW: CGFloat, color: Color) {
        var path = Path()
        var started = false
        for (i, c) in data.enumerated() {
            if let val = c[keyPath: keyPath] {
                let y = calcYPos(price: val, minP: minP, range: range, h: h)
                let pt = CGPoint(x: slotW * CGFloat(i) + slotW / 2, y: y)
                if !started {
                    path.move(to: pt)
                    started = true
                } else {
                    path.addLine(to: pt)
                }
            }
        }
        if started {
            ctx.stroke(path, with: .color(color), lineWidth: 1.2)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = data.count

            if count > 0 {
                let bollPrices: [Double] = mainIndicator == .boll ? (data.compactMap { $0.bollUp } + data.compactMap { $0.bollDown }) : []
                let allPrices = data.map { $0.low } + data.map { $0.high } + bollPrices
                let minP = (allPrices.min() ?? 0) * 0.998
                let maxP = (allPrices.max() ?? 1) * 1.002
                let priceRange = max(maxP - minP, 0.001)
                let slotW = w / CGFloat(count)
                let barW = max(2.0, slotW * 0.72)

                ZStack {
                    Canvas { ctx, _ in
                        // Background price grid lines & price labels
                        for i in 1...3 {
                            let y = h * CGFloat(i) / 4.0
                            let priceAtGrid = maxP - (Double(i) / 4.0) * priceRange
                            var line = Path()
                            line.move(to: CGPoint(x: 0, y: y))
                            line.addLine(to: CGPoint(x: w, y: y))
                            ctx.stroke(line, with: .color(Color(white: 0.12)), lineWidth: 0.5)

                            let text = Text(String(format: "%.2f", priceAtGrid))
                                .font(.system(size: 8))
                                .foregroundColor(.gray.opacity(0.5))
                            ctx.draw(text, at: CGPoint(x: 20, y: y - 6))
                        }

                        // Candles (Tonghuashun Red = Up, Green = Down)
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

                        // Main indicator curves
                        if mainIndicator == .ma {
                            drawLine(ctx: ctx, data: data, keyPath: \.ma5, minP: minP, range: priceRange, h: h, slotW: slotW, color: .yellow)
                            drawLine(ctx: ctx, data: data, keyPath: \.ma10, minP: minP, range: priceRange, h: h, slotW: slotW, color: .cyan)
                            drawLine(ctx: ctx, data: data, keyPath: \.ma20, minP: minP, range: priceRange, h: h, slotW: slotW, color: .purple)
                        } else {
                            drawLine(ctx: ctx, data: data, keyPath: \.bollMid, minP: minP, range: priceRange, h: h, slotW: slotW, color: .yellow)
                            drawLine(ctx: ctx, data: data, keyPath: \.bollUp, minP: minP, range: priceRange, h: h, slotW: slotW, color: .cyan)
                            drawLine(ctx: ctx, data: data, keyPath: \.bollDown, minP: minP, range: priceRange, h: h, slotW: slotW, color: .purple)
                        }

                        // Crosshair highlight
                        if let sel = selectedIndex, sel < count {
                            let cx = slotW * CGFloat(sel) + slotW / 2
                            let cy = calcYPos(price: data[sel].close, minP: minP, range: priceRange, h: h)
                            var vLine = Path()
                            vLine.move(to: CGPoint(x: cx, y: 0))
                            vLine.addLine(to: CGPoint(x: cx, y: h))
                            ctx.stroke(vLine, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))

                            var hLine = Path()
                            hLine.move(to: CGPoint(x: 0, y: cy))
                            hLine.addLine(to: CGPoint(x: w, y: cy))
                            ctx.stroke(hLine, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
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

// MARK: - KDJ Chart View (Tonghuashun Style)
struct KDJChartView: View {
    let data: [KLineData]

    private func calcKdjY(val: Double, h: CGFloat) -> CGFloat {
        h - CGFloat(max(0, min(100, val)) / 100.0) * h
    }

    private func drawKdjCurve(ctx: GraphicsContext, data: [KLineData], keyPath: KeyPath<KLineData, Double?>, h: CGFloat, slotW: CGFloat, color: Color) {
        var path = Path()
        var started = false
        for (i, item) in data.enumerated() {
            if let val = item[keyPath: keyPath] {
                let pt = CGPoint(x: slotW * CGFloat(i) + slotW / 2, y: calcKdjY(val: val, h: h))
                if !started { path.move(to: pt); started = true }
                else { path.addLine(to: pt) }
            }
        }
        if started {
            ctx.stroke(path, with: .color(color), lineWidth: 1.0)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = data.count

            if count > 0 {
                let slotW = w / CGFloat(count)

                Canvas { ctx, _ in
                    // 20, 50, 80 reference lines
                    for level in [20.0, 50.0, 80.0] {
                        let y = calcKdjY(val: level, h: h)
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: y))
                        line.addLine(to: CGPoint(x: w, y: y))
                        ctx.stroke(line, with: .color(Color(white: 0.15)), lineWidth: 0.5)
                    }

                    // K (White), D (Yellow), J (Purple)
                    drawKdjCurve(ctx: ctx, data: data, keyPath: \.k, h: h, slotW: slotW, color: .white)
                    drawKdjCurve(ctx: ctx, data: data, keyPath: \.d, h: h, slotW: slotW, color: .yellow)
                    drawKdjCurve(ctx: ctx, data: data, keyPath: \.j, h: h, slotW: slotW, color: .purple)
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
                let barW = max(2.0, slotW * 0.72)

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
