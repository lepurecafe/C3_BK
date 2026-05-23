import ARKit
import RealityKit

// ARKit을 이용해 주변의 수평 평면을 감지하는 서비스입니다.
//
// 이 서비스는 UI View가 아니라 상태와 ARKit 세션을 관리하는 객체입니다.
// DesktopOrganizerApp에서 하나만 만들고 environment로 공유하므로,
// PlaneOverlayView가 감지를 시작하면 ControlPanelView도 같은 statusText와 detectedTablePlane을 읽습니다.
@Observable
@MainActor
final class PlaneDetectionService {
    // ControlPanel 상단에 그대로 표시되는 감지 상태 문구입니다.
    var statusText: String = "공간 시작 대기"
    // 현재 "책상 후보"로 보고 있는 horizontal PlaneAnchor입니다.
    // 이 앱은 아직 진짜 테이블 semantic 분류를 하지 않고, 충분히 큰 수평면을 책상 후보로 취급합니다.
    var detectedTablePlane: PlaneAnchor?
    // 감지된 책상 후보 평면이 바뀔 때 RealityView의 디버그 시각화를 갱신하기 위한 값입니다.
    var tablePlaneDebugRevision = 0
    // WorldAnchor transform cache가 바뀔 때 WorkspaceRealityView가 다시 확인하도록 하는 revision입니다.
    var worldAnchorRevision = 0

    // ARKitSession은 ARKit provider들을 실행하는 세션입니다.
    private var arkitSession = ARKitSession()
    // horizontal alignment만 요청합니다.
    // 책상, 바닥, 선반처럼 수평인 표면이 모두 들어올 수 있고, 아래 width 필터로 작은 평면을 걸러냅니다.
    private var planeDetection = PlaneDetectionProvider(alignments: [.horizontal])
    // 박스와 공간 메모 entity를 실제 공간 위치에 고정하기 위한 world tracking provider입니다.
    // PlaneDetectionService가 ARKitSession을 이미 소유하므로 같은 session 안에서 같이 실행합니다.
    private var worldTracking = WorldTrackingProvider()
    private var worldAnchorsByObjectID: [UUID: WorldAnchor] = [:]
    private var worldAnchorTransformsByID: [UUID: simd_float4x4] = [:]
    private var worldAnchorUpdateTask: Task<Void, Never>?
    private var pendingWorldAnchorRevisionTask: Task<Void, Never>?
    private var pendingTablePlaneDebugRevisionTask: Task<Void, Never>?
    private var isDetectionRunning = false
    private var detectionGeneration = 0
    private var lockedTablePlaneID: UUID?

    // PlaneOverlayView의 .task에서 호출됩니다.
    // 호출 후에는 anchorUpdates 비동기 시퀀스를 계속 기다리므로, 감지 결과가 들어올 때마다 상태가 갱신됩니다.
    func startDetection() async {
        guard !isDetectionRunning else {
            return
        }

        // Simulator나 일부 기기에서는 plane detection을 지원하지 않을 수 있습니다.
        // 이 경우 앱이 crash하지 않고 ControlPanel에 상태를 보여주도록 빠져나갑니다.
        guard PlaneDetectionProvider.isSupported else {
            statusText = "이 기기에서 지원되지 않음"
            return
        }

        do {
            isDetectionRunning = true
            detectionGeneration += 1
            let generation = detectionGeneration
            defer {
                if generation == detectionGeneration {
                    isDetectionRunning = false
                }
            }

            // 여기서 실제 ARKit 평면 감지가 시작됩니다.
            if WorldTrackingProvider.isSupported {
                try await arkitSession.run([planeDetection, worldTracking])
                await refreshWorldAnchorCache()
                startWorldAnchorUpdatesIfNeeded()
            } else {
                try await arkitSession.run([planeDetection])
            }

            // ARKit이 평면을 추가/갱신/삭제할 때마다 update가 들어옵니다.
            for await update in planeDetection.anchorUpdates {
                guard isDetectionRunning,
                      generation == detectionGeneration,
                      !Task.isCancelled
                else {
                    break
                }

                switch update.event {
                case .added, .updated:
                    handlePlaneCandidate(update.anchor)
                case .removed:
                    // 지금 쓰고 있던 평면이 사라지면 fallback 상태로 돌아갑니다.
                    if lockedTablePlaneID == update.anchor.id {
                        lockedTablePlaneID = nil
                        detectedTablePlane = nil
                        scheduleTablePlaneDebugRevisionUpdate()
                        statusText = "책상 후보 사라짐, 다시 인식 중..."
                    }

                }
            }
        } catch {
            statusText = "인식 실패: \(error.localizedDescription)"
        }
    }

    func stopDetection() {
        isDetectionRunning = false
        detectionGeneration += 1
        arkitSession.stop()
        worldAnchorUpdateTask?.cancel()
        worldAnchorUpdateTask = nil
        pendingWorldAnchorRevisionTask?.cancel()
        pendingWorldAnchorRevisionTask = nil
        pendingTablePlaneDebugRevisionTask?.cancel()
        pendingTablePlaneDebugRevisionTask = nil

        lockedTablePlaneID = nil
        detectedTablePlane = nil
        tablePlaneDebugRevision += 1

        // Provider를 새로 만들어 다음 "공간 시작" 때 깨끗한 anchorUpdates sequence로 다시 시작합니다.
        arkitSession = ARKitSession()
        planeDetection = PlaneDetectionProvider(alignments: [.horizontal])
        worldTracking = WorldTrackingProvider()
        worldAnchorsByObjectID.removeAll()

        statusText = "공간이 닫힘"
    }

    func requestTableRescan() {
        lockedTablePlaneID = nil
        detectedTablePlane = nil
        tablePlaneDebugRevision += 1
        statusText = "책상 다시 인식 중..."
    }

    func addWorldAnchor(
        forObjectID objectID: UUID,
        replacingAnchorIdentifier anchorIdentifier: String? = nil,
        transform: simd_float4x4
    ) async throws -> UUID {
        guard WorldTrackingProvider.isSupported else {
            throw WorldAnchorError.unsupported
        }

        if let existingAnchor = worldAnchorsByObjectID[objectID] {
            try? await worldTracking.removeAnchor(existingAnchor)
        } else if let existingAnchorID = uuid(from: anchorIdentifier) {
            try? await worldTracking.removeAnchor(forID: existingAnchorID)
            worldAnchorTransformsByID[existingAnchorID] = nil
        }

        let anchor = WorldAnchor(originFromAnchorTransform: transform)
        try await worldTracking.addAnchor(anchor)
        worldAnchorsByObjectID[objectID] = anchor
        worldAnchorTransformsByID[anchor.id] = anchor.originFromAnchorTransform
        worldAnchorRevision += 1
        return anchor.id
    }

    func removeWorldAnchor(forObjectID objectID: UUID, anchorIdentifier: String? = nil) async throws {
        if let anchor = worldAnchorsByObjectID[objectID] {
            try await worldTracking.removeAnchor(anchor)
            worldAnchorsByObjectID[objectID] = nil
            worldAnchorTransformsByID[anchor.id] = nil
            worldAnchorRevision += 1
            return
        }

        guard let anchorID = uuid(from: anchorIdentifier) else {
            return
        }

        try await worldTracking.removeAnchor(forID: anchorID)
        worldAnchorTransformsByID[anchorID] = nil
        worldAnchorRevision += 1
    }

    func worldAnchorTransform(for anchorIdentifier: String?) -> simd_float4x4? {
        guard let anchorIdentifier,
              let anchorID = UUID(uuidString: anchorIdentifier)
        else {
            return nil
        }

        return worldAnchorTransformsByID[anchorID]
    }

    func refreshWorldAnchorCache() async {
        guard WorldTrackingProvider.isSupported,
              let anchors = await worldTracking.allAnchors
        else {
            return
        }

        for anchor in anchors {
            worldAnchorTransformsByID[anchor.id] = anchor.originFromAnchorTransform
        }

        if !anchors.isEmpty {
            worldAnchorRevision += 1
            statusText = "월드 앵커 \(anchors.count)개 복원됨"
        }
    }

    private func startWorldAnchorUpdatesIfNeeded() {
        guard worldAnchorUpdateTask == nil else {
            return
        }

        worldAnchorUpdateTask = Task { @MainActor in
            for await update in worldTracking.anchorUpdates {
                switch update.event {
                case .added, .updated:
                    worldAnchorTransformsByID[update.anchor.id] = update.anchor.originFromAnchorTransform
                    scheduleWorldAnchorRevisionUpdate()
                case .removed:
                    worldAnchorTransformsByID[update.anchor.id] = nil
                    scheduleWorldAnchorRevisionUpdate()
                }
            }
        }
    }

    private func scheduleWorldAnchorRevisionUpdate() {
        guard pendingWorldAnchorRevisionTask == nil else {
            return
        }

        pendingWorldAnchorRevisionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            worldAnchorRevision += 1
            pendingWorldAnchorRevisionTask = nil
        }
    }

    private func scheduleTablePlaneDebugRevisionUpdate() {
        guard pendingTablePlaneDebugRevisionTask == nil else {
            return
        }

        pendingTablePlaneDebugRevisionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            tablePlaneDebugRevision += 1
            pendingTablePlaneDebugRevisionTask = nil
        }
    }

    private func uuid(from anchorIdentifier: String?) -> UUID? {
        guard let anchorIdentifier else {
            return nil
        }

        return UUID(uuidString: anchorIdentifier)
    }

    private func handlePlaneCandidate(_ plane: PlaneAnchor) {
        if lockedTablePlaneID == plane.id {
            detectedTablePlane = plane
            scheduleTablePlaneDebugRevisionUpdate()
            return
        }

        selectTablePlaneIfNeeded(plane)

        if lockedTablePlaneID == nil {
            statusText = "책상 후보 확인 중... \(formattedPlaneSize(plane))"
        }
    }

    private func selectTablePlaneIfNeeded(_ plane: PlaneAnchor) {
        guard lockedTablePlaneID == nil,
              isUsableTableCandidate(plane)
        else {
            return
        }

        lockedTablePlaneID = plane.id
        detectedTablePlane = plane
        scheduleTablePlaneDebugRevisionUpdate()
        statusText = "책상 고정됨 ✓ \(formattedPlaneSize(plane))"
    }

    private func isUsableTableCandidate(_ plane: PlaneAnchor) -> Bool {
        let width = plane.geometry.extent.width
        let depth = plane.geometry.extent.height
        let longEdge = max(width, depth)
        let shortEdge = min(width, depth)
        let area = width * depth

        // ARKit은 책상을 처음부터 완성된 사각형으로 주지 않고, 얇은 조각부터 키워 나갈 수 있습니다.
        // 그래서 양쪽 모두 0.3m 이상을 요구하지 않고, 긴 변과 짧은 변 기준을 나눠 둡니다.
        // 너무 큰 면은 바닥일 가능성이 높아 제외합니다.
        // 지금 단계에서는 "책상으로 보이는 수평면"을 안정적으로 한 번 잡는 것이 목표입니다.
        return longEdge > 0.2 && shortEdge > 0.08 && area <= 8.0
    }

    // 박스 생성 시 사용할 위치입니다.
    // 감지된 평면이 있으면 그 중심을 쓰고, 없으면 사용자 앞쪽의 기본 위치를 반환합니다.
    var tablePlaneOrigin: (x: Float, y: Float, z: Float) {
        guard let plane = detectedTablePlane else {
            // Simulator에서 plane detection이 안 되거나 아직 감지 전일 때의 fallback 위치입니다.
            return (0, -0.3, -0.8)
        }

        // PlaneAnchor의 transform에서 translation 성분만 꺼냅니다.
        // y는 감지된 평면 높이를 그대로 사용합니다.
        // 박스 모델의 바닥 높이 보정은 WorkspaceRealityView가 visualBounds를 보고 처리합니다.
        // columns.3은 4x4 transform 행렬에서 위치(x, y, z)가 들어 있는 열입니다.
        // 처음에는 "감지된 평면의 중심 좌표를 꺼낸다" 정도로 이해하면 충분합니다.
        let col = plane.originFromAnchorTransform.columns.3
        return (col.x, col.y, col.z)
    }

    private func formattedPlaneSize(_ plane: PlaneAnchor) -> String {
        let width = plane.geometry.extent.width
        let depth = plane.geometry.extent.height
        return String(format: "%.2fm x %.2fm", width, depth)
    }
}

enum WorldAnchorError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "이 기기에서 WorldAnchor를 지원하지 않습니다."
        }
    }
}
