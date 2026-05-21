import Foundation
import RealityKit

// ImmersiveSpace 안에 표시할 RealityKit entity 요청을 관리하는 앱 공유 상태입니다.
//
// SwiftData의 OrganizerBox가 "저장되는 데이터"라면,
// WorkspaceBoxEntityRequest는 "지금 열린 공간에 어떤 entity를 띄울지"를 나타냅니다.
// Phase A에서는 WorldAnchor 없이 위치만 들고 있고, 이후 anchor identifier를 여기에 연결할 수 있습니다.
struct WorkspaceBoxEntityRequest: Identifiable, Hashable {
    let id: UUID
    var name: String
    var position: SIMD3<Float>
}

// 박스가 왜 열려 있는지를 구분하는 상호작용 상태입니다.
// 단순히 "열림/닫힘"만 저장하면 나중에 메모 조회와 메모 삽입 연출이 섞이므로,
// 클릭 조회(openForLookup)와 드래그 삽입(openForInsertion)을 처음부터 다른 의미로 둡니다.
enum BoxInteractionMode: Equatable {
    case closed
    case opening
    case openForLookup
    case openForInsertion
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

    func addBox(id: UUID, name: String, position: SIMD3<Float>) {
        guard !boxRequests.contains(where: { $0.id == id }) else {
            return
        }

        boxRequests.append(
            WorkspaceBoxEntityRequest(
                id: id,
                name: name,
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
        case .closed, .openForLookup, .openForInsertion:
            false
        }
    }

    func isBoxOpen(_ id: UUID) -> Bool {
        switch interactionMode(for: id) {
        case .openForLookup, .openForInsertion:
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
