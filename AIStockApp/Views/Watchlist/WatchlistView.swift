import SwiftUI

struct WatchlistView: View {
    @EnvironmentObject var viewModel: WatchlistViewModel
    @State private var showSearch = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Market index bar at top
                    if !viewModel.indices.isEmpty {
                        MarketIndexBar(stocks: viewModel.indices)
                    }

                    // Stock list
                    if viewModel.regularStocks.isEmpty && viewModel.isLoading {
                        Spacer()
                        ProgressView("加载中...")
                            .tint(.red)
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        List {
                            ForEach(viewModel.regularStocks) { stock in
                                NavigationLink(destination: StockDetailView(stock: stock)
                                    .navigationBarTitleDisplayMode(.inline)) {
                                    StockRowView(stock: stock)
                                }
                                .listRowBackground(Color(white: 0.08))
                                .listRowSeparatorTint(Color.gray.opacity(0.2))
                            }
                            .onDelete(perform: viewModel.removeStock)

                            if let time = viewModel.lastUpdated {
                                HStack {
                                    Spacer()
                                    Text("更新于 \(timeString(time))")
                                        .font(.caption2)
                                        .foregroundColor(.gray.opacity(0.5))
                                    Spacer()
                                }
                                .listRowBackground(Color.black)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.black)
                        .refreshable {
                            await viewModel.loadStocks()
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding()
                        Spacer()
                    }
                }
            }
            .navigationTitle("自选股")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.isMarketOpen ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                        Text(viewModel.marketStatusText)
                            .font(.caption)
                            .foregroundColor(viewModel.isMarketOpen ? .green : .gray)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSearch = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchStockView()
                    .environmentObject(viewModel)
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Market Index Bar
struct MarketIndexBar: View {
    let stocks: [Stock]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(stocks) { stock in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stock.name)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(String(format: "%.2f", stock.currentPrice))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text(String(format: "%+.2f%%", stock.changePercent))
                            .font(.system(size: 10))
                            .foregroundColor(stock.changePercent >= 0 ? .red : Color(red: 0, green: 0.78, blue: 0.2))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(white: 0.13))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(white: 0.06))
    }
}

// MARK: - Search Stock View
struct SearchStockView: View {
    @EnvironmentObject var viewModel: WatchlistViewModel
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss

    private let hotStocks = [
        SearchResult(name: "贵州茅台", code: "600519", exchange: "sh"),
        SearchResult(name: "宁德时代", code: "300750", exchange: "sz"),
        SearchResult(name: "比亚迪", code: "002594", exchange: "sz"),
        SearchResult(name: "中信证券", code: "600030", exchange: "sh"),
        SearchResult(name: "东方财富", code: "300059", exchange: "sz"),
        SearchResult(name: "中国平安", code: "601318", exchange: "sh")
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom search textfield
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("输入股票名称、拼音或代码 (如 茅台 / 600519)", text: $searchText)
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await viewModel.searchStock(keyword: searchText) }
                            }
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                viewModel.searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(white: 0.12))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if viewModel.isSearching {
                        ProgressView()
                            .tint(.red)
                            .padding()
                    }

                    if !viewModel.searchResults.isEmpty {
                        List(viewModel.searchResults) { result in
                            Button(action: {
                                viewModel.addStock(result)
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.name)
                                            .foregroundColor(.white)
                                            .font(.system(size: 15, weight: .medium))
                                        Text("\(result.fullCode.uppercased())")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title3)
                                }
                            }
                            .listRowBackground(Color(white: 0.1))
                            .listRowSeparatorTint(Color.gray.opacity(0.2))
                        }
                        .listStyle(.plain)
                    } else if !searchText.isEmpty && !viewModel.isSearching {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.6))
                            Text("未找到相关股票")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    } else {
                        // Hot recommendations
                        VStack(alignment: .leading, spacing: 12) {
                            Text("热门股票推荐")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.top, 12)

                            List(hotStocks) { result in
                                Button(action: {
                                    viewModel.addStock(result)
                                    dismiss()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.name)
                                                .foregroundColor(.white)
                                                .font(.system(size: 15, weight: .medium))
                                            Text("\(result.fullCode.uppercased())")
                                                .foregroundColor(.gray)
                                                .font(.caption)
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(.red)
                                    }
                                }
                                .listRowBackground(Color(white: 0.08))
                                .listRowSeparatorTint(Color.gray.opacity(0.2))
                            }
                            .listStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("添加自选股")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: searchText) { newValue in
                Task { await viewModel.searchStock(keyword: newValue) }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.red)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
