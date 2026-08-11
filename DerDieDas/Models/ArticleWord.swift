import Foundation

enum Article: String, CaseIterable, Identifiable, Codable, Hashable {
    case der
    case die
    case das

    var id: String { rawValue }

    var label: String { rawValue }
}

struct ArticleWord: Identifiable, Equatable, Codable, Hashable {
    var id: String
    var word: String
    var article: Article
    var emoji: String

    var fullPhrase: String { "\(article.rawValue) \(word)" }

    init(id: String? = nil, word: String, article: Article, emoji: String = "📘") {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        self.word = trimmedWord
        self.article = article
        self.emoji = emoji.isEmpty ? "📘" : emoji
        self.id = id ?? "\(article.rawValue)-\(trimmedWord)"
    }
}

struct WordPack: Codable, Equatable {
    var version: Int
    var source: String
    var words: [ArticleWord]
}

struct Player: Identifiable, Equatable {
    let id: UUID
    var name: String
    var score: Int
    var turns: Int

    init(id: UUID = UUID(), name: String, score: Int = 0, turns: Int = 0) {
        self.id = id
        self.name = name
        self.score = score
        self.turns = turns
    }
}

enum FeedbackState: Equatable {
    case idle
    case correct(String)
    case incorrect(expected: String, heard: String)
    case empty
}

enum GameSpeed: String, CaseIterable, Identifiable {
    case slow
    case normal
    case fast

    var id: String { rawValue }

    var label: String {
        switch self {
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        }
    }

    /// Extra pause after a correct answer before the next word.
    var correctAdvanceDelay: Double {
        switch self {
        case .slow: return 2.4
        case .normal: return 1.6
        case .fast: return 1.0
        }
    }

    /// Extra pause after an incorrect answer before the next word.
    var incorrectAdvanceDelay: Double {
        switch self {
        case .slow: return 3.0
        case .normal: return 2.1
        case .fast: return 1.3
        }
    }

    /// Gap after the noun is spoken before the mic opens.
    var postPromptDelay: Double {
        switch self {
        case .slow: return 0.65
        case .normal: return 0.4
        case .fast: return 0.25
        }
    }

    /// Multiplier on the default TTS rate (lower = slower speech).
    var speechRateMultiplier: Float {
        switch self {
        case .slow: return 0.72
        case .normal: return 0.88
        case .fast: return 1.02
        }
    }
}

