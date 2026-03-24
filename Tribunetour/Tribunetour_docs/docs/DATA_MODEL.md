# Data Model

## Club
- id: String
- name: String
- division: String
- stadium: Stadium

## Stadium
- id: String
- name: String
- city: String
- latitude: Double
- longitude: Double

## VisitedStadium (CloudKit)
- recordName: clubId
- clubId: String
- visited: Bool
- visitedDate: Date?
- notes: String?
- review: JSON?
- photoFileNames: [String]
- photoMetadata: [String: PhotoMeta]
- updatedAt: Date

### Merge rules (local vs remote)
- visited: `local || remote`
- visitedDate: earliest non-nil date
- notes: newest record `updatedAt` wins
- review: newest review `updatedAt` wins
- photoFileNames: union
- photoMetadata: newest `PhotoMeta.updatedAt` per file
- updatedAt: max(local, remote)

## WeekendPlan (CloudKit)
- recordName: "current"
- fixtureIds: [String]
- updatedAt: Date
