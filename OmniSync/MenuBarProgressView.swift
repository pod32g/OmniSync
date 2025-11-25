import SwiftUI

struct MenuBarProgressView: View {
    let progress: Double?

    var body: some View {
        if let progress {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 6)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(12, CGFloat(progress) * 60), height: 6)
            }
            .frame(width: 60, height: 8, alignment: .leading)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    MenuBarProgressView(progress: 0.4)
        .padding()
        .frame(width: 120)
}
