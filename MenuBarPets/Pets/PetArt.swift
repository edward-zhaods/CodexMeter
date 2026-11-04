import AppKit

enum PetPose: String, Sendable {
    case idle
    case working
}

@MainActor
enum PetArt {
    static let frameCount = 4

    private static var cache: [String: NSImage] = [:]

    static func menuIcon(_ kind: PetKind) -> NSImage? {
        load(
            key: "\(kind.rawValue)/menubar/icon",
            subdirectory: "Art/\(kind.rawValue)/menubar",
            name: "icon"
        )
    }

    static func frame(_ kind: PetKind, pose: PetPose, index: Int) -> NSImage? {
        let number = normalizedFrame(index) + 1
        let name = String(format: "frame_%02d", number)
        return load(
            key: "\(kind.rawValue)/\(pose.rawValue)/\(name)",
            subdirectory: "Art/\(kind.rawValue)/\(pose.rawValue)",
            name: name
        )
    }

    static func pose(for mood: PetMood) -> PetPose {
        mood == .working ? .working : .idle
    }

    static func normalizedFrame(_ index: Int) -> Int {
        let count = frameCount
        return ((index % count) + count) % count
    }

    static func statusBarImage(moods: [PetKind: PetMood], bob: Bool) -> NSImage {
        let height: CGFloat = 18
        let gap: CGFloat = 3
        let pets = PetKind.allCases
        let icons = pets.map { menuIcon($0) }
        let widths = icons.map { icon -> CGFloat in
            guard let icon else { return height }
            let pixelSize = icon.representations.first.map {
                NSSize(width: $0.pixelsWide, height: $0.pixelsHigh)
            } ?? icon.size
            guard pixelSize.height > 0 else { return height }
            return height * pixelSize.width / pixelSize.height
        }
        let width = widths.reduce(0, +) + gap * CGFloat(max(0, pets.count - 1))
        let canvasHeight = height + 2
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(1, Int((width * scale).rounded(.up))),
            pixelsHigh: max(1, Int((canvasHeight * scale).rounded(.up))),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: NSSize(width: width, height: canvasHeight))
        }
        rep.size = NSSize(width: width, height: canvasHeight)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .none
        var x: CGFloat = 0
        for (index, kind) in pets.enumerated() {
            let mood = moods[kind] ?? .idle
            let yOffset: CGFloat = bob && (mood == .working || mood == .vacation) ? 1 : 0
            let rect = NSRect(x: x, y: yOffset, width: widths[index], height: height)
            let fraction: CGFloat = mood == .offline ? 0.38 : 1
            icons[index]?.draw(in: rect, from: .zero, operation: .sourceOver, fraction: fraction)
            x += widths[index] + gap
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        image.isTemplate = false
        return image
    }

    private static func load(key: String, subdirectory: String, name: String) -> NSImage? {
        if let cached = cache[key] {
            return cached
        }
        let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: name, withExtension: "png")
        guard let url, let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = false
        cache[key] = image
        return image
    }
}
