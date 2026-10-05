import Foundation
import Testing
@testable import PaperKit

@Suite struct IndexBuilderTests {
    @Test func parsesHeadingsWithLevelsAndLocations() {
        let markdown = """
        # Kickoff
        testo
        ## Decisioni ##
        #non-un-titolo
        ### Prossimi passi
        """
        let headings = IndexBuilder.headings(in: markdown)
        #expect(headings.map(\.text) == ["Kickoff", "Decisioni", "Prossimi passi"])
        #expect(headings.map(\.level) == [1, 2, 3])
        #expect(headings.map(\.location) == [0, 16, 47])
    }

    @Test func ignoresHeadingsInsideCodeFences() {
        let markdown = """
        ## Vero
        ```
        # commento bash
        ```
        """
        #expect(IndexBuilder.headings(in: markdown).map(\.text) == ["Vero"])
    }

    @Test func stripsInlineMarkupFromHeadings() {
        #expect(IndexBuilder.headings(in: "## Note su **API** e [docs](https://x.y)").first?.text == "Note su API e docs")
    }

    @Test func countsTasks() {
        let markdown = """
        - [ ] scrivere mail
        - [x] chiamare Luca
          * [X] sotto-attività
        - [] non è un'attività
        """
        let counts = IndexBuilder.taskCounts(in: markdown)
        #expect(counts.open == 1)
        #expect(counts.completed == 2)
    }

    @Test func previewSkipsHeadingsAndMarkers() {
        let markdown = """
        # Titolo

        - primo punto
        > una citazione
        """
        #expect(IndexBuilder.preview(of: markdown) == "primo punto una citazione")
    }

    @Test func previewIsTruncated() {
        let preview = IndexBuilder.preview(of: String(repeating: "parola ", count: 50), maxLength: 20)
        #expect(preview.hasSuffix("…"))
        #expect(preview.count <= 21)
    }

    @Test func entriesAreNumberedInPageOrder() {
        let folder = Folder(name: "Lavoro", pages: [
            Page(title: "Primo", fileName: "Primo.md", body: "# A\n#### troppo profondo"),
            Page(title: "", fileName: "Senza titolo.md", body: "- [ ] fare"),
        ])
        let entries = IndexBuilder.entries(for: folder)
        #expect(entries.map(\.number) == [1, 2])
        #expect(entries.map(\.title) == ["Primo", "Senza titolo"])
        #expect(entries[0].headings.map(\.text) == ["A"])
        #expect(entries[1].openTasks == 1)
    }

    @Test func markdownDocumentLinksEveryPage() {
        let folder = Folder(name: "Lavoro", pages: [
            Page(title: "Riunione [Q4]", fileName: "Riunione [Q4].md", body: "# Agenda\n## Punto uno\n- [ ] follow-up"),
            Page(title: "Idee", fileName: "Idee.md", body: "testo"),
        ])
        let document = IndexBuilder.markdownDocument(for: folder, locale: Locale(identifier: "it_IT"))
        #expect(document.hasPrefix("# Lavoro\n"))
        #expect(document.contains("1. [Riunione \\[Q4\\]](Riunione%20%5BQ4%5D.md) — "))
        #expect(document.contains(" · 1 attività aperta\n"))
        #expect(document.contains("\n   - Agenda\n     - Punto uno\n"))
        #expect(document.contains("2. [Idee](Idee.md) — "))
    }

    @Test func emptyFolderDocument() {
        let document = IndexBuilder.markdownDocument(for: Folder(name: "Vuota"))
        #expect(document.contains("_Nessuna pagina._"))
    }
}
