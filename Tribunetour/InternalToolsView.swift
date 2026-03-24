import SwiftUI
import UIKit

struct InternalToolsView: View {
    @ObservedObject var visitedStore: VisitedStore
    let fixtures: [Fixture]

    @AppStorage("achievements.seenUnlockedIds") private var seenUnlockedIdsRaw: String = ""
    @AppStorage(NotificationPreferenceKeys.weekendReminderEnabled) private var weekendReminderEnabled: Bool = true
    @AppStorage(NotificationPreferenceKeys.midweekReminderEnabled) private var midweekReminderEnabled: Bool = true

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

    private func refreshSchedules() {
        Task {
            await WeekendOpportunityNotifier.shared.refreshWeekendReminder(
                fixtures: fixtures,
                visitedVenueClubIds: visitedVenueClubIds
            )
        }
    }
}
