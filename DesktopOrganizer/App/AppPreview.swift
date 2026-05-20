#if DEBUG
import SwiftData
import SwiftUI

// 앱의 핵심 화면을 한 Preview 창에서 빠르게 확인하기 위한 개발 전용 컨테이너입니다.
//
// DesktopOrganizerApp은 여러 Scene(WindowGroup, ImmersiveSpace)을 등록하므로
// Xcode Preview에서 전체 앱 흐름을 한 번에 열어 보기가 어렵습니다.
// 이 파일은 실제 앱 실행 코드와 분리된 DEBUG 전용 미리보기 허브입니다.
struct AppPreviewContainer: View {
    var body: some View {
        TabView {
            ControlPanelView()
                .modelContainer(for: [OrganizerBox.self, MemoItem.self], inMemory: true)
                .environment(PlaneDetectionService())
                .tabItem {
                    Label("ControlPanel", systemImage: "slider.horizontal.3")
                }

            BoxVolumeView(payload: BoxPayload(name: "Preview Box"))
                .tabItem {
                    Label("Box", systemImage: "shippingbox")
                }

            MemoEditorSheet()
                .modelContainer(for: [OrganizerBox.self, MemoItem.self], inMemory: true)
                .tabItem {
                    Label("Memo Editor", systemImage: "square.and.pencil")
                }

            MemoLabelView(
                memo: .constant(
                    MemoLabel(text: "메모 미리보기", colorIndex: 0, cornerRadius: 20)
                )
            )
            .disabled(true)
            .tabItem {
                Label("Memo Label", systemImage: "note.text")
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    AppPreviewContainer()
}
#endif
