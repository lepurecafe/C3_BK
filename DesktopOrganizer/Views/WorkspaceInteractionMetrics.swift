import CoreGraphics

// 여러 View가 함께 쓰는 상호작용 숫자 모음입니다.
//
// 숫자를 각 파일에 직접 쓰면 "72pt가 왜 72pt인지"를 찾기 어렵습니다.
// 그래서 드래그 거리처럼 앱 전체에서 의미가 있는 값은 여기 한곳에 모아 둡니다.
// 교재 10장: 드래그앤드롭으로 메모를 공간에 열기
enum WorkspaceInteractionMetrics {
    // 박스 안 메모 카드를 이 거리 이상 끌면 공간 메모로 펼칩니다.
    // 단위는 meter가 아니라 SwiftUI DragGesture가 주는 화면 point입니다.
    static let memoDragActivationDistance: CGFloat = 72
}
