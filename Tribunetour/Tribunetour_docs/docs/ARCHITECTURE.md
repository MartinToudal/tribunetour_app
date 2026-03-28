# Architecture

## Overview
Tribunetour is a SwiftUI app built with a local-first architecture and optional cloud sync.

## AppState
Central coordinator responsible for:
- Loading clubs and fixtures
- Initialising stores
- Injecting shared state into views

Fixtures are loaded through a provider chain:
- Remote fixtures endpoint (optional, controlled by app config)
- Local `fixtures.csv` fallback if remote is unavailable/invalid
- Source/version is logged in debug builds for verification

## Persistence
- UserDefaults for fast local access
- CloudKit for backup & sync

## CloudKit
- Private database
- No login required
- Per-user isolated data

## Sync Conflict Policy
Visited data uses deterministic field-level merge rules:
- `visited`: boolean OR (true wins)
- `visitedDate`: earliest non-nil date wins
- `notes`: value from newest `record.updatedAt`
- `review`: value from newest `review.updatedAt`
- `photoFileNames`: union of local + remote
- `photoMetadata`: newest `photoMeta.updatedAt` per file wins
- `updatedAt`: max(local, remote)

Weekend plan sync uses retry on CloudKit `serverRecordChanged` to reduce transient write conflicts.
