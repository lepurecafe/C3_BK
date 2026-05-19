import SwiftData
import SwiftUI

// 새 메모를 만들 때 ControlPanel 위에 뜨는 작성 sheet입니다.
//
// 작성 흐름:
// 1. 사용자가 텍스트, 색상, 모서리 둥글기를 조절합니다.
// 2. previewMemo가 현재 입력값을 MemoLabel로 바꿔 미리보기를 보여줍니다.
// 3. Create를 누르면 MemoItem으로 SwiftData에 저장합니다.
// 4. 같은 값으로 MemoLabel을 만들어 plain window를 엽니다.
struct MemoEditorSheet: View {
    // sheet를 닫는 환경 함수입니다.
    @Environment(\.dismiss) private var dismiss
    // MemoLabel 값을 DesktopOrganizerApp의 WindowGroup(for: MemoLabel.self)에 전달합니다.
    @Environment(\.openWindow) private var openWindow
    // 생성된 메모를 SwiftData에 저장하기 위한 context입니다.
    @Environment(\.modelContext) private var modelContext

    // 사용자가 작성 중인 임시 UI 상태입니다.
    // 아직 Create를 누르기 전이므로 SwiftData에는 저장하지 않습니다.
    @State private var text = ""
    @State private var colorIndex = 0
    @State private var cornerRadius = 20.0

    // 입력 중인 값을 즉시 MemoLabel 형태로 바꿔 미리보기 라벨에 전달합니다.
    // 이 값은 저장용이 아니라 화면에 보여주기 위한 일시적인 값입니다.
    var previewMemo: MemoLabel {
        MemoLabel(
            text: text.isEmpty ? "메모 미리보기" : text,
            colorIndex: colorIndex,
            cornerRadius: cornerRadius
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("메모 작성")
                .font(.headline)

            // 실제 생성될 plain label과 같은 MemoLabelView를 재사용합니다.
            // .constant는 미리보기에서 사용자가 직접 텍스트를 편집하지 못하게 고정 Binding을 만듭니다.
            MemoLabelView(memo: .constant(previewMemo))
                .disabled(true)
                .frame(maxHeight: 180)

            // 메모 본문 입력 영역입니다.
            TextEditor(text: $text)
                .frame(height: 80)
                .padding(6)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                // MemoLabel.colors 배열을 기준으로 색상 버튼을 만듭니다.
                // colorIndex만 저장하면 MemoLabel과 MemoItem이 모두 Codable/SwiftData 친화적으로 유지됩니다.
                ForEach(MemoLabel.colors.indices, id: \.self) { index in
                    ColorButton(
                        color: MemoLabel.colors[index],
                        isSelected: colorIndex == index
                    ) {
                        colorIndex = index
                    }
                }
            }

            HStack {
                Text("모서리")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // 라벨 배경 RoundedRectangle의 cornerRadius를 조절합니다.
                Slider(value: $cornerRadius, in: 0...60)
            }

            HStack(spacing: 16) {
                Button("취소") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    createMemo()
                }
                .buttonStyle(.borderedProminent)
                // 빈 메모가 저장되거나 창으로 열리지 않도록 막습니다.
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }

    private func createMemo() {
        // 앞뒤 공백만 있는 입력은 실제 내용이 아니므로 제거 후 검사합니다.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 먼저 SwiftData 모델로 저장합니다.
        // 저장된 MemoItem은 ControlPanelView의 @Query 목록에 나타납니다.
        let memo = MemoItem(
            text: trimmed,
            colorIndex: colorIndex,
            cornerRadius: cornerRadius
        )
        modelContext.insert(memo)
        try? modelContext.save()

        // 저장 모델을 창 payload인 MemoLabel로 변환합니다.
        // openWindow(value:)는 이 값을 DesktopOrganizerApp의 MemoLabel WindowGroup으로 보냅니다.
        let label = MemoLabel(
            id: memo.id,
            text: trimmed,
            colorIndex: colorIndex,
            cornerRadius: cornerRadius
        )
        openWindow(value: label)
        // 창을 연 뒤 작성 sheet는 닫습니다.
        dismiss()
    }
}

#Preview {
    // Preview에서는 앱의 실제 SwiftData container가 없으므로 미리보기용 in-memory container를 넣습니다.
    MemoEditorSheet()
        .modelContainer(for: [OrganizerBox.self, MemoItem.self], inMemory: true)
}
