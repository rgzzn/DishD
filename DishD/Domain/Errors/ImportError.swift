import Foundation

enum ImportError: LocalizedError, Sendable {
    case invalidURL
    case unsafeURL
    case inaccessibleURL
    case unsupportedContent
    case responseTooLarge
    case noUsableContent
    case socialContentUnavailable
    case modelUnavailable(RecipeModelAvailability)
    case transcriptionUnavailable
    case extractionFailed
    case validationFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Il link non è valido"
        case .unsafeURL: "Questo indirizzo non può essere aperto"
        case .inaccessibleURL: "La pagina non è accessibile"
        case .unsupportedContent: "Il contenuto non è supportato"
        case .responseTooLarge: "La pagina è troppo grande"
        case .noUsableContent: "Non ho trovato una ricetta utilizzabile"
        case .socialContentUnavailable: "Il social ha condiviso soltanto il link"
        case .modelUnavailable: "Apple Intelligence non è disponibile"
        case .transcriptionUnavailable: "Trascrizione locale non disponibile"
        case .extractionFailed: "Non sono riuscito a creare la ricetta"
        case .validationFailed: "La bozza richiede un controllo manuale"
        case .cancelled: "Importazione annullata"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            "Controlla l’indirizzo oppure incolla direttamente il testo della ricetta."
        case .unsafeURL:
            "DishD apre solo pagine pubbliche HTTPS e non accede a reti locali."
        case .inaccessibleURL:
            "La piattaforma potrebbe richiedere un login. Aggiungi la didascalia, uno screenshot o il testo."
        case .unsupportedContent:
            "Prova con testo, un link pubblico o una pagina che contiene dati ricetta."
        case .responseTooLarge:
            "Incolla la parte utile della ricetta invece dell’intera pagina."
        case .noUsableContent:
            "Aggiungi ingredienti e procedimento oppure passa all’inserimento manuale."
        case .socialContentUnavailable:
            "Da Instagram o TikTok condividi il video vero, la didascalia, oppure una registrazione dello schermo. DishD non aggira login o protezioni della piattaforma."
        case .modelUnavailable(let availability):
            availability.italianMessage
        case .transcriptionUnavailable:
            "Il video può ancora essere letto dai fotogrammi. Per risultati migliori aggiungi la didascalia o una trascrizione."
        case .extractionFailed:
            "Riprova oppure importa comunque il testo e completa i campi manualmente."
        case .validationFailed:
            "Controlla ingredienti e passaggi prima di salvare."
        case .cancelled:
            nil
        }
    }
}
