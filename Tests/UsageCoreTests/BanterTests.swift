import XCTest
@testable import UsageCore

final class BanterTests: XCTestCase {
    func testFiftyUniqueLinesAreGroupedAndRotateHourly() {
        XCTAssertEqual(Banter.greenLines.count, 17)
        XCTAssertEqual(Banter.amberLines.count, 16)
        XCTAssertEqual(Banter.redLines.count, 17)
        XCTAssertEqual(Banter.lines.count, 50)
        XCTAssertEqual(Set(Banter.lines).count, 50)

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for color in ["green", "amber", "red"] {
            XCTAssertEqual(Banter.line(color: color, now: start), Banter.line(color: color, now: start.addingTimeInterval(3599)))
            XCTAssertNotEqual(Banter.line(color: color, now: start), Banter.line(color: color, now: start.addingTimeInterval(3600)))
        }
        let pauseLines = Set(Banter.amberLines.suffix(4))
        XCTAssertTrue(pauseLines.contains(Banter.line(color: "amber", pause: true, now: start)))
        XCTAssertEqual(Banter.menuPhrase(color: "green"), "go on, boss!")
        XCTAssertEqual(Banter.menuPhrase(color: "amber", pause: true), "easy there, boss!")
        XCTAssertEqual(Banter.menuPhrase(color: "red"), "you’re fucked, mate!")
    }
}
