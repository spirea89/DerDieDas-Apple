import SwiftUI

struct GameView: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var wordStore: WordStore
    @FocusState private var answerFocused: Bool

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !viewModel.gameStarted || viewModel.gameOver {
                        setupSection
                    } else {
                        playSection
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }

            if viewModel.showCelebration {
                CelebrationView(
                    winners: viewModel.winners,
                    onClose: {
                        viewModel.showCelebration = false
                        viewModel.resetToSetup()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: viewModel.showCelebration)
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            brandHero

            Text("Practice German articles out loud. The app says the noun — you answer with der, die, or das plus the word.")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                Text("Players")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.muted)

                Picker("Players", selection: $viewModel.playerCount) {
                    ForEach(1...6, id: \.self) { count in
                        Text(count == 1 ? "Solo" : "\(count) players").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.playerCount) { _, _ in
                    viewModel.syncPlayerNames()
                }

                ForEach(viewModel.playerNames.indices, id: \.self) { index in
                    TextField("Player \(index + 1)", text: $viewModel.playerNames[index])
                        .textFieldStyle(RoundedFieldStyle())
                        .font(AppTheme.bodyFont)
                }
            }
            .padding(16)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text("Rounds per player")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.muted)

                Picker("Rounds", selection: $viewModel.roundLimit) {
                    ForEach(viewModel.roundOptions, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                viewModel.startGame()
                answerFocused = true
            } label: {
                Text(wordStore.hasWords ? "Start" : "Add words first")
            }
            .buttonStyle(PrimaryButtonStyle(disabled: !wordStore.hasWords))
            .disabled(!wordStore.hasWords)

            Text("\(wordStore.words.count) words ready")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.muted)
        }
        .onAppear { viewModel.syncPlayerNames() }
    }

    private var brandHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Der Die Das")
                .font(AppTheme.brandFont)
                .foregroundStyle(AppTheme.ink)
                .overlay(alignment: .bottomLeading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.der, AppTheme.die, AppTheme.das],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 120, height: 5)
                        .offset(y: 8)
                }
                .padding(.bottom, 6)

            HStack(spacing: 8) {
                articleBadge(.der)
                articleBadge(.die)
                articleBadge(.das)
            }
        }
        .padding(.top, 4)
    }

    private func articleBadge(_ article: Article) -> some View {
        Text(article.label)
            .font(AppTheme.captionFont.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppTheme.articleColor(article))
            .clipShape(Capsule())
    }

    private var playSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            scoreStrip

            if viewModel.players.count > 1 {
                ScoreboardView(players: viewModel.players, currentPlayerID: viewModel.currentPlayer?.id)
            }

            promptCard

            articleChooser

            VStack(alignment: .leading, spacing: 8) {
                Text("Your answer")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.muted)

                TextField("der Sonne", text: $viewModel.answerText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($answerFocused)
                    .submitLabel(.go)
                    .onSubmit { viewModel.checkAnswer() }
                    .font(AppTheme.titleFont)
                    .textFieldStyle(RoundedFieldStyle())

                Text("Type the article and the word together.")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.muted)
            }

            feedbackBanner

            HStack(spacing: 10) {
                Button {
                    viewModel.checkAnswer()
                } label: {
                    Text("Check")
                }
                .buttonStyle(PrimaryButtonStyle(disabled: !viewModel.canCheck))
                .disabled(!viewModel.canCheck)

                Button {
                    viewModel.skipWord()
                    answerFocused = true
                } label: {
                    Text("Skip")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.speakCurrentWord()
                } label: {
                    Label("Hear word", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(GhostButtonStyle())

                Button {
                    viewModel.resetToSetup()
                } label: {
                    Text("End game")
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
        .onAppear { answerFocused = true }
    }

    private var scoreStrip: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentPlayer?.name ?? "Player")
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.ink)
                Text("Turn \(min((viewModel.currentPlayer?.turns ?? 0) + 1, viewModel.roundLimit)) of \(viewModel.roundLimit)")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(viewModel.currentPlayer?.score ?? 0)")
                    .font(AppTheme.displayFont)
                    .foregroundStyle(AppTheme.accent)
                    .contentTransition(.numericText())
                Text("Streak \(viewModel.streak)")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    private var promptCard: some View {
        VStack(spacing: 14) {
            Text(viewModel.currentWord?.emoji ?? "📘")
                .font(.system(size: 54))
                .scaleEffect(viewModel.promptBounce ? 1.08 : 1.0)
                .animation(.spring(response: 0.45, dampingFraction: 0.55), value: viewModel.promptBounce)

            Text(viewModel.currentWord?.word ?? "—")
                .font(AppTheme.displayFont)
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .id(viewModel.currentWord?.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

            Text("Say or type the article + this word")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.der.opacity(0.35), AppTheme.die.opacity(0.35), AppTheme.das.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }

    private var articleChooser: some View {
        HStack(spacing: 10) {
            ForEach(Article.allCases) { article in
                Button {
                    viewModel.selectArticle(article)
                    answerFocused = true
                } label: {
                    Text(article.label)
                        .font(AppTheme.titleFont)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.articleColor(article).opacity(viewModel.selectedArticle == article ? 1 : 0.78))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(viewModel.selectedArticle == article ? 0.9 : 0), lineWidth: 2)
                        )
                        .scaleEffect(viewModel.selectedArticle == article ? 1.03 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.selectedArticle)
    }

    @ViewBuilder
    private var feedbackBanner: some View {
        switch viewModel.feedback {
        case .idle:
            EmptyView()
        case .correct(let phrase):
            Label("Yes! \(phrase)", systemImage: "checkmark.seal.fill")
                .font(AppTheme.bodyFont.weight(.bold))
                .foregroundStyle(AppTheme.success)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.success.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .incorrect(_, let heard):
            VStack(alignment: .leading, spacing: 4) {
                Label("Almost. Heard: \(heard)", systemImage: "arrow.triangle.2.circlepath")
                Text("Answer with both the article and the word, then Check again.")
                    .font(AppTheme.captionFont)
            }
            .font(AppTheme.bodyFont.weight(.semibold))
            .foregroundStyle(AppTheme.danger)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.danger.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .empty:
            Text("No words available. Add some in Words.")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.danger)
        }
    }
}

struct RoundedFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
