import Foundation
import CloudKit

/// Lille helper til VisitedStore-sync via CloudKit (Private DB)
final class CloudVisitedSync: VisitedSyncBackend {
    static let shared = CloudVisitedSync()

    // ✅ Brug eksplicit container-id (så vi ikke risikerer at default peger forkert)
    private let containerID = "iCloud.icloud.everystadium.Tribunetour"

    private let recordType = "VisitedStadium"
    private let photoRecordType = "PhotoVisited"

    private enum Keys {
        static let clubId = "clubId"
        static let visited = "visited"
        static let visitedDate = "visitedDate"
        static let notes = "notes"
        static let reviewJSON = "reviewJSON"
        static let updatedAt = "updatedAt"
    }

    private enum PhotoKeys {
        static let clubId = "clubId"
        static let fileName = "fileName"
        static let caption = "caption"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let image = "image"
    }

    private let container: CKContainer
    private let db: CKDatabase

    private init() {
        self.container = CKContainer(identifier: containerID)
        self.db = container.privateCloudDatabase
    }

    // MARK: - Debug

    func debugAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            dlog("☁️ CloudKit account status: \(status.rawValue) (0=couldNotDetermine,1=available,2=restricted,3=noAccount,4=temporarilyUnavailable)")
        } catch {
            dlog("☁️ CloudKit accountStatus error: \(error)")
        }
    }

    // MARK: - Public API

    func fetchAll() async throws -> [String: VisitedStore.Record] {
        var result: [String: VisitedStore.Record] = [:]

        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        var cursor: CKQueryOperation.Cursor? = nil

        repeat {
            let (records, nextCursor) = try await performQuery(query: query, cursor: cursor)
            for rec in records {
                guard let clubId = rec[Keys.clubId] as? String else { continue }

                let visited = (rec[Keys.visited] as? Int64).map { $0 != 0 } ?? false
                let visitedDate = rec[Keys.visitedDate] as? Date
                let notes = rec[Keys.notes] as? String ?? ""
                let review = decodeReview(from: rec[Keys.reviewJSON] as? String)
                let updatedAt = rec[Keys.updatedAt] as? Date ?? Date.distantPast

                result[clubId] = VisitedStore.Record(
                    visited: visited,
                    visitedDate: visitedDate,
                    notes: notes,
                    review: review,
                    updatedAt: updatedAt
                )
            }

            cursor = nextCursor
        } while cursor != nil

        return result
    }

    func upsert(clubId: String, record: VisitedStore.Record) async throws {
        let recordID = CKRecord.ID(recordName: clubId)
        var attempt = 0
        while true {
            attempt += 1

            let ck: CKRecord
            do {
                ck = try await db.record(for: recordID)
            } catch {
                ck = CKRecord(recordType: recordType, recordID: recordID)
            }

            applyVisitedFields(ck, clubId: clubId, record: record)

            do {
                _ = try await db.save(ck)
                return
            } catch {
                if attempt < 3, isServerRecordChanged(error) {
                    continue
                }
                throw error
            }
        }
    }

    func delete(clubId: String) async throws {
        let recordID = CKRecord.ID(recordName: clubId)
        _ = try await db.deleteRecord(withID: recordID)
    }

    func fetchAllPhotos() async throws -> [VisitedRemotePhotoPayload] {
        var result: [VisitedRemotePhotoPayload] = []
        let query = CKQuery(recordType: photoRecordType, predicate: NSPredicate(value: true))
        var cursor: CKQueryOperation.Cursor? = nil

        repeat {
            let (records, nextCursor) = try await performQuery(query: query, cursor: cursor)
            for rec in records {
                guard
                    let clubId = rec[PhotoKeys.clubId] as? String,
                    let fileName = rec[PhotoKeys.fileName] as? String,
                    let asset = rec[PhotoKeys.image] as? CKAsset,
                    let fileURL = asset.fileURL,
                    let imageData = try? Data(contentsOf: fileURL)
                else { continue }

                let createdAt = rec[PhotoKeys.createdAt] as? Date ?? Date.distantPast
                let updatedAt = rec[PhotoKeys.updatedAt] as? Date ?? createdAt
                let caption = rec[PhotoKeys.caption] as? String ?? ""
                let meta = VisitedStore.Record.PhotoMeta(caption: caption, createdAt: createdAt, updatedAt: updatedAt)

                result.append(VisitedRemotePhotoPayload(clubId: clubId, fileName: fileName, meta: meta, imageData: imageData))
            }
            cursor = nextCursor
        } while cursor != nil

        return result
    }

    func fetchPhotoMetadata(for clubId: String) async throws -> [String: VisitedStore.Record.PhotoMeta] {
        let predicate = NSPredicate(format: "clubId == %@", clubId)
        let query = CKQuery(recordType: photoRecordType, predicate: predicate)
        var cursor: CKQueryOperation.Cursor? = nil
        var result: [String: VisitedStore.Record.PhotoMeta] = [:]

        repeat {
            let (records, nextCursor) = try await performQuery(query: query, cursor: cursor)
            for rec in records {
                guard let fileName = rec[PhotoKeys.fileName] as? String else { continue }
                let createdAt = rec[PhotoKeys.createdAt] as? Date ?? Date.distantPast
                let updatedAt = rec[PhotoKeys.updatedAt] as? Date ?? createdAt
                let caption = rec[PhotoKeys.caption] as? String ?? ""
                result[fileName] = VisitedStore.Record.PhotoMeta(caption: caption, createdAt: createdAt, updatedAt: updatedAt)
            }
            cursor = nextCursor
        } while cursor != nil

        return result
    }

    func upsertPhoto(
        clubId: String,
        fileName: String,
        imageData: Data,
        meta: VisitedStore.Record.PhotoMeta
    ) async throws {
        let recordID = CKRecord.ID(recordName: fileName)
        var attempt = 0
        while true {
            attempt += 1

            let ck: CKRecord
            do {
                ck = try await db.record(for: recordID)
            } catch {
                ck = CKRecord(recordType: photoRecordType, recordID: recordID)
            }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("tribunetour_photo_\(UUID().uuidString).jpg")
            try imageData.write(to: tempURL, options: .atomic)

            applyPhotoFields(
                ck,
                clubId: clubId,
                fileName: fileName,
                meta: meta,
                tempAssetURL: tempURL
            )

            do {
                _ = try await db.save(ck)
                try? FileManager.default.removeItem(at: tempURL)
                return
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                if attempt < 3, isServerRecordChanged(error) {
                    continue
                }
                throw error
            }
        }
    }

    func deletePhoto(fileName: String) async throws {
        let recordID = CKRecord.ID(recordName: fileName)
        _ = try await db.deleteRecord(withID: recordID)
    }

    // MARK: - Internal

    private func performQuery(query: CKQuery, cursor: CKQueryOperation.Cursor?) async throws -> ([CKRecord], CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { cont in
            let op: CKQueryOperation
            if let cursor {
                op = CKQueryOperation(cursor: cursor)
            } else {
                op = CKQueryOperation(query: query)
            }

            var fetched: [CKRecord] = []

            op.recordMatchedBlock = { _, res in
                if case .success(let record) = res {
                    fetched.append(record)
                }
            }

            op.queryResultBlock = { res in
                switch res {
                case .success(let nextCursor):
                    cont.resume(returning: (fetched, nextCursor))
                case .failure(let err):
                    cont.resume(throwing: err)
                }
            }

            self.db.add(op)
        }
    }

    private func encodeReview(_ review: VisitedStore.StadiumReview?) -> String? {
        guard let review else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(review) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func decodeReview(from raw: String?) -> VisitedStore.StadiumReview? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(VisitedStore.StadiumReview.self, from: data)
    }

    private func applyVisitedFields(_ record: CKRecord, clubId: String, record local: VisitedStore.Record) {
        record[Keys.clubId] = clubId as NSString
        record[Keys.visited] = (local.visited ? 1 : 0) as NSNumber
        if let d = local.visitedDate {
            record[Keys.visitedDate] = d as NSDate
        } else {
            record[Keys.visitedDate] = nil
        }
        record[Keys.notes] = local.notes as NSString
        if let reviewJSON = encodeReview(local.review) {
            record[Keys.reviewJSON] = reviewJSON as NSString
        } else {
            record[Keys.reviewJSON] = nil
        }
        record[Keys.updatedAt] = local.updatedAt as NSDate
    }

    private func applyPhotoFields(
        _ record: CKRecord,
        clubId: String,
        fileName: String,
        meta: VisitedStore.Record.PhotoMeta,
        tempAssetURL: URL
    ) {
        record[PhotoKeys.clubId] = clubId as NSString
        record[PhotoKeys.fileName] = fileName as NSString
        record[PhotoKeys.caption] = meta.caption as NSString
        record[PhotoKeys.createdAt] = meta.createdAt as NSDate
        record[PhotoKeys.updatedAt] = meta.updatedAt as NSDate
        record[PhotoKeys.image] = CKAsset(fileURL: tempAssetURL)
    }

    private func isServerRecordChanged(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == CKError.errorDomain else { return false }
        return ns.code == CKError.serverRecordChanged.rawValue
    }
}
