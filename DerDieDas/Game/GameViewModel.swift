import Combine
import Foundation
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    @Published var playerCount = 1
    @Published var playerNames: [String] = ["Player 1"]
    @Published var roundLimit = 10
    @Published var players: [Player] = []
    @Published var currentPlayerIndex = 0
    @Published var gameStarted = false
    @Published var gameOver = false
    @Published var showCelebration = false

    @Published var currentWord: ArticleWord?
    @Published var answerText = ""
    @Published var selectedArticle: Article?
    @Published var feedback: FeedbackState = .idle
    @Published var streak = 0
    @Published var promptBounce = false

    private weak var wordStore: WordStore?
    private let speech = SpeechService()
    private var recentWordIDs: [String] = []
    private let recentWindow = 12

    let roundOptions = [5, 10, 15, 20, 30]

    init(wordStore: WordStore) {
        self.wordStore = wordStore
    }

    func attach(wordStore: WordStore) {
        self.wordStore = wordStore
    }

    var setupLocked: Bool { gameStarted && !gameOver }
    var currentPlayer: Player? {
        guard players.indices.contains(currentPlayerIndex) else { return nil }
        return players[currentPlayerIndex]
    }

    var canCheck: Bool {
        gameStarted && !gameOver && currentWord != nil && !normalizedAnswerInput.isEmpty
    }

    private var normalizedAnswerInput: String {
        let typed = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let selectedArticle, !typed.isEmpty {
            // If the user tapped an article chip and typed only the noun, compose both.
            if GermanText.parseArticle(typed) == nil {
                return "\(selectedArticle.rawValue) \(typed)"
            }
        }
        if let selectedArticle, typed.isEmpty {
            return selectedArticle.rawValue
        }
        return typed
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
        pickNextWord(speak: true)
    }

    func resetToSetup() {
        speech.cancel()
        gameStarted = false
        gameOver = false
        showCelebration = false
        players = []
        currentPlayerIndex = 0
        currentWord = nil
        answerText = ""
        selectedArticle = nil
        feedback = .idle
        streak = 0
        recentWordIDs.removeAll()
    }

    func pickNextWord(speak: Bool) {
        guard let store = wordStore, store.hasWords else {
            currentWord = nil
            feedback = .empty
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

        currentWord = next
        recentWordIDs.append(next.id)
        if recentWordIDs.count > recentWindow {
            recentWordIDs.removeFirst(recentWordIDs.count - recentWindow)
        }

        answerText = ""
        selectedArticle = nil
        feedback = .idle
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
            promptBounce.toggle()
        }
        if speak {
            speakCurrentWord()
        }
    }

    func speakCurrentWord() {
        guard let word = currentWord?.word else { return }
        speech.speakGerman(word)
    }

    func speakFullAnswer() {
        guard let phrase = currentWord?.fullPhrase else { return }
        speech.speakGerman(phrase)
    }

    func selectArticle(_ article: Article) {
        selectedArticle = article
        if answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            answerText = "\(article.rawValue) "
        } else if GermanText.parseArticle(answerText.split(separator: " ").first.map(String.init) ?? "") == nil {
            answerText = "\(article.rawValue) \(answerText.trimmingCharacters(in: .whitespacesAndNewlines))"
        } else {
            var parts = answerText.split(separator: " ").map(String.init)
            if !parts.isEmpty {
                parts[0] = article.rawValue
                answerText = parts.joined(separator: " ")
            }
        }
    }

    func checkAnswer() {
        guard let expected = currentWord, canCheck else { return }
        let raw = normalizedAnswerInput

        if GermanText.answersMatch(expected: expected, rawAnswer: raw) {
            streak += 1
            awardPoint()
            feedback = .correct(expected.fullPhrase)
            speech.speakGerman(expected.fullPhrase)
            Task {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                advanceTurn()
            }
            return
        }

        streak = 0
        let heard = GermanText.parseAnswer(raw).map { "\($0.article.rawValue) \($0.word)" } ?? raw
        feedback = .incorrect(expected: expected.fullPhrase, heard: heard)
    }

    func skipWord() {
        streak = 0
        feedback = .idle
        consumeTurnWithoutScore()
        advanceTurn()
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
        if players.allSatisfy({ $0.turns >= roundLimit }) {
            gameOver = true
            showCelebration = true
            speech.cancel()
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

    var winners: [Player] {
        let top = players.map(\.score).max() ?? 0
        return players.filter { $0.score == top }
    }
}
