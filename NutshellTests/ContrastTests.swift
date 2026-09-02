import Testing
import SwiftUI
@testable import Nutshell

/// The score palettes are fixed by the standards they come from, so the only lever the
/// app has is which foreground it puts on them. These assert that lever is pulled
/// correctly — that every badge in the app clears WCAG AA for large text.
@Suite("Badge contrast")
struct ContrastTests {

    /// WCAG AA for large / bold text. The badges are heavy rounded type at 15pt and up,
    /// which qualifies.
    private let minimumRatio = 3.0

    private func ratioOfChosenForeground(on background: UInt32) -> Double {
        let foreground: UInt32 = Color.prefersDarkForeground(on: background) ? Color.inkHex : 0xFFFFFF
        return Color.contrastRatio(background, foreground)
    }

    @Test("Every Nutri-Score tile is legible")
    func nutriScoreContrast() {
        for score in NutriScore.allCases {
            let ratio = ratioOfChosenForeground(on: score.hex)
            #expect(ratio >= minimumRatio, "Nutri-Score \(score.letter) contrast \(ratio)")
        }
    }

    @Test("Every NOVA tile is legible")
    func novaContrast() {
        for group in NovaGroup.allCases {
            let ratio = ratioOfChosenForeground(on: group.hex)
            #expect(ratio >= minimumRatio, "NOVA \(group.rawValue) contrast \(ratio)")
        }
    }

    @Test("Every Eco-Score tile is legible")
    func ecoScoreContrast() {
        for score in EcoScore.allCases {
            let ratio = ratioOfChosenForeground(on: score.hex)
            #expect(ratio >= minimumRatio, "Eco-Score \(score.letter) contrast \(ratio)")
        }
    }

    /// Regression: the bright grades were rendering white-on-yellow at roughly 1.6:1,
    /// which is effectively unreadable. They must resolve to dark text.
    @Test("The bright grades take dark text, not white")
    func brightGradesUseDarkText() {
        #expect(Color.prefersDarkForeground(on: NutriScore.c.hex))                 // 0xFECB02
        #expect(Color.prefersDarkForeground(on: NovaGroup.culinaryIngredient.hex)) // 0xFFCC00
        // The darkest grade keeps white, which is also the on-pack appearance.
        #expect(Color.prefersDarkForeground(on: NutriScore.a.hex) == false)
    }

    @Test("The chosen foreground is always the higher-contrast of the two")
    func alwaysPicksTheBetterForeground() {
        let backgrounds = NutriScore.allCases.map(\.hex)
            + NovaGroup.allCases.map(\.hex)
            + EcoScore.allCases.map(\.hex)

        for background in backgrounds {
            let white = Color.contrastRatio(background, 0xFFFFFF)
            let dark = Color.contrastRatio(background, Color.inkHex)
            let chosen = Color.prefersDarkForeground(on: background) ? dark : white
            #expect(chosen == max(white, dark), "background \(String(background, radix: 16))")
        }
    }

    @Test("The contrast maths matches known WCAG reference values")
    func contrastMathsIsCorrect() {
        // Black on white is the maximum possible ratio, 21:1.
        #expect(abs(Color.contrastRatio(0x000000, 0xFFFFFF) - 21) < 0.01)
        // A colour against itself is 1:1.
        #expect(abs(Color.contrastRatio(0x777777, 0x777777) - 1) < 0.001)
        // Order must not matter.
        #expect(Color.contrastRatio(0x038141, 0xFFFFFF) == Color.contrastRatio(0xFFFFFF, 0x038141))
    }
}
