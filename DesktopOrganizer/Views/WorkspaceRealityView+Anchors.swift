import RealityKit
import SwiftUI

// 박스와 공간 메모를 WorldAnchor에 연결하거나, 지원되지 않는 환경에서 임시 고정으로 대체합니다.
//
// 교재 연결:
// - 13장: 공간 오브젝트 위치 저장하기
// - 14장: 실제 공간에 고정하기
extension WorkspaceRealityView {
    @MainActor
    func applyKnownWorldAnchorTransforms() {
        // 교재 14장: WorldAnchor transform cache가 있으면 저장 좌표보다 실제 공간 anchor 위치를 우선 적용합니다.
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

        // 현재 앱은 박스 회전 조작을 제공하지 않으므로 WorldAnchor의 위치 성분만 복원합니다.
        // 나중에 회전까지 저장/복원하려면 boxRoot.transform.matrix 전체 적용을 별도 검토해야 합니다.
        let position = transform.columns.3
        return SIMD3<Float>(position.x, position.y, position.z)
    }

    func spatialWorldAnchorPosition(for memo: MemoItem) -> SIMD3<Float>? {
        guard let transform = planeService.worldAnchorTransform(for: memo.spatialWorldAnchorIdentifier) else {
            return nil
        }

        // 공간 메모는 BillboardComponent가 사용자를 향하게 만들기 때문에,
        // anchor 복원에서는 방향보다 위치를 우선 사용합니다.
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

        // 교재 14장: 현재 boxRoot의 world transform을 WorldAnchor의 기준 transform으로 저장합니다.
        let transform = boxRoot.transformMatrix(relativeTo: nil)
        let previousAnchorIdentifier = box.worldAnchorIdentifier
        let anchorID = try await planeService.addWorldAnchor(
            forObjectID: boxID,
            replacingAnchorIdentifier: box.worldAnchorIdentifier,
            transform: transform
        )
        box.worldAnchorIdentifier = anchorID.uuidString

        do {
            try modelContext.save()
        } catch {
            // ARKit에는 이미 새 WorldAnchor가 생긴 상태입니다.
            // SwiftData 저장이 실패하면 앱이 그 anchor id를 잃어버리므로, 방금 만든 anchor를 즉시 제거합니다.
            try? await planeService.removeWorldAnchor(
                forObjectID: boxID,
                anchorIdentifier: anchorID.uuidString
            )
            box.worldAnchorIdentifier = previousAnchorIdentifier
            modelContext.rollback()
            throw error
        }
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

        // 교재 14장: 공간 메모는 SwiftUI attachment entity지만 위치는 presentation.position으로 관리하므로,
        // 그 좌표를 4x4 transform으로 만들어 WorldAnchor에 넘깁니다.
        let transform = transformMatrix(for: presentation.position)
        let previousAnchorIdentifier = memo.spatialWorldAnchorIdentifier
        let previousPosition = SIMD3<Float>(memo.spatialPosX, memo.spatialPosY, memo.spatialPosZ)
        let anchorID = try await planeService.addWorldAnchor(
            forObjectID: presentation.id,
            replacingAnchorIdentifier: memo.spatialWorldAnchorIdentifier,
            transform: transform
        )
        memo.spatialWorldAnchorIdentifier = anchorID.uuidString
        memo.spatialPosX = presentation.position.x
        memo.spatialPosY = presentation.position.y
        memo.spatialPosZ = presentation.position.z

        do {
            try modelContext.save()
        } catch {
            // 박스와 같은 보상 처리입니다.
            // 저장 실패 시 새 anchor를 제거하고, 메모의 anchor id와 좌표를 저장 전 값으로 되돌립니다.
            try? await planeService.removeWorldAnchor(
                forObjectID: presentation.id,
                anchorIdentifier: anchorID.uuidString
            )
            memo.spatialWorldAnchorIdentifier = previousAnchorIdentifier
            memo.spatialPosX = previousPosition.x
            memo.spatialPosY = previousPosition.y
            memo.spatialPosZ = previousPosition.z
            modelContext.rollback()
            throw error
        }
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
