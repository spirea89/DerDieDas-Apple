import SwiftUI

struct ContentView: View {
    @ObservedObject var wordStore: WordStore
    @StateObject private var gameViewModel: GameViewModel
    @StateObject private var configureViewModel: ConfigureViewModel
    @State private var selectedTab: AppTab = .play

    init(wordStore: WordStore) {
        self.wordStore = wordStore
        _gameViewModel = StateObject(wrappedValue: GameViewModel(wordStore: wordStore))
        _configureViewModel = StateObject(wrappedValue: ConfigureViewModel(wordStore: wordStore))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.skyTop, AppTheme.skyBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(
                GeometryReader { geo in
                    Circle()
                        .fill(AppTheme.der.opacity(0.10))
                        .frame(width: geo.size.width * 0.7)
                        .offset(x: -geo.size.width * 0.25, y: -40)
                    Circle()
                        .fill(AppTheme.die.opacity(0.10))
                        .frame(width: geo.size.width * 0.55)
                        .offset(x: geo.size.width * 0.55, y: geo.size.height * 0.15)
                    Circle()
                        .fill(AppTheme.das.opacity(0.12))
                        .frame(width: geo.size.width * 0.45)
                        .offset(x: geo.size.width * 0.2, y: geo.size.height * 0.62)
                }
                .allowsHitTesting(false)
            )

            VStack(spacing: 0) {
                topBar
                TabView(selection: $selectedTab) {
                    GameView(viewModel: gameViewModel, wordStore: wordStore)
                        .tag(AppTab.play)
                    ConfigureView(viewModel: configureViewModel, wordStore: wordStore)
                        .tag(AppTab.words)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .play {
                wordStore.reload()
                gameViewModel.attach(wordStore: wordStore)
            } else {
                configureViewModel.attach(wordStore: wordStore)
                configureViewModel.loadFromStore()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("DdD")
                    .font(AppTheme.captionFont.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.der, AppTheme.die, AppTheme.das],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("Der Die Das")
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.ink)
            }

            Spacer()

            HStack(spacing: 6) {
                tabButton(.play, title: "Play")
                tabButton(.words, title: "Words")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.55))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.line.opacity(0.7))
                .frame(height: 1)
        }
    }

    private func tabButton(_ tab: AppTab, title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(title)
                .font(AppTheme.captionFont.weight(.bold))
                .foregroundStyle(selectedTab == tab ? AppTheme.ink : AppTheme.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selectedTab == tab ? Color.white.opacity(0.9) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private enum AppTab {
    case play
    case words
}

#Preview {
    ContentView(wordStore: WordStore())
}
