import Foundation
import ImageIO

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
    print("ok: \(message)")
}

// Kok dizin, iOS dizini veya istege bagli Frames yolu kabul edilir.
let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let directory: URL
if CommandLine.arguments.count > 1 {
    directory = URL(fileURLWithPath: CommandLine.arguments[1])
} else if FileManager.default.fileExists(atPath: cwd.appendingPathComponent("iOS/Shared/Mascot/Frames").path) {
    directory = cwd.appendingPathComponent("iOS/Shared/Mascot/Frames")
} else {
    directory = cwd.appendingPathComponent("Shared/Mascot/Frames")
}
let names = Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
func numbers(_ prefix: String) -> Set<String> {
    Set(names.filter { $0.range(of: "^\(prefix)[0-9]{2}\\.png$", options: .regularExpression) != nil }
        .map { String($0.dropFirst().dropLast(4)) })
}
let expected: Set<String> = ["01", "02", "06", "07", "08", "10", "11"]
check(numbers("h") == expected, "hello frame numbers")
check(numbers("z") == numbers("h"), "tired frame numbers match hello")
check(numbers("p") == numbers("h"), "proud frame numbers match hello")
let accessories = ["acc-headphones.png", "acc-mug.png", "acc-cape.png", "acc-antenna.png"]
let outputs = ["z", "p"].flatMap { prefix in expected.sorted().map { prefix + $0 + ".png" } } + accessories
for name in outputs {
    check(names.contains(name), "\(name) exists")
    let url = directory.appendingPathComponent(name)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        check(false, "\(name) decodes")
        fatalError("Unreachable")
    }
    check(image.width == 314 && image.height == 314, "\(name) is 314x314")
    check([.first, .last, .premultipliedFirst, .premultipliedLast].contains(image.alphaInfo),
          "\(name) has alpha")
}
print("ok: all 18 mood and accessory frames")
