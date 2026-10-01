import SwiftUI

struct StockDetailView: View {
    let stock: Stock
    @StateObject private var chatVM = ChatViewModel()
    @StateObject private var newsVM = NewsViewModel()
    @State private var klineData: [KLineData] = []
    @State private var selectedPeriod: StockService.KLinePeriod = .daily
    @State private var aiAnalysis: String = ""
    @State private var isAnalyzing = false
    @State private var showChat = false
    @State private var isLoadingKLine = true

    var upColor: Color { Color.red }
    var downColor: Color { Color(red: 0, green: 0.78, blue: 0.2) }
    var priceColor: Color { stock.changePercent >= 0 ? upColor : downColor }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Price Header
                    priceHeader
                        .padding()

                    Divider().background(Color.gray.opacity(0.2))

                    // MARK: Period Selector
                    periodSelector
                        .padding(.vertical, 8)
                        .padding(.horizontal)

                    // MARK: K-Line Chart
                    Group {
                        if isLoadingKLine {
                            ProgressView()
                                .tint(.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 260)
                        } else if klineData.isEmpty {
                            Text("暂无K线数据")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .frame(height: 260)
                        } else {
                            KLineChartView(data: klineData)
                                .frame(height: 350)
                                .padding(.horizontal, 4)
                        }
                    }

                    Divider().background(Color.gray.opacity(0.2))

                    // MARK: Data Grid
                    stockDataGrid
                        .padding()

                    Divider().background(Color.gray.opacity(0.2))

                    // MARK: AI Analysis
                    aiAnalysisSection
                        .padding()

                    Divider().background(Color.gray.opacity(0.2))

                    // MARK: News
                    VStack(alignment: .leading, spacing: 8) {
                        Text("相关资讯")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.top)

                        if newsVM.news.isEmpty && newsVM.isLoading {
                            ProgressView().tint(.red).padding()
                        } else {
                            ForEach(newsVM.news.prefix(6)) { item in
                                NewsRowView(item: item)
                                    .padding(.horizontal)
                                Divider().background(Color.gray.opacity(0.15)).padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle(stock.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showChat = true }) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            chatVM.contextStock = stock
            Task {
                await loadKLine()
                await newsVM.loadNews()
            }
        }
        .onChange(of: selectedPeriod) { _ in
            Task { await loadKLine() }
        }
        .sheet(isPresented: $showChat) {
            AIChatView()
                .environmentObject(chatVM)
                .environmentObject(newsVM)
        }
    }

    // MARK: - Subviews

    private var priceHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.2f", stock.currentPrice))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(priceColor)

                HStack(spacing: 8) {
                    Text(String(format: "%+.2f", stock.change))
                        .font(.subheadline)
                        .foregroundColor(priceColor)
                    Text(String(format: "%+.2f%%", stock.changePercent))
                        .font(.subheadline)
                        .foregroundColor(priceColor)
                }
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stock.exchange.rawValue)\(stock.id)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([
                    StockService.KLinePeriod.daily,
                    .weekly,
                    .monthly,
                    .minute60,
                    .minute30,
                    .minute15,
                    .minute5
                ], id: \.rawValue) { period in
                    Button(period.label) {
                        selectedPeriod = period
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(selectedPeriod == period ? Color.red : Color(white: 0.15))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
        }
    }

    private var stockDataGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
            DataCell(label: "今开", value: String(format: "%.2f", stock.open))
            DataCell(label: "最高", value: String(format: "%.2f", stock.high), color: upColor)
            DataCell(label: "最低", value: String(format: "%.2f", stock.low), color: downColor)
            DataCell(label: "成交量", value: formatVol(stock.volume))
            DataCell(label: "成交额", value: formatAmt(stock.turnover))
            DataCell(label: "涨跌幅", value: String(format: "%+.2f%%", stock.changePercent), color: priceColor)
        }
    }

    private var aiAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AI智能分析", systemImage: "brain.head.profile")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { Task { await runAnalysis() } }) {
                    HStack(spacing: 4) {
                        if isAnalyzing {
                            ProgressView().scaleEffect(0.7).tint(.white)
                        }
                        Text(isAnalyzing ? "分析中..." : "立即分析")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isAnalyzing ? Color.gray : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isAnalyzing)
            }

            if !aiAnalysis.isEmpty {
                Text(aiAnalysis)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(5)
                    .padding(12)
                    .background(Color(white: 0.1))
                    .cornerRadius(10)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Actions

    private func loadKLine() async {
        isLoadingKLine = true
        do {
            klineData = try await StockService.shared.fetchKLine(code: stock.fullCode, period: selectedPeriod)
        } catch {
            print("KLine error: \(error)")
            klineData = []
        }
        isLoadingKLine = false
    }

    private func runAnalysis() async {
        isAnalyzing = true
        do {
            let recentNews = Array(newsVM.news.prefix(5))
            aiAnalysis = try await DeepSeekService.shared.analyzeStock(stock, news: recentNews)
        } catch let err as DeepSeekService.DeepSeekError {
            aiAnalysis = "⚠️ \(err.errorDescription ?? "分析失败")"
        } catch {
            aiAnalysis = "⚠️ 分析失败，请检查网络连接"
        }
        isAnalyzing = false
    }

    // MARK: - Helpers

    private func formatVol(_ v: Double) -> String {
        let lots = v / 100
        if lots >= 10_000 { return String(format: "%.1f万手", lots / 10_000) }
        return String(format: "%.0f手", lots)
    }

    private func formatAmt(_ v: Double) -> String {
        if v >= 100_000_000 { return String(format: "%.2f亿", v / 100_000_000) }
        if v >= 10_000 { return String(format: "%.2f万", v / 10_000) }
        return String(format: "%.0f元", v)
    }
}

// MARK: - Data Cell
struct DataCell: View {
    let label: String
    let value: String
    var color: Color = .white

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(white: 0.1))
        .cornerRadius(8)
    }
}
