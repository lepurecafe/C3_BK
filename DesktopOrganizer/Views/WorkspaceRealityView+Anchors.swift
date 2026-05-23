import RealityKit
import SwiftUI

extension WorkspaceRealityView {
    @MainActor
    func applyKnownWorldAnchorTransforms() {
        for box in persistedBoxes {
            guard let boxRoot = sceneState.boxRoots[box.id],
                  let anchorPosition = worldAnchorPosition(for: box)
            else {
                continue
            }

            boxRoot.position = anchorPosition
        }

        for memo in memos where memo.isSpatiallyPresented {
            guard let anchorPosition = spatialWorldAnchorPosition(for: memo) else {
                continue
            }

            updateSpatialMemoPresentation(id: memo.id) { presentation in
                presentation.position = anchorPosition
            }
        }
    }

    func worldAnchorPosition(for box: OrganizerBox) -> SIMD3<Float>? {
        guard let transform = planeService.worldAnchorTransform(for: box.worldAnchorIdentifier) else {
            return nil
        }

        let position = transform.columns.3
        return SIMD3<Float>(position.x, position.y, position.z)
    }

    func spatialWorldAnchorPosition(for memo: MemoItem) -> SIMD3<Float>? {
        guard let transform = planeService.worldAnchorTransform(for: memo.spatialWorldAnchorIdentifier) else {
            return nil
        }

        let position = transform.columns.3
        return SIMD3<Float>(position.x, position.y, position.z)
    }

    @MainActor
    func toggleAnchor(for boxID: UUID) async {
        let nextState = !workspaceStore.isBoxAnchored(boxID)

        do {
            if nextState {
                try await addWorldAnchor(for: boxID)
            } else {
                try await removeWorldAnchor(for: boxID)
            }
        } catch {
            if nextState, isWorldAnchorUnavailable(error) {
                applyTemporaryAnchorFallback(for: boxID)
                return
            }

            planeService.statusText = "앵커 실패: \(error.localizedDescription)"
            return
        }

        workspaceStore.setBoxAnchored(nextState, for: boxID)
        saveBoxAnchorState(boxID, isAnchored: nextState)
        planeService.statusText = nextState ? "월드 앵커 저장됨" : "앵커 해제됨"
    }

    @MainActor
    func addWorldAnchor(for boxID: UUID) async throws {
        guard let boxRoot = sceneState.boxRoots[boxID],
              let box = persistedBoxes.first(where: { $0.id == boxID })
        else {
            return
        }

        let transform = boxRoot.transformMatrix(relativeTo: nil)
        let anchorID = try await planeService.addWorldAnchor(
            forObjectID: boxID,
            replacingAnchorIdentifier: box.worldAnchorIdentifier,
            transform: transform
        )
        box.worldAnchorIdentifier = anchorID.uuidString
        try modelContext.save()
    }

    @MainActor
    func removeWorldAnchor(for boxID: UUID) async throws {
        guard let box = persistedBoxes.first(where: { $0.id == boxID }) else {
            return
        }

        if box.worldAnchorIdentifier != nil {
            try await planeService.removeWorldAnchor(
                forObjectID: boxID,
                anchorIdentifier: box.worldAnchorIdentifier
            )
        }

        box.worldAnchorIdentifier = nil
        try modelContext.save()
    }

    @MainActor
    func applyTemporaryAnchorFallback(for boxID: UUID) {
        guard let box = persistedBoxes.first(where: { $0.id == boxID }) else {
            return
        }

        box.worldAnchorIdentifier = nil
        workspaceStore.setBoxAnchored(true, for: boxID)
        saveBoxAnchorState(boxID, isAnchored: true)
        planeService.statusText = "Simulator: 임시 앵커 적용됨"
    }

    func isWorldAnchorUnavailable(_ error: Error) -> Bool {
        if case WorldAnchorError.unsupported = error {
            return true
        }

        let message = error.localizedDescription.lowercased()
        return message.contains("not supported") || message.contains("simulator")
    }

    func saveBoxPosition(_ boxID: UUID) {
        guard let boxRoot = sceneState.boxRoots[boxID] else {
            return
        }

        saveBoxState(boxID, isAnchored: workspaceStore.isBoxAnchored(boxID), position: boxRoot.position)
    }

    func saveBoxAnchorState(_ boxID: UUID, isAnchored: Bool) {
        guard let boxRoot = sceneState.boxRoots[boxID] else {
            return
        }

        saveBoxState(boxID, isAnchored: isAnchored, position: boxRoot.position)
    }

    func saveBoxState(_ boxID: UUID, isAnchored: Bool, position: SIMD3<Float>) {
        guard let box = persistedBoxes.first(where: { $0.id == boxID }) else {
            return
        }

        box.posX = position.x
        box.posY = position.y
        box.posZ = position.z
        box.isAnchored = isAnchored

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }

    @MainActor
    func toggleSpatialMemoAnchor(id: UUID) async {
        guard let presentation = spatialMemoPresentations.first(where: { $0.id == id }),
              let memo = memos.first(where: { $0.id == id })
        else {
            return
        }

        let nextState = !presentation.isAnchored

        do {
            if nextState {
                try await addWorldAnchor(forSpatialMemo: presentation)
                spatialMemoDragStartPositions.removeValue(forKey: id)
            } else {
                try await removeWorldAnchor(forSpatialMemo: memo)
            }
        } catch {
            if nextState, isWorldAnchorUnavailable(error) {
                applyTemporarySpatialMemoAnchorFallback(id: id)
                return
            }

            planeService.statusText = "메모 앵커 실패: \(error.localizedDescription)"
            return
        }

        updateSpatialMemoPresentation(id: id) { presentation in
            presentation.isAnchored = nextState
        }

        memo.isSpatiallyAnchored = nextState
        saveSpatialMemoState(statusText: nextState ? "공간 메모 월드 앵커 저장됨" : "공간 메모 앵커 해제됨")
    }

    @MainActor
    func addWorldAnchor(forSpatialMemo presentation: SpatialMemoPresentation) async throws {
        guard let memo = memos.first(where: { $0.id == presentation.id }) else {
            return
        }

        let transform = transformMatrix(for: presentation.position)
        let anchorID = try await planeService.addWorldAnchor(
            forObjectID: presentation.id,
            replacingAnchorIdentifier: memo.spatialWorldAnchorIdentifier,
            transform: transform
        )
        memo.spatialWorldAnchorIdentifier = anchorID.uuidString
        memo.spatialPosX = presentation.position.x
        memo.spatialPosY = presentation.position.y
        memo.spatialPosZ = presentation.position.z
        try modelContext.save()
    }

    @MainActor
    func removeWorldAnchor(forSpatialMemo memo: MemoItem) async throws {
        if memo.spatialWorldAnchorIdentifier != nil {
            try await planeService.removeWorldAnchor(
                forObjectID: memo.id,
                anchorIdentifier: memo.spatialWorldAnchorIdentifier
            )
        }

        memo.spatialWorldAnchorIdentifier = nil
        try modelContext.save()
    }

    @MainActor
    func applyTemporarySpatialMemoAnchorFallback(id: UUID) {
        guard let memo = memos.first(where: { $0.id == id }) else {
            return
        }

        updateSpatialMemoPresentation(id: id) { presentation in
            presentation.isAnchored = true
        }

        memo.isSpatiallyAnchored = true
        memo.spatialWorldAnchorIdentifier = nil
        spatialMemoDragStartPositions.removeValue(forKey: id)
        saveSpatialMemoState(statusText: "Simulator: 공간 메모 임시 앵커 적용됨")
    }
}
