import SwiftData
import SwiftUI

// DesktopOrganizerApp의 Scene modifier 체인을 분리한 파일입니다.
// App 본문은 Scene 목록만 보여주고, 각 Scene의 크기/스타일/환경 설정은 여기서 관리합니다.
//
// 처음 공부할 때는 이 파일을 "앱이 열 수 있는 창 목록표"로 보면 좋습니다.
// ControlPanelView에서 openWindow/openImmersiveSpace를 호출하면,
// SwiftUI는 여기 등록된 WindowGroup/ImmersiveSpace 중 맞는 항목을 찾아 엽니다.
extension DesktopOrganizerApp {
    var controlPanelScene: some Scene {
        // 앱을 실행하면 처음 보이는 작은 조작 패널입니다.
        // 박스 생성, 메모 생성, 저장된 항목 재열기, ImmersiveSpace 열기 시작점이 모두 여기에 있습니다.
        WindowGroup {
            ControlPanelView()
        }
        // ControlPanel은 내용 크기만큼 작게 유지해서 도구 패널처럼 보이게 합니다.
        .windowResizability(.contentSize)
        .defaultSize(width: 360, height: 260)
        // SwiftData 저장소를 앱에 연결합니다.
        // OrganizerBox와 MemoItem을 @Query로 읽고 modelContext.insert로 저장할 수 있게 됩니다.
        .modelContainer(for: [OrganizerBox.self, MemoItem.self])
        // ControlPanelView가 planeService.statusText와 tablePlaneOrigin을 읽을 수 있게 전달합니다.
        .environment(planeService)
    }

    var memoWindowScene: some Scene {
        // 메모는 값 기반 WindowGroup입니다.
        // MemoEditorSheet에서 openWindow(value: label)을 호출하면 이 Scene이 MemoLabelView를 새 창으로 띄웁니다.
        // id를 따로 쓰지 않아도 MemoLabel 타입 자체가 "이 값을 받을 창"을 찾는 기준이 됩니다.
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
    }

    var sensingSpaceScene: some Scene {
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
        .modelContainer(for: [OrganizerBox.self, MemoItem.self])
        .environment(planeService)
    }
}
