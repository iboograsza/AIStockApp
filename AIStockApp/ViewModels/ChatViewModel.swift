import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var contextStock: Stock?

    init() {
        messages.append(ChatMessage(
            role: .assistant,
            content: "你好！我是股智AI金牌操盘助手 🤖\n\n我可以直接为你：\n🎯 推荐当前潜力金股与主线板块\n📈 深度诊断个股买卖点（支持目标价/止损参考）\n📰 结合实时快讯挖掘盘中暴涨与突发机会\n📊 解读主力资金动向与筹码分布\n\n你可以直接向我提问：例如「今天推荐买什么股票？」或「帮我诊断一下手中股票」！"
        ))
    }

    func sendMessage(_ text: String, newsContext: [NewsItem] = []) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMsg = ChatMessage(role: .user, content: trimmed)
        messages.append(userMsg)
        isLoading = true
        errorMessage = nil

        do {
            // Build context with current stock if available
            var messageToSend = trimmed
            if let stock = contextStock, trimmed.count < 20 {
                // If short message and we have context, add stock context
                messageToSend = "关于\(stock.name)(\(stock.exchange.rawValue)\(stock.id))，当前价\(String(format: "%.2f", stock.currentPrice))元：\(trimmed)"
            }

            let response = try await DeepSeekService.shared.sendMessage(
                messages.dropLast(),
                userMessage: messageToSend,
                newsContext: newsContext
            )
            messages.append(ChatMessage(role: .assistant, content: response))
        } catch let error as DeepSeekService.DeepSeekError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "网络错误，请重试"
        }
        isLoading = false
    }

    func analyzeCurrentStock() async {
        guard let stock = contextStock else {
            errorMessage = "没有选中的股票"
            return
        }
        await sendMessage("请详细分析\(stock.name)的投资价值，当前价\(String(format: "%.2f", stock.currentPrice))元，涨跌幅\(String(format: "%+.2f", stock.changePercent))%")
    }

    func clearHistory() {
        let welcomeMsg = messages.first
        messages.removeAll()
        if let msg = welcomeMsg {
            messages.append(msg)
        }
        errorMessage = nil
    }
}
