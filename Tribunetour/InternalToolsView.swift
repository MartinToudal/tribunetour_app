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
    @AppStorage(AppAuthConfiguration.supabaseURLKey) private var supabaseURL: String = AppAuthConfiguration.default.supabaseURLString
    @AppStorage(AppAuthConfiguration.supabaseAnonKeyKey) private var supabaseAnonKey: String = AppAuthConfiguration.default.supabaseAnonKey
    @AppStorage(AppAuthConfiguration.appBridgeURLKey) private var appBridgeURL: String = AppAuthConfiguration.default.appBridgeURLString
    @AppStorage(AppAuthConfiguration.redirectSchemeKey) private var redirectScheme: String = AppAuthConfiguration.default.redirectScheme
    @AppStorage(AppAuthConfiguration.redirectHostKey) private var redirectHost: String = AppAuthConfiguration.default.redirectHost
    @AppStorage(RemoteFixturesProvider.remoteURLKey) private var fixturesRemoteURLOverride: String = ""
    @AppStorage(AppLeaguePackSettings.germanyTop3EnabledKey) private var germanyTop3Enabled: Bool = false

    @State private var showExportToast = false
    @State private var showImportSheet = false
    @State private var importText: String = ""
    @State private var importError: String?
    @State private var showImportSuccess = false
    @State private var premiumAdminEmail: String = ""
    @State private var premiumAdminSelectedPack: AppPremiumAdminPack = .premiumFull
    @State private var premiumAdminRows: [PremiumAccessAdminRow] = []
    @State private var premiumAdminRequestRows: [PremiumAccessRequestAdminRow] = []
    @State private var premiumAdminIsAdmin: Bool?
    @State private var premiumAdminMessage: String?
    @State private var premiumAdminIsLoading = false
    @State private var premiumAdminActiveRequestId: String?

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

            Section("Sync (internt)") {
                Picker("Sync-mode", selection: $visitedSyncModeRaw) {
                    ForEach(AppVisitedSyncMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }

                Text("Gaelder foerst efter genstart af appen. Brug kun 'Kun app-data' hvis du specifikt tester lokal fallback eller intern fejlfinding.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Auth override") {
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

                Text("Appen bruger nu standard auth-konfiguration fra bundle/build. Felterne her er kun til debug eller midlertidig override.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Premium admin") {
                if appState.authSession.snapshot.isAuthenticated {
                    if premiumAdminIsAdmin == true {
                        let openRequests = premiumAdminRequestRows.filter(\.isOpen)
                        let handledRequests = premiumAdminRequestRows.filter { !$0.isOpen }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Overblik")
                                .font(.caption.weight(.semibold))
                            Text("\(openRequests.count) åbne · \(handledRequests.count) behandlede")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if openRequests.isEmpty {
                            Text("Ingen åbne premium-anmodninger.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(openRequests) { request in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(request.email)
                                        .font(.subheadline.weight(.semibold))
                                    Text(request.packTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let message = request.message,
                                       !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(message)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let createdAt = request.createdAt {
                                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Button {
                                        Task { await approvePremiumAccessRequest(request) }
                                    } label: {
                                        if premiumAdminActiveRequestId == request.requestId {
                                            Label("Godkender...", systemImage: "hourglass")
                                        } else {
                                            Label("Godkend anmodning", systemImage: "checkmark.circle")
                                        }
                                    }
                                    .disabled(premiumAdminIsLoading || premiumAdminActiveRequestId != nil)
                                }
                            }
                        }

                        if !handledRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Senest behandlede")
                                    .font(.caption.weight(.semibold))
                                ForEach(Array(handledRequests.prefix(5))) { request in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(request.email)
                                            .font(.caption.weight(.semibold))
                                        Text("\(request.packTitle) · \(request.status == "handled" ? "Godkendt" : request.status)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        if let updatedAt = request.updatedAt {
                                            Text(updatedAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Brugerens e-mail")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("bruger@email.dk", text: $premiumAdminEmail)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                        }

                        Picker("Pakke", selection: $premiumAdminSelectedPack) {
                            ForEach(AppPremiumAdminPack.allCases) { pack in
                                Text(pack.title).tag(pack)
                            }
                        }

                        Button {
                            Task { await mutatePremiumAccess(grant: true) }
                        } label: {
                            Label("Tildel adgang", systemImage: "checkmark.seal")
                        }
                        .disabled(premiumAdminIsLoading || premiumAdminEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button(role: .destructive) {
                            Task { await mutatePremiumAccess(grant: false) }
                        } label: {
                            Label("Fjern adgang", systemImage: "xmark.seal")
                        }
                        .disabled(premiumAdminIsLoading || premiumAdminEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if premiumAdminRows.isEmpty {
                            Text("Ingen aktive premium-adgange hentet endnu.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(premiumAdminRows.filter(\.enabled)) { row in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.email)
                                        .font(.subheadline.weight(.semibold))
                                    Text(row.packTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else if premiumAdminIsAdmin == false {
                        Text("Den aktuelle bruger har ikke admin-adgang.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Tjekker admin-adgang...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await loadPremiumAdminState() }
                    } label: {
                        if premiumAdminIsLoading {
                            Label("Henter...", systemImage: "hourglass")
                        } else {
                            Label("Opdater premium admin", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(premiumAdminIsLoading)
                } else {
                    Text("Log ind under Min tur for at bruge premium admin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let premiumAdminMessage {
                    Text(premiumAdminMessage)
                        .font(.caption)
                        .foregroundStyle(premiumAdminMessage.contains("Fejl") ? .red : .green)
                }

                Text("Panelet er skjult i Interne værktøjer, men Supabase tjekker stadig, at den loggede bruger er admin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Reference-data") {
                Toggle("Tyskland top 3 (eksperimentel)", isOn: $germanyTop3Enabled)
                    .onChange(of: germanyTop3Enabled) { _, _ in
                        appState.loadData()
                    }

                Text("Slår Bundesliga, 2. Bundesliga og 3. Liga til i stadionlisten på denne enhed. Sync-data bruger stadig klub-id'er med landeprefix, fx de-bayern-munchen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
        .task(id: appState.authSession.snapshot.isAuthenticated) {
            if appState.authSession.snapshot.isAuthenticated {
                await loadPremiumAdminState()
            } else {
                premiumAdminIsAdmin = nil
                premiumAdminRows = []
                premiumAdminRequestRows = []
                premiumAdminMessage = nil
            }
        }
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

    private func loadPremiumAdminState() async {
        guard !premiumAdminIsLoading else { return }
        premiumAdminIsLoading = true
        defer { premiumAdminIsLoading = false }

        do {
            let backend = makePremiumAdminBackend()
            let isAdmin = try await backend.isCurrentUserAdmin()
            premiumAdminIsAdmin = isAdmin
            guard isAdmin else {
                premiumAdminRows = []
                premiumAdminRequestRows = []
                premiumAdminMessage = nil
                return
            }
            premiumAdminRows = try await backend.listPremiumAccess()
            premiumAdminRequestRows = try await backend.listPremiumAccessRequests()
            premiumAdminMessage = nil
        } catch {
            premiumAdminIsAdmin = false
            premiumAdminRows = []
            premiumAdminRequestRows = []
            premiumAdminMessage = "Fejl: \(error.localizedDescription)"
        }
    }

    private func mutatePremiumAccess(grant: Bool) async {
        let trimmedEmail = premiumAdminEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !premiumAdminIsLoading else { return }

        premiumAdminIsLoading = true
        defer { premiumAdminIsLoading = false }

        do {
            let backend = makePremiumAdminBackend()
            _ = grant
                ? try await backend.grant(email: trimmedEmail, pack: premiumAdminSelectedPack)
                : try await backend.revoke(email: trimmedEmail, pack: premiumAdminSelectedPack)
            premiumAdminRows = try await backend.listPremiumAccess()
            await appState.refreshLeaguePackAccess()
            premiumAdminMessage = grant
                ? "Adgang tildelt til \(trimmedEmail)."
                : "Adgang fjernet fra \(trimmedEmail)."
        } catch {
            premiumAdminMessage = "Fejl: \(error.localizedDescription)"
        }
    }

    private func approvePremiumAccessRequest(_ requestRow: PremiumAccessRequestAdminRow) async {
        guard !premiumAdminIsLoading, premiumAdminActiveRequestId == nil else { return }

        premiumAdminIsLoading = true
        premiumAdminActiveRequestId = requestRow.requestId
        defer {
            premiumAdminIsLoading = false
            premiumAdminActiveRequestId = nil
        }

        do {
            let backend = makePremiumAdminBackend()
            _ = try await backend.approveAccessRequest(requestId: requestRow.requestId)
            premiumAdminRows = try await backend.listPremiumAccess()
            premiumAdminRequestRows = try await backend.listPremiumAccessRequests()
            await appState.refreshLeaguePackAccess()
            premiumAdminMessage = "\(requestRow.email) har nu adgang til \(requestRow.packTitle)."
        } catch {
            premiumAdminMessage = "Fejl: \(error.localizedDescription)"
        }
    }

    private func makePremiumAdminBackend() -> SharedPremiumAdminBackend {
        let authConfiguration = AppAuthConfiguration.load()
        return SharedPremiumAdminBackend(
            configuration: SharedLeaguePackAccessConfiguration(
                baseURL: authConfiguration.supabaseURL,
                apiKey: authConfiguration.supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : authConfiguration.supabaseAnonKey,
                authTokenProvider: appState.authSession.authTokenProvider(using: appState.authClient),
                urlSession: .shared
            )
        )
    }
}
