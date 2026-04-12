import Foundation
import CloudKit

final class CloudWeekendPlanSync {
    static let shared = CloudWeekendPlanSync()

    private let containerID = "iCloud.icloud.everystadium.Tribunetour"
    private let recordType = "WeekendPlan"

    private enum Keys {
        static let fixtureIds = "fixtureIds"
        static let updatedAt = "updatedAt"
    }

    private let container: CKContainer?
    private let db: CKDatabase?

    private init() {
        if AppTestRuntime.isRunningAutomatedTests {
            self.container = nil
            self.db = nil
        } else {
            let container = CKContainer(identifier: containerID)
            self.container = container
            self.db = container.privateCloudDatabase
        }
    }

    private var recordID: CKRecord.ID { CKRecord.ID(recordName: "current") }

    func fetch() async throws -> WeekendPlanStore.PlanPayload? {
        guard let db else { return nil }
        do {
            let rec = try await db.record(for: recordID)

            let ids = rec[Keys.fixtureIds] as? [String] ?? []
            let updatedAt = rec[Keys.updatedAt] as? Date ?? .distantPast

            return WeekendPlanStore.PlanPayload(
                fixtureIds: Set(ids),
                updatedAt: updatedAt
            )
        } catch {
            return nil
        }
    }

    func upsert(payload: WeekendPlanStore.PlanPayload) async throws {
        guard let db else { return }
        var attempts = 0
        while true {
            attempts += 1

            let rec: CKRecord
            do {
                rec = try await db.record(for: recordID)
            } catch {
                rec = CKRecord(recordType: recordType, recordID: recordID)
            }

            rec[Keys.fixtureIds] = Array(payload.fixtureIds) as NSArray
            rec[Keys.updatedAt] = payload.updatedAt as NSDate

            do {
                _ = try await db.save(rec)
                return
            } catch {
                if attempts < 3, isServerRecordChanged(error) {
                    continue
                }
                throw error
            }
        }
    }

    private func isServerRecordChanged(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == CKError.errorDomain else { return false }
        return ns.code == CKError.serverRecordChanged.rawValue
    }
}
