import Foundation
import RealityKit

// RealityKit entity와 animation controller는 SwiftUI 화면 상태가 아니라 런타임 객체입니다.
// RealityView update 중 @State를 직접 바꾸면 "Modifying state during view update" 경고가 나므로,
// SwiftUI가 관찰하지 않는 reference container에 모아 둡니다.
@MainActor
final class WorkspaceRealitySceneState {
    var rootEntity: Entity?
    var renderedBoxIDs = Set<UUID>()
    var boxRoots: [UUID: Entity] = [:]
    var boxModels: [UUID: Entity] = [:]
    var boxAnimations: [UUID: AnimationResource] = [:]
    var animationControllers: [UUID: AnimationPlaybackController] = [:]
    var animationTasks: [UUID: Task<Void, Never>] = [:]
    var dragStartPositions: [UUID: SIMD3<Float>] = [:]
    var tablePlaneDebugEntity: ModelEntity?
}

struct DraggingMemoPreview: Equatable {
    let boxID: UUID
    let text: String
    let colorIndex: Int
    var translation: CGSize
}

struct SpatialMemoPresentation: Identifiable, Equatable {
    let id: UUID
    let boxID: UUID
    let text: String
    let colorIndex: Int
    var position: SIMD3<Float>
    var isAnchored = false

    var title: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "메모"
        }

        return String(trimmed.prefix(10))
    }
}
