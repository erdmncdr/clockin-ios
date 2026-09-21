import Foundation
func check(_ b: @autoclosure () -> Bool, _ message: String) { precondition(b(), message) }
var checks = 0
for index in 0...20 {
    let start = max(1, index * 75)
    let end = (index + 1) * 75 - 1
    for level in [start, end] {
        let s = LevelPrestige(level: level)
        check(s.index == index, "rank boundary \(level)")
        check(s.nextUnlock == (index + 1) * 75, "next unlock")
        check(s.rankProgress >= 0 && s.rankProgress < 1, "rank progress")
        check(s.stage >= min(index, 8), "never return to beginner art")
        checks += 1
    }
}
check(LevelPrestige(level: 500).name == "Sovereign", "500 belongs to 450–524")
check(LevelPrestige(level: 500).nextUnlock == 525, "next rank at 525")
check(!LevelPrestige(level: 500).isMilestone, "no extra 500-level exception")
check(LevelPrestige(level: 450).isMilestone, "450 unlock burst")
check(LevelPrestige(level: 74).stage == 0 && LevelPrestige(level: 75).stage == 1, "first unlock")
check(LevelPrestige(level: 600).stage == 8 && LevelPrestige(level: 675).stage == 8, "retain apex structure")
check(LevelPrestige(level: -1).level == 1, "invalid level")
check(LevelPrestige.progress(xp: 499) == 0.998, "XP before reset")
check(LevelPrestige.progress(xp: 500) == 0, "XP reset")
check(LevelPrestige.progress(xp: -1) == 0, "invalid XP")
print("PASS: \(checks) rank boundaries, 500-level identity, no visual reset, XP unchanged")
