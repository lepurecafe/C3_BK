import Foundation
import RealityKit
import RealityKitContent
import SwiftData
import SwiftUI

// ImmersiveSpace 안에서 실제 공간 오브젝트들을 직접 관리할 RealityKit 화면입니다.
//
// 저장된 OrganizerBox와 WorkspaceEntityStore 요청을 읽어 TravelCase entity를 만들고,
// 탭/드래그/앵커/메모 목록 attachment/평면 디버그 시각화를 한곳에서 연결합니다.
// 박스는 volumetric window가 아니라 ImmersiveSpace 안의 실제 공간 entity로 운용됩니다.
//
// 교재 연결:
// - 3장: 공간에 3D entity 배치하기
// - 4장: entity에 SwiftUI 버튼 붙이기
// - 5장: entity 탭과 선택 상태 처리하기
// - 8장: entity 위에 목록 UI 붙이기
// - 10장: 드래그앤드롭으로 메모를 공간에 열기
// - 11장: SwiftUI 카드 UI를 공간 오브젝트처럼 다루기
struct WorkspaceRealityView: View {
    let selectedBoxControlAttachmentID = "SelectedBoxControls"
    let draggingMemoPreviewAttachmentID = "DraggingMemoPreview"
    let travelCaseSurfaceOffset: Float = -0.12
    let memoDragActivationDistance = WorkspaceInteractionMetrics.memoDragActivationDistance
    let memoDragMetersPerPoint: Float = 0.001

    @Environment(\.modelContext) var modelContext
    @Environment(PlaneDetectionService.self) var planeService
    @Query(sort: \OrganizerBox.createdAt) var persistedBoxes: [OrganizerBox]
    @Query(sort: \MemoItem.createdAt) var memos: [MemoItem]

    @State var workspaceStore = WorkspaceEntityStore.shared
    @State var sceneState = WorkspaceRealitySceneState()
    @State var draggingMemoPreview: DraggingMemoPreview?
    @State var spatialMemoPresentations: [SpatialMemoPresentation] = []
    @State var spatialMemoDragStartPositions: [UUID: SIMD3<Float>] = [:]

    var body: some View {
        RealityView { content, attachments in
            let root = Entity()
            root.name = "WorkspaceRoot"
            sceneState.rootEntity = root
            content.add(root)

            Task { @MainActor in
                await renderKnownBoxes()
                restoreSpatialMemoPresentations()
                applyKnownWorldAnchorTransforms()
            }

            updateTablePlaneDebugOverlay()
            updateSelectedBoxControls(attachments: attachments)
            updateOpenBoxMemoLists(attachments: attachments)
            updateDraggingMemoPreview(attachments: attachments)
            updateSpatialMemoPresentations(attachments: attachments)
        } update: { content, attachments in
            updateTablePlaneDebugOverlay()
            updateSelectedBoxControls(attachments: attachments)
            updateOpenBoxMemoLists(attachments: attachments)
            updateDraggingMemoPreview(attachments: attachments)
            updateSpatialMemoPresentations(attachments: attachments)
        } attachments: {
            // 교재 4장: SwiftUI로 만든 버튼 UI를 Attachment로 등록한 뒤,
            // updateSelectedBoxControls에서 RealityKit entity처럼 꺼내 박스 아래에 붙입니다.
            Attachment(id: selectedBoxControlAttachmentID) {
                if let selectedBoxID = workspaceStore.selectedBoxID,
                   let selectedBox = persistedBoxes.first(where: { $0.id == selectedBoxID }) {
                    BoxControlAttachmentView(
                        boxName: selectedBox.name,
                        isAnchored: workspaceStore.isBoxAnchored(selectedBoxID),
                        onDelete: {
                            deleteBox(selectedBox)
                        },
                        onToggle: {
                            Task {
                                await toggleAnchor(for: selectedBoxID)
                            }
                        }
                    )
                }
            }

            // 교재 8장: 박스별 메모 목록도 SwiftUI View지만,
            // Attachment로 등록하면 박스 위에 붙는 공간 UI처럼 배치할 수 있습니다.
            ForEach(persistedBoxes) { box in
                Attachment(id: memoListAttachmentID(for: box.id)) {
                    BoxMemoAttachmentView(
                        boxName: box.name,
                        memos: memos(in: box.id),
                        onMemoCreated: { text, colorIndex in
                            createMemo(in: box.id, text: text, colorIndex: colorIndex)
                        },
                        onMemosDeleted: { memoIDs in
                            deleteMemos(ids: memoIDs)
                        },
                        onMemoDragChanged: { memo, translation in
                            updateDraggingMemoPreview(for: memo, in: box.id, translation: translation)
                        },
                        onMemoDragEnded: { memo, translation in
                            finishDraggingMemoPreview(for: memo, in: box.id, translation: translation)
                        }
                    ) { memo in
                        openSpatialMemo(memo, in: box.id)
                    }
                }
            }

            // 교재 10장: 메모 카드를 드래그 중일 때만 임시 preview attachment를 만듭니다.
            if let draggingMemoPreview {
                Attachment(id: draggingMemoPreviewAttachmentID) {
                    SpatialMemoPreviewAttachment(
                        text: draggingMemoPreview.text,
                        colorIndex: draggingMemoPreview.colorIndex
                    )
                }
            }

            // 교재 11장: 공간에 열린 메모 카드입니다.
            // SwiftUI View -> Attachment -> RealityKit entity -> rootEntity.addChild 흐름으로 공간 오브젝트처럼 다룹니다.
            ForEach(spatialMemoPresentations) { presentation in
                Attachment(id: spatialMemoAttachmentID(for: presentation.id)) {
                    SpatialMemoOpenedAttachment(
                        title: presentation.title,
                        text: presentation.text,
                        colorIndex: presentation.colorIndex,
                        isAnchored: presentation.isAnchored,
                        onClose: {
                            deleteSpatialMemoPresentation(id: presentation.id)
                        },
                        onDelete: {
                            deleteMemoFromSpatialPresentation(presentation)
                        },
                        onToggleAnchor: {
                            Task {
                                await toggleSpatialMemoAnchor(id: presentation.id)
                            }
                        },
                        onDragChanged: { translation in
                            moveSpatialMemoPresentation(id: presentation.id, translation: translation)
                        },
                        onDragEnded: {
                            finishMovingSpatialMemoPresentation(id: presentation.id)
                        }
                    )
                }
            }
        }
        .task(id: renderRevision) {
            await renderKnownBoxes()
        }
        .task(id: spatialMemoPersistenceRevision) {
            restoreSpatialMemoPresentations()
        }
        .task(id: workspaceStore.resetRevision) {
            resetRenderedWorkspace()
        }
        .task(id: planeService.worldAnchorRevision) {
            applyKnownWorldAnchorTransforms()
        }
        .task(id: planeService.tablePlaneDebugRevision) {
            updateTablePlaneDebugOverlay()
        }
        .simultaneousGesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard let boxID = boxID(for: value.entity) else {
                        return
                    }

                    workspaceStore.selectBox(id: boxID)
                    toggleBoxOpenState(for: boxID)
                }
        )
        .simultaneousGesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    moveBox(with: value)
                }
                .onEnded { value in
                    guard let boxID = boxID(for: value.entity) else {
                        return
                    }

                    sceneState.dragStartPositions[boxID] = nil
                    saveBoxPosition(boxID)
                }
        )
    }

    private var renderRevision: String {
        // SwiftUI의 .task(id:)는 id 값이 바뀔 때 다시 실행됩니다.
        // workspaceStore.revision은 새 박스 요청을, persistedIDs는 SwiftData에 저장된 박스 목록 변화를 나타냅니다.
        // 둘을 문자열로 합쳐 두면 "새 요청"과 "저장 데이터 변화" 어느 쪽이든 renderKnownBoxes가 다시 호출됩니다.
        let persistedIDs = persistedBoxes
            .map(\.id.uuidString)
            .joined(separator: "|")

        return "\(workspaceStore.revision):\(persistedIDs)"
    }

    private var spatialMemoPersistenceRevision: String {
        // 공간 메모는 위치, 열린 상태, anchor id가 바뀔 때 attachment 복원이 다시 필요합니다.
        // @Query 배열 자체는 같은 MemoItem 객체를 가리킬 수 있으므로,
        // 복원에 영향을 주는 필드들을 문자열로 펼쳐 .task(id:)가 변화를 감지하게 합니다.
        memos
            .map { memo in
                [
                    memo.id.uuidString,
                    memo.containerBoxID?.uuidString ?? "none",
                    memo.isSpatiallyPresented.description,
                    memo.spatialBoxID?.uuidString ?? "none",
                    String(memo.spatialPosX),
                    String(memo.spatialPosY),
                    String(memo.spatialPosZ),
                    memo.isSpatiallyAnchored.description,
                    memo.spatialWorldAnchorIdentifier ?? "none"
                ].joined(separator: ",")
            }
            .joined(separator: "|")
    }
}
