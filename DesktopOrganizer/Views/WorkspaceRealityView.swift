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

            if let draggingMemoPreview {
                Attachment(id: draggingMemoPreviewAttachmentID) {
                    SpatialMemoPreviewAttachment(
                        text: draggingMemoPreview.text,
                        colorIndex: draggingMemoPreview.colorIndex
                    )
                }
            }

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
        let persistedIDs = persistedBoxes
            .map(\.id.uuidString)
            .joined(separator: "|")

        return "\(workspaceStore.revision):\(persistedIDs)"
    }

    private var spatialMemoPersistenceRevision: String {
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
