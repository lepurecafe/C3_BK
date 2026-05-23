import SwiftUI

struct SpatialMemoPreviewAttachment: View {
    let text: String
    let colorIndex: Int

    var body: some View {
        SpatialMemoCard(
            text: text,
            colorIndex: colorIndex,
            opacity: 0.62,
            title: "놓으면 열림"
        )
        .allowsHitTesting(false)
    }
}

struct SpatialMemoOpenedAttachment: View {
    let title: String
    let text: String
    let colorIndex: Int
    let isAnchored: Bool
    let onClose: () -> Void
    let onDelete: () -> Void
    let onToggleAnchor: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void

    @State private var isLookedAt = false

    var body: some View {
        VStack(spacing: 8) {
            SpatialMemoCard(
                text: text,
                colorIndex: colorIndex,
                opacity: 0.9,
                title: nil,
                isLookedAt: isLookedAt
            )
            .contentShape(RoundedRectangle(cornerRadius: SpatialMemoCard.cornerRadius))
            .hoverEffect(.highlight)
            .onHover { isHovered in
                isLookedAt = isHovered
            }
            .scaleEffect(isLookedAt ? 1.03 : 1)
            .animation(.snappy(duration: 0.18), value: isLookedAt)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        onDragChanged(value.translation)
                    }
                    .onEnded { _ in
                        onDragEnded()
                    }
            )

            SpatialMemoControlBar(
                title: title,
                isAnchored: isAnchored,
                onClose: onClose,
                onDelete: onDelete,
                onToggleAnchor: onToggleAnchor
            )
        }
    }
}

private struct SpatialMemoControlBar: View {
    let title: String
    let isAnchored: Bool
    let onClose: () -> Void
    let onDelete: () -> Void
    let onToggleAnchor: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.bordered)

            Text(title)
                .font(.caption)
                .lineLimit(1)
                .frame(minWidth: 64, maxWidth: 140)

            Button {
                onToggleAnchor()
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

private struct SpatialMemoCard: View {
    static let cornerRadius: CGFloat = 12

    let text: String
    let colorIndex: Int
    let opacity: Double
    let title: String?
    var isLookedAt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label(title, systemImage: "arrow.up.forward.app.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            } else if isLookedAt {
                Label("보고 있음", systemImage: "eye.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }

            Text(text)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)
                .lineLimit(8)
        }
        .padding(24)
        .frame(width: 280, alignment: .topLeading)
        .frame(minHeight: 180, alignment: .topLeading)
        .background(
            safeMemoColor.opacity(opacity),
            in: RoundedRectangle(cornerRadius: Self.cornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .stroke(isLookedAt ? .white : .white.opacity(0.7), lineWidth: isLookedAt ? 3 : 2)
        }
        .shadow(
            color: isLookedAt ? .white.opacity(0.24) : .black.opacity(0.25),
            radius: isLookedAt ? 24 : 18,
            y: isLookedAt ? 6 : 10
        )
    }

    private var safeMemoColor: Color {
        MemoPalette.color(for: colorIndex)
    }
}
