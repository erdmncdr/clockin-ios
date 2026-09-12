import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) { precondition(condition, name); checks += 1; print("ok: \(name)") }

// Esikler Mac ile ayni olmali.
check(CompanionMode.auto.requiredHours == 0, "Auto is always available")
check(CompanionMode.typing.requiredHours == 0 && CompanionMode.coffee.requiredHours == 0,
      "Typing and Coffee need no hours")
check(CompanionMode.victory.requiredHours == 10 && CompanionMode.stretch.requiredHours == 25
      && CompanionMode.dance.requiredHours == 50 && CompanionMode.music.requiredHours == 100,
      "unlock thresholds are 10, 25, 50 and 100 hours")
check(CompanionMode.allCases.count == 7, "all seven Mac modes are offered")

// Kilitli secim Auto'ya duser. Simulatordeki arsivde her sey acik oldugu icin
// bu yol ekranda denenemiyordu.
check(CompanionMode.resolve("Music", totalHours: 99.9) == .auto, "a locked mode falls back to Auto")
check(CompanionMode.resolve("Music", totalHours: 100) == .music, "the threshold itself unlocks")
check(CompanionMode.resolve("Dance", totalHours: 60) == .dance, "an unlocked mode is kept")
check(CompanionMode.resolve("Victory", totalHours: 0) == .auto, "no work means no Victory")
check(CompanionMode.resolve("Coffee", totalHours: 0) == .coffee, "free modes work from zero")

// Taninmayan deger kirmaz.
check(CompanionMode.resolve("Disco", totalHours: 500) == .auto, "an unknown stored value falls back to Auto")
check(CompanionMode.resolve("", totalHours: 500) == .auto, "an empty stored value falls back to Auto")
check(CompanionMode.resolve("music", totalHours: 500) == .auto, "matching is exact, not case-insensitive")

// Etiketler.
check(CompanionMode.music.menuLabel(totalHours: 10) == "🔒 Music · 100h", "a locked label shows its threshold")
check(CompanionMode.music.menuLabel(totalHours: 100) == "Music", "an unlocked label is just the name")

// Poz eslesmesi: sabit modlar farkli gorseller almali.
let poses = CompanionMode.allCases.compactMap(\.fixedPoseIndex)
check(poses == [1, 2, 3, 4], "fixed poses are distinct and ordered")
check(CompanionMode.auto.fixedPoseIndex == nil && CompanionMode.typing.fixedPoseIndex == nil
      && CompanionMode.coffee.fixedPoseIndex == nil, "animated and automatic modes have no fixed pose")

// Kayitli ad ile okunan ad ayni olmali: iki taraf da bu ham degerleri kullaniyor.
check(CompanionMode.allCases.allSatisfy { CompanionMode(rawValue: $0.rawValue) == $0 },
      "every mode round-trips through its stored name")

print("\(checks) companion checks passed")
