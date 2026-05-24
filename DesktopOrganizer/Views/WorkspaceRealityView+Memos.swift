import Foundation
import SwiftUI

// 박스 안 메모 생성, 드래그로 공간에 펼치기, 공간 메모 닫기/삭제/이동/복원을 담당합니다.
//
// 교재 연결:
// - 9장: 박스 안에서 메모 생성하기
// - 10장: 드래그앤드롭으로 메모를 공간에 열기
// - 11장: SwiftUI 카드 UI를 공간 오브젝트처럼 다루기
// - 12장: 공간 오브젝트 닫기, 삭제, 이동하기
// - 13장: 공간 오브젝트 위치 저장하기
extension WorkspaceRealityView {
    func memos(in boxID: UUID) -> [MemoItem] {
        memos.filter { $0.containerBoxID == boxID }
    }

    func createMemo(in boxID: UUID, text: String, colorIndex: Int) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        // 교재 9장: containerBoxID가 "이 메모가 어느 박스 안에 있는지"를 연결합니다.
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
        guard !memo.isSpatiallyPresented else {
            return
        }

        guard let position = spatialMemoDropPosition(in: boxID, translation: .zero) else {
            return
        }

        // 교재 11장/13장: 저장 모델에 "공간에 펼쳐져 있음"과 위치를 기록하고,
        // 화면 표시용 SpatialMemoPresentation을 만들어 attachment entity로 복원합니다.
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
        guard !memo.isSpatiallyPresented else {
            draggingMemoPreview = nil
            return
        }

        let shouldOpen = dragDistance(translation) >= memoDragActivationDistance
        let position = spatialMemoDropPosition(in: boxID, translation: translation)

        draggingMemoPreview = nil

        guard shouldOpen, let position else {
            return
        }

        // 교재 10장: 시스템 DropDelegate가 아니라 drag distance가 기준 이상이면 공간 메모로 전환합니다.
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

                // 교재 12장: 닫기는 메모를 공간에서 접어 박스 안 메모로 되돌립니다.
                // 이 앱의 제품 규칙은 "닫으면 pin도 해제"입니다. MemoItem 자체는 삭제하지 않습니다.
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

                // 교재 12장: 삭제는 presentation뿐 아니라 SwiftData의 MemoItem도 제거합니다.
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

        // 교재 12장: 드래그 중에는 화면 상태인 SpatialMemoPresentation.position만 먼저 바꿉니다.
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

        guard !presentation.isAnchored else {
            return
        }

        // 교재 13장: 드래그가 끝난 뒤에야 SwiftData 좌표를 갱신합니다.
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
