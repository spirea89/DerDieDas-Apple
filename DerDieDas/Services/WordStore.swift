import Combine
import Foundation

@MainActor
final class WordStore: ObservableObject {
    @Published private(set) var words: [ArticleWord] = []
    @Published private(set) var statusMessage: String?

    private let overrideFileName = "words.json"
    private let folderName = "DerDieDas"

    init() {
        reload()
    }

    var hasWords: Bool { !words.isEmpty }

    func reload() {
        do {
            if let overrideURL = overrideURL(), FileManager.default.fileExists(atPath: overrideURL.path) {
                words = try loadPack(from: overrideURL).words
                statusMessage = nil
                return
            }
            guard let bundled = bundledURL() else {
                words = []
                statusMessage = "Bundled word list missing."
                return
            }
            words = try loadPack(from: bundled).words
            statusMessage = nil
        } catch {
            words = []
            statusMessage = "Could not load words: \(error.localizedDescription)"
        }
    }

    func save(_ nextWords: [ArticleWord]) throws {
        let cleaned = nextWords
            .map {
                ArticleWord(
                    id: $0.id,
                    word: GermanText.cleanWord($0.word),
                    article: $0.article,
                    emoji: $0.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.word.isEmpty }

        let pack = WordPack(version: 1, source: "user", words: cleaned)
        let url = try ensureOverrideURL()
        let data = try JSONEncoder.pretty.encode(pack)
        try data.write(to: url, options: [.atomic])
        words = cleaned
        statusMessage = "Saved \(cleaned.count) words."
    }

    func resetToDefaults() throws {
        if let overrideURL = overrideURL(), FileManager.default.fileExists(atPath: overrideURL.path) {
            try FileManager.default.removeItem(at: overrideURL)
        }
        reload()
        statusMessage = "Reset to bundled word list (\(words.count) words)."
    }

    private func loadPack(from url: URL) throws -> WordPack {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WordPack.self, from: data)
    }

    private func bundledURL() -> URL? {
        let candidates = [
            Bundle.main.url(forResource: "words", withExtension: "json", subdirectory: "content"),
            Bundle.main.url(forResource: "words", withExtension: "json", subdirectory: "Resources/content"),
            Bundle.main.url(forResource: "words", withExtension: "json")
        ]
        return candidates.compactMap { $0 }.first
    }

    private func overrideURL() -> URL? {
        guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return root.appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("content", isDirectory: true)
            .appendingPathComponent(overrideFileName)
    }

    private func ensureOverrideURL() throws -> URL {
        guard let url = overrideURL() else {
            throw NSError(domain: "DerDieDas", code: 1, userInfo: [NSLocalizedDescriptionKey: "No Application Support directory."])
        }
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return url
    }
}

private extension JSONEncoder {
    static let pretty: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
