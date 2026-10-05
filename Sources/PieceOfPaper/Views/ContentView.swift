import PaperKit
import SwiftUI

struct ContentView: View {
    @Environment(LibraryStore.self) private var store
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        @Bindable var store = store

        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } content: {
            Group {
                if !store.searchText.isEmpty {
                    SearchResultsView()
                } else if let folder = store.selectedFolder {
                    FolderIndexView(folder: folder)
                } else {
                    ContentUnavailableView {
                        Label("Nessuna cartella", systemImage: "folder")
                    } description: {
                        Text("Crea una cartella per iniziare a prendere appunti.")
                    } actions: {
                        Button("Nuova cartella") { store.createFolder() }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 340, max: 520)
        } detail: {
            if let page = store.selectedPage, let folder = store.folder(containing: page.id) {
                PageEditorView(page: page, folder: folder)
                    .id(page.id)
            } else {
                ContentUnavailableView {
                    Label("Nessuna pagina aperta", systemImage: "doc.text")
                } description: {
                    Text("Scegli una pagina dall'indice o creane una nuova con ⌘N.")
                }
            }
        }
        .searchable(text: $store.searchText, placement: .sidebar, prompt: "Cerca negli appunti")
        // The index header and the page header already show where you are.
        .toolbar(removing: .title)
        .onChange(of: store.selectedFolderID) { store.folderSelectionDidChange() }
        #if DEBUG
        .onAppear { DebugSnapshot.store = store }
        #endif
        .onChange(of: store.selectedPageID) { store.pageSelectionDidChange() }
        .alert(
            "Si è verificato un problema",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            ),
            presenting: store.errorMessage
        ) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
    }
}
