import AppKit
import SwiftUI

struct PaperCommands: Commands {
    let store: LibraryStore

    var body: some Commands {
        SidebarCommands()
        // Find (⌘F), spelling and substitutions for the editor.
        TextEditingCommands()

        CommandGroup(replacing: .newItem) {
            Button("Nuova pagina") { store.createPage() }
                .keyboardShortcut("n")
            Button("Nuova cartella") { store.createFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Mostra nel Finder") { store.revealSelection() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Button("Ricarica dal disco") { store.reload() }
                .keyboardShortcut("r", modifiers: [.command, .option])
        }

        // The actions are implemented by PaperTextView and reach it through
        // the responder chain, so they only act while the editor has focus.
        CommandMenu("Formato") {
            Button("Titolo") { send(#selector(PaperTextView.paperHeading1(_:))) }
                .keyboardShortcut("1")
            Button("Sottotitolo") { send(#selector(PaperTextView.paperHeading2(_:))) }
                .keyboardShortcut("2")
            Button("Sezione") { send(#selector(PaperTextView.paperHeading3(_:))) }
                .keyboardShortcut("3")
            Button("Testo") { send(#selector(PaperTextView.paperBodyText(_:))) }
                .keyboardShortcut("0")

            Divider()

            Button("Elenco puntato") { send(#selector(PaperTextView.paperBulletList(_:))) }
                .keyboardShortcut("7", modifiers: [.command, .shift])
            Button("Elenco numerato") { send(#selector(PaperTextView.paperNumberedList(_:))) }
                .keyboardShortcut("9", modifiers: [.command, .shift])
            Button("Checklist") { send(#selector(PaperTextView.paperChecklist(_:))) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("Segna come fatta") { send(#selector(PaperTextView.paperToggleTask(_:))) }
                .keyboardShortcut("u", modifiers: [.command, .shift])

            Divider()

            Button("Grassetto") { send(#selector(PaperTextView.paperBold(_:))) }
                .keyboardShortcut("b")
            Button("Corsivo") { send(#selector(PaperTextView.paperItalic(_:))) }
                .keyboardShortcut("i")
            Button("Barrato") { send(#selector(PaperTextView.paperStrikethrough(_:))) }
                .keyboardShortcut("x", modifiers: [.command, .shift])
            Button("Evidenziato") { send(#selector(PaperTextView.paperHighlight(_:))) }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            Button("Codice") { send(#selector(PaperTextView.paperCode(_:))) }
                .keyboardShortcut("c", modifiers: [.command, .option])

            Divider()

            Button("Inserisci data di oggi") { send(#selector(PaperTextView.paperInsertDate(_:))) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }

    private func send(_ action: Selector) {
        NSApp.sendAction(action, to: nil, from: nil)
    }
}
