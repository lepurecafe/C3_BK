import SwiftData
import SwiftUI

// 앱을 실행했을 때 사용자가 처음 만나는 조작 패널입니다.
//
// 이 View의 책임:
// 1. 앱 시작 후 사용자 입력을 방해하지 않는 시점에 책상 인식용 ImmersiveSpace를 엽니다.
// 2. 사용자가 박스 이름을 입력하면 ImmersiveSpace 안에 entity 박스를 띄웁니다.
// 3. DEBUG 빌드에서는 저장된 박스/메모 개수를 확인하고 데이터를 초기화할 수 있게 합니다.
struct ControlPanelView: View {
    private enum PanelMode {
        case home
        case namingBox
    }

    // ARKit 평면 감지를 시작할 ImmersiveSpace를 여는 환경 함수입니다.
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    // DesktopOrganizerApp에서 environment로 전달한 공유 ARKit 서비스입니다.
    // statusText를 화면에 표시하고, 박스 생성 시 tablePlaneOrigin을 읽습니다.
    @Environment(PlaneDetectionService.self) private var planeService
    // ImmersiveSpace 안에 직접 표시할 entity 박스 요청을 관리합니다.
    @State private var workspaceStore = WorkspaceEntityStore.shared
    // SwiftData 저장 작업을 수행하는 context입니다.
    // createBox(named:)에서 새 OrganizerBox를 insert/save합니다.
    @Environment(\.modelContext) private var modelContext

    // SwiftData에 저장된 박스 목록입니다.
    // 새 박스를 저장하면 이 배열이 자동으로 갱신되어 DEBUG 요약과 workspace 복원에 반영됩니다.
    @Query(sort: \OrganizerBox.createdAt) private var boxes: [OrganizerBox]
    // SwiftData에 저장된 메모 목록입니다.
    @Query(sort: \MemoItem.createdAt) private var memos: [MemoItem]

    @State private var panelMode: PanelMode = .home
    @State private var draftBoxName = ""
    // body가 다시 계산되어도 ImmersiveSpace를 반복해서 열지 않도록 막는 플래그입니다.
    @State private var isSensingOpen = false
    @State private var showResetAlert = false
    @State private var storageErrorMessage: String?
    @State private var controlStatusText = "준비됨"
    @State private var isOpeningSensing = false

    var body: some View {
        VStack(spacing: 16) {
            sensingStatusView

            switch panelMode {
            case .home:
                homePanel
            case .namingBox:
                namingBoxPanel
            }

            #if DEBUG
            // 실기기 테스트 중 저장 상태를 빠르게 확인하기 위한 DEBUG 전용 요약입니다.
            if !boxes.isEmpty || !memos.isEmpty {
                Divider()
                storedItemsSummary
            }

            Divider()
            Button("데이터 초기화", role: .destructive) {
                controlStatusText = "초기화 확인 대기"
                showResetAlert = true
            }
            .font(.caption)
            .foregroundStyle(.red)
            #endif
        }
        .padding(20)
        .task {
            await openSensingAfterInitialInputWindow()
        }
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
    }

    private var sensingStatusView: some View {
        VStack(spacing: 6) {
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

            Button(isSensingOpen ? "책상 다시 인식" : "공간 인식 시작") {
                startSensing()
            }
            .buttonStyle(.bordered)
            .font(.caption)

            Text(controlStatusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var homePanel: some View {
        VStack(spacing: 18) {
            Text("안녕하세요. 당신의 친구 직박구리입니다.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button("박스 만들기") {
                draftBoxName = ""
                controlStatusText = "박스 이름 입력"
                panelMode = .namingBox
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var namingBoxPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("박스 이름")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("예: 회의 메모", text: $draftBoxName)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit {
                    Task {
                        await submitBoxName()
                    }
                }

            HStack(spacing: 10) {
                Button("취소") {
                    draftBoxName = ""
                    controlStatusText = "준비됨"
                    panelMode = .home
                }
                .buttonStyle(.bordered)

                Button("확인") {
                    Task {
                        await submitBoxName()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
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
        Task {
            if isSensingOpen {
                planeService.requestTableRescan()
                controlStatusText = "책상 다시 인식 요청"
            } else if isOpeningSensing {
                controlStatusText = "공간 여는 중..."
            } else {
                _ = await openSensingIfNeeded()
            }
        }
    }

    @MainActor
    private func openSensingAfterInitialInputWindow() async {
        // 앱 시작 직후 ImmersiveSpace/ARKit 초기화가 첫 TextField 입력과 겹치면 실기기에서
        // 이름 입력 반응이 늦어질 수 있어, 초기 화면이 안정된 뒤에만 자동으로 공간 인식을 시작합니다.
        try? await Task.sleep(for: .seconds(1.2))

        guard panelMode == .home else {
            controlStatusText = "이름 입력 후 공간 인식"
            return
        }

        _ = await openSensingIfNeeded()
    }

    @MainActor
    private func openSensingIfNeeded() async -> Bool {
        // 같은 ImmersiveSpace를 여러 번 열려고 하면 visionOS 상태가 꼬일 수 있으므로
        // 이미 열려 있다고 표시된 경우에는 새 요청을 보내지 않습니다.
        guard !isSensingOpen else {
            controlStatusText = "공간 이미 열림"
            return true
        }

        guard !isOpeningSensing else {
            controlStatusText = "공간 여는 중..."
            return false
        }

        isOpeningSensing = true
        controlStatusText = "공간 여는 중..."
        defer {
            isOpeningSensing = false
        }

        // openImmersiveSpace는 즉시 성공/실패를 돌려주는 비동기 작업입니다.
        // 실패하면 사용자가 다시 누를 수 있도록 isSensingOpen을 false로 유지합니다.
        let result = await openImmersiveSpace(id: "sensing")
        switch result {
        case .opened:
            isSensingOpen = true
            controlStatusText = "공간 열림"
            return true
        case .userCancelled:
            isSensingOpen = false
            controlStatusText = "공간 열기 취소됨"
            return false
        case .error:
            isSensingOpen = false
            planeService.statusText = "공간 인식 시작 실패"
            controlStatusText = "공간 열기 실패"
            return false
        @unknown default:
            isSensingOpen = false
            controlStatusText = "공간 상태 알 수 없음"
            return false
        }
    }

    private var storedItemsSummary: some View {
        Text("저장 항목 · 박스 \(boxes.count) · 메모 \(memos.count)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func submitBoxName() async {
        let trimmedName = draftBoxName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Box \(boxes.count + 1)" : trimmedName
        await createBox(named: resolvedName)
    }

    @MainActor
    private func createBox(named name: String) async {
        controlStatusText = "박스 생성 중..."

        // ARKit이 책상 후보를 찾았으면 그 위치를, 아직 못 찾았으면 fallback 위치를 받습니다.
        let origin = planeService.tablePlaneOrigin
        // 먼저 SwiftData에 박스 기록을 저장합니다.
        // 이 저장 덕분에 ControlPanel의 @Query 목록과 다음 앱 실행의 재열기 목록에 나타납니다.
        let position = workspacePosition(from: origin)
        let box = OrganizerBox(
            name: name,
            posX: position.x,
            posY: position.y,
            posZ: position.z
        )
        modelContext.insert(box)

        do {
            try modelContext.save()
        } catch {
            modelContext.delete(box)
            storageErrorMessage = error.localizedDescription
            controlStatusText = "박스 저장 실패"
            return
        }

        // 새 박스는 별도 window가 아니라 ImmersiveSpace 안의 WorkspaceRealityView가 직접 entity로 만듭니다.
        // 이 요청은 openImmersiveSpace보다 먼저 넣습니다. 시뮬레이터를 종료하지 않은 채 재빌드하면
        // 이전 ImmersiveSpace 상태 때문에 공간 열기 응답이 불안정할 수 있는데,
        // entity 요청을 먼저 저장해 두면 공간이 늦게 열려도 WorkspaceRealityView가 다시 읽을 수 있습니다.
        workspaceStore.addBox(
            id: box.id,
            position: position
        )

        let isSpaceReady = await openSensingIfNeeded()
        controlStatusText = isSpaceReady ? "박스 등장 요청 완료" : "박스 저장됨, 공간 열기 필요"
        draftBoxName = ""
        panelMode = .home
    }

    private func workspacePosition(from origin: (x: Float, y: Float, z: Float)) -> SIMD3<Float> {
        let offsetX = Float(workspaceStore.boxRequests.count) * 0.3

        if planeService.detectedTablePlane == nil {
            // 아직 평면이 잡히지 않은 상태에서는 사용자 눈앞의 기본 위치를 fallback으로 씁니다.
            return SIMD3<Float>(offsetX, 1.0, -1.0)
        }

        return SIMD3<Float>(origin.x + offsetX, origin.y, origin.z)
    }

    private func resetAllData() {
        // @Query로 읽어온 현재 박스/메모를 모두 삭제합니다.
        // delete만 호출하면 메모리상의 변경일 뿐이고, save가 성공해야 실제 저장소에 반영됩니다.
        boxes.forEach { modelContext.delete($0) }
        memos.forEach { modelContext.delete($0) }

        do {
            try modelContext.save()
            workspaceStore.resetWorkspace()
            controlStatusText = "데이터 초기화 완료"
        } catch {
            storageErrorMessage = error.localizedDescription
            controlStatusText = "데이터 초기화 실패"
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
