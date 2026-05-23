import Foundation
import RealityKit

// ImmersiveSpace 안에 표시할 RealityKit entity 요청을 관리하는 앱 공유 상태입니다.
//
// SwiftData의 OrganizerBox가 "저장되는 데이터"라면,
// WorkspaceBoxEntityRequest는 "지금 열린 공간에 어떤 entity를 띄울지"를 나타냅니다.
// WorldAnchor 자체는 SwiftData 모델과 PlaneDetectionService 쪽에 저장하고,
// 이 request는 현재 열린 ImmersiveSpace에 표시할 박스의 최소 정보만 들고 있습니다.
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
    static let shared = WorkspaceEntityStore()

    private(set) var boxRequests: [WorkspaceBoxEntityRequest] = []
    private(set) var selectedBoxID: UUID?
    private(set) var anchoredBoxIDs = Set<UUID>()
    private(set) var boxInteractionModes: [UUID: BoxInteractionMode] = [:]
    private(set) var revision = 0
    private(set) var resetRevision = 0

    func addBox(id: UUID, position: SIMD3<Float>) {
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
        revision += 1
        resetRevision += 1
    }
}
