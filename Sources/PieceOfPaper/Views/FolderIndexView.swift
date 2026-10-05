import PaperKit
import SwiftUI

/// The middle column: the index of the selected folder, one entry per page.
struct FolderIndexView: View {
    let folder: Folder
    @Environment(LibraryStore.self) private var store
    @State private var pagePendingDeletion: IndexEntry?

    var body: some View {
        @Bindable var store = store
        let entries = IndexBuilder.entries(for: folder)

        Group {
            if entries.isEmpty {
                ContentUnavailableView {
                    Label("Nessuna pagina", systemImage: "doc.text")
                } description: {
                    Text("Ogni pagina che crei in «\(folder.name)» diventa una voce del suo indice.")
                } actions: {
                    Button("Nuova pagina") { store.createPage() }
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                List(selection: $store.selectedPageID) {
                    Section {
                        ForEach(entries) { entry in
                            IndexRow(entry: entry)
                                .tag(entry.pageID)
                                .contextMenu { contextMenu(for: entry) }
                        }
                        .onMove { store.movePages(in: folder.id, from: $0, to: $1) }
                    } header: {
                        IndexHeader(folder: folder, entries: entries)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(folder.name)
        .toolbar {
            ToolbarItem {
                Button {
                    store.createPage()
                } label: {
                    Label("Nuova pagina", systemImage: "square.and.pencil")
                }
                .help("Nuova pagina in «\(folder.name)» (⌘N)")
            }
        }
        .confirmationDialog(
            "Eliminare la pagina «\(pagePendingDeletion?.title ?? "")»?",
            isPresented: Binding(
                get: { pagePendingDeletion != nil },
                set: { if !$0 { pagePendingDeletion = nil } }
            ),
            presenting: pagePendingDeletion
        ) { entry in
            Button("Sposta nel Cestino", role: .destructive) { store.deletePage(entry.pageID) }
        } message: { _ in
            Text("Il file della pagina verrà spostato nel Cestino.")
        }
    }

    @ViewBuilder
    private func contextMenu(for entry: IndexEntry) -> some View {
        Button("Mostra nel Finder") { store.revealInFinder(pageID: entry.pageID) }
        let otherFolders = store.folders.filter { $0.id != folder.id }
        if !otherFolders.isEmpty {
            Menu("Sposta in") {
                ForEach(otherFolders) { destination in
                    Button(destination.name) { store.movePage(entry.pageID, toFolder: destination.id) }
                }
            }
        }
        Divider()
        Button("Elimina pagina…", role: .destructive) { pagePendingDeletion = entry }
    }
}

private struct IndexHeader: View {
    let folder: Folder
    let entries: [IndexEntry]

    var body: some View {
        let openTasks = entries.reduce(0) { $0 + $1.openTasks }
        VStack(alignment: .leading, spacing: 4) {
            Text("Indice")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(folder.name)
                .font(.system(.title, design: .serif).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(entries.count == 1 ? "1 pagina" : "\(entries.count) pagine")
                if openTasks > 0 {
                    Text("·")
                    Text(openTasks == 1 ? "1 attività aperta" : "\(openTasks) attività aperte")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

private struct IndexRow: View {
    let entry: IndexEntry
    @Environment(LibraryStore.self) private var store

    static let maxHeadings = 8

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(entry.number.formatted(.number.precision(.integerLength(2...))))
                .font(.system(.title3, design: .serif))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(minWidth: 26, alignment: .trailing)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if entry.openTasks > 0 {
                        Label("\(entry.openTasks)", systemImage: "circle")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
                            .help(entry.openTasks == 1 ? "1 attività aperta" : "\(entry.openTasks) attività aperte")
                    }
                }

                if !entry.headings.isEmpty {
                    outline
                } else if !entry.preview.isEmpty {
                    Text(entry.preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(entry.updatedAt.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private var outline: some View {
        let minLevel = entry.headings.map(\.level).min() ?? 1
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(entry.headings.prefix(Self.maxHeadings)) { heading in
                Button {
                    store.jump(to: heading, in: entry.pageID)
                } label: {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(width: 1, height: 12)
                        Text(heading.text)
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(heading.level == minLevel ? .subheadline : .caption)
                .foregroundStyle(.secondary)
                .padding(.leading, CGFloat(heading.level - minLevel) * 12)
                .help("Vai a «\(heading.text)»")
            }
            if entry.headings.count > Self.maxHeadings {
                Text("+ altri \(entry.headings.count - Self.maxHeadings) titoli")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
