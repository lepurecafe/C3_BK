import RealityKit
import SwiftUI

extension WorkspaceRealityView {
    func updateDraggingMemoPreview(attachments: RealityViewAttachments) {
        guard let draggingMemoPreview,
              let boxRoot = sceneState.boxRoots[draggingMemoPreview.boxID],
              let preview = attachments.entity(for: draggingMemoPreviewAttachmentID)
        else {
            attachments.entity(for: draggingMemoPreviewAttachmentID)?.removeFromParent()
            return
        }

        if preview.parent !== boxRoot {
            preview.removeFromParent()
            boxRoot.addChild(preview)
        }

        configureMemoBillboard(preview)
        preview.position = spatialMemoPosition(for: draggingMemoPreview.translation)
    }

    func updateSpatialMemoPresentations(attachments: RealityViewAttachments) {
        guard let rootEntity = sceneState.rootEntity else {
            return
        }

        let activeAttachmentIDs = Set(spatialMemoPresentations.map(\.id))

        for presentation in spatialMemoPresentations {
            guard let memoEntity = attachments.entity(for: spatialMemoAttachmentID(for: presentation.id))
            else {
                continue
            }

            if memoEntity.parent !== rootEntity {
                memoEntity.removeFromParent()
                memoEntity.name = spatialMemoAttachmentID(for: presentation.id)
                rootEntity.addChild(memoEntity)
            }

            configureOpenedMemoEntity(memoEntity)
            memoEntity.position = presentation.position
        }

        // SwiftUI가 제거한 presentation의 attachment entity가 RealityKit scene에 남지 않도록 정리합니다.
        for child in rootEntity.children where child.name.hasPrefix("SpatialMemo:") {
            let rawID = child.name.replacingOccurrences(of: "SpatialMemo:", with: "")
            if let id = UUID(uuidString: rawID), !activeAttachmentIDs.contains(id) {
                child.removeFromParent()
            }
        }
    }

    func updateOpenBoxMemoLists(attachments: RealityViewAttachments) {
        for box in persistedBoxes {
            let attachmentID = memoListAttachmentID(for: box.id)

            guard workspaceStore.interactionMode(for: box.id) == .openForLookup,
                  let boxRoot = sceneState.boxRoots[box.id],
                  let memoList = attachments.entity(for: attachmentID)
            else {
                attachments.entity(for: attachmentID)?.removeFromParent()
                continue
            }

            if memoList.parent !== boxRoot {
                memoList.removeFromParent()
                boxRoot.addChild(memoList)
            }

            // 박스 root의 자식으로 두면 사용자가 박스를 드래그할 때 목록 패널도 같은 transform을 따라갑니다.
            memoList.position = SIMD3<Float>(0, 0.34, 0)
        }
    }

    func updateSelectedBoxControls(attachments: RealityViewAttachments) {
        guard let selectedBoxID = workspaceStore.selectedBoxID,
              let selectedBoxRoot = sceneState.boxRoots[selectedBoxID],
              let controls = attachments.entity(for: selectedBoxControlAttachmentID)
        else {
            attachments.entity(for: selectedBoxControlAttachmentID)?.removeFromParent()
            return
        }

        if controls.parent !== selectedBoxRoot {
            controls.removeFromParent()
            selectedBoxRoot.addChild(controls)
        }

        // 박스 root의 자식으로 두어 드래그 중에도 앵커 버튼이 박스와 같이 움직이게 합니다.
        controls.position = SIMD3<Float>(0, -0.12, 0.17)
    }

    func memoListAttachmentID(for id: UUID) -> String {
        "BoxMemoList:\(id.uuidString)"
    }

    func spatialMemoAttachmentID(for id: UUID) -> String {
        "SpatialMemo:\(id.uuidString)"
    }
}
