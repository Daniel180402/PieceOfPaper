import SwiftUI

struct PaperCommands: Commands {
    let store: LibraryStore

    var body: some Commands {
        SidebarCommands()

        CommandGroup(replacing: .newItem) {
            Button("Nuova pagina") { store.createPage() }
                .keyboardShortcut("n")
            Button("Nuova cartella") { store.createFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Mostra nel Finder") { store.revealSelection() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}
