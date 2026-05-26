# 05. Attachment vs Ornament vs Window

Last updated: 2026-05-25

이 교재는 Desktop Organizer를 통해 visionOS의 세 가지 UI 배치 방식을 비교하기 위한 다섯 번째 교재다. 목표는 SwiftUI `WindowGroup`, SwiftUI `ornament`, RealityKit `Attachment`가 각각 어디에 붙고, 언제 어떤 방식을 선택해야 하는지 이해하는 것이다.

## 1. 이 주제를 배우는 이유

Desktop Organizer를 만들면서 실제로 부딪힌 문제가 있었다.

박스를 클릭했을 때 메모 목록 창을 띄울 수는 있었지만, 박스를 움직이면 그 창은 박스를 따라오지 않았다.

이 문제의 핵심은 UI가 "어디에 소속되어 있는가"였다.

- 독립적인 앱 창이면 사용자가 움직이는 window에 소속된다.
- ornament이면 SwiftUI window나 scene 주변에 소속된다.
- RealityKit attachment이면 RealityKit entity 또는 scene graph에 소속된다.

박스 위에 붙어야 하는 UI라면 window보다 attachment가 맞다.

## 2. 세 개념의 한 줄 비교

| 구분 | Window | Ornament | RealityKit Attachment |
| --- | --- | --- | --- |
| 붙는 대상 | 시스템이 관리하는 독립 창 | SwiftUI window/view/scene 주변 | RealityKit scene graph |
| 대표 API | `WindowGroup` | `.ornament(...)` | `RealityView`의 `Attachment(id:)` |
| 이동 기준 | 사용자가 창을 따로 배치 | 창 또는 scene 주변 위치 | 부모 entity의 transform |
| RealityKit entity처럼 다룰 수 있나 | 아니오 | 아니오 | 예 |
| 박스를 따라 움직이나 | 아니오 | 보통 아니오 | 부모를 박스로 두면 예 |
| 이 앱에서 쓰는 곳 | 기본 ControlPanel | 현재는 직접 사용 안 함 | 박스 컨트롤, 메모 목록, 공간 메모 |

## 3. WindowGroup은 독립 창이다

`WindowGroup`은 앱의 독립적인 SwiftUI 창을 만든다.

```swift
WindowGroup {
    ControlPanelView()
}
.windowResizability(.contentSize)
.defaultSize(width: 360, height: 260)
```

Desktop Organizer에서 `ControlPanelView`는 window에 적합하다.

이유는 다음과 같다.

- 사용자가 앱을 조작하는 기본 패널이다.
- 특정 박스 하나에 붙어 있을 필요가 없다.
- 공간 시작/종료, 책상 다시 인식, 박스 생성 같은 전역 조작을 담당한다.

즉, window는 "공간 오브젝트에 붙는 UI"가 아니라 "앱을 조작하는 독립 패널"에 적합하다.

## 4. Window가 적합하지 않았던 경우

박스 안 메모 목록을 별도 window로 띄우면 처음에는 편해 보인다. SwiftUI UI를 그대로 쓸 수 있고, 입력 폼도 만들기 쉽다.

하지만 문제가 있다.

```text
박스를 클릭함
-> 메모 목록 window가 열림
-> 사용자가 박스를 드래그함
-> 박스는 움직임
-> window는 원래 자리에 남음
```

이 앱에서 박스 위 메모 목록은 박스에 종속된 UI다. 박스가 움직이면 같이 움직여야 한다.

그래서 독립 window가 아니라 attachment로 바꾼다.

## 5. Ornament는 창 주변 보조 UI다

SwiftUI ornament는 window나 scene 주변에 붙는 보조 UI다.

예를 들면 ControlPanel 창 아래에 항상 붙는 설정 버튼, 보기 전환 버튼, 상태 표시 버튼 같은 것에 어울린다.

```swift
SomeView()
    .ornament(attachmentAnchor: .scene(.bottom)) {
        HStack {
            Button("설정") {}
            Button("도움말") {}
        }
    }
```

ornament는 "창의 장식처럼 붙는 UI"에 가깝다.

하지만 RealityKit entity의 자식이 되는 것은 아니다. 그래서 특정 박스의 transform을 따라가야 하는 UI에는 맞지 않는다.

## 6. Ornament와 Attachment가 헷갈리는 이유

Desktop Organizer의 박스 아래 컨트롤은 모양만 보면 ornament처럼 느껴질 수 있다.

```text
[삭제] [박스 이름] [고정]
```

하지만 이 UI는 SwiftUI ornament가 아니다. RealityKit attachment다.

왜냐하면 이 UI는 window 주변이 아니라 박스 entity 아래에 붙어야 하기 때문이다.

```text
WorkspaceBox:{boxID}
└─ SelectedBoxControls Attachment
```

사용자 눈에는 "박스의 오너먼트 같은 버튼"으로 보이지만, 구현은 RealityKit attachment가 맞다.

## 7. RealityKit Attachment의 핵심

`RealityView`의 `attachments` closure에서 SwiftUI view를 등록한다.

```swift
Attachment(id: selectedBoxControlAttachmentID) {
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
```

등록된 attachment는 update 단계에서 entity로 꺼낸다.

```swift
let controls = attachments.entity(for: selectedBoxControlAttachmentID)
```

이 순간 SwiftUI view가 RealityKit scene graph에 붙일 수 있는 entity처럼 다뤄진다.

## 8. 박스 컨트롤 attachment

박스 아래 컨트롤은 선택된 박스의 자식으로 붙는다.

```swift
if controls.parent !== selectedBoxRoot {
    controls.removeFromParent()
    selectedBoxRoot.addChild(controls)
}

controls.position = SIMD3<Float>(0, -0.12, 0.17)
```

이 구조의 의미는 분명하다.

- 선택된 박스가 바뀌면 같은 controls attachment를 새 박스 아래로 옮긴다.
- controls의 부모가 `selectedBoxRoot`이므로 박스가 움직이면 controls도 같이 움직인다.
- 위치는 박스 root 기준 상대 좌표다.

## 9. 박스 위 메모 목록 attachment

박스를 열면 메모 목록도 attachment로 박스 위에 붙는다.

```swift
if memoList.parent !== boxRoot {
    memoList.removeFromParent()
    boxRoot.addChild(memoList)
}

memoList.position = SIMD3<Float>(0, 0.34, 0)
```

이 UI는 창처럼 보이지만 실제 window가 아니다.

```text
WorkspaceBox:{boxID}
└─ BoxMemoList:{boxID} Attachment
```

그래서 박스가 움직일 때 같이 움직인다.

## 10. 공간 메모 attachment

박스 안 메모를 드래그해서 공간에 꺼내면 열린 메모 카드도 attachment가 된다.

```swift
if memoEntity.parent !== rootEntity {
    memoEntity.removeFromParent()
    memoEntity.name = spatialMemoAttachmentID(for: presentation.id)
    rootEntity.addChild(memoEntity)
}

memoEntity.position = presentation.position
```

공간 메모는 박스의 자식이 아니라 `WorkspaceRoot`의 자식이다.

이유는 공간 메모가 박스와 독립적으로 움직일 수 있어야 하기 때문이다.

이때 실제 SwiftUI view 타입은 `SpatialMemoOpenedAttachment`이고, `Attachment(id: spatialMemoAttachmentID(for: presentation.id))` 안에서 등록된다.

## 11. 드래그 preview attachment

메모를 드래그하는 동안에는 원본 메모 카드가 attachment 안에 남고, 반투명 preview attachment가 공간 쪽으로 움직인다.

```swift
if preview.parent !== boxRoot {
    preview.removeFromParent()
    boxRoot.addChild(preview)
}

configureMemoBillboard(preview)
preview.position = spatialMemoPosition(for: draggingMemoPreview.translation)
```

이 preview는 실제 저장된 공간 메모가 아니라 "놓으면 열릴 위치"를 보여주는 임시 UI다.

그래서 `SpatialMemoPreviewAttachment`에는 hit testing도 꺼져 있다.

```swift
.allowsHitTesting(false)
```

## 12. attachment의 부모 선택이 설계다

Attachment 자체보다 더 중요한 것은 "어느 entity의 자식으로 붙일 것인가"다.

| UI | 부모 | 이유 |
| --- | --- | --- |
| 박스 컨트롤 | 선택된 `boxRoot` | 박스를 따라 움직여야 함 |
| 박스 메모 목록 | 해당 `boxRoot` | 박스를 따라 움직여야 함 |
| 드래그 preview | 드래그 시작 박스의 `boxRoot` | 박스 기준으로 꺼내지는 느낌 |
| 열린 공간 메모 | `WorkspaceRoot` | 박스와 독립적으로 움직여야 함 |
| 기본 ControlPanel | window | 앱 전체 조작 패널 |

이 표가 이 교재의 핵심이다.

## 13. SwiftUI View와 attachment entity의 차이

`BoxMemoAttachmentView`는 처음에는 SwiftUI view다.

```swift
struct BoxMemoAttachmentView: View {
    let boxName: String
    let memos: [MemoItem]
    let onMemoCreated: (String, Int) -> Void
}
```

하지만 `Attachment(id:)`에 들어가면 RealityKit이 attachment entity로 꺼낼 수 있게 해 준다.

```swift
Attachment(id: memoListAttachmentID(for: box.id)) {
    BoxMemoAttachmentView(...)
}
```

SwiftUI view는 UI 내용을 만든다. attachment entity는 그 UI가 공간에서 어디에 붙을지를 결정한다.

## 14. 버튼 입력은 SwiftUI, 위치는 RealityKit

Attachment의 재미있는 점은 역할이 둘로 나뉜다는 것이다.

| 책임 | 담당 |
| --- | --- |
| 버튼, 텍스트, 입력폼, `@State` | SwiftUI view |
| 부모, 위치, billboard, hover/input component | RealityKit entity |

예를 들어 `BoxControlAttachmentView` 안의 버튼은 SwiftUI 버튼이다.

```swift
Button(role: .destructive) {
    onDelete()
} label: {
    Image(systemName: "trash")
}
```

하지만 그 버튼 바가 박스 아래 어디에 놓일지는 RealityKit 쪽에서 정한다.

```swift
controls.position = SIMD3<Float>(0, -0.12, 0.17)
```

## 15. attachment가 모든 문제의 답은 아니다

Attachment는 강력하지만 항상 정답은 아니다.

별도 window가 더 좋은 경우도 있다.

- 긴 문서를 편집해야 한다.
- 키보드 입력이 많다.
- 공간 오브젝트와 독립된 앱 설정 화면이다.
- 사용자가 창을 크게 조절해야 한다.
- 한 번에 여러 데이터 목록을 비교해야 한다.

ornament가 더 좋은 경우도 있다.

- 특정 window 주변에 항상 붙는 짧은 도구 모음이다.
- 공간 entity가 아니라 화면/scene 조작 버튼이다.
- 사용자가 오브젝트가 아니라 앱 모드 자체를 바꾼다.

## 16. 이 앱의 선택 기준

Desktop Organizer에서는 다음 기준을 쓰면 된다.

| 만들 UI | 추천 방식 |
| --- | --- |
| 앱 전체 조작 패널 | `WindowGroup` |
| 공간 시작/종료, 책상 다시 인식 | `WindowGroup` 안 버튼 |
| ControlPanel 주변의 보조 설정 | `ornament` 후보 |
| 박스 아래 삭제/이름/고정 | RealityKit `Attachment` |
| 박스 위 메모 목록 | RealityKit `Attachment` |
| 드래그 중 메모 preview | RealityKit `Attachment` |
| 공간에 열린 메모 카드 | RealityKit `Attachment` |
| 아주 긴 메모 편집기 | 별도 `WindowGroup` 또는 sheet 후보 |

## 17. Attachment 사용 시 주의점

Attachment를 사용할 때는 아래를 주의해야 한다.

- `Attachment(id:)`의 id는 안정적이어야 한다.
- SwiftUI view가 사라졌는데 scene에 entity가 남지 않도록 정리해야 한다.
- 부모 entity를 바꿀 때는 기존 parent에서 `removeFromParent()`를 먼저 호출한다.
- attachment 위치는 부모 기준 상대 좌표라는 점을 기억한다.
- 복잡한 입력 UI는 너무 작은 공간 attachment에 넣으면 사용성이 떨어질 수 있다.

이 프로젝트도 사라진 공간 메모 attachment를 정리한다.

```swift
for child in rootEntity.children where child.name.hasPrefix("SpatialMemo:") {
    let rawID = child.name.replacingOccurrences(of: "SpatialMemo:", with: "")
    if let id = UUID(uuidString: rawID), !activeAttachmentIDs.contains(id) {
        child.removeFromParent()
    }
}
```

## 18. 현재 프로젝트에 없는 ornament

현재 Desktop Organizer는 SwiftUI `ornament`를 직접 사용하지 않는다.

이것은 누락이라기보다 선택이다. 현재 필요한 UI 대부분이 박스나 메모 entity에 붙어야 하기 때문이다.

다만 앞으로 아래 기능이 생기면 ornament를 검토할 수 있다.

- ControlPanel 하단의 항상 보이는 도움말
- 전체 보기 모드 전환
- 공간 디버그 overlay 표시/숨김 토글
- 앱 전역 설정 버튼

## 19. 코드 읽는 순서

이 주제를 공부하려면 아래 순서로 읽는 것이 좋다.

1. `DesktopOrganizer/App/DesktopOrganizerApp.swift`
2. `DesktopOrganizer/Views/WorkspaceRealityView.swift`
3. `DesktopOrganizer/Views/WorkspaceRealityView+Attachments.swift`
4. `DesktopOrganizer/Views/BoxControlAttachmentView.swift`
5. `DesktopOrganizer/Views/BoxMemoAttachmentView.swift`
6. `DesktopOrganizer/Views/SpatialMemoAttachmentViews.swift`
7. `DesktopOrganizer/Views/WorkspaceRealityView+Geometry.swift`

## 20. 다음 교재와의 연결

이 교재를 읽은 뒤에는 `06-spatial-interaction-guide.html`로 넘어가면 좋다.

5번 교재에서 UI가 어디에 붙는지 배웠다면, 6번 교재에서는 사용자가 그 UI와 entity를 어떻게 보고, 탭하고, 핀치하고, 드래그하는지 공부한다.

## 21. 체크리스트

아래 질문에 답할 수 있으면 5번 교재의 목표를 달성한 것이다.

- `WindowGroup`과 RealityKit `Attachment`의 차이를 설명할 수 있는가?
- SwiftUI `ornament`가 왜 박스 아래 버튼에 적합하지 않은지 말할 수 있는가?
- 박스 위 메모 목록을 window가 아니라 attachment로 만든 이유를 설명할 수 있는가?
- attachment의 부모 entity를 정하는 것이 왜 중요한지 설명할 수 있는가?
- 열린 공간 메모가 `boxRoot`가 아니라 `WorkspaceRoot` 아래에 붙는 이유를 말할 수 있는가?
- attachment 안의 버튼 입력은 SwiftUI가, 위치는 RealityKit이 담당한다는 말을 설명할 수 있는가?
