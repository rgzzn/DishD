import Foundation
import FoundationModels
import OSLog

actor RecipeExtractionService {
    private let availabilityChecker: any ModelAvailabilityChecking
    private let validator: RecipeDraftValidator
    private let logger = Logger(subsystem: AppBrand.bundleIdentifier, category: "RecipeExtraction")

    init(
        availabilityChecker: any ModelAvailabilityChecking = AppleSystemModelAvailabilityChecker(),
        validator: RecipeDraftValidator = RecipeDraftValidator()
    ) {
        self.availabilityChecker = availabilityChecker
        self.validator = validator
    }

    func extractRecipe(
        from evidence: RecipeEvidenceBundle,
        locale: Locale = Locale(identifier: "it_IT")
    ) async throws -> RecipeDraft {
        let availability = await availabilityChecker.availability(for: locale)
        guard availability == .available else {
            throw ImportError.modelUnavailable(availability)
        }

        let model = SystemLanguageModel.default
        let session = LanguageModelSession(
            model: model,
            instructions: RecipePromptBuilder.systemInstructions
        )
        let prompt = RecipePromptBuilder.extractionPrompt(for: evidence)

        do {
            let generated = try await withThrowingTaskGroup(
                of: GeneratedRecipeDraft.self
            ) { group in
                group.addTask {
                    let response = try await session.respond(
                        to: prompt,
                        generating: GeneratedRecipeDraft.self
                    )
                    return response.content
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(45))
                    throw ImportError.extractionFailed
                }
                guard let first = try await group.next() else {
                    throw ImportError.extractionFailed
                }
                group.cancelAll()
                return first
            }
            let draft = map(generated, source: evidence.source)
            return try validator.validate(draft, evidence: evidence)
        } catch is CancellationError {
            throw ImportError.cancelled
        } catch {
            logger.error("Foundation Models extraction failed: \(String(describing: error), privacy: .public)")
            throw ImportError.extractionFailed
        }
    }

    private func map(
        _ generated: GeneratedRecipeDraft,
        source: RecipeSourceDraft
    ) -> RecipeDraft {
        let servingsRange = DecimalParser.parseRange(generated.servingsText.numericToken)
        let normalizedTitle = generated.title.replacingOccurrences(
            of: #"(?i)\s+(?:per\s+)?\d+(?:[,.]\d+)?\s*(?:porzioni|persone)?\s*$"#,
            with: "",
            options: .regularExpression
        )

        return RecipeDraft(
            isRecipe: generated.isRecipe,
            title: normalizedTitle.isEmpty ? generated.title : normalizedTitle,
            summary: generated.summary.nilIfBlank,
            languageCode: generated.languageCode.nilIfBlank ?? "it",
            servings: servingsRange.minimum,
            servingsLabel: generated.servingsText.nilIfBlank,
            prepTimeSeconds: generated.prepTimeMinutes.positiveSeconds,
            cookTimeSeconds: generated.cookTimeMinutes.positiveSeconds,
            totalTimeSeconds: generated.totalTimeMinutes.positiveSeconds,
            ingredientSections: generated.ingredientSections.map { section in
                IngredientSectionDraft(
                    title: section.title.nilIfBlank,
                    ingredients: section.ingredients.map { ingredient in
                        let quantityRange = DecimalParser.parseRange(ingredient.quantityText)
                        return IngredientDraft(
                            originalText: ingredient.originalText,
                            itemName: ingredient.itemName,
                            quantityText: ingredient.quantityText.nilIfBlank,
                            quantity: quantityRange.minimum,
                            quantityMax: quantityRange.maximum,
                            unit: ingredient.unitText.nilIfBlank,
                            preparation: ingredient.preparation.nilIfBlank,
                            optional: ingredient.optional,
                            confidence: ingredient.confidence,
                            evidenceIDs: ingredient.evidenceIDs
                        )
                    }
                )
            },
            steps: generated.steps.map { step in
                StepDraft(
                    instruction: step.instruction,
                    durationSeconds: step.durationMinutes.positiveSeconds,
                    temperatureValue: step.temperatureValue > 0 ? Decimal(step.temperatureValue) : nil,
                    temperatureUnit: step.temperatureUnit.nilIfBlank,
                    confidence: step.confidence,
                    evidenceIDs: step.evidenceIDs
                )
            },
            unresolved: generated.unresolvedFields.map {
                UnresolvedFieldDraft(
                    fieldName: $0.fieldName,
                    message: $0.message,
                    evidenceIDs: $0.evidenceIDs
                )
            },
            warnings: generated.warnings,
            source: source,
            confidence: generated.overallConfidence,
            extractionMethod: .foundationModels
        )
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var numericToken: String? {
        range(of: #"\d+(?:[,.]\d+)?"#, options: .regularExpression).map {
            String(self[$0])
        }
    }
}

private extension Int {
    var positiveSeconds: Int? {
        self > 0 ? self * 60 : nil
    }
}
