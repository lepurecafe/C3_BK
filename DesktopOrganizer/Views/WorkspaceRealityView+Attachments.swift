import RealityKit
import SwiftUI

// RealityView Attachment로 등록한 SwiftUI View들을 실제 RealityKit scene graph에 붙입니다.
//
// 교재 연결:
// - 4장: entity에 SwiftUI 버튼 붙이기
// - 8장: entity 위에 목록 UI 붙이기
// - 10장: 드래그앤드롭으로 메모를 공간에 열기
// - 11장: SwiftUI 카드 UI를 공간 오브젝트처럼 다루기
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

        // 교재 10장/11장: preview도 attachment entity이므로 위치와 billboard를 RealityKit 쪽에서 제어합니다.
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

            // 교재 11장: SwiftUI 카드 UI를 attachment entity로 꺼내 rootEntity에 붙이면
            // 박스와 독립적으로 이동/고정/삭제할 수 있는 공간 오브젝트가 됩니다.
            if memoEntity.parent !== rootEntity {
                memoEntity.removeFromParent()
                memoEntity.name = spatialMemoAttachmentID(for: presentation.id)
                rootEntity.addChild(memoEntity)
            }

            // Billboard/InputTarget/HoverEffect는 SwiftUI 카드가 공간에서 읽히고 조작되게 하는 RealityKit 설정입니다.
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

            // 교재 8장: 메모 목록은 박스의 자식으로 붙여 박스를 드래그할 때 같이 움직이게 합니다.
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

        // 교재 4장: 선택된 박스가 바뀌면 같은 controls attachment를 새 boxRoot 아래로 옮깁니다.
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
