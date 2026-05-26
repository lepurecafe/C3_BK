# 03. SwiftData 입문: 공간 오브젝트 저장하기

Last updated: 2026-05-25

이 교재는 Desktop Organizer를 통해 SwiftData를 공부하기 위한 세 번째 교재다. 목표는 `OrganizerBox`와 `MemoItem`이 어떤 정보를 저장하고, 그 저장 정보가 어떻게 RealityKit entity와 attachment를 다시 만드는 재료가 되는지 이해하는 것이다.

## 1. 이 주제를 배우는 이유

Desktop Organizer의 박스와 메모는 단순히 화면에 한 번 그려지는 UI가 아니다. 앱을 껐다 켜도 다시 나타나야 하고, 위치와 앵커 상태도 복원되어야 한다.

하지만 SwiftData 모델 자체가 RealityKit entity는 아니다.

핵심은 이 문장이다.

> SwiftData 모델은 공간 오브젝트를 다시 만들기 위한 기록이다.

이 프로젝트에서 `OrganizerBox`는 박스 entity를 복원하기 위한 기록이고, `MemoItem`은 박스 안 메모와 공간에 펼쳐진 메모 attachment를 복원하기 위한 기록이다.

## 2. SwiftData가 맡는 역할

SwiftData는 앱의 영속 데이터를 저장한다. 여기서 영속 데이터란 앱을 종료했다가 다시 실행해도 남아야 하는 값이다.

이 프로젝트에서 SwiftData가 저장하는 것은 크게 두 가지다.

| 모델 | 저장하는 것 | 다시 만드는 대상 |
| --- | --- | --- |
| `OrganizerBox` | 박스 이름, 위치, 고정 상태, WorldAnchor id | 박스 RealityKit entity |
| `MemoItem` | 메모 본문, 색상, 소속 박스, 공간 표시 상태, 위치, WorldAnchor id | 박스 안 메모 카드, 공간 메모 attachment |

반대로 SwiftData가 저장하지 않는 것도 있다.

| 저장하지 않는 것 | 이유 |
| --- | --- |
| `Entity` 객체 자체 | RealityKit 런타임 객체라 앱 실행 중에만 유효함 |
| animation controller | 재실행 후 다시 만들면 되는 런타임 상태 |
| drag 중 임시 위치 | 손을 놓기 전까지는 확정된 저장 상태가 아님 |
| attachment view 객체 | SwiftUI view는 저장 대상이 아니라 상태를 보고 다시 생성됨 |

## 3. modelContainer가 연결되는 위치

SwiftData 모델은 앱 시작점에서 scene에 연결된다.

```swift
.modelContainer(for: [OrganizerBox.self, MemoItem.self])
```

이 설정이 있어야 `ControlPanelView`와 `WorkspaceRealityView`에서 `@Query`와 `modelContext`를 사용할 수 있다.

```swift
@Environment(\.modelContext) private var modelContext
@Query(sort: \OrganizerBox.createdAt) private var boxes: [OrganizerBox]
@Query(sort: \MemoItem.createdAt) private var memos: [MemoItem]
```

`modelContainer`는 저장소를 준비하고, `modelContext`는 저장소에 데이터를 넣고 지우는 작업 창구다.

## 4. @Model이 붙은 OrganizerBox

`OrganizerBox`는 SwiftData에 저장되는 박스 기록이다.

```swift
@Model
final class OrganizerBox {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var posX: Float = 0
    var posY: Float = 1.0
    var posZ: Float = -1.0
    var isAnchored: Bool = false
    var worldAnchorIdentifier: String?
}
```

각 필드의 의미는 다음과 같다.

| 필드 | 의미 |
| --- | --- |
| `id` | SwiftData 모델, RealityKit entity 이름, WorldAnchor 연결에 공통으로 쓰는 식별자 |
| `name` | 박스 아래 attachment에 표시할 이름 |
| `createdAt` | `@Query(sort:)` 정렬 기준 |
| `posX`, `posY`, `posZ` | WorldAnchor가 없거나 복원 전일 때 사용할 공간 위치 |
| `isAnchored` | 사용자가 고정 버튼을 켰는지 |
| `worldAnchorIdentifier` | 실제 ARKit WorldAnchor id 문자열 |

## 5. 왜 id가 중요한가

공간 앱에서는 하나의 오브젝트가 여러 계층에 걸쳐 등장한다.

- SwiftData의 `OrganizerBox`
- RealityKit의 박스 root entity
- 박스 아래 control attachment
- 박스 위 memo list attachment
- WorldAnchor

이것들을 연결하려면 공통 식별자가 필요하다. 이 프로젝트는 `UUID`를 그 연결점으로 사용한다.

```swift
@Attribute(.unique) var id: UUID
```

`@Attribute(.unique)`는 같은 id가 중복 저장되지 않도록 하는 제약이다. 공간 오브젝트는 중복으로 복원되면 사용자가 바로 이상함을 느끼므로, 고유 id가 중요하다.

## 6. 박스 생성과 저장 흐름

사용자가 박스 이름을 입력하고 확인하면 `ControlPanelView.createBox(named:)`가 실행된다.

```swift
let position = workspacePosition(from: origin)
let box = OrganizerBox(
    name: name,
    posX: position.x,
    posY: position.y,
    posZ: position.z
)
modelContext.insert(box)
```

이때 먼저 SwiftData 모델을 만든다. 그리고 저장을 시도한다.

```swift
do {
    try modelContext.save()
} catch {
    modelContext.delete(box)
    storageErrorMessage = error.localizedDescription
    controlStatusText = "박스 저장 실패"
    return
}
```

저장이 성공한 뒤에야 현재 열린 공간에 entity 생성을 요청한다.

```swift
workspaceStore.addBox(
    id: box.id,
    position: position
)
```

순서가 중요하다.

1. 저장 모델 생성
2. SwiftData 저장
3. 런타임 store에 entity 생성 요청
4. immersive space 열기
5. `WorkspaceRealityView`가 저장 모델과 요청을 보고 entity 생성

## 7. MemoItem은 더 많은 상태를 저장한다

메모는 박스보다 상태가 많다. 박스 안에만 있을 수도 있고, 공간으로 꺼내져 있을 수도 있고, 고정되어 있을 수도 있다.

```swift
@Model
final class MemoItem {
    @Attribute(.unique) var id: UUID
    var text: String
    var createdAt: Date
    var colorIndex: Int = 0
    var containerBoxID: UUID?
    var isSpatiallyPresented: Bool = false
    var spatialBoxID: UUID?
    var spatialPosX: Float = 0
    var spatialPosY: Float = 0
    var spatialPosZ: Float = 0
    var isSpatiallyAnchored: Bool = false
    var spatialWorldAnchorIdentifier: String?
}
```

메모 모델은 내용뿐 아니라 "이 메모가 현재 어떤 상태로 보여야 하는가"도 저장한다.

## 8. MemoItem 필드 읽기

| 필드 | 의미 |
| --- | --- |
| `id` | 메모, 공간 attachment, WorldAnchor를 연결하는 식별자 |
| `text` | 사용자가 입력한 메모 본문 |
| `createdAt` | 생성 순서 정렬 기준 |
| `colorIndex` | `MemoPalette.colors`에서 어떤 색을 쓸지 나타내는 인덱스 |
| `containerBoxID` | 메모가 들어 있는 박스 id |
| `isSpatiallyPresented` | 박스 밖 공간에 펼쳐져 있는지 |
| `spatialBoxID` | 공간 메모가 어느 박스에서 나왔는지 |
| `spatialPosX`, `spatialPosY`, `spatialPosZ` | 공간 메모의 복원 위치 |
| `isSpatiallyAnchored` | 공간 메모가 고정되어 있는지 |
| `spatialWorldAnchorIdentifier` | 공간 메모의 WorldAnchor id 문자열 |

## 9. 관계를 직접 UUID로 저장하는 방식

이 프로젝트는 `OrganizerBox`와 `MemoItem` 사이를 SwiftData 관계 property가 아니라 `UUID`로 연결한다.

```swift
var containerBoxID: UUID?
```

그리고 박스 안 메모를 찾을 때는 필터링한다.

```swift
func memos(in boxID: UUID) -> [MemoItem] {
    memos.filter { $0.containerBoxID == boxID }
}
```

이 방식은 초보자에게 명확하다. "이 메모는 어느 박스 id에 들어 있는가"를 직접 볼 수 있기 때문이다.

다만 앱이 더 커지면 SwiftData의 관계 모델을 쓰는 방식도 검토할 수 있다.

## 10. 메모 생성 흐름

박스 안에서 메모를 만들면 `createMemo(in:text:colorIndex:)`가 실행된다.

```swift
let memo = MemoItem(
    text: trimmed,
    colorIndex: colorIndex,
    containerBoxID: boxID
)
modelContext.insert(memo)
```

여기서 중요한 값은 `containerBoxID`다. 이 값이 있어야 박스를 클릭했을 때 해당 박스 안 메모 목록에 나타난다.

```swift
try modelContext.save()
```

저장에 성공하면 `@Query`로 읽고 있는 `memos` 배열이 갱신되고, attachment 안의 목록도 다시 그려진다.

## 11. 메모를 공간으로 꺼낼 때 저장되는 값

메모를 드래그해서 공간으로 꺼내면 기존 `MemoItem`에 공간 표시 상태를 기록한다.

```swift
memo.isSpatiallyPresented = true
memo.spatialBoxID = boxID
memo.spatialPosX = position.x
memo.spatialPosY = position.y
memo.spatialPosZ = position.z
memo.isSpatiallyAnchored = false
memo.spatialWorldAnchorIdentifier = nil
```

이 값들이 저장되면 앱을 다시 실행했을 때도 "이 메모는 박스 안에만 있는 메모가 아니라 공간에 펼쳐진 메모"라고 복원할 수 있다.

## 12. 닫기와 삭제는 다르다

공간에 펼쳐진 메모에서 닫기와 삭제는 다른 동작이다.

닫기는 공간 presentation만 접고, `MemoItem` 자체는 남긴다.

```swift
memo.isSpatiallyPresented = false
memo.spatialBoxID = nil
memo.isSpatiallyAnchored = false
memo.spatialWorldAnchorIdentifier = nil
saveSpatialMemoState(statusText: "공간 메모 닫힘")
```

삭제는 `MemoItem` 자체를 SwiftData에서 제거한다.

```swift
modelContext.delete(memo)
try modelContext.save()
```

제품 관점에서도 다르다.

| 동작 | 결과 |
| --- | --- |
| 닫기 | 공간에서만 사라지고 박스 안 메모로 돌아감 |
| 삭제 | 메모 데이터 자체가 사라짐 |

## 13. 위치 저장은 언제 하는가

공간 메모를 움직이는 동안에는 화면 상태인 `SpatialMemoPresentation.position`만 먼저 바꾼다.

드래그가 끝나면 그때 SwiftData 모델의 좌표를 갱신한다.

```swift
memo.spatialPosX = presentation.position.x
memo.spatialPosY = presentation.position.y
memo.spatialPosZ = presentation.position.z
saveSpatialMemoState(statusText: "공간 메모 위치 저장됨")
```

이 패턴은 성능과 데이터 안정성에 좋다.

- 드래그 중에는 화면 반응이 우선이다.
- 사용자가 손을 놓은 뒤에 저장하면 충분하다.
- 저장소를 매 프레임 갱신하지 않아도 된다.

## 14. 데이터 초기화 흐름

데이터 초기화는 SwiftData만 지우면 끝나지 않는다. WorldAnchor와 RealityKit 화면 상태도 같이 정리해야 한다.

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

그 다음 SwiftData 모델을 삭제한다.

```swift
boxes.forEach { modelContext.delete($0) }
memos.forEach { modelContext.delete($0) }
try modelContext.save()
workspaceStore.resetWorkspace()
```

정리 순서는 다음과 같다.

1. WorldAnchor 제거 요청
2. SwiftData 모델 삭제
3. 저장
4. 런타임 workspace reset
5. RealityKit scene에서 보이는 entity 제거

## 15. SwiftData 모델과 RealityKit entity의 차이

초보자가 가장 많이 헷갈리는 부분은 이것이다.

| 질문 | SwiftData 모델 | RealityKit entity |
| --- | --- | --- |
| 앱을 껐다 켜도 남는가? | 남음 | 다시 만들어야 함 |
| SwiftData에 저장되는가? | 예 | 아니오 |
| 위치를 가질 수 있는가? | 숫자로 저장 | 실제 transform/position을 가짐 |
| 사용자가 볼 수 있는가? | 직접 보이지 않음 | 공간에서 보임 |
| 예시 | `OrganizerBox`, `MemoItem` | `boxRoot`, attachment entity |

`OrganizerBox`가 있다고 해서 화면에 박스가 보이는 것은 아니다. `WorkspaceRealityView`가 이 저장 모델을 읽고 RealityKit entity를 만들어야 보인다.

## 16. 이 프로젝트의 설계 장점과 한계

### 장점

- 저장 모델이 단순해서 초보자가 읽기 쉽다.
- `UUID`로 박스와 메모 연결을 추적하기 쉽다.
- WorldAnchor id를 문자열로 저장해 ARKit 복원과 연결할 수 있다.
- 저장 데이터와 런타임 entity가 분리되어 있다.

### 한계

- `containerBoxID`를 직접 UUID로 관리하므로 관계 무결성을 코드가 책임져야 한다.
- 박스를 삭제할 때 관련 메모 삭제 규칙을 명시적으로 관리해야 한다.
- 앱이 커지면 SwiftData relationship을 도입하는 편이 더 안전할 수 있다.
- 좌표 필드가 `posX`, `posY`, `posZ`로 나뉘어 있어 변환 로직이 반복될 수 있다.

현재 단계에서는 학습과 디버깅이 쉬운 장점이 크다. 추후 데이터가 복잡해지면 relationship 기반 모델로 발전시킬 수 있다.

## 17. 코드 읽는 순서

SwiftData 흐름을 공부하려면 아래 순서가 좋다.

1. `DesktopOrganizer/Models/OrganizerBox.swift`
2. `DesktopOrganizer/Models/MemoItem.swift`
3. `DesktopOrganizer/App/DesktopOrganizerApp.swift`
4. `DesktopOrganizer/Views/ControlPanelView.swift`
5. `DesktopOrganizer/Views/WorkspaceRealityView+Memos.swift`
6. `DesktopOrganizer/Views/WorkspaceRealityView+Boxes.swift`
7. `DesktopOrganizer/Views/WorkspaceRealityView+Anchors.swift`

## 18. 다음 교재와의 연결

이 교재를 읽은 뒤에는 `04-realitykit-entity-design-guide.html`로 넘어가면 좋다.

3번 교재에서 저장 모델을 배웠다면, 4번 교재에서는 이 저장 모델을 바탕으로 실제 공간에 보이는 RealityKit entity가 어떻게 만들어지는지 공부한다.

## 19. 체크리스트

아래 질문에 답할 수 있으면 3번 교재의 목표를 달성한 것이다.

- `@Model`이 붙은 타입이 왜 저장 모델인지 설명할 수 있는가?
- `OrganizerBox`와 실제 박스 entity가 왜 다른지 말할 수 있는가?
- `MemoItem.containerBoxID`가 어떤 역할을 하는지 설명할 수 있는가?
- 메모 닫기와 삭제의 차이를 설명할 수 있는가?
- 드래그 중에는 왜 SwiftData 좌표를 계속 저장하지 않는지 말할 수 있는가?
- 데이터 초기화 때 SwiftData 삭제 외에 WorldAnchor와 runtime reset이 필요한 이유를 설명할 수 있는가?
