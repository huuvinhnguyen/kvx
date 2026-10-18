import Foundation

protocol PIRTriggerActionRepository {
    func configuration(chipID: String) async throws -> PIRTriggerConfiguration
    func targets(chipID: String) async throws -> [PIRTriggerTarget]
    func create(chipID: String, draft: PIRTriggerActionDraft) async throws
    func update(chipID: String, actionID: Int, draft: PIRTriggerActionDraft) async throws
    func delete(chipID: String, actionID: Int) async throws
    func reorder(chipID: String, actionIDs: [Int]) async throws
    func migrateLegacy(chipID: String) async throws
}
