import SwiftData
import SwiftUI

// 앱을 실행했을 때 사용자가 처음 만나는 조작 패널입니다.
//
// 이 View의 책임:
// 1. ARKit 감지 상태를 보여줍니다.
// 2. 박스 생성 버튼으로 volumetric window를 엽니다.
// 3. 메모 생성 버튼으로 MemoEditorSheet를 띄웁니다.
// 4. SwiftData에 저장된 박스/메모를 @Query로 읽어 재열기 목록을 보여줍니다.
struct ControlPanelView: View {
    // DesktopOrganizerApp에 등록된 WindowGroup을 새 창으로 여는 SwiftUI 환경 함수입니다.
    @Environment(\.openWindow) private var openWindow
    // ARKit 평면 감지를 시작할 ImmersiveSpace를 여는 환경 함수입니다.
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    // DesktopOrganizerApp에서 environment로 전달한 공유 ARKit 서비스입니다.
    // statusText를 화면에 표시하고, 박스 생성 시 tablePlaneOrigin을 읽습니다.
    @Environment(PlaneDetectionService.self) private var planeService
    // SwiftData 저장 작업을 수행하는 context입니다.
    // createBox()에서 새 OrganizerBox를 insert/save합니다.
    @Environment(\.modelContext) private var modelContext

    // SwiftData에 저장된 박스 목록입니다.
    // 새 박스를 저장하면 이 배열이 자동으로 갱신되어 reopenList가 다시 그려집니다.
    @Query(sort: \OrganizerBox.createdAt) private var boxes: [OrganizerBox]
    // SwiftData에 저장된 메모 목록입니다.
    @Query(sort: \MemoItem.createdAt) private var memos: [MemoItem]

    // 메모 작성 sheet 표시 여부입니다.
    @State private var showMemoEditor = false
    // body가 다시 계산되어도 ImmersiveSpace를 반복해서 열지 않도록 막는 플래그입니다.
    @State private var isSensingOpen = false

    var body: some View {
        VStack(spacing: 16) {
            // PlaneDetectionService가 갱신하는 상태 문구입니다.
            // PlaneOverlayView에서 ARKit update가 들어오면 이 텍스트가 바뀝니다.
            Text(planeService.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                // 박스 생성 흐름:
                // 버튼 탭 -> createBox() -> SwiftData 저장 -> BoxPayload 생성 -> boxWindow 열기
                Button("박스 생성") {
                    createBox()
                }
                .buttonStyle(.borderedProminent)

                // 메모 생성 흐름:
                // 버튼 탭 -> showMemoEditor true -> sheet 표시 -> MemoEditorSheet에서 Create 처리
                Button("메모 생성") {
                    showMemoEditor = true
                }
                .buttonStyle(.bordered)
            }

            // 저장된 항목이 하나라도 있으면 재열기 목록을 보여줍니다.
            // 앱을 다시 실행한 뒤 이전 박스/메모를 찾는 MVP 복원 지점입니다.
            if !boxes.isEmpty || !memos.isEmpty {
                Divider()
                reopenList
            }
        }
        .padding(20)
        .sheet(isPresented: $showMemoEditor) {
            MemoEditorSheet()
        }
        .task {
            // UIApplicationSupportsMultipleScenes: true 로 인해 visionOS는 이전 실행의
            // scene session을 복원합니다. ImmersiveSpace도 복원 대상이므로,
            // 새 앱이 시작될 때 시스템이 space를 자동 복원하는 동시에 여기서 또 열려고 하면 충돌합니다.
            // openImmersiveSpace 결과를 확인해서 이미 열려있는 경우를 처리합니다.
            guard !isSensingOpen else { return }
            isSensingOpen = true

            let result = await openImmersiveSpace(id: "sensing")
            switch result {
            case .opened:
                break
            case .userCancelled:
                isSensingOpen = false
            case .error:
                // scene restoration에 의해 space가 이미 관리되고 있는 경우이므로 열린 것으로 간주합니다.
                break
            @unknown default:
                break
            }
        }
    }

    private var reopenList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(boxes) { box in
                // 저장된 OrganizerBox를 다시 BoxPayload로 바꿔 volumetric window를 엽니다.
                // 저장 모델과 창 payload를 분리하면 SwiftData 모델을 window value로 직접 노출하지 않아도 됩니다.
                Button("📦 \(box.name)") {
                    openWindow(
                        id: "boxWindow",
                        value: BoxPayload(id: box.id, name: box.name)
                    )
                }
                .font(.caption)
            }

            ForEach(memos) { memo in
                // 저장된 MemoItem을 다시 MemoLabel 값으로 바꿔 plain 메모 창을 엽니다.
                Button("📝 \(memo.text.prefix(20))") {
                    openWindow(
                        value: MemoLabel(
                            id: memo.id,
                            text: memo.text,
                            colorIndex: memo.colorIndex,
                            cornerRadius: memo.cornerRadius
                        )
                    )
                }
                .font(.caption)
            }
        }
    }

    private func createBox() {
        // ARKit이 책상 후보를 찾았으면 그 위치를, 아직 못 찾았으면 fallback 위치를 받습니다.
        let origin = planeService.tablePlaneOrigin
        // 먼저 SwiftData에 박스 기록을 저장합니다.
        // 이 저장 덕분에 ControlPanel의 @Query 목록과 다음 앱 실행의 재열기 목록에 나타납니다.
        let box = OrganizerBox(name: "Box \(boxes.count + 1)")
        modelContext.insert(box)
        try? modelContext.save()

        // 창을 여는 데 필요한 값만 payload로 포장합니다.
        // posX/Y/Z는 이후 실제 공간 배치나 WorldAnchor 저장으로 확장할 수 있는 자리입니다.
        let payload = BoxPayload(
            id: box.id,
            name: box.name,
            posX: origin.x,
            posY: origin.y,
            posZ: origin.z
        )
        // DesktopOrganizerApp의 WindowGroup(id: "boxWindow", for: BoxPayload.self)을 찾아 새 창을 엽니다.
        openWindow(id: "boxWindow", value: payload)
    }
}

#Preview(windowStyle: .automatic) {
    // Preview에서는 실제 앱의 modelContainer/environment가 자동으로 들어오지 않으므로
    // 미리보기 전용 in-memory SwiftData 저장소와 PlaneDetectionService를 직접 넣어줍니다.
    ControlPanelView()
        .modelContainer(for: [OrganizerBox.self, MemoItem.self], inMemory: true)
        .environment(PlaneDetectionService())
}
