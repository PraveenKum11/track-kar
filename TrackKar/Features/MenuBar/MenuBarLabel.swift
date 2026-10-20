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
                blinkOn: Int(engine.now.timeIntervalSinceReferenceDate) % 2 == 0,
                countdown: engine.countdown
            ),
            fixedWidth: options.fixedWidth
        )
    }
}

/// Renders a `MenuBarContent` as a single image. Shared by the real status item and the Settings preview.
///
/// Status items flatten SwiftUI labels: they ignore opacity, monospaced digits and colors, and
/// show one image at most. Drawing everything into one image keeps digits fixed-width (so the
/// item, and the popover anchored to it, don't shift as time changes), allows dimming, and
/// keeps the color dot's color.
struct MenuBarLabelContent: View {
    let content: MenuBarContent
    let fixedWidth: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(nsImage: rendered)
            .accessibilityLabel([content.text].compactMap { $0 }.joined())
    }

    private var rendered: NSImage {
        // Without a color dot the image is a template, so the system tints it to match the
        // menu bar. With one, it must keep its colors, so the text ink follows the appearance.
        let isTemplate = content.colorHex == nil
        let ink: Color = isTemplate || colorScheme == .light ? .black : .white
        let renderer = ImageRenderer(content: drawing(ink: ink))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = isTemplate
        return image
    }

    private func drawing(ink: Color) -> some View {
        HStack(spacing: 4) {
            if let colorHex = content.colorHex {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 9, height: 9)
            }
            if let symbolName = content.symbolName {
                Image(systemName: symbolName)
            }
            if let text = content.text {
                Text(text)
                    .monospacedDigit(fixedWidth)
            }
        }
        .font(Font(NSFont.menuBarFont(ofSize: 0)))
        .foregroundStyle(ink)
        .opacity(content.isDimmed ? 0.45 : 1)
        .fixedSize()
    }
}

private extension View {
    @ViewBuilder
    func monospacedDigit(_ enabled: Bool) -> some View {
        if enabled { monospacedDigit() } else { self }
    }
}
