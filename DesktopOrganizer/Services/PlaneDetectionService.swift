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
    var statusText: String = "책상 인식 중..."
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
    // 박스 entity를 실제 공간 위치에 고정하기 위한 world tracking provider입니다.
    // PlaneDetectionService가 ARKitSession을 이미 소유하므로 같은 session 안에서 같이 실행합니다.
    private var worldTracking = WorldTrackingProvider()
    private var worldAnchorsByBoxID: [UUID: WorldAnchor] = [:]
    private var worldAnchorTransformsByID: [UUID: simd_float4x4] = [:]
    private var worldAnchorUpdateTask: Task<Void, Never>?

    // PlaneOverlayView의 .task에서 호출됩니다.
    // 호출 후에는 anchorUpdates 비동기 시퀀스를 계속 기다리므로, 감지 결과가 들어올 때마다 상태가 갱신됩니다.
    func startDetection() async {
        // Simulator나 일부 기기에서는 plane detection을 지원하지 않을 수 있습니다.
        // 이 경우 앱이 crash하지 않고 ControlPanel에 상태를 보여주도록 빠져나갑니다.
        guard PlaneDetectionProvider.isSupported else {
            statusText = "이 기기에서 지원되지 않음"
            return
        }

        do {
            // 여기서 실제 ARKit 평면 감지가 시작됩니다.
            if WorldTrackingProvider.isSupported {
                try await arkitSession.run([planeDetection, worldTracking])
                startWorldAnchorUpdatesIfNeeded()
            } else {
                try await arkitSession.run([planeDetection])
            }

            // ARKit이 평면을 추가/갱신/삭제할 때마다 update가 들어옵니다.
            for await update in planeDetection.anchorUpdates {
                switch update.event {
                case .added, .updated:
                    // MVP 기준의 단순한 책상 후보 판정입니다.
                    // 폭이 0.3m보다 큰 수평면이면 책상으로 쓸 수 있다고 보고 저장합니다.
                    if update.anchor.geometry.extent.width > 0.3 {
                        detectedTablePlane = update.anchor
                        tablePlaneDebugRevision += 1
                        statusText = "책상 감지됨 ✓ \(formattedPlaneSize(update.anchor))"
                    }
                case .removed:
                    // 지금 쓰고 있던 평면이 사라지면 fallback 상태로 돌아갑니다.
                    if detectedTablePlane?.id == update.anchor.id {
                        detectedTablePlane = nil
                        tablePlaneDebugRevision += 1
                        statusText = "책상 인식 중..."
                    }
                }
            }
        } catch {
            statusText = "인식 실패: \(error.localizedDescription)"
        }
    }

    func addWorldAnchor(for boxID: UUID, transform: simd_float4x4) async throws -> UUID {
        guard WorldTrackingProvider.isSupported else {
            throw WorldAnchorError.unsupported
        }

        if let existingAnchor = worldAnchorsByBoxID[boxID] {
            try? await worldTracking.removeAnchor(existingAnchor)
        }

        let anchor = WorldAnchor(originFromAnchorTransform: transform)
        try await worldTracking.addAnchor(anchor)
        worldAnchorsByBoxID[boxID] = anchor
        worldAnchorTransformsByID[anchor.id] = anchor.originFromAnchorTransform
        worldAnchorRevision += 1
        return anchor.id
    }

    func removeWorldAnchor(for boxID: UUID) async throws {
        guard let anchor = worldAnchorsByBoxID[boxID] else {
            return
        }

        try await worldTracking.removeAnchor(anchor)
        worldAnchorsByBoxID[boxID] = nil
        worldAnchorTransformsByID[anchor.id] = nil
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

    private func startWorldAnchorUpdatesIfNeeded() {
        guard worldAnchorUpdateTask == nil else {
            return
        }

        worldAnchorUpdateTask = Task { @MainActor in
            for await update in worldTracking.anchorUpdates {
                switch update.event {
                case .added, .updated:
                    worldAnchorTransformsByID[update.anchor.id] = update.anchor.originFromAnchorTransform
                    worldAnchorRevision += 1
                case .removed:
                    worldAnchorTransformsByID[update.anchor.id] = nil
                    worldAnchorRevision += 1
                }
            }
        }
    }

    // 박스 생성 시 사용할 위치입니다.
    // 감지된 평면이 있으면 그 중심을 쓰고, 없으면 사용자 앞쪽의 기본 위치를 반환합니다.
    var tablePlaneOrigin: (x: Float, y: Float, z: Float) {
        guard let plane = detectedTablePlane else {
            // Simulator에서 plane detection이 안 되거나 아직 감지 전일 때의 fallback 위치입니다.
            return (0, -0.3, -0.8)
        }

        // PlaneAnchor의 transform에서 translation 성분만 꺼냅니다.
        // y를 0.05m 낮추는 것은 모델이 표면에 너무 떠 보이지 않게 조정하기 위한 MVP 값입니다.
        // columns.3은 4x4 transform 행렬에서 위치(x, y, z)가 들어 있는 열입니다.
        // 처음에는 "감지된 평면의 중심 좌표를 꺼낸다" 정도로 이해하면 충분합니다.
        let col = plane.originFromAnchorTransform.columns.3
        return (col.x, col.y - 0.05, col.z)
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
