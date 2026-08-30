import Foundation

enum GermanText {
    static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: Locale(identifier: "de_DE"))
            .replacingOccurrences(of: "ß", with: "ss")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    static func cleanWord(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let allowed = CharacterSet.letters.union(.whitespaces).union(CharacterSet(charactersIn: "-"))
        return String(trimmed.unicodeScalars.filter { allowed.contains($0) })
    }

    static func parseArticle(_ value: String) -> Article? {
        let cleaned = normalize(value).replacingOccurrences(of: " ", with: "")
        return Article(rawValue: cleaned)
    }

    /// Softens common speech-recognition misfires for der/die/das.
    private static func softenSpeech(_ raw: String) -> String {
        normalize(raw)
            .replacingOccurrences(of: #"\bdeer\b"#, with: "der", options: .regularExpression)
            .replacingOccurrences(of: #"\bdear\b"#, with: "der", options: .regularExpression)
            .replacingOccurrences(of: #"\bdir\b"#, with: "der", options: .regularExpression)
            .replacingOccurrences(of: #"\bdare\b"#, with: "der", options: .regularExpression)
            .replacingOccurrences(of: #"\bdurr\b"#, with: "der", options: .regularExpression)
            .replacingOccurrences(of: #"\bdass\b"#, with: "das", options: .regularExpression)
            .replacingOccurrences(of: #"\bdaz\b"#, with: "das", options: .regularExpression)
            .replacingOccurrences(of: #"\bdee\b"#, with: "die", options: .regularExpression)
            .replacingOccurrences(of: #"[^\p{L}\s-]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Accepts answers like "der Sonne", "die Sonne.", speech-ish variants.
    static func parseAnswer(_ raw: String) -> (article: Article, word: String)? {
        let normalized = softenSpeech(raw)

        guard let match = normalized.range(of: #"\b(der|die|das)\b"#, options: .regularExpression) else {
            return nil
        }

        let articleRaw = String(normalized[match])
        guard let article = Article(rawValue: articleRaw) else { return nil }

        var remainder = normalized
        remainder.removeSubrange(match)
        let word = remainder
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        guard !word.isEmpty else { return nil }
        return (article, word)
    }

    /// Finds der/die/das even when spoken alone (no noun).
    static func parseSpokenArticle(_ raw: String) -> Article? {
        if let parsed = parseAnswer(raw) {
            return parsed.article
        }
        let normalized = softenSpeech(raw)
        if let alone = Article(rawValue: normalized) {
            return alone
        }
        guard let match = normalized.range(of: #"\b(der|die|das)\b"#, options: .regularExpression) else {
            return nil
        }
        return Article(rawValue: String(normalized[match]))
    }

    static func answersMatch(expected: ArticleWord, rawAnswer: String, mode: AnswerMode) -> Bool {
        switch mode {
        case .articleOnly:
            guard let article = parseSpokenArticle(rawAnswer) else { return false }
            return article == expected.article
        case .articleAndWord:
            guard let parsed = parseAnswer(rawAnswer) else { return false }
            return parsed.article == expected.article
                && normalize(parsed.word) == normalize(expected.word)
        }
    }

    static func heardSummary(rawAnswer: String, mode: AnswerMode) -> String {
        switch mode {
        case .articleOnly:
            if let article = parseSpokenArticle(rawAnswer) {
                return article.rawValue
            }
            return rawAnswer
        case .articleAndWord:
            if let parsed = parseAnswer(rawAnswer) {
                return "\(parsed.article.rawValue) \(parsed.word)"
            }
            return rawAnswer
        }
    }
}
