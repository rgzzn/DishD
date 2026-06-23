import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum RecipeModelAvailability: Sendable, Equatable {
    case available
    case deviceNotCompatible
    case appleIntelligenceDisabled
    case modelPreparing
    case languageOrRegionUnsupported
    case temporarilyUnavailable

    var italianMessage: String {
        switch self {
        case .available: "Apple Intelligence è pronta per l’estrazione locale."
        case .deviceNotCompatible: "Questo dispositivo non supporta il modello locale richiesto."
        case .appleIntelligenceDisabled: "Apple Intelligence non è attiva su questo dispositivo."
        case .modelPreparing: "Il modello locale non è ancora pronto. Riprova tra poco."
        case .languageOrRegionUnsupported: "Lingua o regione non supportata dal modello locale."
        case .temporarilyUnavailable: "Il modello locale è temporaneamente non disponibile."
        }
    }
}

protocol ModelAvailabilityChecking: Sendable { func availability() async -> RecipeModelAvailability }

actor AppleSystemModelAvailabilityChecker: ModelAvailabilityChecking {
    func availability() async -> RecipeModelAvailability {
        #if canImport(FoundationModels)
        _ = SystemLanguageModel()
        return .available
        #else
        return .deviceNotCompatible
        #endif
    }
}
