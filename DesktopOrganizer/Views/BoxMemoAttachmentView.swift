import SwiftUI

struct BoxMemoAttachmentView: View {
    let boxName: String
    let memos: [MemoItem]
    let onMemoCreated: (String, Int) -> Void
    let onMemosDeleted: (Set<UUID>) -> Void
    let onMemoDragChanged: (MemoItem, CGSize) -> Void
    let onMemoDragEnded: (MemoItem, CGSize) -> Void
    let onMemoSelected: (MemoItem) -> Void

    @State private var isCreatingMemo = false
    @State private var isSelectingMemos = false
    @State private var selectedMemoIDs = Set<UUID>()
    @State private var draftMemoText = ""
    @State private var draftColorIndex = 0
    @State private var draggingMemoID: UUID?
    @State private var draggingMemoTranslation: CGSize = .zero
    @State private var hoveredMemoID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isCreatingMemo {
                memoComposer
            }

            memoList
        }
        .padding(14)
        .frame(width: 420, alignment: .topLeading)
        .glassBackgroundEffect()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(boxName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button {
                    isCreatingMemo.toggle()
                    if !isCreatingMemo {
                        clearDraft()
                    }
                } label: {
                    Label("메모 추가", systemImage: "plus")
                }

                Button {
                    isSelectingMemos.toggle()
                    if !isSelectingMemos {
                        selectedMemoIDs.removeAll()
                    }
                } label: {
                    Text(isSelectingMemos ? "완료" : "선택")
                }

                Button(role: .destructive) {
                    onMemosDeleted(selectedMemoIDs)
                    selectedMemoIDs.removeAll()
                    isSelectingMemos = false
                } label: {
                    Label("삭제", systemImage: "trash")
                }
                .disabled(selectedMemoIDs.isEmpty)
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
    }

    private var memoComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $draftMemoText)
                .frame(height: 74)
                .padding(6)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                ForEach(MemoPalette.colors.indices, id: \.self) { index in
                    ColorButton(
                        color: MemoPalette.colors[index],
                        isSelected: draftColorIndex == index
                    ) {
                        draftColorIndex = index
                    }
                }

                Spacer()

                Button("취소") {
                    isCreatingMemo = false
                    clearDraft()
                }

                Button("저장") {
                    onMemoCreated(draftMemoText, draftColorIndex)
                    isCreatingMemo = false
                    clearDraft()
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftMemoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .font(.caption)
        }
    }

    private var memoList: some View {
        Group {
            if memos.isEmpty {
                Text("박스 안에 메모가 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .center)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(memos) { memo in
                        MemoPreviewCard(
                            memo: memo,
                            isSelected: selectedMemoIDs.contains(memo.id),
                            isSelecting: isSelectingMemos,
                            isLookedAt: hoveredMemoID == memo.id,
                            isDragging: draggingMemoID == memo.id,
                            isReadyToOpen: draggingMemoID == memo.id &&
                                dragDistance(draggingMemoTranslation) >= WorkspaceInteractionMetrics.memoDragActivationDistance
                        )
                        .scaleEffect(hoveredMemoID == memo.id || draggingMemoID == memo.id ? 1.03 : 1)
                        .opacity(draggingMemoID == memo.id ? 0.72 : 1)
                        .animation(.snappy(duration: 0.18), value: draggingMemoID)
                        .animation(.snappy(duration: 0.18), value: hoveredMemoID)
                        .animation(.snappy(duration: 0.18), value: selectedMemoIDs)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .hoverEffect(.highlight)
                        .onHover { isHovered in
                            hoveredMemoID = isHovered ? memo.id : nil
                        }
                        .onTapGesture {
                            if isSelectingMemos {
                                toggleSelection(for: memo.id)
                            } else {
                                onMemoSelected(memo)
                            }
                        }
                        .highPriorityGesture(memoDragGesture(for: memo))
                    }
                }
            }
        }
    }

    private func memoDragGesture(for memo: MemoItem) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isSelectingMemos else {
                    return
                }

                draggingMemoID = memo.id
                draggingMemoTranslation = value.translation
                onMemoDragChanged(memo, value.translation)
            }
            .onEnded { value in
                guard !isSelectingMemos else {
                    clearDragState()
                    onMemoDragEnded(memo, .zero)
                    return
                }

                onMemoDragEnded(memo, value.translation)
                clearDragState()
            }
    }

    private func dragDistance(_ translation: CGSize) -> CGFloat {
        sqrt((translation.width * translation.width) + (translation.height * translation.height))
    }

    private func clearDragState() {
        draggingMemoID = nil
        draggingMemoTranslation = .zero
    }

    private func toggleSelection(for memoID: UUID) {
        if selectedMemoIDs.contains(memoID) {
            selectedMemoIDs.remove(memoID)
        } else {
            selectedMemoIDs.insert(memoID)
        }
    }

    private func clearDraft() {
        draftMemoText = ""
        draftColorIndex = 0
    }
}

private struct MemoPreviewCard: View {
    let memo: MemoItem
    let isSelected: Bool
    let isSelecting: Bool
    let isLookedAt: Bool
    let isDragging: Bool
    let isReadyToOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Text(String(memo.text.prefix(10)))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .blue : .secondary)
                } else if isDragging {
                    Image(systemName: isReadyToOpen ? "arrow.up.forward.app.fill" : "hand.draw")
                        .font(.caption)
                        .foregroundStyle(isReadyToOpen ? .green : .secondary)
                } else if isLookedAt {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }

            Text(memo.text)
                .font(.caption2)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary.opacity(0.82))

            if isDragging || isLookedAt {
                Text(dragHintText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(isReadyToOpen ? .green : .secondary)
            }
        }
        .padding(10)
        .frame(height: 104, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(MemoPalette.color(for: memo.colorIndex).opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: isDragging ? .black.opacity(0.25) : .clear, radius: 14, y: 8)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: borderWidth)
        }
    }

    private var borderColor: Color {
        if isReadyToOpen {
            return .green
        }

        if isDragging {
            return .white.opacity(0.85)
        }

        if isLookedAt {
            return .white.opacity(0.72)
        }

        if isSelected {
            return .blue
        }

        return Color.primary.opacity(0.12)
    }

    private var borderWidth: CGFloat {
        isSelected || isDragging || isLookedAt ? 2 : 1
    }

    private var dragHintText: String {
        if isReadyToOpen {
            return "놓으면 열림"
        }

        if isDragging {
            return "밖으로 드래그"
        }

        return "보고 있음"
    }
}
