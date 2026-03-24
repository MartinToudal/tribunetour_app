import Foundation

enum AppVisitedMigrationAuthority {
    case appPrimaryDuringMigration
}

struct AppVisitedMergePolicy {
    let authority: AppVisitedMigrationAuthority

    static let appPrimaryDuringMigration = AppVisitedMergePolicy(authority: .appPrimaryDuringMigration)

    func merge(local: VisitedStore.Record, remote: VisitedStore.Record) -> VisitedStore.Record {
        switch authority {
        case .appPrimaryDuringMigration:
            return mergeAppPrimary(local: local, remote: remote)
        }
    }

    private func mergeAppPrimary(local: VisitedStore.Record, remote: VisitedStore.Record) -> VisitedStore.Record {
        let mergedVisited = local.visited || remote.visited

        let mergedVisitedDate: Date? = {
            switch (local.visitedDate, remote.visitedDate) {
            case let (l?, r?): return min(l, r)
            case let (l?, nil): return l
            case let (nil, r?): return r
            case (nil, nil): return nil
            }
        }()

        let mergedNotes: String = {
            if local.updatedAt > remote.updatedAt { return local.notes }
            if remote.updatedAt > local.updatedAt { return remote.notes }
            return local.notes.count >= remote.notes.count ? local.notes : remote.notes
        }()

        let mergedReview: VisitedStore.StadiumReview? = {
            switch (local.review, remote.review) {
            case let (l?, r?):
                if l.updatedAt > r.updatedAt { return l }
                if r.updatedAt > l.updatedAt { return r }
                return l.hasMeaningfulContent ? l : r
            case let (l?, nil):
                return l
            case let (nil, r?):
                return r
            case (nil, nil):
                return nil
            }
        }()

        let mergedPhotoNames = Array(Set(local.photoFileNames).union(remote.photoFileNames)).sorted()
        var mergedPhotoMeta = local.photoMetadata
        for (fileName, remoteMeta) in remote.photoMetadata {
            if let localMeta = mergedPhotoMeta[fileName] {
                if remoteMeta.updatedAt > localMeta.updatedAt {
                    mergedPhotoMeta[fileName] = remoteMeta
                } else if remoteMeta.updatedAt == localMeta.updatedAt {
                    mergedPhotoMeta[fileName] = localMeta.caption.count >= remoteMeta.caption.count ? localMeta : remoteMeta
                }
            } else {
                mergedPhotoMeta[fileName] = remoteMeta
            }
        }

        return VisitedStore.Record(
            visited: mergedVisited,
            visitedDate: mergedVisitedDate,
            notes: mergedNotes,
            review: mergedReview,
            photoFileNames: mergedPhotoNames,
            photoMetadata: mergedPhotoMeta,
            updatedAt: max(local.updatedAt, remote.updatedAt)
        )
    }
}
