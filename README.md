# Piece of Paper

App nativa per macOS per prendere appunti di lavoro.

Organizzi gli appunti in **cartelle** (un progetto, un cliente, un'area di lavoro) e ogni **pagina** che crei diventa una voce dell'**indice** della cartella: numerata, con i titoli interni come sotto-voci e il conteggio delle attività aperte.

## Funzionalità

- **Cartelle e indice**: la colonna centrale mostra l'indice della cartella. Le pagine si riordinano trascinandole, e un clic su un titolo dell'indice porta direttamente a quel punto della pagina.
- **Editor Markdown**: scrivi in Markdown e lo vedi già formattato (titoli, grassetto, corsivo, barrato, evidenziato, codice, citazioni, link).
- **Evidenziatore**: seleziona una frase e premi il pulsante con l'evidenziatore nella barra (o ⇧⌘H, o tasto destro → Evidenzia). Con il cursore dentro una frase evidenziata, lo stesso comando toglie l'evidenziazione. Nel file è salvata come `==frase==`, sintassi letta anche da Obsidian e Typora.
- **Elenchi e checklist**: Invio continua l'elenco, Tab/⇧Tab cambiano il livello, un clic sulla casella `[ ]` segna l'attività come fatta.
- **Ricerca** in tutte le cartelle, senza distinzione tra maiuscole e accenti.
- **Salvataggio automatico** mentre scrivi.
- **File tuoi**: tutto è salvato come file Markdown normali, leggibili anche senza l'app.

## Come sono salvati gli appunti

Per impostazione predefinita in `~/Documents/Piece of Paper` (si può cambiare nelle Impostazioni, ad esempio scegliendo una cartella in iCloud Drive):

```
Piece of Paper/
├── .library.json            ordine delle cartelle
└── Lavoro/                  una cartella dell'app = una cartella sul disco
    ├── .paper.json          ordine e dati delle pagine
    ├── INDICE.md            indice generato automaticamente
    ├── Kickoff progetto.md  una pagina = un file Markdown
    └── Follow-up.md
```

`INDICE.md` viene rigenerato a ogni modifica e contiene i link a tutte le pagine della cartella con i loro titoli interni. I file `.md` aggiunti a mano in una cartella diventano nuove pagine (⌥⌘R per ricaricare), quelli eliminati spariscono dall'indice.

## Requisiti

- macOS 15 o successivo
- Xcode 16 o successivo (Swift 6)

## Compilare ed eseguire

```bash
swift run PieceOfPaper
```

Per creare l'app (`build/Piece of Paper.app`):

```bash
Scripts/build-app.sh
```

Per crearla e copiarla in `/Applications`:

```bash
Scripts/build-app.sh --install
```

Per lavorare in Xcode basta aprire `Package.swift`.

## Scorciatoie

| Azione | Tasti |
| --- | --- |
| Nuova pagina | ⌘N |
| Nuova cartella | ⇧⌘N |
| Mostra nel Finder | ⇧⌘R |
| Ricarica dal disco | ⌥⌘R |
| Titolo / Sottotitolo / Sezione / Testo | ⌘1 / ⌘2 / ⌘3 / ⌘0 |
| Elenco puntato / numerato | ⇧⌘7 / ⇧⌘9 |
| Checklist / Segna come fatta | ⇧⌘L / ⇧⌘U |
| Grassetto / Corsivo | ⌘B / ⌘I |
| Evidenzia / togli evidenziazione | ⇧⌘H |
| Barrato / Codice | ⇧⌘X / ⌥⌘C |
| Data di oggi | ⇧⌘D |
| Apri un link | ⌘-clic |

## Struttura del progetto

```
Sources/
├── PaperKit/        modello, salvataggio su disco, indice, ricerca (senza UI)
└── PieceOfPaper/    app SwiftUI
    ├── Store/       stato dell'app e posizione dell'archivio
    ├── Views/       sidebar, indice, pagina, ricerca, impostazioni
    └── Editor/      editor Markdown basato su NSTextView
Tests/
├── PaperKitTests/   salvataggio, indice, formattazione, ricerca
└── PieceOfPaperTests/  comportamento dell'editor
Scripts/
├── build-app.sh     crea il bundle .app
└── make-icon.swift  disegna l'icona (Resources/AppIcon.icns)
```

## Test

```bash
swift test
```

Nelle build di debug l'app accetta `-libraryPath <cartella>` per usare un archivio di prova e `-snapshotPath <file.png>` per salvare un'immagine della finestra e chiudersi, utile per controllare la UI da script.
