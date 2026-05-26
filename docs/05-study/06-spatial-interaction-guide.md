# 06. Spatial Interaction: 보고, 탭하고, 드래그하는 공간 상호작용

Last updated: 2026-05-26

이 교재는 Desktop Organizer를 통해 visionOS 공간 상호작용을 공부하기 위한 여섯 번째 교재다. 목표는 사용자의 시선/hover, tap, pinch/drag, 메모 드래그 preview, 공간 메모 이동이 SwiftUI와 RealityKit 사이에서 어떻게 연결되는지 이해하는 것이다.

## 1. 이 주제를 배우는 이유

공간 앱은 버튼을 누르는 앱에서 끝나지 않는다. 사용자는 실제 공간 속 오브젝트를 보고, 선택하고, 잡고, 움직인다.

Desktop Organizer의 핵심 상호작용은 다음과 같다.

- 박스를 바라보면 hover feedback이 나타난다.
- 박스를 탭하면 선택되고 열림/닫힘 animation이 재생된다.
- 박스를 드래그하면 책상 위 공간에서 이동한다.
- 박스 안 메모 카드를 바라보면 강조된다.
- 메모 카드를 끌면 원본은 남고 preview가 공간으로 움직인다.
- 일정 거리 이상 드래그 후 손을 놓으면 공간 메모로 열린다.
- 열린 공간 메모는 다시 드래그해서 옮길 수 있다.

이 교재는 이 흐름을 코드 기준으로 연결한다.

## 2. 공간 상호작용의 두 층

Desktop Organizer에는 상호작용 층이 두 가지 있다.

| 층 | 대상 | 대표 코드 |
| --- | --- | --- |
| RealityKit entity 상호작용 | 박스 entity, 공간 메모 attachment entity | `.targetedToAnyEntity()`, `InputTargetComponent`, `CollisionComponent` |
| SwiftUI attachment 내부 상호작용 | 메모 카드, 버튼, hover, drag | `.onTapGesture`, `.onHover`, `DragGesture`, `Button` |

박스 자체를 잡고 움직이는 것은 RealityKit entity 상호작용이다.

박스 위 attachment 안에서 메모 카드를 드래그하는 것은 SwiftUI view 상호작용에서 시작하지만, 결과는 RealityKit attachment entity로 이어진다.

## 3. 입력 가능한 entity 만들기

RealityKit entity가 targeted gesture의 대상이 되려면 입력 대상 component와 collision shape가 필요하다.

```swift
func configureInputTargets(in entity: Entity) {
    entity.components.set(InputTargetComponent())
    entity.components.set(HoverEffectComponent())

    for child in entity.children {
        configureInputTargets(in: child)
    }
}
```

박스 모델에는 child entity가 있을 수 있으므로 재귀적으로 component를 붙인다.

그리고 collision shape를 생성한다.

```swift
travelCase.generateCollisionShapes(recursive: true)
```

이 두 가지가 있어야 사용자의 시선, 손, 포인터, gesture가 entity를 대상으로 삼을 수 있다.

## 4. HoverEffectComponent와 시각 피드백

박스에는 `HoverEffectComponent`가 붙어 있다.

```swift
entity.components.set(HoverEffectComponent())
```

이 component는 사용자가 entity를 바라보거나 포인터가 닿을 때 시스템이 제공하는 hover feedback을 줄 수 있게 한다.

이 프로젝트에서 박스가 "보고 있는 대상"처럼 살짝 반응하는 것은 수동으로 색을 바꾸는 방식이 아니라, RealityKit component를 붙여 시스템 hover 효과를 받는 방식이다.

메모 카드 쪽은 SwiftUI hover 상태를 직접 관리한다.

```swift
.hoverEffect(.highlight)
.onHover { isHovered in
    hoveredMemoID = isHovered ? memo.id : nil
}
```

즉, 박스 hover는 RealityKit component 중심이고, attachment 내부 카드 hover는 SwiftUI view 상태 중심이다.

## 5. 박스 탭: 선택과 열림/닫힘

`WorkspaceRealityView`는 모든 entity를 대상으로 tap gesture를 등록한다.

```swift
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
```

사용자가 탭한 entity가 박스 모델의 child일 수도 있기 때문에 `boxID(for:)`가 부모를 따라 올라가며 `WorkspaceBox:<UUID>` 이름을 찾는다.

```swift
func boxID(for entity: Entity) -> UUID? {
    if let id = boxID(from: entity.name) {
        return id
    }

    guard let parent = entity.parent else {
        return nil
    }

    return boxID(for: parent)
}
```

탭의 결과는 두 가지다.

1. 선택된 박스 id가 바뀐다.
2. 박스 열림/닫힘 animation이 실행된다.

## 6. 박스 열림/닫힘 상호작용

박스 탭은 `toggleBoxOpenState(for:)`로 이어진다.

```swift
func toggleBoxOpenState(for boxID: UUID) {
    guard !workspaceStore.isBoxAnimating(boxID),
          let entity = sceneState.boxModels[boxID],
          let animation = sceneState.boxAnimations[boxID]
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
```

여기서 중요한 상태는 `BoxInteractionMode`다.

```swift
enum BoxInteractionMode: Equatable {
    case closed
    case opening
    case openForLookup
    case closing
}
```

animation 중에는 다시 탭해도 중복 실행되지 않도록 `isBoxAnimating`으로 막는다.

## 7. 박스 드래그 이동

박스 이동은 targeted `DragGesture`로 처리한다.

```swift
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
```

드래그 중에는 `boxRoot.position`을 바꾼다.

```swift
let startPosition = sceneState.dragStartPositions[boxID] ?? boxRoot.position
sceneState.dragStartPositions[boxID] = startPosition

let movement = value.convert(value.translation3D, from: .global, to: .scene)
boxRoot.position = startPosition + movement
```

여기서 `value.convert(..., from: .global, to: .scene)`가 중요하다. 사용자의 gesture 이동량을 RealityKit scene 좌표계로 바꾸는 작업이다.

## 8. 고정된 박스는 움직이지 않는다

박스가 pin으로 고정되어 있으면 드래그 이동을 막는다.

```swift
guard !workspaceStore.isBoxAnchored(boxID) else {
    sceneState.dragStartPositions[boxID] = nil
    return
}
```

이것은 UX적으로 중요하다.

고정 버튼이 켜진 오브젝트는 사용자가 잡아도 위치가 바뀌지 않아야 한다. 그렇지 않으면 "고정"의 의미가 사라진다.

## 9. 박스 안 메모 카드 hover

박스 안 메모 목록은 `BoxMemoAttachmentView` 안에 있다. 이 내부는 SwiftUI view이므로 SwiftUI hover를 쓴다.

```swift
.hoverEffect(.highlight)
.onHover { isHovered in
    hoveredMemoID = isHovered ? memo.id : nil
}
```

hover 상태는 카드 UI에 전달된다.

```swift
MemoPreviewCard(
    memo: memo,
    isLookedAt: hoveredMemoID == memo.id,
    isDragging: draggingMemoID == memo.id,
    isReadyToOpen: ...
)
```

카드는 `isLookedAt` 상태에 따라 눈 아이콘, 테두리, scale 효과를 보여준다.

```swift
if isLookedAt {
    Image(systemName: "eye.fill")
}
```

## 10. 메모 카드 선택과 삭제

메모 목록에는 선택 모드가 있다.

```swift
@State private var isSelectingMemos = false
@State private var selectedMemoIDs = Set<UUID>()
```

선택 모드에서 카드를 탭하면 삭제 대상에 들어가거나 빠진다.

```swift
if isSelectingMemos {
    toggleSelection(for: memo.id)
} else if memo.isSpatiallyPresented {
    return
} else {
    onMemoSelected(memo)
}
```

선택 상태는 `MemoItem`에 저장하지 않는다. 선택은 앱 데이터가 아니라 현재 화면의 임시 UI 상태이기 때문이다.

## 11. 메모 드래그 시작

메모 카드는 `highPriorityGesture`로 drag gesture를 받는다.

```swift
.highPriorityGesture(memoDragGesture(for: memo))
```

드래그가 시작되면 attachment 내부 상태와 바깥 RealityKit preview 상태가 함께 바뀐다.

```swift
draggingMemoID = memo.id
draggingMemoTranslation = value.translation
onMemoDragChanged(memo, value.translation)
```

`onMemoDragChanged`는 `WorkspaceRealityView`의 `updateDraggingMemoPreview`로 연결된다.

```swift
draggingMemoPreview = DraggingMemoPreview(
    boxID: boxID,
    text: memo.text,
    colorIndex: memo.colorIndex,
    translation: translation
)
```

## 12. 원본은 남고 preview가 움직인다

메모 드래그에서 중요한 UX는 "원본 메모는 목록에 남아 있고, 반투명 preview가 공간으로 움직인다"는 점이다.

SwiftUI 카드 쪽에서는 원본 카드 opacity를 낮춘다.

```swift
.opacity(draggingMemoID == memo.id ? 0.72 : 1)
```

RealityKit 쪽에서는 preview attachment를 박스 root 아래에 붙이고 위치를 갱신한다.

```swift
if preview.parent !== boxRoot {
    preview.removeFromParent()
    boxRoot.addChild(preview)
}

configureMemoBillboard(preview)
preview.position = spatialMemoPosition(for: draggingMemoPreview.translation)
```

이 구조 덕분에 사용자는 "카드를 밖으로 꺼내고 있다"는 시각 피드백을 받는다.

## 13. 드래그 거리 기준

메모는 조금 움직였다고 바로 공간으로 열리지 않는다. 일정 거리 이상 드래그해야 한다.

```swift
enum WorkspaceInteractionMetrics {
    static let memoDragActivationDistance: CGFloat = 72
}
```

거리 계산은 x/y 이동량을 하나의 값으로 바꾼다.

```swift
func dragDistance(_ translation: CGSize) -> CGFloat {
    sqrt((translation.width * translation.width) + (translation.height * translation.height))
}
```

72pt 이상이면 카드에는 "놓으면 열림" 상태가 표시된다.

## 14. 2D drag를 3D 위치로 변환

SwiftUI `DragGesture`는 2D point 단위의 `CGSize`를 준다. 공간 preview는 RealityKit 3D 좌표로 움직여야 한다.

```swift
func spatialMemoPosition(for translation: CGSize) -> SIMD3<Float> {
    SIMD3<Float>(
        Float(translation.width) * memoDragMetersPerPoint,
        0.34 - Float(translation.height) * memoDragMetersPerPoint,
        0.03
    )
}
```

`memoDragMetersPerPoint`는 화면 point를 공간 좌표로 축소하는 값이다.

```swift
let memoDragMetersPerPoint: Float = 0.001
```

화면에서 아래로 끌면 `translation.height`는 양수지만, RealityKit에서 위쪽은 y 양수다. 그래서 y축에는 마이너스가 들어간다.

## 15. 손을 놓으면 공간 메모로 열린다

드래그가 끝나면 조건을 확인한다.

```swift
let shouldOpen = dragDistance(translation) >= memoDragActivationDistance
let position = spatialMemoDropPosition(in: boxID, translation: translation)

draggingMemoPreview = nil

guard shouldOpen, let position else {
    return
}
```

조건을 만족하면 `MemoItem`에 공간 표시 상태와 위치를 저장한다.

```swift
memo.isSpatiallyPresented = true
memo.spatialBoxID = boxID
memo.spatialPosX = position.x
memo.spatialPosY = position.y
memo.spatialPosZ = position.z
```

그리고 화면용 presentation을 만든다.

```swift
upsertSpatialMemoPresentation(for: memo)
saveSpatialMemoState(statusText: "메모를 공간에 펼침")
```

## 16. 열린 공간 메모 이동

공간에 열린 메모도 다시 드래그할 수 있다.

`SpatialMemoOpenedAttachment` 안에는 `DragGesture`가 있다.

```swift
DragGesture(minimumDistance: 8)
    .onChanged { value in
        guard !isAnchored else {
            return
        }

        onDragChanged(value.translation)
    }
    .onEnded { _ in
        guard !isAnchored else {
            return
        }

        onDragEnded()
    }
```

이 입력은 `moveSpatialMemoPresentation`으로 이어진다.

```swift
let startPosition = spatialMemoDragStartPositions[id] ?? presentation.position
spatialMemoDragStartPositions[id] = startPosition

updateSpatialMemoPresentation(id: id) { presentation in
    presentation.position = startPosition + spatialMemoMovement(for: translation)
}
```

드래그가 끝나면 SwiftData 위치를 저장한다.

```swift
memo.spatialPosX = presentation.position.x
memo.spatialPosY = presentation.position.y
memo.spatialPosZ = presentation.position.z
saveSpatialMemoState(statusText: "공간 메모 위치 저장됨")
```

## 17. 열린 메모 hover와 시각 피드백

공간에 열린 메모는 SwiftUI attachment지만, 사용자가 바라보는 상태를 표시해야 한다.

```swift
@State private var isLookedAt = false
```

카드에 hover effect와 onHover를 붙인다.

```swift
.hoverEffect(.highlight)
.onHover { isHovered in
    isLookedAt = isHovered
}
.scaleEffect(isLookedAt ? 1.03 : 1)
```

카드 내부는 `isLookedAt`일 때 "보고 있음"과 눈 아이콘을 보여준다.

```swift
Label("보고 있음", systemImage: "eye.fill")
```

공간 상호작용에서는 이런 피드백이 매우 중요하다. 사용자가 무엇을 보고 있고, 무엇을 잡을 수 있는지 알 수 있어야 한다.

## 18. BillboardComponent와 읽기 방향

공간 메모는 카드 UI라서 사용자가 읽기 쉬운 방향을 유지해야 한다.

```swift
func configureMemoBillboard(_ entity: Entity) {
    var billboard = BillboardComponent()
    billboard.blendFactor = 0.75
    entity.components.set(billboard)
}
```

`BillboardComponent`는 attachment entity가 어느 정도 사용자를 향하게 해 준다.

열린 메모에는 billboard, input target, hover effect를 함께 붙인다.

```swift
func configureOpenedMemoEntity(_ entity: Entity) {
    configureMemoBillboard(entity)
    entity.components.set(InputTargetComponent())
    entity.components.set(HoverEffectComponent())
}
```

## 19. 상호작용 상태와 저장 상태 분리

공간 상호작용에서 상태를 바로 저장하지 않는 것이 중요하다.

| 상황 | 먼저 바꾸는 상태 | 저장 시점 |
| --- | --- | --- |
| 메모 카드 드래그 중 | `draggingMemoPreview`, `draggingMemoTranslation` | 손을 놓고 열림 조건 충족 시 |
| 공간 메모 이동 중 | `SpatialMemoPresentation.position` | 드래그 종료 시 |
| 박스 이동 중 | `boxRoot.position` | 드래그 종료 시 `saveBoxPosition` |
| hover 중 | `hoveredMemoID`, `isLookedAt` | 저장하지 않음 |

hover와 선택 같은 상태는 앱 데이터가 아니다. 드래그 중 위치도 아직 확정된 데이터가 아니다.

## 20. 실기기에서 확인할 것

공간 상호작용은 시뮬레이터보다 실기기에서 확인해야 할 것이 많다.

| 확인 항목 | 봐야 할 것 |
| --- | --- |
| 박스 hover | 시선이 닿을 때 박스가 인식되는 느낌이 있는가 |
| 박스 탭 | 탭이 의도한 박스에 들어가는가 |
| 박스 드래그 | 핀치해서 움직일 때 버튼/메모 목록이 같이 따라오는가 |
| 고정된 박스 | pin이 켜지면 움직이지 않는가 |
| 메모 카드 hover | 보고 있는 카드가 시각적으로 구분되는가 |
| 메모 drag preview | 원본은 남고 반투명 preview가 밖으로 나오는가 |
| 놓으면 열림 | 충분히 끌었을 때 상태 문구와 초록 피드백이 보이는가 |
| 열린 공간 메모 이동 | 다시 잡아서 움직일 수 있는가 |

## 21. 자주 헷갈리는 지점

### 박스 드래그와 메모 드래그는 같은 drag가 아니다

박스 드래그는 RealityKit entity 대상 gesture다. 메모 카드 드래그는 SwiftUI attachment 내부 gesture에서 시작한다.

### hover도 두 방식이 있다

박스 hover는 `HoverEffectComponent` 중심이고, 메모 카드 hover는 SwiftUI `onHover` 상태 중심이다.

### 드래그 중에는 저장하지 않는다

드래그 중에는 화면 상태를 바꾸고, 손을 놓은 뒤에 SwiftData에 저장한다.

### preview와 열린 메모는 다르다

`SpatialMemoPreviewAttachment`는 드래그 중 미리보기다. `SpatialMemoOpenedAttachment`는 실제 공간에 열린 메모다.

## 22. 코드 읽는 순서

공간 상호작용을 공부하려면 아래 순서가 좋다.

1. `DesktopOrganizer/Views/WorkspaceRealityView.swift`
2. `DesktopOrganizer/Views/WorkspaceRealityView+Boxes.swift`
3. `DesktopOrganizer/Views/BoxMemoAttachmentView.swift`
4. `DesktopOrganizer/Views/WorkspaceRealityView+Memos.swift`
5. `DesktopOrganizer/Views/WorkspaceRealityView+Attachments.swift`
6. `DesktopOrganizer/Views/WorkspaceRealityView+Geometry.swift`
7. `DesktopOrganizer/Views/SpatialMemoAttachmentViews.swift`
8. `DesktopOrganizer/Views/WorkspaceInteractionMetrics.swift`

## 23. 다음 교재와의 연결

이 교재를 읽은 뒤에는 `07-arkit-table-plane-detection-guide.html`로 넘어가면 좋다.

6번 교재에서 사용자가 공간 오브젝트와 상호작용하는 방식을 배웠다면, 7번 교재에서는 그 오브젝트를 놓을 실제 책상 평면을 어떻게 찾고 보여주는지 공부한다.

## 24. 체크리스트

아래 질문에 답할 수 있으면 6번 교재의 목표를 달성한 것이다.

- `targetedToAnyEntity()`가 어떤 역할을 하는지 설명할 수 있는가?
- `InputTargetComponent`, `HoverEffectComponent`, collision shape가 왜 필요한지 말할 수 있는가?
- 박스 드래그와 메모 카드 드래그의 차이를 설명할 수 있는가?
- 원본 메모는 남고 preview만 움직이는 구조를 설명할 수 있는가?
- 2D `CGSize` drag translation을 3D `SIMD3<Float>` 위치로 바꾸는 이유를 말할 수 있는가?
- hover, drag 중 위치, 저장 위치를 각각 다른 상태로 다루는 이유를 설명할 수 있는가?
