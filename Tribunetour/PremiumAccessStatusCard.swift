import SwiftUI

struct PremiumAccessStatusCard: View {
    let isLoggedIn: Bool
    let unlockedPremiumTitles: [String]
    let lockedPremiumTitles: [String]
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 10) {
                accessColumn(
                    label: "Åbent nu",
                    value: unlockedSummary,
                    detail: unlockedDetail
                )
                accessColumn(
                    label: "Låst nu",
                    value: lockedSummary,
                    detail: lockedDetail
                )
            }

            if !isLoggedIn {
                Text("Log ind i Min tur for at se hvad der åbner sig for dig, og for at anmode om adgang til flere lande.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var unlockedSummary: String {
        unlockedPremiumTitles.isEmpty
            ? "Kun Danmark"
            : "Danmark + \(unlockedPremiumTitles.count) premiumland\(unlockedPremiumTitles.count == 1 ? "" : "e")"
    }

    private var unlockedDetail: String {
        unlockedPremiumTitles.isEmpty
            ? "Grundpakken er åben."
            : summarize(unlockedPremiumTitles)
    }

    private var lockedSummary: String {
        lockedPremiumTitles.isEmpty
            ? "Alt er åbent"
            : "\(lockedPremiumTitles.count) premiumland\(lockedPremiumTitles.count == 1 ? "" : "e") venter"
    }

    private var lockedDetail: String {
        lockedPremiumTitles.isEmpty
            ? "Ingen flere premium-pakker er låst."
            : summarize(lockedPremiumTitles)
    }

    private func summarize(_ items: [String], maxVisible: Int = 3) -> String {
        guard items.count > maxVisible else {
            return items.joined(separator: ", ")
        }
        let visible = items.prefix(maxVisible).joined(separator: ", ")
        return "\(visible) + \(items.count - maxVisible) mere"
    }

    private func accessColumn(label: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
