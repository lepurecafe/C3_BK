import RealityKit
import SwiftUI

extension WorkspaceRealityView {
    func spatialMemoPosition(for translation: CGSize) -> SIMD3<Float> {
        SIMD3<Float>(
            Float(translation.width) * memoDragMetersPerPoint,
            0.34 - Float(translation.height) * memoDragMetersPerPoint,
            0.03
        )
    }

    func spatialMemoDropPosition(in boxID: UUID, translation: CGSize) -> SIMD3<Float>? {
        guard let boxRoot = sceneState.boxRoots[boxID] else {
            return nil
        }

        return boxRoot.position + spatialMemoPosition(for: translation)
    }

    func spatialMemoMovement(for translation: CGSize) -> SIMD3<Float> {
        SIMD3<Float>(
            Float(translation.width) * memoDragMetersPerPoint,
            -Float(translation.height) * memoDragMetersPerPoint,
            0
        )
    }

    func transformMatrix(for position: SIMD3<Float>) -> simd_float4x4 {
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(position.x, position.y, position.z, 1)
        return transform
    }

    func configureMemoBillboard(_ entity: Entity) {
        var billboard = BillboardComponent()
        billboard.blendFactor = 0.75
        entity.components.set(billboard)
    }

    func configureOpenedMemoEntity(_ entity: Entity) {
        configureMemoBillboard(entity)
        entity.components.set(InputTargetComponent())
        entity.components.set(HoverEffectComponent())
    }

    func dragDistance(_ translation: CGSize) -> CGFloat {
        sqrt((translation.width * translation.width) + (translation.height * translation.height))
    }

    func firstAvailableAnimation(in entity: Entity) -> AnimationResource? {
        if let animation = entity.availableAnimations.first {
            return animation
        }

        for child in entity.children {
            if let animation = firstAvailableAnimation(in: child) {
                return animation
            }
        }

        return nil
    }

    func boxID(for entity: Entity) -> UUID? {
        if let id = boxID(from: entity.name) {
            return id
        }

        guard let parent = entity.parent else {
            return nil
        }

        return boxID(for: parent)
    }

    func boxID(from entityName: String) -> UUID? {
        guard entityName.hasPrefix("WorkspaceBox:") else {
            return nil
        }

        let rawID = entityName.replacingOccurrences(of: "WorkspaceBox:", with: "")
        return UUID(uuidString: rawID)
    }

    func boxEntityName(for id: UUID) -> String {
        "WorkspaceBox:\(id.uuidString)"
    }
}
