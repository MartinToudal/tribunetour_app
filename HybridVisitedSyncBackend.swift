import Foundation

struct HybridVisitedSyncConfiguration {
    let primaryBackend: any VisitedSyncBackend
    let secondaryBackend: (any VisitedSyncBackend)?
    let mergePolicy: AppVisitedMergePolicy
    let mirrorWritesToSecondary: Bool
}

final class HybridVisitedSyncBackend: VisitedSyncBackend {
    private let configuration: HybridVisitedSyncConfiguration

    init(configuration: HybridVisitedSyncConfiguration) {
        self.configuration = configuration
    }

    func debugAccountStatus() async {
        await configuration.primaryBackend.debugAccountStatus()
        if let secondaryBackend = configuration.secondaryBackend {
            await secondaryBackend.debugAccountStatus()
        }
    }

    func fetchAll() async throws -> [String: VisitedStore.Record] {
        let primary = try await configuration.primaryBackend.fetchAll()
        guard let secondaryBackend = configuration.secondaryBackend else {
            return primary
        }

        do {
            let secondary = try await secondaryBackend.fetchAll()
            return merge(primary: primary, secondary: secondary)
        } catch SharedVisitedSyncBackendError.notConfigured {
            return primary
        } catch {
            dlog("Shared visited fetch fallback til primary: \(error)")
            return primary
        }
    }

    func upsert(clubId: String, record: VisitedStore.Record) async throws {
        try await configuration.primaryBackend.upsert(clubId: clubId, record: record)
        guard configuration.mirrorWritesToSecondary, let secondaryBackend = configuration.secondaryBackend else {
            return
        }

        do {
            try await secondaryBackend.upsert(clubId: clubId, record: record)
        } catch SharedVisitedSyncBackendError.notConfigured {
            dlog("Shared visited upsert er ikke konfigureret endnu for \(clubId)")
        } catch {
            dlog("Shared visited mirror upsert error for \(clubId): \(error)")
        }
    }

    func delete(clubId: String) async throws {
        try await configuration.primaryBackend.delete(clubId: clubId)
        guard configuration.mirrorWritesToSecondary, let secondaryBackend = configuration.secondaryBackend else {
            return
        }

        do {
            try await secondaryBackend.delete(clubId: clubId)
        } catch SharedVisitedSyncBackendError.notConfigured {
            dlog("Shared visited delete er ikke konfigureret endnu for \(clubId)")
        } catch {
            dlog("Shared visited mirror delete error for \(clubId): \(error)")
        }
    }

    func fetchAllPhotos() async throws -> [VisitedRemotePhotoPayload] {
        do {
            return try await configuration.primaryBackend.fetchAllPhotos()
        } catch SharedVisitedSyncBackendError.unsupportedPhotos {
            guard let secondaryBackend = configuration.secondaryBackend else {
                throw SharedVisitedSyncBackendError.unsupportedPhotos
            }
            return try await secondaryBackend.fetchAllPhotos()
        }
    }

    func fetchPhotoMetadata(for clubId: String) async throws -> [String: VisitedStore.Record.PhotoMeta] {
        do {
            return try await configuration.primaryBackend.fetchPhotoMetadata(for: clubId)
        } catch SharedVisitedSyncBackendError.unsupportedPhotos {
            guard let secondaryBackend = configuration.secondaryBackend else {
                throw SharedVisitedSyncBackendError.unsupportedPhotos
            }
            return try await secondaryBackend.fetchPhotoMetadata(for: clubId)
        }
    }

    func upsertPhoto(
        clubId: String,
        fileName: String,
        imageData: Data,
        meta: VisitedStore.Record.PhotoMeta
    ) async throws {
        do {
            try await configuration.primaryBackend.upsertPhoto(
                clubId: clubId,
                fileName: fileName,
                imageData: imageData,
                meta: meta
            )
        } catch SharedVisitedSyncBackendError.unsupportedPhotos {
            guard let secondaryBackend = configuration.secondaryBackend else {
                throw SharedVisitedSyncBackendError.unsupportedPhotos
            }
            try await secondaryBackend.upsertPhoto(
                clubId: clubId,
                fileName: fileName,
                imageData: imageData,
                meta: meta
            )
        }
    }

    func deletePhoto(fileName: String) async throws {
        do {
            try await configuration.primaryBackend.deletePhoto(fileName: fileName)
        } catch SharedVisitedSyncBackendError.unsupportedPhotos {
            guard let secondaryBackend = configuration.secondaryBackend else {
                throw SharedVisitedSyncBackendError.unsupportedPhotos
            }
            try await secondaryBackend.deletePhoto(fileName: fileName)
        }
    }

    private func merge(
        primary: [String: VisitedStore.Record],
        secondary: [String: VisitedStore.Record]
    ) -> [String: VisitedStore.Record] {
        var merged = primary
        for (clubId, secondaryRecord) in secondary {
            if let primaryRecord = merged[clubId] {
                merged[clubId] = configuration.mergePolicy.merge(local: primaryRecord, remote: secondaryRecord)
            } else {
                merged[clubId] = secondaryRecord
            }
        }
        return merged
    }
}
