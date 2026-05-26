# 10. 리팩토링과 아키텍처 성장: 공간 앱 코드를 오래 관리하기

Last updated: 2026-05-26

이 교재는 Desktop Organizer를 통해 리팩토링과 아키텍처 성장을 공부하기 위한 열 번째 교재다. 목표는 "코드를 예쁘게 나누는 법"이 아니라, visionOS 공간 앱이 커질 때 어떤 기준으로 파일, 상태, 서비스, Entity 로직을 나눠야 오래 버틸 수 있는지 배우는 것이다.

## 1. 이 주제를 배우는 이유

앱이 작을 때는 하나의 파일에 모든 코드를 넣어도 된다.

하지만 Desktop Organizer처럼 기능이 늘어나면 상황이 달라진다.

- 책상 평면을 찾는다.
- 박스를 만든다.
- 박스를 움직인다.
- 박스를 열고 닫는다.
- 박스 아래에 컨트롤을 붙인다.
- 메모를 만든다.
- 메모를 공간에 꺼낸다.
- 메모를 움직인다.
- WorldAnchor로 박스와 메모 위치를 저장한다.
- SwiftData에 데이터를 저장한다.
- RealityKit Entity와 SwiftUI Attachment를 동기화한다.

이 모든 기능이 한 파일에 있으면 처음에는 빠르지만, 조금만 지나도 "어디를 고쳐야 하는지" 찾기 어려워진다.

리팩토링은 코드를 줄이는 일이 아니다. 코드를 읽는 사람이 다음 질문에 답하기 쉽게 만드는 일이다.

```text
이 기능의 책임은 어디에 있는가?
이 상태는 누가 소유하는가?
이 함수는 화면을 바꾸는가, 데이터를 바꾸는가, RealityKit scene을 바꾸는가?
이 변경이 다른 기능을 깨뜨릴 가능성은 어디에 있는가?
```

## 2. 현재 프로젝트 구조 한눈에 보기

현재 Desktop Organizer의 핵심 구조는 크게 네 층으로 나눌 수 있다.

```text
App
└─ DesktopOrganizerApp.swift

Views
├─ ControlPanelView.swift
├─ PlaneOverlayView.swift
├─ WorkspaceRealityView.swift
├─ WorkspaceRealityView+Boxes.swift
├─ WorkspaceRealityView+Memos.swift
├─ WorkspaceRealityView+Anchors.swift
├─ WorkspaceRealityView+Attachments.swift
├─ WorkspaceRealityView+Geometry.swift
├─ WorkspaceRealityState.swift
├─ BoxControlAttachmentView.swift
├─ BoxMemoAttachmentView.swift
└─ SpatialMemoAttachmentViews.swift

Services
├─ PlaneDetectionService.swift
└─ WorkspaceEntityStore.swift

Models
├─ OrganizerBox.swift
├─ MemoItem.swift
└─ MemoPalette.swift
```

초보자가 볼 때 중요한 점은 이것이다.

`Views` 폴더에 있다고 해서 모두 "그림을 그리는 코드"만 있는 것은 아니다. visionOS 앱에서는 RealityKit scene graph를 갱신하는 코드도 View 근처에 놓이는 경우가 많다. 그래서 파일 이름만 보지 말고, 그 파일이 어떤 책임을 갖는지 봐야 한다.

## 3. 현재 파일 길이로 보는 복잡도

코드 전수 검사에서 확인한 주요 파일 길이는 다음과 같다.

| 파일 | 줄 수 | 현재 책임 |
| --- | ---: | --- |
| `WorkspaceRealityView+Boxes.swift` | 315 | 박스 생성, 배치, 이동, 열기/닫기, 삭제 |
| `WorkspaceRealityView+Memos.swift` | 289 | 메모 생성, 공간 메모 표시, 이동, 삭제, 저장 |
| `WorkspaceRealityView+Anchors.swift` | 287 | 박스/메모 WorldAnchor 저장과 복원 |
| `PlaneDetectionService.swift` | 341 | ARKit 평면 감지, 책상 후보 선택, WorldAnchor 세션 관리 |
| `WorkspaceRealityView.swift` | 223 | RealityView 구성, update 루프, gesture 연결 |
| `WorkspaceRealityView+Attachments.swift` | 115 | attachment entity를 scene graph에 붙이기 |
| `WorkspaceRealityView+Geometry.swift` | 115 | 좌표와 배치 계산 |

줄 수만으로 나쁜 코드를 판단할 수는 없다. 하지만 "어디가 더 자주 바뀔 가능성이 큰가"를 보는 신호로는 쓸 수 있다.

현재 가장 많이 자라는 축은 세 곳이다.

- 박스 lifecycle
- 메모 lifecycle
- ARKit 평면/앵커 service

## 4. WorkspaceRealityView는 오케스트레이션 레이어다

`WorkspaceRealityView.swift`의 핵심 역할은 직접 모든 일을 하는 것이 아니라, 여러 기능을 연결하는 것이다.

대표적으로 `RealityView`의 `update` 블록은 이런 일을 한다.

```swift
update: { _, attachments in
    updateTablePlaneDebugOverlay()
    updateSelectedBoxControls(attachments: attachments)
    updateOpenBoxMemoLists(attachments: attachments)
    updateDraggingMemoPreview(attachments: attachments)
    updateSpatialMemoPresentations(attachments: attachments)
}
```

이 코드는 직접 박스를 만들거나 메모를 저장하지 않는다.

대신 "현재 프레임에서 RealityKit scene에 반영해야 할 것들"을 순서대로 호출한다.

이런 파일은 오케스트레이션 레이어라고 볼 수 있다.

```text
오케스트레이션 레이어
= 여러 기능을 직접 구현하기보다
  언제 어떤 기능을 호출할지 조율하는 층
```

## 5. 왜 extension 파일로 나누었을까?

현재 프로젝트는 `WorkspaceRealityView`를 여러 extension 파일로 나누고 있다.

```text
WorkspaceRealityView.swift
WorkspaceRealityView+Boxes.swift
WorkspaceRealityView+Memos.swift
WorkspaceRealityView+Anchors.swift
WorkspaceRealityView+Attachments.swift
WorkspaceRealityView+Geometry.swift
```

이 방식의 장점은 진입점은 하나로 유지하면서도, 기능별 코드를 파일 단위로 나눌 수 있다는 것이다.

초보자에게는 다음처럼 읽으면 좋다.

| 파일 | 읽는 관점 |
| --- | --- |
| `WorkspaceRealityView.swift` | 앱의 공간 scene이 어떻게 시작되고 갱신되는가 |
| `+Boxes.swift` | 박스 Entity는 어떻게 만들어지고 움직이는가 |
| `+Memos.swift` | 메모 데이터와 공간 메모는 어떻게 연결되는가 |
| `+Anchors.swift` | 위치 저장과 WorldAnchor는 어떻게 처리되는가 |
| `+Attachments.swift` | SwiftUI UI가 RealityKit Entity로 어떻게 붙는가 |
| `+Geometry.swift` | 좌표 변환과 배치 계산은 어디서 하는가 |

## 6. 좋은 분리 기준 1: 책임으로 나누기

가장 기본적인 리팩토링 기준은 책임이다.

예를 들어 박스 코드는 하나의 책임처럼 보이지만, 실제로는 여러 책임이 섞여 있다.

```text
박스 생성
박스 위치 계산
박스 모델 fitting
박스 tap 처리
박스 open/close animation
박스 drag 이동
박스 삭제
```

현재는 이것들이 `WorkspaceRealityView+Boxes.swift` 안에 있다. 아직은 한 파일에서 볼 수 있기 때문에 괜찮다.

하지만 박스 애니메이션이 복잡해지거나, 박스 종류가 여러 개가 되거나, 회전/크기 조절까지 들어오면 더 나누는 것이 좋다.

가능한 다음 분리 예시는 이렇다.

```text
WorkspaceRealityView+BoxRendering.swift
WorkspaceRealityView+BoxMovement.swift
WorkspaceRealityView+BoxAnimation.swift
WorkspaceRealityView+BoxDeletion.swift
```

다만 지금 당장 이렇게 나눌 필요는 없다. 파일이 길다는 이유만으로 나누면 오히려 읽기 어려워질 수 있다.

## 7. 좋은 분리 기준 2: lifecycle로 나누기

공간 앱에서는 오브젝트의 lifecycle이 중요하다.

박스 lifecycle은 다음 순서를 가진다.

```text
생성 요청
-> SwiftData 저장
-> RealityKit Entity 생성
-> 위치 배치
-> 조작 가능하게 설정
-> 이동/열기/닫기
-> 위치 저장
-> 삭제
```

메모 lifecycle은 조금 다르다.

```text
박스 안에 메모 생성
-> attachment 목록에 표시
-> 드래그 preview 생성
-> 공간 메모로 열기
-> 공간에서 이동
-> 닫기 또는 삭제
-> 위치/고정 상태 저장
```

이 두 lifecycle은 다르기 때문에 `+Boxes.swift`와 `+Memos.swift`로 나뉜 것은 자연스럽다.

리팩토링할 때는 "같이 태어나고, 같이 움직이고, 같이 사라지는가"를 기준으로 보면 좋다.

## 8. 좋은 분리 기준 3: side effect로 나누기

side effect는 함수가 자기 밖의 세계를 바꾸는 일이다.

이 앱에서 side effect는 여러 종류가 있다.

| side effect | 예시 |
| --- | --- |
| SwiftUI 상태 변경 | `selectedBoxID` 변경 |
| RealityKit scene 변경 | Entity 추가, 제거, 위치 변경 |
| SwiftData 저장 | `modelContext.save()` |
| ARKit 세션 변경 | plane detection 시작, WorldAnchor 추가 |
| async 작업 | asset loading, anchor 저장 |

좋은 리팩토링은 이런 side effect를 숨기지 않는다.

예를 들어 `PlaneDetectionService`는 ARKit 세션과 anchor cache를 다루는 side effect를 한 서비스에 모아둔다.

```swift
@Observable
@MainActor
final class PlaneDetectionService {
    var statusText = "공간 인식 대기 중"
    var selectedTablePlane: DetectedTablePlane?

    func startDetection() async { ... }
    func requestTableRescan() { ... }
    func addWorldAnchor(...) async throws -> UUID { ... }
}
```

이렇게 하면 View는 ARKit의 세부 구현을 몰라도 된다.

## 9. 좋은 분리 기준 4: framework boundary로 나누기

visionOS 앱은 여러 framework가 섞인다.

```text
SwiftUI
RealityKit
ARKit
SwiftData
```

이 framework들은 생각하는 방식이 다르다.

| Framework | 주로 맡는 일 |
| --- | --- |
| SwiftUI | 화면, 버튼, 상태 기반 UI |
| RealityKit | Entity, Transform, scene graph |
| ARKit | 실제 공간 인식, WorldAnchor |
| SwiftData | 앱 데이터 저장 |

초보자가 가장 헷갈리는 지점은 SwiftUI와 RealityKit의 경계다.

예를 들어 `BoxControlAttachmentView`는 SwiftUI view다.

```swift
BoxControlAttachmentView(
    boxName: selectedBox.name,
    isAnchored: workspaceStore.isBoxAnchored(selectedBox.id),
    onDelete: { deleteBox(selectedBox.id) },
    onToggleAnchor: {
        Task { await toggleAnchor(for: selectedBox.id) }
    }
)
```

하지만 이 view는 일반 window 안에 있는 것이 아니라, RealityKit scene 안의 attachment entity로 붙는다.

```swift
let controls = attachments.entity(for: selectedBoxControlAttachmentID)
selectedBoxRoot.addChild(controls)
controls.position = SIMD3<Float>(0, -0.12, 0.17)
```

즉 UI는 SwiftUI로 만들고, 위치와 부모-자식 관계는 RealityKit으로 다룬다.

## 10. WorkspaceRealityState는 왜 따로 있을까?

`WorkspaceRealityState.swift`는 관찰되는 앱 상태가 아니라, RealityKit runtime 참조를 보관한다.

```swift
final class WorkspaceRealitySceneState {
    var rootEntity: Entity?
    var renderedBoxIDs = Set<UUID>()
    var boxRoots: [UUID: Entity] = [:]
    var boxModels: [UUID: Entity] = [:]
    var animationControllers: [UUID: AnimationPlaybackController] = [:]
    var dragStartPositions: [UUID: SIMD3<Float>] = [:]
    var tablePlaneDebugEntity: ModelEntity?
}
```

이 상태는 SwiftData 모델과 다르다.

SwiftData 모델은 앱을 껐다 켜도 남아야 하는 데이터다.

```text
박스 이름
박스 저장 위치
메모 내용
메모 색상
WorldAnchor identifier
```

반대로 `WorkspaceRealitySceneState`는 앱 실행 중에만 필요한 참조다.

```text
실제 Entity 객체
현재 animation controller
현재 drag 시작 위치
debug plane entity
```

이 둘을 분리한 것은 좋은 구조다. 저장해야 하는 데이터와 실행 중 참조를 섞으면, 나중에 디버깅하기 매우 어려워진다.

## 11. WorkspaceEntityStore는 무엇을 연결하나?

`WorkspaceEntityStore`는 SwiftUI window와 immersive RealityKit scene 사이의 공유 상태다.

```swift
@Observable
final class WorkspaceEntityStore {
    static let shared = WorkspaceEntityStore()

    private(set) var boxRequests: [WorkspaceBoxEntityRequest] = []
    var selectedBoxID: UUID?
    private(set) var anchoredBoxIDs = Set<UUID>()
    private var boxInteractionModes: [UUID: BoxInteractionMode] = [:]
    private(set) var revision = 0
    private(set) var resetRevision = 0
}
```

예를 들어 사용자가 `ControlPanelView`에서 박스 만들기 버튼을 누르면, 이 store에 요청이 들어간다. 그 후 `WorkspaceRealityView`가 revision 변화를 보고 실제 Entity를 만든다.

```text
ControlPanelView
-> WorkspaceEntityStore.addBox(...)
-> revision 변경
-> WorkspaceRealityView.task(id: renderRevision)
-> renderKnownBoxes()
-> RealityKit Entity 생성
```

이 구조는 "패널 UI"와 "공간 Entity 생성"을 직접 연결하지 않게 해준다.

## 12. PlaneDetectionService는 서비스 경계다

`PlaneDetectionService`는 ARKit 관련 복잡도를 View 밖으로 빼낸 서비스다.

현재 맡는 일은 꽤 많다.

```text
ARKitSession 시작/중지
PlaneDetectionProvider 관리
WorldTrackingProvider 관리
책상 후보 plane 선택
cyan debug plane 표시용 데이터 제공
WorldAnchor 추가/삭제
WorldAnchor cache 갱신
상태 메시지 제공
```

이 파일은 현재 341줄로, 프로젝트에서 가장 긴 축 중 하나다.

다음 단계에서 기능이 더 늘어난다면 두 서비스로 나눌 수 있다.

```text
PlaneDetectionService
- 책상 평면 찾기
- 후보 선택
- 재인식
- debug plane 정보

WorldAnchorService
- WorldAnchor 추가
- WorldAnchor 삭제
- anchor transform cache
- anchor update stream
```

하지만 지금 바로 나누기 전에 확인할 것이 있다.

두 기능이 실제로 독립적으로 바뀌는가?

만약 평면 인식과 WorldAnchor가 계속 같은 ARKit session을 공유하고, 같은 status text를 써야 한다면, 무리해서 나누는 것이 더 복잡할 수 있다.

## 13. 현재 구조의 장점

현재 구조는 완벽하지 않지만, 좋은 선택들이 있다.

- `WorkspaceRealityView` 본문이 너무 많은 세부 구현을 직접 들고 있지 않다.
- 박스, 메모, 앵커, attachment, geometry가 파일 단위로 나뉘어 있다.
- SwiftData 모델과 RealityKit runtime 상태가 분리되어 있다.
- ARKit 평면 인식은 `PlaneDetectionService`로 빠져 있다.
- SwiftUI attachment view는 별도 view 파일로 나뉘어 있다.
- 메모 색상은 `MemoPalette`로 분리되어 있다.
- 앱 시작 scene 구성은 `DesktopOrganizerApp.swift`에 모여 있다.

이 정도 구조면 초보자 학습용 프로젝트로도 좋고, 기능을 더 키우기 위한 기반으로도 충분하다.

## 14. 현재 구조의 한계

반대로 조심해야 할 부분도 있다.

첫째, `WorkspaceRealityView+Boxes.swift`는 박스의 많은 책임을 한 파일에 들고 있다.

```text
rendering
asset fitting
placement
input target
animation
movement
deletion
```

둘째, `WorkspaceRealityView+Memos.swift`는 데이터 작업과 공간 presentation 작업이 함께 있다.

```text
MemoItem 생성/삭제
SpatialMemoPresentation 생성/이동/저장
drag preview 처리
SwiftData 저장
```

셋째, `PlaneDetectionService`는 평면 감지와 WorldAnchor를 모두 맡고 있다.

넷째, `WorkspaceEntityStore.shared`는 간단하고 편하지만, 테스트가 많아지거나 scene이 여러 개가 되면 의존성을 주입하는 방식이 더 나을 수 있다.

이 한계들은 지금 당장 버그가 아니다. 다만 앱이 더 커질 때 리팩토링 후보가 되는 지점이다.

## 15. 나쁜 리팩토링 기준

리팩토링을 처음 배울 때 흔한 실수는 파일 길이만 보고 나누는 것이다.

```text
300줄이 넘었으니까 무조건 나누자
함수가 20줄이 넘었으니까 무조건 쪼개자
클래스를 많이 만들면 구조가 좋아진다
```

이 기준은 위험하다.

좋은 질문은 이것이다.

```text
이 코드는 왜 같이 있어야 하는가?
이 코드는 왜 따로 있어야 하는가?
이름을 붙이면 더 읽기 쉬워지는가?
테스트하거나 바꾸기 쉬워지는가?
숨겨진 의존성이 줄어드는가?
```

리팩토링은 파일 수를 늘리는 일이 아니라, 변경할 때 생각해야 하는 범위를 줄이는 일이다.

## 16. 다음 리팩토링 후보 1: 박스 애니메이션 분리

박스 열기/닫기는 사용자 경험에서 중요한 기능이다.

현재는 박스를 클릭하면 열리고, 다시 클릭하면 닫힌다. 이 animation은 박스의 data 저장과는 성격이 다르다.

나중에 animation이 복잡해지면 다음처럼 분리할 수 있다.

```swift
struct BoxAnimationState {
    var isOpen: Bool
    var isAnimating: Bool
}

enum BoxAnimationCommand {
    case open
    case close
    case reverse
}
```

그리고 실제 재생 로직을 별도 helper로 옮길 수 있다.

```text
BoxAnimationController
- open(boxRoot:)
- close(boxRoot:)
- stopCurrentAnimation(for:)
- updateInteractionMode(after:)
```

다만 지금은 RealityKit animation controller와 Entity 참조가 `WorkspaceRealityView` 안에 강하게 연결되어 있으므로, 성급하게 타입을 빼면 오히려 전달 인자가 많아질 수 있다.

## 17. 다음 리팩토링 후보 2: 메모 데이터와 공간 표시 분리

메모 기능은 두 세계를 동시에 다룬다.

```text
MemoItem
= 저장되는 데이터

SpatialMemoPresentation
= 현재 공간에 열려 있는 runtime 표현
```

이 둘은 비슷해 보이지만 다르다.

`MemoItem`은 앱을 껐다 켜도 남아야 한다.

`SpatialMemoPresentation`은 실행 중 SwiftUI attachment를 어디에 붙일지 알려준다.

나중에 메모 기능이 커지면 다음처럼 나눌 수 있다.

```text
MemoDataActions
- createMemo
- deleteMemos
- updateMemoContent
- updateMemoColor

SpatialMemoPresentationActions
- openSpatialMemo
- closeSpatialMemo
- moveSpatialMemoPresentation
- saveSpatialMemoState
```

이 분리는 "메모 내용 편집"과 "공간에서 메모를 움직이기"가 서로를 덜 건드리게 만든다.

## 18. 다음 리팩토링 후보 3: PlaneDetection과 WorldAnchor 분리

현재 `PlaneDetectionService`는 평면 감지와 WorldAnchor를 모두 다룬다.

이 둘은 ARKit을 쓴다는 공통점이 있지만, 사용자의 관점에서는 다른 기능이다.

```text
평면 감지
= 책상을 찾는다

WorldAnchor
= 오브젝트 위치를 실제 공간에 저장한다
```

앱이 커지면 다음 구조가 가능하다.

```text
SpatialSessionService
- ARKitSession 소유
- provider 시작/중지 조율

TablePlaneDetectionService
- table plane 후보 선택
- rescan
- status text

WorldAnchorPersistenceService
- add anchor
- remove anchor
- anchor transform cache
```

하지만 이 분리는 ARKit session 공유 방식이 안정된 뒤에 하는 것이 좋다.

실기기 테스트에서 평면 인식이 아직 불안정하다면, 먼저 동작을 안정화하고 그 다음 나누는 편이 낫다.

## 19. 다음 리팩토링 후보 4: Attachment placement system

`WorkspaceRealityView+Attachments.swift`는 SwiftUI attachment를 RealityKit scene에 붙인다.

현재 하는 일은 다음과 같다.

```text
선택된 박스 아래 컨트롤 붙이기
열린 박스 위에 메모 목록 붙이기
드래그 중인 메모 preview 붙이기
공간에 열린 메모 카드 붙이기
사라진 attachment 정리하기
```

이 로직은 ECS 관점으로 보면 system에 가깝다.

```text
AttachmentPlacementSystem
= 현재 상태를 읽고
  attachment entity의 부모와 위치를 갱신하는 시스템
```

나중에 attachment 종류가 더 많아지면 다음처럼 분리할 수 있다.

```text
BoxControlAttachmentPlacer
BoxMemoListAttachmentPlacer
SpatialMemoAttachmentPlacer
DraggingPreviewAttachmentPlacer
```

지금은 파일이 115줄 정도라서 한 파일로 유지해도 충분히 읽을 만하다.

## 20. ECS와 연결해서 보기

이 프로젝트는 순수 ECS 구조는 아니다.

하지만 ECS를 이해하기 좋은 재료는 많다.

| 현재 코드 | ECS식으로 보면 |
| --- | --- |
| `OrganizerBox` | 저장되는 box data component |
| `MemoItem` | 저장되는 memo data component |
| `WorkspaceRealitySceneState.boxRoots` | Entity registry |
| `BoxInteractionMode` | interaction state component |
| `anchoredBoxIDs` | anchor state component |
| `updateSelectedBoxControls` | attachment placement system |
| `updateSpatialMemoPresentations` | spatial memo rendering system |
| `PlaneDetectionService` | environment sensing system |

중요한 것은 이름보다 사고방식이다.

ECS는 "객체가 모든 행동을 직접 가진다"보다 "데이터를 가진 component와 그 데이터를 처리하는 system을 나눈다"는 생각에 가깝다.

Desktop Organizer에서도 이미 그런 흐름이 보인다.

```text
데이터
- OrganizerBox
- MemoItem
- WorkspaceEntityStore 상태
- SpatialMemoPresentation

시스템처럼 움직이는 함수
- renderKnownBoxes
- updateSelectedBoxControls
- updateOpenBoxMemoLists
- updateSpatialMemoPresentations
- applyKnownWorldAnchorTransforms
```

## 21. 리팩토링 전 반드시 확인할 것

리팩토링은 기능을 바꾸지 않는 변경이다.

그래서 리팩토링 전후로 같은 동작이 유지되는지 확인해야 한다.

이 프로젝트에서는 다음을 확인해야 한다.

- 앱이 빌드되는가
- 기본 패널이 뜨는가
- 공간 인식을 시작할 수 있는가
- cyan plane이 책상 후보 위에 보이는가
- 박스를 만들 수 있는가
- 박스가 책상 위에 놓이는가
- 박스를 드래그할 수 있는가
- 박스를 클릭하면 열리고 다시 클릭하면 닫히는가
- 박스 아래 삭제/이름/pin attachment가 따라오는가
- 메모를 만들 수 있는가
- 메모 preview를 attachment 밖으로 드래그할 수 있는가
- 공간 메모가 열린 뒤 움직이는가
- 박스와 메모 anchor 상태가 저장되는가
- 앱 재실행 후 위치가 복원되는가

리팩토링 후 이 중 하나라도 깨지면, 구조가 좋아졌다고 말하기 어렵다.

## 22. 작은 리팩토링 순서

이 프로젝트에서 안전하게 리팩토링한다면 다음 순서를 추천한다.

1. 주석과 함수 이름을 먼저 정리한다.
2. 중복된 작은 계산을 helper로 뽑는다.
3. 파일 내부에서 관련 함수 순서를 정리한다.
4. 한 파일이 너무 커지면 extension 파일로 나눈다.
5. extension 파일 안에서도 책임이 갈라지면 helper type을 만든다.
6. helper type이 상태를 가져야 할 때만 class나 actor를 검토한다.
7. 저장 데이터와 runtime 상태가 섞이면 모델을 분리한다.
8. ARKit, SwiftData, RealityKit side effect가 섞이면 service 경계를 만든다.

이 순서가 중요한 이유는, 초반부터 타입을 많이 만들면 오히려 앱의 흐름을 따라가기 어려워지기 때문이다.

## 23. 초보자를 위한 코드 읽는 순서

처음 이 프로젝트를 읽는다면 다음 순서가 좋다.

1. `DesktopOrganizerApp.swift`
2. `ControlPanelView.swift`
3. `WorkspaceEntityStore.swift`
4. `WorkspaceRealityView.swift`
5. `WorkspaceRealityState.swift`
6. `WorkspaceRealityView+Boxes.swift`
7. `WorkspaceRealityView+Attachments.swift`
8. `BoxControlAttachmentView.swift`
9. `BoxMemoAttachmentView.swift`
10. `WorkspaceRealityView+Memos.swift`
11. `SpatialMemoAttachmentViews.swift`
12. `WorkspaceRealityView+Anchors.swift`
13. `PlaneDetectionService.swift`
14. `OrganizerBox.swift`, `MemoItem.swift`, `MemoPalette.swift`

이 순서로 읽으면 "앱 시작 -> 버튼 -> 요청 저장소 -> RealityView -> Entity 생성 -> UI attachment -> 메모 -> anchor -> ARKit" 흐름을 따라갈 수 있다.

## 24. 리팩토링 체크리스트

리팩토링할 때 다음 질문을 사용하자.

```text
이 변경은 기능 변경인가, 구조 변경인가?
함수 이름만 봐도 side effect가 예상되는가?
저장 데이터와 runtime 참조가 섞이지 않았는가?
SwiftUI 상태와 RealityKit Entity 참조가 무리하게 결합되지 않았는가?
ARKit 관련 코드는 View 밖으로 충분히 빠져 있는가?
WorldAnchor 실패/Simulator fallback은 유지되는가?
메모와 박스 삭제 시 SwiftData와 scene graph가 함께 정리되는가?
attachment는 부모 Entity를 정확히 따라가는가?
리팩토링 후 실기기에서 확인할 항목이 명확한가?
```

체크리스트의 목적은 완벽한 구조를 만드는 것이 아니다.

작업자가 바뀌어도 같은 기준으로 코드를 판단하게 만드는 것이다.

## 25. 이 교재 시리즈의 마무리

이 10개 교재는 Desktop Organizer를 단순히 "완성해야 할 앱"이 아니라 "visionOS 개발을 배우는 실습 프로젝트"로 읽기 위한 지도다.

지금까지의 흐름은 다음과 같다.

```text
01 앱 구조
02 SwiftUI 상태
03 SwiftData
04 RealityKit Entity
05 Attachment / Ornament / Window
06 Spatial Interaction
07 ARKit Plane Detection
08 World Anchor
09 visionOS UX
10 Refactoring / Architecture Growth
```

이제 코드를 볼 때는 기능 하나만 보지 말고, 세 가지를 함께 보면 좋다.

```text
사용자 경험
데이터 흐름
공간 Entity lifecycle
```

이 세 가지가 맞물릴 때 visionOS 앱은 단순히 화면에 뜨는 프로그램이 아니라, 실제 공간 안에서 오래 사용할 수 있는 도구가 된다.
