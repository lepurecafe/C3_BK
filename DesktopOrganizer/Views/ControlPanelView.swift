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
    @State private var showResetAlert = false
    @State private var storageErrorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            sensingStatusView

            HStack(spacing: 12) {
                // 박스 생성 흐름:
                // 버튼 탭 -> createBox() -> SwiftData 저장 -> BoxPayload 생성 -> boxWindow 열기
                Button("박스 등장") {
                    createBox()
                }
                .buttonStyle(.borderedProminent)

                // 메모 생성 흐름:
                // 버튼 탭 -> showMemoEditor true -> sheet 표시 -> MemoEditorSheet에서 Create 처리
                Button("메모 작성") {
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

            #if DEBUG
            Divider()
            Button("데이터 초기화", role: .destructive) {
                showResetAlert = true
            }
            .font(.caption)
            .foregroundStyle(.red)
            #endif
        }
        .padding(20)
        .alert("데이터 초기화", isPresented: $showResetAlert) {
            Button("취소", role: .cancel) {}
            Button("전부 삭제", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("저장된 박스와 메모가 전부 삭제됩니다.")
        }
        .alert("저장 실패", isPresented: storageErrorBinding) {
            Button("확인", role: .cancel) {
                storageErrorMessage = nil
            }
        } message: {
            Text(storageErrorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
        .sheet(isPresented: $showMemoEditor) {
            MemoEditorSheet()
        }
    }

    private var sensingStatusView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSensingOpen ? .green : .gray)
                    .frame(width: 8, height: 8)

                // PlaneDetectionService가 갱신하는 상태 문구입니다.
                // PlaneOverlayView에서 ARKit update가 들어오면 이 텍스트가 바뀝니다.
                Text(planeService.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !isSensingOpen {
                Button("공간 인식 시작") {
                    startSensing()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
    }

    private var storageErrorBinding: Binding<Bool> {
        // SwiftUI의 alert(isPresented:)는 Binding<Bool>을 요구합니다.
        // 우리는 실제 오류 문구를 String?으로 들고 있으므로,
        // "문구가 있으면 alert를 보여준다"는 Bool 연결을 여기서 만들어 줍니다.
        Binding(
            get: { storageErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    storageErrorMessage = nil
                }
            }
        )
    }

    private func startSensing() {
        // 같은 ImmersiveSpace를 여러 번 열려고 하면 visionOS 상태가 꼬일 수 있으므로
        // 이미 열려 있다고 표시된 경우에는 아무 일도 하지 않습니다.
        guard !isSensingOpen else { return }
        isSensingOpen = true

        Task {
            // openImmersiveSpace는 즉시 성공/실패를 돌려주는 비동기 작업입니다.
            // 실패하면 사용자가 다시 누를 수 있도록 isSensingOpen을 false로 되돌립니다.
            let result = await openImmersiveSpace(id: "sensing")
            switch result {
            case .opened:
                break
            case .userCancelled, .error:
                isSensingOpen = false
                planeService.statusText = "공간 인식 시작 실패"
            @unknown default:
                isSensingOpen = false
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

        do {
            try modelContext.save()
        } catch {
            modelContext.delete(box)
            storageErrorMessage = error.localizedDescription
            return
        }

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

    private func resetAllData() {
        // @Query로 읽어온 현재 박스/메모를 모두 삭제합니다.
        // delete만 호출하면 메모리상의 변경일 뿐이고, save가 성공해야 실제 저장소에 반영됩니다.
        boxes.forEach { modelContext.delete($0) }
        memos.forEach { modelContext.delete($0) }

        do {
            try modelContext.save()
        } catch {
            storageErrorMessage = error.localizedDescription
        }
    }
}

#Preview(windowStyle: .automatic) {
    // Preview에서는 실제 앱의 modelContainer/environment가 자동으로 들어오지 않으므로
    // 미리보기 전용 in-memory SwiftData 저장소와 PlaneDetectionService를 직접 넣어줍니다.
    ControlPanelView()
        .modelContainer(for: [OrganizerBox.self, MemoItem.self], inMemory: true)
        .environment(PlaneDetectionService())
}
