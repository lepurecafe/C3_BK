import Foundation
import RealityKit

// ImmersiveSpace 안에 표시할 RealityKit entity 요청을 관리하는 앱 공유 상태입니다.
//
// SwiftData의 OrganizerBox가 "저장되는 데이터"라면,
// WorkspaceBoxEntityRequest는 "지금 열린 공간에 어떤 entity를 띄울지"를 나타냅니다.
// WorldAnchor 자체는 SwiftData 모델과 PlaneDetectionService 쪽에 저장하고,
// 이 request는 현재 열린 ImmersiveSpace에 표시할 박스의 최소 정보만 들고 있습니다.
//
// 교재 연결:
// - 3장: 공간에 3D entity 배치하기
// - 5장: entity 탭과 선택 상태 처리하기
// - 7장: 내장 3D animation 재생하기
struct WorkspaceBoxEntityRequest: Identifiable, Hashable {
    let id: UUID
    var position: SIMD3<Float>
}

// 박스가 왜 열려 있는지를 구분하는 상호작용 상태입니다.
// 현재는 닫힘, 열림/닫힘 애니메이션 중, 메모 조회용 열림 상태를 구분합니다.
enum BoxInteractionMode: Equatable {
    case closed
    case opening
    case openForLookup
    case closing
}

@Observable
final class WorkspaceEntityStore: @unchecked Sendable {
    // WindowGroup의 ControlPanelView와 ImmersiveSpace의 WorkspaceRealityView가 같은 요청 목록을 봐야 하므로
    // 앱 안에서 하나만 쓰는 shared store로 둡니다.
    static let shared = WorkspaceEntityStore()

    // "새 박스를 공간에 띄워 달라"는 런타임 요청 목록입니다.
    // SwiftData에 저장된 전체 박스 목록과 다르게, 현재 실행 중 새로 요청한 박스만 들어올 수 있습니다.
    private(set) var boxRequests: [WorkspaceBoxEntityRequest] = []
    // 마지막으로 사용자가 탭한 박스입니다. 선택된 박스 아래에 control attachment를 붙일 때 씁니다.
    private(set) var selectedBoxID: UUID?
    // WorldAnchor 또는 Simulator fallback으로 고정된 박스 id 목록입니다.
    // 이 목록에 있으면 드래그 이동을 막습니다.
    private(set) var anchoredBoxIDs = Set<UUID>()
    // 박스별 열림 상태입니다. animation 중인지, 메모 조회용으로 열려 있는지 구분합니다.
    private(set) var boxInteractionModes: [UUID: BoxInteractionMode] = [:]
    // RealityView의 .task(id:)를 다시 실행시키는 간단한 변경 번호입니다.
    private(set) var revision = 0
    // 공간 전체를 리셋해야 할 때만 올리는 별도 변경 번호입니다.
    private(set) var resetRevision = 0

    func addBox(id: UUID, position: SIMD3<Float>) {
        // 같은 UUID가 두 번 들어오면 같은 박스 entity가 두 개 생길 수 있으므로 요청을 무시합니다.
        guard !boxRequests.contains(where: { $0.id == id }) else {
            return
        }

        boxRequests.append(
            WorkspaceBoxEntityRequest(
                id: id,
                position: position
            )
        )
        boxInteractionModes[id, default: .closed] = .closed
        // WorkspaceRealityView.renderRevision이 이 값을 읽고 새 박스를 렌더링합니다.
        revision += 1
    }

    func selectBox(id: UUID) {
        selectedBoxID = id
    }

    func isBoxAnchored(_ id: UUID) -> Bool {
        anchoredBoxIDs.contains(id)
    }

    func setBoxAnchored(_ isAnchored: Bool, for id: UUID) {
        if isAnchored {
            anchoredBoxIDs.insert(id)
        } else {
            anchoredBoxIDs.remove(id)
        }
    }

    func removeBox(id: UUID) {
        boxRequests.removeAll { $0.id == id }

        // 삭제된 박스가 선택 중이었다면 control attachment가 남지 않도록 선택도 비웁니다.
        if selectedBoxID == id {
            selectedBoxID = nil
        }

        anchoredBoxIDs.remove(id)
        boxInteractionModes.removeValue(forKey: id)
        revision += 1
    }

    func interactionMode(for id: UUID) -> BoxInteractionMode {
        boxInteractionModes[id, default: .closed]
    }

    func setInteractionMode(_ mode: BoxInteractionMode, for id: UUID) {
        boxInteractionModes[id] = mode
    }

    func isBoxAnimating(_ id: UUID) -> Bool {
        switch interactionMode(for: id) {
        case .opening, .closing:
            true
        case .closed, .openForLookup:
            false
        }
    }

    func isBoxOpen(_ id: UUID) -> Bool {
        switch interactionMode(for: id) {
        case .openForLookup:
            true
        case .closed, .opening, .closing:
            false
        }
    }

    func resetWorkspace() {
        boxRequests.removeAll()
        selectedBoxID = nil
        anchoredBoxIDs.removeAll()
        boxInteractionModes.removeAll()
        // 일반 렌더링 갱신과 "이미 렌더된 entity를 모두 제거"하는 갱신을 둘 다 발생시킵니다.
        revision += 1
        resetRevision += 1
    }
}
