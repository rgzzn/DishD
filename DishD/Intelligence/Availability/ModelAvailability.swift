import Foundation
import FoundationModels

enum RecipeModelAvailability: Sendable, Equatable {
    case available
    case deviceNotCompatible
    case appleIntelligenceDisabled
    case modelPreparing
    case languageOrRegionUnsupported
    case temporarilyUnavailable

    var italianTitle: String {
        switch self {
        case .available: "Apple Intelligence pronta"
        case .deviceNotCompatible: "Dispositivo non compatibile"
        case .appleIntelligenceDisabled: "Apple Intelligence non attiva"
        case .modelPreparing: "Modello in preparazione"
        case .languageOrRegionUnsupported: "Lingua o regione non supportata"
        case .temporarilyUnavailable: "Modello non disponibile"
        }
    }

    var italianMessage: String {
        switch self {
        case .available:
            "Il modello locale è pronto. Le ricette vengono analizzate sul dispositivo."
        case .deviceNotCompatible:
            "Questo dispositivo non supporta il modello locale. Restano disponibili import web strutturato e inserimento manuale."
        case .appleIntelligenceDisabled:
            "Attiva Apple Intelligence nelle Impostazioni di sistema, oppure usa l’importazione deterministica."
        case .modelPreparing:
            "Il modello locale non è ancora pronto o è in download. Riprova tra poco."
        case .languageOrRegionUnsupported:
            "La lingua o la regione correnti non sono supportate dal modello locale."
        case .temporarilyUnavailable:
            "Il modello locale è temporaneamente non disponibile. Puoi continuare senza AI."
        }
    }
}

protocol ModelAvailabilityChecking: Sendable {
    func availability(for locale: Locale) async -> RecipeModelAvailability
}

actor AppleSystemModelAvailabilityChecker: ModelAvailabilityChecking {
    func availability(for locale: Locale = Locale(identifier: "it_IT")) async -> RecipeModelAvailability {
        let model = SystemLanguageModel.default
        guard model.supportsLocale(locale) else {
            return .languageOrRegionUnsupported
        }

        switch model.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotCompatible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceDisabled
        case .unavailable(.modelNotReady):
            return .modelPreparing
        @unknown default:
            return .temporarilyUnavailable
        }
    }
}
