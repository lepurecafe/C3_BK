import SwiftData
import SwiftUI

// 앱의 시작점입니다.
// 이 파일을 먼저 읽으면 Desktop Organizer가 어떤 창과 공간을 등록하는지 한눈에 볼 수 있습니다.
//
// 전체 실행 흐름:
// 1. 기본 WindowGroup이 ControlPanelView를 띄웁니다.
// 2. ControlPanelView가 앱 시작 후 "sensing" ImmersiveSpace를 엽니다.
// 3. ImmersiveSpace 안의 PlaneOverlayView가 ARKit 평면 감지를 시작합니다.
// 4. 사용자가 버튼을 누르면 openWindow가 아래에 등록된 box/memo WindowGroup을 찾아 새 창을 엽니다.
// 5. SwiftData modelContainer가 생성된 박스와 메모를 저장해 다음 실행 때 목록으로 복원합니다.
@main
struct DesktopOrganizerApp: App {
    // ARKit 감지 상태를 앱 전체에서 공유하는 서비스입니다.
    // @State로 들고 있어 App 생명주기 동안 같은 인스턴스가 유지되고,
    // 아래 .environment(planeService)를 통해 ControlPanelView와 PlaneOverlayView가 같은 값을 봅니다.
    @State private var planeService = PlaneDetectionService()

    var body: some Scene {
        // 앱을 실행하면 처음 보이는 작은 조작 패널입니다.
        // 박스 생성, 메모 생성, 저장된 항목 재열기, ImmersiveSpace 열기 시작점이 모두 여기에 있습니다.
        WindowGroup {
            ControlPanelView()
        }
        // ControlPanel은 내용 크기만큼 작게 유지해서 도구 패널처럼 보이게 합니다.
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 200)
        // SwiftData 저장소를 앱에 연결합니다.
        // OrganizerBox와 MemoItem을 @Query로 읽고 modelContext.insert로 저장할 수 있게 됩니다.
        .modelContainer(for: [OrganizerBox.self, MemoItem.self])
        // ControlPanelView가 planeService.statusText와 tablePlaneOrigin을 읽을 수 있게 전달합니다.
        .environment(planeService)

        // "박스 생성" 버튼이 openWindow(id:value:)로 여는 volumetric window입니다.
        // BoxPayload는 이 창에 전달되는 값이며, 현재는 이름과 위치 후보를 담습니다.
        WindowGroup(id: "boxWindow", for: BoxPayload.self) { $payload in
            BoxVolumeView(payload: payload)
                .padding3D(.all, 10)
        }
        // volumetric window는 3D 부피를 가진 창입니다.
        // BoxVolumeView 안에서 RealityKitContent의 TravelCaseScene 모델을 표시합니다.
        .windowStyle(.volumetric)
        .windowResizability(.contentSize)
//        .defaultSize(width: 2.4, height: 2.35, depth: 10, in: .meters)

        // 메모는 값 기반 WindowGroup입니다.
        // MemoEditorSheet에서 openWindow(value: label)을 호출하면 이 Scene이 MemoLabelView를 새 창으로 띄웁니다.
        WindowGroup(for: MemoLabel.self) { $memo in
            MemoLabelView(memo: $memo)
                // 생성된 메모 창은 편집 창이 아니라 결과 라벨처럼 쓰기 위해 비활성화합니다.
                // MemoLabelView는 isEnabled 값을 보고 disabled 상태일 때 높이를 내용에 맞춥니다.
                .disabled(true)
        } defaultValue: {
            MemoLabel(text: "")
        }
        // plain window는 창 장식을 최소화해 라벨이 공간에 떠 있는 느낌을 줍니다.
        .windowResizability(.contentSize)
        .windowStyle(.plain)

        // ARKit 평면 감지를 실행하기 위한 혼합 몰입 공간입니다.
        // visionOS에서 주변 공간을 감지하려면 일반 WindowGroup만으로는 부족하고,
        // ImmersiveSpace 안에서 ARKitSession을 돌려야 합니다.
        ImmersiveSpace(id: "sensing") {
            PlaneOverlayView()
        }
        // .mixed는 앱 창과 실제 공간 인식을 같이 쓰는 모드입니다.
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        // PlaneOverlayView도 ControlPanelView와 같은 서비스 인스턴스를 사용해야
        // 감지 결과가 ControlPanel의 상태 텍스트와 박스 위치 계산에 반영됩니다.
        .environment(planeService)
    }
}
