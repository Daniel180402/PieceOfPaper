import AppKit
import PaperKit
import SwiftUI

struct SettingsView: View {
    @Environment(LibraryStore.self) private var store
    @AppStorage(SettingsKeys.editorFontSize) private var fontSize = SettingsKeys.defaultFontSize

    var body: some View {
        Form {
            Section {
                LabeledContent("Cartella") {
                    Text(store.rootURL.path(percentEncoded: false))
                        .truncationMode(.middle)
                        .lineLimit(1)
                        .textSelection(.enabled)
                        .help(store.rootURL.path(percentEncoded: false))
                }
                HStack {
                    if store.rootURL.standardizedFileURL != LibraryLocation.defaultURL.standardizedFileURL {
                        Button("Usa la cartella predefinita") { use(LibraryLocation.defaultURL) }
                    }
                    Spacer()
                    Button("Mostra nel Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.rootURL])
                    }
                    Button("Cambia…", action: chooseFolder)
                }
            } header: {
                Text("Archivio")
            } footer: {
                Text("Ogni cartella dell'app è una cartella sul disco e ogni pagina è un file Markdown. Scegli una cartella in iCloud Drive per avere gli appunti su tutti i tuoi Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Editor") {
                Slider(value: $fontSize, in: 12...22, step: 1) {
                    Text("Dimensione del testo")
                } minimumValueLabel: {
                    Text("A").font(.caption)
                } maximumValueLabel: {
                    Text("A").font(.title3)
                }
                LabeledContent("Dimensione attuale", value: "\(Int(fontSize)) pt")
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Usa questa cartella"
        panel.message = "Scegli dove salvare gli appunti. Se la cartella contiene già altri file, gli appunti andranno in una sottocartella «Piece of Paper»."
        panel.directoryURL = store.rootURL.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        use(LibraryLocation.libraryURL(forChosen: url))
    }

    private func use(_ url: URL) {
        LibraryLocation.save(url)
        store.changeRoot(to: url)
    }
}
