import SwiftUI

// 메모 카드와 공간 메모가 공유하는 색상 팔레트입니다.
// 색상 자체는 저장하지 않고 MemoItem.colorIndex만 저장한 뒤, 화면에서는 이 배열을 기준으로 색을 복원합니다.
enum MemoPalette {
    static let colors: [Color] = [.cyan, .green, .yellow, .pink]

    static func safeColorIndex(_ colorIndex: Int) -> Int {
        guard colors.indices.contains(colorIndex) else {
            return 0
        }

        return colorIndex
    }

    static func color(for colorIndex: Int) -> Color {
        colors[safeColorIndex(colorIndex)]
    }
}
