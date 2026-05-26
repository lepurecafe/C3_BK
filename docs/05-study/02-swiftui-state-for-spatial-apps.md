# 02. SwiftUI 상태 관리: 공간 앱에서 상태를 나누는 법

Last updated: 2026-05-25

이 교재는 Desktop Organizer를 통해 SwiftUI 상태 관리를 공부하기 위한 두 번째 교재다. 목표는 `@State`, `@Environment`, `@Query`, `@Observable`, SwiftData 모델, RealityKit 런타임 객체가 각각 어떤 역할을 맡는지 구분하는 것이다.

## 1. 이 주제를 배우는 이유

공간 앱은 일반 화면 앱보다 상태가 더 쉽게 섞인다.

- 사용자가 지금 보고 있는 패널 상태
- 앱을 껐다 켜도 남아야 하는 저장 데이터
- ARKit이 감지한 책상 상태
- RealityKit scene에 실제로 붙어 있는 entity
- 드래그 중인 임시 preview
- WorldAnchor와 연결된 고정 상태

이 모든 것을 한 곳에 넣으면 코드가 금방 불안정해진다. Desktop Organizer는 이 상태들을 여러 층으로 나누어 관리한다.

## 2. SwiftUI 상태의 큰 원칙

SwiftUI는 상태가 바뀌면 `body`를 다시 계산한다. 그래서 상태를 바꾼다는 말은 "화면을 다시 그릴 이유를 만든다"는 뜻에 가깝다.

하지만 모든 값을 SwiftUI가 관찰해야 하는 것은 아니다. RealityKit entity reference나 animation controller처럼 화면 선언을 다시 계산할 필요가 없는 값도 있다.

이 프로젝트의 기본 원칙은 아래와 같다.

| 상태 종류 | 보관 위치 | 예시 |
| --- | --- | --- |
| 현재 view의 UI 상태 | `@State` | `panelMode`, `draftBoxName`, `isSensingOpen` |
| 앱 여러 view가 공유하는 상태 | `@Environment`, `@Observable` | `PlaneDetectionService`, `WorkspaceEntityStore.shared` |
| 앱 재실행 후에도 남아야 하는 데이터 | SwiftData `@Model`, `@Query` | `OrganizerBox`, `MemoItem` |
| RealityKit 런타임 객체 | 비관찰 reference container | `WorkspaceRealitySceneState` |
| 드래그 중 임시 표현 | `@State` | `draggingMemoPreview`, `spatialMemoPresentations` |

## 3. ControlPanelView의 상태

`ControlPanelView`는 사용자가 처음 보는 조작 패널이다. 여기에는 전형적인 SwiftUI 화면 상태가 많다.

```swift
@State private var panelMode: PanelMode = .home
@State private var draftBoxName = ""
@State private var isSensingOpen = false
@State private var showResetAlert = false
@State private var storageErrorMessage: String?
@State private var controlStatusText = "준비됨"
@State private var isOpeningSensing = false
```

각 값은 화면을 바꾸기 위해 존재한다.

| 상태 | 의미 | 화면에 미치는 영향 |
| --- | --- | --- |
| `panelMode` | 홈 패널인지 이름 입력 패널인지 | `homePanel`과 `namingBoxPanel` 전환 |
| `draftBoxName` | 사용자가 입력 중인 박스 이름 | `TextField` 내용 |
| `isSensingOpen` | immersive space가 열려 있다고 보는지 | 공간 시작/종료 버튼 전환 |
| `showResetAlert` | 초기화 경고창 표시 여부 | alert 표시 |
| `storageErrorMessage` | 저장 실패 문구 | 오류 alert 표시 |
| `controlStatusText` | 패널 하단 상태 문구 | 사용자 피드백 |
| `isOpeningSensing` | 공간 열기 중복 요청 방지 | 버튼 동작 안정화 |

## 4. @State는 view가 소유하는 값이다

`@State`는 해당 view가 직접 소유하고 바꾸는 값에 적합하다.

예를 들어 `draftBoxName`은 `ControlPanelView`의 `TextField`에만 필요한 입력 중 상태다. 앱을 껐다 켜도 보존할 필요가 없고, 다른 view가 직접 읽을 이유도 작다.

```swift
TextField("예: 회의 메모", text: $draftBoxName)
```

반면 박스 이름이 확정되면 더 이상 `draftBoxName`에 머무르지 않는다. `OrganizerBox.name`으로 SwiftData에 저장된다.

이 구분이 중요하다.

- 입력 중인 값: `@State`
- 확정되어 저장할 값: SwiftData 모델

## 5. @Environment는 밖에서 주입받는 값이다

`ControlPanelView`는 여러 환경 값을 받는다.

```swift
@Environment(\.openImmersiveSpace) private var openImmersiveSpace
@Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
@Environment(PlaneDetectionService.self) private var planeService
@Environment(\.modelContext) private var modelContext
```

여기서 `openImmersiveSpace`, `dismissImmersiveSpace`, `modelContext`는 시스템 또는 SwiftData가 제공하는 환경 값이다. `planeService`는 `DesktopOrganizerApp`에서 직접 넣은 앱 공유 서비스다.

```swift
.environment(planeService)
```

환경 값은 "이 view가 직접 만들지는 않지만, 주변 앱 구조가 제공하는 값"이라고 생각하면 쉽다.

## 6. @Query는 저장소를 관찰한다

`@Query`는 SwiftData 저장소에서 모델을 읽고, 저장소가 바뀌면 view를 다시 갱신한다.

```swift
@Query(sort: \OrganizerBox.createdAt) private var boxes: [OrganizerBox]
@Query(sort: \MemoItem.createdAt) private var memos: [MemoItem]
```

`ControlPanelView`에서는 저장 항목 요약과 새 박스 이름 기본값에 사용한다.

```swift
Text("저장 항목 · 박스 \(boxes.count) · 메모 \(memos.count)")
```

`WorkspaceRealityView`에서도 같은 모델을 읽는다.

```swift
@Query(sort: \OrganizerBox.createdAt) var persistedBoxes: [OrganizerBox]
@Query(sort: \MemoItem.createdAt) var memos: [MemoItem]
```

이 덕분에 박스나 메모가 SwiftData에 저장되면, 공간 view도 그 변화를 보고 entity/attachment를 갱신할 수 있다.

## 7. 저장 상태와 화면 상태를 구분하기

박스를 만들 때 흐름은 두 단계다.

```swift
let box = OrganizerBox(
    name: name,
    posX: position.x,
    posY: position.y,
    posZ: position.z
)
modelContext.insert(box)
try modelContext.save()
```

이 코드는 앱을 다시 켜도 남아야 하는 박스 기록을 만든다.

그 다음에는 현재 열린 공간에 표시해 달라는 런타임 요청을 보낸다.

```swift
workspaceStore.addBox(
    id: box.id,
    position: position
)
```

같은 "박스 만들기" 안에서도 두 상태가 다르다.

| 단계 | 상태 종류 | 이유 |
| --- | --- | --- |
| `OrganizerBox` 저장 | 영속 상태 | 앱 재실행 후에도 박스가 있어야 함 |
| `workspaceStore.addBox` | 런타임 요청 상태 | 지금 열린 공간에 entity를 만들라고 알림 |

## 8. WorkspaceEntityStore는 런타임 공유 상태다

`WorkspaceEntityStore`는 SwiftData가 아니다. 현재 실행 중인 앱에서 `ControlPanelView`와 `WorkspaceRealityView`가 같이 보는 공유 상태다.

```swift
@Observable
final class WorkspaceEntityStore: @unchecked Sendable {
    static let shared = WorkspaceEntityStore()

    private(set) var boxRequests: [WorkspaceBoxEntityRequest] = []
    private(set) var selectedBoxID: UUID?
    private(set) var anchoredBoxIDs = Set<UUID>()
    private(set) var boxInteractionModes: [UUID: BoxInteractionMode] = [:]
    private(set) var revision = 0
    private(set) var resetRevision = 0
}
```

이 store에는 "저장 데이터"가 아니라 "현재 공간이 알아야 할 상태"가 들어간다.

| 값 | 의미 |
| --- | --- |
| `boxRequests` | 현재 실행 중 새로 공간에 띄워 달라고 요청한 박스 |
| `selectedBoxID` | 마지막으로 선택된 박스 |
| `anchoredBoxIDs` | 현재 드래그 이동을 막아야 하는 박스 |
| `boxInteractionModes` | 박스가 닫힘/열림/애니메이션 중인지 |
| `revision` | `WorkspaceRealityView`가 다시 렌더링해야 하는 변경 번호 |
| `resetRevision` | 공간 전체를 비워야 하는 변경 번호 |

## 9. PlaneDetectionService는 앱 공유 서비스다

`PlaneDetectionService`는 `@Observable` 객체다.

```swift
@Observable
@MainActor
final class PlaneDetectionService {
    var statusText: String = "공간 시작 대기"
    var detectedTablePlane: PlaneAnchor?
    var tablePlaneDebugRevision = 0
    var worldAnchorRevision = 0
}
```

이 서비스는 세 곳에서 쓰인다.

| View | 사용하는 이유 |
| --- | --- |
| `ControlPanelView` | 감지 상태 문구 표시, 책상 다시 인식 요청, 박스 생성 위치 계산 |
| `PlaneOverlayView` | immersive space가 열릴 때 `startDetection()` 실행 |
| `WorkspaceRealityView` | 평면 debug overlay와 WorldAnchor transform 갱신 |

이 값들은 앱 전체에서 같은 인스턴스를 봐야 하므로 `DesktopOrganizerApp`에서 만들어 environment로 공유한다.

## 10. WorkspaceRealityView의 상태

`WorkspaceRealityView`는 공간 오브젝트를 관리하므로 상태의 종류가 더 많다.

```swift
@State var workspaceStore = WorkspaceEntityStore.shared
@State var sceneState = WorkspaceRealitySceneState()
@State var draggingMemoPreview: DraggingMemoPreview?
@State var spatialMemoPresentations: [SpatialMemoPresentation] = []
@State var spatialMemoDragStartPositions: [UUID: SIMD3<Float>] = [:]
```

여기서 `draggingMemoPreview`와 `spatialMemoPresentations`는 SwiftUI attachment를 다시 그리는 데 직접 필요하다.

하지만 `sceneState`는 조금 다르다. 그 안에는 SwiftUI가 관찰하지 않아도 되는 RealityKit reference가 들어 있다.

## 11. WorkspaceRealitySceneState는 왜 따로 있나

`WorkspaceRealitySceneState`는 `@Observable`이 아니다.

```swift
@MainActor
final class WorkspaceRealitySceneState {
    var rootEntity: Entity?
    var renderedBoxIDs = Set<UUID>()
    var boxRoots: [UUID: Entity] = [:]
    var boxModels: [UUID: Entity] = [:]
    var boxAnimations: [UUID: AnimationResource] = [:]
    var animationControllers: [UUID: AnimationPlaybackController] = [:]
    var animationTasks: [UUID: Task<Void, Never>] = [:]
    var dragStartPositions: [UUID: SIMD3<Float>] = [:]
    var tablePlaneDebugEntity: ModelEntity?
}
```

이 객체는 RealityKit entity와 animation controller reference를 보관한다.

이 값들은 SwiftUI 화면 상태라기보다 "현재 RealityKit scene에 붙어 있는 실제 객체에 대한 참조"다. 이런 값을 SwiftUI가 계속 관찰하면 `RealityView update` 중 상태 변경 경고가 생기기 쉽다.

프로젝트 주석에도 이 의도가 적혀 있다.

```swift
// RealityView update 중 @State를 직접 바꾸면
// "Modifying state during view update" 경고가 나므로,
// SwiftUI가 관찰하지 않는 reference container에 모아 둡니다.
```

## 12. .task(id:)는 상태 변화를 작업으로 연결한다

`WorkspaceRealityView`에는 여러 `.task(id:)`가 있다.

```swift
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
```

`id` 값이 바뀌면 task가 다시 실행된다. 즉, SwiftUI 상태 변화와 RealityKit 갱신 작업을 연결하는 다리 역할을 한다.

예를 들어 `renderRevision`은 `workspaceStore.revision`과 저장된 박스 id 목록을 합쳐 만든다.

```swift
private var renderRevision: String {
    let persistedIDs = persistedBoxes
        .map(\.id.uuidString)
        .joined(separator: "|")

    return "\(workspaceStore.revision):\(persistedIDs)"
}
```

이렇게 하면 새 박스 요청이 들어오거나 SwiftData 박스 목록이 바뀔 때 `renderKnownBoxes()`가 다시 실행된다.

## 13. 드래그 중 상태와 저장 상태

메모를 드래그할 때는 먼저 화면 상태만 바꾼다.

```swift
draggingMemoPreview = DraggingMemoPreview(
    boxID: boxID,
    text: memo.text,
    colorIndex: memo.colorIndex,
    translation: translation
)
```

손을 놓고 실제로 공간 메모가 열릴 조건을 만족하면 그때 SwiftData 상태를 바꾼다.

```swift
memo.isSpatiallyPresented = true
memo.spatialBoxID = boxID
memo.spatialPosX = position.x
memo.spatialPosY = position.y
memo.spatialPosZ = position.z
```

드래그 중 매 순간 SwiftData에 저장하지 않는 이유는 간단하다.

- 드래그 중 위치는 임시 상태다.
- 저장소를 너무 자주 바꾸면 불필요한 갱신이 많아진다.
- 사용자가 실제로 놓았을 때만 영속 상태가 된다.

## 14. 상태가 섞일 때 생기는 문제

이 프로젝트에서 실제로 주의했던 문제는 다음과 같다.

| 문제 | 원인 | 해결 방향 |
| --- | --- | --- |
| 버튼이 먹통처럼 보임 | immersive space 열림 상태와 요청 상태가 엇갈림 | `isOpeningSensing`, `isSensingOpen`, `workspaceStore` 역할 분리 |
| 데이터 초기화 후 entity가 화면에 남음 | SwiftData 삭제와 RealityKit scene 삭제가 따로 필요 | `workspaceStore.resetWorkspace()`와 `resetRenderedWorkspace()` 연결 |
| `Modifying state during view update` 경고 | `RealityView update` 중 관찰 상태 변경 | `WorkspaceRealitySceneState`로 런타임 reference 분리 |
| 메모 위치 복원이 불안정 | 화면 presentation과 SwiftData 위치 저장이 섞임 | drag 중 `SpatialMemoPresentation`, drag 종료 후 `MemoItem` 저장 |

## 15. 코드 읽는 순서

상태 관리를 공부하려면 아래 순서로 읽는 것이 좋다.

1. `DesktopOrganizer/Views/ControlPanelView.swift`
2. `DesktopOrganizer/Services/WorkspaceEntityStore.swift`
3. `DesktopOrganizer/Services/PlaneDetectionService.swift`
4. `DesktopOrganizer/Views/WorkspaceRealityView.swift`
5. `DesktopOrganizer/Views/WorkspaceRealityState.swift`
6. `DesktopOrganizer/Views/WorkspaceRealityView+Memos.swift`
7. `DesktopOrganizer/Models/OrganizerBox.swift`
8. `DesktopOrganizer/Models/MemoItem.swift`

## 16. 다음 교재와의 연결

이 교재를 읽은 뒤에는 `03-swiftdata-for-spatial-objects.html`로 넘어가면 좋다.

2번 교재에서 "어떤 값이 저장 상태인가"를 구분했다면, 3번 교재에서는 그 저장 상태를 SwiftData 모델로 어떻게 설계하는지 공부한다.

## 17. 체크리스트

아래 질문에 답할 수 있으면 2번 교재의 목표를 달성한 것이다.

- `@State`와 `@Query`의 차이를 설명할 수 있는가?
- `@Environment(PlaneDetectionService.self)`가 필요한 이유를 설명할 수 있는가?
- `WorkspaceEntityStore`가 SwiftData 저장소가 아닌 이유를 말할 수 있는가?
- `WorkspaceRealitySceneState`를 관찰 객체로 만들지 않은 이유를 설명할 수 있는가?
- 드래그 중 상태와 드래그 종료 후 저장 상태를 구분할 수 있는가?
- `.task(id:)`가 상태 변화와 RealityKit 작업을 연결하는 방식을 설명할 수 있는가?
