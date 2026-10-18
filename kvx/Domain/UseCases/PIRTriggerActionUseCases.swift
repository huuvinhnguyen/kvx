import Foundation

struct PIRTriggerActionUseCases {
    let repository: any PIRTriggerActionRepository

    func load(chipID: String) async throws -> PIRTriggerSnapshot {
        async let configuration = repository.configuration(chipID: chipID)
        async let targets = repository.targets(chipID: chipID)
        return try await PIRTriggerSnapshot(configuration: configuration, targets: targets)
    }

    func create(chipID: String, draft: PIRTriggerActionDraft) async throws { try await repository.create(chipID: chipID, draft: draft) }
    func update(chipID: String, actionID: Int, draft: PIRTriggerActionDraft) async throws { try await repository.update(chipID: chipID, actionID: actionID, draft: draft) }
    func delete(chipID: String, actionID: Int) async throws { try await repository.delete(chipID: chipID, actionID: actionID) }
    func reorder(chipID: String, actionIDs: [Int]) async throws { try await repository.reorder(chipID: chipID, actionIDs: actionIDs) }
    func migrateLegacy(chipID: String) async throws { try await repository.migrateLegacy(chipID: chipID) }
}
