import SwiftUI

// 메모 카드와 공간 메모가 공유하는 색상 팔레트입니다.
// 색상 자체는 저장하지 않고 MemoItem.colorIndex만 저장한 뒤, 화면에서는 이 배열을 기준으로 색을 복원합니다.
enum MemoPalette {
    // SwiftData에는 Color를 직접 저장하지 않고, 이 배열의 index만 저장합니다.
    // 이렇게 하면 색상 표현 방식이 바뀌어도 저장 모델은 단순한 Int로 유지됩니다.
    static let colors: [Color] = [.cyan, .green, .yellow, .pink]

    static func safeColorIndex(_ colorIndex: Int) -> Int {
        // 오래된 데이터나 잘못된 값이 들어와도 앱이 crash하지 않도록 0번 색으로 되돌립니다.
        guard colors.indices.contains(colorIndex) else {
            return 0
        }

        return colorIndex
    }

    static func color(for colorIndex: Int) -> Color {
        // 화면에서는 항상 이 함수를 통해 색을 꺼내도록 해서 out-of-range 방어를 한곳에 모읍니다.
        colors[safeColorIndex(colorIndex)]
    }
}
