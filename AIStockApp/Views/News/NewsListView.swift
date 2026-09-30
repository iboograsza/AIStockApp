import SwiftUI

struct NewsListView: View {
    @EnvironmentObject var viewModel: NewsViewModel

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    ForEach(viewModel.news) { item in
                        NewsRowView(item: item)
                            .listRowBackground(Color(white: 0.07))
                            .listRowSeparatorTint(Color.gray.opacity(0.2))
                            .onAppear {
                                // Load more when reaching end
                                if item.id == viewModel.news.last?.id {
                                    Task { await viewModel.loadNews() }
                                }
                            }
                    }

                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView().tint(.gray)
                            Spacer()
                        }
                        .listRowBackground(Color.black)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .background(Color.black)
                .refreshable {
                    await viewModel.loadNews(refresh: true)
                }

                if viewModel.news.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "newspaper")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("暂无资讯")
                            .foregroundColor(.gray)
                        Button("刷新") {
                            Task { await viewModel.loadNews(refresh: true) }
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("财经资讯")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if viewModel.news.isEmpty {
                    Task { await viewModel.loadNews() }
                }
            }
        }
    }
}
