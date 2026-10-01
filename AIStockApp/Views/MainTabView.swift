import SwiftUI

struct MainTabView: View {
    @StateObject private var watchlistVM = WatchlistViewModel()
    @StateObject private var newsVM = NewsViewModel()
    @StateObject private var chatVM = ChatViewModel()

    var body: some View {
        TabView {
            WatchlistView()
                .environmentObject(watchlistVM)
                .tabItem {
                    Label("自选", systemImage: "star.fill")
                }

            NewsListView()
                .environmentObject(newsVM)
                .tabItem {
                    Label("资讯", systemImage: "newspaper.fill")
                }

            AIChatView()
                .environmentObject(chatVM)
                .environmentObject(newsVM)
                .environmentObject(watchlistVM)
                .tabItem {
                    Label("AI助手", systemImage: "brain.head.profile")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .accentColor(.red)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView()
}
