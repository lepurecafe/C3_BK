import SwiftUI

// 박스에서 꺼낸 메모를 공간 카드처럼 보여주는 SwiftUI attachment들입니다.
//
// 교재 연결:
// - 10장: 드래그앤드롭으로 메모를 공간에 열기
// - 11장: SwiftUI 카드 UI를 공간 오브젝트처럼 다루기
// - 12장: 공간 오브젝트 닫기, 삭제, 이동하기
// - 14장: 실제 공간에 고정하기
struct SpatialMemoPreviewAttachment: View {
    let text: String
    let colorIndex: Int

    var body: some View {
        // 드래그 중 preview는 실제 열린 메모가 아니라 "놓으면 이렇게 열린다"는 미리보기입니다.
        // 그래서 버튼 입력을 받지 않고, 살짝 투명하게 보여줍니다.
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

    // 사용자가 메모 카드를 바라보거나 포인터를 올렸을 때 카드에 강조 효과를 주기 위한 순수 UI 상태입니다.
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
                        guard !isAnchored else {
                            // pin이 켜진 메모는 실제 공간에 고정된 것으로 보므로 드래그 입력을 무시합니다.
                            // 이동 함수에서도 한 번 더 막지만, UI 입구에서 먼저 막으면 불필요한 저장 시도를 줄일 수 있습니다.
                            return
                        }

                        onDragChanged(value.translation)
                    }
                    .onEnded { _ in
                        guard !isAnchored else {
                            // 고정된 상태에서는 드래그 종료 저장도 하지 않습니다.
                            return
                        }

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
        // xmark는 "데이터 삭제"가 아니라 "공간에서 접기"입니다.
        // 실제 삭제는 trash 버튼만 담당하므로 두 동작을 시각적으로 분리합니다.
        HStack(spacing: 10) {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("공간 메모 닫기")
            .accessibilityHint("메모를 공간에서 접고 고정 상태를 해제합니다. 메모 데이터는 박스 안에 남습니다.")

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("메모 삭제")

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

    // SpatialMemoPreviewAttachment와 SpatialMemoOpenedAttachment가 같은 카드 모양을 공유합니다.
    // preview는 opacity가 낮고 title이 있으며, opened card는 hover 상태에 따라 "보고 있음"을 표시합니다.
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
