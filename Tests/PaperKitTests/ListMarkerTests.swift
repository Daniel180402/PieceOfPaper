import Testing
@testable import PaperKit

@Suite struct ListMarkerTests {
    @Test func parsesBullets() throws {
        let marker = try #require(ListMarker.parse("  - testo"))
        #expect(marker.indent == "  ")
        #expect(marker.kind == .bullet("-"))
        #expect(marker.prefixLength == 4)
        #expect(marker.content == "testo")
        #expect(marker.continuation == "  - ")
    }

    @Test func parsesOrderedItems() throws {
        let marker = try #require(ListMarker.parse("9) nove"))
        #expect(marker.kind == .ordered(9, delimiter: ")"))
        #expect(marker.continuation == "10) ")
    }

    @Test func parsesTasks() throws {
        let open = try #require(ListMarker.parse("- [ ] da fare"))
        #expect(open.kind == .task(bullet: "-", checked: false))
        #expect(open.content == "da fare")
        #expect(open.checkboxOffset == 2)

        let done = try #require(ListMarker.parse("\t* [x]"))
        #expect(done.kind == .task(bullet: "*", checked: true))
        #expect(done.content == "")
        #expect(done.continuation == "\t* [ ] ")
    }

    @Test(arguments: ["testo", "-", "---", "*corsivo*", "1.5 milioni", "#titolo", ""])
    func rejectsNonListLines(_ line: String) {
        #expect(ListMarker.parse(line) == nil)
    }

    @Test func emptyBulletHasNoContent() throws {
        #expect(try #require(ListMarker.parse("- ")).content.isEmpty)
    }
}
