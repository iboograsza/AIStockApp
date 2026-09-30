import SwiftUI

struct AIChatView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @EnvironmentObject var newsVM: NewsViewModel
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    private let quickQuestions = [
        "结合最新突发快讯分析市场走向",
        "解读今日热点资讯对大盘利好利空",
        "今日哪些板块出现异动或利好？",
        "北向资金今日动向如何？",
        "如何看待当前整体市场情绪？"
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
                                    MessageBubble(message: message)
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

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
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
