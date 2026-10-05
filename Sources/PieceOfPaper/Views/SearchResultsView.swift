import PaperKit
import SwiftUI

/// Replaces the folder index while the search field is not empty.
struct SearchResultsView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        let hits = NoteSearch.search(store.searchText, in: store.folders)

        Group {
            if hits.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
            } else {
                List(selection: Binding(
                    get: { store.selectedPageID },
                    set: { if let pageID = $0 { store.open(pageID: pageID) } }
                )) {
                    Section(hits.count == 1 ? "1 risultato" : "\(hits.count) risultati") {
                        ForEach(hits) { hit in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(hit.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Label(hit.folderName, systemImage: "folder")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !hit.snippet.isEmpty {
                                    Text(hit.snippet)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                            }
                            .padding(.vertical, 4)
                            .tag(hit.pageID)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Ricerca")
    }
}
