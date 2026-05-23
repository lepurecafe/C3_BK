import SwiftUI

struct BoxControlAttachmentView: View {
    let boxName: String
    let isAnchored: Bool
    let onDelete: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.bordered)

            Text(boxName)
                .font(.caption)
                .lineLimit(1)
                .frame(minWidth: 64, maxWidth: 140)

            Button {
                onToggle()
            } label: {
                Image(systemName: isAnchored ? "pin.fill" : "pin")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(isAnchored ? .green : .gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassBackgroundEffect()
    }
}
