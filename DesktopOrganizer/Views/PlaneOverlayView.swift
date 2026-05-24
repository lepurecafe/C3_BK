import RealityKit
import SwiftUI

// ARKit 공간 인식을 실행하기 위해 ImmersiveSpace 안에 들어가는 View입니다.
//
// 화면에 무언가를 그리는 목적보다는,
// mixed ImmersiveSpace 안에서 RealityView를 유지하고 ARKit session을 시작하는 진입점 역할을 합니다.
//
// 교재 연결:
// - 1장: 전체 구조 패턴
// - 2장: 버튼으로 ImmersiveSpace 열기
struct PlaneOverlayView: View {
    // DesktopOrganizerApp에서 ControlPanelView와 같은 PlaneDetectionService 인스턴스를 전달받습니다.
    @Environment(PlaneDetectionService.self) private var planeService

    var body: some View {
        // 이 View 안에서 별도 window가 아닌 RealityKit entity를 직접 표시합니다.
        WorkspaceRealityView()
            .task {
                // ImmersiveSpace가 열리면 ARKit 평면 감지가 시작됩니다.
                // 감지 결과는 planeService.statusText와 detectedTablePlane에 저장됩니다.
                await planeService.startDetection()
            }
    }
}
