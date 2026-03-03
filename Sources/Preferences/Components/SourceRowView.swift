import SwiftUI

struct SourceRowView: View {
    @ObservedObject var model: PreferencesViewModel
    let source: AISource

    var body: some View {
        let isEnabled = model.isSourceEnabled(source.name)
        let isExpanded = model.isSourceExpanded(source.name)
        let hasNotifications = !source.notificationDefinitions.isEmpty

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Toggle(source.name, isOn: Binding(
                    get: { isEnabled },
                    set: { model.sourceToggleChanged(source, enabled: $0) }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(BrandPalette.textPrimary)

                Spacer(minLength: 0)

                if isEnabled, hasNotifications {
                    Button {
                        model.toggleNotificationsSection(source.name)
                    } label: {
                        HStack(spacing: 6) {
                            Text("Notifications")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(BrandPalette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(BrandPalette.card.opacity(0.55))
                        )
                        .overlay(
                            Capsule()
                                .stroke(BrandPalette.primary.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if isEnabled, isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Notification Rules")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(BrandPalette.textSecondary)
                        .textCase(.uppercase)

                    ForEach(source.notificationDefinitions, id: \.id) { definition in
                        RuleRowView(model: model, sourceName: source.name, definition: definition)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BrandPalette.cardAlt.opacity(0.55))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(BrandPalette.primary.opacity(0.18), lineWidth: 1)
                        )
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BrandPalette.cardAlt.opacity(0.38))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BrandPalette.primary.opacity(isExpanded ? 0.22 : 0.14), lineWidth: 1)
                )
        )
    }
}
