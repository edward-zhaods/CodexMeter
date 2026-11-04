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
            "........xx......xx......",
            ".......xGGx....xGGx.....",
            "......xGGGx....xGGGx....",
            "......xG.x......x.Gx....",
            ".....xxddddddddddddxx...",
            "....xG.ddeee.dd.eeedd.x.",
            "....xG.ddeee.dd.eeedd.x.",
            "....xG.dddddddddddddd.x.",
            ".....x.dddd.wwww.dddd.x.",
            "......xGGGGGGGGGGGGGGx..",
            "......xGGGGzyyyyGGGGGx..",
            ".....xww.xxzyyyyxx.wwx..",
            ".....xw...x.yy.x...wx...",
            "......x...x.ggg.x...x...",
            ".......xxx.xgggx.xxx....",
            ".........xx.xxx.xx......",
            "..........x.....x.......",
            "........................",
        ],
        [
            "........xx......xx......",
            ".......xGGx....xGGx.....",
            "......xGGGx....xGGGx....",
            "......xG.x......x.Gx....",
            ".....xxddddddddddddxx...",
            "....xG.dddddddddddddd.x.",
            "....xG.dddeeeeeeeeddd.x.",
            "....xG.dddddddddddddd.x.",
            ".....x.dddd.wwww.dddd.x.",
            "......xGGGGGGGGGGGGGGx..",
            "......xGGGGzyyyyGGGGGx..",
            ".....xww.xxzyyyyxx.wwx..",
            ".....xw...x.yy.x...wx...",
            "......x...x.ggg.x...x...",
            ".......xxx.xgggx.xxx....",
            ".........xx.xxx.xx......",
            "..........x.....x.......",
            "........................",
        ],
        [
            "........xx......xx......",
            ".......xGGx....xGGx.....",
            "......xGGGx....xGGGx....",
            "......xG.x......x.Gx....",
            ".....xxddddddddddddxx...",
            "....xG.dd.eee.eeeeddd.x.",
            "....xG.dd.eee.eeeeddd.x.",
            "....xG.dddddddddddddd.x.",
            ".....x.dddd.wwww.dddd.x.",
            "..xx..xGGGGGGGGGGGGGGx..",
            ".xGx..xGGGGzyyyyGGGGGx..",
            ".xgx.xww.xxzyyyyxx.wwx..",
            "..xx.xw...x.yy.x...wx...",
            "......x...x.ggg.x...x...",
            ".......xxx.xgggx.xxx....",
            ".........xx.xxx.xx......",
            "..........x.....x.......",
            "........................",
        ],
        [
            ".xww....................",
            ".xwwx...xx......xx......",
            "..xx...xGGx....xGGx.....",
            "......xGGGx....xGGGx....",
            ".....xxddddddddddddxx...",
            "....xG.ddeee.dd.eeedd.x.",
            "....xG.ddeee.dd.eeedd.x.",
            "....xG.dddddddddddddd.x.",
            ".....x.dddd.wwww.dddd.x.",
            "......xGGGGGGGGGGGGGGx..",
            "......xGGGGzyyyyGGGGGx..",
            ".....x...xxzyyyyxx...x..",
            ".........x.yy.x.........",
            "......x...x.ggg.x...x...",
            ".......xxx.xgggx.xxx....",
            ".........xx.xxx.xx......",
            "..........x.....x.......",
            "........................",
        ],
    ]

    private static let codexWork: [[String]] = [
        [
            ".....xx....xx...........",
            "....xGGx..xGGx..........",
            "...xG..x..x..Gx..llllx..",
            "..x.dddddddddd.x.ltttlx.",
            ".x.dee.dd.ee.dd.xlttttlx",
            ".x.dee.dd.ee.dd.xlttttlx",
            ".x.dddddddddddd.xlxxxxlx",
            "..x.dd.wwww.dd.xl.wwwwlx",
            "...xggggyggggx.xl.wwwwlx",
            "..xw.xxyyyxx.x.xlxxxxxlx",
            "..x...x.yy.x...xl.....lx",
            ".......xggx....xxxxxxxx.",
            "......xx..xx............",
            "........................",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
        [
            ".....xx....xx...........",
            "....xGGx..xGGx..........",
            "...xG..x..x..Gx..llllx..",
            "..x.dddddddddd.x.ltkklx.",
            ".x.dee.dd.ee.dd.xltkktlx",
            ".x.dee.dd.ee.dd.xltkktlx",
            ".x.dddddddddddd.xlxxxxlx",
            "..x.dd.wwww.dd.xlww..wwx",
            "...xggggyggggx.xlww..wwx",
            "..x...xxyyxx...xlxxxxxlx",
            "..xww.x.yy.xww.xl.....lx",
            ".......xggx....xxxxxxxx.",
            "......xx..xx............",
            "........................",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
        [
            ".....xx....xx...........",
            "....xGGx..xGGx..........",
            "...xG..x..x..Gx..llllx..",
            "..x.dddddddddd.x.ltttlx.",
            ".x.dddddddddddd.xlttttlx",
            ".x.dddeeeeee.dd.xlttttlx",
            ".x.dddddddddddd.xlxxxxlx",
            "..x.dd.wwww.dd.xl......x",
            "...xggggyggggx.xl.wwwwlx",
            "..xw.xxyyyxx.x.xl.wwwwlx",
            "..x...x.yy.x...xlxxxxxlx",
            ".......xggx....xl.....lx",
            "......xx..xx...xxxxxxxx.",
            "........................",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
        [
            ".....xx....xx..q.q......",
            "....xGGx..xGGx.q...q....",
            "...xG..x..x..Gx..llllx..",
            "..x.dddddddddd.x.ltqtlx.",
            ".x.dee.dd.ee.dd.xltqqtlx",
            ".x.dee.dd.ee.dd.xltqqtlx",
            ".x.dddddddddddd.xlxxxxlx",
            "..x.dd.wwww.dd.xl.wwwwlx",
            "...xggggyggggx.xl.wwwwlx",
            "..xw.xxyyyxx.x.xlxxxxxlx",
            "..x...x.yy.x...xl.....lx",
            ".......xggx....xxxxxxxx.",
            "......xx..xx............",
            "........................",
            "........................",
            "........................",
            "........................",
            "........................",
        ],
    ]

    private static let cursorIdle: [[String]] = [
        [
            ".....xx..........xx.....",
            "....xPPx........xPPx....",
            "...xP..Px......xP..Px...",
            "...xP..Px.x..x.xP..Px...",
            "..xxP..Pxu.ii.uxP..Pxx..",
            "..x.xPPxu.iiii.uxPPx.x..",
            "..xP.x.xxuuuuuuxx.x.Px..",
            "...xP.xddddddddddx.Px...",
            "....x.xmmmmmmmmmmx.x....",
            ".....x.xm.d..d.mx.x.....",
            "......x.xrrddrrx.x......",
            ".......xwwxPPxwwx.......",
            ".......xw.xPPx.wx.......",
            "........x..xx..x........",
            ".........x....x.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
        [
            ".....xx..........xx.....",
            "....xPPx........xPPx....",
            "...xP..Px......xP..Px...",
            "...xP..Px.x..x.xP..Px...",
            "..xxP..Pxu.uu.uxP..Pxx..",
            "..x.xPPxuxxxxu.uxPPx.x..",
            "..xP.x.xxuuuuuuxx.x.Px..",
            "...xP.xddddddddddx.Px...",
            "....x.xmmmmmmmmmmx.x....",
            ".....x.xm.d..d.mx.x.....",
            "......x.xrrddrrx.x......",
            ".......xwwxPPxwwx.......",
            ".......xw.xPPx.wx.......",
            "........x..xx..x........",
            ".........x....x.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
        [
            ".....xx..........xx.....",
            "....xPPx........xPPx....",
            "...xP..Px......xP..Px...",
            "...xP..Px.x..x.xP..Px...",
            "..xxP..Pxu.ii.uxP..Pxx..",
            "..x.xPPxu.iiii.uxPPx.x..",
            "..xP.x.xxuuuuuuxx.x.Px..",
            "...xP.xddddddddddx.Px...",
            "....x.xmmmmmmmmmmx.x....",
            ".....x.xm.d..d.mx.x.....",
            "......x.x.rr.rrx.x......",
            ".......xw.rr.xwwx.......",
            ".......xw.rr.x.wx.......",
            "........x.xx...x........",
            ".........x....x.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
        [
            ".....xx..........xx.....",
            "....xPPx........xPPx....",
            "...xP..Px......xP..Px...",
            "...xP..Px.x..x.xP..Px...",
            "xwwxP..Pxu.ii.uxP..Pxx..",
            "xwwxxPPxu.iiii.uxPPx.x..",
            "..xP.x.xxuuuuuuxx.x.Px..",
            "...xP.xddddddddddx.Px...",
            "....x.xmmmmmmmmmmx.x....",
            ".....x.xm.d..d.mx.x.....",
            "......x.xrrddrrx.x......",
            ".......x..xPPxwwx.......",
            ".......x..xPPx.wx.......",
            "........x..xx..x........",
            ".........x....x.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
    ]

    private static let cursorWork: [[String]] = [
        [
            ".....xx..........xx.....",
            "....xPPx........xPPx....",
            "...xP..Px......xP..Px...",
            "...xP..Px.x..x.xP..Px...",
            "..xxP..Pxu.ii.uxP..Pxx..",
            "..x.xPPxu.iiii.uxPPx.x..",
            "..xP.x.xxuuuuuuxx.x.Px..",
            "...xP.xddddddddddx.Px...",
            "....x.xmmmmmmm.llllx....",
            ".....x.xm.d..dlttttlx...",
            "......x.xrrddrlttttlx...",
            ".......xwwxPPxlxxxxlx...",
            ".......xw.xPPxlwwwwlx...",
            "........x..xx.lxxxxlx...",
            ".........x....x.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
        [
            ".....xx..........xx.....",
            "....xPPx........xPPx....",
            "...xP..Px......xP..Px...",
            "...xP..Px.x..x.xP..Px...",
            "..xxP..Pxu.ii.uxP..Pxx..",
            "..x.xPPxu.iiii.uxPPx.x..",
            "..xP.x.xxuuuuuuxx.x.Px..",
            "...xP.xddddddddddx.Px...",
            "....x.xmmmmmmm.llllx....",
            ".....x.xm.d..dltkktlx...",
            "......x.xrrddrltkktlx...",
            ".......xwwxPPxlxxxxlx...",
            ".......xw.xPPxl.wwwlx...",
            "........x..xx.lxxxxlx...",
            ".........x....x.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
        [
            ".....xx..........xx.....",
            "....xPPx........xPPx....",
            "...xP..Px......xP..Px...",
            "...xP..Px.x..x.xP..Px...",
            "..xxP..Pxu.uu.uxP..Pxx..",
            "..x.xPPxuxxxxu.uxPPx.x..",
            "..xP.x.xxuuuuuuxx.x.Px..",
            "...xP.xddddddddddx.Px...",
            "....x.xmmmmmmm.llllx....",
            ".....x.xm.d..dlttttlx...",
            "......x.xrrddrlttttlx...",
            ".......xwwxPPxlxxxxlx...",
            ".......xw.xPPxl.....lx..",
            "........x..xx.l.wwwlx...",
            ".........x....lxxxxlx...",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
        [
            ".....xx.........q.q.....",
            "....xPPx.........q.x....",
            "...xP..Px......xP..Px...",
            "...xP..Px.x..x.xP..Px...",
            "..xxP..Pxu.ii.uxP..Pxx..",
            "..x.xPPxu.iiii.uxPPx.x..",
            "..xP.x.xxuuuuuuxx.x.Px..",
            "...xP.xddddddddddx.Px...",
            "....x.xmmmmmmm.llllx....",
            ".....x.xm.d..dltqqtlx...",
            "......x.xrrddrltqqtlx...",
            ".......xwwxPPxlxxxxlx...",
            ".......xw.xPPxlwwwwlx...",
            "........x..xx.lxxxxlx...",
            ".........x....x.........",
            "..........xxxx..........",
            "........................",
            "........................",
        ],
    ]

    private static let geminiIdle: [[String]] = [
        [
            "........xx......xx......",
            ".......xBBx....xBBx.....",
            "......xBBBx....xBBBx....",
            "......xB.x......x.Bx....",
            ".....xxnnnnnnnnnnnnxx...",
            "....xB.xxee.xx.eexx.Bx..",
            "....xb.xe.e.xx.e.ex.bx..",
            "....xB.xxee.xx.eexx.Bx..",
            ".....x.nnnnnxxnnnnn.x...",
            "......xBBBByyyyBBBBBx...",
            "......xBBBbzyyybBBBBx...",
            ".....xww.xxzyyyxx.wwx...",
            ".....xw...x.yy.x...wx...",
            "......x...x.bb.x...x....",
            ".......xxx.xbbbx.xxx....",
            ".........xx.xxx.xx......",
            "..........x.....x.......",
            "........................",
        ],
        [
            "........xx......xx......",
            ".......xBBx....xBBx.....",
            "......xBBBx....xBBBx....",
            "......xB.x......x.Bx....",
            ".....xxnnnnnnnnnnnnxx...",
            "....xB.xxnn.xx.nnxx.Bx..",
            "....xb.xxxx.xx.xxxx.bx..",
            "....xB.xxnn.xx.nnxx.Bx..",
            ".....x.nnnnnxxnnnnn.x...",
            "......xBBBByyyyBBBBBx...",
            "......xBBBbzyyybBBBBx...",
            ".....xww.xxzyyyxx.wwx...",
            ".....xw...x.yy.x...wx...",
            "......x...x.bb.x...x....",
            ".......xxx.xbbbx.xxx....",
            ".........xx.xxx.xx......",
            "..........x.....x.......",
            "........................",
        ],
        [
            "........xx......xx......",
            ".......xBBx....xBBx.....",
            "......xBBBx....xBBBx....",
            "......xB.x......x.Bx....",
            ".....xxnnnnnnnnnnnnxx...",
            "....xB.xxee.xx.eexx.Bx..",
            "....xb.xi.e.xx.e.ex.bx..",
            "....xB.xxee.xx.eexx.Bx..",
            ".....x.nnnnnxxnnnnn.x...",
            "......xBBBBByyyBBBBBx...",
            "......xBBBBzyyybBBBBBx..",
            ".....xww.xxyzyyxx.wwx...",
            ".....xw...x.yy.x...wx...",
            "......x...x.bb.x...x....",
            ".......xxx.xbbbx.xxx....",
            ".........xx.xxx.xx......",
            "..........x.....x.......",
            "........................",
        ],
        [
            "........xx......xx......",
            ".......xBBx....xBBx.....",
            "......xBBBx....xBBBx....",
            "......xB.x......x.Bx....",
            ".....xxnnnnnnnnnnnnxx...",
            "....xB.xxee.xx.eexx.Bx..",
            "xwwxxb.xe.e.xx.e.ex.bx..",
            "xwwxxB.xxee.xx.eexx.Bx..",
            ".....x.nnnnnxxnnnnn.x...",
            "......xBBBByyyyBBBBBx...",
            "......xBBBbzyyybBBBBx...",
            ".....x...xxzyyyxx.wwx...",
            ".....x....x.yy.x...wx...",
            "......x...x.bb.x...x....",
            ".......xxx.xbbbx.xxx....",
            ".........xx.xxx.xx......",
            "..........x.....x.......",
            "........................",
        ],
    ]

    private static let geminiWork: [[String]] = [
        [
            "........xx......xx......",
            ".......xBBx....xBBx.....",
            "......xBBBx....xBBBx....",
            "......xB.x......x.Bx....",
            ".....xxnnnnnnnnnnnnxx...",
            "....xB.xxee.xx.eexx.Bx..",
            "....xb.xe.e.xx.e.ex.bx..",
            "....xB.xxee.xx.eexx.Bx..",
            ".....x.nnnnnxx.llllxx...",
            "......xBBBByyylttttlx...",
            "......xBBBbzyylttttlx...",
            ".....xww.xxzyylxxxxlx...",
            ".....xw...x.yylwwwwlx...",
            "......x...x.bblxxxxlx...",
            ".......xxx.xbbbx.xxx....",
            ".........xx.xxx.xx......",
            "..........x.....x.......",
            "........................",
        ],
        [
            "........xx......xx......",
            ".......xBBx....xBBx.....",
            "......xBBBx....xBBBx....",
            "......xB.x......x.Bx....",
            ".....xxnnnnnnnnnnnnxx...",
            "....xB.xxee.xx.eexx.Bx..",
            "....xb.xe.e.xx.e.ex.bx..",
            "....xB.xxee.xx.eexx.Bx..",
            ".....x.nnnnnxx.llllxx...",
            "......xBBBByyyltkktlx...",
            "......xBBBbzyyltkktlx...",
            ".....xww.xxzyylxxxxlx...",
            ".....xw...x.yyl.wwwlx...",
            "......x...x.bblxxxxlx...",
            ".......xxx.xbbbx.xxx....",
            ".........xx.xxx.xx......",
            "..........x.....x.......",
            "........................",
        ],
        [
            "........xx......xx......",
            ".......xBBx....xBBx.....",
            "......xBBBx....xBBBx....",
            "......xB.x......x.Bx....",
            ".....xxnnnnnnnnnnnnxx...",
            "....xB.xxnn.xx.nnxx.Bx..",
            "....xb.xxxx.xx.xxxx.bx..",
            "....xB.xxnn.xx.nnxx.Bx..",
            ".....x.nnnnnxx.llllxx...",
            "......xBBBByyylttttlx...",
            "......xBBBbzyylttttlx...",
            ".....xww.xxzyylxxxxlx...",
            ".....xw...x.yylwww..lx..",
            "......x...x.bbl.wwwlx...",
            ".......xxx.xbblxxxxlx...",
            ".........xx.xxx.xx......",
            "..........x.....x.......",
            "........................",
        ],
        [
            "........xx......xxq.q...",
            ".......xBBx....xBB.q....",
            "......xBBBx....xBBBx....",
            "......xB.x......x.Bx....",
            ".....xxnnnnnnnnnnnnxx...",
            "....xB.xxee.xx.eexx.Bx..",
            "....xb.xe.e.xx.e.ex.bx..",
            "....xB.xxee.xx.eexx.Bx..",
            ".....x.nnnnnxx.llllxx...",
            "......xBBBByyyltqqtlx...",
            "......xBBBbzyyltqqtlx...",
            ".....xww.xxzyylxxxxlx...",
            ".....xw...x.yylwwwwlx...",
            "......x...x.bblxxxxlx...",
            ".......xxx.xbbbx.xxx....",
            ".........xx.xxx.xx......",
            "..........x.....x.......",
            "........................",
        ],
    ]

    private static let claudeIdle: [[String]] = [
        [
            "................................",
            ".........................xx.xx..",
            "........................xaaxaax.",
            "........................xaaaaaax",
            "...............xx......xasssssax",
            "..............xAAx.....xaaaaaaax",
            "............xAAAAAxxxxxaawwwaaax",
            "..........xAAAAAAAAAAAAAaaaaaaax",
            "........xAAAAAAAAAAAAAAAAAAAAaxx",
            ".......xxAAAAAAAAAAAAAAAAAxxx...",
            ".........xxxAAAAAAAAAAAxx.......",
            "...........xxxxxxxxxxx..........",
            "........xccccccccccccccccx......",
            ".......xh................hx.....",
            ".......xh................hx.....",
            "........hh..............hh......",
            "................................",
            "................................",
        ],
        [
            "................................",
            ".........................xx.xx..",
            "........................xaaxaax.",
            "........................xaaaaaax",
            "...............xx......xasssssax",
            "........xx....xAAx.....xaaaaaaax",
            ".......xAAx.xAAAAAxxxxxaawwwaaax",
            "......xAAAxAAAAAAAAAAAAAaaaaaaax",
            ".......xxxAAAAAAAAAAAAAAAAAAAaxx",
            ".......xxAAAAAAAAAAAAAAAAAxxx...",
            ".........xxxAAAAAAAAAAAxx.......",
            "...........xxxxxxxxxxx..........",
            "........xccccccccccccccccx......",
            ".......xh................hx.....",
            ".......xh................hx.....",
            "........hh..............hh......",
            "................................",
            "................................",
        ],
        [
            "................................",
            ".........................xx.xx..",
            "........................xaaxaax.",
            "........................xaaaaaax",
            "...............xx......xaissssax",
            "..............xAAx.....xaaaaaaax",
            "............xAAAAAxxxxxaawwwaaax",
            "..........xAAAAAAAAAAAAAaaaaaaax",
            "........xAAAAAAAAAAAAAAAAAAAAaxx",
            ".......xxAAAAAAAAAAAAAAAAAxxx...",
            ".........xxxAAAAAAAAAAAxx.......",
            "...........xxxxxxxxxxx..........",
            "........xccccccccccccccccx......",
            ".......xh................hx.....",
            ".......xh................hx.....",
            "........hh..............hh......",
            "................................",
            "................................",
        ],
        [
            "................................",
            ".....................xww.xx.xx..",
            "....................xwwxxaaxaax.",
            ".....................xx.xaaaaaax",
            "...............xx......xasssssax",
            "..............xAAx.....xaaaaaaax",
            "............xAAAAAxxxxxaawwwaaax",
            "..........xAAAAAAAAAAAAAaaaaaaax",
            "........xAAAAAAAAAAAAAAAAAAAAaxx",
            ".......xxAAAAAAAAAAAAAAAAAxxx...",
            ".........xxxAAAAAAAAAAAxx.......",
            "...........xxxxxxxxxxx..........",
            "........xccccccccccccccccx......",
            ".......xh................hx.....",
            ".......xh................hx.....",
            "........hh..............hh......",
            "................................",
            "................................",
        ],
    ]

    private static let claudeWork: [[String]] = [
        [
            "................................",
            "................................",
            "................................",
            ".......xx......xx...............",
            "......xaax....xaax..............",
            ".....xaaaaaaaaaaaax....llllx....",
            "....xaasssssssssssax...lttttlx..",
            "....xaaa.wwwwww.aaax..ltttttlx..",
            "....xaaaaaaaaaaaaaax..lxxxxxxlx.",
            ".....xxaaaawwwaaaaxx..l.wwww.lx.",
            ".......xxaaaaaaaax....l.wwww.lx.",
            ".........xxx.xxx......lxxxxxxlx.",
            "......................l......lx.",
            "......................xxxxxxxx..",
            "................................",
            "................................",
            "................................",
            "................................",
        ],
        [
            "................................",
            "................................",
            "................................",
            ".......xx......xx...............",
            "......xaax....xaax..............",
            ".....xaaaaaaaaaaaax....llllx....",
            "....xaasssisssssssax...ltkktlx..",
            "....xaaa.wwwwww.aaax..ltkkttlx..",
            "....xaaaaaaaaaaaaaax..lxxxxxxlx.",
            ".....xxaaaawwwaaaaxx..lww..wwlx.",
            ".......xxaaaaaaaax....lww..wwlx.",
            ".........xxx.xxx......lxxxxxxlx.",
            "......................l......lx.",
            "......................xxxxxxxx..",
            "................................",
            "................................",
            "................................",
            "................................",
        ],
        [
            "................................",
            "................................",
            "................................",
            ".......xx......xx...............",
            "......xaax....xaax..............",
            ".....xaaaaaaaaaaaax....llllx....",
            "....xassssssssssssax...lttttlx..",
            "....xaaaaaaaaaaaaaax..ltttttlx..",
            "....xaaa.wwwwww.aaax..lxxxxxxlx.",
            ".....xxaaaawwwaaaaxx..l......lx.",
            ".......xxaaaaaaaax....l.wwww.lx.",
            ".........xxx.xxx......l.wwww.lx.",
            "......................lxxxxxxlx.",
            "......................l......lx.",
            "......................xxxxxxxx..",
            "................................",
            "................................",
            "................................",
        ],
        [
            "........................q.q.....",
            ".........................q......",
            "................................",
            ".......xx......xx...............",
            "......xaax....xaax..............",
            ".....xaaaaaaaaaaaax....llllx....",
            "....xaasssssssssssax...ltqqtlx..",
            "....xaaa.wwwwww.aaax..ltqqqtlx..",
            "....xaaaaaaaaaaaaaax..lxxxxxxlx.",
            ".....xxaaaawwwaaaaxx..l.wwww.lx.",
            ".......xxaaaaaaaax....l.wwww.lx.",
            ".........xxx.xxx......lxxxxxxlx.",
            "......................l......lx.",
            "......................xxxxxxxx..",
            "................................",
            "................................",
            "................................",
            "................................",
        ],
    ]

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
            return image(for: kind, pose: pose, frame: frame)
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
