import Foundation
import SwiftUI

extension WorkspaceRealityView {
    func memos(in boxID: UUID) -> [MemoItem] {
        memos.filter { $0.containerBoxID == boxID }
    }

    func createMemo(in boxID: UUID, text: String, colorIndex: Int) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let memo = MemoItem(
            text: trimmed,
            colorIndex: colorIndex,
            containerBoxID: boxID
        )
        modelContext.insert(memo)

        do {
            try modelContext.save()
            planeService.statusText = "박스 안 메모 생성됨"
        } catch {
            modelContext.delete(memo)
            planeService.statusText = "메모 저장 실패: \(error.localizedDescription)"
        }
    }

    func openSpatialMemo(_ memo: MemoItem, in boxID: UUID) {
        guard let position = spatialMemoDropPosition(in: boxID, translation: .zero) else {
            return
        }

        memo.isSpatiallyPresented = true
        memo.spatialBoxID = boxID
        memo.spatialPosX = position.x
        memo.spatialPosY = position.y
        memo.spatialPosZ = position.z
        memo.isSpatiallyAnchored = false
        memo.spatialWorldAnchorIdentifier = nil

        upsertSpatialMemoPresentation(for: memo)
        saveSpatialMemoState(statusText: "메모를 공간에 펼침")
    }

    func deleteMemos(ids memoIDs: Set<UUID>) {
        let targets = memos.filter { memoIDs.contains($0.id) }
        guard !targets.isEmpty else {
            return
        }

        Task {
            for memo in targets {
                try? await planeService.removeWorldAnchor(
                    forObjectID: memo.id,
                    anchorIdentifier: memo.spatialWorldAnchorIdentifier
                )
            }

            await MainActor.run {
                spatialMemoPresentations.removeAll { memoIDs.contains($0.id) }
                targets.forEach { modelContext.delete($0) }

                do {
                    try modelContext.save()
                    planeService.statusText = "메모 \(targets.count)개 삭제됨"
                } catch {
                    modelContext.rollback()
                    planeService.statusText = "메모 삭제 실패: \(error.localizedDescription)"
                }
            }
        }
    }

    func updateDraggingMemoPreview(for memo: MemoItem, in boxID: UUID, translation: CGSize) {
        draggingMemoPreview = DraggingMemoPreview(
            boxID: boxID,
            text: memo.text,
            colorIndex: memo.colorIndex,
            translation: translation
        )
    }

    func finishDraggingMemoPreview(for memo: MemoItem, in boxID: UUID, translation: CGSize) {
        let shouldOpen = dragDistance(translation) >= memoDragActivationDistance
        let position = spatialMemoDropPosition(in: boxID, translation: translation)

        draggingMemoPreview = nil

        guard shouldOpen, let position else {
            return
        }

        memo.isSpatiallyPresented = true
        memo.spatialBoxID = boxID
        memo.spatialPosX = position.x
        memo.spatialPosY = position.y
        memo.spatialPosZ = position.z
        memo.isSpatiallyAnchored = false
        memo.spatialWorldAnchorIdentifier = nil

        upsertSpatialMemoPresentation(for: memo)
        saveSpatialMemoState(statusText: "메모를 공간에 펼침")
    }

    func deleteSpatialMemoPresentation(id: UUID) {
        Task {
            let anchorIdentifier = memos.first { $0.id == id }?.spatialWorldAnchorIdentifier
            try? await planeService.removeWorldAnchor(
                forObjectID: id,
                anchorIdentifier: anchorIdentifier
            )

            await MainActor.run {
                spatialMemoPresentations.removeAll { $0.id == id }
                spatialMemoDragStartPositions.removeValue(forKey: id)

                guard let memo = memos.first(where: { $0.id == id }) else {
                    return
                }

                memo.isSpatiallyPresented = false
                memo.spatialBoxID = nil
                memo.isSpatiallyAnchored = false
                memo.spatialWorldAnchorIdentifier = nil
                saveSpatialMemoState(statusText: "공간 메모 닫힘")
            }
        }
    }

    func deleteMemoFromSpatialPresentation(_ presentation: SpatialMemoPresentation) {
        Task {
            let anchorIdentifier = memos.first { $0.id == presentation.id }?.spatialWorldAnchorIdentifier
            try? await planeService.removeWorldAnchor(
                forObjectID: presentation.id,
                anchorIdentifier: anchorIdentifier
            )

            await MainActor.run {
                spatialMemoPresentations.removeAll { $0.id == presentation.id }
                spatialMemoDragStartPositions.removeValue(forKey: presentation.id)

                guard let memo = memos.first(where: { $0.id == presentation.id }) else {
                    return
                }

                modelContext.delete(memo)

                do {
                    try modelContext.save()
                    planeService.statusText = "메모 삭제됨"
                } catch {
                    modelContext.rollback()
                    planeService.statusText = "메모 삭제 실패: \(error.localizedDescription)"
                }
            }
        }
    }

    func moveSpatialMemoPresentation(id: UUID, translation: CGSize) {
        guard let presentation = spatialMemoPresentations.first(where: { $0.id == id }),
              !presentation.isAnchored
        else {
            spatialMemoDragStartPositions.removeValue(forKey: id)
            return
        }

        let startPosition = spatialMemoDragStartPositions[id] ?? presentation.position
        spatialMemoDragStartPositions[id] = startPosition

        updateSpatialMemoPresentation(id: id) { presentation in
            presentation.position = startPosition + spatialMemoMovement(for: translation)
        }
    }

    func finishMovingSpatialMemoPresentation(id: UUID) {
        spatialMemoDragStartPositions.removeValue(forKey: id)

        guard let presentation = spatialMemoPresentations.first(where: { $0.id == id }),
              let memo = memos.first(where: { $0.id == id })
        else {
            return
        }

        memo.spatialPosX = presentation.position.x
        memo.spatialPosY = presentation.position.y
        memo.spatialPosZ = presentation.position.z
        saveSpatialMemoState(statusText: "공간 메모 위치 저장됨")
    }

    func updateSpatialMemoPresentation(
        id: UUID,
        update: (inout SpatialMemoPresentation) -> Void
    ) {
        guard let index = spatialMemoPresentations.firstIndex(where: { $0.id == id }) else {
            return
        }

        update(&spatialMemoPresentations[index])
    }

    func restoreSpatialMemoPresentations() {
        let validBoxIDs = Set(persistedBoxes.map(\.id))
        let restored = memos.compactMap { memo -> SpatialMemoPresentation? in
            guard memo.isSpatiallyPresented,
                  let boxID = memo.spatialBoxID,
                  validBoxIDs.contains(boxID)
            else {
                return nil
            }

            return spatialMemoPresentation(for: memo, boxID: boxID)
        }

        spatialMemoPresentations = restored
        let restoredIDs = Set(restored.map(\.id))
        spatialMemoDragStartPositions = spatialMemoDragStartPositions.filter { restoredIDs.contains($0.key) }
    }

    func upsertSpatialMemoPresentation(for memo: MemoItem) {
        guard let boxID = memo.spatialBoxID else {
            return
        }

        let presentation = spatialMemoPresentation(for: memo, boxID: boxID)

        if let index = spatialMemoPresentations.firstIndex(where: { $0.id == presentation.id }) {
            spatialMemoPresentations[index] = presentation
        } else {
            spatialMemoPresentations.append(presentation)
        }
    }

    func spatialMemoPresentation(for memo: MemoItem, boxID: UUID) -> SpatialMemoPresentation {
        SpatialMemoPresentation(
            id: memo.id,
            boxID: boxID,
            text: memo.text,
            colorIndex: memo.colorIndex,
            position: SIMD3<Float>(memo.spatialPosX, memo.spatialPosY, memo.spatialPosZ),
            isAnchored: memo.isSpatiallyAnchored
        )
    }

    func saveSpatialMemoState(statusText: String? = nil) {
        do {
            try modelContext.save()

            if let statusText {
                planeService.statusText = statusText
            }
        } catch {
            modelContext.rollback()
            planeService.statusText = "공간 메모 저장 실패: \(error.localizedDescription)"
        }
    }
}
