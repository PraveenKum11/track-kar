import SwiftUI

/// The status item, driven by the live engine and the Menu Bar settings.
struct MenuBarLabel: View {
    let engine: TimerEngine
    let options: MenuBarOptions
    let widthLock: StatusItemWidthLock

    var body: some View {
        MenuBarLabelContent(
            content: Self.content(engine: engine, options: options),
            fixedWidth: options.fixedWidth,
            minimumWidth: widthLock.isPopoverOpen ? widthLock.minimumWidth : 0,
            onRender: { widthLock.accommodate($0) }
        )
    }

    static func content(engine: TimerEngine, options: MenuBarOptions) -> MenuBarContent {
        let entry = engine.activeEntry
        return .make(
            options: options,
            state: engine.state,
            elapsed: engine.elapsed,
            activityName: entry?.displayName,
            colorHex: entry?.colorHex,
            todayTotal: options.idleDisplay == .iconAndToday && engine.state == .idle ? engine.todayTotal() : 0,
            blinkOn: Int(engine.now.timeIntervalSinceReferenceDate) % 2 == 0,
            countdown: engine.countdown
        )
    }

    /// The item's current width, kept as a minimum while the popover is open.
    static func currentWidth(engine: TimerEngine, options: MenuBarOptions) -> CGFloat {
        MenuBarLabelContent.render(content(engine: engine, options: options), fixedWidth: options.fixedWidth, colorScheme: .dark)
            .size.width
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
    /// Pads the image (centered) to at least this width.
    var minimumWidth: CGFloat = 0
    /// Reports the unpadded width after rendering.
    var onRender: ((CGFloat) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let image = Self.render(content, fixedWidth: fixedWidth, colorScheme: colorScheme)
        if let onRender {
            let width = image.size.width
            // Report after this render pass; state can't change during one.
            DispatchQueue.main.async { onRender(width) }
        }
        return Image(nsImage: Self.padded(image, toWidth: minimumWidth))
            .accessibilityLabel(content.text.map { "Track Kar, \($0)" } ?? "Track Kar")
    }

    static func render(_ content: MenuBarContent, fixedWidth: Bool, colorScheme: ColorScheme) -> NSImage {
        // Without a color dot the image is a template, so the system tints it to match the
        // menu bar. With one, it must keep its colors, so the text ink follows the appearance.
        let isTemplate = content.colorHex == nil
        let ink: Color = isTemplate || colorScheme == .light ? .black : .white
        let renderer = ImageRenderer(content: drawing(content, fixedWidth: fixedWidth, ink: ink))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = isTemplate
        return image
    }

    private static func padded(_ image: NSImage, toWidth width: CGFloat) -> NSImage {
        guard width > image.size.width else { return image }
        let size = NSSize(width: width, height: image.size.height)
        let padded = NSImage(size: size, flipped: false) { _ in
            image.draw(at: NSPoint(x: ((width - image.size.width) / 2).rounded(), y: 0), from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        padded.isTemplate = image.isTemplate
        return padded
    }

    private static func drawing(_ content: MenuBarContent, fixedWidth: Bool, ink: Color) -> some View {
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
