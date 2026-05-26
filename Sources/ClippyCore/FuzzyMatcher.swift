import Foundation

public struct FuzzyMatchResult: Equatable, Sendable {
    public var matched: Bool
    public var score: Int

    public init(matched: Bool, score: Int) {
        self.matched = matched
        self.score = score
    }
}

public enum FuzzyMatcher {
    public static func match(query: String, candidate: String) -> FuzzyMatchResult {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanedCandidate = candidate.lowercased()

        guard !cleanedQuery.isEmpty else {
            return FuzzyMatchResult(matched: true, score: 1)
        }

        if cleanedCandidate.contains(cleanedQuery) {
            return FuzzyMatchResult(matched: true, score: 1_000 + cleanedQuery.count * 8)
        }

        var score = 0
        var searchStart = cleanedCandidate.startIndex
        var previousMatch: String.Index?

        for character in cleanedQuery {
            guard let matchIndex = cleanedCandidate[searchStart...].firstIndex(of: character) else {
                return FuzzyMatchResult(matched: false, score: 0)
            }

            score += 12
            if let previousMatch, cleanedCandidate.index(after: previousMatch) == matchIndex {
                score += 8
            }
            if matchIndex == cleanedCandidate.startIndex || cleanedCandidate[cleanedCandidate.index(before: matchIndex)].isWhitespace {
                score += 5
            }

            previousMatch = matchIndex
            searchStart = cleanedCandidate.index(after: matchIndex)
        }

        return FuzzyMatchResult(matched: true, score: score)
    }
}
