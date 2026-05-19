import SwiftUI

// MemoEditorSheet에서 색상을 고를 때 사용하는 작은 원형 버튼입니다.
//
// 이 버튼은 색상 선택 상태를 직접 소유하지 않습니다.
// 부모인 MemoEditorSheet가 colorIndex를 가지고 있고, 버튼은 눌렸을 때 action으로 부모에게 알려줍니다.
struct ColorButton: View {
    // 원 안에 표시할 색입니다.
    let color: Color
    // 현재 선택된 색인지 여부입니다. 선택된 경우 흰색 테두리를 보여줍니다.
    var isSelected: Bool = false
    // 버튼을 눌렀을 때 부모가 실행할 동작입니다.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: isSelected ? 3 : 0)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    // 선택 상태와 비선택 상태를 나란히 확인하기 위한 미리보기입니다.
    HStack {
        ColorButton(color: .cyan, isSelected: true) {}
        ColorButton(color: .green) {}
    }
}
