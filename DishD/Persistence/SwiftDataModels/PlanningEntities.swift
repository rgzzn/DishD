import Foundation
import SwiftData

@Model
final class ImportJobEntity {
    @Attribute(.unique) var id: UUID
    var stateRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var sourceTypeRawValue: String
    var secureFileReference: String?
    var originalURLString: String?
    var rawText: String?
    var currentPhase: String
    var progress: Double
    var errorMessage: String?
    var retryCount: Int
    var contentHash: String?
    var draftTitle: String?
    var temporaryFilesExpireAt: Date?
    init(id: UUID = UUID(), stateRawValue: String = "queued", createdAt: Date = .now, updatedAt: Date = .now, sourceTypeRawValue: String = "text", secureFileReference: String? = nil, originalURLString: String? = nil, rawText: String? = nil, currentPhase: String = "In coda", progress: Double = 0, errorMessage: String? = nil, retryCount: Int = 0, contentHash: String? = nil, draftTitle: String? = nil, temporaryFilesExpireAt: Date? = nil) { self.id = id; self.stateRawValue = stateRawValue; self.createdAt = createdAt; self.updatedAt = updatedAt; self.sourceTypeRawValue = sourceTypeRawValue; self.secureFileReference = secureFileReference; self.originalURLString = originalURLString; self.rawText = rawText; self.currentPhase = currentPhase; self.progress = progress; self.errorMessage = errorMessage; self.retryCount = retryCount; self.contentHash = contentHash; self.draftTitle = draftTitle; self.temporaryFilesExpireAt = temporaryFilesExpireAt }
}

@Model
final class MealPlanWeekEntity { @Attribute(.unique) var id: UUID; var weekStartDate: Date; @Relationship(deleteRule: .cascade, inverse: \MealPlanEntryEntity.week) var entries: [MealPlanEntryEntity]; init(id: UUID = UUID(), weekStartDate: Date, entries: [MealPlanEntryEntity] = []) { self.id = id; self.weekStartDate = weekStartDate; self.entries = entries } }
@Model
final class MealPlanEntryEntity { @Attribute(.unique) var id: UUID; var dayOffset: Int; var mealSlot: String; var plannedServings: Decimal?; var note: String?; var recipe: RecipeEntity?; var week: MealPlanWeekEntity?; init(id: UUID = UUID(), dayOffset: Int, mealSlot: String, plannedServings: Decimal? = nil, note: String? = nil, recipe: RecipeEntity? = nil) { self.id = id; self.dayOffset = dayOffset; self.mealSlot = mealSlot; self.plannedServings = plannedServings; self.note = note; self.recipe = recipe } }
@Model
final class GroceryListEntity { @Attribute(.unique) var id: UUID; var title: String; var createdAt: Date; @Relationship(deleteRule: .cascade, inverse: \GroceryItemEntity.list) var items: [GroceryItemEntity]; init(id: UUID = UUID(), title: String = "Lista della spesa", createdAt: Date = .now, items: [GroceryItemEntity] = []) { self.id = id; self.title = title; self.createdAt = createdAt; self.items = items } }
@Model
final class GroceryItemEntity { @Attribute(.unique) var id: UUID; var name: String; var quantityText: String?; var category: String; var checked: Bool; var manual: Bool; var sourceSummary: String?; var list: GroceryListEntity?; init(id: UUID = UUID(), name: String, quantityText: String? = nil, category: String = "Altro", checked: Bool = false, manual: Bool = false, sourceSummary: String? = nil) { self.id = id; self.name = name; self.quantityText = quantityText; self.category = category; self.checked = checked; self.manual = manual; self.sourceSummary = sourceSummary } }
