import SwiftUI

struct AIChatView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @EnvironmentObject var newsVM: NewsViewModel
    @EnvironmentObject var watchlistVM: WatchlistViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    private let quickQuestions = [
        "🔥 请给我推荐3只近期值得布局的潜力金股！",
        "🚀 当前A股最有爆发力的是哪些板块龙头？",
        "📰 结合最新突发快讯，有哪些个股迎来重大利好？",
        "💡 给出中线稳健和短线爆发的选股策略与标的",
        "📊 如何看待当前整体市场情绪与主力资金走向？"
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Messages scroll area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message, watchlistVM: watchlistVM)
                                        .id(message.id)
                                }

                                if viewModel.isLoading {
                                    HStack(alignment: .bottom, spacing: 8) {
                                        Image(systemName: "brain.head.profile")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .padding(6)
                                            .background(Color(white: 0.18))
                                            .clipShape(Circle())
                                        TypingIndicator()
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .id("typing")
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            withAnimation(.easeOut(duration: 0.3)) {
                                if let last = viewModel.messages.last {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: viewModel.isLoading) { loading in
                            if loading {
                                withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                            }
                        }
                    }

                    // Error banner
                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                            Button(action: { viewModel.errorMessage = nil }) {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                    }

                    // Quick questions (only show on fresh start)
                    if viewModel.messages.count <= 1 && !isInputFocused {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(quickQuestions, id: \.self) { q in
                                    Button(q) {
                                        inputText = q
                                        sendMessage()
                                    }
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color(white: 0.14))
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                    )
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        .padding(.vertical, 6)
                        .background(Color(white: 0.06))
                    }

                    // Input bar
                    ChatInputBar(
                        text: $inputText,
                        isFocused: $isInputFocused,
                        isLoading: viewModel.isLoading,
                        onSend: sendMessage
                    )
                }
            }
            .navigationTitle("AI助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("实时资讯已接入(\(newsVM.news.count)条)")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.clearHistory() }) {
                        Image(systemName: "trash")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if newsVM.news.isEmpty {
                Task { await newsVM.loadNews() }
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false
        Task { await viewModel.sendMessage(text, newsContext: newsVM.news) }
    }
}

// MARK: - Stock Detection
struct DetectedStock: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let exchange: String // "sh" or "sz"

    var fullCode: String { exchange + code }
    var displayText: String { "\(name) \(code)" }

    var searchResult: SearchResult {
        SearchResult(name: name, code: code, exchange: exchange)
    }
}

/// Parses AI message text to find mentioned Chinese stocks
func detectStocks(in text: String) -> [DetectedStock] {
    // Match patterns like: 贵州茅台(600519) / 600519（贵州茅台）/ 【600519】 / 代码600519
    // We look for 6-digit codes and try to grab adjacent Chinese name
    var results: [DetectedStock] = []
    var seenCodes = Set<String>()

    // Known stock map (code → name, exchange)
    let knownStocks: [String: (String, String)] = [
        "600519": ("贵州茅台", "sh"), "000858": ("五粮液", "sz"), "300750": ("宁德时代", "sz"),
        "601318": ("中国平安", "sh"), "000002": ("万科A", "sz"), "600036": ("招商银行", "sh"),
        "601166": ("兴业银行", "sh"), "600276": ("恒瑞医药", "sh"), "000333": ("美的集团", "sz"),
        "002594": ("比亚迪", "sz"), "600900": ("长江电力", "sh"), "601398": ("工商银行", "sh"),
        "601939": ("建设银行", "sh"), "601988": ("中国银行", "sh"), "600028": ("中国石化", "sh"),
        "601857": ("中国石油", "sh"), "600048": ("保利发展", "sh"), "601601": ("中国太保", "sh"),
        "601628": ("中国人寿", "sh"), "600887": ("伊利股份", "sh"), "000651": ("格力电器", "sz"),
        "002415": ("海康威视", "sz"), "300059": ("东方财富", "sz"), "000播": ("平安银行", "sz"),
        "000001": ("平安银行", "sz"), "600000": ("浦发银行", "sh"), "601988": ("中国银行", "sh"),
        "002714": ("牧原股份", "sz"), "600346": ("恒力石化", "sh"), "601012": ("隆基绿能", "sh"),
        "600测": ("中芯国际", "sh"), "688981": ("中芯国际", "sh"), "600009": ("上海机场", "sh"),
        "601111": ("中国国航", "sh"), "600104": ("上汽集团", "sh"), "002027": ("分众传媒", "sz"),
        "300122": ("智飞生物", "sz"), "600309": ("万华化学", "sh"), "601888": ("中国中免", "sh")
    ]

    // Regex: find 6-digit sequences starting with 0,3,6
    let pattern = "\\b([036]\\d{5})\\b"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let nsText = text as NSString
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

    for match in matches {
        let code = nsText.substring(with: match.range(at: 1))
        guard !seenCodes.contains(code) else { continue }
        seenCodes.insert(code)

        if let (name, exchange) = knownStocks[code] {
            results.append(DetectedStock(code: code, name: name, exchange: exchange))
        } else {
            // Unknown code — still show with generic name
            let exchange = code.hasPrefix("6") ? "sh" : "sz"
            results.append(DetectedStock(code: code, name: code, exchange: exchange))
        }
    }

    // Also parse "name(code)" patterns for named but unlisted stocks
    let namedPattern = "([\\u4e00-\\u9fa5A-Za-z]{2,8})[（(]([036]\\d{5})[）)]"
    if let namedRegex = try? NSRegularExpression(pattern: namedPattern) {
        let namedMatches = namedRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in namedMatches where match.numberOfRanges >= 3 {
            let name = nsText.substring(with: match.range(at: 1))
            let code = nsText.substring(with: match.range(at: 2))
            guard !seenCodes.contains(code) else { continue }
            seenCodes.insert(code)
            let exchange = code.hasPrefix("6") ? "sh" : "sz"
            results.append(DetectedStock(code: code, name: name, exchange: exchange))
        }
    }

    return results
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    @ObservedObject var watchlistVM: WatchlistViewModel
    @State private var addedCodes = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                if message.isUser { Spacer(minLength: 50) }

                if !message.isUser {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color(white: 0.18))
                        .clipShape(Circle())
                }

                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        message.isUser
                        ? Color.red.opacity(0.85)
                        : Color(white: 0.14)
                    )
                    .cornerRadius(16)
                    .cornerRadius(message.isUser ? 4 : 4,
                                  corners: message.isUser ? .bottomRight : .bottomLeft)
                    .textSelection(.enabled)

                if !message.isUser { Spacer(minLength: 50) }

                if message.isUser {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            }

            // Stock quick-add buttons — only for AI messages
            if !message.isUser {
                let stocks = detectStocks(in: message.content)
                if !stocks.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(stocks) { stock in
                                let alreadyAdded = addedCodes.contains(stock.code)
                                    || watchlistVM.stocks.contains(where: { $0.id == stock.code })

                                Button(action: {
                                    if !alreadyAdded {
                                        watchlistVM.addStock(stock.searchResult)
                                        addedCodes.insert(stock.code)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                                            .font(.system(size: 12))
                                        Text(stock.displayText)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(alreadyAdded ? Color(white: 0.2) : Color.red.opacity(0.85))
                                    .foregroundColor(alreadyAdded ? Color.gray : Color.white)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(alreadyAdded ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 0.5)
                                    )
                                }
                                .disabled(alreadyAdded)
                            }
                        }
                        .padding(.leading, 40)  // align under bubble
                        .padding(.trailing, 12)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 7, height: 7)
                    .offset(y: phase == i ? -4 : 0)
                    .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
            }
        }
        .padding(12)
        .background(Color(white: 0.14))
        .cornerRadius(16)
        .onAppear { phase = 0 }
    }
}

// MARK: - Chat Input Bar
struct ChatInputBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let isLoading: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("输入问题...", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(white: 0.13))
                .cornerRadius(22)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
                )
                .focused($isFocused)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(isLoading || text.isEmpty ? .gray : .red)
            }
            .disabled(isLoading || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(white: 0.07))
    }
}

// MARK: - Rounded Corner Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
