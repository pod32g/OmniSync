import SwiftUI

// MARK: - Card Section
//
// Uses native SwiftUI Liquid Glass APIs introduced in macOS 26:
// - .glassEffect() modifier with .regular and .clear materials
// - GlassEffectContainer for grouping glass elements
// - .glassProminent button style

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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Field Label

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(minWidth: 110, alignment: .leading)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

// MARK: - Interactive Button Modifier
// Custom implementation until native .interactive() API is available

struct InteractiveTapScaleModifier: ViewModifier {
    let enabled: Bool
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && enabled ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if enabled { isPressed = true }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension View {
    func interactiveTapScale(enabled: Bool = true) -> some View {
        modifier(InteractiveTapScaleModifier(enabled: enabled))
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String

    private var isError: Bool {
        text.lowercased().contains("fail") || text.lowercased().contains("error")
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isError ? Color.red.opacity(0.25) : Color.green.opacity(0.25))
                .overlay(
                    Circle()
                        .stroke(isError ? Color.red.opacity(0.5) : Color.green.opacity(0.5), lineWidth: 1.5)
                )
                .frame(width: 10, height: 10)
            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.background.opacity(0.5))
                .background(.ultraThinMaterial, in: Capsule())
        )
    }
}
