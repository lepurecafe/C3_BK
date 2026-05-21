# Entity-Only World Anchor — Work Spec

Last updated: 2026-05-21
Phase: Plan
Feature: entity-only-world-anchor

---

## Executive Summary

| 항목 | 내용 |
|------|------|
| Feature | 박스를 volumetric window가 아닌 RealityKit entity로 전환하고 world anchor 기반 배치/복원을 검증 |
| 핵심 결정 | world anchor를 사용하려면 entity-only 전환이 선행되어야 한다 |
| 현재 기준 | `BoxVolumeView` 안의 interactive entity는 동작하지만, 아직 volumetric window 안에 갇힌 구조 |
| 목표 | 실제 공간에 고정되는 박스 entity를 만들고, 이후 메모 넣기/조회 기능의 기반으로 삼는다 |

### Value Delivered

| 관점 | 내용 |
|------|------|
| **Problem** | 현재 박스는 volumetric window 안에 표시되므로 실제 책상 위 오브젝트처럼 고정/복원하기 어렵다 |
| **Solution** | `ImmersiveSpace` 안에 RealityKit entity를 직접 배치하고 world anchor와 연결한다 |
| **Function UX Effect** | 박스가 창이 아니라 현실 공간에 놓인 물체처럼 동작한다 |
| **Core Value** | 메모를 공간 오브젝트에 넣고, 다시 찾아보는 앱의 핵심 경험을 기술적으로 검증한다 |

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | world anchor를 사용해 박스를 현실 공간 위치에 고정하려면 window 기반 박스보다 entity 기반 박스가 우선이다 |
| **WHO** | BK (visionOS 앱 구조와 RealityKit을 학습하며 개발 중) |
| **RISK** | ARKit/world anchor는 Simulator 검증이 제한적이고 실기기 확인이 필요하다 |
| **SUCCESS** | 박스 entity가 ImmersiveSpace에 표시되고, 선택/애니메이션/위치 저장/복원 실험이 가능하다 |
| **SCOPE** | entity-only 박스, world anchor 검증, 상태 모델화 준비, 메모-박스 데이터 흐름의 기반 설계 |

---

## 1. 핵심 방향

### 1.1 왜 entity-only가 먼저인가

world anchor는 "앱 창 안의 3D 콘텐츠"보다 "실제 공간에 배치된 RealityKit entity"와 직접적으로 맞물린다.

현재 구조:

```text
ControlPanel Window
  -> openWindow(value: BoxPayload)
  -> BoxVolumeView
  -> volumetric WindowGroup 안에 TravelCase entity 표시
```

목표 구조:

```text
ControlPanel Window
  -> ImmersiveSpace 안의 WorkspaceRealityView에 박스 생성 요청
  -> RealityKit Entity 생성
  -> World Anchor 또는 공간 위치 저장
  -> 같은 entity에 tap/drag/animation/memo interaction 연결
```

따라서 후속 작업 순서는 다음으로 고정한다.

```text
entity-only 실험
-> world anchor / 위치 복원 검증
-> 박스 상태 모델화
-> MemoItem.containerBoxID 데이터 흐름
-> 메모 넣기/조회 연출
```

---

## 2. 제품 의도

박스 열림은 "메모를 받을 준비가 됐다"는 상시 상태 표시가 아니다.

박스 열림의 용도는 두 가지다.

1. **메모 삽입 연출**
   - 사용자가 메모를 드래그한다.
   - 메모가 박스에 닿으면 박스가 열린다.
   - 사용자가 손을 떼면 메모가 사라지며 박스 안에 들어간 것으로 처리한다.
   - 박스가 닫힌다.

2. **박스 안 메모 조회**
   - 사용자가 메모가 들어 있는 박스를 클릭한다.
   - 박스가 열린다.
   - 박스 위에 window 형태의 메모 목록이 나타난다.
   - 조회가 끝나면 박스가 다시 닫힐 수 있다.

이 의도 때문에 박스의 open/close 상태는 단순 UI 효과가 아니라 `memo insertion`, `memo lookup` 흐름과 연결되는 interaction state로 관리해야 한다.

---

## 3. 현재 코드 기준

### 3.1 이미 있는 것

| 영역 | 현재 상태 |
|------|----------|
| 박스 에셋 | `TravelCaseScene` + `1890s_Travel_Case.usdz` 사용 |
| 박스 애니메이션 | asset 내부 `Open` animation 사용 |
| 박스 tap | `InputTargetComponent` + collision shape + targeted tap gesture |
| 열기 | 첫 탭에서 open animation 재생 |
| 닫기 | 열린 상태에서 같은 animation을 수동 time scrubbing으로 역재생 |
| 데이터 모델 | `OrganizerBox`, `MemoItem`, `BoxPayload`, `MemoLabel` 존재 |
| 메모-박스 연결 필드 | `MemoItem.containerBoxID` 존재하지만 실제 흐름은 아직 약함 |

### 3.2 아직 부족한 것

| 부족한 것 | 이유 |
|----------|------|
| entity-only workspace | 박스가 아직 volumetric window 안에 있음 |
| world anchor 연결 | 실제 공간 고정/복원 검증 전 |
| 박스 상태 소유자 | `BoxVolumeView` 내부 state에 가까운 구조라 여러 박스 관리에 약함 |
| 박스별 memo list UI | `containerBoxID`를 기준으로 조회하는 흐름이 아직 없음 |
| 메모 삽입 interaction | drag/drop 또는 공간 충돌 기반 삽입 로직 필요 |

---

## 4. 작업 범위

### In Scope

- `ImmersiveSpace` 안에서 박스 entity를 직접 생성/표시
- 기존 travel case asset 로딩 재사용
- entity tap으로 open/close animation 유지
- 박스 entity의 위치/회전/식별자 관리 구조 설계
- world anchor 또는 최소한 world transform 저장/복원 검증
- `OrganizerBox`와 entity instance를 연결할 수 있는 ID 흐름 정리
- 이후 `MemoItem.containerBoxID`를 사용할 수 있는 기반 마련

### Out of Scope

- CloudKit 동기화
- 여러 사용자 공유 anchor
- 최종 UX polish
- 완성형 drag/drop memo insertion
- window 기반 박스 구조 즉시 삭제
- 별도 `Close` animation asset 제작

---

## 5. 구현 단계

### Phase A — Entity-Only Workspace 만들기

**목표**: 박스를 volumetric window가 아니라 `ImmersiveSpace` 안의 RealityKit entity로 표시한다.

**작업**:
- `WorkspaceRealityView` 또는 유사한 이름의 새 View를 만든다.
- 기존 `PlaneOverlayView`/`ImmersiveSpace` 흐름 안에서 RealityKit content를 관리한다.
- `Entity(named: "TravelCaseScene", in: realityKitContentBundle)` 로딩 코드를 재사용한다.
- 로딩된 entity에 scale, position, rotation 기본값을 적용한다.
- ControlPanel의 "박스 생성" 액션이 `openWindow` 대신 workspace state에 박스 생성을 요청하도록 실험 경로를 만든다.

**수정 후보 파일**:
- `DesktopOrganizer/App/DesktopOrganizerApp+Scenes.swift`
- `DesktopOrganizer/Views/PlaneOverlayView.swift`
- `DesktopOrganizer/Views/ControlPanelView.swift`
- 신규: `DesktopOrganizer/Views/WorkspaceRealityView.swift`
- 신규 후보: `DesktopOrganizer/Services/WorkspaceEntityStore.swift`

**완료 조건**:
- 앱 실행 후 ImmersiveSpace 안에 travel case entity가 보인다.
- 기존 ControlPanel은 유지된다.
- 박스 생성 버튼으로 entity 박스를 하나 이상 만들 수 있다.
- 기존 volumetric box window 흐름은 비교용으로 남겨둘 수 있다.

---

### Phase B — Entity Input + Open/Close Animation 이식

**목표**: 기존 `BoxVolumeView`의 tap/open/close 로직을 entity-only 구조로 옮긴다.

**작업**:
- entity hierarchy에 `InputTargetComponent`를 부여한다.
- collision shape를 생성한다.
- targeted tap gesture 또는 RealityKit input event를 workspace view에서 처리한다.
- `Open` animation resource를 entity별로 보관한다.
- open은 정방향 재생, close는 현재 검증된 수동 time scrubbing 방식을 우선 사용한다.

**완료 조건**:
- 공간에 놓인 entity 박스를 gaze + pinch 또는 tap gesture로 선택할 수 있다.
- 첫 클릭은 열림.
- 열린 상태에서 다시 클릭하면 닫힘.
- 빠른 연속 클릭 중 animation state가 깨지지 않는다.

---

### Phase C — World Anchor / 위치 복원 검증

**목표**: 박스가 실제 공간의 특정 위치에 고정될 수 있는지 검증한다.

**작업**:
- `OrganizerBox`에 필요한 위치/회전 저장 필드를 현재 구조와 비교한다.
- world anchor를 생성하고 박스 entity와 연결하는 실험 코드를 작성한다.
- anchor identifier와 `OrganizerBox.id`를 연결할 방법을 정한다.
- 앱 재실행 또는 scene 재진입 후 박스를 같은 위치에 복원할 수 있는지 확인한다.
- Simulator 한계와 실기기 필수 체크 항목을 문서화한다.

**수정 후보 파일**:
- `DesktopOrganizer/Models/OrganizerBox.swift`
- `DesktopOrganizer/Services/PlaneDetectionService.swift`
- 신규 후보: `DesktopOrganizer/Services/WorldAnchorStore.swift`
- 신규 후보: `DesktopOrganizer/Services/WorkspaceEntityStore.swift`

**완료 조건**:
- 박스 entity의 transform 또는 anchor 참조가 SwiftData 모델과 연결된다.
- 앱 재실행 후 박스를 복원하는 최소 흐름이 있다.
- Vision Pro 실기기에서 확인해야 할 체크리스트가 남는다.

---

### Phase D — 박스 상태 모델화

**목표**: 박스 open/close/selected/animating 상태를 View 내부가 아니라 상태 객체가 관리한다.

**작업**:
- `BoxInteractionState` 또는 `WorkspaceEntityStore` 안에 박스별 상태를 둔다.
- 상태 key는 `OrganizerBox.id` 또는 stable UUID를 사용한다.
- 상태 예시는 다음과 같다.

```swift
enum BoxInteractionMode {
    case closed
    case opening
    case openForLookup
    case openForInsertion
    case closing
}
```

**완료 조건**:
- 박스 entity가 여러 개여도 각각의 열림/닫힘 상태를 구분할 수 있다.
- tap lookup과 memo insertion이 같은 `open` 상태를 무분별하게 공유하지 않는다.
- view reload가 일어나도 interaction state 관리 지점이 분명하다.

---

### Phase E — MemoItem.containerBoxID 데이터 흐름

**목표**: 어떤 메모가 어떤 박스 안에 들어갔는지 실제 데이터로 연결한다.

**작업**:
- `MemoItem.containerBoxID == nil` 인 메모는 박스 밖 메모로 본다.
- `MemoItem.containerBoxID == OrganizerBox.id` 인 메모는 해당 박스 안 메모로 본다.
- ControlPanel에서 박스별 메모 목록을 조회할 수 있게 한다.
- 임시 버튼 또는 debug action으로 "이 메모를 이 박스에 넣기" 흐름을 먼저 검증할 수 있다.

**수정 후보 파일**:
- `DesktopOrganizer/Models/MemoItem.swift`
- `DesktopOrganizer/Models/OrganizerBox.swift`
- `DesktopOrganizer/Views/ControlPanelView.swift`

**완료 조건**:
- 특정 박스에 연결된 메모 목록을 UI에서 확인할 수 있다.
- 메모의 `containerBoxID` 변경이 SwiftData에 저장된다.
- 앱 재실행 후에도 박스-메모 관계가 유지된다.

---

### Phase F — 메모 넣기 / 조회 연출

**목표**: 제품 의도에 맞는 박스 열림 사용처를 구현한다.

**작업**:
- 메모가 박스 가까이 오거나 충돌하면 `openForInsertion`.
- 사용자가 손을 떼면 메모 entity/window를 숨기거나 닫고 `containerBoxID`를 업데이트한다.
- 박스가 닫힌다.
- 박스를 클릭하면 `openForLookup`.
- 박스 위에 window 형태의 메모 목록을 연다.

**완료 조건**:
- 메모 삽입과 메모 조회가 서로 다른 흐름으로 구분된다.
- 박스 열림 animation이 두 흐름에서 모두 자연스럽게 사용된다.
- 데이터상으로도 메모가 박스 안에 들어간 상태가 된다.

---

## 6. 권장 구현 순서

```text
A1. WorkspaceRealityView 생성
A2. 박스 entity 로딩/표시
A3. ControlPanel에서 entity 박스 생성 요청
B1. entity input/collision 연결
B2. open/close animation 이식
C1. 박스 transform 저장
C2. world anchor 연결 실험
C3. 실기기 복원 테스트
D1. 박스 상태 객체 도입
E1. containerBoxID 기반 박스별 메모 목록
F1. 메모 삽입 연출
F2. 박스 안 메모 조회 window
```

우선순위는 다음과 같다.

| 우선순위 | 작업 | 이유 |
|---------|------|------|
| P0 | entity-only 표시 | world anchor 전제 확인의 시작점 |
| P0 | entity tap/open/close | 기존 박스 경험을 새 구조에서 유지해야 함 |
| P1 | transform/world anchor 저장 | 실기기에서 앱의 핵심 가치를 검증 |
| P1 | 상태 모델화 | 여러 박스와 두 가지 open 목적을 분리 |
| P2 | containerBoxID 흐름 | 메모 넣기/조회 기능의 데이터 기반 |
| P2 | drag/drop insertion | UX 완성 단계 |

---

## 7. 검증 계획

### Simulator에서 가능한 검증

- 빌드 성공
- ControlPanel 표시
- ImmersiveSpace 열림
- entity 로딩/표시
- entity scale/position 기본값
- tap gesture 코드 컴파일 및 일부 입력 확인
- SwiftData 저장/조회

### Vision Pro 실기기 필수 검증

- world sensing 권한 흐름
- 실제 공간에서 박스 entity 표시
- gaze + pinch selection 정확도
- collision shape 선택 범위
- open/close animation 체감
- world anchor 생성 성공 여부
- 앱 재실행 후 anchor/위치 복원
- 책상/방 재인식 후 위치 안정성

---

## 8. 리스크와 대응

| 리스크 | 가능성 | 대응 |
|--------|--------|------|
| Simulator에서 world anchor 검증 불가 | 높음 | Simulator는 구조 검증까지만 사용하고 실기기 체크리스트를 분리 |
| 기존 volumetric window 기능과 충돌 | 중간 | 초기에는 기존 흐름을 삭제하지 않고 entity-only 실험 경로를 병렬로 둔다 |
| 여러 박스 entity 관리 복잡도 증가 | 중간 | `WorkspaceEntityStore` 같은 단일 관리 지점을 둔다 |
| animation controller가 entity별로 꼬임 | 중간 | entity ID별 controller/state를 분리 저장한다 |
| open 상태 의미가 흐려짐 | 중간 | `openForInsertion`, `openForLookup`처럼 목적이 드러나는 상태 이름을 사용한다 |
| anchor 저장 정책이 SwiftData 모델과 어긋남 | 중간 | `OrganizerBox.id`와 anchor identifier 연결 규칙을 Phase C에서 먼저 확정한다 |

---

## 9. 첫 구현 슬라이스

가장 작은 첫 작업은 다음이다.

```text
WorkspaceRealityView를 만들고,
ImmersiveSpace 안에서 TravelCaseScene entity 하나를 직접 띄운다.
```

첫 슬라이스에서는 world anchor를 바로 붙이지 않는다. 먼저 window 밖 entity 표시가 성공해야 한다.

첫 슬라이스 완료 조건:

- `xcodebuild` 성공
- 앱 실행 시 ControlPanel 유지
- ImmersiveSpace 안에 travel case entity 표시
- 기존 volumetric box window 흐름은 망가지지 않음

그 다음 두 번째 슬라이스에서 tap/open/close animation을 옮긴다.

---

## 10. Phase A-1 Implementation Note

Status: Implemented, build-verified

추가/수정 파일:

- `DesktopOrganizer/Views/WorkspaceRealityView.swift`
- `DesktopOrganizer/Views/PlaneOverlayView.swift`
- `DesktopOrganizer/App/DesktopOrganizerApp.swift`

구현 내용:

- `WorkspaceRealityView`를 새로 만들었다.
- `RealityView` 안에서 `TravelCaseScene` entity를 직접 로드한다.
- entity의 bounds를 기준으로 scale을 조정한다.
- 임시 위치 `SIMD3<Float>(0, 1.0, -1.0)`에 배치한다.
- `PlaneOverlayView`가 빈 `RealityView` 대신 `WorkspaceRealityView`를 표시하도록 연결했다.

아직 하지 않은 것:

- ControlPanel의 "박스 등장" 버튼을 entity 생성으로 전환하지 않았다.
- 기존 `BoxVolumeView` / volumetric window 흐름은 유지했다.
- world anchor는 아직 붙이지 않았다.
- entity tap/open/close animation은 아직 `WorkspaceRealityView`로 이식하지 않았다.

---

## 11. Phase A-2 Implementation Note

Status: Implemented, build-verified

추가/수정 파일:

- `DesktopOrganizer/Services/WorkspaceEntityStore.swift`
- `DesktopOrganizer/App/DesktopOrganizerApp.swift`
- `DesktopOrganizer/App/DesktopOrganizerApp+Scenes.swift`
- `DesktopOrganizer/Views/ControlPanelView.swift`
- `DesktopOrganizer/Views/WorkspaceRealityView.swift`

구현 내용:

- `WorkspaceEntityStore`를 앱 공유 상태로 추가했다.
- ControlPanel과 ImmersiveSpace가 같은 `workspaceStore` 인스턴스를 보도록 environment로 전달했다.
- ControlPanel의 "박스 등장" 버튼이 SwiftData에 `OrganizerBox`를 저장한 뒤 workspace에 entity 생성 요청을 추가하도록 변경했다.
- `WorkspaceRealityView`는 `WorkspaceEntityStore.boxRequests`를 보고 아직 렌더링하지 않은 박스 entity를 추가한다.
- 여러 번 생성했을 때 눈으로 구분할 수 있도록 새 entity는 x축으로 조금씩 떨어진 위치에 배치한다.

아직 하지 않은 것:

- 기존 저장된 박스를 앱 재실행 시 자동으로 workspace entity로 복원하지 않는다.
- entity tap/open/close animation은 아직 이식하지 않았다.
- world anchor는 아직 붙이지 않았다.

---

## 12. Phase B Implementation Note

Status: Implemented, build-verified

수정 파일:

- `DesktopOrganizer/Views/WorkspaceRealityView.swift`

구현 내용:

- workspace 박스마다 wrapper entity를 만들고 `WorkspaceBox:<UUID>` 이름을 붙였다.
- travel case 모델 계층 전체에 `InputTargetComponent`를 부여했다.
- travel case 모델에 collision shape를 생성했다.
- `TapGesture().targetedToAnyEntity()`를 `WorkspaceRealityView`에 연결했다.
- 사용자가 하위 mesh를 탭해도 parent chain을 따라 올라가 박스 UUID를 찾도록 했다.
- 박스 ID별로 entity, animation resource, animation controller, animation task, open/animating state를 분리 관리한다.
- 첫 탭은 open animation 정방향 재생, 열린 상태의 다음 탭은 기존 검증 방식과 같은 manual time scrubbing 역재생을 사용한다.

아직 하지 않은 것:

- 박스 상태를 `WorkspaceEntityStore` 같은 모델/상태 객체로 완전히 끌어올리지는 않았다.
- world anchor는 아직 붙이지 않았다.
- 박스 클릭 시 메모 목록 window를 띄우는 lookup 흐름은 아직 없다.

---

## 13. Phase B-2 Implementation Note

Status: Implemented, build-verified

수정 파일:

- `DesktopOrganizer/Views/WorkspaceRealityView.swift`

구현 내용:

- 박스 wrapper entity를 `boxRoots`에 저장한다.
- `DragGesture().targetedToAnyEntity()`를 추가했다.
- 드래그 시작 시 박스 wrapper의 시작 위치를 저장한다.
- 드래그 중 `translation3D`를 scene 좌표계로 변환해 wrapper entity position을 갱신한다.
- travel case hierarchy에 `HoverEffectComponent`를 추가해 사용자가 박스를 바라보거나 직접 가리킬 때 시각 반응이 나타나게 했다.

주의:

- 현재 구현은 "바라보면 시각적으로 반응"까지다.
- "바라보기만 하면 자동으로 열림"은 아직 구현하지 않았다.
- visionOS는 원시 gaze 위치를 앱에 직접 노출하지 않으므로, 자동 열림은 hover/dwell 이벤트를 안정적으로 받을 수 있는 별도 경로를 확인한 뒤 구현해야 한다.
