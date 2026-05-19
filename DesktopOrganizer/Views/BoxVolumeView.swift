import RealityKit
import RealityKitContent
import SwiftUI

// 3D 여행 가방을 보여주는 volumetric window의 내용입니다.
//
// 열리는 경로:
// ControlPanelView.createBox()
// -> openWindow(id: "boxWindow", value: BoxPayload)
// -> DesktopOrganizerApp의 WindowGroup(id: "boxWindow")
// -> BoxVolumeView(payload:)
struct BoxVolumeView: View {
    // 박스 창을 열 때 전달된 값입니다.
    // 현재 뷰는 모델 표시와 회전에 집중하고 있어 payload를 직접 렌더링하지는 않지만,
    // 이후 이름 표시나 감지 위치 기반 배치로 확장할 때 여기서 사용할 수 있습니다.
    let payload: BoxPayload?

    // 드래그 중의 회전값입니다.
    @State private var horizontalRotation = CGFloat.zero
    @State private var verticalRotation = CGFloat.zero
    // 드래그가 끝난 뒤 누적된 회전값입니다.
    // 다음 드래그가 이전 회전 상태에서 이어지도록 저장합니다.
    @State private var endHorizontalRotation = CGFloat.zero
    @State private var endVerticalRotation = CGFloat.zero

    var body: some View {
        // RealityKitContent Swift Package의 .rkassets 안에 있는 TravelCaseScene을 로드합니다.
        // TravelCaseScene.usda가 실제 1890s_Travel_Case.usdz를 reference합니다.
        Model3D(named: "TravelCaseScene", bundle: realityKitContentBundle)
            // 좌우 드래그는 y축 회전으로, 위아래 드래그는 x축 회전으로 연결합니다.
            .rotation3DEffect(.degrees(horizontalRotation), axis: .y)
            .rotation3DEffect(.degrees(-verticalRotation), axis: .x)
            .gesture(
                DragGesture()
                    .onChanged { value in
//                        // translation 값에 이전 누적 회전을 더해 자연스럽게 이어지는 회전을 만듭니다.
                        horizontalRotation = value.translation.width + endHorizontalRotation
                        verticalRotation = value.translation.height + endVerticalRotation
                    }
                    .onEnded { _ in
//                        // 드래그가 끝난 지점을 다음 드래그의 시작 기준으로 저장합니다.
                        endHorizontalRotation = horizontalRotation
                        endVerticalRotation = verticalRotation
                    }
            )
    }
}

#Preview(windowStyle: .volumetric) {
    // Preview에서도 volumetric window 스타일로 모델 크기와 회전 동작을 확인할 수 있게 합니다.
    BoxVolumeView(payload: BoxPayload(name: "Preview Box"))
}
