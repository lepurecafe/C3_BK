# visionOS 공간 UI 구현 패턴 학습 노트

Last updated: 2026-05-24
Audience: visionOS 공간 UI 구현을 처음 학습하는 팀원
Goal: Desktop Organizer를 그대로 복제하는 것이 아니라, 이 앱에 들어간 구현 패턴을 다른 앱에 응용할 수 있게 이해하기

---

## 0. 이 문서의 목적

이 문서는 "Desktop Organizer를 똑같이 다시 만드는 매뉴얼"이 아니다.

목적은 이 앱에서 사용한 visionOS 구현 패턴을 하나씩 분해해서 학습하는 것이다. 예를 들어 "박스 아래 버튼"을 설명할 때는 버튼의 모양만 설명하지 않고, SwiftUI View가 어떻게 RealityKit entity 아래에 붙었는지, 그 방식을 다른 3D 오브젝트에도 어떻게 응용할 수 있는지를 설명한다.

각 장은 아래 흐름으로 읽으면 좋다.

1. 이 패턴으로 해결하는 문제
2. 이 앱에서는 어떻게 구현했는가
3. 핵심 코드
4. 핵심 아이디어
5. 직접 만들어보는 최소 예제
6. 다른 방식으로도 가능한가
7. 언제 이 방식을 고르면 좋은가
8. 공식문서 / 참고자료

---

## 1. 전체 구조 패턴

### 이 패턴으로 해결하는 문제

visionOS 앱은 일반 iPhone 앱처럼 화면 하나만 생각하면 어렵다. 앱에는 작은 조작 패널도 있고, 실제 공간에 떠 있는 3D 오브젝트도 있고, 저장 데이터도 있다.

그래서 이 앱은 역할을 나눴다.

```text
DesktopOrganizerApp
├─ WindowGroup
│  └─ ControlPanelView
│     └─ 버튼, 이름 입력, 상태 표시
└─ ImmersiveSpace(id: "sensing")
   └─ PlaneOverlayView
      └─ WorkspaceRealityView
         ├─ RealityKit 3D entity
         └─ SwiftUI attachment
```

### 이 앱에서는 어떻게 구현했나?

앱의 시작점은 `DesktopOrganizerApp`이다.

```swift
@main
struct DesktopOrganizerApp: App {
    @State var planeService = PlaneDetectionService()

    var body: some Scene {
        controlPanelScene
        sensingSpaceScene
    }
}
```

Scene 등록은 `DesktopOrganizerApp+Scenes.swift`에서 분리했다.

```swift
WindowGroup {
    ControlPanelView()
}
.modelContainer(for: [OrganizerBox.self, MemoItem.self])
.environment(planeService)
```

```swift
ImmersiveSpace(id: "sensing") {
    PlaneOverlayView()
}
.immersionStyle(selection: .constant(.mixed), in: .mixed)
.modelContainer(for: [OrganizerBox.self, MemoItem.self])
.environment(planeService)
```

파일:

- `DesktopOrganizer/App/DesktopOrganizerApp.swift`
- `DesktopOrganizer/App/DesktopOrganizerApp+Scenes.swift`
- `DesktopOrganizer/Views/ControlPanelView.swift`
- `DesktopOrganizer/Views/PlaneOverlayView.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView.swift`

### 핵심 아이디어

`WindowGroup`은 사용자가 누르는 조작 패널이고, `ImmersiveSpace`는 실제 공간에 3D 오브젝트를 배치하는 무대다.

역할을 짧게 정리하면:

- `WindowGroup`: 리모컨
- `ImmersiveSpace`: 무대
- `RealityView`: 무대 위에 물건을 올리는 장치
- `SwiftData`: 물건과 메모의 기록장
- `PlaneDetectionService`: 책상 위치를 찾는 감지 담당자

### 저장 데이터와 실행 중 상태는 다르다

이 앱을 읽을 때 가장 헷갈리기 쉬운 부분은 `SwiftData`와 `WorkspaceEntityStore`의 차이다.

둘 다 "박스 정보"를 다루지만 역할이 다르다.

```text
SwiftData
앱을 껐다 켜도 남아야 하는 기록장
예: OrganizerBox, MemoItem

WorkspaceEntityStore
지금 열린 ImmersiveSpace 안에서만 필요한 작업 지시서
예: 새 박스를 공간에 띄워 달라는 요청, 현재 선택된 박스, animation 상태
```

예를 들어 사용자가 새 박스를 만들면 먼저 `OrganizerBox`가 SwiftData에 저장된다.

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

그 다음 현재 열린 공간에 실제 entity를 띄우기 위해 `WorkspaceEntityStore`에 요청을 넣는다.

```swift
workspaceStore.addBox(
    id: box.id,
    position: position
)
```

쉽게 말하면:

```text
SwiftData에 저장한다
-> 앱을 다시 켜도 박스 기록이 남는다

WorkspaceEntityStore에 요청한다
-> 지금 열린 공간에 박스 entity를 그린다
```

이 둘을 나누면 좋은 점이 있다.

- 저장 실패와 화면 표시 실패를 따로 다룰 수 있다.
- 앱 재실행 후에는 SwiftData를 읽어 다시 그릴 수 있다.
- 지금 화면에서만 필요한 선택 상태, animation 상태를 저장 데이터에 섞지 않아도 된다.

### `.task(id:)`와 revision 패턴

`RealityView` 안에서는 SwiftUI 화면처럼 모든 것을 자동으로 다시 그리기 어렵다. 이미 만들어 둔 RealityKit entity를 언제 새로 만들고, 언제 지울지 직접 알려줘야 한다.

그래서 이 앱은 `revision`이라는 숫자를 사용한다.

```swift
private(set) var revision = 0
```

새 박스 요청이 들어오면 revision을 올린다.

```swift
revision += 1
```

그리고 `WorkspaceRealityView`에서는 이 값을 `.task(id:)`에 연결한다.

```swift
.task(id: renderRevision) {
    await renderKnownBoxes()
}
```

`renderRevision`은 저장된 박스 id와 `workspaceStore.revision`을 합친 문자열이다.

```swift
private var renderRevision: String {
    let persistedIDs = persistedBoxes
        .map(\.id.uuidString)
        .joined(separator: "|")

    return "\(workspaceStore.revision):\(persistedIDs)"
}
```

이렇게 하면 둘 중 하나가 바뀔 때 렌더링을 다시 확인한다.

```text
새 박스 요청이 들어옴
-> workspaceStore.revision 증가
-> renderRevision 변경
-> .task(id:) 재실행
-> renderKnownBoxes() 호출
```

공간 메모도 비슷하다. 메모가 열렸는지, 위치가 바뀌었는지, anchor id가 생겼는지를 문자열로 펼쳐서 `spatialMemoPersistenceRevision`을 만든다. 값이 바뀌면 공간 메모 attachment를 다시 복원한다.

대안도 있다.

- 직접 함수를 호출해서 바로 entity를 만들 수 있다.
- 모든 상태를 `@State` 배열에 넣고 SwiftUI 변경만 믿을 수 있다.
- 별도 Observable view model을 만들어 더 엄격하게 상태를 관리할 수 있다.

하지만 이 앱처럼 SwiftData, RealityKit entity, attachment가 함께 움직이는 구조에서는 `revision` 숫자로 "다시 확인해"라고 알려주는 방식이 단순하고 추적하기 쉽다.

### 직접 만들어보는 최소 예제

```swift
@main
struct MySpatialApp: App {
    var body: some Scene {
        WindowGroup {
            ControlPanelView()
        }

        ImmersiveSpace(id: "space") {
            RealityContentView()
        }
    }
}
```

### 다른 방식으로도 가능한가?

가능하다.

- 공간 오브젝트가 필요 없다면 `WindowGroup`만으로 만들 수 있다.
- 3D 오브젝트가 단순히 보여주기용이면 `Model3D`만 써도 된다.
- 여러 개의 독립 창을 열어야 한다면 value-based `WindowGroup(for:)`를 추가할 수 있다.

### 언제 이 방식을 고르면 좋은가?

3D 오브젝트가 실제 공간에 놓여야 하고, 그 주변에 버튼이나 메모 UI가 같이 붙어야 한다면 이 앱처럼 `ImmersiveSpace + RealityView + Attachment` 구조가 적합하다.

### 공식문서 / 참고자료

- [Apple Developer - WindowGroup](https://developer.apple.com/documentation/swiftui/windowgroup)
- [Apple Developer - ImmersiveSpace](https://developer.apple.com/documentation/swiftui/immersivespace)
- [Apple Developer - RealityView](https://developer.apple.com/documentation/realitykit/realityview)
- [Apple Developer - SwiftData](https://developer.apple.com/documentation/swiftdata)
- [Apple Developer - task(id:priority:_:)](https://developer.apple.com/documentation/swiftui/view/task%28id:priority:_%3A%29)

---

## 2. 버튼으로 ImmersiveSpace 열기

### 이 패턴으로 해결하는 문제

사용자가 버튼을 눌렀을 때 실제 공간 UI를 시작하고 싶을 때 사용한다.

이 앱에서는 조작 패널의 `공간 인식 시작` 버튼이 `ImmersiveSpace(id: "sensing")`를 연다. 그 공간 안에서 ARKit 평면 감지와 3D 박스 표시가 시작된다.

### 이 앱에서는 어떻게 구현했나?

`ControlPanelView`는 SwiftUI 환경에서 `openImmersiveSpace`를 꺼내 쓴다.

```swift
@Environment(\.openImmersiveSpace) private var openImmersiveSpace
```

버튼은 `startSensing()`을 호출한다.

```swift
Button(isSensingOpen ? "책상 다시 인식" : "공간 인식 시작") {
    startSensing()
}
```

실제 공간 열기는 `openSensingIfNeeded()`에서 처리한다.

```swift
let result = await openImmersiveSpace(id: "sensing")
switch result {
case .opened:
    isSensingOpen = true
    controlStatusText = "공간 열림"
case .userCancelled:
    isSensingOpen = false
    controlStatusText = "공간 열기 취소됨"
case .error:
    isSensingOpen = false
    planeService.statusText = "공간 인식 시작 실패"
    controlStatusText = "공간 열기 실패"
@unknown default:
    isSensingOpen = false
    controlStatusText = "공간 상태 알 수 없음"
}
```

파일:

- `DesktopOrganizer/Views/ControlPanelView.swift`
- `DesktopOrganizer/App/DesktopOrganizerApp+Scenes.swift`
- `DesktopOrganizer/Views/PlaneOverlayView.swift`

### 핵심 아이디어

`ControlPanelView`가 직접 3D 공간을 만드는 것이 아니다. 이미 앱 시작점에 등록해 둔 `ImmersiveSpace(id: "sensing")`를 SwiftUI에게 "열어줘"라고 요청한다.

등록은 앱 쪽에서 한다.

```swift
ImmersiveSpace(id: "sensing") {
    PlaneOverlayView()
}
```

열기는 버튼 쪽에서 한다.

```swift
await openImmersiveSpace(id: "sensing")
```

### 직접 만들어보는 최소 예제

```swift
struct ControlPanelView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        Button("공간 열기") {
            Task {
                await openImmersiveSpace(id: "mySpace")
            }
        }
    }
}
```

### 다른 방식으로도 가능한가?

가능하다.

- 앱 시작 직후 자동으로 `ImmersiveSpace`를 열 수 있다.
- 사용자의 명시적 버튼 없이 특정 상태가 되면 열 수 있다.
- 공간 UI가 필요 없다면 일반 `WindowGroup`만 쓸 수 있다.

### 언제 이 방식을 고르면 좋은가?

사용자가 준비된 뒤 공간 인식을 시작해야 하거나, 권한/성능/입력 타이밍을 조절하고 싶다면 버튼으로 여는 방식이 좋다.

### 공식문서 / 참고자료

- [Apple Developer - openImmersiveSpace](https://developer.apple.com/documentation/swiftui/environmentvalues/openimmersivespace)
- [Apple Developer - ImmersiveSpace](https://developer.apple.com/documentation/swiftui/immersivespace)
- [Apple Developer - ARKit in visionOS](https://developer.apple.com/documentation/arkit/arkit-in-visionos)

---

## 3. 공간에 3D entity 배치하기

### 이 패턴으로 해결하는 문제

앱 안에 포함된 3D 모델을 실제 공간 안에 오브젝트처럼 놓고 싶을 때 사용한다.

이 앱에서는 travel case 모델을 `RealityKitContent` 패키지에 넣고, `WorkspaceRealityView`에서 `Entity(named:in:)`로 불러온다.

### 이 앱에서는 어떻게 구현했나?

`RealityView`가 열릴 때 root entity를 만들고 content에 추가한다.

```swift
RealityView { content, attachments in
    let root = Entity()
    root.name = "WorkspaceRoot"
    sceneState.rootEntity = root
    content.add(root)
}
```

박스를 실제로 만들 때는 `renderBox(...)`가 실행된다.

```swift
guard let travelCase = try? await Entity(
    named: "TravelCaseScene",
    in: realityKitContentBundle
) else {
    return
}
```

그 다음 박스의 wrapper entity를 만든다.

```swift
let boxRoot = Entity()
boxRoot.name = boxEntityName(for: id)
boxRoot.position = position
```

그리고 3D 모델을 그 아래에 붙인다.

```swift
boxRoot.addChild(travelCase)
rootEntity.addChild(boxRoot)
```

전체 구조는 이렇게 된다.

```text
WorkspaceRoot
└─ WorkspaceBox:{UUID}
   └─ TravelCaseScene
```

파일:

- `DesktopOrganizer/Views/WorkspaceRealityView.swift`
- `Packages/RealityKitContent/Sources/RealityKitContent/RealityKitContent.swift`
- `Packages/RealityKitContent/Sources/RealityKitContent/RealityKitContent.rkassets/TravelCaseScene.usda`

### 핵심 아이디어

3D 모델 entity 자체를 바로 움직이는 대신, `boxRoot`라는 빈 wrapper entity를 하나 더 만든다.

이렇게 하면 역할이 나뉜다.

- `boxRoot`: 박스의 실제 공간 위치 담당
- `travelCase`: 모델 모양, 크기 보정, animation 담당

그래서 박스를 이동할 때는 `boxRoot.position`을 바꾸면 되고, 모델 스케일이나 바닥 맞춤은 `travelCase` 안에서 처리하면 된다.

### 왜 `boxRoot`와 `travelCase`를 나눴을까?

핵심 이유는 "공간에서 움직이는 물체"와 "실제 3D 모델 모양"의 책임을 분리하기 위해서다.

이 앱의 박스 구조는 아래처럼 생겼다.

```text
WorkspaceRoot
└─ boxRoot Entity
   ├─ travelCase Entity
   ├─ 하단 버튼 attachment
   └─ 메모 목록 attachment
```

`boxRoot`는 박스 한 개의 대표 좌표다. 사용자가 박스를 드래그해서 옮길 때, 저장된 위치로 복원할 때, WorldAnchor를 붙일 때는 `boxRoot.position` 또는 `boxRoot.transform`을 다룬다.

반면 `travelCase`는 실제 USDZ 모델이다. 이쪽에서는 모델 크기를 맞추고, 바닥 높이를 보정하고, 내장 animation을 재생한다.

이렇게 나누면 좋은 점이 있다.

1. 위치 이동이 단순해진다.
   박스를 옮길 때 `travelCase` 모델 자체를 직접 옮기지 않고 `boxRoot`만 움직이면 된다. 하단 버튼과 메모 목록도 `boxRoot`의 자식이므로 박스를 옮길 때 같이 따라온다.

2. 모델 보정이 공간 좌표를 망치지 않는다.
   USDZ 모델은 pivot이 이상하거나 크기가 너무 클 수 있다. 그래서 `travelCase.scale`이나 `travelCase.position.y`를 조정해도, 박스의 실제 공간 좌표인 `boxRoot.position`은 그대로 유지된다.

3. attachment를 붙일 안정적인 기준점이 생긴다.
   하단 버튼은 `boxRoot.addChild(controls)`로 붙이고, 메모 목록도 `boxRoot.addChild(memoList)`로 붙인다. 만약 `travelCase`에 바로 붙이면 모델 scale, pivot, animation 영향을 같이 받아서 UI 위치 잡기가 더 어려워질 수 있다.

4. animation과 드래그 이동이 섞이지 않는다.
   `travelCase`는 열림/닫힘 animation을 담당하고, `boxRoot`는 공간 이동을 담당한다. 그래서 "박스 위치는 이동 중인데 모델 뚜껑은 열리는 중" 같은 상태에서도 역할이 덜 꼬인다.

정리하면 아래처럼 기억하면 된다.

```text
boxRoot = 이 박스의 공간상 대표 좌표
travelCase = 그 좌표 안에 들어가는 실제 모델
```

다른 앱에서도 이 패턴은 자주 쓸 수 있다. 특히 3D 모델에 크기 보정, pivot 보정, animation, UI attachment가 같이 필요하면 wrapper entity를 하나 두는 편이 다루기 쉽다.

### 직접 만들어보는 최소 예제

```swift
RealityView { content in
    let root = Entity()
    content.add(root)

    if let model = try? await Entity(named: "MyModel", in: realityKitContentBundle) {
        let wrapper = Entity()
        wrapper.position = SIMD3<Float>(0, 1.0, -1.0)
        wrapper.addChild(model)
        root.addChild(wrapper)
    }
}
```

### 다른 방식으로도 가능한가?

가능하다.

- 간단한 3D 모델 표시만 필요하면 SwiftUI의 `Model3D`를 쓸 수 있다.
- 코드로 박스, 구, 평면 같은 기본 mesh를 직접 만들 수 있다.
- Reality Composer Pro에서 scene을 만들고 scene 단위로 불러올 수 있다.

### 언제 이 방식을 고르면 좋은가?

3D 오브젝트를 탭하거나 드래그하거나, 그 주변에 SwiftUI attachment를 붙여야 한다면 `RealityView + Entity` 방식이 좋다.

### 공식문서 / 참고자료

- [Apple Developer - RealityView](https://developer.apple.com/documentation/realitykit/realityview)
- [Apple Developer - Entity](https://developer.apple.com/documentation/realitykit/entity)
- [Apple Developer - Entity.load(named:in:)](https://developer.apple.com/documentation/realitykit/entity/load(named:in:))
- [Apple Developer - Model3D](https://developer.apple.com/documentation/swiftui/model3d)

---

## 4. entity에 SwiftUI 버튼 붙이기

### 이 패턴으로 해결하는 문제

3D 오브젝트 가까이에 삭제, 고정, 설정 같은 버튼을 붙이고 싶을 때 사용한다.

이 앱에서는 박스를 선택하면 박스 아래에 작은 버튼 바가 붙는다. 이 버튼 바는 3D 모델이 아니라 SwiftUI View다.

### 이 앱에서는 어떻게 구현했나?

먼저 SwiftUI 버튼 View를 만든다.

```swift
struct BoxControlAttachmentView: View {
    let boxName: String
    let isAnchored: Bool
    let onDelete: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }

            Text(boxName)
                .font(.caption)
                .lineLimit(1)

            Button {
                onToggle()
            } label: {
                Image(systemName: isAnchored ? "pin.fill" : "pin")
                    .font(.caption)
            }
        }
        .glassBackgroundEffect()
    }
}
```

그 다음 `RealityView`의 `attachments` 블록에 등록한다.

```swift
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
```

마지막으로 attachment entity를 꺼내서 선택된 박스의 자식으로 붙인다.

```swift
private func updateSelectedBoxControls(attachments: RealityViewAttachments) {
    guard let selectedBoxID = workspaceStore.selectedBoxID,
          let selectedBoxRoot = sceneState.boxRoots[selectedBoxID],
          let controls = attachments.entity(for: selectedBoxControlAttachmentID)
    else {
        attachments.entity(for: selectedBoxControlAttachmentID)?.removeFromParent()
        return
    }

    if controls.parent !== selectedBoxRoot {
        controls.removeFromParent()
        selectedBoxRoot.addChild(controls)
    }

    controls.position = SIMD3<Float>(0, -0.12, 0.17)
}
```

파일:

- `DesktopOrganizer/Views/BoxControlAttachmentView.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView+Attachments.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView.swift`

### 핵심 아이디어

SwiftUI View는 원래 2D UI다. 하지만 `RealityView`의 `Attachment`로 등록하면 RealityKit 안에서 entity처럼 꺼낼 수 있다.

핵심 흐름은 이렇다.

```text
SwiftUI View 만들기
-> Attachment(id:)에 등록
-> attachments.entity(for:)로 꺼내기
-> targetEntity.addChild(...)
-> position으로 위치 조정
```

여기서 `controls.position = SIMD3<Float>(0, -0.12, 0.17)`는 선택된 박스 기준 위치다.

```text
x:  0      좌우 가운데
y: -0.12   박스 기준 아래쪽
z:  0.17   사용자 쪽으로 살짝 앞으로
```

버튼을 `selectedBoxRoot`의 자식으로 붙였기 때문에, 사용자가 박스를 드래그하면 버튼도 같이 따라간다.

### ornament와 RealityKit attachment는 무엇이 다른가?

이 버튼 바는 모양만 보면 visionOS의 `ornament`처럼 느껴질 수 있다. 하지만 구현 방식은 `ornament`가 아니라 `RealityView`의 `Attachment`다.

둘의 가장 큰 차이는 "무엇에 붙는가"다.

| 구분 | SwiftUI ornament | RealityKit attachment |
|------|------------------|-----------------------|
| 붙는 대상 | SwiftUI window, volume, view, scene | RealityKit entity 또는 RealityKit scene graph |
| 좌표 기준 | 창/scene 주변 UI 위치 | 3D 공간 좌표 |
| 부모가 움직일 때 | entity를 자동으로 따라가지 않음 | parent entity의 자식으로 붙이면 같이 움직임 |
| WorldAnchor와의 궁합 | 약함 | 좋음 |
| 이 앱의 박스 아래 버튼에 적합한가 | 부적합 | 적합 |

`ornament`는 창 주변에 붙는 시스템 UI에 가깝다.

```swift
SomeView()
    .ornament(attachmentAnchor: .scene(.bottom)) {
        Button("설정") {
            // window 주변의 보조 UI
        }
    }
```

이 코드는 SwiftUI view나 scene 주변에 버튼을 붙인다. 그래서 조작 패널 아래에 앱 설정 버튼을 붙이는 용도라면 좋다. 하지만 RealityKit 박스 entity가 책상 위에서 움직일 때, 이 버튼이 박스 아래를 따라다니지는 않는다.

반면 `RealityView Attachment`는 SwiftUI View를 RealityKit에서 다룰 수 있는 attachment entity로 꺼낸다.

```swift
Attachment(id: "box-controls") {
    Button("고정") {
        // 특정 3D entity에 붙는 조작 UI
    }
}
```

그리고 update 단계에서 이 attachment entity를 박스 entity의 자식으로 붙인다.

```swift
if let controls = attachments.entity(for: "box-controls") {
    boxRoot.addChild(controls)
    controls.position = SIMD3<Float>(0, -0.12, 0.17)
}
```

이렇게 하면 `controls`는 SwiftUI로 만든 버튼이지만, 배치는 RealityKit entity처럼 처리된다. 박스가 움직이면 child인 controls도 같이 움직인다.

이 앱 기준으로 정리하면 아래와 같다.

```text
ControlPanel 창 주변 설정 버튼  -> ornament 후보
박스 아래 [삭제] [이름] [고정] -> RealityKit attachment
메모 아래 [닫기] [삭제] [고정] -> RealityKit attachment
```

즉, "3D 오브젝트의 오너먼트처럼 보이는 UI"를 만들 수는 있지만, 실제 구현은 SwiftUI `ornament`가 아니라 RealityKit attachment를 쓰는 편이 맞다.

### 직접 만들어보는 최소 예제

```swift
struct ObjectControls: View {
    var body: some View {
        HStack {
            Button("삭제") {}
            Button("고정") {}
        }
        .glassBackgroundEffect()
    }
}
```

```swift
RealityView { content, attachments in
    let object = Entity()
    content.add(object)

    if let controls = attachments.entity(for: "controls") {
        object.addChild(controls)
        controls.position = SIMD3<Float>(0, -0.1, 0.2)
    }
} update: { content, attachments in
    if let controls = attachments.entity(for: "controls") {
        controls.position = SIMD3<Float>(0, -0.1, 0.2)
    }
} attachments: {
    Attachment(id: "controls") {
        ObjectControls()
    }
}
```

### 다른 방식으로도 가능한가?

가능하다.

- 별도 `WindowGroup`에 조작 패널을 열 수 있다.
- 선택된 물체의 정보만 기존 control panel에 표시할 수 있다.
- 버튼 모양을 3D mesh로 직접 만들고 tap gesture를 처리할 수 있다.
- 물체를 길게 눌렀을 때 context menu처럼 UI를 띄울 수 있다.

### 언제 이 방식을 고르면 좋은가?

버튼이 특정 3D 오브젝트와 물리적으로 같이 움직여야 한다면 attachment를 entity 자식으로 붙이는 방식이 좋다.

반대로 버튼이 항상 사용자 앞에 있어야 한다면 별도 window나 control panel이 더 적합하다.

### 공식문서 / 참고자료

- [Apple Developer - RealityView](https://developer.apple.com/documentation/realitykit/realityview)
- [Apple Developer - Entity](https://developer.apple.com/documentation/realitykit/entity)
- [Apple Developer - Attachment](https://developer.apple.com/documentation/realitykit/attachment)
- [Apple Developer - ViewAttachmentEntity](https://developer.apple.com/documentation/realitykit/viewattachmententity)
- [Apple Developer - ornament](https://developer.apple.com/documentation/swiftui/view/ornament(visibility:attachmentanchor:contentalignment:ornament:))
- [Apple Developer - SwiftUI Button](https://developer.apple.com/documentation/swiftui/button)
- [Apple Developer - glassBackgroundEffect](https://developer.apple.com/documentation/swiftui/view/glassbackgroundeffect(displaymode:))

---

## 5. entity 탭과 선택 상태 처리하기

### 이 패턴으로 해결하는 문제

공간 안에 여러 3D 오브젝트가 있을 때, 사용자가 어떤 오브젝트를 탭했는지 알아내고 선택 상태를 바꾸고 싶을 때 사용한다.

이 앱에서는 박스를 탭하면 그 박스가 선택되고, 박스 아래 버튼이 그 박스에 붙으며, 박스 열림/닫힘 애니메이션도 실행된다.

### 이 앱에서는 어떻게 구현했나?

박스 모델에 입력 대상 컴포넌트를 붙인다.

```swift
private func configureInputTargets(in entity: Entity) {
    entity.components.set(InputTargetComponent())
    entity.components.set(HoverEffectComponent())

    for child in entity.children {
        configureInputTargets(in: child)
    }
}
```

그리고 `RealityView`에 targeted tap gesture를 연결한다.

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

탭된 entity가 박스의 하위 entity일 수 있으므로, 부모를 따라 올라가며 박스 ID를 찾는다.

```swift
private func boxID(for entity: Entity) -> UUID? {
    if let id = boxID(from: entity.name) {
        return id
    }

    guard let parent = entity.parent else {
        return nil
    }

    return boxID(for: parent)
}
```

박스 root entity 이름에는 UUID를 넣어 둔다.

```swift
private func boxEntityName(for id: UUID) -> String {
    "WorkspaceBox:\(id.uuidString)"
}
```

파일:

- `DesktopOrganizer/Views/WorkspaceRealityView.swift`
- `DesktopOrganizer/Services/WorkspaceEntityStore.swift`

### 핵심 아이디어

사용자는 꼭 root entity를 정확히 탭하지 않는다. 3D 모델의 손잡이, 뚜껑, 자식 mesh를 탭할 수도 있다.

그래서 이 앱은 entity 이름에 박스 ID를 넣어 두고, 탭된 entity에서 부모 방향으로 올라가며 `WorkspaceBox:{UUID}` 이름을 찾는다.

### 직접 만들어보는 최소 예제

```swift
model.components.set(InputTargetComponent())
model.components.set(HoverEffectComponent())
model.generateCollisionShapes(recursive: true)
```

```swift
TapGesture()
    .targetedToAnyEntity()
    .onEnded { value in
        print("Tapped entity:", value.entity.name)
    }
```

### 다른 방식으로도 가능한가?

가능하다.

- entity에 custom component를 붙여 ID를 저장할 수 있다.
- 박스 root만 input target으로 만들고 자식은 입력 대상에서 제외할 수 있다.
- 3D 오브젝트마다 별도 gesture를 구성할 수 있다.

### 언제 이 방식을 고르면 좋은가?

3D 모델 구조가 복잡하고 어떤 child entity가 탭될지 예측하기 어렵다면, 부모를 따라 올라가며 ID를 찾는 방식이 실용적이다.

### 공식문서 / 참고자료

- [Apple Developer - Entity](https://developer.apple.com/documentation/realitykit/entity)
- [Apple Developer - InputTargetComponent](https://developer.apple.com/documentation/realitykit/inputtargetcomponent)
- [Apple Developer - HoverEffectComponent](https://developer.apple.com/documentation/realitykit/hovereffectcomponent)
- [Apple Developer - TapGesture](https://developer.apple.com/documentation/swiftui/tapgesture)

---

## 6. entity 드래그 이동 처리하기

### 이 패턴으로 해결하는 문제

공간 안의 3D 오브젝트를 손으로 끌어 이동시키고 싶을 때 사용한다.

이 앱에서는 박스를 드래그하면 박스 root entity의 위치가 바뀐다. 드래그가 끝나면 그 위치를 SwiftData에 저장해서 다음 실행 때 복원할 수 있게 한다.

### 이 앱에서는 어떻게 구현했나?

`RealityView`에 targeted drag gesture를 붙인다.

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

이동 계산은 `moveBox(with:)`에서 한다.

```swift
let startPosition = sceneState.dragStartPositions[boxID] ?? boxRoot.position
sceneState.dragStartPositions[boxID] = startPosition

let movement = value.convert(value.translation3D, from: .global, to: .scene)
boxRoot.position = startPosition + movement
```

드래그가 끝나면 저장 모델에 좌표를 기록한다.

```swift
box.posX = position.x
box.posY = position.y
box.posZ = position.z
box.isAnchored = isAnchored

try modelContext.save()
```

파일:

- `DesktopOrganizer/Views/WorkspaceRealityView.swift`
- `DesktopOrganizer/Views/WorkspaceRealityState.swift`
- `DesktopOrganizer/Models/OrganizerBox.swift`

### 핵심 아이디어

드래그 gesture는 "이번 프레임에서 이만큼 움직였다"가 아니라 "처음 드래그한 지점에서 지금까지 이만큼 움직였다"는 translation을 준다.

그래서 드래그 시작 위치를 따로 저장해 둔다.

```text
드래그 시작 위치 + 현재 translation = 새 위치
```

또, 3D 공간 이동은 좌표계가 중요하다. 이 앱은 gesture의 `translation3D`를 scene 좌표로 변환해서 사용한다.

```swift
value.convert(value.translation3D, from: .global, to: .scene)
```

### 직접 만들어보는 최소 예제

```swift
@State private var dragStart: SIMD3<Float>?

DragGesture()
    .targetedToAnyEntity()
    .onChanged { value in
        let start = dragStart ?? value.entity.position
        dragStart = start

        let movement = value.convert(value.translation3D, from: .global, to: .scene)
        value.entity.position = start + movement
    }
    .onEnded { _ in
        dragStart = nil
    }
```

### 다른 방식으로도 가능한가?

가능하다.

- 오브젝트를 직접 드래그하지 않고, 별도 move handle을 붙일 수 있다.
- x축 또는 z축 이동만 허용할 수 있다.
- 사용자가 새 위치를 탭해서 순간 이동시키는 방식도 가능하다.
- physics를 사용해 잡고 놓는 느낌을 더 강하게 만들 수 있다.

### 언제 이 방식을 고르면 좋은가?

사용자가 공간 오브젝트를 직접 잡고 위치를 조정해야 한다면 targeted drag gesture가 좋다.

오브젝트 위치를 정확한 격자나 책상 위에만 제한해야 한다면, 드래그 결과를 그대로 쓰지 말고 보정 로직을 추가하는 것이 좋다.

### 공식문서 / 참고자료

- [Apple Developer - DragGesture](https://developer.apple.com/documentation/swiftui/draggesture)
- [Apple Developer - Entity](https://developer.apple.com/documentation/realitykit/entity)
- [Apple Developer - RealityView](https://developer.apple.com/documentation/realitykit/realityview)

---

## 7. 내장 3D animation 재생하기

### 이 패턴으로 해결하는 문제

USDZ나 Reality Composer Pro scene 안에 들어 있는 animation을 앱에서 재생하고 싶을 때 사용한다.

이 앱에서는 travel case 모델 안에 들어 있는 열림 animation을 사용한다. 박스를 탭하면 열리고, 다시 탭하면 닫힌다.

### 이 앱에서는 어떻게 구현했나?

먼저 entity와 그 자식들에서 사용할 수 있는 첫 animation을 찾는다.

```swift
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
```

박스를 열 때는 animation을 0초부터 끝까지 재생한다.

```swift
let controller = entity.playAnimation(animation, transitionDuration: 0, startsPaused: true)
let duration = max(controller.duration, 0.1)
controller.speed = 1
controller.time = 0
controller.resume()
```

animation이 끝나면 마지막 자세에서 멈춘다.

```swift
try? await Task.sleep(nanoseconds: nanoseconds)
controller.pause()
controller.time = duration
workspaceStore.setInteractionMode(mode, for: id)
```

닫을 때는 같은 animation을 뒤에서 앞으로 수동으로 되감는다.

```swift
for frame in stride(from: frameCount, through: 0, by: -1) {
    let progress = Double(frame) / Double(frameCount)
    controller.time = duration * progress
    try? await Task.sleep(nanoseconds: frameNanoseconds)
}

controller.pause()
controller.time = 0
workspaceStore.setInteractionMode(.closed, for: id)
```

파일:

- `DesktopOrganizer/Views/WorkspaceRealityView.swift`
- `DesktopOrganizer/Views/WorkspaceRealityState.swift`
- `docs/04-report/features/box-open-animation-implementation.md`

### 핵심 아이디어

3D asset 안에 animation이 이미 들어 있다면 Swift 코드에서 뚜껑 회전 각도를 직접 계산하지 않아도 된다.

이 앱의 특징은 닫기 animation을 별도로 갖고 있지 않다는 점이다. 그래서 같은 열림 animation의 `time`을 거꾸로 움직여 닫히는 것처럼 보여준다.

### 직접 만들어보는 최소 예제

```swift
if let animation = model.availableAnimations.first {
    let controller = model.playAnimation(animation, startsPaused: true)
    controller.time = 0
    controller.resume()
}
```

### 다른 방식으로도 가능한가?

가능하다.

- open animation과 close animation을 각각 따로 export할 수 있다.
- Swift 코드로 entity의 rotation, position, scale을 직접 바꿀 수 있다.
- Reality Composer Pro에서 상태별 scene이나 timeline을 구성할 수 있다.
- 단순한 UI 효과라면 3D animation 없이 SwiftUI attachment만 animate할 수도 있다.

### 언제 이 방식을 고르면 좋은가?

모델러나 asset pipeline에서 자연스러운 animation을 이미 만들어 둔 경우에는 내장 animation을 재생하는 방식이 좋다.

반대로 단순히 위아래로 떠오르거나 회전하는 정도라면 코드 animation이 더 간단할 수 있다.

### 공식문서 / 참고자료

- [Apple Developer - AnimationPlaybackController](https://developer.apple.com/documentation/realitykit/animationplaybackcontroller)
- [Apple Developer - AnimationResource](https://developer.apple.com/documentation/realitykit/animationresource)
- [Apple Developer - Entity](https://developer.apple.com/documentation/realitykit/entity)

---

## 8. entity 위에 목록 UI 붙이기

### 이 패턴으로 해결하는 문제

3D 오브젝트 위에 목록, 카드, 설정 패널 같은 SwiftUI UI를 띄우고 싶을 때 사용한다.

이 앱에서는 박스가 열리면 박스 위에 메모 목록이 나타난다. 이 목록도 3D 모델이 아니라 SwiftUI attachment다.

### 이 앱에서는 어떻게 구현했나?

각 박스마다 memo list attachment를 등록한다.

```swift
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
```

박스가 열림 상태일 때만 attachment를 박스에 붙인다.

```swift
guard workspaceStore.interactionMode(for: box.id) == .openForLookup,
      let boxRoot = sceneState.boxRoots[box.id],
      let memoList = attachments.entity(for: attachmentID)
else {
    attachments.entity(for: attachmentID)?.removeFromParent()
    continue
}
```

위치도 박스 기준으로 잡는다.

```swift
memoList.position = SIMD3<Float>(0, 0.34, 0)
```

파일:

- `DesktopOrganizer/Views/WorkspaceRealityView.swift`
- `DesktopOrganizer/Views/BoxMemoAttachmentView.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView+Attachments.swift`

### 핵심 아이디어

이 구조는 "박스가 열렸을 때만 박스 위에 붙는 작은 창"이다. 하지만 진짜 `WindowGroup` 창은 아니다.

정확한 구조는 이렇다.

```text
boxRoot Entity
├─ travelCase Entity
└─ BoxMemoAttachmentView Attachment
```

attachment를 `boxRoot`의 자식으로 붙였기 때문에, 박스를 이동하면 메모 목록도 같이 움직인다.

### 직접 만들어보는 최소 예제

```swift
Attachment(id: "list") {
    VStack {
        Text("아이템 목록")
        Button("추가") {}
    }
    .padding()
    .glassBackgroundEffect()
}
```

```swift
if isObjectOpen,
   let list = attachments.entity(for: "list") {
    objectRoot.addChild(list)
    list.position = SIMD3<Float>(0, 0.3, 0)
} else {
    attachments.entity(for: "list")?.removeFromParent()
}
```

### 다른 방식으로도 가능한가?

가능하다.

- 메모 목록을 별도 plain window로 열 수 있다.
- 항상 사용자 앞에 떠 있는 side panel로 만들 수 있다.
- 메모 카드 하나하나를 3D entity로 직접 만들 수 있다.
- 목록을 박스 위가 아니라 조작 패널에 표시할 수 있다.

### 언제 이 방식을 고르면 좋은가?

목록 UI가 특정 3D 오브젝트에 붙어 있어야 한다면 attachment 방식이 좋다.

목록이 길고 복잡하거나 키보드 입력이 많다면 별도 window가 더 편할 수 있다.

### 공식문서 / 참고자료

- [Apple Developer - RealityView](https://developer.apple.com/documentation/realitykit/realityview)
- [Apple Developer - SwiftUI View](https://developer.apple.com/documentation/swiftui/view)
- [Apple Developer - LazyVGrid](https://developer.apple.com/documentation/swiftui/lazyvgrid)

---

## 9. 박스 안에서 메모 생성하기

### 이 패턴으로 해결하는 문제

3D 오브젝트에 붙은 UI 안에서 사용자가 데이터를 만들고, 그 데이터를 저장소에 남기고 싶을 때 사용한다.

이 앱에서는 박스 위 메모 목록 attachment 안에서 메모를 입력하고 저장한다.

### 이 앱에서는 어떻게 구현했나?

`BoxMemoAttachmentView`는 입력 중인 텍스트와 색상 인덱스를 `@State`로 들고 있다.

```swift
@State private var draftMemoText = ""
@State private var draftColorIndex = 0
```

작성 UI는 `TextEditor`와 색상 버튼으로 구성된다.

```swift
TextEditor(text: $draftMemoText)
    .frame(height: 74)
```

```swift
ForEach(MemoPalette.colors.indices, id: \.self) { index in
    ColorButton(
        color: MemoPalette.colors[index],
        isSelected: draftColorIndex == index
    ) {
        draftColorIndex = index
    }
}
```

저장 버튼을 누르면 부모가 넘겨준 closure를 호출한다.

```swift
Button("저장") {
    onMemoCreated(draftMemoText, draftColorIndex)
    isCreatingMemo = false
    clearDraft()
}
```

실제 SwiftData 저장은 `WorkspaceRealityView`에서 한다.

```swift
let memo = MemoItem(
    text: trimmed,
    colorIndex: colorIndex,
    containerBoxID: boxID
)
modelContext.insert(memo)
try modelContext.save()
```

파일:

- `DesktopOrganizer/Views/BoxMemoAttachmentView.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView+Memos.swift`
- `DesktopOrganizer/Models/MemoItem.swift`
- `DesktopOrganizer/Models/MemoPalette.swift`
- `DesktopOrganizer/Views/ColorButton.swift`

### 핵심 아이디어

입력 중인 값과 저장된 값은 다르다.

- `draftMemoText`: 아직 저장 전인 임시 입력값
- `MemoItem`: 저장소에 들어간 실제 메모

또, 메모가 어느 박스 안에 들어 있는지는 `containerBoxID`로 연결한다.

```swift
containerBoxID: boxID
```

메모에 "나는 이 박스에 들어 있어요"라고 박스 ID 스티커를 붙이는 구조라고 보면 된다.

### 직접 만들어보는 최소 예제

```swift
struct NoteComposer: View {
    @State private var text = ""
    let onSave: (String) -> Void

    var body: some View {
        VStack {
            TextEditor(text: $text)
            Button("저장") {
                onSave(text)
                text = ""
            }
        }
    }
}
```

### 다른 방식으로도 가능한가?

가능하다.

- 메모 작성만 별도 sheet나 window에서 처리할 수 있다.
- 메모를 저장하지 않고 앱 실행 중 메모리 상태로만 관리할 수 있다.
- `containerBoxID` 대신 SwiftData relationship을 사용할 수 있다.
- 색상을 index가 아니라 enum이나 hex string으로 저장할 수 있다.

### 언제 이 방식을 고르면 좋은가?

작은 입력 UI를 공간 오브젝트 가까이에 붙이고 싶다면 attachment 안에서 바로 작성하는 방식이 좋다.

입력 폼이 길거나 복잡하다면 별도 window나 sheet가 더 적합하다.

### 공식문서 / 참고자료

- [Apple Developer - TextEditor](https://developer.apple.com/documentation/swiftui/texteditor)
- [Apple Developer - SwiftData](https://developer.apple.com/documentation/swiftdata)
- [Apple Developer - ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext)
- [Apple Developer - @State](https://developer.apple.com/documentation/swiftui/state)

---

## 10. 드래그앤드롭으로 메모를 공간에 열기

### 이 패턴으로 해결하는 문제

목록 안에 있는 카드를 "밖으로 꺼내서" 공간 오브젝트처럼 펼치고 싶을 때 사용한다.

이 앱에서는 박스 안 메모 카드를 밖으로 드래그하면, 일정 거리 이상에서 공간 메모로 열린다.

### 이 앱에서는 어떻게 구현했나?

메모 카드마다 drag gesture를 붙인다.

```swift
.highPriorityGesture(memoDragGesture(for: memo))
```

gesture가 바뀔 때는 드래그 중인 메모와 이동 거리를 부모에게 알려준다.

```swift
DragGesture(minimumDistance: 8)
    .onChanged { value in
        guard !isSelectingMemos else {
            return
        }

        draggingMemoID = memo.id
        draggingMemoTranslation = value.translation
        onMemoDragChanged(memo, value.translation)
    }
```

gesture가 끝나면 부모에게 최종 translation을 전달한다.

```swift
.onEnded { value in
    onMemoDragEnded(memo, value.translation)
    clearDragState()
}
```

부모인 `WorkspaceRealityView`는 드래그 중 preview attachment를 업데이트한다.

```swift
draggingMemoPreview = DraggingMemoPreview(
    boxID: boxID,
    text: memo.text,
    colorIndex: memo.colorIndex,
    cornerRadius: memo.cornerRadius,
    translation: translation
)
```

드래그가 끝나면 거리를 계산한다.

```swift
let shouldOpen = dragDistance(translation) >= memoDragActivationDistance
```

기준 거리 이상이면 메모를 공간에 열린 상태로 바꾼다.

```swift
memo.isSpatiallyPresented = true
memo.spatialBoxID = boxID
memo.spatialPosX = position.x
memo.spatialPosY = position.y
memo.spatialPosZ = position.z
memo.isSpatiallyAnchored = false
memo.spatialWorldAnchorIdentifier = nil

upsertSpatialMemoPresentation(for: memo)
saveSpatialMemoState(statusText: "메모를 공간에 펼침")
```

파일:

- `DesktopOrganizer/Views/BoxMemoAttachmentView.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView+Memos.swift`
- `DesktopOrganizer/Views/WorkspaceRealityState.swift`
- `DesktopOrganizer/Models/MemoItem.swift`

### 핵심 아이디어

이 앱의 drag and drop은 시스템 `DropDelegate`로 파일을 드롭하는 방식이 아니다. 직접 gesture 거리를 계산해서 "충분히 밖으로 끌었다"고 판단하는 방식이다.

흐름은 이렇다.

```text
메모 카드 drag 시작
-> draggingMemoID 저장
-> translation 계속 전달
-> preview attachment 표시
-> drag 종료
-> dragDistance가 72pt 이상인지 확인
-> true이면 MemoItem.isSpatiallyPresented = true
-> SpatialMemoPresentation 생성
-> 공간 메모 attachment를 rootEntity에 붙임
```

`memoDragActivationDistance`는 꺼내기 기준 거리다.

```swift
private let memoDragActivationDistance: CGFloat = 72
```

2D drag translation을 3D 위치로 바꾸는 함수도 따로 있다.

```swift
private func spatialMemoPosition(for translation: CGSize) -> SIMD3<Float> {
    SIMD3<Float>(
        Float(translation.width) * memoDragMetersPerPoint,
        0.34 - Float(translation.height) * memoDragMetersPerPoint,
        0.03
    )
}
```

여기서 `memoDragMetersPerPoint`는 화면 drag point를 공간 meter로 바꾸는 비율이다.

조금 더 쉽게 풀면, SwiftUI의 `DragGesture`는 "손이 화면에서 몇 point 움직였는지"를 알려준다. 하지만 RealityKit 공간에서는 박스와 메모가 meter에 가까운 3D 좌표로 배치된다.

그래서 바로 이 값을 쓸 수 없다.

```text
SwiftUI drag translation
예: width 120pt, height 40pt

RealityKit position
예: x 0.12m, y 0.30m, z -0.8m
```

이 앱은 아주 단순한 변환 비율을 둔다.

```swift
let memoDragMetersPerPoint: Float = 0.001
```

그래서 100pt를 끌면 공간에서는 약 0.1m 움직인 것으로 계산한다.

```text
100pt * 0.001 = 0.1
```

y축은 부호가 반대다.

SwiftUI에서는 아래로 끌면 `translation.height`가 양수로 커진다. 하지만 3D 공간에서는 보통 위쪽이 +y다. 그래서 아래로 끌 때 공간 메모가 아래로 내려가게 하려면 `height` 앞에 `-`를 붙인다.

```swift
-Float(translation.height) * memoDragMetersPerPoint
```

이 패턴을 기억하면 된다.

```text
화면 drag 값
-> 작게 줄인다
-> x는 그대로 사용한다
-> y는 부호를 반대로 한다
-> 필요하면 기준 위치를 더한다
```

이미 공간에 열린 메모를 다시 열지 않는 처리도 중요하다.

박스 목록에는 같은 메모가 계속 보인다. 사용자는 "이 메모가 박스 안에 있구나"를 확인할 수 있다. 하지만 이미 공간에 열린 메모를 다시 탭하거나 드래그해서 또 열면 같은 `MemoItem`을 두 번 펼치는 문제가 생긴다.

그래서 이 앱은 이미 열린 메모를 목록에 남기되, 상태만 표시하고 다시 열기는 막는다.

```swift
if isSelectingMemos {
    toggleSelection(for: memo.id)
} else if memo.isSpatiallyPresented {
    return
} else {
    onMemoSelected(memo)
}
```

카드에는 "공간에 열림" 상태를 보여준다.

```swift
if isOpenedInSpace {
    return "공간에 열림"
}
```

이 방식은 사용자가 현재 상태를 이해하기 쉽고, 앱 내부 데이터도 안전하다.

### 직접 만들어보는 최소 예제

```swift
let activationDistance: CGFloat = 80

func dragDistance(_ translation: CGSize) -> CGFloat {
    sqrt((translation.width * translation.width) + (translation.height * translation.height))
}
```

```swift
DragGesture(minimumDistance: 8)
    .onChanged { value in
        previewOffset = value.translation
    }
    .onEnded { value in
        if dragDistance(value.translation) >= activationDistance {
            openCardInSpace()
        }
        previewOffset = .zero
    }
```

### 다른 방식으로도 가능한가?

가능하다.

- SwiftUI의 정식 drag and drop API를 사용할 수 있다.
- 메모를 탭하면 바로 공간에 열리게 할 수 있다.
- 카드 옆에 "공간에 열기" 버튼을 둘 수 있다.
- 드래그 거리가 아니라 특정 drop zone에 들어갔는지를 기준으로 열 수 있다.
- 3D raycast나 collision을 이용해 실제 박스 밖으로 나온 위치를 계산할 수 있다.

### 언제 이 방식을 고르면 좋은가?

카드를 "꺼낸다"는 감각이 중요하고, 복잡한 drop target이 필요 없다면 이 앱처럼 gesture 거리 기반으로 구현하는 방식이 단순하고 좋다.

정확한 드롭 위치, 여러 drop target, 파일/텍스트 교환이 중요하다면 시스템 drag and drop API나 별도 drop zone을 고려하는 것이 좋다.

### 공식문서 / 참고자료

- [Apple Developer - DragGesture](https://developer.apple.com/documentation/swiftui/draggesture)
- [Apple Developer - SwiftUI gestures](https://developer.apple.com/documentation/swiftui/gestures)
- [Apple Developer - RealityView](https://developer.apple.com/documentation/realitykit/realityview)

---

## 11. SwiftUI 카드 UI를 공간 오브젝트처럼 다루기

### 이 패턴으로 해결하는 문제

SwiftUI로 만든 카드 UI를 3D 공간 안에 독립적인 오브젝트처럼 띄우고 싶을 때 사용한다.

이 앱에서는 박스 안 메모를 꺼내면 `SpatialMemoOpenedAttachment`가 공간에 떠 있는 카드처럼 나타난다.

### 이 앱에서는 어떻게 구현했나?

공간에 열린 메모는 SwiftData 모델인 `MemoItem`을 그대로 entity로 쓰지 않는다. 먼저 화면 표시용 상태인 `SpatialMemoPresentation`으로 바꾼다.

```swift
struct SpatialMemoPresentation: Identifiable, Equatable {
    let id: UUID
    let boxID: UUID
    let text: String
    let colorIndex: Int
    let cornerRadius: Double
    var position: SIMD3<Float>
    var isAnchored = false
}
```

그리고 각 presentation마다 attachment를 만든다.

```swift
ForEach(spatialMemoPresentations) { presentation in
    Attachment(id: spatialMemoAttachmentID(for: presentation.id)) {
        SpatialMemoOpenedAttachment(
            title: presentation.title,
            text: presentation.text,
            colorIndex: presentation.colorIndex,
            cornerRadius: presentation.cornerRadius,
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
```

attachment entity는 root entity에 직접 붙인다.

```swift
if memoEntity.parent !== rootEntity {
    memoEntity.removeFromParent()
    memoEntity.name = spatialMemoAttachmentID(for: presentation.id)
    rootEntity.addChild(memoEntity)
}

configureOpenedMemoEntity(memoEntity)
memoEntity.position = presentation.position
```

파일:

- `DesktopOrganizer/Views/WorkspaceRealityState.swift`
- `DesktopOrganizer/Views/SpatialMemoAttachmentViews.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView+Attachments.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView+Geometry.swift`

### 핵심 아이디어

박스 위 메모 목록은 박스의 자식이다. 반면 공간으로 꺼낸 메모는 root entity의 자식이다.

```text
WorkspaceRoot
├─ WorkspaceBox:{UUID}
│  └─ BoxMemoList attachment
└─ SpatialMemo:{UUID} attachment
```

이렇게 하면 공간 메모가 박스와 독립적으로 움직일 수 있다.

### attachment entity란?

`attachment entity`는 SwiftUI View를 RealityKit 공간 안에 배치할 수 있게 꺼낸 entity다.

흐름은 아래와 같다.

```text
SwiftUI View
-> Attachment(id:)
-> attachments.entity(for:)
-> RealityKit Entity
-> rootEntity.addChild(...) 또는 boxRoot.addChild(...)
```

예를 들어 `SpatialMemoOpenedAttachment`는 처음에는 SwiftUI View다.

```swift
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
```

이 SwiftUI View를 `Attachment`로 등록한다.

```swift
Attachment(id: spatialMemoAttachmentID(for: presentation.id)) {
    SpatialMemoOpenedAttachment(...)
}
```

그 다음 `RealityView`의 update 쪽에서 `attachments.entity(for:)`로 꺼낸다.

```swift
guard let memoEntity = attachments.entity(
    for: spatialMemoAttachmentID(for: presentation.id)
) else {
    continue
}
```

여기서부터 `memoEntity`는 RealityKit scene graph에 붙일 수 있는 entity처럼 다룰 수 있다.

```swift
rootEntity.addChild(memoEntity)
memoEntity.position = presentation.position
```

이 앱에서 attachment entity로 쓰는 SwiftUI View는 아래와 같다.

- `BoxControlAttachmentView`: 박스 아래 삭제/pin 버튼
- `BoxMemoAttachmentView`: 박스 위 메모 목록
- `SpatialMemoPreviewAttachment`: 드래그 중 미리보기 카드
- `SpatialMemoOpenedAttachment`: 공간에 열린 메모 카드

이 방식을 쓰면 UI는 SwiftUI로 빠르게 만들고, 공간 배치는 RealityKit entity처럼 처리할 수 있다. 그래서 위치 설정, 부모-자식 관계, `BillboardComponent`, `InputTargetComponent`, `HoverEffectComponent`, WorldAnchor 연결 같은 공간 기능을 함께 사용할 수 있다.

정리하면 아래와 같다.

```text
메모 UI 자체는 SwiftUI
공간 배치 대상은 attachment entity
```

### BillboardComponent란?

`BillboardComponent`는 entity가 사용자를 향하도록 방향을 보정해주는 RealityKit 컴포넌트다.

공간 메모는 SwiftUI 카드처럼 납작한 UI다. 사용자가 옆으로 이동하면 카드가 비스듬히 보이거나 읽기 어려워질 수 있다. 메모는 감상용 3D 물체가 아니라 읽어야 하는 카드이므로, 가능한 한 사용자를 향하는 편이 좋다.

또, 메모가 사용자를 향하도록 `BillboardComponent`를 붙인다.

```swift
private func configureMemoBillboard(_ entity: Entity) {
    var billboard = BillboardComponent()
    billboard.blendFactor = 0.75
    entity.components.set(billboard)
}
```

`blendFactor`는 billboard 효과를 얼마나 강하게 줄지 정하는 값이다.

```text
0.0  -> 원래 entity 방향을 거의 유지
1.0  -> 완전히 사용자를 향하게 회전
0.75 -> 대부분 사용자를 향하지만 약간 자연스럽게 유지
```

이 앱에서는 공간 메모 entity를 설정할 때 billboard, input target, hover effect를 함께 붙인다.

```swift
func configureOpenedMemoEntity(_ entity: Entity) {
    configureMemoBillboard(entity)
    entity.components.set(InputTargetComponent())
    entity.components.set(HoverEffectComponent())
}
```

세 컴포넌트의 역할은 아래와 같다.

```text
BillboardComponent     -> 사용자를 향하게 함
InputTargetComponent   -> 입력/gesture 대상이 되게 함
HoverEffectComponent   -> 바라보거나 hover할 때 반응하게 함
```

`BillboardComponent`는 메모, 이름표, 툴팁, 말풍선, 상태 라벨처럼 항상 읽기 쉬워야 하는 2D성 UI에 잘 맞는다. 반대로 조각상이나 가구처럼 방향 자체가 의미 있는 3D 물체에는 조심해서 써야 한다.

### 직접 만들어보는 최소 예제

```swift
struct FloatingCard: View {
    let text: String

    var body: some View {
        Text(text)
            .padding()
            .background(.yellow, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

```swift
Attachment(id: "floating-card") {
    FloatingCard(text: "공간 카드")
}
```

```swift
if let card = attachments.entity(for: "floating-card") {
    rootEntity.addChild(card)
    card.position = SIMD3<Float>(0, 1.2, -1.0)

    var billboard = BillboardComponent()
    billboard.blendFactor = 0.75
    card.components.set(billboard)
}
```

### 다른 방식으로도 가능한가?

가능하다.

- 메모 카드를 별도 plain window로 열 수 있다.
- SwiftUI attachment 대신 3D plane mesh에 텍스트 texture를 입힐 수 있다.
- 모든 메모를 하나의 큰 board attachment 안에서 관리할 수 있다.
- 메모 카드가 항상 사용자 앞에 따라오도록 위치를 head pose 기준으로 계산할 수 있다.

### 언제 이 방식을 고르면 좋은가?

카드 UI는 SwiftUI로 빠르게 만들고 싶고, 위치는 RealityKit 공간 안에서 직접 관리하고 싶다면 attachment 방식이 좋다.

텍스트가 수백 개이거나 성능이 중요하면 3D mesh/texture 기반 방식을 따로 검토하는 것이 좋다.

### 공식문서 / 참고자료

- [Apple Developer - RealityView](https://developer.apple.com/documentation/realitykit/realityview)
- [Apple Developer - BillboardComponent](https://developer.apple.com/documentation/realitykit/billboardcomponent)
- [Apple Developer - Entity](https://developer.apple.com/documentation/realitykit/entity)

---

## 12. 공간 오브젝트 닫기, 삭제, 이동하기

### 이 패턴으로 해결하는 문제

공간에 열린 SwiftUI attachment를 사용자가 닫거나, 완전히 삭제하거나, 위치를 옮기게 만들고 싶을 때 사용한다.

이 앱에서는 공간 메모에 닫기, 삭제, pin 버튼과 drag gesture가 붙어 있다.

### 이 앱에서는 어떻게 구현했나?

공간 메모 UI는 카드와 조작 바로 나뉜다.

```swift
VStack(spacing: 8) {
    SpatialMemoCard(...)

    SpatialMemoControlBar(
        title: title,
        isAnchored: isAnchored,
        onClose: onClose,
        onDelete: onDelete,
        onToggleAnchor: onToggleAnchor
    )
}
```

이 앱에서 닫기는 "잠깐 숨김"이 아니라 "공간에서 접어서 박스 안 메모로 되돌리기"다.

그래서 닫기를 누르면 presentation을 제거하고, 공간 고정 상태도 같이 해제한다. 하지만 MemoItem 자체는 남긴다.

```swift
spatialMemoPresentations.removeAll { $0.id == id }
memo.isSpatiallyPresented = false
memo.spatialBoxID = nil
memo.isSpatiallyAnchored = false
memo.spatialWorldAnchorIdentifier = nil
saveSpatialMemoState(statusText: "공간 메모 닫힘")
```

삭제는 SwiftData 모델 자체를 삭제한다.

```swift
spatialMemoPresentations.removeAll { $0.id == presentation.id }
modelContext.delete(memo)
try modelContext.save()
```

이동은 drag translation을 meter 단위의 위치 변화로 바꾼다.

```swift
presentation.position = startPosition + spatialMemoMovement(for: translation)
```

이동이 끝나면 저장 모델 좌표를 갱신한다.

```swift
memo.spatialPosX = presentation.position.x
memo.spatialPosY = presentation.position.y
memo.spatialPosZ = presentation.position.z
saveSpatialMemoState(statusText: "공간 메모 위치 저장됨")
```

파일:

- `DesktopOrganizer/Views/SpatialMemoAttachmentViews.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView+Memos.swift`
- `DesktopOrganizer/Models/MemoItem.swift`

### 핵심 아이디어

닫기와 삭제는 다르다.

- 닫기: 공간에서 접는다. 메모 데이터는 박스 안에 남고, pin은 해제된다.
- 삭제: 메모 데이터 자체를 지운다.

이 차이를 저장 모델의 상태값으로 표현한다.

```swift
memo.isSpatiallyPresented = false
```

이동도 마찬가지로 화면 상태와 저장 상태를 나눠서 생각한다.

- 드래그 중: `SpatialMemoPresentation.position`
- 드래그 종료 후: `MemoItem.spatialPosX/Y/Z`

### 직접 만들어보는 최소 예제

```swift
Button("닫기") {
    openedCards.removeAll { $0.id == card.id }
}

Button("삭제") {
    openedCards.removeAll { $0.id == card.id }
    modelContext.delete(cardModel)
    try? modelContext.save()
}
```

### 다른 방식으로도 가능한가?

가능하다.

- 닫기와 삭제를 하나로 합칠 수 있다.
- 닫은 메모를 박스 안 목록에서 숨기지 않고 그대로 유지할 수 있다.
- 공간 메모를 여러 개 열지 못하게 하고 하나만 열 수 있게 제한할 수 있다.
- 이동은 drag 대신 pinching handle이나 별도 move mode로 만들 수 있다.

### 언제 이 방식을 고르면 좋은가?

사용자가 "잠깐 닫기"와 "완전히 삭제"를 구분해야 한다면 이 방식이 좋다.

반대로 앱이 단순한 포스트잇 앱이라면 닫기 없이 삭제만 제공해도 된다.

### 공식문서 / 참고자료

- [Apple Developer - SwiftData](https://developer.apple.com/documentation/swiftdata)
- [Apple Developer - DragGesture](https://developer.apple.com/documentation/swiftui/draggesture)
- [Apple Developer - Button](https://developer.apple.com/documentation/swiftui/button)

---

## 13. 공간 오브젝트 위치 저장하기

### 이 패턴으로 해결하는 문제

앱을 껐다 켜도 박스나 메모가 이전 위치에 다시 나타나게 하고 싶을 때 사용한다.

이 앱은 SwiftData 모델에 위치 좌표와 열림 상태를 저장한다.

### 이 앱에서는 어떻게 구현했나?

박스 위치는 `OrganizerBox`에 저장한다.

```swift
var posX: Float = 0
var posY: Float = 1.0
var posZ: Float = -1.0
var isAnchored: Bool = false
var worldAnchorIdentifier: String?
```

메모 위치는 `MemoItem`에 저장한다.

```swift
var isSpatiallyPresented: Bool = false
var spatialBoxID: UUID?
var spatialPosX: Float = 0
var spatialPosY: Float = 0
var spatialPosZ: Float = 0
var isSpatiallyAnchored: Bool = false
var spatialWorldAnchorIdentifier: String?
```

저장된 박스는 `@Query`로 다시 읽는다.

```swift
@Query(sort: \OrganizerBox.createdAt) private var persistedBoxes: [OrganizerBox]
```

그리고 `renderKnownBoxes()`가 저장된 박스를 다시 렌더링한다.

```swift
for box in persistedBoxes where !sceneState.renderedBoxIDs.contains(box.id) {
    await renderBox(
        id: box.id,
        name: box.name,
        position: workspacePosition(for: box),
        in: rootEntity
    )
}
```

공간 메모도 저장 상태를 보고 복원한다.

```swift
let restored = memos.compactMap { memo -> SpatialMemoPresentation? in
    guard memo.isSpatiallyPresented,
          let boxID = memo.spatialBoxID,
          validBoxIDs.contains(boxID)
    else {
        return nil
    }

    return spatialMemoPresentation(for: memo, boxID: boxID)
}

spatialMemoPresentations = restored
```

파일:

- `DesktopOrganizer/Models/OrganizerBox.swift`
- `DesktopOrganizer/Models/MemoItem.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView.swift`

### 핵심 아이디어

RealityKit entity 자체는 저장하지 않는다. entity는 실행 중에만 존재하는 화면 물체다.

저장하는 것은 entity를 다시 만들 수 있는 재료다.

```text
저장하는 것:
- id
- 이름
- 좌표
- 열림 상태
- 어느 박스에 속하는지
- anchor id

저장하지 않는 것:
- Entity 객체 자체
- AnimationPlaybackController
- 현재 drag gesture 상태
```

### 직접 만들어보는 최소 예제

```swift
@Model
final class SpatialObject {
    @Attribute(.unique) var id: UUID
    var name: String
    var x: Float
    var y: Float
    var z: Float

    init(name: String, position: SIMD3<Float>) {
        self.id = UUID()
        self.name = name
        self.x = position.x
        self.y = position.y
        self.z = position.z
    }
}
```

### 다른 방식으로도 가능한가?

가능하다.

- 간단한 앱이면 `UserDefaults`에 좌표만 저장할 수 있다.
- JSON 파일로 저장할 수 있다.
- Core Data를 사용할 수 있다.
- CloudKit으로 여러 기기 간 동기화할 수 있다.
- 서버 DB에 저장해 협업 공간을 만들 수 있다.

### 언제 이 방식을 고르면 좋은가?

앱 안에서 여러 종류의 데이터가 계속 늘어나고, `@Query`로 UI와 자동 연결하고 싶다면 SwiftData가 좋다.

단순 설정값 한두 개만 저장한다면 `UserDefaults`가 더 가볍다.

### 공식문서 / 참고자료

- [Apple Developer - SwiftData](https://developer.apple.com/documentation/swiftdata)
- [Apple Developer - @Model](https://developer.apple.com/documentation/swiftdata/model)
- [Apple Developer - Query](https://developer.apple.com/documentation/swiftdata/query)
- [Apple Developer - UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults)

---

## 14. 실제 공간에 고정하기

### 이 패턴으로 해결하는 문제

앱 안 좌표만 저장하면 다음 실행 때 비슷한 위치에 다시 만들 수는 있지만, 실제 방 안의 같은 지점에 강하게 고정된다고 보장하기 어렵다.

실제 공간의 특정 위치에 오브젝트를 고정하려면 ARKit의 world tracking과 anchor 개념이 필요하다.

이 앱에서는 박스와 공간 메모에 pin 버튼을 제공하고, 가능하면 `WorldAnchor`를 만든다.

### 이 앱에서는 어떻게 구현했나?

`PlaneDetectionService`는 `WorldTrackingProvider`를 갖고 있다.

```swift
private var worldTracking = WorldTrackingProvider()
private var worldAnchorsByObjectID: [UUID: WorldAnchor] = [:]
private var worldAnchorTransformsByID: [UUID: simd_float4x4] = [:]
```

공간 인식을 시작할 때 world tracking도 같이 실행한다.

```swift
if WorldTrackingProvider.isSupported {
    try await arkitSession.run([planeDetection, worldTracking])
    startWorldAnchorUpdatesIfNeeded()
} else {
    try await arkitSession.run([planeDetection])
}
```

pin을 켜면 현재 entity transform으로 WorldAnchor를 만든다.

```swift
let transform = boxRoot.transformMatrix(relativeTo: nil)
let anchorID = try await planeService.addWorldAnchor(for: boxID, transform: transform)
box.worldAnchorIdentifier = anchorID.uuidString
try modelContext.save()
```

여기서 중요한 점은 순서다.

```text
1. ARKit에 WorldAnchor를 만든다
2. SwiftData에 anchor id를 저장한다
```

이 순서는 자연스럽다. 실제 anchor를 만들어야 id를 알 수 있기 때문이다.

하지만 이 순서에는 위험도 있다. 1번은 성공했는데 2번 저장이 실패하면 어떻게 될까?

```text
ARKit에는 anchor가 생김
SwiftData에는 anchor id가 저장되지 않음
앱은 나중에 그 anchor를 찾거나 지우기 어려움
```

이런 상태를 고아 anchor라고 생각하면 된다. 그래서 이 앱은 저장 실패 시 방금 만든 anchor를 다시 제거한다.

```swift
let previousAnchorIdentifier = box.worldAnchorIdentifier
let anchorID = try await planeService.addWorldAnchor(
    forObjectID: boxID,
    replacingAnchorIdentifier: box.worldAnchorIdentifier,
    transform: transform
)
box.worldAnchorIdentifier = anchorID.uuidString

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

쉽게 말하면:

```text
고정핀 꽂기 성공
-> 기록장에 번호 쓰기 실패
-> 방금 꽂은 고정핀을 다시 뽑기
```

이런 코드를 보상 처리라고 부를 수 있다. ARKit 같은 외부 시스템 상태와 SwiftData 같은 앱 저장 상태를 함께 바꿀 때는, 중간에 실패했을 때 되돌리는 처리가 중요하다.

WorldAnchor 생성은 service가 담당한다.

```swift
let anchor = WorldAnchor(originFromAnchorTransform: transform)
try await worldTracking.addAnchor(anchor)
worldAnchorsByObjectID[objectID] = anchor
worldAnchorTransformsByID[anchor.id] = anchor.originFromAnchorTransform
worldAnchorRevision += 1
```

나중에 transform cache가 있으면 저장 좌표보다 WorldAnchor 위치를 우선 사용한다.

```swift
private func workspacePosition(for box: OrganizerBox) -> SIMD3<Float> {
    worldAnchorPosition(for: box) ?? SIMD3<Float>(box.posX, box.posY, box.posZ)
}
```

현재 앱은 WorldAnchor의 transform 전체를 복원하지 않고, 위치 성분만 꺼내 쓴다.

```swift
let position = transform.columns.3
return SIMD3<Float>(position.x, position.y, position.z)
```

왜 이렇게 했을까?

현재 앱에는 사용자가 박스나 메모를 회전시키는 기능이 없다. 그리고 공간 메모는 `BillboardComponent`가 붙어서 사용자를 향하도록 방향을 보정한다. 그래서 지금 단계에서는 "어느 방향을 보고 있었는가"보다 "어디에 있었는가"가 더 중요하다.

정리하면 현재 정책은 이렇다.

```text
WorldAnchor 전체 pose 저장
-> 복원할 때는 position 중심으로 사용
-> 회전 복원은 추후 회전 기능이 생기면 별도 검토
```

만약 회전이 중요한 앱이라면 다르게 해야 한다. 예를 들어 그림 액자, 3D 조형물, 방향이 중요한 도구라면 `transform.columns.3`만 꺼내지 말고 matrix 전체를 entity transform에 적용하는 방식을 검토해야 한다.

공간을 닫을 때는 WorldAnchor transform cache도 비운다.

```swift
worldAnchorsByObjectID.removeAll()
worldAnchorTransformsByID.removeAll()
worldAnchorRevision += 1
```

이 cache는 "방금 알고 있던 anchor 위치 메모장"에 가깝다. 공간을 닫고 provider를 새로 만들면, 예전 메모장을 계속 들고 있는 것보다 다음 시작 때 다시 읽는 편이 안전하다.

파일:

- `DesktopOrganizer/Services/PlaneDetectionService.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView.swift`
- `DesktopOrganizer/Models/OrganizerBox.swift`
- `DesktopOrganizer/Models/MemoItem.swift`

### 핵심 아이디어

좌표 저장과 WorldAnchor는 다르다.

```text
좌표 저장:
앱 안의 root 기준 위치를 숫자로 저장한다.

WorldAnchor:
ARKit이 이해하는 실제 공간 기준점을 저장한다.
```

Simulator나 일부 환경에서는 WorldAnchor를 지원하지 않을 수 있다. 그래서 이 앱은 실패하면 crash하지 않고 임시 고정 fallback을 쓴다.

```swift
if nextState, isWorldAnchorUnavailable(error) {
    applyTemporaryAnchorFallback(for: boxID)
    return
}
```

### 직접 만들어보는 최소 예제

```swift
let transform = entity.transformMatrix(relativeTo: nil)
let anchor = WorldAnchor(originFromAnchorTransform: transform)
try await worldTracking.addAnchor(anchor)
```

### 다른 방식으로도 가능한가?

가능하다.

- WorldAnchor 없이 앱 실행 중 위치만 유지할 수 있다.
- SwiftData에 좌표만 저장하고 다음 실행 때 대략적인 위치에 복원할 수 있다.
- 사용자가 매번 직접 위치를 다시 배치하게 할 수 있다.
- 특정 평면 위에만 스냅되도록 plane detection 결과를 계속 사용할 수 있다.

### 언제 이 방식을 고르면 좋은가?

물체가 실제 책상 위, 벽 앞, 방 안 특정 위치에 남아 있어야 한다면 WorldAnchor를 고려해야 한다.

단순 데모나 Simulator 중심 테스트라면 좌표 저장만으로도 충분할 수 있다.

### 공식문서 / 참고자료

- [Apple Developer - WorldAnchor](https://developer.apple.com/documentation/arkit/worldanchor)
- [Apple Developer - WorldTrackingProvider](https://developer.apple.com/documentation/arkit/worldtrackingprovider)
- [Apple Developer - ARKitSession](https://developer.apple.com/documentation/arkit/arkitsession)
- [Apple Developer - Tracking points in world space](https://developer.apple.com/documentation/visionos/tracking-points-in-world-space)
