import Foundation

class DeepSeekService: ObservableObject {
    static let shared = DeepSeekService()

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "deepseek_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "deepseek_api_key") }
    }

    private let baseURL = "https://api.deepseek.com/chat/completions"
    private let model = "deepseek-chat"

    private let systemPrompt = """
    你是一位顶尖的A股资深金牌投资顾问与股票操盘专家。
    【核心使命】：
    用户向你询问行情、选股、个股分析或求推荐股票时，你必须【积极主动、毫不推脱】地给出明确的观点、标的推荐和操作策略！
    
    【回答规范】：
    1. 🎯 明确选股与推荐：当用户询问买什么、推荐股票或板块机会时，必须明确给出具体的关注标的（如行业龙头、具备业绩反转或当前热点主线的标的）、推荐逻辑、参考买入区间和止盈止损位。
    2. 📈 个股深度诊断：给出明确的操作评级（【强烈推荐/买入】、【持股待涨】、【高抛减仓】或【观望规避】），并结合估值、技术形态（突破/支撑）、资金流向做断定。
    3. ⚡ 结合实时快讯：结合最新的政策导向、快讯利好利空分析，挖掘潜在的领涨板块与龙头个股。
    4. 💡 表达风格：专业、果断、有理有据，不讲废话套话。在回答结尾附一句标准的合规提示：“（投资有风险，决策需独立，以上分析与标的仅供策略参考）”。
    """

    // MARK: - Chat
    func sendMessage(_ history: [ChatMessage], userMessage: String, newsContext: [NewsItem] = []) async throws -> String {
        guard !apiKey.isEmpty else { throw DeepSeekError.noAPIKey }

        var prompt = systemPrompt
        if !newsContext.isEmpty {
            let newsSnippets = newsContext.prefix(8).map { "【\($0.source)】\($0.title)" }.joined(separator: "\n")
            prompt += "\n\n【最新市场实时快报资讯】：\n\(newsSnippets)\n\n请在回答用户提问时，充分结合上述最新突发资讯与市场消息进行专业分析与解读。"
        }

        var requestMessages: [[String: String]] = [
            ["role": "system", "content": prompt]
        ]

        // Add conversation history (last 10 messages to save tokens)
        for msg in history.suffix(10) {
            requestMessages.append([
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.content
            ])
        }
        requestMessages.append(["role": "user", "content": userMessage])

        let requestBody: [String: Any] = [
            "model": model,
            "messages": requestMessages,
            "max_tokens": 2048,
            "temperature": 0.7,
            "stream": false
        ]

        guard let url = URL(string: baseURL) else { throw DeepSeekError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if httpResponse.statusCode == 401 { throw DeepSeekError.invalidAPIKey }
            throw DeepSeekError.httpError(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        return decoded.choices.first?.message.content ?? "无法获取回复"
    }

    // MARK: - Stock Analysis
    func analyzeStock(_ stock: Stock, news: [NewsItem] = []) async throws -> String {
        let newsText = news.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
        let prompt = """
        请分析以下A股股票：

        股票：\(stock.name) (\(stock.exchange.rawValue)\(stock.id))
        当前价格：\(String(format: "%.2f", stock.currentPrice)) 元
        涨跌幅：\(String(format: "%+.2f", stock.changePercent))%
        今开：\(String(format: "%.2f", stock.open))  最高：\(String(format: "%.2f", stock.high))  最低：\(String(format: "%.2f", stock.low))
        成交量：\(Int(stock.volume / 100))手  成交额：\(String(format: "%.2f", stock.turnover / 100000000))亿元

        \(newsText.isEmpty ? "" : "相关新闻：\n\(newsText)\n")
        请从技术面、基本面和市场情绪三个维度进行简要分析，并给出操作参考（仅供参考）。
        """
        return try await sendMessage([], userMessage: prompt)
    }

    // MARK: - News Sentiment
    func analyzeNewsSentiment(_ news: NewsItem) async throws -> NewsItem.NewsSentiment {
        let prompt = "请判断以下财经新闻对股市/个股的影响，只回复：利好、利空 或 中性\n\n新闻：\(news.title)"
        let response = try await sendMessage([], userMessage: prompt)
        if response.contains("利好") { return .positive }
        if response.contains("利空") { return .negative }
        return .neutral
    }

    // MARK: - Market Summary
    func getMarketSummary(indices: [Stock]) async throws -> String {
        let indicesText = indices.map { "\($0.name): \(String(format: "%.2f", $0.currentPrice))(\(String(format: "%+.2f", $0.changePercent))%)" }.joined(separator: ", ")
        let prompt = "当前A股主要指数：\(indicesText)。请简要分析今日市场行情，给出板块机会提示。"
        return try await sendMessage([], userMessage: prompt)
    }

    // MARK: - Errors
    enum DeepSeekError: Error, LocalizedError {
        case noAPIKey
        case invalidAPIKey
        case invalidURL
        case httpError(Int)
        case decodingError

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "请先在设置中配置 DeepSeek API Key"
            case .invalidAPIKey: return "API Key 无效，请检查设置"
            case .invalidURL: return "无效的URL"
            case .httpError(let code): return "HTTP错误: \(code)"
            case .decodingError: return "数据解析错误"
            }
        }
    }
}

// MARK: - Response Models
struct DeepSeekResponse: Codable {
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Codable {
        let message: Message
        struct Message: Codable {
            let content: String
        }
    }

    struct Usage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}
