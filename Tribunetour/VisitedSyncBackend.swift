import Foundation

struct VisitedRemotePhotoPayload {
    let clubId: String
    let fileName: String
    let meta: VisitedStore.Record.PhotoMeta
    let imageData: Data
}

protocol VisitedSyncBackend {
    func debugAccountStatus() async
    func fetchAll() async throws -> [String: VisitedStore.Record]
    func upsert(clubId: String, record: VisitedStore.Record) async throws
    func delete(clubId: String) async throws
    func fetchAllPhotos() async throws -> [VisitedRemotePhotoPayload]
    func fetchPhotoMetadata(for clubId: String) async throws -> [String: VisitedStore.Record.PhotoMeta]
    func upsertPhoto(
        clubId: String,
        fileName: String,
        imageData: Data,
        meta: VisitedStore.Record.PhotoMeta
    ) async throws
    func deletePhoto(fileName: String) async throws
}
