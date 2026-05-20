import SwiftData
import SwiftUI

// 앱의 시작점입니다.
// 이 파일을 먼저 읽으면 Desktop Organizer가 어떤 창과 공간을 등록하는지 한눈에 볼 수 있습니다.
//
// 전체 실행 흐름:
// 1. 기본 WindowGroup이 ControlPanelView를 띄웁니다.
// 2. 사용자가 ControlPanelView의 "공간 인식 시작" 버튼을 누르면 "sensing" ImmersiveSpace를 엽니다.
// 3. ImmersiveSpace 안의 PlaneOverlayView가 ARKit 평면 감지를 시작합니다.
// 4. 사용자가 버튼을 누르면 openWindow가 아래에 등록된 box/memo WindowGroup을 찾아 새 창을 엽니다.
// 5. SwiftData modelContainer가 생성된 박스와 메모를 저장해 다음 실행 때 목록으로 복원합니다.
@main
struct DesktopOrganizerApp: App {
    // ARKit 감지 상태를 앱 전체에서 공유하는 서비스입니다.
    // @State로 들고 있어 App 생명주기 동안 같은 인스턴스가 유지되고,
    // 아래 .environment(planeService)를 통해 ControlPanelView와 PlaneOverlayView가 같은 값을 봅니다.
    @State var planeService = PlaneDetectionService()

    var body: some Scene {
        controlPanelScene
        boxWindowScene
        memoWindowScene
        sensingSpaceScene
    }
}
