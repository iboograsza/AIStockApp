import Foundation
import SwiftUI

@MainActor
class NewsViewModel: ObservableObject {
    @Published var news: [NewsItem] = []
    @Published var isLoading = false
    @Published var currentPage = 1
    @Published var hasMore = true

    func loadNews(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMore = true
        }
        guard !isLoading && hasMore else { return }
        isLoading = true
        do {
            let items = try await NewsService.shared.fetchLatestNews(page: currentPage)
            if refresh || currentPage == 1 {
                news = items
            } else {
                // Deduplicate by ID
                let existingIds = Set(news.map { $0.id })
                let newItems = items.filter { !existingIds.contains($0.id) }
                news.append(contentsOf: newItems)
            }
            hasMore = items.count >= 15
            currentPage += 1
        } catch {
            print("News fetch error: \(error)")
        }
        isLoading = false
    }

    func analyzeSentiment(for item: NewsItem) async {
        guard DeepSeekService.shared.apiKey.isEmpty == false else { return }
        do {
            let sentiment = try await DeepSeekService.shared.analyzeNewsSentiment(item)
            if let index = news.firstIndex(where: { $0.id == item.id }) {
                news[index].sentiment = sentiment
            }
        } catch {
            print("Sentiment error: \(error)")
        }
    }
}
