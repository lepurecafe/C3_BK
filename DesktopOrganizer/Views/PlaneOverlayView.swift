import RealityKit
import SwiftUI

// ARKit 공간 인식을 실행하기 위해 ImmersiveSpace 안에 들어가는 View입니다.
//
// 화면에 무언가를 그리는 목적보다는,
// mixed ImmersiveSpace 안에서 RealityView를 유지하고 ARKit session을 시작하는 진입점 역할을 합니다.
struct PlaneOverlayView: View {
    // DesktopOrganizerApp에서 ControlPanelView와 같은 PlaneDetectionService 인스턴스를 전달받습니다.
    @Environment(PlaneDetectionService.self) private var planeService

    var body: some View {
        // 지금은 감지된 plane을 시각화하지 않으므로 비어 있는 RealityView를 둡니다.
        // 이후 책상 위에 반투명 overlay를 표시하고 싶다면 이 클로저 안에서 Entity를 추가하면 됩니다.
        RealityView { _ in }
            .task {
                // ImmersiveSpace가 열리면 ARKit 평면 감지가 시작됩니다.
                // 감지 결과는 planeService.statusText와 detectedTablePlane에 저장됩니다.
                await planeService.startDetection()
            }
    }
}
