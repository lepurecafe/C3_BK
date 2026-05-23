import RealityKit
import RealityKitContent
import SwiftUI
import UIKit

extension WorkspaceRealityView {
    @MainActor
    func renderKnownBoxes() async {
        guard let rootEntity = sceneState.rootEntity else {
            return
        }

        for box in persistedBoxes where !sceneState.renderedBoxIDs.contains(box.id) {
            await renderBox(
                id: box.id,
                position: workspacePosition(for: box),
                in: rootEntity
            )

            if box.isAnchored {
                workspaceStore.setBoxAnchored(true, for: box.id)
            }
        }

        for request in workspaceStore.boxRequests where !sceneState.renderedBoxIDs.contains(request.id) {
            await renderBox(
                id: request.id,
                position: request.position,
                in: rootEntity
            )
        }
    }

    @MainActor
    func resetRenderedWorkspace() {
        sceneState.animationTasks.values.forEach { $0.cancel() }
        sceneState.animationControllers.values.forEach { $0.stop() }
        sceneState.boxRoots.values.forEach { $0.removeFromParent() }

        sceneState.renderedBoxIDs.removeAll()
        sceneState.boxRoots.removeAll()
        sceneState.boxModels.removeAll()
        sceneState.boxAnimations.removeAll()
        sceneState.animationControllers.removeAll()
        sceneState.animationTasks.removeAll()
        sceneState.dragStartPositions.removeAll()
        sceneState.tablePlaneDebugEntity?.removeFromParent()
        sceneState.tablePlaneDebugEntity = nil
        draggingMemoPreview = nil
        spatialMemoPresentations.removeAll()
        spatialMemoDragStartPositions.removeAll()
    }

    @MainActor
    func removeRenderedBox(id: UUID) {
        sceneState.animationTasks[id]?.cancel()
        sceneState.animationControllers[id]?.stop()
        sceneState.boxRoots[id]?.removeFromParent()

        sceneState.renderedBoxIDs.remove(id)
        sceneState.boxRoots.removeValue(forKey: id)
        sceneState.boxModels.removeValue(forKey: id)
        sceneState.boxAnimations.removeValue(forKey: id)
        sceneState.animationControllers.removeValue(forKey: id)
        sceneState.animationTasks.removeValue(forKey: id)
        sceneState.dragStartPositions.removeValue(forKey: id)
    }

    @MainActor
    func renderBox(id: UUID, position: SIMD3<Float>, in rootEntity: Entity) async {
        guard let travelCase = try? await Entity(
            named: "TravelCaseScene",
            in: realityKitContentBundle
        ) else {
            return
        }

        let boxRoot = Entity()
        boxRoot.name = boxEntityName(for: id)
        boxRoot.position = position

        fitTravelCaseForWorkspace(travelCase)
        placeTravelCaseOnRootPlane(travelCase)
        configureInputTargets(in: travelCase)
        travelCase.generateCollisionShapes(recursive: true)

        boxRoot.addChild(travelCase)
        rootEntity.addChild(boxRoot)

        sceneState.boxRoots[id] = boxRoot
        sceneState.boxModels[id] = travelCase
        sceneState.boxAnimations[id] = firstAvailableAnimation(in: travelCase)
        sceneState.renderedBoxIDs.insert(id)
    }

    func fitTravelCaseForWorkspace(_ entity: Entity) {
        let bounds = entity.visualBounds(relativeTo: nil)
        let maxExtent = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))

        if maxExtent > 0 {
            // ImmersiveSpace에서는 실제 책상 위 물체처럼 보이도록 적당한 물리 크기로 맞춥니다.
            let targetSize: Float = 0.45
            let uniformScale = targetSize / maxExtent
            entity.scale = SIMD3<Float>(repeating: uniformScale)
        }

        // 위치는 wrapper entity가 담당합니다.
        // 모델 entity는 wrapper 안에서 원점 근처에 두어 animation과 transform 책임을 분리합니다.
        entity.position = .zero
    }

    func placeTravelCaseOnRootPlane(_ entity: Entity) {
        let bounds = entity.visualBounds(relativeTo: entity)
        // visualBounds 기준으로 바닥을 평면에 맞춘 뒤, 실기기에서 보이는 모델 pivot/mesh 여백을 보정합니다.
        entity.position.y = -bounds.min.y + travelCaseSurfaceOffset
    }

    func workspacePosition(for box: OrganizerBox) -> SIMD3<Float> {
        worldAnchorPosition(for: box) ?? SIMD3<Float>(box.posX, box.posY, box.posZ)
    }

    @MainActor
    func updateTablePlaneDebugOverlay() {
        guard let rootEntity = sceneState.rootEntity else {
            return
        }

        guard let tablePlane = planeService.detectedTablePlane else {
            sceneState.tablePlaneDebugEntity?.removeFromParent()
            sceneState.tablePlaneDebugEntity = nil
            return
        }

        let width = max(tablePlane.geometry.extent.width, 0.1)
        let depth = max(tablePlane.geometry.extent.height, 0.1)
        let mesh = MeshResource.generatePlane(width: width, depth: depth)
        let material = SimpleMaterial(
            color: UIColor.cyan.withAlphaComponent(0.45),
            roughness: 0.7,
            isMetallic: false
        )

        let debugEntity = sceneState.tablePlaneDebugEntity ?? ModelEntity()
        debugEntity.name = "DebugTablePlane"
        debugEntity.model = ModelComponent(mesh: mesh, materials: [material])
        debugEntity.transform.matrix = tablePlane.originFromAnchorTransform

        // 감지된 평면과 완전히 같은 높이에 두면 z-fighting처럼 깜빡일 수 있어 아주 조금 위로 올립니다.
        debugEntity.position.y += 0.003

        if debugEntity.parent == nil {
            rootEntity.addChild(debugEntity)
        }

        sceneState.tablePlaneDebugEntity = debugEntity
    }

    func toggleBoxOpenState(for boxID: UUID) {
        guard !workspaceStore.isBoxAnimating(boxID),
              let entity = sceneState.boxModels[boxID],
              let animation = sceneState.boxAnimations[boxID]
        else {
            return
        }

        if workspaceStore.isBoxOpen(boxID) {
            closeBox(id: boxID, entity: entity, animation: animation)
        } else {
            openBox(
                id: boxID,
                mode: .openForLookup,
                entity: entity,
                animation: animation
            )
        }
    }

    func openBox(
        id: UUID,
        mode: BoxInteractionMode,
        entity: Entity,
        animation: AnimationResource,
        onOpened: (() -> Void)? = nil
    ) {
        sceneState.animationTasks[id]?.cancel()
        sceneState.animationControllers[id]?.stop()

        let controller = entity.playAnimation(animation, transitionDuration: 0, startsPaused: true)
        let duration = max(controller.duration, 0.1)
        controller.speed = 1
        controller.time = 0

        sceneState.animationControllers[id] = controller
        workspaceStore.setInteractionMode(.opening, for: id)
        controller.resume()

        sceneState.animationTasks[id] = Task { @MainActor in
            let nanoseconds = UInt64(duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }

            controller.pause()
            controller.time = duration
            workspaceStore.setInteractionMode(mode, for: id)
            onOpened?()
        }
    }

    func closeBox(id: UUID, entity: Entity, animation: AnimationResource) {
        sceneState.animationTasks[id]?.cancel()
        sceneState.animationControllers[id]?.stop()

        let controller = entity.playAnimation(animation, transitionDuration: 0, startsPaused: true)
        let duration = max(controller.duration, 0.1)
        controller.pause()
        controller.time = duration

        sceneState.animationControllers[id] = controller
        workspaceStore.setInteractionMode(.closing, for: id)

        sceneState.animationTasks[id] = Task { @MainActor in
            let frameCount = 90
            let frameDuration = duration / Double(frameCount)
            let frameNanoseconds = UInt64(frameDuration * 1_000_000_000)

            for frame in stride(from: frameCount, through: 0, by: -1) {
                guard !Task.isCancelled else { return }

                let progress = Double(frame) / Double(frameCount)
                controller.time = duration * progress
                try? await Task.sleep(nanoseconds: frameNanoseconds)
            }

            controller.pause()
            controller.time = 0
            workspaceStore.setInteractionMode(.closed, for: id)
        }
    }

    func configureInputTargets(in entity: Entity) {
        entity.components.set(InputTargetComponent())
        entity.components.set(HoverEffectComponent())

        for child in entity.children {
            configureInputTargets(in: child)
        }
    }

    func moveBox(with value: EntityTargetValue<DragGesture.Value>) {
        guard let boxID = boxID(for: value.entity),
              let boxRoot = sceneState.boxRoots[boxID]
        else {
            return
        }

        workspaceStore.selectBox(id: boxID)

        guard !workspaceStore.isBoxAnchored(boxID) else {
            sceneState.dragStartPositions[boxID] = nil
            return
        }

        let startPosition = sceneState.dragStartPositions[boxID] ?? boxRoot.position
        sceneState.dragStartPositions[boxID] = startPosition

        let movement = value.convert(value.translation3D, from: .global, to: .scene)
        boxRoot.position = startPosition + movement
    }

    @MainActor
    func deleteBox(_ box: OrganizerBox) {
        Task {
            try? await planeService.removeWorldAnchor(forObjectID: box.id)
            for memo in memos(in: box.id) {
                try? await planeService.removeWorldAnchor(forObjectID: memo.id)
            }

            await MainActor.run {
                removeRenderedBox(id: box.id)
                spatialMemoPresentations.removeAll { $0.boxID == box.id }
                memos(in: box.id).forEach { modelContext.delete($0) }
                modelContext.delete(box)

                do {
                    try modelContext.save()
                    workspaceStore.removeBox(id: box.id)
                    planeService.statusText = "\(box.name) 삭제됨"
                } catch {
                    modelContext.rollback()
                    planeService.statusText = "박스 삭제 실패: \(error.localizedDescription)"
                }
            }
        }
    }
}
