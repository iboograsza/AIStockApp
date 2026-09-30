import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date = Date()

    enum MessageRole {
        case user
        case assistant
        case system
    }

    var isUser: Bool { role == .user }
}
