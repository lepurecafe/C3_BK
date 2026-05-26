# 08. World Anchor와 영속성: 앱을 다시 열어도 제자리에 두기

Last updated: 2026-05-26

이 교재는 Desktop Organizer를 통해 World Anchor와 공간 오브젝트 영속성을 공부하기 위한 여덟 번째 교재다. 목표는 박스와 공간 메모가 앱 재실행 후에도 원래 자리에 복원되도록 SwiftData 저장값, RealityKit entity, ARKit WorldAnchor를 어떻게 연결하는지 이해하는 것이다.

## 1. 이 주제를 배우는 이유

공간 앱에서 "저장"은 텍스트나 숫자만 저장하는 문제가 아니다.

사용자는 박스와 메모가 실제 책상 위에 남아 있다고 기대한다. 앱을 껐다 켰을 때 박스가 다시 눈앞 기본 위치로 돌아오면 공간 앱의 신뢰감이 크게 떨어진다.

Desktop Organizer는 두 단계로 위치를 다룬다.

1. SwiftData에 좌표와 anchor id를 저장한다.
2. 실기기에서 WorldAnchor transform을 사용할 수 있으면 그 위치를 우선 적용한다.

즉, SwiftData는 "기록"이고 WorldAnchor는 "실제 공간 기준점"이다.

## 2. 좌표 저장과 WorldAnchor의 차이

| 구분 | SwiftData 좌표 | WorldAnchor |
| --- | --- | --- |
| 저장 위치 | `OrganizerBox.posX/Y/Z`, `MemoItem.spatialPosX/Y/Z` | ARKit WorldTrackingProvider |
| 기준 | 앱의 RealityKit scene 기준 좌표 | 실제 세계 공간 기준 |
| 앱 재실행 후 | 기록을 읽어 entity를 다시 배치 | ARKit이 anchor transform을 복원하면 실제 위치 우선 |
| Simulator | 사용 가능 | 지원 안 될 수 있음 |
| 회전/방향 | 현재는 위치 중심 | transform 전체를 가질 수 있음 |

현재 앱은 WorldAnchor transform에서 위치 성분만 사용한다. 회전 조작은 아직 제공하지 않기 때문이다.

## 3. 저장 모델에 들어 있는 anchor 정보

박스 모델에는 위치와 anchor id가 저장된다.

```swift
@Model
final class OrganizerBox {
    var posX: Float = 0
    var posY: Float = 1.0
    var posZ: Float = -1.0
    var isAnchored: Bool = false
    var worldAnchorIdentifier: String?
}
```

공간 메모에도 같은 역할의 필드가 있다.

```swift
@Model
final class MemoItem {
    var spatialPosX: Float = 0
    var spatialPosY: Float = 0
    var spatialPosZ: Float = 0
    var isSpatiallyAnchored: Bool = false
    var spatialWorldAnchorIdentifier: String?
}
```

`isAnchored`는 UI와 이동 가능 여부를 나타내고, `worldAnchorIdentifier`는 실제 ARKit WorldAnchor id를 저장한다.

## 4. WorldTrackingProvider는 어디서 시작되나

WorldAnchor를 쓰려면 `WorldTrackingProvider`가 필요하다. 이 앱은 `PlaneDetectionService`가 plane detection과 world tracking을 같은 ARKit session에서 실행한다.

```swift
private var arkitSession = ARKitSession()
private var planeDetection = PlaneDetectionProvider(alignments: [.horizontal])
private var worldTracking = WorldTrackingProvider()
```

감지 시작 시 world tracking이 지원되면 함께 실행한다.

```swift
if WorldTrackingProvider.isSupported {
    try await arkitSession.run([planeDetection, worldTracking])
    await refreshWorldAnchorCache()
    startWorldAnchorUpdatesIfNeeded()
} else {
    try await arkitSession.run([planeDetection])
}
```

이 구조 덕분에 책상 평면 인식과 WorldAnchor 관리가 같은 ARKit session 안에서 돌아간다.

## 5. WorldAnchor 생성 흐름

WorldAnchor 생성은 `PlaneDetectionService.addWorldAnchor`에서 처리한다.

```swift
func addWorldAnchor(
    forObjectID objectID: UUID,
    replacingAnchorIdentifier anchorIdentifier: String? = nil,
    transform: simd_float4x4
) async throws -> UUID {
    guard WorldTrackingProvider.isSupported else {
        throw WorldAnchorError.unsupported
    }

    let anchor = WorldAnchor(originFromAnchorTransform: transform)
    try await worldTracking.addAnchor(anchor)
    worldAnchorsByObjectID[objectID] = anchor
    worldAnchorTransformsByID[anchor.id] = anchor.originFromAnchorTransform
    worldAnchorRevision += 1
    return anchor.id
}
```

핵심은 `WorldAnchor(originFromAnchorTransform:)`이다. 단순 위치가 아니라 4x4 transform matrix를 넘긴다.

## 6. 박스 anchor 추가

박스 pin 버튼을 누르면 `toggleAnchor(for:)`가 실행된다.

```swift
func toggleAnchor(for boxID: UUID) async {
    let nextState = !workspaceStore.isBoxAnchored(boxID)

    if nextState {
        try await addWorldAnchor(for: boxID)
    } else {
        try await removeWorldAnchor(for: boxID)
    }
}
```

박스 anchor를 추가할 때는 현재 `boxRoot`의 world transform을 가져온다.

```swift
let transform = boxRoot.transformMatrix(relativeTo: nil)
let anchorID = try await planeService.addWorldAnchor(
    forObjectID: boxID,
    replacingAnchorIdentifier: box.worldAnchorIdentifier,
    transform: transform
)
box.worldAnchorIdentifier = anchorID.uuidString
```

즉, 현재 공간에 놓인 박스 위치를 실제 세계 기준 anchor로 저장한다.

## 7. 저장 실패 보상 처리

WorldAnchor 생성은 ARKit 쪽 작업이고, anchor id 저장은 SwiftData 작업이다. 둘 중 하나만 성공하면 상태가 꼬일 수 있다.

그래서 SwiftData 저장이 실패하면 방금 만든 WorldAnchor를 즉시 제거한다.

```swift
do {
    try modelContext.save()
} catch {
    try? await planeService.removeWorldAnchor(
        forObjectID: boxID,
        anchorIdentifier: anchorID.uuidString
    )
    box.worldAnchorIdentifier = previousAnchorIdentifier
    modelContext.rollback()
    throw error
}
```

이런 보상 처리는 중요하다.

앱이 anchor id를 저장하지 못했는데 ARKit에는 anchor가 남아 있으면, 나중에 그 anchor를 찾거나 지우기 어려워진다.

## 8. 박스 anchor 해제

anchor를 끌 때는 ARKit anchor를 제거하고 SwiftData의 id도 비운다.

```swift
if box.worldAnchorIdentifier != nil {
    try await planeService.removeWorldAnchor(
        forObjectID: boxID,
        anchorIdentifier: box.worldAnchorIdentifier
    )
}

box.worldAnchorIdentifier = nil
try modelContext.save()
```

그 뒤 `workspaceStore.setBoxAnchored(false, for: boxID)`와 저장 상태 갱신으로 드래그가 다시 가능해진다.

## 9. Simulator fallback

Simulator에서는 WorldAnchor가 지원되지 않을 수 있다.

실제로 다음과 같은 메시지를 볼 수 있다.

```text
Adding world anchors is not supported on Simulator.
```

이 앱은 WorldAnchor 생성 실패가 지원 불가 때문이면 임시 anchor fallback을 적용한다.

```swift
func applyTemporaryAnchorFallback(for boxID: UUID) {
    box.worldAnchorIdentifier = nil
    workspaceStore.setBoxAnchored(true, for: boxID)
    saveBoxAnchorState(boxID, isAnchored: true)
    planeService.statusText = "Simulator: 임시 앵커 적용됨"
}
```

이 fallback은 실제 세계 고정이 아니다. 하지만 Simulator에서 pin UI와 드래그 잠금 동작을 테스트할 수 있게 한다.

## 10. 위치 저장은 WorldAnchor와 별개로 계속 한다

박스를 드래그한 뒤에는 위치를 SwiftData에 저장한다.

```swift
func saveBoxPosition(_ boxID: UUID) {
    guard let boxRoot = sceneState.boxRoots[boxID] else {
        return
    }

    saveBoxState(boxID, isAnchored: workspaceStore.isBoxAnchored(boxID), position: boxRoot.position)
}
```

```swift
func saveBoxState(_ boxID: UUID, isAnchored: Bool, position: SIMD3<Float>) {
    box.posX = position.x
    box.posY = position.y
    box.posZ = position.z
    box.isAnchored = isAnchored
    try modelContext.save()
}
```

WorldAnchor가 없는 상황에서도 이 좌표는 앱 재실행 후 fallback 복원 위치가 된다.

## 11. WorldAnchor transform 우선 적용

앱을 다시 열면 SwiftData 좌표만 쓰지 않는다. WorldAnchor transform cache가 있으면 그것을 우선 적용한다.

```swift
func applyKnownWorldAnchorTransforms() {
    for box in persistedBoxes {
        guard let boxRoot = sceneState.boxRoots[box.id],
              let anchorPosition = worldAnchorPosition(for: box)
        else {
            continue
        }

        boxRoot.position = anchorPosition
    }
}
```

`worldAnchorPosition(for:)`는 anchor id로 transform을 찾고 위치 성분을 꺼낸다.

```swift
func worldAnchorPosition(for box: OrganizerBox) -> SIMD3<Float>? {
    guard let transform = planeService.worldAnchorTransform(for: box.worldAnchorIdentifier) else {
        return nil
    }

    let position = transform.columns.3
    return SIMD3<Float>(position.x, position.y, position.z)
}
```

## 12. anchor cache 복원

앱을 다시 열면 SwiftData에는 anchor id가 남아 있지만, `PlaneDetectionService`의 메모리 cache는 비어 있다.

그래서 world tracking이 시작된 뒤 기존 anchor들을 훑어서 cache를 다시 채운다.

```swift
func refreshWorldAnchorCache() async {
    guard WorldTrackingProvider.isSupported,
          let anchors = await worldTracking.allAnchors
    else {
        return
    }

    for anchor in anchors {
        worldAnchorTransformsByID[anchor.id] = anchor.originFromAnchorTransform
    }

    if !anchors.isEmpty {
        worldAnchorRevision += 1
        statusText = "월드 앵커 \(anchors.count)개 복원됨"
    }
}
```

`worldAnchorRevision`이 바뀌면 `WorkspaceRealityView`가 다시 anchor transform을 적용한다.

```swift
.task(id: planeService.worldAnchorRevision) {
    applyKnownWorldAnchorTransforms()
}
```

## 13. anchor update 계속 듣기

WorldAnchor도 추가/갱신/삭제 update를 보낸다.

```swift
worldAnchorUpdateTask = Task { @MainActor in
    for await update in worldTracking.anchorUpdates {
        switch update.event {
        case .added, .updated:
            worldAnchorTransformsByID[update.anchor.id] = update.anchor.originFromAnchorTransform
            scheduleWorldAnchorRevisionUpdate()
        case .removed:
            worldAnchorTransformsByID[update.anchor.id] = nil
            scheduleWorldAnchorRevisionUpdate()
        }
    }
}
```

이렇게 cache를 최신 상태로 유지해야 앱이 anchor 이동/복원 상태를 따라갈 수 있다.

## 14. 공간 메모 anchor

공간 메모도 박스와 비슷하게 anchor를 붙일 수 있다.

```swift
func toggleSpatialMemoAnchor(id: UUID) async {
    let nextState = !presentation.isAnchored

    if nextState {
        try await addWorldAnchor(forSpatialMemo: presentation)
    } else {
        try await removeWorldAnchor(forSpatialMemo: memo)
    }
}
```

공간 메모는 `boxRoot` 같은 RealityKit model entity가 아니라 attachment presentation으로 위치를 관리한다. 그래서 `presentation.position`을 transform matrix로 바꿔 anchor를 만든다.

```swift
let transform = transformMatrix(for: presentation.position)
let anchorID = try await planeService.addWorldAnchor(
    forObjectID: presentation.id,
    replacingAnchorIdentifier: memo.spatialWorldAnchorIdentifier,
    transform: transform
)
```

## 15. 위치를 transform matrix로 바꾸기

공간 메모 anchor에 쓰는 transform은 위치만 채운 identity matrix다.

```swift
func transformMatrix(for position: SIMD3<Float>) -> simd_float4x4 {
    var transform = matrix_identity_float4x4
    transform.columns.3 = SIMD4<Float>(position.x, position.y, position.z, 1)
    return transform
}
```

현재 앱은 회전 조작을 제공하지 않으므로 위치만 저장한다.

나중에 메모나 박스의 회전까지 저장하려면 transform 전체를 저장/복원하는 설계를 추가해야 한다.

## 16. 고정된 공간 메모는 드래그하지 않는다

`SpatialMemoOpenedAttachment`는 pin이 켜져 있으면 drag 입력을 무시한다.

```swift
DragGesture(minimumDistance: 8)
    .onChanged { value in
        guard !isAnchored else {
            return
        }

        onDragChanged(value.translation)
    }
```

이동 함수에서도 한 번 더 막는다.

```swift
guard let presentation = spatialMemoPresentations.first(where: { $0.id == id }),
      !presentation.isAnchored
else {
    spatialMemoDragStartPositions.removeValue(forKey: id)
    return
}
```

UI 입구와 데이터 처리 쪽에서 둘 다 막는 이유는 불필요한 저장 시도를 줄이고 상태를 더 안전하게 유지하기 위해서다.

## 17. 닫기와 anchor 해제

공간 메모를 닫으면 pin도 해제한다. 메모 데이터는 삭제하지 않고 박스 안 메모로 돌아간다.

```swift
memo.isSpatiallyPresented = false
memo.spatialBoxID = nil
memo.isSpatiallyAnchored = false
memo.spatialWorldAnchorIdentifier = nil
saveSpatialMemoState(statusText: "공간 메모 닫힘")
```

이 제품 규칙은 명확하다.

- 닫기: 공간에서 접고, 박스 안 메모는 유지
- 삭제: `MemoItem` 자체를 삭제
- pin: 공간에 펼쳐진 동안 위치 고정

## 18. 데이터 초기화와 anchor 제거

데이터 초기화는 SwiftData 모델만 지우면 부족하다. WorldAnchor도 같이 지워야 한다.

```swift
for box in boxes {
    try? await planeService.removeWorldAnchor(
        forObjectID: box.id,
        anchorIdentifier: box.worldAnchorIdentifier
    )
}

for memo in memos {
    try? await planeService.removeWorldAnchor(
        forObjectID: memo.id,
        anchorIdentifier: memo.spatialWorldAnchorIdentifier
    )
}
```

그 다음 모델을 삭제하고 workspace를 reset한다.

```swift
boxes.forEach { modelContext.delete($0) }
memos.forEach { modelContext.delete($0) }
try modelContext.save()
workspaceStore.resetWorkspace()
```

이 순서를 지켜야 화면에 남은 entity와 실제 anchor가 서로 어긋나지 않는다.

## 19. 박스 삭제와 anchor 제거

박스를 삭제할 때도 박스 anchor와 그 박스 안 메모 anchor를 제거한다.

```swift
try? await planeService.removeWorldAnchor(
    forObjectID: box.id,
    anchorIdentifier: box.worldAnchorIdentifier
)
for memo in memos(in: box.id) {
    try? await planeService.removeWorldAnchor(
        forObjectID: memo.id,
        anchorIdentifier: memo.spatialWorldAnchorIdentifier
    )
}
```

공간 앱에서 삭제는 화면에서 지우는 것뿐 아니라 실제 공간 anchor도 지우는 일이다.

## 20. 현재 구현의 한계

현재 구현은 위치 중심이다.

| 항목 | 현재 상태 |
| --- | --- |
| 박스 위치 | 저장/복원 |
| 공간 메모 위치 | 저장/복원 |
| WorldAnchor id | 저장/복원 |
| 회전 | 아직 위치만 사용 |
| scale | 모델 생성 시 고정 보정 |
| 여러 기기 동기화 | 없음 |

이전에 사용자가 말한 "window/volume처럼 이동 시 각도가 자연스럽게 바뀌는가"라는 문제는 여기와 연결된다.

WorldAnchor는 transform 전체를 가질 수 있지만, 현재 앱은 위치 성분만 복원한다. 회전까지 자연스럽게 다루려면 entity rotation, billboard, 사용자 기준 방향 정책을 별도 설계해야 한다.

## 21. Simulator와 실기기의 차이

WorldAnchor는 Simulator에서 제한될 수 있다.

| 환경 | 예상 |
| --- | --- |
| visionOS Simulator | WorldAnchor 추가가 지원되지 않을 수 있음, 임시 anchor fallback으로 UI 테스트 |
| Vision Pro 실기기 | WorldAnchor 생성/복원 테스트 필요 |

Simulator에서 pin 버튼이 "임시 앵커 적용됨"으로 동작한다면, 그것은 실제 공간 고정이 아니라 드래그 잠금과 UI 상태를 테스트하기 위한 fallback이다.

실제 고정 여부는 Vision Pro 실기기에서 앱 재실행 후 같은 위치에 복원되는지 확인해야 한다.

## 22. 실기기에서 확인할 것

| 확인 항목 | 봐야 할 것 |
| --- | --- |
| 박스 pin | pin 버튼이 초록색으로 바뀌고 드래그가 막히는가 |
| 박스 재실행 복원 | 앱을 껐다 켜도 같은 실제 위치에 있는가 |
| 메모 pin | 공간 메모 아래 pin 버튼이 동작하는가 |
| 메모 재실행 복원 | 공간에 펼친 메모가 같은 위치로 돌아오는가 |
| anchor 해제 | pin을 끄면 다시 이동 가능한가 |
| 데이터 초기화 | 박스/메모와 anchor가 함께 사라지는가 |
| 삭제 | 박스 삭제 시 관련 메모 anchor도 제거되는가 |
| Simulator fallback | Simulator에서는 임시 anchor로 드래그 잠금만 확인되는가 |

## 23. 코드 읽는 순서

WorldAnchor와 영속성을 공부하려면 아래 순서가 좋다.

1. `DesktopOrganizer/Models/OrganizerBox.swift`
2. `DesktopOrganizer/Models/MemoItem.swift`
3. `DesktopOrganizer/Services/PlaneDetectionService.swift`
4. `DesktopOrganizer/Views/WorkspaceRealityView+Anchors.swift`
5. `DesktopOrganizer/Views/WorkspaceRealityView+Boxes.swift`
6. `DesktopOrganizer/Views/WorkspaceRealityView+Memos.swift`
7. `DesktopOrganizer/Views/BoxControlAttachmentView.swift`
8. `DesktopOrganizer/Views/SpatialMemoAttachmentViews.swift`
9. `DesktopOrganizer/Views/ControlPanelView.swift`

## 24. 다음 교재와의 연결

이 교재를 읽은 뒤에는 `09-visionos-ux-for-spatial-tools.html`로 넘어가면 좋다.

8번 교재에서 실제 공간에 오브젝트를 고정하고 복원하는 기술을 배웠다면, 9번 교재에서는 사용자가 그 상태를 어떻게 이해하고 조작하게 만들지 UX 관점에서 공부한다.

## 25. 체크리스트

아래 질문에 답할 수 있으면 8번 교재의 목표를 달성한 것이다.

- SwiftData 좌표와 WorldAnchor의 차이를 설명할 수 있는가?
- `worldAnchorIdentifier`가 왜 SwiftData에 저장되는지 말할 수 있는가?
- WorldAnchor 생성 후 SwiftData 저장 실패 시 anchor를 제거하는 이유를 설명할 수 있는가?
- Simulator fallback이 실제 WorldAnchor가 아닌 이유를 말할 수 있는가?
- 앱 재실행 후 WorldAnchor cache를 다시 채우는 흐름을 설명할 수 있는가?
- 박스와 공간 메모의 anchor 처리 차이를 설명할 수 있는가?
- 데이터 초기화 때 WorldAnchor도 함께 제거해야 하는 이유를 말할 수 있는가?
