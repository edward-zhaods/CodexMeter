import AppKit

enum PetPose: Sendable {
    case idle
    case working
}

/// Hand-drawn menu-bar pets. Each frame is a few flat colors, not a scaled photo.
@MainActor
enum PetPixels {
    static let frameCount = 4

    private static var cache: [String: NSImage] = [:]

    private static let colors: [Character: UInt32] = [
        "x": 0x1A1224,
        "G": 0x3DDC78,
        "g": 0x128240,
        "d": 0x182030,
        "e": 0xC6FF46,
        "w": 0xFFF8EE,
        "y": 0xFFD030,
        "z": 0xC48010,
        "P": 0x9A68F6,
        "p": 0xD6C6FF,
        "m": 0xFFF6FF,
        "u": 0x5430A4,
        "B": 0x4AA8FF,
        "b": 0x1866D2,
        "n": 0xE8F6FF,
        "a": 0xFF9C4A,
        "A": 0xD66226,
        "s": 0x201A16,
        "c": 0xF4D8A8,
        "h": 0xB87E3C,
        "l": 0x30384E,
        "t": 0x7EECFF,
        "k": 0x182438,
        "r": 0xFF668C,
        "q": 0xFFE256,
        "i": 0xFFFFFF,
    ]

    private static let codexIdle: [[String]] = [
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xGGx.xxxx.xGGx.....",
            ".....xGGxxGGGGxxGGx.....",
            "......xxGGGGGGGGxx......",
            "......xGGGGGGGGGGx......",
            ".....xGGddddddddGGx.....",
            ".....xGGdeeddeedGGx.....",
            ".....xGGdeeddeedGGx.....",
            ".....xGGddddddddGGx.....",
            ".....xGGGGGGGGGGGGx.....",
            "......xGGGGGGGGGGx......",
            ".......xGGzyyGGGx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.gg.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xGGx.xxxx.xGGx.....",
            ".....xGGxxGGGGxxGGx.....",
            "......xxGGGGGGGGxx......",
            "......xGGGGGGGGGGx......",
            ".....xGGddddddddGGx.....",
            ".....xGGdeeddeedGGx.....",
            ".....xGGdeeddeedGGx.....",
            ".....xGGddddddddGGx.....",
            ".....xGGGGGGGGGGGGx.....",
            "......xGGGGGGGGGGx......",
            ".......xGGzyyGGGx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.gg.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xGGx.xxxx.xGGx.....",
            ".....xGGxxGGGGxxGGx.....",
            "......xxGGGGGGGGxx......",
            "......xGGGGGGGGGGx......",
            ".....xGGddddddddGGx.....",
            ".....xGGdeeddeedGGx.....",
            ".....xGGdeeddeedGGx.....",
            ".....xGGddddddddGGx.....",
            ".....xGGGGGGGGGGGGx.....",
            "......xGGGGGGGGGGx......",
            ".......xGGzyyGGGx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.gg.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xGGx.xxxx.xGGx.....",
            ".....xGGxxGGGGxxGGx.....",
            "......xxGGGGGGGGxx......",
            "......xGGGGGGGGGGx......",
            ".....xGGddddddddGGx.....",
            ".....xGGdeeddeedGGx.....",
            ".....xGGdeeddeedGGx.....",
            ".....xGGddddddddGGx.....",
            ".....xGGGGGGGGGGGGx.....",
            "......xGGGGGGGGGGx......",
            ".......xGGzyyGGGx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.gg.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
    ]

    private static let codexWork: [[String]] = [
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xGGx.xxxx.xGGx.....",
            ".....xGGxxGGGGxxGGx.....",
            "......xxGGGGGGGGxx......",
            "......xGGGGGGGGGGx......",
            ".....xGGddddddddGGx.....",
            ".....xGGdeeddeedGGx.....",
            ".....xGGdeeddeedGGx.....",
            ".....xGGddddddddGGx.....",
            ".....xGGGGGGGGGGGGx.....",
            "......xGGGGGGGGGGx......",
            ".......xGGzyyGGGx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.gg.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xGGx.xxxx.xGGx.....",
            ".....xGGxxGGGGxxGGx.....",
            "......xxGGGGGGGGxx......",
            "......xGGGGGGGGGGx......",
            ".....xGGeeedddddGGx.....",
            ".....xGGeeeddeedGGx.....",
            ".....xGGeeeddeedGGx.....",
            ".....xGGddddddddGGx.....",
            ".....xGGGGGGGGGGGGx.....",
            "......xGGGGGGGGGGx......",
            ".......xGGzyyGGGx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.gg.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xGGx.xxxx.xGGx.....",
            ".....xGGxxGGGGxxGGx.....",
            "......xxGGGGGGGGxx......",
            "......xGGGGGGGGGGx......",
            ".....xGGddddddddGGx.....",
            ".....xGGddddddddGGx.....",
            ".....xGGddddddddGGx.....",
            ".....xGGddddddddGGx.....",
            ".....xGGGGGGGGGGGGx.....",
            "......xGGGGGGGGGGx......",
            ".......xGGzyyGGGx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.gg.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xGGx.xxxx.xGGx.....",
            ".....xGGxxGGGGxxGGx.....",
            "......xxGGGGGGGGxx......",
            "......xGGGGGGGGGGx......",
            ".....xGGddddddeeeGx.....",
            ".....xGGdeeddeeeeGx.....",
            ".....xGGdeeddeeeeGx.....",
            ".....xGGddddddddGGx.....",
            ".....xGGGGGGGGGGGGx.....",
            "......xGGGGGGGGGGx......",
            ".......xGGzyyGGGx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.gg.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
    ]

    private static let cursorIdle: [[String]] = [
        [
            "........................",
            "....xx............xx....",
            "...xPPx..........xPPx...",
            "...xPPp..........pPPx...",
            "...xPPx..........xPPx...",
            "....xPPxx......xxPPx....",
            ".....xPPPPPPPPPPPPx.....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPuiiiiuiiiiPPx....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPxx......xxPPx....",
            ".....xPPmmmmmmmmPPx.....",
            "......xPmmmmmmmmPx......",
            ".......xxmmrrmmxx.......",
            ".........xxrrxx.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
        [
            "........................",
            "....xx............xx....",
            "...xPPx..........xPPx...",
            "...xPPp..........pPPx...",
            "...xPPx..........xPPx...",
            "....xPPxx......xxPPx....",
            ".....xPPPPPPPPPPPPx.....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPuiiiiuiiiiPPx....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPxx......xxPPx....",
            ".....xPPmmmmmmmmPPx.....",
            "......xPmmmmmmmmPx......",
            ".......xxmmrrmmxx.......",
            ".........xxrrxx.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
        [
            "........................",
            "....xx............xx....",
            "...xPPx..........xPPx...",
            "...xPPp..........pPPx...",
            "...xPPx..........xPPx...",
            "....xPPxx......xxPPx....",
            ".....xPPPPPPPPPPPPx.....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPuiiiiuiiiiPPx....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPxx......xxPPx....",
            ".....xPPmmmmmmmmPPx.....",
            "......xPmmmmmmmmPx......",
            ".......xxmmrrmmxx.......",
            ".........xxrrxx.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
        [
            "........................",
            "....xx............xx....",
            "...xPPx..........xPPx...",
            "...xPPp..........pPPx...",
            "...xPPx..........xPPx...",
            "....xPPxx......xxPPx....",
            ".....xPPPPPPPPPPPPx.....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPuiiiiuiiiiPPx....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPxx......xxPPx....",
            ".....xPPmmmmmmmmPPx.....",
            "......xPmmmmmmmmPx......",
            ".......xxmmrrmmxx.......",
            ".........xxrrxx.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
    ]

    private static let cursorWork: [[String]] = [
        [
            "........................",
            "....xx............xx....",
            "...xPPx..........xPPx...",
            "...xPPp..........pPPx...",
            "...xPPx..........xPPx...",
            "....xPPxx......xxPPx....",
            ".....xPPPPPPPPPPPPx.....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPuiiiiuiiiiPPx....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPxx......xxPPx....",
            ".....xPPmmmmmmmmPPx.....",
            "......xPmmmmmmmmPx......",
            ".......xxmmrrmmxx.......",
            ".........xxrrxx.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
        [
            "........................",
            "........................",
            "........................",
            "....xx............xx....",
            "...xPPx..........xPPx...",
            "...xPPp.x......x.pPPx...",
            "...xPPxPPPPPPPPPPxPPx...",
            "....xPPxuuuuuuuuxPPx....",
            "....xPPuiiiiuiiiiPPx....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPxx......xxPPx....",
            ".....xPPmmmmmmmmPPx.....",
            "......xPmmmmmmmmPx......",
            ".......xmmmrrrmxx.......",
            ".........xrrrrx.........",
            "..........xrrx..........",
            "..........xxxx..........",
            "........................",
        ],
        [
            "........................",
            "....xx............xx....",
            "...xPPx..........xPPx...",
            "...xPPp..........pPPx...",
            "...xPPx..........xPPx...",
            "....xPPxx......xxPPx....",
            ".....xPPPPPPPPPPPPx.....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPxx......xxPPx....",
            ".....xPPmmmmmmmmPPx.....",
            "......xPmmmmmmmmPx......",
            ".......xxmmrrmmxx.......",
            ".........xxrrxx.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
        [
            "........................",
            "....xx..................",
            "...xPPx.................",
            "...xPPp...........xx....",
            "...xPPx..........xPPx...",
            "....xPPxx......x.pPPx...",
            ".....xPPPPPPPPPPPxPPx...",
            "....xPPuuuuuuuuuxPPx....",
            "....xPPuiiiiuiiiiPPx....",
            "....xPPuuuuuuuuuuPPx....",
            "....xPPxx......xxPPx....",
            ".....xPPmmmmmmmmPPx.....",
            "......xPmmmmmmmmPx......",
            "........xmmmrrrmx.......",
            "..........xrrrrx........",
            "...........xrrx.........",
            "...........xxxx.........",
            "........................",
        ],
    ]

    private static let geminiIdle: [[String]] = [
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xBBx.xxxx.xBBx.....",
            ".....xBBxxBBBBxxBBx.....",
            "......xxBBBBBBBBxx......",
            "......xBBBBBBBBBBx......",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBxndxnBdBBBx.....",
            ".....xBBxnBxnBxBBBx.....",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBBBBBBBBBBBx.....",
            "......xBBBBBBBBBBx......",
            ".......xBBzyyBBBx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.bb.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xBBx.xxxx.xBBx.....",
            ".....xBBxxBBBBxxBBx.....",
            "......xxBBBBBBBBxx......",
            "......xBBBBBBBBBBx......",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBxndxnBdBBBx.....",
            ".....xBBxnBxnBxBBBx.....",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBBBBBBBBBBBx.....",
            "......xBBBBBBBBBBx......",
            ".......xBBzyyBBBx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.bb.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xBBx.xxxx.xBBx.....",
            ".....xBBxxBBBBxxBBx.....",
            "......xxBBBBBBBBxx......",
            "......xBBBBBBBBBBx......",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBxndxnBdBBBx.....",
            ".....xBBxnBxnBxBBBx.....",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBBBBBBBBBBBx.....",
            "......xBBBBBBBBBBx......",
            ".......xBBzyyBBBx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.bb.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xBBx.xxxx.xBBx.....",
            ".....xBBxxBBBBxxBBx.....",
            "......xxBBBBBBBBxx......",
            "......xBBBBBBBBBBx......",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBxndxnBdBBBx.....",
            ".....xBBxnBxnBxBBBx.....",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBBBBBBBBBBBx.....",
            "......xBBBBBBBBBBx......",
            ".......xBBzyyBBBx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.bb.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
    ]

    private static let geminiWork: [[String]] = [
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xBBx.xxxx.xBBx.....",
            ".....xBBxxBBBBxxBBx.....",
            "......xxBBBBBBBBxx......",
            "......xBBBBBBBBBBx......",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBxndxnBdBBBx.....",
            ".....xBBxnBxnBxBBBx.....",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBBBBBBBBBBBx.....",
            "......xBBBBBBBBBBx......",
            ".......xBBzyyBBBx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.bb.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xBBx.xxxx.xBBx.....",
            ".....xBBxxBBBBxxBBx.....",
            "......xxBBBBBBBBxx......",
            "......xBBBBBBBBBBx......",
            ".....xBBxndxnBdBBBx.....",
            ".....xBBxnBxnBxBBBx.....",
            ".....xBBBBBBBBBBBBx.....",
            ".....xBBBBBBBBBBBBx.....",
            ".....xBBBBBBBBBBBBx.....",
            "......xBBBBBBBBBBx......",
            ".......xBBzyyBBBx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.bb.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xBBx.xxxx.xBBx.....",
            ".....xBBxxBBBBxxBBx.....",
            "......xxBBBBBBBBxx......",
            "......xBBBBBBBBBBx......",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBxnnnnndBBBx.....",
            ".....xBBxnnnnnxBBBx.....",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBBBBBBBBBBBx.....",
            "......xBBBBBBBBBBx......",
            ".......xBBzyyBBBx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.bb.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xBBx.xxxx.xBBx.....",
            ".....xBBxxBBBBxxBBx.....",
            "......xxBBBBBBBBxx......",
            "......xBBBBBBBBBBx......",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBxddxnBdBBBx.....",
            ".....xBBBBBxnBxBBBx.....",
            ".....xBBBxxBxxBBBBx.....",
            ".....xBBBBBBBBBBBBx.....",
            "......xBBBBBBBBBBx......",
            ".......xBBzyyBBBx.......",
            "......xwwxxyyxxwwx......",
            "......xwwx.bb.xwwx......",
            ".......xx......xx.......",
            "........................",
            "........................",
        ],
    ]

    private static let claudeIdle: [[String]] = [
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xaaxxxxxxxxaax.....",
            ".....xaaxaaaaaaxaax.....",
            "......xaaaaaaaaaax......",
            ".....xaaaaaaaaaaaax.....",
            ".....xassssssssssax.....",
            "....xaasiassssaisaax....",
            "....xaassssssssssaax....",
            ".....xaaaaaaaaaaaax.....",
            ".....xaaraaaaaaraax.....",
            "......xaaccccccaax......",
            ".......xaaccccaax.......",
            ".......xxxxaaxxxx.......",
            "......xwwx.xx.xwwx......",
            "......xwwx....xwwx......",
            ".......xx......xx.......",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xaaxxxxxxxxaax.....",
            ".....xaaxaaaaaaxaax.....",
            "......xaaaaaaaaaax......",
            ".....xaaaaaaaaaaaax.....",
            ".....xassssssssssax.....",
            "....xaasiassssaisaax....",
            "....xaassssssssssaax....",
            ".....xaaaaaaaaaaaax.....",
            ".....xaaraaaaaaraax.....",
            "......xaaccccccaax......",
            ".......xaaccccaax.......",
            ".......xxxxaaxxxx.......",
            "......xwwx.xx.xwwx......",
            "......xwwx....xwwx......",
            ".......xx......xx.......",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xaaxxxxxxxxaax.....",
            ".....xaaxaaaaaaxaax.....",
            "......xaaaaaaaaaax......",
            ".....xaaaaaaaaaaaax.....",
            ".....xassssssssssax.....",
            "....xaasiassssaisaax....",
            "....xaassssssssssaax....",
            ".....xaaaaaaaaaaaax.....",
            ".....xaaraaaaaaraax.....",
            "......xaaccccccaax......",
            ".......xaaccccaax.......",
            ".......xxxxaaxxxx.......",
            "......xwwx.xx.xwwx......",
            "......xwwx....xwwx......",
            ".......xx......xx.......",
            "........................",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xaaxxxxxxxxaax.....",
            ".....xaaxaaaaaaxaax.....",
            "......xaaaaaaaaaax......",
            ".....xaaaaaaaaaaaax.....",
            ".....xassssssssssax.....",
            "....xaasiassssaisaax....",
            "....xaassssssssssaax....",
            ".....xaaaaaaaaaaaax.....",
            ".....xaaraaaaaaraax.....",
            "......xaaccccccaax......",
            ".......xaaccccaax.......",
            ".......xxxxaaxxxx.......",
            "......xwwx.xx.xwwx......",
            "......xwwx....xwwx......",
            ".......xx......xx.......",
            "........................",
        ],
    ]

    private static let claudeWork: [[String]] = [
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xaaxxxxxxxxaax.....",
            ".....xaaxaaaaaaxaax.....",
            "......xaaaaaaaaaax......",
            ".....xaaaaaaaaaaaax.....",
            ".....xassssssssssax.....",
            "....xaasiassssaisaax....",
            "....xaassssssssssaax....",
            ".....xaaaaaaaaaaaax.....",
            ".....xaaraaaaaaraax.....",
            "......xaaccccccaax......",
            ".......xaaccccaax.......",
            ".......xxxxaaxxxx.......",
            "......xxkqqqqqqkxx......",
            "......xxqiiiiiiqxx......",
            "......xxxwwqqqqkxx......",
            "........xx..............",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xaaxxxxxxxxaax.....",
            ".....xaaxaaaaaaxaax.....",
            "......xaaaaaaaaaax......",
            ".....xaaaaaaaaaaaax.....",
            ".....xassssssssssax.....",
            "....xaasiassssaisaax....",
            "....xaassssssssssaax....",
            ".....xaaaaaaaaaaaax.....",
            ".....xaaraaaaaaraax.....",
            "......xaaccccccaax......",
            ".......xaaccccaax.......",
            ".......xxxxaaxxxx.......",
            "......xxkqqqqqqkxx......",
            "......xxqiiqqiiqxx......",
            "......xxkqqxwwqkxx......",
            "...........xx...........",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xaaxxxxxxxxaax.....",
            ".....xaaxaaaaaaxaax.....",
            "......xaaaaaaaaaax......",
            ".....xaaaaaaaaaaaax.....",
            ".....xassssssssssax.....",
            "....xaasiassssaisaax....",
            "....xaassssssssssaax....",
            ".....xaaaaaaaaaaaax.....",
            ".....xaaraaaaaaraax.....",
            "......xaaccccccaax......",
            ".......xaaccccaax.......",
            ".......xxxxaaxxxx.......",
            "......xxkqqqqqqkxx......",
            "......xxqiiiiiiqxx......",
            "......xxkqqqqqxwwx......",
            "..............xx........",
        ],
        [
            "......xx........xx......",
            ".....xrrx......xrrx.....",
            ".....xaaxxxxxxxxaax.....",
            ".....xaaxaaaaaaxaax.....",
            "......xaaaaaaaaaax......",
            ".....xaaaaaaaaaaaax.....",
            ".....xassssssssssax.....",
            "....xaasiassssaisaax....",
            "....xaassssssssssaax....",
            ".....xaaaaaaaaaaaax.....",
            ".....xaaraaaaaaraax.....",
            "......xaaccccccaax......",
            ".......xaaccccaax.......",
            ".......xxxxxwwxxx.......",
            "......xxkqqxxqqkxx......",
            "......xxqiiqqiiqxx......",
            "......xxkqqqqqqkxx......",
            "........................",
        ],
    ]

    /// Each pet is on its own beat, so a shared clock does not make them move together.
    static func frameIndex(for kind: PetKind, frame: Int) -> Int {
        let shift: Int
        switch kind {
        case .codex:
            shift = 0
        case .cursor:
            shift = 1
        case .gemini:
            shift = 2
        case .claude:
            shift = 3
        }
        return (frame + shift).mod(frameCount)
    }

    static func image(for kind: PetKind, pose: PetPose = .idle, frame: Int = 0) -> NSImage {
        let index = frame.mod(frameCount)
        let key = "\(kind.rawValue)-\(pose)-\(index)"
        if let cached = cache[key] {
            return cached
        }
        let rows = frames(for: kind, pose: pose)[index]
        let sprite = render(rows)
        cache[key] = sprite
        return sprite
    }

    static func statusBarImage(moods: [PetKind: PetMood], frame: Int) -> NSImage {
        let pets = PetKind.allCases
        let sprites = pets.map { kind in
            let mood = moods[kind] ?? .idle
            let pose: PetPose = mood == .working ? .working : .idle
            let index = mood == .working ? frameIndex(for: kind, frame: frame) : 0
            return image(for: kind, pose: pose, frame: index)
        }
        let gap: CGFloat = 3
        let width = sprites.reduce(CGFloat(0)) { $0 + $1.size.width } + gap * CGFloat(max(0, pets.count - 1))
        let height = sprites.map(\.size.height).max() ?? 1
        let scale = max(1, Int((NSScreen.main?.backingScaleFactor ?? 2).rounded()))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(1, Int(width.rounded(.up)) * scale),
            pixelsHigh: max(1, Int(height.rounded(.up)) * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: NSSize(width: width, height: height))
        }
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .none
        var x: CGFloat = 0
        for (index, kind) in pets.enumerated() {
            let mood = moods[kind] ?? .idle
            let sprite = sprites[index]
            let y = height - sprite.size.height
            let rect = NSRect(x: x, y: y, width: sprite.size.width, height: sprite.size.height)
            let fraction: CGFloat = mood == .offline ? 0.38 : 1
            sprite.draw(in: rect, from: NSRect.zero, operation: NSCompositingOperation.sourceOver, fraction: fraction)
            x += sprite.size.width + gap
        }
        NSGraphicsContext.restoreGraphicsState()
        let composed = NSImage(size: rep.size)
        composed.addRepresentation(rep)
        composed.isTemplate = false
        return composed
    }

    private static func frames(for kind: PetKind, pose: PetPose) -> [[String]] {
        switch (kind, pose) {
        case (.codex, .idle):
            return codexIdle
        case (.codex, .working):
            return codexWork
        case (.cursor, .idle):
            return cursorIdle
        case (.cursor, .working):
            return cursorWork
        case (.gemini, .idle):
            return geminiIdle
        case (.gemini, .working):
            return geminiWork
        case (.claude, .idle):
            return claudeIdle
        case (.claude, .working):
            return claudeWork
        }
    }

    private static func render(_ rows: [String]) -> NSImage {
        let height = rows.count
        let width = rows[0].count
        let scale = max(1, Int((NSScreen.main?.backingScaleFactor ?? 2).rounded()))
        let pointSize = NSSize(width: CGFloat(width), height: CGFloat(height))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width * scale,
            pixelsHigh: height * scale,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: pointSize)
        }
        rep.size = pointSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)).fill()
        for (y, line) in rows.enumerated() {
            for (x, token) in line.enumerated() {
                guard let rgb = colors[token] else { continue }
                let red = CGFloat((rgb >> 16) & 0xFF) / 255
                let green = CGFloat((rgb >> 8) & 0xFF) / 255
                let blue = CGFloat(rgb & 0xFF) / 255
                NSColor(srgbRed: red, green: green, blue: blue, alpha: 1).setFill()
                let pixelY = CGFloat(height - 1 - y)
                NSRect(x: CGFloat(x), y: pixelY, width: 1, height: 1).fill()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        let sprite = NSImage(size: pointSize)
        sprite.addRepresentation(rep)
        sprite.isTemplate = false
        return sprite
    }
}

private extension Int {
    func mod(_ divisor: Int) -> Int {
        guard divisor != 0 else { return 0 }
        let value = self % divisor
        return value >= 0 ? value : value + divisor
    }
}
