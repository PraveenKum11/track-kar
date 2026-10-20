import SwiftUI

/// The status item, driven by the live engine and the Menu Bar settings.
struct MenuBarLabel: View {
    let engine: TimerEngine
    let options: MenuBarOptions

    var body: some View {
        let entry = engine.activeEntry
        MenuBarLabelContent(
            content: .make(
                options: options,
                state: engine.state,
                elapsed: engine.elapsed,
                activityName: entry?.displayName,
                colorHex: entry?.colorHex,
                todayTotal: options.idleDisplay == .iconAndToday && engine.state == .idle ? engine.todayTotal() : 0,
                blinkOn: Int(engine.now.timeIntervalSinceReferenceDate) % 2 == 0
            ),
            fixedWidth: options.fixedWidth
        )
    }
}

/// Renders a `MenuBarContent`. Shared by the real status item and the Settings preview.
struct MenuBarLabelContent: View {
    let content: MenuBarContent
    let fixedWidth: Bool

    var body: some View {
        if content.isDimmed {
            Image(nsImage: dimmedImage)
        } else {
            HStack(spacing: 4) {
                if let colorHex = content.colorHex {
                    Image(nsImage: Self.dot(hex: colorHex))
                }
                if let symbolName = content.symbolName {
                    Image(systemName: symbolName)
                }
                if let text = content.text {
                    Text(text)
                        .monospacedDigit(fixedWidth)
                }
            }
        }
    }

    /// Status items draw labels as templates and ignore opacity, but a template image keeps its
    /// alpha, so the dimmed label is rendered into one at reduced alpha.
    private var dimmedImage: NSImage {
        let renderer = ImageRenderer(content:
            HStack(spacing: 4) {
                if let symbolName = content.symbolName {
                    Image(systemName: symbolName)
                }
                if let text = content.text {
                    Text(text)
                        .monospacedDigit(fixedWidth)
                }
            }
            .font(Font(NSFont.menuBarFont(ofSize: 0)))
            .foregroundStyle(.black.opacity(0.45))
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }

    /// Status items render SwiftUI shapes as monochrome templates, so the color dot is a
    /// non-template bitmap to keep its color. The label shows one image at most.
    private static func dot(hex: String) -> NSImage {
        let size = NSSize(width: 10, height: 10)
        let image = NSImage(size: size, flipped: false) { rect in
            (NSColor(hex: hex) ?? .gray).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}

private extension View {
    @ViewBuilder
    func monospacedDigit(_ enabled: Bool) -> some View {
        if enabled { monospacedDigit() } else { self }
    }
}
