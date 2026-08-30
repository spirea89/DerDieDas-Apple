import Combine
import Foundation
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    @Published var playerCount = 1
    @Published var playerNames: [String] = ["Player 1"]
    @Published var roundLimit = 10
    @Published var gameSpeed: GameSpeed = .normal
    @Published var answerMode: AnswerMode = .articleAndWord
    @Published var players: [Player] = []
    @Published var currentPlayerIndex = 0
    @Published var gameStarted = false
    @Published var gameOver = false
    @Published var showCelebration = false

    @Published var currentWord: ArticleWord?
    @Published var feedback: FeedbackState = .idle
    @Published var streak = 0
    @Published var promptBounce = false
    @Published var isSpeakingPrompt = false
    @Published var isAwaitingSpeech = false
    @Published var isListening = false
    @Published var liveTranscript = ""
    @Published var recognitionHint: String?
    @Published var authorizationDenied = false

    private weak var wordStore: WordStore?
    private let speech = SpeechService()
    private let recognizer = SpeechRecognitionService()
    private var recentWordIDs: [String] = []
    private let recentWindow = 12
    private var advanceTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?
    private var roundToken = UUID()
    private var hasResolvedCurrentAnswer = false
    private var cancellables = Set<AnyCancellable>()
    private let speedDefaultsKey = "derDieDas.gameSpeed"
    private let answerModeDefaultsKey = "derDieDas.answerMode"

    let roundOptions = [5, 10, 15, 20, 30]

    init(wordStore: WordStore) {
        self.wordStore = wordStore
        if let saved = UserDefaults.standard.string(forKey: speedDefaultsKey),
           let speed = GameSpeed(rawValue: saved) {
            gameSpeed = speed
        }
        if let saved = UserDefaults.standard.string(forKey: answerModeDefaultsKey),
           let mode = AnswerMode(rawValue: saved) {
            answerMode = mode
        }
        recognizer.onTranscript = { [weak self] text, isFinal in
            self?.handleTranscript(text, isFinal: isFinal)
        }
        recognizer.$isListening
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.isListening = value }
            .store(in: &cancellables)
        recognizer.$authorizationDenied
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.authorizationDenied = value }
            .store(in: &cancellables)
        $gameSpeed
            .dropFirst()
            .sink { [weak self] speed in
                guard let self else { return }
                UserDefaults.standard.set(speed.rawValue, forKey: self.speedDefaultsKey)
            }
            .store(in: &cancellables)
        $answerMode
            .dropFirst()
            .sink { [weak self] mode in
                guard let self else { return }
                UserDefaults.standard.set(mode.rawValue, forKey: self.answerModeDefaultsKey)
            }
            .store(in: &cancellables)
    }

    func attach(wordStore: WordStore) {
        self.wordStore = wordStore
    }

    var currentPlayer: Player? {
        guard players.indices.contains(currentPlayerIndex) else { return nil }
        return players[currentPlayerIndex]
    }

    func syncPlayerNames() {
        let count = min(max(playerCount, 1), 6)
        playerCount = count
        if playerNames.count < count {
            for index in playerNames.count..<count {
                playerNames.append("Player \(index + 1)")
            }
        } else if playerNames.count > count {
            playerNames = Array(playerNames.prefix(count))
        }
    }

    func startGame() {
        syncPlayerNames()
        players = playerNames.enumerated().map { index, name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return Player(name: trimmed.isEmpty ? "Player \(index + 1)" : trimmed)
        }
        currentPlayerIndex = 0
        gameStarted = true
        gameOver = false
        showCelebration = false
        streak = 0
        recentWordIDs.removeAll()
        feedback = .idle
        liveTranscript = ""
        recognitionHint = nil
        pickNextWord(speak: true)
    }

    func resetToSetup() {
        cancelPendingWork()
        speech.cancel()
        stopRecognizer(resetTranscript: true)
        gameStarted = false
        gameOver = false
        showCelebration = false
        players = []
        currentPlayerIndex = 0
        currentWord = nil
        feedback = .idle
        streak = 0
        recentWordIDs.removeAll()
        isSpeakingPrompt = false
        isAwaitingSpeech = false
        isListening = false
        liveTranscript = ""
        recognitionHint = nil
        authorizationDenied = false
        hasResolvedCurrentAnswer = false
    }

    func pickNextWord(speak: Bool) {
        guard let store = wordStore, store.hasWords else {
            currentWord = nil
            feedback = .empty
            isAwaitingSpeech = false
            return
        }

        let pool = store.words
        let filtered = pool.filter { !recentWordIDs.contains($0.id) }
        let candidates = filtered.isEmpty ? pool : filtered
        guard let next = candidates.randomElement() else {
            currentWord = nil
            feedback = .empty
            return
        }

        cancelPendingWork()
        stopRecognizer(resetTranscript: true)

        currentWord = next
        recentWordIDs.append(next.id)
        if recentWordIDs.count > recentWindow {
            recentWordIDs.removeFirst(recentWordIDs.count - recentWindow)
        }

        feedback = .idle
        liveTranscript = ""
        recognitionHint = nil
        hasResolvedCurrentAnswer = false
        isAwaitingSpeech = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
            promptBounce.toggle()
        }
        if speak {
            beginPromptAndListen()
        }
    }

    func speakCurrentWord() {
        beginPromptAndListen()
    }

    func skipWord() {
        streak = 0
        feedback = .idle
        consumeTurnWithoutScore()
        advanceTurn()
    }

    func retryListening() {
        guard gameStarted, !gameOver, currentWord != nil, !hasResolvedCurrentAnswer else { return }
        feedback = .idle
        liveTranscript = ""
        recognitionHint = nil
        beginListeningOnly()
    }

    private func beginPromptAndListen() {
        guard let word = currentWord?.word else { return }
        let token = UUID()
        roundToken = token
        cancelPendingWork()
        stopRecognizer(resetTranscript: true)
        liveTranscript = ""
        isAwaitingSpeech = false
        hasResolvedCurrentAnswer = false
        isSpeakingPrompt = true
        recognitionHint = "Listen to the word…"

        listenTask = Task { [weak self] in
            guard let self else { return }
            await self.speech.speakGerman(word, rateMultiplier: self.gameSpeed.speechRateMultiplier)
            guard !Task.isCancelled, self.roundToken == token, self.gameStarted, !self.gameOver else { return }
            // Brief gap so TTS audio does not bleed into recognition.
            let gap = self.gameSpeed.postPromptDelay
            try? await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
            guard !Task.isCancelled, self.roundToken == token else { return }
            self.isSpeakingPrompt = false
            self.recognitionHint = "Wait for the beep…"
            await self.speech.playSpeakCue()
            guard !Task.isCancelled, self.roundToken == token, self.gameStarted, !self.gameOver else { return }
            await self.startListening(token: token)
        }
    }

    private func beginListeningOnly() {
        let token = roundToken
        cancelPendingWork()
        stopRecognizer(resetTranscript: true)
        isSpeakingPrompt = false
        listenTask = Task { [weak self] in
            guard let self else { return }
            self.recognitionHint = "Wait for the beep…"
            await self.speech.playSpeakCue()
            guard !Task.isCancelled, self.roundToken == token, self.gameStarted, !self.gameOver else { return }
            await self.startListening(token: token)
        }
    }

    private func startListening(token: UUID) async {
        guard roundToken == token, gameStarted, !gameOver, !hasResolvedCurrentAnswer else { return }
        recognitionHint = answerMode.yourTurnHint
        isAwaitingSpeech = true
        await recognizer.startListening()
        syncRecognizerState()
        if authorizationDenied {
            isAwaitingSpeech = false
            recognitionHint = recognizer.statusMessage
        } else if !isListening {
            isAwaitingSpeech = false
            recognitionHint = recognizer.statusMessage ?? "Could not start listening."
        } else {
            recognitionHint = answerMode.listeningHint
        }
    }

    private func syncRecognizerState() {
        isListening = recognizer.isListening
        authorizationDenied = recognizer.authorizationDenied
    }

    private func stopRecognizer(resetTranscript: Bool) {
        recognizer.stopListening(resetTranscript: resetTranscript)
        syncRecognizerState()
    }

    private func handleTranscript(_ text: String, isFinal: Bool) {
        guard gameStarted, !gameOver, !hasResolvedCurrentAnswer, let expected = currentWord else { return }
        liveTranscript = text

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Accept as soon as the spoken answer matches the selected mode.
        if GermanText.answersMatch(expected: expected, rawAnswer: trimmed, mode: answerMode) {
            resolveAnswer(raw: trimmed)
            return
        }

        // Otherwise wait until Speech finalizes (or silence debounce) before marking wrong.
        if isFinal {
            resolveAnswer(raw: trimmed)
        }
    }

    private func resolveAnswer(raw: String) {
        guard let expected = currentWord, !hasResolvedCurrentAnswer else { return }
        hasResolvedCurrentAnswer = true
        isAwaitingSpeech = false
        recognitionHint = nil
        stopRecognizer(resetTranscript: false)
        liveTranscript = raw

        if GermanText.answersMatch(expected: expected, rawAnswer: raw, mode: answerMode) {
            streak += 1
            awardPoint()
            feedback = .correct(expected.fullPhrase)
            speech.speakGerman(expected.fullPhrase, rateMultiplier: gameSpeed.speechRateMultiplier)
            scheduleAdvance(after: gameSpeed.correctAdvanceDelay)
            return
        }

        streak = 0
        let heard = GermanText.heardSummary(rawAnswer: raw, mode: answerMode)
        feedback = .incorrect(expected: expected.fullPhrase, heard: heard)
        speech.speakGerman(expected.fullPhrase, rateMultiplier: gameSpeed.speechRateMultiplier)
        consumeTurnWithoutScore()
        scheduleAdvance(after: gameSpeed.incorrectAdvanceDelay)
    }

    private func scheduleAdvance(after seconds: Double) {
        advanceTask?.cancel()
        let token = roundToken
        advanceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, !Task.isCancelled, self.roundToken == token else { return }
            self.advanceTurn()
        }
    }

    private func awardPoint() {
        guard players.indices.contains(currentPlayerIndex) else { return }
        players[currentPlayerIndex].score += 1
        players[currentPlayerIndex].turns += 1
    }

    private func consumeTurnWithoutScore() {
        guard players.indices.contains(currentPlayerIndex) else { return }
        players[currentPlayerIndex].turns += 1
    }

    private func advanceTurn() {
        cancelPendingWork()
        stopRecognizer(resetTranscript: true)
        if players.allSatisfy({ $0.turns >= roundLimit }) {
            gameOver = true
            showCelebration = true
            speech.cancel()
            isSpeakingPrompt = false
            isAwaitingSpeech = false
            isListening = false
            return
        }
        moveToNextPlayer()
        pickNextWord(speak: true)
    }

    private func moveToNextPlayer() {
        guard players.count > 1 else { return }
        var next = (currentPlayerIndex + 1) % players.count
        var guardCount = 0
        while players[next].turns >= roundLimit && guardCount < players.count {
            next = (next + 1) % players.count
            guardCount += 1
        }
        currentPlayerIndex = next
    }

    private func cancelPendingWork() {
        advanceTask?.cancel()
        advanceTask = nil
        listenTask?.cancel()
        listenTask = nil
        speech.cancel()
    }

    var winners: [Player] {
        let top = players.map(\.score).max() ?? 0
        return players.filter { $0.score == top }
    }
}
