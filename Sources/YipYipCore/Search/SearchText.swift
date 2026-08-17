import Foundation

/// Folds text into the form used for searching, so a query typed on any keyboard
/// finds the clip regardless of diacritics or case: "insallah" finds "inşallah",
/// "istanbul" finds "İSTANBUL", "gunes" finds "güneş".
public enum SearchText {
    /// Letters Unicode does not treat as accented forms of an ASCII letter, so
    /// diacritic folding alone would leave them untouched.
    private static let letterMap: [Character: Character] = [
        "ı": "i", "İ": "i",
        "ﬂ": "f", "ﬁ": "f",
        "ø": "o", "Ø": "o",
        "đ": "d", "Đ": "d",
        "ß": "s",
        "æ": "a", "Æ": "a",
        "œ": "o", "Œ": "o",
        "ł": "l", "Ł": "l",
    ]

    public static func fold(_ text: String) -> String {
        var mapped = ""
        mapped.reserveCapacity(text.count)
        for character in text {
            mapped.append(letterMap[character] ?? character)
        }

        // Folded in a fixed locale on purpose: under a Turkish locale "I" would
        // lowercase to "ı" and split the very matches this is meant to join.
        return mapped.folding(
            options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}
