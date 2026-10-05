import PaperKit
import SwiftUI

/// The detail column: title and body of the selected page.
struct PageEditorView: View {
    let page: Page
    let folder: Folder
    @Environment(LibraryStore.self) private var store
    @AppStorage(SettingsKeys.editorFontSize) private var fontSize = SettingsKeys.defaultFontSize
    @FocusState private var titleFocused: Bool
    @State private var editorFocusRequest = 0
    @State private var confirmingDeletion = false

    /// Keep the header aligned with the editor text column.
    static let readableWidth = PaperTextView.readableWidth
    static let horizontalPadding = PaperTextView.minimumInset

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            MarkdownEditor(
                text: Binding(
                    get: { page.body },
                    set: { store.updateBody($0, of: page.id) }
                ),
                fontSize: fontSize,
                jump: store.jumpRequest?.pageID == page.id ? store.jumpRequest : nil,
                focusRequest: editorFocusRequest,
                onJumpHandled: { store.jumpRequest = nil }
            )
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(page.displayTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.revealInFinder(pageID: page.id)
                } label: {
                    Label("Mostra nel Finder", systemImage: "folder")
                }
                .help("Mostra il file della pagina nel Finder")

                Button {
                    confirmingDeletion = true
                } label: {
                    Label("Elimina pagina", systemImage: "trash")
                }
                .help("Sposta la pagina nel Cestino")
            }
        }
        .confirmationDialog("Eliminare la pagina «\(page.displayTitle)»?", isPresented: $confirmingDeletion) {
            Button("Sposta nel Cestino", role: .destructive) { store.deletePage(page.id) }
        } message: {
            Text("Il file della pagina verrà spostato nel Cestino.")
        }
        .onAppear {
            if store.newlyCreatedPageID == page.id {
                store.newlyCreatedPageID = nil
                DispatchQueue.main.async { titleFocused = true }
            }
        }
    }

    private var pageNumber: Int {
        (folder.pages.firstIndex { $0.id == page.id } ?? 0) + 1
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(folder.name) · pagina \(pageNumber) di \(folder.pages.count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(Page.untitled, text: Binding(
                get: { page.title },
                set: { store.updateTitle($0, of: page.id) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 28, weight: .bold))
            .focused($titleFocused)
            .onSubmit { editorFocusRequest += 1 }

            Text(metadata)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .frame(maxWidth: Self.readableWidth + 2 * Self.horizontalPadding, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private var metadata: String {
        let created = page.createdAt.formatted(date: .abbreviated, time: .omitted)
        let updated = page.updatedAt.formatted(date: .abbreviated, time: .shortened)
        let words = page.wordCount == 1 ? "1 parola" : "\(page.wordCount) parole"
        return "Creata il \(created) · Modificata \(updated) · \(words)"
    }
}
