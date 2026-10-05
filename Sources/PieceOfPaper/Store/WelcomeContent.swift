import PaperKit

/// Sample pages created the first time the app runs.
enum WelcomeContent {
    static func install(using storage: LibraryStorage) throws {
        var folder = try storage.createFolder(named: "Benvenuto")
        _ = try storage.createPage(titled: "Come funziona", body: howItWorks, in: &folder)
        _ = try storage.createPage(titled: "Esempio di riunione", body: meetingExample, in: &folder)
        _ = try storage.createPage(titled: "Scorciatoie", body: shortcuts, in: &folder)
        try storage.saveFolder(folder)
        try storage.saveFolderOrder([folder])
    }

    static let howItWorks = """
    # Cartelle e pagine

    A sinistra trovi le **cartelle**: creane una per progetto, cliente o area di lavoro.

    Ogni **pagina** che crei in una cartella diventa una voce del suo **indice**, numerata nell'ordine in cui le hai create. Puoi riordinarle trascinandole.

    # L'indice

    I titoli all'interno di una pagina (le righe che iniziano con `#`, `##` o `###`) compaiono nell'indice sotto la pagina: fai clic su un titolo per saltare direttamente a quel punto.

    L'indice mostra anche quante attività aperte ci sono in ogni pagina.

    # I tuoi file

    Gli appunti sono normali file Markdown nella cartella *Documenti/Piece of Paper*: ogni cartella dell'app è una cartella sul disco e ogni pagina è un file `.md`.

    In ogni cartella trovi anche `INDICE.md`, l'indice generato automaticamente con i link a tutte le pagine.

    Il salvataggio è automatico.
    """

    static let meetingExample = """
    # Partecipanti

    - Marta (prodotto)
    - Luca (sviluppo)

    # Decisioni

    1. Il rilascio slitta a **fine mese**
    2. La demo al cliente resta confermata

    # Prossimi passi

    - [ ] Inviare il riepilogo al cliente
    - [ ] Aggiornare la roadmap
    - [x] Prenotare la sala per la demo

    > Suggerimento: fai clic sulla casella di un'attività per segnarla come fatta.
    """

    static let shortcuts = """
    # Pagine e cartelle

    - ⌘N nuova pagina
    - ⇧⌘N nuova cartella
    - ⇧⌘R mostra nel Finder

    # Formato

    - ⌘1, ⌘2, ⌘3 titolo, sottotitolo, sezione · ⌘0 testo normale
    - ⌘B grassetto · ⌘I corsivo · ⇧⌘X barrato · ⇧⌘H evidenziato
    - ⇧⌘7 elenco puntato · ⇧⌘9 elenco numerato
    - ⇧⌘L checklist · ⇧⌘U segna attività come fatta
    - ⇧⌘D inserisce la data di oggi

    # Elenchi

    Premi Invio alla fine di un elenco per continuarlo, Invio su una voce vuota per terminarlo. Tab e ⇧Tab cambiano il livello della voce.
    """
}
