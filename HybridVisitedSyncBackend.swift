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
        try await configuration.primaryBackend.fetchAll()
    }

    func upsert(clubId: String, record: VisitedStore.Record) async throws {
        try await configuration.primaryBackend.upsert(clubId: clubId, record: record)
    }

    func delete(clubId: String) async throws {
        try await configuration.primaryBackend.delete(clubId: clubId)
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
}
