import AppKit
import SwiftUI

extension NSColor {
    /// Parses `#RRGGBB`. Returns `nil` for malformed input.
    convenience init?(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var hexString: String? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        let channels = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
            .map { Int(($0 * 255).rounded()).clamped(to: 0...255) }
        return String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
    }
}

extension Color {
    /// Parses `#RRGGBB`. Falls back to gray for malformed input.
    init(hex: String) {
        if let color = NSColor(hex: hex) {
            self.init(nsColor: color)
        } else {
            self = .gray
        }
    }

    /// An activity or group color. Palette colors switch to their dark-mode step automatically.
    static func activity(_ hex: String) -> Color {
        guard let slot = ActivityPalette.slot(forHex: hex),
              let light = NSColor(hex: slot.light),
              let dark = NSColor(hex: slot.dark)
        else { return Color(hex: hex) }
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    var hexString: String? {
        NSColor(self).hexString
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
