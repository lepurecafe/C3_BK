import SwiftUI

// 메모 라벨의 실제 모양을 그리는 재사용 View입니다.
//
// 같은 View가 두 곳에서 쓰입니다.
// - MemoEditorSheet: 작성 중인 미리보기
// - MemoLabel WindowGroup: Create 후 공간에 뜨는 plain window
struct MemoLabelView: View {
    // 데이터 초기화가 발생하면 이미 떠 있는 메모 창도 같이 닫기 위해 공유 reset 신호를 봅니다.
    @State private var workspaceStore = WorkspaceEntityStore.shared
    // WindowGroup(for: MemoLabel.self)로 열린 현재 메모 창을 닫는 환경 함수입니다.
    @Environment(\.dismissWindow) private var dismissWindow
    // .disabled(true) 상태인지 확인합니다.
    // 생성된 plain window에서는 disabled 상태로 사용해서 읽기 전용 라벨처럼 보이게 합니다.
    @Environment(\.isEnabled) private var isEnabled
    // 부모가 가진 MemoLabel 값을 읽고 쓸 수 있는 연결입니다.
    // WindowGroup(for:)에서 받은 $memo나 Preview의 $memo가 여기로 들어옵니다.
    @Binding var memo: MemoLabel

    var body: some View {
        // LabelMaker 프로젝트의 LabelView 구조를 이어받은 부분입니다.
        // TextField를 쓰면 편집 가능한 라벨과 표시용 라벨을 같은 컴포넌트로 재사용할 수 있습니다.
        TextField("메모 내용을 입력하세요", text: $memo.text, axis: .vertical)
            // enabled 상태의 편집 화면에서는 정사각형 영역을 유지하고,
            // disabled 상태의 생성된 창에서는 내용과 패딩에 맞춰 높이를 줄입니다.
            .frame(width: 400, height: isEnabled ? 400 : nil)
            .padding(40)
            .padding()
            // MemoLabel의 색상 인덱스와 cornerRadius가 실제 라벨 배경이 되는 지점입니다.
            .background(
                memo.selectedColor().opacity(0.85),
                in: RoundedRectangle(cornerRadius: memo.cornerRadius)
            )
            .foregroundStyle(.black)
            .font(.system(size: 36, weight: .semibold))
            .multilineTextAlignment(.center)
            .onChange(of: workspaceStore.resetRevision) {
                dismissWindow(value: memo)
            }
    }
}

#Preview {
    // Preview에서도 Binding이 필요하므로 @State 값을 하나 만들고 $memo로 전달합니다.
    @Previewable @State var memo = MemoLabel(text: "메모 미리보기")

    MemoLabelView(memo: $memo)
        .disabled(true)
}
