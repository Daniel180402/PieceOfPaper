import Foundation
import Testing
@testable import PaperKit

@Suite struct MarkdownFormattingTests {
    @Test func detectsBlockStyles() {
        #expect(MarkdownFormatting.style(of: "## Titolo") == .heading(2))
        #expect(MarkdownFormatting.style(of: "- punto") == .bullet)
        #expect(MarkdownFormatting.style(of: "3. punto") == .numbered)
        #expect(MarkdownFormatting.style(of: "- [x] fatto") == .task)
        #expect(MarkdownFormatting.style(of: "testo") == .body)
    }

    @Test func convertsBetweenStyles() {
        #expect(MarkdownFormatting.apply(.heading(1), to: ["- punto"]) == ["# punto"])
        #expect(MarkdownFormatting.apply(.task, to: ["## Titolo"]) == ["- [ ] Titolo"])
        #expect(MarkdownFormatting.apply(.bullet, to: ["  1. annidato"]) == ["  - annidato"])
    }

    @Test func numbersListsAndKeepsBlankLines() {
        let result = MarkdownFormatting.apply(.numbered, to: ["uno", "", "due"])
        #expect(result == ["1. uno", "", "2. due"])
    }

    @Test func togglesStyleOffWhenAlreadyApplied() {
        #expect(MarkdownFormatting.apply(.bullet, to: ["- a", "- b"]) == ["a", "b"])
        #expect(MarkdownFormatting.apply(.heading(2), to: ["## Titolo"]) == ["Titolo"])
    }

    @Test func togglesTasks() {
        #expect(MarkdownFormatting.toggleTask("- [ ] mail") == "- [x] mail")
        #expect(MarkdownFormatting.toggleTask("  - [x] mail") == "  - [ ] mail")
        #expect(MarkdownFormatting.toggleTask("- mail") == "- [ ] mail")
        #expect(MarkdownFormatting.toggleTask("mail") == "- [ ] mail")
    }

    @Test func wrapsSelection() {
        let text = "una parola qui" as NSString
        let edit = MarkdownFormatting.toggleWrap(marker: "**", in: text, selection: NSRange(location: 4, length: 6))
        #expect(edit.range == NSRange(location: 4, length: 6))
        #expect(edit.replacement == "**parola**")
        #expect(edit.selection == NSRange(location: 6, length: 6))
    }

    @Test func unwrapsWhenMarkersSurroundSelection() {
        let text = "una **parola** qui" as NSString
        let edit = MarkdownFormatting.toggleWrap(marker: "**", in: text, selection: NSRange(location: 6, length: 6))
        #expect(edit.range == NSRange(location: 4, length: 10))
        #expect(edit.replacement == "parola")
        #expect(edit.selection == NSRange(location: 4, length: 6))
    }

    @Test func unwrapsWhenSelectionIncludesMarkers() {
        let text = "una **parola** qui" as NSString
        let edit = MarkdownFormatting.toggleWrap(marker: "**", in: text, selection: NSRange(location: 4, length: 10))
        #expect(edit.replacement == "parola")
        #expect(edit.selection == NSRange(location: 4, length: 6))
    }

    @Test func caretInsideAHighlightRemovesIt() {
        let text = "una ==frase importante== qui" as NSString
        let edit = MarkdownFormatting.toggleWrap(marker: "==", in: text, selection: NSRange(location: 10, length: 0))
        #expect(edit.range == NSRange(location: 4, length: 20))
        #expect(edit.replacement == "frase importante")
        #expect(edit.selection == NSRange(location: 8, length: 0))
    }

    @Test func partialSelectionInsideAHighlightRemovesIt() {
        let text = "una ==frase importante== qui" as NSString
        let edit = MarkdownFormatting.toggleWrap(marker: "==", in: text, selection: NSRange(location: 12, length: 5))
        #expect(edit.replacement == "frase importante")
        #expect(edit.selection == NSRange(location: 10, length: 5))
    }

    @Test func caretNextToAHighlightStartsANewOne() {
        let text = "==uno== due" as NSString
        let edit = MarkdownFormatting.toggleWrap(marker: "==", in: text, selection: NSRange(location: 7, length: 0))
        #expect(edit.range == NSRange(location: 7, length: 0))
        #expect(edit.replacement == "====")
    }

    @Test func caretInsideBoldRemovesBoldButNotItalic() {
        let text = "a **grassetto** e _corsivo_" as NSString
        #expect(MarkdownFormatting.toggleWrap(marker: "**", in: text, selection: NSRange(location: 6, length: 0)).replacement == "grassetto")
        #expect(MarkdownFormatting.enclosingSpan(marker: "_", in: text, containing: NSRange(location: 6, length: 0)) == nil)
        #expect(MarkdownFormatting.enclosingSpan(marker: "_", in: text, containing: NSRange(location: 21, length: 0)) == NSRange(location: 18, length: 9))
    }

    @Test func spansDoNotCrossLines() {
        let text = "==uno\ndue==" as NSString
        #expect(MarkdownFormatting.enclosingSpan(marker: "==", in: text, containing: NSRange(location: 3, length: 0)) == nil)
    }

    @Test func insertsEmptyMarkersAtCaret() {
        let edit = MarkdownFormatting.toggleWrap(marker: "_", in: "ab" as NSString, selection: NSRange(location: 1, length: 0))
        #expect(edit.replacement == "__")
        #expect(edit.selection == NSRange(location: 2, length: 0))
    }
}
