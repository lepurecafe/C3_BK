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
    private let selectedBoxControlAttachmentID = "SelectedBoxControls"

    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    @Environment(PlaneDetectionService.self) private var planeService
    @Query(sort: \OrganizerBox.createdAt) private var persistedBoxes: [OrganizerBox]
    @Query(sort: \MemoItem.createdAt) private var memos: [MemoItem]

    @State private var workspaceStore = WorkspaceEntityStore.shared
    @State private var rootEntity: Entity?
    @State private var renderedBoxIDs = Set<UUID>()
    @State private var boxRoots: [UUID: Entity] = [:]
    @State private var boxModels: [UUID: Entity] = [:]
    @State private var boxAnimations: [UUID: AnimationResource] = [:]
    @State private var animationControllers: [UUID: AnimationPlaybackController] = [:]
    @State private var animationTasks: [UUID: Task<Void, Never>] = [:]
    @State private var dragStartPositions: [UUID: SIMD3<Float>] = [:]
    @State private var tablePlaneDebugEntity: ModelEntity?

    var body: some View {
        RealityView { content, attachments in
            let root = Entity()
            root.name = "WorkspaceRoot"
            rootEntity = root
            content.add(root)

            updateSelectedBoxControls(attachments: attachments)
            updateOpenBoxMemoLists(attachments: attachments)
        } update: { content, attachments in
            updateSelectedBoxControls(attachments: attachments)
            updateOpenBoxMemoLists(attachments: attachments)
        } attachments: {
            Attachment(id: selectedBoxControlAttachmentID) {
                if let selectedBoxID = workspaceStore.selectedBoxID {
                    BoxAnchorControlView(
                        isAnchored: workspaceStore.isBoxAnchored(selectedBoxID)
                    ) {
                        Task {
                            await toggleAnchor(for: selectedBoxID)
                        }
                    }
                }
            }

            ForEach(persistedBoxes) { box in
                Attachment(id: memoListAttachmentID(for: box.id)) {
                    BoxMemoAttachmentView(
                        boxName: box.name,
                        memos: memos(in: box.id)
                    ) { memo in
                        openMemoWindow(memo)
                    }
                }
            }
        }
        .task(id: renderRevision) {
            await renderKnownBoxes()
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

                    dragStartPositions[boxID] = nil
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

    @MainActor
    private func renderKnownBoxes() async {
        guard let rootEntity else {
            return
        }

        for box in persistedBoxes where !renderedBoxIDs.contains(box.id) {
            await renderBox(
                id: box.id,
                name: box.name,
                position: workspacePosition(for: box),
                in: rootEntity
            )

            if box.isAnchored {
                workspaceStore.setBoxAnchored(true, for: box.id)
            }
        }

        for request in workspaceStore.boxRequests where !renderedBoxIDs.contains(request.id) {
            await renderBox(
                id: request.id,
                name: request.name,
                position: request.position,
                in: rootEntity
            )
        }
    }

    @MainActor
    private func resetRenderedWorkspace() {
        animationTasks.values.forEach { $0.cancel() }
        animationControllers.values.forEach { $0.stop() }
        boxRoots.values.forEach { $0.removeFromParent() }

        renderedBoxIDs.removeAll()
        boxRoots.removeAll()
        boxModels.removeAll()
        boxAnimations.removeAll()
        animationControllers.removeAll()
        animationTasks.removeAll()
        dragStartPositions.removeAll()
        tablePlaneDebugEntity?.removeFromParent()
        tablePlaneDebugEntity = nil
    }

    @MainActor
    private func applyKnownWorldAnchorTransforms() {
        for box in persistedBoxes {
            guard let boxRoot = boxRoots[box.id],
                  let anchorPosition = worldAnchorPosition(for: box)
            else {
                continue
            }

            boxRoot.position = anchorPosition
        }
    }

    @MainActor
    private func renderBox(id: UUID, name: String, position: SIMD3<Float>, in rootEntity: Entity) async {
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
        configureInputTargets(in: travelCase)
        travelCase.generateCollisionShapes(recursive: true)

        boxRoot.addChild(travelCase)
        rootEntity.addChild(boxRoot)

        boxRoots[id] = boxRoot
        boxModels[id] = travelCase
        boxAnimations[id] = firstAvailableAnimation(in: travelCase)
        renderedBoxIDs.insert(id)
    }

    private func fitTravelCaseForWorkspace(_ entity: Entity) {
        let bounds = entity.visualBounds(relativeTo: nil)
        let maxExtent = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))

        if maxExtent > 0 {
            // volumetric window 안에서는 0.35m 정도로 맞췄지만,
            // ImmersiveSpace에서는 실제 책상 위 물체처럼 보이도록 조금 더 크게 둡니다.
            let targetSize: Float = 0.45
            let uniformScale = targetSize / maxExtent
            entity.scale = SIMD3<Float>(repeating: uniformScale)
        }

        // 위치는 wrapper entity가 담당합니다.
        // 모델 entity는 wrapper 안에서 원점에 두어 animation과 transform 책임을 분리합니다.
        entity.position = .zero
    }

    private func workspacePosition(for box: OrganizerBox) -> SIMD3<Float> {
        worldAnchorPosition(for: box) ?? SIMD3<Float>(box.posX, box.posY, box.posZ)
    }

    @MainActor
    private func updateTablePlaneDebugOverlay() {
        guard let rootEntity else {
            return
        }

        guard let tablePlane = planeService.detectedTablePlane else {
            tablePlaneDebugEntity?.removeFromParent()
            tablePlaneDebugEntity = nil
            return
        }

        let width = max(tablePlane.geometry.extent.width, 0.1)
        let depth = max(tablePlane.geometry.extent.height, 0.1)
        let mesh = MeshResource.generatePlane(width: width, depth: depth)
        let material = SimpleMaterial(
            color: .cyan.withAlphaComponent(0.28),
            roughness: 0.7,
            isMetallic: false
        )

        let debugEntity = tablePlaneDebugEntity ?? ModelEntity()
        debugEntity.name = "DebugTablePlane"
        debugEntity.model = ModelComponent(mesh: mesh, materials: [material])
        debugEntity.transform.matrix = tablePlane.originFromAnchorTransform

        // 감지된 평면과 완전히 같은 높이에 두면 z-fighting처럼 깜빡일 수 있어 아주 조금 위로 올립니다.
        debugEntity.position.y += 0.003

        if debugEntity.parent == nil {
            rootEntity.addChild(debugEntity)
        }

        tablePlaneDebugEntity = debugEntity
    }

    private func worldAnchorPosition(for box: OrganizerBox) -> SIMD3<Float>? {
        guard let transform = planeService.worldAnchorTransform(for: box.worldAnchorIdentifier) else {
            return nil
        }

        let position = transform.columns.3
        return SIMD3<Float>(position.x, position.y, position.z)
    }

    private func toggleBoxOpenState(for boxID: UUID) {
        guard !workspaceStore.isBoxAnimating(boxID),
              let entity = boxModels[boxID],
              let animation = boxAnimations[boxID]
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

    private func openBox(
        id: UUID,
        mode: BoxInteractionMode,
        entity: Entity,
        animation: AnimationResource,
        onOpened: (() -> Void)? = nil
    ) {
        animationTasks[id]?.cancel()
        animationControllers[id]?.stop()

        let controller = entity.playAnimation(animation, transitionDuration: 0, startsPaused: true)
        let duration = max(controller.duration, 0.1)
        controller.speed = 1
        controller.time = 0

        animationControllers[id] = controller
        workspaceStore.setInteractionMode(.opening, for: id)
        controller.resume()

        animationTasks[id] = Task { @MainActor in
            let nanoseconds = UInt64(duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }

            controller.pause()
            controller.time = duration
            workspaceStore.setInteractionMode(mode, for: id)
            onOpened?()
        }
    }

    private func closeBox(id: UUID, entity: Entity, animation: AnimationResource) {
        animationTasks[id]?.cancel()
        animationControllers[id]?.stop()

        let controller = entity.playAnimation(animation, transitionDuration: 0, startsPaused: true)
        let duration = max(controller.duration, 0.1)
        controller.pause()
        controller.time = duration

        animationControllers[id] = controller
        workspaceStore.setInteractionMode(.closing, for: id)

        animationTasks[id] = Task { @MainActor in
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

    private func configureInputTargets(in entity: Entity) {
        entity.components.set(InputTargetComponent())
        entity.components.set(HoverEffectComponent())

        for child in entity.children {
            configureInputTargets(in: child)
        }
    }

    private func moveBox(with value: EntityTargetValue<DragGesture.Value>) {
        guard let boxID = boxID(for: value.entity),
              let boxRoot = boxRoots[boxID]
        else {
            return
        }

        workspaceStore.selectBox(id: boxID)

        guard !workspaceStore.isBoxAnchored(boxID) else {
            dragStartPositions[boxID] = nil
            return
        }

        let startPosition = dragStartPositions[boxID] ?? boxRoot.position
        dragStartPositions[boxID] = startPosition

        let movement = value.convert(value.translation3D, from: .global, to: .scene)
        boxRoot.position = startPosition + movement
    }

    @MainActor
    private func toggleAnchor(for boxID: UUID) async {
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
    private func addWorldAnchor(for boxID: UUID) async throws {
        guard let boxRoot = boxRoots[boxID],
              let box = persistedBoxes.first(where: { $0.id == boxID })
        else {
            return
        }

        let transform = boxRoot.transformMatrix(relativeTo: nil)
        let anchorID = try await planeService.addWorldAnchor(for: boxID, transform: transform)
        box.worldAnchorIdentifier = anchorID.uuidString
        try modelContext.save()
    }

    @MainActor
    private func removeWorldAnchor(for boxID: UUID) async throws {
        guard let box = persistedBoxes.first(where: { $0.id == boxID }) else {
            return
        }

        if box.worldAnchorIdentifier != nil {
            try await planeService.removeWorldAnchor(for: boxID)
        }

        box.worldAnchorIdentifier = nil
        try modelContext.save()
    }

    @MainActor
    private func applyTemporaryAnchorFallback(for boxID: UUID) {
        guard let box = persistedBoxes.first(where: { $0.id == boxID }) else {
            return
        }

        box.worldAnchorIdentifier = nil
        workspaceStore.setBoxAnchored(true, for: boxID)
        saveBoxAnchorState(boxID, isAnchored: true)
        planeService.statusText = "Simulator: 임시 앵커 적용됨"
    }

    private func isWorldAnchorUnavailable(_ error: Error) -> Bool {
        if case WorldAnchorError.unsupported = error {
            return true
        }

        let message = error.localizedDescription.lowercased()
        return message.contains("not supported") || message.contains("simulator")
    }

    private func saveBoxPosition(_ boxID: UUID) {
        guard let boxRoot = boxRoots[boxID] else {
            return
        }

        saveBoxState(boxID, isAnchored: workspaceStore.isBoxAnchored(boxID), position: boxRoot.position)
    }

    private func saveBoxAnchorState(_ boxID: UUID, isAnchored: Bool) {
        guard let boxRoot = boxRoots[boxID] else {
            return
        }

        saveBoxState(boxID, isAnchored: isAnchored, position: boxRoot.position)
    }

    private func saveBoxState(_ boxID: UUID, isAnchored: Bool, position: SIMD3<Float>) {
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

    private func memos(in boxID: UUID) -> [MemoItem] {
        memos.filter { $0.containerBoxID == boxID }
    }

    private func openMemoWindow(_ memo: MemoItem) {
        openWindow(
            value: MemoLabel(
                id: memo.id,
                text: memo.text,
                colorIndex: memo.colorIndex,
                cornerRadius: memo.cornerRadius
            )
        )
    }

    private func updateOpenBoxMemoLists(attachments: RealityViewAttachments) {
        for box in persistedBoxes {
            let attachmentID = memoListAttachmentID(for: box.id)

            guard workspaceStore.interactionMode(for: box.id) == .openForLookup,
                  let boxRoot = boxRoots[box.id],
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

    private func updateSelectedBoxControls(attachments: RealityViewAttachments) {
        guard let selectedBoxID = workspaceStore.selectedBoxID,
              let selectedBoxRoot = boxRoots[selectedBoxID],
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

    private func firstAvailableAnimation(in entity: Entity) -> AnimationResource? {
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

    private func boxID(for entity: Entity) -> UUID? {
        if let id = boxID(from: entity.name) {
            return id
        }

        guard let parent = entity.parent else {
            return nil
        }

        return boxID(for: parent)
    }

    private func boxID(from entityName: String) -> UUID? {
        guard entityName.hasPrefix("WorkspaceBox:") else {
            return nil
        }

        let rawID = entityName.replacingOccurrences(of: "WorkspaceBox:", with: "")
        return UUID(uuidString: rawID)
    }

    private func boxEntityName(for id: UUID) -> String {
        "WorkspaceBox:\(id.uuidString)"
    }

    private func memoListAttachmentID(for id: UUID) -> String {
        "BoxMemoList:\(id.uuidString)"
    }
}

private struct BoxAnchorControlView: View {
    let isAnchored: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            Label(
                isAnchored ? "앵커 ON" : "앵커 OFF",
                systemImage: isAnchored ? "pin.fill" : "pin"
            )
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(isAnchored ? .green : .gray)
        .glassBackgroundEffect()
    }
}

private struct BoxMemoAttachmentView: View {
    let boxName: String
    let memos: [MemoItem]
    let onMemoSelected: (MemoItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(boxName)
                .font(.headline)

            if memos.isEmpty {
                Text("박스 안에 메모가 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(memos) { memo in
                    Button {
                        onMemoSelected(memo)
                    } label: {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(MemoLabel.colors[memo.workspaceSafeColorIndex])
                                .frame(width: 12, height: 12)

                            Text(memo.text)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 260, alignment: .topLeading)
        .glassBackgroundEffect()
    }
}

private extension MemoItem {
    var workspaceSafeColorIndex: Int {
        guard MemoLabel.colors.indices.contains(colorIndex) else {
            return 0
        }

        return colorIndex
    }
}

#Preview {
    WorkspaceRealityView()
}
