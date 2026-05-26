# Desktop Organizer 학습 로드맵

Last updated: 2026-05-25

이 문서는 Desktop Organizer 프로젝트를 통해 배울 수 있는 10가지 학습 주제를 정리한다. 앞서 6개로 줄였던 항목은 "먼저 교재화하기 좋은 순서"였고, 여기서는 장기 학습 트랙으로 10개를 모두 살린다.

## 전체 구조

| 순서 | 주제 | 핵심 질문 | 프로젝트에서 보는 곳 |
| --- | --- | --- | --- |
| 1 | visionOS 앱의 기본 구조 | window, immersive space, RealityView는 어떻게 연결되는가? | `DesktopOrganizer/App/DesktopOrganizerApp.swift`, `DesktopOrganizer/Views/ControlPanelView.swift`, `DesktopOrganizer/Views/WorkspaceRealityView.swift` |
| 2 | SwiftUI 상태 관리 | 어떤 값은 `@State`, 어떤 값은 `@Environment`, 어떤 값은 `@Query`로 다루는가? | `ControlPanelView.swift`, `WorkspaceRealityView.swift`, `WorkspaceRealityState.swift` |
| 3 | SwiftData 입문 | 저장 모델과 화면의 entity는 어떻게 연결되는가? | `OrganizerBox.swift`, `MemoItem.swift`, `ControlPanelView.swift` |
| 4 | RealityKit Entity 설계 | 박스와 메모는 어떻게 공간 오브젝트가 되는가? | `WorkspaceRealityView+Boxes.swift`, `WorkspaceRealityView+Memos.swift`, `WorkspaceRealityView+Attachments.swift` |
| 5 | Attachment vs Ornament vs Window | 공간 UI는 언제 entity에 붙이고, 언제 시스템 창으로 띄우는가? | `BoxControlAttachmentView.swift`, `BoxMemoAttachmentView.swift`, `WorkspaceRealityView+Attachments.swift` |
| 6 | Spatial Interaction | 시선, 탭, 핀치, 드래그는 entity와 어떻게 연결되는가? | `WorkspaceRealityView.swift`, `WorkspaceRealityView+Geometry.swift`, `SpatialMemoAttachmentViews.swift` |
| 7 | ARKit Plane Detection | 책상 평면은 어떻게 찾고, 사용자에게 어떻게 보여주는가? | `PlaneDetectionService.swift`, `PlaneOverlayView.swift`, `ControlPanelView.swift` |
| 8 | World Anchor와 영속성 | 앱을 다시 켰을 때 박스와 메모는 왜 원래 자리에 있어야 하는가? | `WorkspaceRealityView+Anchors.swift`, `OrganizerBox.swift`, `MemoItem.swift` |
| 9 | visionOS UX 설계 | 공간 안에서 버튼, 패널, 피드백은 어떻게 배치해야 자연스러운가? | `ControlPanelView.swift`, `BoxControlAttachmentView.swift`, `BoxMemoAttachmentView.swift`, `PlaneOverlayView.swift` |
| 10 | 리팩토링과 아키텍처 성장 | 커지는 `RealityView` 코드를 어떻게 나누고 관리하는가? | `WorkspaceRealityView.swift`, `WorkspaceRealityView+Boxes.swift`, `WorkspaceRealityView+Memos.swift`, `WorkspaceRealityState.swift` |

## 1. visionOS 앱의 기본 구조

### 배울 것

- `WindowGroup`과 `ImmersiveSpace`의 차이
- `openImmersiveSpace`, `dismissImmersiveSpace` 흐름
- SwiftUI 패널과 RealityKit 공간이 공존하는 방식
- 앱 시작, 공간 시작, 공간 종료를 사용자에게 어떻게 노출할지

### 이 프로젝트에서 중요한 이유

Desktop Organizer는 일반 iOS 앱처럼 한 화면에서 끝나지 않는다. 기본 패널은 SwiftUI window이고, 박스와 메모는 immersive space 안의 RealityKit entity다. 이 구조를 먼저 이해해야 이후의 entity, attachment, anchor 흐름이 보인다.

### 교재 산출물

`01-visionos-app-structure-guide.html`

## 2. SwiftUI 상태 관리

### 배울 것

- `@State`는 현재 view가 소유하는 화면 상태
- `@Environment`는 앱 전체에서 주입되는 서비스나 상태
- `@Query`는 SwiftData 저장소에서 읽어오는 데이터
- "저장되어야 하는 상태"와 "잠깐 보이는 상태"의 구분

### 이 프로젝트에서 중요한 이유

박스 목록, 메모 목록, 공간 시작 여부, 드래그 중인 메모, 열린 박스 창은 모두 상태지만 성격이 다르다. 이 구분이 흐려지면 버튼이 먹통이 되거나, 앱 재실행 후 위치 복원이 불안정해진다.

### 교재 산출물

`02-swiftui-state-for-spatial-apps.html`

## 3. SwiftData 입문

### 배울 것

- `@Model`
- `@Attribute(.unique)`
- 모델 관계
- 삭제 규칙
- 저장 모델과 런타임 entity의 분리

### 이 프로젝트에서 중요한 이유

`OrganizerBox`와 `MemoItem`은 앱의 실제 데이터다. RealityKit entity는 화면에 다시 만들어질 수 있지만, 저장 데이터가 정확해야 앱이 이어진다.

### 교재 산출물

`03-swiftdata-for-spatial-objects.html`

## 4. RealityKit Entity 설계

### 배울 것

- `Entity`, `ModelEntity`, attachment entity의 차이
- parent-child 구조
- `Transform`, `position`, `orientation`, `scale`
- `InputTargetComponent`, `HoverEffectComponent`, `CollisionComponent` 등 component 부착

### 이 프로젝트에서 중요한 이유

박스 아래 컨트롤, 박스 위 메모 목록, 공간에 꺼낸 메모가 따라 움직이려면 "무엇을 누구의 자식으로 붙일 것인가"가 핵심이다.

### 교재 산출물

`04-realitykit-entity-design-guide.html`

## 5. Attachment vs Ornament vs Window

### 배울 것

- SwiftUI window
- visionOS ornament
- RealityKit attachment
- entity에 붙는 UI와 시스템이 관리하는 UI의 차이
- 왜 박스 위 메모 목록은 attachment가 더 적합한가

### 이 프로젝트에서 중요한 이유

초기 window/volume 방식에서는 박스를 움직여도 창이 따라오지 않는 문제가 있었다. 이 프로젝트는 그 문제를 통해 공간 UI의 소속 관계를 배우기 좋다.

### 교재 산출물

`05-attachment-ornament-window-guide.html`

## 6. Spatial Interaction

### 배울 것

- 시선 hover
- tap gesture
- pinch/drag gesture
- attachment 안의 메모를 복제해서 공간으로 꺼내는 흐름
- 2D gesture와 3D 공간 좌표 변환

### 이 프로젝트에서 중요한 이유

이 앱은 버튼만 누르는 앱이 아니라, 공간 속 물체를 보고 잡고 움직이는 앱이다. 사용자가 "내가 무엇을 보고 있는지", "무엇을 잡았는지", "어디에 놓았는지"를 시각적으로 알 수 있어야 한다.

### 교재 산출물

`06-spatial-interaction-guide.html`

## 7. ARKit Plane Detection

### 배울 것

- ARKit session과 provider의 역할
- 책상 평면 후보를 찾는 방식
- 너무 큰 바닥면과 작은 책상면을 구분하는 기준
- 감지된 평면을 시각적으로 표시하는 UX
- 재인식 버튼이 필요한 이유

### 이 프로젝트에서 중요한 이유

앱의 최종 형태는 실행 후 눈앞의 책상을 찾고, 그 책상 위에 박스를 놓는 것이다. 공간 인식이 불안정하면 이후 기능이 모두 흔들린다.

### 교재 산출물

`07-arkit-table-plane-detection-guide.html`

## 8. World Anchor와 영속성

### 배울 것

- World Anchor가 해결하는 문제
- anchor id와 SwiftData 저장값의 연결
- 앱 재실행 후 anchor 복원
- Simulator와 실기기 차이
- anchor 삭제와 데이터 초기화의 관계

### 이 프로젝트에서 중요한 이유

박스와 메모는 "이번 실행에서만 보이는 물체"가 아니라 사용자의 책상 위에 남아 있어야 하는 작업 공간이다. 그래서 위치 저장과 anchor 복원이 핵심 기능이다.

### 교재 산출물

`08-world-anchor-persistence-guide.html`

## 9. visionOS UX 설계

### 배울 것

- 공간에서 버튼을 어디에 붙일 것인가
- 삭제, 닫기, 고정 같은 위험/상태 버튼을 어떻게 구분할 것인가
- 책상 인식 상태를 어떻게 보여줄 것인가
- hover, highlight, selection feedback을 어떻게 줄 것인가
- 실기기 테스트에서만 보이는 UX 문제

### 이 프로젝트에서 중요한 이유

공간 앱은 기능이 있어도 사용자가 인식하지 못하면 실패한다. 특히 책상 인식, 시선 hover, 드래그 중 복제 메모, anchor 상태는 시각 피드백이 중요하다.

### 교재 산출물

`09-visionos-ux-for-spatial-tools.html`

## 10. 리팩토링과 아키텍처 성장

### 배울 것

- 처음에는 한 view에 모이던 코드가 왜 길어지는가
- extension 파일로 나눌 때의 장단점
- 상태 객체를 분리하는 기준
- feature 단위 구조와 layer 단위 구조의 차이
- 나중에 ECS로 옮길 수 있는 코드의 특징

### 이 프로젝트에서 중요한 이유

`WorkspaceRealityView`는 공간 앱의 중심이라 자연스럽게 길어진다. 이 파일을 어떻게 나누고, 어떤 책임을 상태 객체나 helper로 옮길지 보는 것은 실전 리팩토링 교재로 좋다.

### 교재 산출물

`10-spatial-app-refactoring-guide.html`

## 권장 학습 순서

초보 팀원이 처음 합류한다면 아래 순서가 가장 자연스럽다.

1. visionOS 앱의 기본 구조
2. SwiftUI 상태 관리
3. SwiftData 입문
4. RealityKit Entity 설계
5. Attachment vs Ornament vs Window
6. Spatial Interaction
7. ARKit Plane Detection
8. World Anchor와 영속성
9. visionOS UX 설계
10. 리팩토링과 아키텍처 성장

ECS는 4번 RealityKit Entity 설계 이후에 읽는 것이 좋다. 단, Swift 기본기가 약하면 `ecs-prerequisites-guide.html`을 먼저 읽는다.

## 현재 이미 있는 관련 교재

- `Workbooks/swift/ecs-prerequisites-guide.html`
- `Workbooks/swift/entity-component-system-architecture-guide.html`
- `Workbooks/swift/visionos-spatial-ui-implementation-patterns.html`
- `Workbooks/swift/visionOS-space-volume-entity.html`
- `Workbooks/swift/SwiftData_101.html`
- `Workbooks/swift/Swift_101.html`

## 다음에 만들면 좋은 교재

가장 먼저 만들 교재는 `01-visionos-app-structure-guide.html`이 좋다. 이유는 이 주제가 나머지 9개 주제의 입구이기 때문이다.
