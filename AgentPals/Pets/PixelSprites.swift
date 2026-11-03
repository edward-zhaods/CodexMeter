import AppKit

enum PetKind: CaseIterable {
    case claude
    case codex
    case cursor

    var title: String {
        switch self {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        case .cursor:
            return "Cursor"
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

    static func cacheKey(
        claudeWorking: Bool,
        codexWorking: Bool,
        cursorWorking: Bool,
        tick: Int,
        reduceMotion: Bool
    ) -> String {
        let flags: [PetKind: Bool] = [
            .claude: claudeWorking,
            .codex: codexWorking,
            .cursor: cursorWorking
        ]
        return PetKind.allCases.map { kind in
            poseName(pose(working: flags[kind] ?? false, tick: tick, reduceMotion: reduceMotion))
        }.joined(separator: "|")
    }

    static func image(
        claudeWorking: Bool,
        codexWorking: Bool,
        cursorWorking: Bool,
        tick: Int,
        reduceMotion: Bool
    ) -> NSImage {
        let key = cacheKey(
            claudeWorking: claudeWorking,
            codexWorking: codexWorking,
            cursorWorking: cursorWorking,
            tick: tick,
            reduceMotion: reduceMotion
        )
        if let cached = images[key] {
            return cached
        }
        let image = draw(
            claudeWorking: claudeWorking,
            codexWorking: codexWorking,
            cursorWorking: cursorWorking,
            tick: tick,
            reduceMotion: reduceMotion
        )
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

    private static func draw(
        claudeWorking: Bool,
        codexWorking: Bool,
        cursorWorking: Bool,
        tick: Int,
        reduceMotion: Bool
    ) -> NSImage {
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

        let flags: [PetKind: Bool] = [
            .claude: claudeWorking,
            .codex: codexWorking,
            .cursor: cursorWorking
        ]
        for (index, kind) in PetKind.allCases.enumerated() {
            let petPose = pose(working: flags[kind] ?? false, tick: tick, reduceMotion: reduceMotion)
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
        "o": rgb(255, 214, 168),
        "O": rgb(242, 154, 86),
        "D": rgb(214, 108, 52),
        "e": rgb(48, 30, 20),
        "h": rgb(112, 58, 30),
        "k": rgb(74, 52, 40),
        "w": rgb(255, 228, 186),
        "p": rgb(255, 246, 220),
        "l": rgb(150, 104, 58),
        "r": rgb(236, 214, 170)
    ]

    private static let codexColors: [Character: NSColor] = [
        "O": rgb(16, 20, 16),
        "D": rgb(6, 8, 6),
        "g": rgb(70, 255, 110),
        "e": rgb(186, 255, 150),
        "h": rgb(190, 255, 140),
        "k": rgb(20, 28, 20),
        "w": rgb(64, 110, 70),
        "c": rgb(8, 18, 12),
        "b": rgb(160, 255, 176),
        "s": rgb(240, 255, 180)
    ]

    private static let cursorColors: [Character: NSColor] = [
        "o": rgb(110, 146, 255),
        "O": rgb(58, 74, 226),
        "D": rgb(118, 64, 236),
        "P": rgb(176, 100, 255),
        "e": rgb(255, 255, 255),
        "h": rgb(255, 255, 255),
        "k": rgb(36, 28, 78),
        "w": rgb(196, 186, 255),
        "a": rgb(255, 255, 255),
        "m": rgb(255, 214, 96),
        "d": rgb(214, 224, 255),
        "n": rgb(36, 28, 78)
    ]

    private static let claudeIdle = [
        "........................",
        "........................",
        ".........OO.............",
        "......OOOOOOOO..........",
        ".....OOOOOOOOOO.........",
        "....OOooooOOOOOO........",
        "....OooooooDDDOOO.......",
        "....OoeeoooeeDDDO.......",
        "....OOeeooDeeDDDO.......",
        "....OOODDDDDDDDDppppppp.",
        "....OOOODDDDDDDDppppprr.",
        ".....OOODDDDDDDDppppppr.",
        "......OOODDDDDD.ppppppp.",
        "........OOOOO...ppppppp.",
        ".....hhh...hhh..ppppppp.",
        ".....hhh...hhh..ppppppp.",
        "....kkkkkkkkkkkkk.......",
        "....wkwkwkwkwkwkw.......",
        "....kkkkkkkkkkkkk.......",
        "........................",
        "........................",
        "........................"
    ]

    private static let claudeBlink = [
        "........................",
        "........................",
        ".........OO.............",
        "......OOOOOOOO..........",
        ".....OOOOOOOOOO.........",
        "....OOooooOOOOOO........",
        "....OooooooDDDOOO.......",
        "....OooooooDDDDDO.......",
        "....OOeeeoDeeeDDO.......",
        "....OOODDDDDDDDDppppppp.",
        "....OOOODDDDDDDDppppprr.",
        ".....OOODDDDDDDDppppppr.",
        "......OOODDDDDD.ppppppp.",
        "........OOOOO...ppppppp.",
        ".....hhh...hhh..ppppppp.",
        ".....hhh...hhh..ppppppp.",
        "....kkkkkkkkkkkkk.......",
        "....wkwkwkwkwkwkw.......",
        "....kkkkkkkkkkkkk.......",
        "........................",
        "........................",
        "........................"
    ]

    private static let claudeWork: [[String]] = [
        [
            "........................",
            "........................",
            ".........OO.............",
            "......OOOOOOOO..........",
            ".....OOOOOOOOOO.........",
            "....OOooooOOOOOO........",
            "....OooooooDDDOOO.......",
            "....OoeeoooeeDDDO.......",
            "....OOeeooDeeDDDO.......",
            "....OOODDDDDDDDDppppppp.",
            "....OOOODDDDDDDDppppprr.",
            ".....OOODDDDDDDDplllllr.",
            "......OOODDDDDD.ppppppp.",
            "........OOOOO...ppppppp.",
            ".....hhh...hhh..ppppppp.",
            ".....hhh...hhh..ppppppp.",
            "....kkkkkkkkkkkkk.......",
            "....wkwkwkwkwkwkw.......",
            "....kkkkkkkkkkkkk.......",
            "........................",
            "........................",
            "........................"
        ],
        [
            "........................",
            "........................",
            ".........OO.............",
            "......OOOOOOOO..........",
            ".....OOOOOOOOOO.........",
            "....OOooooOOOOOO........",
            "....OooooooDDDOOO.......",
            "....OoeeoooeeDDDO.......",
            "....OOeeooDeeDDDO.......",
            "....OOODDDDDDDDDppppppp.",
            "....OOOODDDDDDDDppppprr.",
            ".....OOODDDDDDDDplllllr.",
            ".....hhhODDDDDD.ppppppp.",
            ".....hhhOOOOO...plllllp.",
            "...........hhh..ppppppp.",
            "...........hhh..ppppppp.",
            "....kkkkkkkkkkkkk.......",
            "....wkwkwkwkwkwkw.......",
            "....kkkkkkkkkkkkk.......",
            "........................",
            "........................",
            "........................"
        ],
        [
            "........................",
            "........................",
            "........................",
            ".........OO.............",
            "......OOOOOOOO..........",
            ".....OOOOOOOOOO.........",
            "....OOooooOOOOOO........",
            "....OooooooDDDOOO.......",
            "....OoeeoooeeDDDO.......",
            "....OOeeooDeeDDDppppppp.",
            "....OOODDDDDDDDDppppprr.",
            "....OOOODDDDDDDDplllllr.",
            ".....OOODDDDDDDDppppppp.",
            "......OOODDDDDD.plllllp.",
            ".....hhhOOOhhh..plllllp.",
            ".....hhh...hhh..ppppppp.",
            "....kkkkkkkkkkkkk.......",
            "....wkkkkkkkkkkkw.......",
            "....kkkkkkkkkkkkk.......",
            "........................",
            "........................",
            "........................"
        ],
        [
            "........................",
            "........................",
            ".........OO.............",
            "......OOOOOOOO..........",
            ".....OOOOOOOOOO.........",
            "....OOooooOOOOOO........",
            "....OooooooDDDOOO.......",
            "....OoeeoooeeDDDO.......",
            "....OOeeooDeeDDDO.......",
            "....OOODDDDDDDDDppppppp.",
            "....OOOODDDDDDDDppppprr.",
            ".....OOODDDDDDDDplllllr.",
            "......OOODDhhhD.ppppppp.",
            "........OOOhhh..plllllp.",
            ".....hhh........ppppppp.",
            ".....hhh........ppppppp.",
            "....kkkkkkkkkkkkk.......",
            "....wkwkwkwkwkwkw.......",
            "....kkkkkkkkkkkkk.......",
            "........................",
            "........................",
            "........................"
        ]
    ]

    private static let codexIdle = [
        "........................",
        ".........ggg............",
        "........gOOOg...........",
        ".....gggggOgggg.........",
        "....gOOgOOOOOOggg.......",
        "....gOOOOOOOOgOOg.......",
        "....gOOOOOOOOggOg.......",
        "...ggOeeOODeeDOOg.......",
        "...ggOeeODDeeDDOg.......",
        "....gOOODDDDDDDDg.......",
        "....gOOODDDDDDDDg.......",
        ".....gOOODDDDDDg........",
        "......ggOOODDgg.cbcccbc.",
        ".......ggggggg..ccbcbcc.",
        ".....hhh...hhh..cbcccbc.",
        ".....hhh...hhh..ccccccc.",
        "....kkkkkkkkkkkkk.......",
        "....wkwkwkwkwkwkw.......",
        "....kkkkkkkkkkkkk.......",
        "........................",
        "........................",
        "........................"
    ]

    private static let codexBlink = [
        "........................",
        ".........ggg............",
        "........gOOOg...........",
        ".....gggggOgggg.........",
        "....gOOgOOOOOOggg.......",
        "....gOOOOOOOOgOOg.......",
        "....gOOOOOOOOggOg.......",
        "...ggOOOOODDDDOOg.......",
        "...ggOeeeDDeeeDOg.......",
        "....gOOODDDDDDDDg.......",
        "....gOOODDDDDDDDg.......",
        ".....gOOODDDDDDg........",
        "......ggOOODDgg.cbcccbc.",
        ".......ggggggg..ccbcbcc.",
        ".....hhh...hhh..cbcccbc.",
        ".....hhh...hhh..ccccccc.",
        "....kkkkkkkkkkkkk.......",
        "....wkwkwkwkwkwkw.......",
        "....kkkkkkkkkkkkk.......",
        "........................",
        "........................",
        "........................"
    ]

    private static let codexWork: [[String]] = [
        [
            "...................g....",
            ".........ggg......gsg...",
            "........gOOOg......g....",
            ".....gggggOgggg.........",
            "....gOOgOOOOOOggg.......",
            "....gOOOOOOOOgOOg.......",
            "....gOOOOOOOOggOg.......",
            "...ggOeeOODeeDOOg.......",
            "...ggOeeODDeeDDOg.......",
            "....gOOODDDDDDDDg.......",
            "....gOOODDDDDDDDg.......",
            ".....gOOODDDDDDg........",
            "......ggOOODDgg.cbcccbc.",
            ".......ggggggg..ccbcbcc.",
            ".....hhh...hhh..cbcccbc.",
            ".....hhh...hhh..ccccccc.",
            "....kkkkkkkkkkkkk.......",
            "....wkwkwkwkwkwkw.......",
            "....kkkkkkkkkkkkk.......",
            "........................",
            "........................",
            "........................"
        ],
        [
            "....................gsg.",
            ".........ggg.........g..",
            "........gOOOg...........",
            ".....gggggOgggg.........",
            "....gOOgOOOOOOggg.......",
            "....gOOOOOOOOgOOg.......",
            "....gOOOOOOOOggOg.......",
            "...ggOeeOODeeDOOg.......",
            "...ggOeeODDeeDDOg.......",
            "....gOOODDDDDDDDg.......",
            "....gOOODDDDDDDDg.......",
            ".....gOOODDDDDDg........",
            ".....hhhOOODDgg.cbcccbc.",
            ".....hhhgggggg..ccbcbcc.",
            "...........hhh..cbcccbc.",
            "...........hhh..ccccccc.",
            "....kkkkkkkkkkkkk.......",
            "....wkwkwkwkwkwkw.......",
            "....kkkkkkkkkkkkk.......",
            "........................",
            "........................",
            "........................"
        ],
        [
            "........................",
            "..................g.....",
            ".........ggg.....gsg....",
            "........gOOOg.....g.....",
            ".....gggggOgggg.........",
            "....gOOgOOOOOOggg.......",
            "....gOOOOOOOOgOOg.......",
            "....gOOOOOOOOggOg.......",
            "...ggOeeOODeeDOOg.......",
            "...ggOeeODDeeDDOg.......",
            "....gOOODDDDDDDDg.......",
            "....gOOODDDDDDDDg.......",
            ".....gOOODDDDDDgcbcccbc.",
            "......ggOOODDgg.ccbcbcc.",
            ".....hhhggghhh..cbcccbc.",
            ".....hhh...hhh..ccccccc.",
            "....kkkkkkkkkkkkk.......",
            "....wkkkkkkkkkkkw.......",
            "....kkkkkkkkkkkkk.......",
            "........................",
            "........................",
            "........................"
        ],
        [
            "......................g.",
            ".........ggg.........gsg",
            "........gOOOg.........g.",
            ".....gggggOgggg.........",
            "....gOOgOOOOOOggg.......",
            "....gOOOOOOOOgOOg.......",
            "....gOOOOOOOOggOg.......",
            "...ggOeeOODeeDOOg.......",
            "...ggOeeODDeeDDOg.......",
            "....gOOODDDDDDDDg.......",
            "....gOOODDDDDDDDg.......",
            ".....gOOODDDDDDg........",
            "......ggOOOhhhg.cbcccbc.",
            ".......gggghhh..ccbcbcc.",
            ".....hhh........cbcccbc.",
            ".....hhh........ccccccc.",
            "....kkkkkkkkkkkkk.......",
            "....wkwkwkwkwkwkw.......",
            "....kkkkkkkkkkkkk.......",
            "........................",
            "........................",
            "........................"
        ]
    ]

    private static let cursorIdle = [
        "........................",
        "........................",
        ".....d.dOdOO............",
        ".......OOOOOOO..........",
        "....OOOOOOOOOOO.........",
        "...OOOOooOOOOOPPP.......",
        "....OOooooOOOPPPP.......",
        "...OOoeeooPeePPPP.......",
        "...OOOeeoPPeePPPO.......",
        "...OOOPPPDDDDDDPP.......",
        "....OOPPDDDDDDDDP.......",
        "....OOOPDDDDDDDDP.......",
        ".....OOPPDDDDDDP...a....",
        ".......OOPPPPP.....aa...",
        ".....hhh...hhh.....aaa..",
        ".....hhh...hhh.....aaaa.",
        "....kkkkkkkkkkkkk..aaaa.",
        "....wkwkwkwkwkwkw..aann.",
        "....kkkkkkkkkkkkk...a...",
        "........................",
        "........................",
        "........................"
    ]

    private static let cursorBlink = [
        "........................",
        "........................",
        ".....d.dOdOO............",
        ".......OOOOOOO..........",
        "....OOOOOOOOOOO.........",
        "...OOOOooOOOOOPPP.......",
        "....OOooooOOOPPPP.......",
        "...OOoooooPPPPPPP.......",
        "...OOOeeePPeeePPO.......",
        "...OOOPPPDDDDDDPP.......",
        "....OOPPDDDDDDDDP.......",
        "....OOOPDDDDDDDDP.......",
        ".....OOPPDDDDDDP...a....",
        ".......OOPPPPP.....aa...",
        ".....hhh...hhh.....aaa..",
        ".....hhh...hhh.....aaaa.",
        "....kkkkkkkkkkkkk..aaaa.",
        "....wkwkwkwkwkwkw..aann.",
        "....kkkkkkkkkkkkk...a...",
        "........................",
        "........................",
        "........................"
    ]

    private static let cursorWork: [[String]] = [
        [
            "........................",
            "........................",
            ".....d.dOdOO............",
            ".......OOOOOOO..........",
            "....OOOOOOOOOOO.........",
            "...OOOOooOOOOOPPP.......",
            "....OOooooOOOPPPP.......",
            "...OOoeeooPeePPPP.......",
            "...OOOeeoPPeePPPO.......",
            "...OOOPPPDDDDDDPP.......",
            "....OOPPDDDDDDDDP.......",
            "....OOOPDDDDDDDDP.......",
            ".....OOPPDDDDDDP...a....",
            ".......OOPPPPP.....aa...",
            ".....hhh...hhh.....aaa..",
            ".....hhh...hhh.....aaaa.",
            "....kkkkkkkkkkkkk..aaaa.",
            "....wkwkwkwkwkwkw..aann.",
            "....kkkkkkkkkkkkk...a...",
            "........................",
            "........................",
            "........................"
        ],
        [
            "........................",
            "........................",
            ".....d.dOdOO............",
            ".......OOOOOOO..........",
            "....OOOOOOOOOOO.........",
            "...OOOOooOOOOOPPP.......",
            "....OOooooOOOPPPP.......",
            "...OOoeeooPeePPPP.......",
            "...OOOeeoPPeePPPO.......",
            "...OOOPPPDDDDDDPP.......",
            "....OOPPDDDDDDDDP....m..",
            "....OOOPDDDDDDDDP.....m.",
            ".....hhhPDDDDDDP...a...m",
            ".....hhhOPPPPP.....aa...",
            "...........hhh.....aaa..",
            "...........hhh.....aaaa.",
            "....kkkkkkkkkkkkk..aaaa.",
            "....wkwkwkwkwkwkw..aann.",
            "....kkkkkkkkkkkkk...a...",
            "........................",
            "........................",
            "........................"
        ],
        [
            "........................",
            "........................",
            ".....d.d.d..............",
            "........OOOO............",
            ".......OOOOOOO..........",
            "....OOOOOOOOOOO.........",
            "...OOOOooOOOOOPPP.......",
            "....OOooooOOOPPPP.......",
            "...OOoeeooPeePPPP.......",
            "...OOOeeoPPeePPPO.......",
            "...OOOPPPDDDDDDPP.......",
            "....OOPPDDDDDDDDP.......",
            "....OOOPDDDDDDDDP..a....",
            ".....OOPPDDDDDDP...aa...",
            ".....hhhOPPhhh.....aaa..",
            ".....hhh...hhh.....aaaa.",
            "....kkkkkkkkkkkkk..aaaa.",
            "....wkkkkkkkkkkkw..aann.",
            "....kkkkkkkkkkkkk...a...",
            "........................",
            "........................",
            "........................"
        ],
        [
            "........................",
            "........................",
            ".....d.dOdOO............",
            ".......OOOOOOO..........",
            "....OOOOOOOOOOO.........",
            "...OOOOooOOOOOPPP.......",
            "....OOooooOOOPPPP.......",
            "...OOoeeooPeePPPP.......",
            "...OOOeeoPPeePPPO.......",
            "...OOOPPPDDDDDDPP.......",
            "....OOPPDDDDDDDDP....m..",
            "....OOOPDDDDDDDDP.....m.",
            ".....OOPPDDhhhDP...a...m",
            ".......OOPPhhh.....aa...",
            ".....hhh...........aaa..",
            ".....hhh...........aaaa.",
            "....kkkkkkkkkkkkk..aaaa.",
            "....wkwkwkwkwkwkw..aann.",
            "....kkkkkkkkkkkkk...a...",
            "........................",
            "........................",
            "........................"
        ]
    ]
}
