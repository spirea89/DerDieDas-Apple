import SwiftUI

struct GameView: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var wordStore: WordStore

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

            Text("Practice German articles out loud. The app says the noun, then beeps when it is your turn — answer with der, die, or das plus the word. No typing. Best on a real iPhone.")
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

            VStack(alignment: .leading, spacing: 12) {
                Text("Pace")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.muted)

                Picker("Pace", selection: $viewModel.gameSpeed) {
                    ForEach(GameSpeed.allCases) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .pickerStyle(.segmented)

                Text(paceHelpText)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.muted)
            }
            .padding(16)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                viewModel.startGame()
            } label: {
                Text(wordStore.hasWords ? "Start" : "Add words first")
            }
            .buttonStyle(PrimaryButtonStyle(disabled: !wordStore.hasWords))
            .disabled(!wordStore.hasWords)

            Text("\(wordStore.words.count) words ready · answers by voice")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.muted)
        }
        .onAppear { viewModel.syncPlayerNames() }
    }

    private var paceHelpText: String {
        switch viewModel.gameSpeed {
        case .slow:
            return "Slower speech and a longer pause before the next word."
        case .normal:
            return "Balanced speech and pause between words."
        case .fast:
            return "Quicker speech and a shorter pause between words."
        }
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

            paceStrip

            promptCard
            listeningPanel
            feedbackBanner

            HStack(spacing: 10) {
                Button {
                    viewModel.speakCurrentWord()
                } label: {
                    Label("Hear again", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    viewModel.skipWord()
                } label: {
                    Text("Skip")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            HStack(spacing: 10) {
                if viewModel.authorizationDenied || (!viewModel.isListening && !viewModel.isSpeakingPrompt && viewModel.feedback == .idle) {
                    Button {
                        viewModel.retryListening()
                    } label: {
                        Label("Listen again", systemImage: "mic.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button {
                    viewModel.resetToSetup()
                } label: {
                    Text("End game")
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
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

    private var paceStrip: some View {
        HStack(spacing: 10) {
            Text("Pace")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.muted)
            Picker("Pace", selection: $viewModel.gameSpeed) {
                ForEach(GameSpeed.allCases) { speed in
                    Text(speed.label).tag(speed)
                }
            }
            .pickerStyle(.segmented)
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

            Text("Wait for the beep, then say der/die/das + this word")
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

    private var listeningPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(micColor.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: micSymbol)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(micColor)
                        .symbolEffect(.pulse, isActive: viewModel.isListening)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(AppTheme.titleFont)
                        .foregroundStyle(AppTheme.ink)
                    if let hint = viewModel.recognitionHint, !hint.isEmpty {
                        Text(hint)
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                Spacer(minLength: 0)
            }

            if !viewModel.liveTranscript.isEmpty {
                Text(viewModel.liveTranscript)
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.line, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Heard \(viewModel.liveTranscript)")
            } else {
                Text("Your spoken answer will appear here.")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: viewModel.isListening)
        .animation(.easeInOut(duration: 0.2), value: viewModel.liveTranscript)
    }

    private var statusTitle: String {
        if viewModel.isSpeakingPrompt { return "Hearing the word" }
        if viewModel.recognitionHint?.localizedCaseInsensitiveContains("beep") == true {
            return "Get ready"
        }
        if viewModel.isListening { return "Your turn" }
        switch viewModel.feedback {
        case .correct: return "Correct"
        case .incorrect: return "Not quite"
        default: return "Ready when you are"
        }
    }

    private var micSymbol: String {
        if viewModel.isSpeakingPrompt { return "speaker.wave.2.fill" }
        if viewModel.isListening { return "mic.fill" }
        switch viewModel.feedback {
        case .correct: return "checkmark.circle.fill"
        case .incorrect: return "xmark.circle.fill"
        default: return "mic"
        }
    }

    private var micColor: Color {
        if viewModel.isSpeakingPrompt { return AppTheme.accent }
        if viewModel.isListening { return AppTheme.die }
        switch viewModel.feedback {
        case .correct: return AppTheme.success
        case .incorrect: return AppTheme.danger
        default: return AppTheme.muted
        }
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
        case .incorrect(let expected, let heard):
            VStack(alignment: .leading, spacing: 4) {
                Label("Heard: \(heard)", systemImage: "ear.fill")
                Text("Correct is \(expected). Next word coming up…")
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
