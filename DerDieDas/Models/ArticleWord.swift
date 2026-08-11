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
