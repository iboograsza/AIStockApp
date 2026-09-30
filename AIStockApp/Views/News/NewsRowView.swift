import SwiftUI

struct NewsRowView: View {
    let item: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                // Source badge
                Text(item.source)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                Text("·")
                    .foregroundColor(.gray.opacity(0.5))

                Text(item.timeAgo)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                Spacer()

                // Sentiment badge
                if let sentiment = item.sentiment {
                    sentimentBadge(sentiment)
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func sentimentBadge(_ sentiment: NewsItem.NewsSentiment) -> some View {
        let (text, color): (String, Color) = {
            switch sentiment {
            case .positive: return (sentiment.rawValue, .red)
            case .negative: return (sentiment.rawValue, Color(red: 0, green: 0.78, blue: 0.2))
            case .neutral: return (sentiment.rawValue, .gray)
            }
        }()

        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.4), lineWidth: 0.5)
            )
            .cornerRadius(4)
    }
}
