import Foundation
import Testing
@testable import YipYipCore

@Suite("SearchText")
struct SearchTextTests {
    @Test("Turkish letters fold to their ASCII counterparts", arguments: [
        ("inşallah", "insallah"),
        ("İstanbul", "istanbul"),
        ("ışık", "isik"),
        ("güneş", "gunes"),
        ("çöp", "cop"),
        ("yağmur", "yagmur"),
        ("ÇALIŞMA", "calisma"),
    ])
    func turkishFolding(input: String, expected: String) {
        #expect(SearchText.fold(input) == expected)
    }

    @Test("Folding is symmetric, so either spelling finds the other")
    func symmetry() {
        #expect(SearchText.fold("inşallah") == SearchText.fold("insallah"))
        #expect(SearchText.fold("İNŞALLAH") == SearchText.fold("insallah"))
        #expect(SearchText.fold("Işık") == SearchText.fold("isik"))
    }

    @Test("Capital I and dotless i land on the same letter")
    func dottedAndDotlessI() {
        // Under a Turkish locale these would diverge — the fold pins the locale.
        #expect(SearchText.fold("I") == "i")
        #expect(SearchText.fold("ı") == "i")
        #expect(SearchText.fold("İ") == "i")
        #expect(SearchText.fold("i") == "i")
    }

    @Test("Other European diacritics fold too", arguments: [
        ("café", "cafe"),
        ("Müller", "muller"),
        ("naïve", "naive"),
        ("Łódź", "lodz"),
    ])
    func europeanFolding(input: String, expected: String) {
        #expect(SearchText.fold(input) == expected)
    }

    @Test("Non-letters and spacing survive folding")
    func preservesStructure() {
        #expect(SearchText.fold("Ürün #42 · 15,90 ₺") == "urun #42 · 15,90 ₺")
        #expect(SearchText.fold("") == "")
    }
}
