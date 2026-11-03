import AppKit

enum PetKind: CaseIterable {
    case codex
    case cursor
    case agy
    case claude

    var title: String {
        switch self {
        case .codex:
            return "Codex(架构师)"
        case .cursor:
            return "Cursor(开发A)"
        case .agy:
            return "Gemini(开发B)"
        case .claude:
            return "Claude(休假中)"
        }
    }
}

/// 24×22 pixel pets. Working frames are a half-second typing loop.
/// Idle pets keep their hands down and blink for a quarter second every four seconds.
@MainActor
enum PixelSprites {
    static let width = 24
    static let height = 22
    static let gap = 2
    static let pixelScale = 2

    private static var images: [String: NSImage] = [:]

    static func cacheKey(working: [PetKind: Bool], tick: Int, reduceMotion: Bool) -> String {
        PetKind.allCases.map { kind in
            poseName(pose(working: working[kind] ?? false, tick: tick, reduceMotion: reduceMotion))
        }.joined(separator: "|")
    }

    static func image(working: [PetKind: Bool], tick: Int, reduceMotion: Bool) -> NSImage {
        let key = cacheKey(working: working, tick: tick, reduceMotion: reduceMotion)
        if let cached = images[key] {
            return cached
        }
        let image = draw(working: working, tick: tick, reduceMotion: reduceMotion)
        images[key] = image
        return image
    }

    private static func pose(working: Bool, tick: Int, reduceMotion: Bool) -> Pose {
        if working {
            return .working(frame: reduceMotion ? 0 : tick % 4)
        }
        if reduceMotion || tick % 32 >= 2 {
            return .idle
        }
        return .blink
    }

    private static func poseName(_ pose: Pose) -> String {
        switch pose {
        case .idle:
            return "idle"
        case .blink:
            return "blink"
        case .working(let frame):
            return "work\(frame)"
        }
    }

    private static func draw(working: [PetKind: Bool], tick: Int, reduceMotion: Bool) -> NSImage {
        let columns = PetKind.allCases.count
        let pointWidth = columns * width + (columns - 1) * gap
        let pointHeight = height
        let pixelsWide = pointWidth * pixelScale
        let pixelsHigh = pointHeight * pixelScale
        let pointSize = NSSize(width: pointWidth, height: pointHeight)
        // setColor(atX:y:) on an NSBitmapImageRep leaves the alpha byte at 0,
        // so the status item keeps its width and draws nothing.
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: pixelsWide,
                height: pixelsHigh,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return NSImage(size: pointSize)
        }
        context.interpolationQuality = .none

        for (index, kind) in PetKind.allCases.enumerated() {
            let petPose = pose(working: working[kind] ?? false, tick: tick, reduceMotion: reduceMotion)
            let originX = index * (width + gap)
            for (y, row) in rows(kind: kind, pose: petPose).enumerated() {
                for (x, pixel) in row.enumerated() {
                    guard let color = color(kind: kind, pixel: pixel) else { continue }
                    context.setFillColor(color.cgColor)
                    let pixelX = (originX + x) * pixelScale
                    let pixelY = (pointHeight - 1 - y) * pixelScale
                    context.fill(CGRect(x: pixelX, y: pixelY, width: pixelScale, height: pixelScale))
                }
            }
        }

        guard let cgImage = context.makeImage() else {
            return NSImage(size: pointSize)
        }
        let image = NSImage(size: pointSize)
        image.isTemplate = false
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = pointSize
        image.addRepresentation(rep)
        return image
    }

    private enum Pose {
        case idle
        case blink
        case working(frame: Int)
    }

    private static func rows(kind: PetKind, pose: Pose) -> [String] {
        let pack: (idle: [String], blink: [String], work: [[String]])
        switch kind {
        case .claude:
            pack = (claudeIdle, claudeBlink, claudeWork)
        case .codex:
            pack = (codexIdle, codexBlink, codexWork)
        case .cursor:
            pack = (cursorIdle, cursorBlink, cursorWork)
        case .agy:
            pack = (agyIdle, agyBlink, agyWork)
        }
        switch pose {
        case .idle:
            return pack.idle
        case .blink:
            return pack.blink
        case .working(let frame):
            return pack.work[frame % pack.work.count]
        }
    }

    private static func color(kind: PetKind, pixel: Character) -> NSColor? {
        if pixel == "." { return nil }
        let palette: [Character: NSColor]
        switch kind {
        case .claude:
            palette = claudeColors
        case .codex:
            palette = codexColors
        case .cursor:
            palette = cursorColors
        case .agy:
            palette = agyColors
        }
        return palette[pixel]
    }

    private static func rgb(_ red: Int, _ green: Int, _ blue: Int) -> NSColor {
        NSColor(
            srgbRed: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }

    private static let claudeColors: [Character: NSColor] = [
        "H": rgb(255, 250, 242),
        "o": rgb(255, 216, 178),
        "O": rgb(255, 166, 110),
        "S": rgb(198, 106, 70),
        "w": rgb(255, 255, 255),
        "E": rgb(64, 38, 28),
        "b": rgb(255, 146, 136),
        "m": rgb(168, 82, 66),
        "h": rgb(236, 156, 112),
        "p": rgb(255, 252, 246),
        "l": rgb(168, 124, 90),
        "f": rgb(226, 200, 170),
        "k": rgb(98, 64, 46),
        "K": rgb(244, 214, 176),
        "d": rgb(62, 40, 30),
    ]

    private static let codexColors: [Character: NSColor] = [
        "O": rgb(12, 18, 16),
        "D": rgb(6, 10, 8),
        "g": rgb(72, 255, 148),
        "G": rgb(14, 32, 24),
        "e": rgb(214, 255, 200),
        "w": rgb(255, 255, 255),
        "z": rgb(18, 70, 42),
        "c": rgb(8, 14, 12),
        "k": rgb(14, 26, 18),
        "s": rgb(226, 255, 170),
        "S": rgb(255, 255, 236),
    ]

    private static let cursorColors: [Character: NSColor] = [
        "o": rgb(148, 180, 255),
        "O": rgb(132, 140, 250),
        "D": rgb(190, 120, 255),
        "H": rgb(248, 250, 255),
        "n": rgb(34, 22, 70),
        "w": rgb(255, 255, 255),
        "E": rgb(28, 16, 58),
        "b": rgb(255, 168, 198),
        "m": rgb(42, 24, 82),
        "a": rgb(252, 252, 255),
        "N": rgb(22, 14, 46),
        "k": rgb(42, 30, 86),
        "y": rgb(255, 208, 84),
        "s": rgb(255, 236, 170),
    ]

    private static let claudeIdle: [String] = [
        "........................",
        "........................",
        "........................",
        "........................",
        ".....SSSSSSS............",
        "....SOOOOOOOS...........",
        "...SOHHooooOOS..........",
        "...SowEoowEoOS..pppppff.",
        "..SOoEEooEEoOS..ppppppf.",
        "..SOooooooooOO..pllllpp.",
        "...ObooooooObS..ppppppp.",
        "...SOOooooOOOS..pllllpp.",
        "....SOOmmmOOS...ppppppp.",
        ".....SOOOOSS....ppppppp.",
        "..hh...SSS...hh.ppppppp.",
        "..hh.........hh.........",
        "..KkKkKkKkKkKkKk........",
        "...dddddddddddd.........",
        "........................",
        "........................",
        "........................",
        "........................",
    ]

    private static let claudeBlink: [String] = [
        "........................",
        "........................",
        "........................",
        "........................",
        ".....SSSSSSS............",
        "....SOOOOOOOS...........",
        "...SOHHooooOOS..........",
        "...SoHooooooOS..pppppff.",
        "..SOoEEooEEoOS..ppppppf.",
        "..SOooooooooOO..pllllpp.",
        "...ObooooooObS..ppppppp.",
        "...SOOooooOOOS..pllllpp.",
        "....SOOmmmOOS...ppppppp.",
        ".....SOOOOSS....ppppppp.",
        "..hh...SSS...hh.ppppppp.",
        "..hh.........hh.........",
        "..KkKkKkKkKkKkKk........",
        "...dddddddddddd.........",
        "........................",
        "........................",
        "........................",
        "........................",
    ]

    private static let claudeWork: [[String]] = [
        [
            "........................",
            "........................",
            "........................",
            "........................",
            ".....SSSSSSS............",
            "....SOOOOOOOS...........",
            "...SOHHooooOOS..........",
            "...SowEoowEoOS..pppppff.",
            "..SOoEEooEEoOS..ppppppf.",
            "..SOooooooooOO..pllllpp.",
            "...ObooooooObS..ppppppp.",
            "...SOOooooOOOS..ppppppp.",
            "....SOOmmmOOS...ppppppp.",
            ".....SOOOOSS....ppppppp.",
            "..hh...SSS...hh.ppppppp.",
            "..hh.........hh.........",
            "..KkKkKkKkKkKkKk........",
            "...dddddddddddd.........",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
        [
            "........................",
            "........................",
            "........................",
            "........................",
            ".....SSSSSSS............",
            "....SOOOOOOOS...........",
            "...SOHHooooOOS..........",
            "...SowEoowEoOS..pppppff.",
            "..SOoEEooEEoOS..ppppppf.",
            "..SOooooooooOO..pllllpp.",
            "...ObooooooObS..ppppppp.",
            "...SOOooooOOOS..pllllpp.",
            ".hh.SOOmmmOOS...ppppppp.",
            ".hh..SOOOOSS....ppppppp.",
            ".......SSS...hh.ppppppp.",
            ".............hh.........",
            "..KkKkKkKkKkKkKk........",
            "...dddddddddddd.........",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
        [
            "........................",
            "........................",
            "........................",
            "........................",
            "........................",
            ".....SSSSSSS............",
            "....SOOOOOOOS...........",
            "...SOHHooooOOS..........",
            "...SowEoowEoOS..pppppff.",
            "..SOoEEooEEoOS..ppppppf.",
            "..SOooooooooOO..pllllpp.",
            "...ObooooooObS..ppppppp.",
            "...SOOooooOOOS..pllllpp.",
            "....SOOmmmOOS...ppppppp.",
            ".....SOOOOSS....pllllpp.",
            "..hh...SSS...hh.ppppppp.",
            "..hh.........hh.........",
            "..KkKkKkKkKkKkKk........",
            "...dddddddddddd.........",
            "........................",
            "........................",
            "........................",
        ],
        [
            "........................",
            "........................",
            "........................",
            "........................",
            ".....SSSSSSS............",
            "....SOOOOOOOS...........",
            "...SOHHooooOOS..........",
            "...SowEoowEoOS..pppppff.",
            "..SOoEEooEEoOS..ppppppf.",
            "..SOooooooooOO..pllllpp.",
            "...ObooooooObS..ppppppp.",
            "...SOOooooOOOS..pllllpp.",
            "....SOOmmmOOShh.ppppppp.",
            ".....SOOOOSS.hh.ppppppp.",
            "..hh...SSS......ppppppp.",
            "..hh....................",
            "..KkKkKkKkKkKkKk........",
            "...dddddddddddd.........",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
    ]

    private static let codexIdle: [String] = [
        "........................",
        "........................",
        "........................",
        "........................",
        "......gggg..............",
        "....ggOOOOgg............",
        "...ggeeOOOOOg...........",
        "...gOwGOOwGOgg..........",
        "...gOGGOOGGOOg..ggggggg.",
        "..ggOOOOOOOOOg..gcccccg.",
        "...gzOOOOOOOzg..gcgcccg.",
        "...gOOOOOOOOg...gccgccg.",
        "....gOOgggOgg...gcgcccg.",
        ".....ggOOggg....gcccccg.",
        "..ee...ggg...ee.gcgggcg.",
        "..ee.........ee.ggggggg.",
        "..gkgkgkgkgkgkgk........",
        "...DDDDDDDDDDDD.........",
        "........................",
        "........................",
        "........................",
        "........................",
    ]

    private static let codexBlink: [String] = [
        "........................",
        "........................",
        "........................",
        "........................",
        "......gggg..............",
        "....ggOOOOgg............",
        "...ggeeOOOOOg...........",
        "...gOeOOOOOOgg..........",
        "...gOGGOOGGOOg..ggggggg.",
        "..ggOOOOOOOOOg..gcccccg.",
        "...gzOOOOOOOzg..gcgcccg.",
        "...gOOOOOOOOg...gccgccg.",
        "....gOOgggOgg...gcgcccg.",
        ".....ggOOggg....gcccccg.",
        "..ee...ggg...ee.gcgggcg.",
        "..ee.........ee.ggggggg.",
        "..gkgkgkgkgkgkgk........",
        "...DDDDDDDDDDDD.........",
        "........................",
        "........................",
        "........................",
        "........................",
    ]

    private static let codexWork: [[String]] = [
        [
            "........................",
            "........................",
            "...................s....",
            "..................sSs...",
            "......gggg.........s....",
            "....ggOOOOgg............",
            "...ggeeOOOOOg...........",
            "...gOwGOOwGOgg..........",
            "...gOGGOOGGOOg..ggggggg.",
            "..ggOOOOOOOOOg..gcccccg.",
            "...gzOOOOOOOzg..gcgcccg.",
            "...gOOOOOOOOg...gccgccg.",
            "....gOOgggOgg...gcgcccg.",
            ".....ggOOggg....gcccccg.",
            "..ee...ggg...ee.gcgggcg.",
            "..ee.........ee.ggggggg.",
            "..gkgkgkgkgkgkgk........",
            "...DDDDDDDDDDDD.........",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
        [
            "........................",
            "........................",
            "........................",
            "....................s...",
            "......gggg.........sSs..",
            "....ggOOOOgg........s...",
            "...ggeeOOOOOg...........",
            "...gOwGOOwGOgg..........",
            "...gOGGOOGGOOg..ggggggg.",
            "..ggOOOOOOOOOg..gcccccg.",
            "...gzOOOOOOOzg..gcgcccg.",
            "...gOOOOOOOOg...gccgccg.",
            ".ee.gOOgggOgg...gcgcccg.",
            ".ee..ggOOggg....gcccccg.",
            ".......ggg...ee.gcgggcg.",
            ".............ee.ggggggg.",
            "..gkgkgkgkgkgkgk........",
            "...DDDDDDDDDDDD.........",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
        [
            "........................",
            "........................",
            "..................s.....",
            ".................sSs....",
            "..................s.....",
            "......gggg..............",
            "....ggOOOOgg............",
            "...ggeeOOOOOg...........",
            "...gOwGOOwGOgg..........",
            "...gOGGOOGGOOg..ggggggg.",
            "..ggOOOOOOOOOg..gcccccg.",
            "...gzOOOOOOOzg..gcgcccg.",
            "...gOOOOOOOOg...gccgccg.",
            "....gOOgggOgg...gcgcccg.",
            ".....ggOOggg....gcccccg.",
            "..ee...ggg...ee.gcgggcg.",
            "..ee.........ee.ggggggg.",
            "..gkgkgkgkgkgkgk........",
            "...DDDDDDDDDDDD.........",
            "........................",
            "........................",
            "........................",
        ],
        [
            "........................",
            "........................",
            "........................",
            ".....................s..",
            "......gggg..........sSs.",
            "....ggOOOOgg.........s..",
            "...ggeeOOOOOg...........",
            "...gOwGOOwGOgg..........",
            "...gOGGOOGGOOg..ggggggg.",
            "..ggOOOOOOOOOg..gcccccg.",
            "...gzOOOOOOOzg..gcgcccg.",
            "...gOOOOOOOOg...gccgccg.",
            "....gOOgggOggee.gcgcccg.",
            ".....ggOOggg.ee.gcccccg.",
            "..ee...ggg......gcgggcg.",
            "..ee............ggggggg.",
            "..gkgkgkgkgkgkgk........",
            "...DDDDDDDDDDDD.........",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
    ]

    private static let cursorIdle: [String] = [
        "........................",
        "........................",
        "........................",
        "................NNN.....",
        ".....nnnnnn.....NaNN....",
        "....noooooon....NaaNN...",
        "...noHHooooon...NaaaNN..",
        "..noowEoowEoOn..NaaaaN..",
        "..nooEEooEEOOn..NaNNaN..",
        "..noooooooOOOn..NaaNNN..",
        "..nobooooODbDn..NaNN....",
        "...nooooOODDn...NNN.....",
        "...nooommmDDn...........",
        "....nnOOOOnn............",
        "..aa..nnnn...aa.........",
        "..aa.........aa.........",
        "..akakakakakakak........",
        "...nnnnnnnnnnnn.........",
        "........................",
        "........................",
        "........................",
        "........................",
    ]

    private static let cursorBlink: [String] = [
        "........................",
        "........................",
        "........................",
        "................NNN.....",
        ".....nnnnnn.....NaNN....",
        "....noooooon....NaaNN...",
        "...noHHooooon...NaaaNN..",
        "..nooHooooooOn..NaaaaN..",
        "..nooEEooEEOOn..NaNNaN..",
        "..noooooooOOOn..NaaNNN..",
        "..nobooooODbDn..NaNN....",
        "...nooooOODDn...NNN.....",
        "...nooommmDDn...........",
        "....nnOOOOnn............",
        "..aa..nnnn...aa.........",
        "..aa.........aa.........",
        "..akakakakakakak........",
        "...nnnnnnnnnnnn.........",
        "........................",
        "........................",
        "........................",
        "........................",
    ]

    private static let cursorWork: [[String]] = [
        [
            "........................",
            "........................",
            "........................",
            "................NNN.....",
            ".....nnnnnn.....NaNN....",
            "....noooooon....NaaNN...",
            "...noHHooooon...NaaaNN..",
            "..noowEoowEoOn..NaaaaN..",
            "..nooEEooEEOOn..NaNNaN..",
            "..noooooooOOOn..NaaNNN..",
            "..nobooooODbDn..NaNN....",
            "...nooooOODDn...NNN.....",
            "...nooommmDDn...........",
            "....nnOOOOnn............",
            "..aa..nnnn...aa.........",
            "..aa.........aa.........",
            "..akakakakakakak........",
            "...nnnnnnnnnnnn.........",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
        [
            "........................",
            "........................",
            "...............y......y.",
            "................NNN..s..",
            ".....nnnnnn.....NaNN....",
            "....noooooon....NaaNN...",
            "...noHHooooon...NaaaNN..",
            "..noowEoowEoOn..NaaaaN..",
            "..nooEEooEEOOn..NaNNaN..",
            "..noooooooOOOn..NaaNNN..",
            "..nobooooODbDn..NaNN....",
            "...nooooOODDn...NNN.....",
            ".aanooommmDDn...........",
            ".aa.nnOOOOnn............",
            "......nnnn...aa.........",
            ".............aa.........",
            "..akakakakakakak........",
            "...nnnnnnnnnnnn.........",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
        [
            "........................",
            "........................",
            "........................",
            "........................",
            "................NNN.....",
            ".....nnnnnn.....NaNN....",
            "....noooooon....NaaNN...",
            "...noHHooooon...NaaaNN..",
            "..noowEoowEoOn..NaaaaN..",
            "..nooEEooEEOOn..NaNNaN..",
            "..noooooooOOOn..NaaNNN..",
            "..nobooooODbDn..NaNN....",
            "...nooooOODDn...NNN.....",
            "...nooommmDDn...........",
            "....nnOOOOnn............",
            "..aa..nnnn...aa.........",
            "..aa.........aa.........",
            "..akakakakakakak........",
            "...nnnnnnnnnnnn.........",
            "........................",
            "........................",
            "........................",
        ],
        [
            "........................",
            "........................",
            "...............y......y.",
            "................NNN..s..",
            ".....nnnnnn.....NaNN....",
            "....noooooon....NaaNN...",
            "...noHHooooon...NaaaNN..",
            "..noowEoowEoOn..NaaaaN..",
            "..nooEEooEEOOn..NaNNaN..",
            "..noooooooOOOn..NaaNNN..",
            "..nobooooODbDn..NaNN....",
            "...nooooOODDn...NNN.....",
            "...nooommmDDnaa.........",
            "....nnOOOOnn.aa.........",
            "..aa..nnnn..............",
            "..aa....................",
            "..akakakakakakak........",
            "...nnnnnnnnnnnn.........",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
    ]

    private static let agyColors: [Character: NSColor] = [
        "H": rgb(232, 252, 255),
        "o": rgb(64, 86, 168),
        "O": rgb(28, 36, 92),
        "r": rgb(72, 230, 226),
        "w": rgb(255, 255, 255),
        "E": rgb(12, 16, 42),
        "b": rgb(168, 120, 220),
        "m": rgb(96, 236, 220),
        "h": rgb(150, 236, 230),
        "k": rgb(24, 28, 64),
        "c": rgb(120, 245, 236),
        "n": rgb(12, 14, 36),
        "s": rgb(255, 236, 170),
        "S": rgb(255, 255, 240),
    ]

    private static let agyIdle: [String] = [
        "........................",
        "...................s....",
        "..................sSs...",
        "...................s....",
        "......rrrrr.............",
        "....rrOOOOOrr...........",
        "...rrHHoooOOr...........",
        "...rOwEoowEOOr..........",
        "...rOEEooEEoOr..........",
        "...rOoooooooOr...rrr....",
        "...rbooooooObr...rOr....",
        "...rOOoooooOOr...rrr....",
        "....rOOmmmOOr...........",
        ".....rrOOOrr............",
        "..hh..rrrr...hh.........",
        "..hh.........hh.........",
        "..ckckckckckckck........",
        "...nnnnnnnnnnnn.........",
        "........................",
        "........................",
        "........................",
        "........................",
    ]

    private static let agyBlink: [String] = [
        "........................",
        "...................s....",
        "..................sSs...",
        "...................s....",
        "......rrrrr.............",
        "....rrOOOOOrr...........",
        "...rrHHoooOOr...........",
        "...rOHoooooOOr..........",
        "...rOEEooEEoOr..........",
        "...rOoooooooOr...rrr....",
        "...rbooooooObr...rOr....",
        "...rOOoooooOOr...rrr....",
        "....rOOmmmOOr...........",
        ".....rrOOOrr............",
        "..hh..rrrr...hh.........",
        "..hh.........hh.........",
        "..ckckckckckckck........",
        "...nnnnnnnnnnnn.........",
        "........................",
        "........................",
        "........................",
        "........................",
    ]

    private static let agyWork: [[String]] = [
        [
            "...................s....",
            "..................sSs...",
            "...................s....",
            "........................",
            "......rrrrr.............",
            "....rrOOOOOrr...........",
            "...rrHHoooOOr...........",
            "...rOwEoowEOOr..........",
            "...rOEEooEEoOr..........",
            "...rOoooooooOr...rrr....",
            "...rbooooooObr...rOr....",
            "...rOOoooooOOr...rrr....",
            "....rOOmmmOOr...........",
            ".....rrOOOrr............",
            "..hh..rrrr...hh.........",
            "..hh.........hh.........",
            "..ckckckckckckck........",
            "...nnnnnnnnnnnn.........",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
        [
            "........................",
            "....................s...",
            "...................sSs..",
            "....................s...",
            "......rrrrr.............",
            "....rrOOOOOrr...........",
            "...rrHHoooOOr...........",
            "...rOwEoowEOOr..........",
            "...rOEEooEEoOr..........",
            "...rOoooooooOr...rrr....",
            "...rbooooooObr...rOr....",
            "...rOOoooooOOr...rrr....",
            ".hh.rOOmmmOOr...........",
            ".hh..rrOOOrr............",
            "......rrrr...hh.........",
            ".............hh.........",
            "..ckckckckckckck........",
            "...nnnnnnnnnnnn.........",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
        [
            "..................s.....",
            ".................sSs....",
            "..................s.....",
            "........................",
            "........................",
            "......rrrrr.............",
            "....rrOOOOOrr...........",
            "...rrHHoooOOr...........",
            "...rOwEoowEOOr..........",
            "...rOEEooEEoOr..........",
            "...rOoooooooOr...rrr....",
            "...rbooooooObr...rOr....",
            "...rOOoooooOOr...rrr....",
            "....rOOmmmOOr...........",
            ".....rrOOOrr............",
            "..hh..rrrr...hh.........",
            "..hh.........hh.........",
            "..ckckckckckckck........",
            "...nnnnnnnnnnnn.........",
            "........................",
            "........................",
            "........................",
        ],
        [
            "........................",
            ".....................s..",
            "....................sSs.",
            ".....................s..",
            "......rrrrr.............",
            "....rrOOOOOrr...........",
            "...rrHHoooOOr...........",
            "...rOwEoowEOOr..........",
            "...rOEEooEEoOr..........",
            "...rOoooooooOr...rrr....",
            "...rbooooooObr...rOr....",
            "...rOOoooooOOr...rrr....",
            "....rOOmmmOOrhh.........",
            ".....rrOOOrr.hh.........",
            "..hh..rrrr..............",
            "..hh....................",
            "..ckckckckckckck........",
            "...nnnnnnnnnnnn.........",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
    ]

}
