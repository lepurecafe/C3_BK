import SwiftUI

// 박스가 열렸을 때 박스 위에 붙는 메모 목록/작성 attachment입니다.
//
// 교재 연결:
// - 8장: entity 위에 목록 UI 붙이기
// - 9장: 박스 안에서 메모 생성하기
// - 10장: 드래그앤드롭으로 메모를 공간에 열기
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
    // 선택 모드는 여러 메모를 한 번에 삭제하기 위한 UI 상태입니다.
    // MemoItem 자체에 선택 여부를 저장하지 않는 이유는 선택이 앱 데이터가 아니라 잠깐의 화면 상태이기 때문입니다.
    @State private var selectedMemoIDs = Set<UUID>()
    @State private var draftMemoText = ""
    @State private var draftColorIndex = 0
    // 드래그 중인 카드와 누적 이동량입니다.
    // 이 값으로 카드 opacity, "놓으면 열림" 문구, 임시 preview 위치를 동시에 맞춥니다.
    @State private var draggingMemoID: UUID?
    @State private var draggingMemoTranslation: CGSize = .zero
    // visionOS hover 상태를 저장해 사용자가 어떤 메모를 바라보거나 가리키는지 표시합니다.
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
        // 교재 9장: 입력 중인 draft 상태와 SwiftData에 저장된 MemoItem을 분리합니다.
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
                            isOpenedInSpace: memo.isSpatiallyPresented,
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
                            } else if memo.isSpatiallyPresented {
                                // 이미 공간에 열린 메모는 같은 MemoItem을 두 번 펼치지 않습니다.
                                // 목록에는 "공간에 열림" 상태로 남겨 두고, 다시 열기 입력만 막습니다.
                                return
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
        // 교재 10장: 카드가 일정 거리 이상 드래그되면 공간 메모로 펼치는 custom drag-and-drop입니다.
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isSelectingMemos,
                      !memo.isSpatiallyPresented else {
                    // 선택 모드에서는 드래그가 선택/삭제 UX와 충돌하고,
                    // 이미 열린 메모는 중복 공간 메모가 생길 수 있어 드래그를 시작하지 않습니다.
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

                guard !memo.isSpatiallyPresented else {
                    clearDragState()
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
    let isOpenedInSpace: Bool
    let isLookedAt: Bool
    let isDragging: Bool
    let isReadyToOpen: Bool

    var body: some View {
        // 이 카드는 MemoItem을 직접 수정하지 않고, 부모가 계산해 준 상태값만 받아 표시합니다.
        // 그래서 같은 카드가 선택 모드, hover 상태, 드래그 상태, 이미 열린 상태를 모두 표현할 수 있습니다.
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
                } else if isOpenedInSpace {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
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

            if isOpenedInSpace || isDragging || isLookedAt {
                Text(dragHintText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(isReadyToOpen || isOpenedInSpace ? .green : .secondary)
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
        // 상태가 겹칠 때 가장 중요한 신호를 먼저 보여줍니다.
        // 예를 들어 이미 열린 메모는 hover보다 "공간에 열림" 초록 테두리가 더 중요합니다.
        if isOpenedInSpace {
            return .green.opacity(0.78)
        }

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
        isSelected || isOpenedInSpace || isDragging || isLookedAt ? 2 : 1
    }

    private var dragHintText: String {
        if isOpenedInSpace {
            return "공간에 열림"
        }

        if isReadyToOpen {
            return "놓으면 열림"
        }

        if isDragging {
            return "밖으로 드래그"
        }

        return "보고 있음"
    }
}
