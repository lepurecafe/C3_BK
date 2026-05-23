# Desktop Organizer Final Product Shape Plan

Last updated: 2026-05-23
Status: Draft for implementation planning

---

## 0. 목표

이 문서는 Desktop Organizer의 최종 사용자 경험을 기준으로 현재 구현 상태와 남은 작업을 구분한다.

최종 앱은 사용자가 Vision Pro를 착용하고 앱을 실행하면 책상 위에 이름 있는 박스를 만들고, 박스 안에서 메모를 생성/조회/삭제하며, 박스와 메모를 공간에 고정할 수 있는 앱이다.

공간 인식의 제품 목표는 "주변 공간 전체"가 아니라 "책상으로 쓸 수 있는 수평 평면"을 찾는 것이다. 책상 후보 탐지는 Apple의 visionOS 문서인 [Placing content on detected planes](https://developer.apple.com/documentation/visionos/placing-content-on-detected-planes)의 방향과 같은 계열이다. 현재 구현은 문서의 샘플을 그대로 복사한 것은 아니지만, 핵심 기술인 `ARKitSession`, `PlaneDetectionProvider`, `PlaneAnchor` update 흐름을 사용한다.

---

## 1. 최종 사용자 흐름

### 1.1 앱 실행

1. 앱이 실행되면 바로 사용자 눈앞에서 책상을 찾기 시작한다.
2. 기본 패널이 뜬다.
3. 기본 패널은 2단 구성이다.

```text
상단: "안녕하세요. 당신의 친구 직박구리입니다."
하단: [박스 만들기]
```

### 1.2 박스 생성

1. 사용자가 `박스 만들기` 버튼을 누른다.
2. 기본 패널이 박스 이름 입력 화면으로 바뀐다.
3. 사용자가 박스 이름을 입력하고 `확인`을 누른다.
4. 입력한 이름으로 박스가 생성된다.
5. 책상 평면이 인식되어 있으면 박스는 인식된 책상 위 중심에 배치된다.
6. 책상 평면이 인식되지 않았으면 박스는 사용자 눈앞 기본 위치에 배치된다.

### 1.3 박스 위 조작 UI

박스가 생성되면 현재 앵커 버튼과 같은 방식의 공간 attachment가 박스 근처에 표시된다.

표시 순서:

```text
[삭제 아이콘] [박스 이름] [앵커 아이콘]
```

요구 사항:

- 세 요소는 하나의 블록처럼 보인다.
- 각 요소는 시선으로 인식되고 선택 가능해야 한다.
- Apple 기본 상호작용 방식을 우선 사용한다.
- 삭제 아이콘은 삭제 의미가 명확한 `trash` 계열 SF Symbol을 사용한다.
- 박스를 움직이면 이 UI도 박스와 함께 움직인다.
- 조작 블록 위치는 박스 아래로 둔다.

### 1.4 박스 클릭 후 메모 목록 창

1. 박스를 클릭하면 박스가 열린다.
2. 박스 위에 메모 목록 창이 뜬다.
3. 이 창에는 메모 생성 버튼이 있다.
4. 메모 생성 버튼을 누르면 색상 선택과 본문 입력을 할 수 있다.
5. 생성된 메모는 해당 박스 안에 저장된다.
6. 메모 목록에서는 각 메모가 작은 텍스트 줄이 아니라, 선택된 색상의 메모지 미리보기처럼 더 크게 표시된다.
7. 메모 제목은 현재처럼 본문 앞 10글자 정도를 사용한다.
8. 미리보기에는 본문 서두가 보인다.

창 레이아웃:

- 현재 attachment보다 더 넓은 창이 필요하다.
- 메모 미리보기 카드들이 주 영역을 차지한다.
- `메모 추가`, `선택`, `삭제` 버튼은 창 상단에 한 행으로 표시한다.

결정:

- 메모 생성 시 코너 곡률 제어는 제공하지 않는다.
- 메모지는 앱이 정한 고정 corner radius를 사용한다.
- 사용자가 고르는 값은 색상과 본문만 둔다.

### 1.5 메모 활성화

메모는 두 방식으로 활성화될 수 있어야 한다.

1. 메모 미리보기를 클릭한다.
2. 메모 미리보기를 드래그해서 박스 위 창 밖으로 꺼낸다.

활성화되면 공간 memo entity가 표시된다.

결정:

- 메모에도 앵커링 버튼이 필요하므로 최종 형태는 공간 memo entity를 목표로 한다.
- 기존 `MemoLabel` plain window는 중간 단계 또는 비교용으로만 본다.

### 1.6 메모 삭제

박스 위 메모 창에는 메모 삭제 흐름이 있어야 한다.

1. 메모 선택 모드 또는 선택 UI가 있다.
2. 사용자가 삭제할 메모를 선택한다.
3. 삭제 버튼을 누른다.
4. 선택된 메모가 SwiftData에서 삭제된다.
5. 박스 위 목록과 ControlPanel 상태가 즉시 갱신된다.

### 1.7 메모 앵커링

메모 아래에도 앵커링 버튼이 있어야 한다.

목표:

- 박스처럼 메모도 공간에 고정할 수 있다.
- 메모가 개별 window인지, RealityKit entity인지에 따라 구현 방식이 달라진다.
- WorldAnchor를 사용하려면 메모도 entity-only 구조로 가는 편이 안정적이다.

### 1.8 박스를 바라볼 때 밝아지는 효과

현재 박스를 사용자가 바라보면 살짝 밝아지는 효과는 앱이 별도 색상 애니메이션을 만든 것이 아니라 visionOS/RealityKit 기본 hover 효과를 사용한다.

현재 구현:

```text
TravelCase entity와 모든 child entity
-> InputTargetComponent 부여
-> HoverEffectComponent 부여
-> 사용자의 시선/포인터가 entity를 겨냥하면 시스템 hover feedback 표시
```

의미:

- `InputTargetComponent`는 entity가 입력 대상이 될 수 있게 한다.
- `HoverEffectComponent`는 사용자가 바라보거나 가리킬 때 시스템 기본 강조 효과가 나타나게 한다.
- 이 효과 덕분에 박스가 "선택 가능한 오브젝트"처럼 느껴진다.
- 직접 만든 밝기 조정이 아니므로 visionOS 기본 룩앤필을 따른다.

---

## 2. 현재 구현 상태

### 2.1 이미 구현됨

| 영역 | 현재 상태 |
|---|---|
| 앱 기본 구조 | `WindowGroup` + `ImmersiveSpace` 구조 존재 |
| 책상 인식 | `PlaneDetectionService`가 ARKit plane detection으로 책상 후보 수평면 탐지 |
| 감지 상태 표시 | ControlPanel에 `statusText` 표시 |
| 감지 평면 디버그 | 감지된 책상 후보를 cyan plane으로 시각화 |
| 박스 저장 | `OrganizerBox` SwiftData 모델 존재 |
| 메모 저장 | `MemoItem` SwiftData 모델 존재 |
| 박스 entity 표시 | `WorkspaceRealityView`가 `TravelCaseScene` entity 생성 |
| 박스 위치 저장 | `OrganizerBox.posX/Y/Z` 저장 및 재사용 |
| 평면 기반 박스 생성 | 감지 평면이 있으면 평면 중심 기반 좌표 사용 |
| fallback 박스 생성 | 감지 평면이 없으면 사용자 앞 기본 위치 사용 |
| 박스 이동 | 비앵커 상태 박스 drag 이동 가능 |
| 박스 열림/닫힘 | 탭으로 열림/닫힘 애니메이션 동작 |
| 박스 hover feedback | `InputTargetComponent` + `HoverEffectComponent`로 시스템 기본 강조 효과 동작 |
| 박스 앵커 버튼 | 선택된 박스에 anchor attachment 표시 |
| WorldAnchor 시도 | 실기기 지원 시 `WorldAnchor` 생성/삭제 흐름 존재 |
| 박스 안 메모 데이터 | `MemoItem.containerBoxID` 사용 |
| 박스 위 메모 목록 | 박스 클릭 시 attachment 목록 표시 |
| 메모 창 열기 | 메모 클릭 시 `MemoLabel` window 열기 |
| 데이터 초기화 | 박스와 메모 삭제 및 공간 entity reset |

### 2.2 부분 구현됨

| 영역 | 현재 상태 | 부족한 점 |
|---|---|---|
| 앱 실행 후 책상 인식 | 사용자가 `공간 인식 시작` 버튼을 눌러야 함 | 앱 실행 시 자동 시작 필요 |
| 기본 패널 | 감지 상태, 박스/메모 버튼, 목록 중심 | 최종 2단 구성으로 단순화 필요 |
| 박스 생성 | 버튼 즉시 생성, 이름은 `Box N` 자동 부여 | 이름 입력 단계 필요 |
| 박스 위치 | 감지 평면 중심 + X offset | "책상 위 중심" 기준을 더 명확히 조정 필요 |
| 박스 조작 attachment | 앵커 버튼만 표시 | 삭제 아이콘, 박스 이름, 앵커 아이콘 3요소 필요 |
| 박스 삭제 | 데이터 초기화는 있음 | 개별 박스 삭제 필요 |
| 박스 위 메모 목록 | 텍스트 버튼 형태 | 큰 메모지 미리보기 형태 필요 |
| 메모 생성 | ControlPanel sheet에서 생성 | 박스 위 창 안에서 생성 필요 |
| 메모 삭제 | 전체 초기화만 있음 | 박스 창 안에서 선택 삭제 필요 |
| 메모 활성화 | 클릭으로 개별 memo window 열기 | 드래그해서 창 밖으로 꺼내는 흐름 필요 |
| 메모 앵커링 | 없음 | 메모 자체의 entity/window 전략 결정 필요 |

### 2.3 구현되지 않음

| 영역 | 필요 작업 |
|---|---|
| 직박구리 인사 패널 | 최종 기본 패널 UI 신규 구현 |
| 박스 이름 입력 패널 | ControlPanel 내부 상태 전환 UI 신규 구현 |
| 개별 박스 삭제 | SwiftData 삭제 + RealityKit entity 제거 + 관련 메모 처리 정책 필요 |
| 박스 조작 3요소 블록 | 삭제/이름/앵커 attachment UI 신규 구현 |
| 박스 안 메모 생성 | 특정 boxID를 가진 `MemoItem` 생성 흐름 신규 구현 |
| 메모지 미리보기 카드 | `BoxMemoAttachmentView` 재설계 |
| 메모 선택 모드 | 선택 상태와 삭제 버튼 신규 구현 |
| 메모 드래그 아웃 활성화 | attachment drag gesture와 활성화 판정 신규 구현 |
| 메모 앵커 버튼 | 메모 표시 방식을 entity로 전환할지 결정 후 구현 |

---

## 3. 구현 방향

### 3.1 ControlPanel을 최종 기본 패널로 재설계

현재 `ControlPanelView`는 개발용 조작 패널에 가깝다.

최종 구조는 내부 상태를 가진 간단한 flow로 바꾼다.

```swift
enum ControlPanelMode {
    case home
    case namingBox
}
```

`home`:

```text
안녕하세요. 당신의 친구 직박구리입니다.
[박스 만들기]
```

`namingBox`:

```text
박스 이름
[TextField]
[취소] [확인]
```

수정 사항:

- 앱 실행 시 자동으로 `openSensingIfNeeded()`를 호출한다.
- 기존 개발용 목록과 데이터 초기화는 DEBUG 전용 또는 별도 개발자 패널로 분리한다.
- `createBox()`는 이름을 인자로 받도록 바꾼다.

```swift
private func createBox(named name: String) async
```

### 3.2 책상 인식과 박스 위치 정책 정리

현재는 감지된 plane 중심을 가져온 뒤 `x` 방향으로 offset을 더한다.

최종 요구에 맞추려면 기본 정책은 아래처럼 정리한다.

```text
첫 박스: 감지된 책상 후보 평면 중심
두 번째 이후 박스: 중심 주변에 작은 grid 또는 ring 형태로 분산
감지 실패: 사용자 눈앞 fallback 위치
```

주의:

- 현재 `tablePlaneOrigin`은 y값에 `-0.05` 보정을 한다.
- 실제 책상 위에 정확히 얹혀 보이는지는 실기기에서 모델 pivot과 visual bounds 기준으로 다시 조정해야 한다.
- 박스가 평면 아래로 파묻혀 보이면 y 보정값을 `0`, `+0.02`, 또는 모델 bounds 기반 보정으로 바꿔야 한다.

현재 책상 후보 판정:

```text
PlaneDetectionProvider(alignments: [.horizontal])
-> 수평 PlaneAnchor update 수신
-> geometry.extent.width > 0.3 인 plane을 책상 후보로 저장
```

즉, 현재는 `PlaneAnchor.Classification.table`로 진짜 책상만 고르는 방식이 아니라, 충분히 큰 수평면을 책상 후보로 간주한다.

개선 방향:

- 가능하면 `PlaneAnchor.Classification.table`을 활용해 table plane을 우선 선택한다.
- classification이 없거나 불안정하면 현재의 큰 수평면 fallback을 유지한다.
- plane 중심 좌표만 쓰지 말고, 모델의 visual bounds/pivot을 고려해 박스 바닥이 plane 위에 놓이도록 y값을 보정한다.
- 감지 plane debug overlay는 실기기에서 "정말 책상 위 plane을 잡았는지" 확인하기 위한 개발용 도구로 유지한다.

### 3.3 박스 조작 attachment 재설계

현재:

```text
[앵커 버튼]
```

목표:

```text
[삭제 아이콘] [박스 이름] [앵커 아이콘]
```

구현 방향:

- 기존 `BoxAnchorControlView`를 `BoxControlAttachmentView`로 확장 또는 교체한다.
- `WorkspaceRealityView` attachment에서 선택된 boxID와 `OrganizerBox.name`을 전달한다.
- 삭제 버튼 callback은 `WorkspaceRealityView`에서 SwiftData 삭제와 entity 제거를 수행한다.
- 앵커 버튼 callback은 기존 `toggleAnchor(for:)`를 유지한다.
- attachment 위치는 박스 아래로 둔다.

삭제 처리 시 함께 정리할 것:

- `OrganizerBox` 삭제
- 해당 박스 root entity 제거
- `renderedBoxIDs`, `boxRoots`, `boxModels`, `boxAnimations` 등 캐시 제거
- `WorkspaceEntityStore`의 selected/anchored/interaction mode 정리
- 해당 박스 안 메모 처리 정책 적용

메모 처리 정책:

1. 박스 삭제 시 박스 안 메모도 함께 삭제

결정:

- 박스 삭제 시 해당 박스 안의 메모도 함께 삭제한다.
- 사용자가 박스를 하나의 보관 단위로 인식하므로, 박스를 삭제하면 내부 내용도 같이 사라지는 쪽이 단순하다.
- 구현 시 삭제 전 확인 alert는 추가하는 것이 좋다.

### 3.4 박스 위 메모 창 재설계

현재 `BoxMemoAttachmentView`는 메모 목록 버튼에 가깝다.

목표는 박스 위에 붙는 작은 메모 관리 창이다.

필요 구성:

```text
+--------------------------------------+
| [+ 메모] [선택] [삭제]              |
| [메모 미리보기 카드]                |
| [메모 미리보기 카드]                |
| [메모 미리보기 카드]                |
+--------------------------------------+
```

레이아웃 요구:

- attachment 폭은 현재 `260`보다 넓게 잡는다.
- 상단에 `메모 추가`, `선택`, `삭제` 버튼 행을 고정한다.
- 버튼 행 아래 영역은 메모 미리보기 카드 grid 또는 list가 사용한다.
- 카드가 늘어나도 상단 버튼 행 위치가 흔들리지 않게 한다.

메모 카드:

- 배경색은 `MemoItem.colorIndex` 기반
- 제목은 본문 앞 10글자
- 본문 서두를 1~3줄 표시
- 현재보다 크고 시각적으로 메모지처럼 보여야 함
- corner radius는 사용자 설정값이 아니라 앱 고정 스타일로 처리

상태:

```swift
@State private var selectedMemoIDs = Set<UUID>()
@State private var isSelectingMemos = false
@State private var isCreatingMemo = false
```

### 3.5 박스 안 메모 생성

현재 메모 생성은 ControlPanel의 `MemoEditorSheet`에서 앱 전체 메모를 만든다.

목표는 열린 박스 창 안에서 바로 생성하는 것이다.

구현 방향:

- `BoxMemoAttachmentView` 안에 생성 UI를 둔다.
- 색상 선택은 기존 `ColorButton` 또는 동일한 색상 source를 재사용한다.
- 본문 입력 후 저장 시 `MemoItem(containerBoxID: box.id)`로 생성한다.
- 코너 곡률 slider/control은 추가하지 않는다.
- 저장은 attachment view에서 직접 `modelContext.insert`를 하거나, callback을 통해 `WorkspaceRealityView`가 수행한다.

권장:

- SwiftData 저장은 `WorkspaceRealityView`가 담당하고, attachment view는 callback만 호출한다.
- 이렇게 하면 저장 실패 처리와 openWindow 처리를 한곳에 모을 수 있다.

### 3.6 메모 클릭/드래그 활성화

현재:

```text
메모 버튼 클릭 -> MemoLabel window 열기
```

목표:

```text
메모 카드 클릭 -> 활성화
메모 카드 드래그해서 창 밖으로 꺼냄 -> 활성화
```

구현 방향:

- 1차 구현: 클릭 활성화 유지 + drag gesture에서 일정 거리 이상 이동하면 활성화.
- attachment 내부 SwiftUI drag gesture가 RealityView attachment에서 원하는 방식으로 동작하는지 실기기 확인이 필요하다.
- drag out이 안정적이지 않으면 대안으로 `꺼내기` 버튼 또는 long press 후 공간 배치를 먼저 구현한다.

활성화 결과:

- 메모를 RealityKit entity 또는 entity에 붙은 attachment로 만들어 공간에 띄운다.
- 기존 `MemoLabel` plain window는 Phase 5 이전까지의 임시 구현으로만 유지한다.
- WorldAnchor와 메모 앵커링까지 고려하면 memo entity 방식이 최종 방향이다.

### 3.7 메모 삭제

구현 방향:

- `BoxMemoAttachmentView`에 선택 모드를 둔다.
- 선택된 메모 ID들을 `WorkspaceRealityView` callback으로 넘긴다.
- `WorkspaceRealityView`가 SwiftData에서 해당 `MemoItem`을 삭제한다.
- 삭제 후 열린 memo window가 있다면 닫는 정책도 필요하다.

최소 구현:

```text
선택 버튼 탭
-> 카드 선택 가능
-> 삭제 버튼 탭
-> 선택된 MemoItem 삭제
```

### 3.8 메모 앵커링

이 요구는 메모 표시 방식과 연결된다.

현재 메모는 `MemoLabel` plain window로 열린다. plain window는 박스 entity처럼 `WorldAnchor`를 붙이기 어렵다.

결정:

- 메모도 최종적으로 entity-only 구조로 전환한다.
- 박스에서 꺼낸 메모는 공간 memo entity로 표시한다.
- 메모 아래 앵커 버튼은 memo entity의 attachment로 붙인다.

최종적으로 메모 아래에 앵커 버튼을 붙이려면 권장 방향은:

```text
MemoLabel window 중심
-> Memo workspace entity / attachment 중심으로 전환
```

필요한 모델 확장:

```swift
var posX: Float?
var posY: Float?
var posZ: Float?
var isAnchored: Bool
var worldAnchorIdentifier: String?
```

또는 메모의 공간 배치 상태를 별도 모델로 분리할 수 있다.

단계적으로는:

1. 메모를 공간 entity로 표시하는 실험
2. 메모 드래그 아웃 시 memo entity 생성
3. 메모 entity 아래에 anchor button attachment 추가
4. WorldAnchor 적용

---

## 4. 추천 구현 순서

### Phase 1. 최종 기본 패널과 박스 이름 입력

목표:

- 앱 실행 시 책상 인식 자동 시작
- 기본 패널을 인사 + 박스 만들기 버튼으로 단순화
- 박스 이름 입력 후 생성

수정 파일:

- `ControlPanelView.swift`
- 필요 시 `PlaneDetectionService.swift`

완료 기준:

- 앱 실행 후 사용자가 별도로 공간 인식 버튼을 누르지 않아도 책상 인식이 시작된다.
- 권한 거부, 공간 진입 취소, ARKit 실패 시 기본 패널에서 다시 공간 인식 요청을 할 수 있다.
- `박스 만들기` 버튼을 누르면 이름 입력 화면으로 바뀐다.
- 입력한 이름이 박스 위 UI와 SwiftData에 저장된다.

### Phase 2. 박스 조작 블록

목표:

- 박스 아래 attachment를 `[삭제] [이름] [앵커]` 블록으로 변경
- 개별 박스 삭제 구현

수정 파일:

- `WorkspaceRealityView.swift`
- `WorkspaceEntityStore.swift`
- 필요 시 `OrganizerBox.swift`

완료 기준:

- 박스 선택 시 3요소 블록이 보인다.
- 삭제 아이콘을 선택하면 해당 박스가 화면과 SwiftData에서 사라진다.
- 앵커 버튼은 기존처럼 작동한다.

### Phase 3. 박스 위 메모 관리 창

목표:

- 박스 클릭 시 열리는 attachment를 메모 관리 창으로 확장
- 메모 생성 버튼 추가
- 메모 카드 미리보기 UI 구현

수정 파일:

- `WorkspaceRealityView.swift`
- 새 파일 후보: `BoxMemoAttachmentView.swift`
- `ColorButton.swift` 재사용 가능

완료 기준:

- 열린 박스 위 창에서 메모를 만들 수 있다.
- 생성된 메모의 `containerBoxID`가 해당 박스 ID로 저장된다.
- 메모가 색상 카드 형태로 표시된다.

### Phase 4. 메모 선택 삭제

목표:

- 박스 위 메모 창에서 선택 모드와 삭제 버튼 구현

완료 기준:

- 여러 메모를 선택할 수 있다.
- 삭제 버튼으로 선택 메모가 SwiftData에서 삭제된다.
- 목록이 즉시 갱신된다.

### Phase 5. 메모 드래그 아웃 활성화

목표:

- 메모 카드를 창 밖으로 끌어내면 메모가 활성화된다.

완료 기준:

- 클릭 활성화는 유지된다.
- 일정 거리 이상 drag하면 공간 메모 entity를 생성한다.
- 실기기에서 gesture가 안정적으로 동작한다.

### Phase 6. 메모 entity와 앵커링

목표:

- 메모도 WorldAnchor를 붙일 수 있는 공간 오브젝트로 확장
- 메모 아래 anchor button 추가

완료 기준:

- 메모가 공간에 독립적으로 배치된다.
- 메모 아래 앵커 버튼이 표시된다.
- 실기기에서 WorldAnchor 생성/삭제가 동작한다.

---

## 5. 확인이 필요한 질문

현재 없음.

결정 완료:

- 박스 삭제 시 그 박스 안의 메모도 함께 삭제한다.
- 메모를 드래그해서 창 밖으로 꺼냈을 때 최종 형태는 공간 memo entity다.
- 메모 앵커링을 위해 메모도 최종적으로 entity-only 구조로 전환한다.
- 메모 생성 UI에서 코너 곡률 제어는 제거하고, 색상과 본문 입력만 제공한다.
- 박스 조작 블록은 박스 아래에 둔다.
- 앱 실행 즉시 책상 인식을 요청하되, 사용자가 거부하거나 실패하면 기본 패널에서 다시 공간 인식 요청을 할 수 있어야 한다.
- 박스 삭제 아이콘은 `xmark`가 아니라 삭제 의미가 명확한 `trash` 계열 SF Symbol을 사용한다.

---

## 6. 우선 결론

다음 작업은 Phase 1부터 시작하는 것이 좋다.

이유:

- 최종 UX의 입구가 현재 개발용 ControlPanel과 다르다.
- 박스 이름 입력이 먼저 들어가야 박스 위 조작 블록의 이름 표시도 자연스럽게 연결된다.
- 책상 인식 자동 시작과 fallback 정책을 먼저 정리하면 이후 박스 배치, 삭제, 메모 창 작업이 안정된다.
