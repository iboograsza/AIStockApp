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
    你是一位专业的A股投资分析师助手，具有丰富的中国股市分析经验。
    你能够：
    1. 分析股票技术面和基本面数据
    2. 解读财务数据和新闻资讯
    3. 提供客观的投资参考建议
    4. 分析市场情绪和板块趋势
    5. 解答投资相关问题

    注意事项：
    - 所有分析结果仅供参考，不构成投资建议
    - 股市有风险，入市需谨慎
    - 请遵守相关法律法规
    - 回答要简洁专业，使用中文
    """

    // MARK: - Chat
    func sendMessage(_ history: [ChatMessage], userMessage: String) async throws -> String {
        guard !apiKey.isEmpty else { throw DeepSeekError.noAPIKey }

        var requestMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
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
