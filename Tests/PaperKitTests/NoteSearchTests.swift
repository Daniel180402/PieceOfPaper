import Testing
@testable import PaperKit

@Suite struct NoteSearchTests {
    let folders = [
        Folder(name: "Lavoro", pages: [
            Page(title: "Budget", fileName: "Budget.md", body: "Rivedere i costi del trimestre"),
            Page(title: "Riunione", fileName: "Riunione.md", body: "Parlare del budget con la società"),
        ]),
    ]

    @Test func titleMatchesComeFirst() {
        let hits = NoteSearch.search("budget", in: folders)
        #expect(hits.map(\.title) == ["Budget", "Riunione"])
    }

    @Test func ignoresAccentsAndCase() {
        #expect(NoteSearch.search("SOCIETA", in: folders).map(\.title) == ["Riunione"])
    }

    @Test func requiresAllTerms() {
        #expect(NoteSearch.search("budget costi", in: folders).map(\.title) == ["Budget"])
        #expect(NoteSearch.search("budget assente", in: folders).isEmpty)
        #expect(NoteSearch.search("   ", in: folders).isEmpty)
    }

    @Test func snippetShowsTheMatch() {
        let hit = NoteSearch.search("società", in: folders).first
        #expect(hit?.snippet == "Parlare del budget con la società")
        #expect(hit?.folderName == "Lavoro")
    }
}
