import AppKit
import Testing
@testable import PieceOfPaper

@MainActor
@Suite struct PaperTextViewTests {
    private func textView(_ text: String, selection: NSRange? = nil) -> PaperTextView {
        let textView = PaperTextView.make()
        textView.string = text
        textView.setSelectedRange(selection ?? NSRange(location: (text as NSString).length, length: 0))
        return textView
    }

    // MARK: Lists

    @Test func returnContinuesBulletLists() {
        let view = textView("- uno")
        view.insertNewline(nil)
        #expect(view.string == "- uno\n- ")
    }

    @Test func returnIncrementsNumberedLists() {
        let view = textView("1. uno")
        view.insertNewline(nil)
        #expect(view.string == "1. uno\n2. ")
    }

    @Test func returnStartsAnOpenTask() {
        let view = textView("\t- [x] fatto")
        view.insertNewline(nil)
        #expect(view.string == "\t- [x] fatto\n\t- [ ] ")
    }

    @Test func returnOnAnEmptyItemEndsTheList() {
        let view = textView("- uno\n- ")
        view.insertNewline(nil)
        #expect(view.string == "- uno\n")
    }

    @Test func returnOutsideListsIsPlain() {
        let view = textView("testo")
        view.insertNewline(nil)
        #expect(view.string == "testo\n")
    }

    @Test func returnInsideTheMarkerIsPlain() {
        let view = textView("- uno", selection: NSRange(location: 0, length: 0))
        view.insertNewline(nil)
        #expect(view.string == "\n- uno")
    }

    @Test func tabAndBacktabChangeTheItemLevel() {
        let view = textView("- uno")
        view.insertTab(nil)
        #expect(view.string == "\t- uno")
        #expect(view.selectedRange() == NSRange(location: 6, length: 0))
        view.insertBacktab(nil)
        #expect(view.string == "- uno")
        #expect(view.selectedRange() == NSRange(location: 5, length: 0))
    }

    @Test func tabOutsideListsInsertsATab() {
        let view = textView("testo")
        view.insertTab(nil)
        #expect(view.string == "testo\t")
    }

    // MARK: Format menu

    @Test func headingCommands() {
        let view = textView("titolo")
        view.paperHeading2(nil)
        #expect(view.string == "## titolo")
        view.paperHeading1(nil)
        #expect(view.string == "# titolo")
        view.paperBodyText(nil)
        #expect(view.string == "titolo")
    }

    @Test func checklistAppliesToEverySelectedLine() {
        let view = textView("a\nb\n", selection: NSRange(location: 0, length: 3))
        view.paperChecklist(nil)
        #expect(view.string == "- [ ] a\n- [ ] b\n")
        view.paperToggleTask(nil)
        #expect(view.string == "- [x] a\n- [x] b\n")
    }

    @Test func boldWrapsAndUnwrapsTheSelection() {
        let view = textView("una parola", selection: NSRange(location: 4, length: 6))
        view.paperBold(nil)
        #expect(view.string == "una **parola**")
        #expect(view.selectedRange() == NSRange(location: 6, length: 6))
        view.paperBold(nil)
        #expect(view.string == "una parola")
    }

    @Test func formattingIsUndoable() throws {
        let window = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
        let view = textView("titolo")
        window.contentView = view
        view.paperHeading1(nil)
        #expect(view.string == "# titolo")
        try #require(view.undoManager).undo()
        #expect(view.string == "titolo")
    }

    // MARK: Highlighter

    @Test func highlighterWrapsTheSelection() {
        let view = textView("una frase importante", selection: NSRange(location: 4, length: 16))
        view.paperHighlight(nil)
        #expect(view.string == "una ==frase importante==")
        #expect(view.selectedRange() == NSRange(location: 6, length: 16))
    }

    @Test func highlighterWithTheCaretInsideRemovesTheHighlight() {
        let view = textView("una ==frase importante== qui", selection: NSRange(location: 10, length: 0))
        #expect(view.selectionIsHighlighted)
        view.paperHighlight(nil)
        #expect(view.string == "una frase importante qui")
        #expect(view.selectedRange() == NSRange(location: 8, length: 0))
        #expect(!view.selectionIsHighlighted)
    }

    @Test func marksAreHiddenAwayFromTheSelection() throws {
        let view = textView("==evidenziato==\naltra riga")
        let storage = try #require(view.textStorage)
        #expect(storage.attribute(.paperHidden, at: 0, effectiveRange: nil) != nil)
        #expect(storage.attribute(.paperHidden, at: 13, effectiveRange: nil) != nil)
        #expect(storage.attribute(.paperHidden, at: 5, effectiveRange: nil) == nil)
        #expect(storage.attribute(.backgroundColor, at: 5, effectiveRange: nil) != nil)
    }

    @Test func marksAppearWhenTheCaretIsOnTheLine() throws {
        let view = textView("==evidenziato==\naltra riga")
        let storage = try #require(view.textStorage)
        view.setSelectedRange(NSRange(location: 5, length: 0))
        #expect(storage.attribute(.paperHidden, at: 0, effectiveRange: nil) == nil)
        view.setSelectedRange(NSRange(location: 20, length: 0))
        #expect(storage.attribute(.paperHidden, at: 0, effectiveRange: nil) != nil)
    }

    @Test func hiddenMarksTakeNoSpace() throws {
        let view = textView("==evidenziato==\naltra riga")
        let layoutManager = try #require(view.layoutManager)
        let marker = layoutManager.glyphIndexForCharacter(at: 0)
        let text = layoutManager.glyphIndexForCharacter(at: 2)
        #expect(layoutManager.propertyForGlyph(at: marker).contains(.null))
        #expect(!layoutManager.propertyForGlyph(at: text).contains(.null))
    }

    @Test func contextMenuOffersTheHighlighter() throws {
        let view = textView("una frase", selection: NSRange(location: 4, length: 5))
        let event = try #require(NSEvent.mouseEvent(
            with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
        #expect(view.menu(for: event)?.items.first?.title == "Evidenzia")
        view.paperHighlight(nil)
        #expect(view.menu(for: event)?.items.first?.title == "Rimuovi evidenziazione")
    }

    // MARK: Styling

    @Test func headingsUseALargerFont() throws {
        let view = textView("# Titolo\ntesto")
        let storage = try #require(view.textStorage)
        let heading = try #require(storage.attribute(.font, at: 3, effectiveRange: nil) as? NSFont)
        let body = try #require(storage.attribute(.font, at: 10, effectiveRange: nil) as? NSFont)
        #expect(heading.pointSize > body.pointSize)
    }

    @Test func urlsBecomeLinks() throws {
        let view = textView("vedi https://example.com/a e [doc](https://example.com/doc)")
        let storage = try #require(view.textStorage)
        #expect(storage.attribute(.paperLink, at: 8, effectiveRange: nil) as? URL == URL(string: "https://example.com/a"))
        #expect(storage.attribute(.paperLink, at: 31, effectiveRange: nil) as? URL == URL(string: "https://example.com/doc"))
        #expect(storage.attribute(.paperLink, at: 0, effectiveRange: nil) == nil)
    }

    @Test func codeBlocksAreNotStyledAsMarkdown() throws {
        let view = textView("```\n# commento\n```\n# Titolo")
        let storage = try #require(view.textStorage)
        let inCode = try #require(storage.attribute(.font, at: 6, effectiveRange: nil) as? NSFont)
        let heading = try #require(storage.attribute(.font, at: 22, effectiveRange: nil) as? NSFont)
        #expect(inCode.isFixedPitch)
        #expect(heading.pointSize > inCode.pointSize)
    }

    @Test func closingAFenceRestylesFollowingLines() throws {
        let view = textView("```\n# dentro")
        let storage = try #require(view.textStorage)
        #expect((storage.attribute(.font, at: 6, effectiveRange: nil) as? NSFont)?.isFixedPitch == true)
        view.setSelectedRange(NSRange(location: 3, length: 0))
        view.insertText("\n```", replacementRange: view.selectedRange())
        // "```\n```\n# dentro": the heading is now outside the code block.
        #expect((storage.attribute(.font, at: 10, effectiveRange: nil) as? NSFont)?.isFixedPitch == false)
    }
}
