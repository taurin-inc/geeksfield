import Foundation

struct Size: Codable, Hashable, Sendable, CustomStringConvertible {
    let width: Int
    let height: Int

    var description: String { "\(width)x\(height)" }

    static let auto = Size(width: 0, height: 0)
    var isAuto: Bool { width == 0 && height == 0 }

    static func parse(_ raw: String) -> Size? {
        if raw == "auto" { return .auto }
        let parts = raw.split(separator: "x")
        guard parts.count == 2,
              let w = Int(parts[0]),
              let h = Int(parts[1]) else { return nil }
        return Size(width: w, height: h)
    }
}
