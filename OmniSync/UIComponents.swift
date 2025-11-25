import SwiftUI

struct CardSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.headline)
                Spacer()
            }
            Divider()
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 110, alignment: .leading)
    }
}

struct StatusBadge: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(text.lowercased().contains("fail") ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                .frame(width: 10, height: 10)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
