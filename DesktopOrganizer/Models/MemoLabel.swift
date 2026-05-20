import SwiftUI

// plain 메모 창을 열 때 전달하는 값 타입입니다.
//
// 역할:
// - MemoEditorSheet에서 사용자가 입력한 텍스트와 스타일을 담습니다.
// - openWindow(value:)로 DesktopOrganizerApp의 WindowGroup(for: MemoLabel.self)에 전달됩니다.
// - MemoLabelView가 이 값을 Binding으로 받아 실제 라벨 모양을 그립니다.
struct MemoLabel: Hashable, Codable, Identifiable {
    // SwiftData의 MemoItem id와 맞춰두면 저장된 메모를 다시 창으로 열 때 같은 항목임을 알 수 있습니다.
    var id: UUID = UUID()
    // 라벨에 표시될 내용입니다.
    var text: String = ""
    // Color는 Codable이 아니므로 실제 색 대신 배열 인덱스를 저장합니다.
    var colorIndex: Int = 0
    // 라벨 배경 RoundedRectangle의 모서리 둥글기입니다.
    var cornerRadius: Double = 20.0

    // 저장 가능한 colorIndex를 실제 SwiftUI Color로 바꾸는 계산 함수입니다.
    // MemoLabelView는 이 함수를 통해 배경색을 결정합니다.
    func selectedColor() -> Color {
        // 저장 데이터는 앱 버전이 바뀐 뒤에도 남아 있을 수 있습니다.
        // 예전 데이터의 colorIndex가 현재 colors 배열 범위를 벗어나면 crash가 날 수 있으므로,
        // 잘못된 값은 첫 번째 색으로 안전하게 돌립니다.
        guard MemoLabel.colors.indices.contains(colorIndex) else {
            return MemoLabel.colors[0]
        }

        return MemoLabel.colors[colorIndex]
    }

    // 사용자가 고를 수 있는 MVP 색상 목록입니다.
    // MemoEditorSheet의 색상 버튼과 MemoLabelView의 배경색이 같은 배열을 공유합니다.
    static let colors: [Color] = [.cyan, .green, .yellow, .pink]
}
