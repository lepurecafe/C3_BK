# 04. RealityKit Entity 설계: 박스와 메모가 공간 오브젝트가 되는 법

Last updated: 2026-05-25

이 교재는 Desktop Organizer를 통해 RealityKit Entity 설계를 공부하기 위한 네 번째 교재다. 목표는 SwiftData에 저장된 `OrganizerBox`와 `MemoItem`이 실제 공간에서 보이는 `Entity`, `ModelEntity`, attachment entity, component, transform으로 어떻게 바뀌는지 이해하는 것이다.

## 1. 이 주제를 배우는 이유

visionOS 공간 앱에서 사용자가 보는 것은 SwiftData 모델이 아니다. 사용자가 보는 것은 RealityKit scene graph에 붙은 entity다.

Desktop Organizer에서 박스와 메모는 다음 과정을 거친다.

1. SwiftData에 `OrganizerBox` 또는 `MemoItem`으로 저장된다.
2. `WorkspaceRealityView`가 저장 모델을 읽는다.
3. `RealityView` 안에 root entity를 만든다.
4. 박스는 `boxRoot`와 `travelCase` entity로 구성된다.
5. SwiftUI로 만든 버튼과 메모 목록은 attachment entity가 되어 박스나 root의 자식으로 붙는다.
6. 입력, hover, billboard, collision 같은 성질은 component로 붙인다.

이 흐름을 이해하면 "공간 오브젝트를 설계한다"는 말이 훨씬 구체적으로 보인다.

## 2. RealityKit Entity의 큰 그림

RealityKit의 entity는 공간 안에 존재하는 객체다. entity는 혼자 있을 수도 있고, 다른 entity의 자식일 수도 있다.

Desktop Organizer의 기본 구조는 아래와 같다.

```text
WorkspaceRoot Entity
├─ WorkspaceBox:{boxID} Entity
│  ├─ TravelCaseScene Entity
│  ├─ SelectedBoxControls Attachment
│  └─ BoxMemoList:{boxID} Attachment
├─ SpatialMemo:{memoID} Attachment
└─ DebugTablePlane ModelEntity
```

이 구조에서 중요한 것은 부모-자식 관계다. 부모 entity가 움직이면 자식 entity도 함께 움직인다.

그래서 박스 아래 버튼이나 박스 위 메모 목록을 `boxRoot`의 자식으로 붙이면, 박스를 드래그할 때 같이 움직인다.

## 3. RealityView의 시작점

`WorkspaceRealityView`는 `RealityView` 안에서 root entity를 만든다.

```swift
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
}
```

`content.add(root)`가 이 공간 scene graph의 시작점이다.

이후 박스, 공간 메모, 디버그 평면은 모두 이 root 아래에 붙거나 root의 후손으로 붙는다.

## 4. 저장 모델에서 entity로 가는 흐름

`renderKnownBoxes()`는 저장된 박스와 새로 요청된 박스를 확인한다.

```swift
for box in persistedBoxes where !sceneState.renderedBoxIDs.contains(box.id) {
    await renderBox(
        id: box.id,
        position: workspacePosition(for: box),
        in: rootEntity
    )
}
```

여기서 `persistedBoxes`는 SwiftData의 `OrganizerBox` 배열이다. 하지만 `renderBox`가 실행되기 전까지는 공간에 보이는 entity가 아니다.

`renderBox`가 실제 RealityKit entity를 만든다.

## 5. boxRoot와 travelCase를 분리하는 이유

박스를 만들 때 바로 USDZ 모델을 root에 붙이지 않는다. 먼저 wrapper 역할의 `boxRoot`를 만든다.

```swift
let boxRoot = Entity()
boxRoot.name = boxEntityName(for: id)
boxRoot.position = position

fitTravelCaseForWorkspace(travelCase)
placeTravelCaseOnRootPlane(travelCase)

boxRoot.addChild(travelCase)
rootEntity.addChild(boxRoot)
```

이렇게 나누는 이유가 중요하다.

| entity | 역할 |
| --- | --- |
| `boxRoot` | 박스의 대표 위치, 드래그 이동, attachment 부모 |
| `travelCase` | 실제 보이는 USDZ 모델, scale/pivot/animation 보정 |

모델 파일은 pivot, scale, animation 상태가 앱이 원하는 공간 좌표와 다를 수 있다. wrapper entity를 두면 모델 보정과 앱의 공간 좌표를 분리할 수 있다.

## 6. entity 이름은 식별 도구다

박스 root 이름은 UUID를 포함한다.

```swift
func boxEntityName(for id: UUID) -> String {
    "WorkspaceBox:\(id.uuidString)"
}
```

나중에 사용자가 박스 모델의 child entity를 탭해도, 부모를 따라 올라가며 `WorkspaceBox:<UUID>` 이름을 찾는다.

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

이 방식 덕분에 gesture가 모델의 어느 child를 잡아도 최종적으로 어떤 박스인지 알아낼 수 있다.

## 7. 모델 크기와 높이 보정

USDZ 모델은 앱에서 원하는 실제 크기와 다를 수 있다. 그래서 먼저 visual bounds를 보고 scale을 맞춘다.

```swift
func fitTravelCaseForWorkspace(_ entity: Entity) {
    let bounds = entity.visualBounds(relativeTo: nil)
    let maxExtent = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))

    if maxExtent > 0 {
        let targetSize: Float = 0.45
        let uniformScale = targetSize / maxExtent
        entity.scale = SIMD3<Float>(repeating: uniformScale)
    }

    entity.position = .zero
}
```

그 다음 모델 바닥이 root 기준 평면에 오도록 y 위치를 보정한다.

```swift
func placeTravelCaseOnRootPlane(_ entity: Entity) {
    let bounds = entity.visualBounds(relativeTo: entity)
    entity.position.y = -bounds.min.y + travelCaseSurfaceOffset
}
```

`travelCaseSurfaceOffset`은 실기기에서 모델이 살짝 뜨거나 파고드는 문제를 보정하는 값이다.

## 8. component는 entity에 성질을 붙인다

RealityKit에서 entity는 component를 통해 기능과 성질을 얻는다.

```swift
entity.components.set(InputTargetComponent())
entity.components.set(HoverEffectComponent())
```

Desktop Organizer에서 자주 쓰는 component는 다음과 같다.

| component | 역할 |
| --- | --- |
| `InputTargetComponent` | targeted gesture의 입력 대상이 되게 함 |
| `HoverEffectComponent` | 사용자가 바라보거나 포인터가 닿을 때 hover feedback 제공 |
| `CollisionComponent` | gesture hit test를 위한 충돌 형태 제공 |
| `ModelComponent` | mesh와 material을 통해 보이는 물체가 되게 함 |
| `BillboardComponent` | attachment가 사용자를 향하게 함 |

ECS 교재에서 말한 component 감각이 RealityKit에서는 이런 식으로 나타난다.

## 9. 입력 가능한 모델 만들기

박스 모델은 child entity를 많이 가질 수 있다. 그래서 입력 component를 재귀적으로 붙인다.

```swift
func configureInputTargets(in entity: Entity) {
    entity.components.set(InputTargetComponent())
    entity.components.set(HoverEffectComponent())

    for child in entity.children {
        configureInputTargets(in: child)
    }
}
```

그리고 collision shape도 생성한다.

```swift
travelCase.generateCollisionShapes(recursive: true)
```

targeted gesture가 entity를 찾으려면 입력 대상과 collision shape가 필요하다.

## 10. attachment도 entity다

`RealityView`의 attachment는 SwiftUI view로 작성하지만, RealityKit scene 안에서는 entity처럼 꺼내 붙일 수 있다.

```swift
Attachment(id: selectedBoxControlAttachmentID) {
    BoxControlAttachmentView(...)
}
```

이 attachment는 update 함수에서 entity로 꺼낸다.

```swift
let controls = attachments.entity(for: selectedBoxControlAttachmentID)
```

그리고 박스 root의 자식으로 붙인다.

```swift
if controls.parent !== selectedBoxRoot {
    controls.removeFromParent()
    selectedBoxRoot.addChild(controls)
}

controls.position = SIMD3<Float>(0, -0.12, 0.17)
```

이렇게 하면 SwiftUI로 만든 UI도 박스를 따라 움직이는 공간 오브젝트처럼 동작한다.

## 11. 박스 위 메모 목록 attachment

박스를 클릭해 열면 메모 목록 attachment가 박스 위에 붙는다.

```swift
if memoList.parent !== boxRoot {
    memoList.removeFromParent()
    boxRoot.addChild(memoList)
}

memoList.position = SIMD3<Float>(0, 0.34, 0)
```

이 구조 덕분에 박스를 움직이면 메모 목록도 같이 움직인다.

만약 이 목록을 일반 window로 띄웠다면 박스가 움직여도 window가 따라오지 않는다. 그래서 박스에 붙어야 하는 UI는 attachment가 적합하다.

## 12. 공간 메모 attachment

박스 안 메모를 공간으로 꺼내면 `SpatialMemo:{memoID}` attachment가 root entity 아래에 붙는다.

```swift
if memoEntity.parent !== rootEntity {
    memoEntity.removeFromParent()
    memoEntity.name = spatialMemoAttachmentID(for: presentation.id)
    rootEntity.addChild(memoEntity)
}

configureOpenedMemoEntity(memoEntity)
memoEntity.position = presentation.position
```

박스 위 메모 목록과 다른 점은 부모다.

| attachment | 부모 | 이유 |
| --- | --- | --- |
| 박스 컨트롤 | 선택된 `boxRoot` | 박스를 따라 움직여야 함 |
| 박스 메모 목록 | 해당 `boxRoot` | 박스를 따라 움직여야 함 |
| 공간 메모 | `WorkspaceRoot` | 박스와 독립적으로 움직일 수 있어야 함 |

## 13. BillboardComponent로 읽기 쉽게 만들기

공간에 열린 메모는 얇은 카드처럼 보인다. 사용자가 읽기 쉬우려면 어느 정도 사용자를 향해야 한다.

```swift
func configureMemoBillboard(_ entity: Entity) {
    var billboard = BillboardComponent()
    billboard.blendFactor = 0.75
    entity.components.set(billboard)
}
```

`blendFactor`는 완전히 강제적으로 정면을 보게 할지, 어느 정도만 따라오게 할지 조절하는 값이다.

열린 메모에는 billboard뿐 아니라 입력과 hover component도 붙인다.

```swift
func configureOpenedMemoEntity(_ entity: Entity) {
    configureMemoBillboard(entity)
    entity.components.set(InputTargetComponent())
    entity.components.set(HoverEffectComponent())
}
```

## 14. 2D drag를 3D 위치로 바꾸기

SwiftUI의 drag gesture는 화면 point 단위의 `CGSize` translation을 준다. RealityKit은 3D 좌표를 쓴다.

```swift
func spatialMemoPosition(for translation: CGSize) -> SIMD3<Float> {
    SIMD3<Float>(
        Float(translation.width) * memoDragMetersPerPoint,
        0.34 - Float(translation.height) * memoDragMetersPerPoint,
        0.03
    )
}
```

여기서 y축 부호가 중요하다.

- SwiftUI 화면에서는 아래로 끌면 `translation.height`가 양수다.
- RealityKit 공간에서는 위가 y 양수다.
- 그래서 `- Float(translation.height)`처럼 부호를 반대로 쓴다.

## 15. 박스 드래그 이동

박스를 드래그하면 `boxRoot.position`을 바꾼다.

```swift
let startPosition = sceneState.dragStartPositions[boxID] ?? boxRoot.position
sceneState.dragStartPositions[boxID] = startPosition

let movement = value.convert(value.translation3D, from: .global, to: .scene)
boxRoot.position = startPosition + movement
```

`travelCase`가 아니라 `boxRoot`를 움직이는 이유는 명확하다.

- 모델과 attachment가 모두 함께 움직여야 한다.
- `boxRoot`가 박스 전체의 대표 transform이다.
- `travelCase`는 root 안에서 모델 보정만 담당한다.

## 16. DebugTablePlane도 entity다

책상으로 인식된 평면을 보여주기 위해 cyan plane을 만든다.

```swift
let mesh = MeshResource.generatePlane(width: width, depth: depth)
let material = SimpleMaterial(
    color: UIColor.cyan.withAlphaComponent(0.45),
    roughness: 0.7,
    isMetallic: false
)

let debugEntity = sceneState.tablePlaneDebugEntity ?? ModelEntity()
debugEntity.name = "DebugTablePlane"
debugEntity.model = ModelComponent(mesh: mesh, materials: [material])
debugEntity.transform.matrix = tablePlane.originFromAnchorTransform
```

이 entity는 사용자가 "앱이 어느 면을 책상으로 잡았는지" 확인하기 위한 디버그 시각화다.

## 17. animation도 entity 설계의 일부다

박스 열림/닫힘은 USDZ 안의 animation을 사용한다.

```swift
sceneState.boxAnimations[id] = firstAvailableAnimation(in: travelCase)
```

열 때는 animation을 앞에서 뒤로 재생한다.

```swift
let controller = entity.playAnimation(animation, transitionDuration: 0, startsPaused: true)
controller.speed = 1
controller.time = 0
controller.resume()
```

닫을 때는 별도 close animation이 없으므로 같은 animation의 `time`을 뒤에서 앞으로 직접 움직인다.

```swift
for frame in stride(from: frameCount, through: 0, by: -1) {
    let progress = Double(frame) / Double(frameCount)
    controller.time = duration * progress
}
```

여기서 animation controller는 SwiftUI 저장 상태가 아니라 RealityKit 런타임 객체이므로 `WorkspaceRealitySceneState`에 보관한다.

## 18. sceneState가 보관하는 entity reference

`WorkspaceRealitySceneState`는 현재 scene에 붙어 있는 entity와 animation reference를 들고 있다.

```swift
final class WorkspaceRealitySceneState {
    var rootEntity: Entity?
    var renderedBoxIDs = Set<UUID>()
    var boxRoots: [UUID: Entity] = [:]
    var boxModels: [UUID: Entity] = [:]
    var boxAnimations: [UUID: AnimationResource] = [:]
    var animationControllers: [UUID: AnimationPlaybackController] = [:]
    var dragStartPositions: [UUID: SIMD3<Float>] = [:]
    var tablePlaneDebugEntity: ModelEntity?
}
```

이 값들은 SwiftData에 저장하지 않는다.

앱 실행 중에만 유효한 RealityKit 객체이기 때문이다. 앱을 다시 열면 SwiftData 모델을 읽어 새 entity를 만든다.

## 19. entity 설계의 핵심 원칙

Desktop Organizer에서 배울 수 있는 RealityKit entity 설계 원칙은 다음과 같다.

| 원칙 | 설명 |
| --- | --- |
| 대표 root를 둔다 | 실제 모델과 UI attachment를 묶는 wrapper entity를 둔다 |
| 모델 보정과 위치 책임을 나눈다 | `boxRoot`는 공간 위치, `travelCase`는 모델 scale/pivot 보정 |
| 붙어야 하는 UI는 자식으로 둔다 | 박스 컨트롤과 메모 목록은 `boxRoot`의 자식 |
| 독립 오브젝트는 root 아래 둔다 | 공간 메모는 `WorkspaceRoot`의 자식 |
| 입력은 component로 부여한다 | `InputTargetComponent`, `HoverEffectComponent`, collision |
| 저장 모델과 entity를 구분한다 | `OrganizerBox`는 기록, `boxRoot`는 런타임 객체 |

## 20. 코드 읽는 순서

RealityKit Entity 설계를 공부하려면 아래 순서가 좋다.

1. `DesktopOrganizer/Views/WorkspaceRealityView.swift`
2. `DesktopOrganizer/Views/WorkspaceRealityView+Boxes.swift`
3. `DesktopOrganizer/Views/WorkspaceRealityView+Attachments.swift`
4. `DesktopOrganizer/Views/WorkspaceRealityView+Geometry.swift`
5. `DesktopOrganizer/Views/WorkspaceRealityState.swift`
6. `DesktopOrganizer/Services/WorkspaceEntityStore.swift`
7. `DesktopOrganizer/Models/OrganizerBox.swift`
8. `DesktopOrganizer/Models/MemoItem.swift`

## 21. 다음 교재와의 연결

이 교재를 읽은 뒤에는 `05-attachment-ornament-window-guide.html`로 넘어가면 좋다.

4번 교재에서 attachment가 entity처럼 scene graph에 붙는다는 것을 배웠다면, 5번 교재에서는 attachment, ornament, window가 정확히 무엇이 다른지 비교한다.

## 22. 체크리스트

아래 질문에 답할 수 있으면 4번 교재의 목표를 달성한 것이다.

- `boxRoot`와 `travelCase`를 분리한 이유를 설명할 수 있는가?
- attachment가 왜 박스를 따라 움직일 수 있는지 설명할 수 있는가?
- `InputTargetComponent`와 collision shape가 왜 필요한지 말할 수 있는가?
- 공간 메모가 `boxRoot`가 아니라 `WorkspaceRoot` 아래에 붙는 이유를 설명할 수 있는가?
- `OrganizerBox`와 `boxRoot`의 차이를 말할 수 있는가?
- `BillboardComponent`가 메모 카드에 필요한 이유를 설명할 수 있는가?
