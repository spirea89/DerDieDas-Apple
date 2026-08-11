import Combine
import Foundation
import SwiftUI

struct EditableWord: Identifiable, Equatable {
    let id: UUID
    var word: String
    var article: Article
    var emoji: String

    init(id: UUID = UUID(), word: String, article: Article, emoji: String) {
        self.id = id
        self.word = word
        self.article = article
        self.emoji = emoji
    }

    init(from word: ArticleWord) {
        self.id = UUID()
        self.word = word.word
        self.article = word.article
        self.emoji = word.emoji
    }
}

@MainActor
final class ConfigureViewModel: ObservableObject {
    @Published var editableWords: [EditableWord] = []
    @Published var filter: String = ""
    @Published var hasUnsavedChanges = false
    @Published var statusMessage: String?
    @Published var selectedID: UUID?

    private weak var wordStore: WordStore?

    init(wordStore: WordStore) {
        self.wordStore = wordStore
        loadFromStore()
    }

    func attach(wordStore: WordStore) {
        self.wordStore = wordStore
    }

    var filteredWords: [EditableWord] {
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return editableWords }
        let normalized = GermanText.normalize(query)
        return editableWords.filter {
            GermanText.normalize($0.word).contains(normalized)
                || $0.article.rawValue.contains(normalized)
        }
    }

    func loadFromStore() {
        guard let store = wordStore else { return }
        editableWords = store.words.map(EditableWord.init(from:))
        selectedID = editableWords.first?.id
        hasUnsavedChanges = false
        statusMessage = "Loaded \(editableWords.count) words."
    }

    func addWord() {
        let item = EditableWord(word: "", article: .der, emoji: "📘")
        editableWords.insert(item, at: 0)
        selectedID = item.id
        hasUnsavedChanges = true
    }

    func deleteSelected() {
        guard let selectedID else { return }
        editableWords.removeAll { $0.id == selectedID }
        self.selectedID = editableWords.first?.id
        hasUnsavedChanges = true
    }

    func markDirty() {
        hasUnsavedChanges = true
    }

    func save() {
        guard let store = wordStore else { return }
        let next = editableWords.compactMap { item -> ArticleWord? in
            let word = GermanText.cleanWord(item.word)
            guard !word.isEmpty else { return nil }
            return ArticleWord(word: word, article: item.article, emoji: item.emoji.isEmpty ? "📘" : item.emoji)
        }

        // Dedupe by normalized word, keep first.
        var seen = Set<String>()
        var unique: [ArticleWord] = []
        for word in next {
            let key = GermanText.normalize(word.word)
            if seen.contains(key) { continue }
            seen.insert(key)
            unique.append(word)
        }

        do {
            try store.save(unique)
            loadFromStore()
            statusMessage = "Saved \(unique.count) words."
            hasUnsavedChanges = false
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func resetToDefaults() {
        guard let store = wordStore else { return }
        do {
            try store.resetToDefaults()
            loadFromStore()
            statusMessage = store.statusMessage
            hasUnsavedChanges = false
        } catch {
            statusMessage = "Reset failed: \(error.localizedDescription)"
        }
    }

    func binding(for id: UUID) -> Binding<EditableWord>? {
        guard let index = editableWords.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.editableWords[index] },
            set: {
                self.editableWords[index] = $0
                self.hasUnsavedChanges = true
            }
        )
    }
}
