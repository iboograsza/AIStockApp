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
            content: "你好！我是股智AI助手 🤖\n\n我可以帮你：\n• 分析个股技术面和基本面\n• 解读市场行情和新闻\n• 回答投资相关问题\n• 提供板块趋势分析\n\n请问有什么可以帮你的？\n\n⚠️ 提示：需要在设置中配置 DeepSeek API Key 才能使用 AI 功能。"
        ))
    }

    func sendMessage(_ text: String) async {
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

            let response = try await DeepSeekService.shared.sendMessage(messages.dropLast(), userMessage: messageToSend)
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
