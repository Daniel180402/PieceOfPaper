import PaperKit
import SwiftUI

struct SidebarView: View {
    @Environment(LibraryStore.self) private var store
    @State private var folderPendingDeletion: Folder?

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selectedFolderID) {
            Section("Cartelle") {
                ForEach(store.folders) { folder in
                    FolderRow(folder: folder)
                        .tag(folder.id)
                        .contextMenu {
                            Button("Nuova pagina") {
                                store.selectedFolderID = folder.id
                                store.createPage()
                            }
                            Divider()
                            Button("Rinomina") { store.renamingFolderID = folder.id }
                            Button("Mostra nel Finder") { store.revealInFinder(folderID: folder.id) }
                            Divider()
                            Button("Elimina cartella…", role: .destructive) { folderPendingDeletion = folder }
                        }
                }
                .onMove { store.moveFolders(from: $0, to: $1) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Button {
                    store.createFolder()
                } label: {
                    Label("Nuova cartella", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderless)
                .help("Crea una nuova cartella (⇧⌘N)")
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .confirmationDialog(
            "Eliminare la cartella «\(folderPendingDeletion?.name ?? "")»?",
            isPresented: Binding(
                get: { folderPendingDeletion != nil },
                set: { if !$0 { folderPendingDeletion = nil } }
            ),
            presenting: folderPendingDeletion
        ) { folder in
            Button("Sposta nel Cestino", role: .destructive) { store.deleteFolder(folder.id) }
        } message: { folder in
            Text("La cartella e le sue \(folder.pages.count) pagine verranno spostate nel Cestino.")
        }
    }
}

private struct FolderRow: View {
    let folder: Folder
    @Environment(LibraryStore.self) private var store
    @State private var draftName = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        if store.renamingFolderID == folder.id {
            TextField("Nome cartella", text: $draftName)
                .focused($isEditing)
                .onAppear {
                    draftName = folder.name
                    DispatchQueue.main.async { isEditing = true }
                }
                .onSubmit { store.renameFolder(folder.id, to: draftName) }
                .onExitCommand { store.renamingFolderID = nil }
                .onChange(of: isEditing) { _, editing in
                    if !editing, store.renamingFolderID == folder.id {
                        store.renameFolder(folder.id, to: draftName)
                    }
                }
        } else {
            Label(folder.name, systemImage: "folder")
                .badge(folder.pages.count)
        }
    }
}
