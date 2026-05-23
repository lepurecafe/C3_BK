# Desktop Organizer Code Reading Guide

Last updated: 2026-05-23
Audience: 코딩을 처음 공부하는 사람
Goal: 혼자 프로젝트 파일을 열어 보면서 "앱이 어떤 순서로 실행되고, 데이터가 어디서 어디로 흐르는지" 이해하기

---

## 0. 이 앱을 한 문장으로 이해하기

Desktop Organizer는 visionOS에서 조작 패널을 띄우고, 사용자가 만든 3D 박스와 메모를 공간 안에 배치해 관리하는 앱이다.

현재 박스는 예전처럼 volumetric window로 열리지 않는다. `ImmersiveSpace` 안의 RealityKit entity로 직접 만들어지고, 그 위에 앵커 버튼과 박스 안 메모 목록이 attachment로 붙는다.

앱의 핵심 흐름은 아래 5단계다.

1. 앱 실행
2. `ControlPanelView`가 열린다
3. 사용자가 공간 인식, 박스 생성, 박스 안 메모 생성을 누른다
4. SwiftUI가 `WindowGroup` 또는 `ImmersiveSpace`를 찾아 조작 패널/공간을 연다
5. SwiftData가 생성된 박스와 메모 기록을 저장한다

---

## 1. 먼저 알아야 할 SwiftUI 기본 단어

### `View`

화면에 보이는 한 조각이다.

예:

- `ControlPanelView`: 버튼과 목록이 있는 조작 패널
- `WorkspaceRealityView`: 공간 속 3D 박스 entity를 관리하는 화면
- `BoxMemoAttachmentView`: 박스 위에 붙는 메모 관리 attachment

### `App`

앱의 시작점이다.

이 프로젝트에서는 `DesktopOrganizerApp`이 시작점이다.

```swift
@main
struct DesktopOrganizerApp: App
```

`@main`은 "앱을 실행하면 여기서 시작한다"는 표시다.

### `Scene`

visionOS에서 하나의 창 또는 몰입 공간 단위다.

이 앱에는 주로 2개의 Scene이 있다.

| Scene | 역할 |
|------|------|
| `controlPanelScene` | 앱을 실행하면 처음 보이는 조작 패널 |
| `sensingSpaceScene` | ARKit 공간 인식과 3D 박스 entity를 실행하는 mixed ImmersiveSpace |

### `@State`

View 또는 App이 직접 소유하는 상태다.

예:

```swift
@State private var panelMode: PanelMode = .home
```

뜻:

- `.home`이면 기본 인사 화면을 보여준다.
- `.namingBox`가 되면 박스 이름 입력 화면을 보여준다.
- 값이 바뀌면 SwiftUI가 화면을 다시 그린다.

### `@Environment`

부모 쪽에서 내려준 기능이나 값을 꺼내 쓰는 방법이다.

예:

```swift
@Environment(\.openImmersiveSpace) private var openImmersiveSpace
```

뜻:

- `openImmersiveSpace(...)`를 호출하면 앱에 등록된 몰입 공간을 열 수 있다.
- `ControlPanelView`가 직접 ARKit 화면을 만드는 것이 아니라, SwiftUI 환경에 "이 공간 열어줘"라고 요청한다.

### `@Query`

SwiftData 저장소에서 데이터를 자동으로 읽어오는 방법이다.

예:

```swift
@Query(sort: \OrganizerBox.createdAt) private var boxes: [OrganizerBox]
```

뜻:

- 저장된 `OrganizerBox`들을 `createdAt` 순서로 가져온다.
- 새 박스가 저장되면 `boxes`가 자동으로 바뀌고 화면도 다시 그려진다.

### `Binding`

부모의 값을 자식 View가 읽고 수정할 수 있게 연결한 것이다.

예:

```swift
TextField("예: 회의 메모", text: $draftBoxName)
```

`$draftBoxName`은 "값을 복사해서 주는 것"이 아니라 "이 값과 연결된 손잡이를 주는 것"에 가깝다.

---

## 2. 파일 읽는 순서

처음부터 모든 파일을 동시에 보려고 하면 어렵다. 아래 순서로 읽으면 흐름이 잡힌다.

### 1단계: 앱 시작점

읽을 파일:

- `DesktopOrganizer/App/DesktopOrganizerApp.swift`
- `DesktopOrganizer/App/DesktopOrganizerApp+Scenes.swift`

볼 것:

- 앱이 어떤 Scene들을 등록하는지
- 기본 창이 무엇인지
- ARKit 공간 인식과 3D 박스 공간은 어떤 Scene에서 시작되는지

핵심 질문:

- 앱 실행 후 처음 보이는 View는 무엇인가?
- `ControlPanelView`가 여는 창과 공간은 어디에 미리 등록되어 있는가?

### 2단계: 사용자가 처음 만나는 화면

읽을 파일:

- `DesktopOrganizer/Views/ControlPanelView.swift`

볼 것:

- 버튼이 어떤 함수를 호출하는지
- `createBox(named:)`가 어떤 순서로 실행되는지
- 저장된 박스/메모 목록이 어떻게 화면에 표시되는지
- 박스 안 메모가 `MemoItem.containerBoxID`로 어떻게 연결되는지

핵심 질문:

- 박스 생성 버튼을 누르면 어떤 코드가 실행되는가?
- 박스 안 메모 목록은 어떤 기준으로 필터링되는가?

### 3단계: 데이터 모델

읽을 파일:

- `DesktopOrganizer/Models/OrganizerBox.swift`
- `DesktopOrganizer/Models/MemoItem.swift`
- `DesktopOrganizer/Models/MemoPalette.swift`

볼 것:

- `OrganizerBox`, `MemoItem`은 SwiftData 저장용 모델이다.
- `MemoPalette`는 메모 색상 배열과 안전한 색상 인덱스 처리를 담당한다.
- `MemoItem.containerBoxID`는 메모가 어느 박스에서 만들어졌는지 연결한다.
- `MemoItem.isSpatiallyPresented`가 true이면 공간에 꺼낸 메모 attachment로 복원된다.
- `OrganizerBox.worldAnchorIdentifier`는 실제 ARKit WorldAnchor가 만들어졌을 때 채워진다.

핵심 질문:

- 앱을 껐다 켜도 남아야 하는 값은 어떤 타입에 저장되는가?
- 메모가 어느 박스 안에 들어 있는지는 어디에 저장되는가?
- Simulator에서 앵커 버튼을 눌렀을 때 왜 `worldAnchorIdentifier`가 비어 있을 수 있을까?

### 4단계: 박스 안 메모와 공간 메모 흐름

읽을 파일:

- `DesktopOrganizer/Views/WorkspaceRealityView.swift`
- `DesktopOrganizer/Views/ColorButton.swift`

볼 것:

- 박스 위 attachment 안에서 메모 내용을 입력하고 색상을 고른다.
- 저장 버튼을 누르면 `MemoItem(containerBoxID: box.id)`로 저장한다.
- 메모 카드를 클릭하거나 밖으로 드래그하면 공간 메모 attachment가 열린다.
- 공간 메모는 이동, 닫기, 삭제, 앵커링을 할 수 있다.

핵심 질문:

- 입력 중인 텍스트는 언제 SwiftData에 저장되는가?
- 색상은 왜 `Color`가 아니라 `colorIndex`로 저장되는가?
- 공간 메모를 닫는 것과 삭제하는 것은 어떻게 다를까?

### 5단계: 박스와 3D entity

읽을 파일:

- `DesktopOrganizer/Views/WorkspaceRealityView.swift`
- `DesktopOrganizer/Services/WorkspaceEntityStore.swift`
- `Packages/RealityKitContent/Sources/RealityKitContent/RealityKitContent.swift`
- `Packages/RealityKitContent/Package.swift`

볼 것:

- 3D 모델은 앱 본체가 아니라 `RealityKitContent` Swift Package에 들어 있다.
- `realityKitContentBundle`은 그 패키지 안의 리소스를 찾기 위한 경로다.
- `WorkspaceRealityView`는 `Entity(named:in:)`로 `TravelCaseScene`을 읽는다.
- `WorkspaceEntityStore`는 선택된 박스, 열린 박스, 앵커 상태, reset revision 같은 화면 상태를 모은다.
- 앵커 버튼과 박스 안 메모 목록은 `RealityView` attachment로 만들어진 뒤 박스 entity의 자식으로 붙는다.

핵심 질문:

- `Bundle.module`은 왜 필요할까?
- 새 `OrganizerBox`가 저장되면 어떻게 공간 속 entity가 생길까?
- 박스를 클릭했을 때 열림/닫힘 상태는 어디에 저장될까?

### 6단계: 공간 인식과 WorldAnchor

읽을 파일:

- `DesktopOrganizer/Views/PlaneOverlayView.swift`
- `DesktopOrganizer/Services/PlaneDetectionService.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView.swift`

볼 것:

- 공간 인식은 일반 창이 아니라 `ImmersiveSpace` 안에서 시작한다.
- `PlaneDetectionService`가 ARKit session, plane detection, world tracking 상태를 관리한다.
- 감지 결과는 `statusText`, `detectedTablePlane`, `tablePlaneDebugRevision`으로 UI에 전달된다.
- 책상 plane이 감지되면 `WorkspaceRealityView`가 반투명 cyan plane entity를 만들어 실제 감지 위치를 보여준다.
- Simulator에서는 WorldAnchor 추가가 지원되지 않아서 임시 잠금 fallback으로 동작할 수 있다.

핵심 질문:

- 왜 `ControlPanelView`에서 직접 ARKit을 시작하지 않을까?
- 감지된 책상 위치는 어디서 계산될까?
- plane detection과 occlusion은 왜 같은 기능이 아닐까?

---

## 3. 버튼을 눌렀을 때 실제 실행 순서

### 3.1 공간 인식 시작

```text
사용자: "공간 인식 시작" 버튼 탭
-> ControlPanelView.startSensing()
-> openImmersiveSpace(id: "sensing")
-> DesktopOrganizerApp+Scenes.sensingSpaceScene
-> PlaneOverlayView + WorkspaceRealityView
-> planeService.startDetection()
-> ARKitSession.run(...)
-> planeDetection.anchorUpdates 감시
-> statusText / detectedTablePlane 변경
-> ControlPanelView와 WorkspaceRealityView 화면 업데이트
```

### 3.2 박스 생성

```text
사용자: "박스 생성" 버튼 탭
-> ControlPanelView.createBox()
-> planeService.tablePlaneOrigin 또는 fallback 위치 읽기
-> OrganizerBox 생성
-> modelContext.insert(box)
-> try modelContext.save()
-> WorkspaceEntityStore.requestRender(boxID)
-> WorkspaceRealityView.renderKnownBoxes()
-> RealityKitContent에서 TravelCaseScene 로드
-> ImmersiveSpace 안에 박스 entity 배치
```

### 3.3 박스 안 메모 생성

```text
사용자: 열린 박스 위 attachment에서 "메모 추가" 버튼 탭
-> BoxMemoAttachmentView의 작성 UI 표시
-> 사용자가 텍스트/색상 입력
-> "저장" 버튼 탭
-> WorkspaceRealityView.createMemo(in:text:colorIndex:)
-> MemoItem 생성
-> modelContext.insert(memo)
-> try modelContext.save()
-> 박스 위 메모 목록 갱신
```

### 3.4 박스 안 메모 조회와 공간 메모 열기

```text
사용자: 공간 속 박스 entity 탭
-> WorkspaceRealityView.handleBoxTap(...)
-> WorkspaceEntityStore interaction mode 변경
-> 박스 열림 애니메이션 재생
-> BoxMemoAttachmentView가 박스 위 attachment로 표시
-> attachment 안의 메모 카드 탭 또는 drag out
-> WorkspaceRealityView.openSpatialMemo(...) 또는 drag out 완료 처리
-> 공간 메모 attachment 표시
```

### 3.5 데이터 초기화

```text
사용자: "데이터 초기화" 버튼 탭
-> ControlPanelView.resetAllData()
-> SwiftData의 OrganizerBox와 MemoItem 삭제
-> WorkspaceEntityStore.resetWorkspace()
-> WorkspaceRealityView.resetRenderedWorkspace()
-> 공간 속 박스 entity와 attachment 정리
```

---

## 4. 이 프로젝트에서 헷갈리기 쉬운 포인트

### 4.1 저장 모델과 화면 상태는 다르다

이 프로젝트에는 비슷해 보이는 타입들이 있다.

| 저장용 | 화면/런타임 상태 | 이유 |
|--------|-----------|------|
| `OrganizerBox` | RealityKit box entity | 박스를 앱 재실행 후 같은 위치에 복원하기 위해 |
| `MemoItem` | spatial memo attachment | 메모 본문과 공간 배치 상태를 함께 복원하기 위해 |
| `WorkspaceEntityStore` | 선택/열림/reset 상태 | SwiftData에 저장하지 않을 임시 interaction 상태를 공유하기 위해 |

처음에는 번거로워 보이지만, 이 분리가 있으면 저장 데이터와 현재 화면 상태를 따로 생각할 수 있다.

### 4.2 공간 메모는 plain window가 아니다

현재 메모는 별도 `WindowGroup`으로 열지 않는다.

```text
MemoItem
-> SpatialMemoPresentation
-> RealityView Attachment
-> 필요하면 WorldAnchor
```

이 구조를 쓰는 이유는 메모도 박스처럼 이동, 앵커링, billboard 적용을 받아야 하기 때문이다.

### 4.3 `ImmersiveSpace`는 ARKit과 공간 entity를 실행하기 위한 무대다

`PlaneOverlayView`와 `WorkspaceRealityView`는 `sensingSpaceScene` 안에서 함께 실행된다.

필요한 이유는:

- visionOS에서 공간 인식을 하려면 mixed ImmersiveSpace가 필요하다.
- 3D 박스를 실제 공간 entity처럼 다루려면 RealityKit entity가 필요하다.
- 감지 결과와 박스 상태는 service/store를 통해 ControlPanel과 WorkspaceRealityView가 공유한다.

### 4.4 plane detection은 occlusion이 아니다

책상이 감지되었다고 해서 책상이 자동으로 3D 오브젝트를 가려주는 것은 아니다.

현재 앱은 감지 확인을 쉽게 하기 위해 감지된 책상 위치에 반투명 cyan plane을 그린다. 이 plane은 앱이 책상 후보로 확정한 수평면이다.

### 4.5 Preview는 실제 앱 실행과 다르다

`#Preview`는 Xcode 안에서 화면 조각을 빠르게 보는 기능이다.

주의할 점:

- Preview에서는 전체 App의 Scene 등록이 항상 같이 뜨지 않는다.
- `openImmersiveSpace`와 ARKit 흐름은 실제 앱 실행에서 확인해야 한다.
- Preview에서는 `.modelContainer(..., inMemory: true)`처럼 가짜 저장소를 넣어줘야 할 때가 있다.

---

## 5. 혼자 공부할 때 추천 방법

### 5.1 한 번에 외우려고 하지 말기

처음에는 이름만 익혀도 충분하다.

- `DesktopOrganizerApp`: 시작점
- `ControlPanelView`: 조작 패널
- `PlaneDetectionService`: ARKit, plane detection, WorldAnchor 상태 관리
- `WorkspaceRealityView`: 3D 박스 entity, attachment, interaction 관리
- `WorkspaceEntityStore`: 공간 속 박스 UI 상태 관리
- `MemoPalette`: 메모 색상 팔레트
- `OrganizerBox`, `MemoItem`: 저장 데이터

### 5.2 버튼 하나씩 따라가기

가장 좋은 공부 방법은 버튼 하나를 정하고 끝까지 추적하는 것이다.

추천 순서:

1. "공간 인식 시작" 버튼
2. "박스 만들기" 버튼
3. 박스 이름 입력 후 "확인" 버튼
4. 공간 속 박스 탭
5. 박스 위 "메모 추가" 버튼
6. 메모 카드 drag out
7. 공간 메모 닫기/삭제/앵커 버튼

### 5.3 주석을 읽을 때 보는 기준

주석은 코드의 모든 단어를 번역하는 용도가 아니다.

좋은 주석은 아래 질문에 답한다.

- 이 코드가 왜 필요한가?
- 이 값이 어디서 와서 어디로 가는가?
- 이 타입은 저장용인가, 화면용인가?
- 사용자가 어떤 행동을 하면 여기까지 도달하는가?
- 나중에 확장할 때 어디를 바꾸면 되는가?

이 프로젝트의 주석도 이 기준으로 읽으면 좋다.

---

## 6. 다음에 공부하면 좋은 주제

1. SwiftUI 기본
   - `View`
   - `@State`
   - `@Binding`
   - `@Environment`
   - `sheet`

2. visionOS 창 구조
   - `WindowGroup`
   - `.windowStyle(.plain)`
   - `ImmersiveSpace`
   - `openImmersiveSpace`
   - `openImmersiveSpace`
   - `RealityView` attachment

3. SwiftData
   - `@Model`
   - `ModelContext`
   - `insert`
   - `save`
   - `@Query`

4. RealityKit
   - `RealityView`
   - `Entity`
   - `ModelEntity`
   - `Bundle.module`
   - `visualBounds`
   - `transform`
   - `AnimationPlaybackController`

5. ARKit on visionOS
   - `ARKitSession`
   - `PlaneDetectionProvider`
   - `WorldTrackingProvider`
   - `WorldAnchor`
