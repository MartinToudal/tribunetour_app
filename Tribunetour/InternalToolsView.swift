import SwiftUI
import UIKit

struct InternalToolsView: View {
    @ObservedObject var visitedStore: VisitedStore
    let clubs: [Club]
    let fixtures: [Fixture]
    @EnvironmentObject private var appState: AppState

    @AppStorage("achievements.seenUnlockedIds") private var seenUnlockedIdsRaw: String = ""
    @AppStorage(NotificationPreferenceKeys.weekendReminderEnabled) private var weekendReminderEnabled: Bool = true
    @AppStorage(NotificationPreferenceKeys.midweekReminderEnabled) private var midweekReminderEnabled: Bool = true
    @AppStorage(NotificationPreferenceKeys.nextMissingStadiumReminderEnabled) private var nextMissingStadiumReminderEnabled: Bool = false
    @AppStorage(AppVisitedSyncRuntimeFlags.visitedSyncModeKey) private var visitedSyncModeRaw: String = AppVisitedSyncMode.cloudKitPrimary.rawValue
    @AppStorage(AppAuthConfiguration.supabaseURLKey) private var supabaseURL: String = ""
    @AppStorage(AppAuthConfiguration.supabaseAnonKeyKey) private var supabaseAnonKey: String = ""
    @AppStorage(AppAuthConfiguration.appBridgeURLKey) private var appBridgeURL: String = AppAuthConfiguration.default.appBridgeURLString
    @AppStorage(AppAuthConfiguration.redirectSchemeKey) private var redirectScheme: String = AppAuthConfiguration.default.redirectScheme
    @AppStorage(AppAuthConfiguration.redirectHostKey) private var redirectHost: String = AppAuthConfiguration.default.redirectHost
    @AppStorage(RemoteFixturesProvider.remoteURLKey) private var fixturesRemoteURLOverride: String = ""

    @State private var showExportToast = false
    @State private var showImportSheet = false
    @State private var importText: String = ""
    @State private var importError: String?
    @State private var showImportSuccess = false

    var body: some View {
        List {
            Section("Backup og gendannelse") {
                Button {
                    let json = visitedStore.exportJSON(pretty: true)
                    UIPasteboard.general.string = json
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showExportToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showExportToast = false
                        }
                    }
                } label: {
                    Label("Kopiér backup (JSON)", systemImage: "doc.on.doc")
                }

                Button {
                    importText = ""
                    importError = nil
                    showImportSheet = true
                } label: {
                    Label("Importér backup (JSON)", systemImage: "square.and.arrow.down")
                }
            }

            Section("Notifikationer") {
                Toggle("Torsdag kl. 20 (weekend)", isOn: $weekendReminderEnabled)
                    .onChange(of: weekendReminderEnabled) { _, newValue in
                        WeekendOpportunityNotifier.shared.setWeekendReminderEnabled(newValue)
                        refreshSchedules()
                    }

                Toggle("Mandag kl. 20 (midtugesuggest)", isOn: $midweekReminderEnabled)
                    .onChange(of: midweekReminderEnabled) { _, newValue in
                        WeekendOpportunityNotifier.shared.setMidweekReminderEnabled(newValue)
                        refreshSchedules()
                    }

                Toggle("Næste kamp på stadion du mangler", isOn: $nextMissingStadiumReminderEnabled)
                    .onChange(of: nextMissingStadiumReminderEnabled) { _, newValue in
                        WeekendOpportunityNotifier.shared.setNextMissingStadiumReminderEnabled(newValue)
                        refreshSchedules()
                    }

                Button {
                    Task {
                        await WeekendOpportunityNotifier.shared.sendTestNotificationInFiveSeconds(
                            fixtures: fixtures,
                            visitedVenueClubIds: visitedVenueClubIds
                        )
                    }
                } label: {
                    Label("Force test: Weekend (5 sek)", systemImage: "bell.badge")
                }

                Button {
                    Task {
                        await WeekendOpportunityNotifier.shared.sendMidweekTestNotificationInFiveSeconds(
                            fixtures: fixtures,
                            visitedVenueClubIds: visitedVenueClubIds
                        )
                    }
                } label: {
                    Label("Force test: Midtuge (5 sek)", systemImage: "bell.badge.fill")
                }

                Button {
                    Task {
                        await WeekendOpportunityNotifier.shared.sendNextMissingStadiumTestNotificationInFiveSeconds(
                            fixtures: fixtures,
                            visitedVenueClubIds: visitedVenueClubIds,
                            clubById: clubById
                        )
                    }
                } label: {
                    Label("Force test: Næste stadion (5 sek)", systemImage: "bell.circle")
                }
            }

            Section("Visited sync") {
                Picker("Sync-mode", selection: $visitedSyncModeRaw) {
                    ForEach(AppVisitedSyncMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }

                Text("Gaelder foerst efter genstart af appen. Brug kun CloudKit (legacy) hvis du specifikt tester overgangsadfaerd.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Auth") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Supabase URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://projekt-ref.supabase.co", text: $supabaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Supabase anon / publishable key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("sb_publishable_...", text: $supabaseAnonKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Redirect scheme")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("tribunetour", text: $redirectScheme)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Redirect host")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("auth-callback", text: $redirectHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("App bridge URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://tribunetour.dk/auth/app-callback", text: $appBridgeURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                let authConfiguration = AppAuthConfiguration.load()
                if let validationMessage = authConfiguration.supabaseURLValidationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if let bridgeValidationMessage = authConfiguration.appBridgeValidationMessage {
                    Text(bridgeValidationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if !authConfiguration.hasAnonKey {
                    Text("Supabase anon/publishable key mangler.")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("Auth-konfiguration ser komplet ud.")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Text("App-login sender magic link til web-bridge og hopper derefter videre til tribunetour://auth-callback.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Reference-data") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fixtures feed override (valgfri)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("https://tribunetour.dk/reference-data/fixtures.remote.json", text: $fixturesRemoteURLOverride)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                let configuration = AppAuthConfiguration.load()
                if fixturesRemoteURLOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Appen bruger automatisk fixtures-feed fra websitet: \(configuration.fixturesRemoteURL?.absoluteString ?? "ikke tilgængelig endnu")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Override er aktiv. Tom værdi genskaber automatisk URL ud fra app bridge.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let source = appState.fixturesLoadSource {
                    Text("Aktuel fixtures-kilde: \(sourceLabel(for: source))")
                        .font(.caption)
                        .foregroundStyle(source == .remote ? .green : .secondary)
                }

                if let remoteURL = appState.fixturesRemoteURL {
                    Text("Forsøgt remote URL: \(remoteURL.absoluteString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let version = appState.fixturesVersion, !version.isEmpty {
                    Text("Fixtures-version: \(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let reason = appState.fixturesFallbackReason,
                   appState.fixturesLoadSource == .localFallback,
                   !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Fallback-årsag: \(reason)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Achievements") {
                Button(role: .destructive) {
                    seenUnlockedIdsRaw = ""
                } label: {
                    Label("Nulstil achievement-toasts", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Interne værktøjer")
        .overlay(alignment: .top) {
            if showExportToast {
                Text("Backup kopieret")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.opacity)
            }
            if showImportSuccess {
                Text("Import gennemført")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showImportSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Indsæt JSON backup")
                        .font(.headline)

                    Text("Indsæt hele JSON-teksten herunder og tryk Importér.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $importText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 220)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.separator, lineWidth: 1)
                        )

                    if let importError {
                        Text(importError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("Import")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Annullér") { showImportSheet = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Importér") {
                            do {
                                try visitedStore.importJSON(importText)
                                showImportSheet = false
                                importError = nil

                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showImportSuccess = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showImportSuccess = false
                                    }
                                }
                            } catch {
                                importError = error.localizedDescription
                            }
                        }
                    }
                }
            }
        }
    }

    private var visitedVenueClubIds: Set<String> {
        Set(
            visitedStore.records
                .filter { $0.value.visited }
                .map { $0.key }
        )
    }

    private var clubById: [String: Club] {
        Dictionary(uniqueKeysWithValues: clubs.map { ($0.id, $0) })
    }

    private func refreshSchedules() {
        Task {
            await WeekendOpportunityNotifier.shared.refreshWeekendReminder(
                fixtures: fixtures,
                visitedVenueClubIds: visitedVenueClubIds,
                clubById: clubById
            )
        }
    }

    private func sourceLabel(for source: FixturesLoadResult.Source) -> String {
        switch source {
        case .remote:
            return "remote"
        case .localFallback:
            return "local fallback"
        }
    }
}
