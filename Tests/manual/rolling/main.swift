import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

func diff(_ old: String, _ new: String, _ oldValue: Double, _ newValue: Double) -> RollingNumberUpdate {
    RollingNumberUpdate(from: .init(text: old, value: oldValue), to: .init(text: new, value: newValue))
}

func changed(_ update: RollingNumberUpdate) -> [Int] {
    update.cells.filter(\.rolls).map(\.id)
}

let tick = diff("01:45:34", "01:45:35", 6334, 6335)
check(changed(tick) == [0], "only the changed seconds digit rolls")
check(tick.cells.map(\.id) == Array((0...7).reversed()), "identity counts positions from the right")
check(tick.cells.last?.previous == "4" && tick.cells.last?.character == "5", "old and new glyphs are retained")
check(tick.direction == .up && !tick.lengthChanged, "increasing timer rolls up")
check(tick.cells.filter { $0.character == ":" }.allSatisfy { !$0.rolls }, "timer separators stay static")

let carry = diff("09", "10", 9, 10)
check(changed(carry) == [1, 0] && carry.direction == .up, "09 to 10 carries both digits upward")
let minute = diff("00:59", "01:00", 59, 60)
check(changed(minute) == [3, 1, 0] && minute.direction == .up, "59 to 00 follows the increasing full timer")
check(diff("59", "00", 59, 60).direction == .up, "seconds-only carry uses semantic value")
let countdown = diff("01:00", "00:59", 60, 59)
check(changed(countdown) == [3, 1, 0] && countdown.direction == .down, "reverse minute carry rolls down")
check(diff("10", "09", 10, 9).direction == .down, "10 to 09 rolls down")
check(diff("00", "59", 60, 59).direction == .down, "seconds-only reverse carry uses semantic value")

let longer = diff("9:59", "10:00", 599, 600)
check(longer.lengthChanged && changed(longer).isEmpty, "timer length change is instant")
check(String(longer.cells.map(\.character)) == "10:00", "length fallback renders the complete new string")
check(longer.cells.last?.id == tick.cells.last?.id, "ones position stays zero after length change")
check(changed(diff("10:00", "9:59", 600, 599)).isEmpty, "shorter timer is instant")
check(changed(diff("$999.99", "$1,000.00", 999.99, 1000)).isEmpty, "new thousands separator is instant")
check(changed(diff("₺1.000,00", "₺999,99", 1000, 999.99)).isEmpty, "removed thousands separator is instant")

let prefix = diff("$43,99", "$44,00", 43.99, 44)
check(changed(prefix) == [3, 1, 0] && prefix.direction == .up, "prefix currency and decimal carry")
check(prefix.cells.first?.rolls == false, "prefix currency symbol is static")
let suffix = diff("43,99 $", "44,00 $", 43.99, 44)
check(changed(suffix) == [5, 3, 2], "suffix currency preserves right-based positions")
check(suffix.cells.suffix(2).allSatisfy { !$0.rolls }, "suffix currency and space stay static")
let turkish = diff("₺2.140,03", "₺2.140,04", 2140.03, 2140.04)
check(changed(turkish) == [0], "Turkish thousands and decimal separators are preserved")
check(String(turkish.cells.map(\.character)) == "₺2.140,04", "Turkish formatted text is not parsed or reformatted")
let turkishCarry = diff("2.199,99 ₺", "2.200,00 ₺", 2199.99, 2200)
check(changed(turkishCarry) == [7, 6, 5, 3, 2], "Turkish suffix thousands carry changes only digits")
check(diff("₺2.140,04", "₺2.140,03", 2140.04, 2140.03).direction == .down, "Turkish money decrement rolls down")
check(changed(diff("$12.34", "€12,35", 12.34, 12.35)) == [0], "changed symbol and separator update instantly")
check(changed(diff("1h 09m", "1h 10m", 4140, 4200)) == [2, 1], "letters and spaces remain static")
check(changed(diff("9 to go", "8 to go", 9, 8)) == [6], "remaining amount rolls independently of its suffix")
check(changed(diff("9", "x", 9, 10)).isEmpty, "digit becoming a letter does not roll")
check(changed(diff("x", "9", 8, 9)).isEmpty, "letter becoming a digit does not roll")
check(changed(diff("", "", 0, 0)).isEmpty, "empty strings are valid")
check(diff("", "1", 0, 1).lengthChanged, "initial nonempty value is instant")
check(changed(diff("1", "", 1, 0)).isEmpty, "clearing value is instant")
check(changed(diff("12.34", "12.34", 12.341, 12.342)).isEmpty, "unrounded changes do not animate unchanged text")
check(changed(diff("09", "10", 10, 10)).isEmpty, "equal semantic values do not roll")
check(RollDirection.between(-2, -1) == .up, "negative values compare numerically")
check(RollDirection.between(1, -1) == .down, "crossing zero downward compares numerically")
check(RollDirection.between(.nan, 1) == .none, "NaN disables rolling")
check(RollDirection.between(1, .infinity) == .none, "nonfinite new value disables rolling")

func allowed(reduce: Bool = false, lowPower: Bool = false,
             thermal: ProcessInfo.ThermalState = .nominal,
             content: Bool = true, scene: Bool = true, visible: Bool = true) -> Bool {
    rollingAnimationAllowed(reduceMotion: reduce, lowPower: lowPower, thermalState: thermal,
                            contentActive: content, sceneActive: scene, visible: visible)
}

check(allowed(), "visible active nominal state animates")
check(allowed(thermal: .fair), "fair thermal state animates")
check(!allowed(reduce: true), "Reduce Motion disables rolling")
check(!allowed(lowPower: true), "Low Power Mode disables rolling")
check(!allowed(thermal: .serious), "serious thermal state disables rolling")
check(!allowed(thermal: .critical), "critical thermal state disables rolling")
check(!allowed(content: false), "covered or deselected content disables rolling")
check(!allowed(scene: false), "inactive app disables rolling")
check(!allowed(visible: false), "disappeared view disables rolling")
for reduce in [false, true] {
    for lowPower in [false, true] {
        for thermal in [ProcessInfo.ThermalState.nominal, .fair, .serious, .critical] {
            for content in [false, true] {
                for scene in [false, true] {
                    for visible in [false, true] {
                        let expected = !reduce && !lowPower && (thermal == .nominal || thermal == .fair)
                            && content && scene && visible
                        check(allowed(reduce: reduce, lowPower: lowPower, thermal: thermal,
                                      content: content, scene: scene, visible: visible) == expected,
                              "policy combination \(reduce)/\(lowPower)/\(thermal.rawValue)/\(content)/\(scene)/\(visible)")
                    }
                }
            }
        }
    }
}
print("\(checks) rolling checks passed")
