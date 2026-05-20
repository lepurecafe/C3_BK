# Sprint 2 Fixes — Design

Last updated: 2026-05-19
Phase: Design
Feature: sprint2-fixes
Architecture: 각 Phase 독립 수정 (Option A for Phase C)

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | MVP 빌드는 됐지만 박스 잘림·재빌드 불안정으로 실질 검증이 막혀있음 |
| **WHO** | BK (iOS 입문, 애플 아카데미 C3 프로젝트) |
| **RISK** | RealityView entity 로딩 async 처리 / ImmersiveSpace 수동 버튼 UX 변경 |
| **SUCCESS** | 박스 잘림 없음 + 재빌드 후 버튼 즉시 동작 + 각 View Preview 동작 |
| **SCOPE** | 4건 독립 수정. 박스-메모 관계는 미포함 |

---

## 1. 파일 변경 매트릭스

| 파일 | A | B | C | D1 | D2 |
|------|---|---|---|----|----|
| `ControlPanelView.swift` | ✦ | | ✦ | | |
| `BoxVolumeView.swift` | | ✦ | | | |
| `DesktopOrganizerApp.swift` | | | | ✦ | |
| `AppPreview.swift` (신규) | | | | | ✦ |

✦ = 해당 Phase에서 수정

---

## 2. Phase A — 데이터 초기화 버튼

### 수정 파일
`DesktopOrganizer/Views/ControlPanelView.swift`

### 추가 State
```swift
@State private var showResetAlert = false
```

### 버튼 추가 위치
ControlPanel body의 `VStack` 맨 아래, `#if DEBUG` 조건 컴파일로 감쌈:

```swift
#if DEBUG
Divider()
Button("데이터 초기화", role: .destructive) {
    showResetAlert = true
}
.font(.caption)
.foregroundStyle(.red)
#endif
```

### Alert
```swift
.alert("데이터 초기화", isPresented: $showResetAlert) {
    Button("취소", role: .cancel) {}
    Button("전부 삭제", role: .destructive) {
        resetAllData()
    }
} message: {
    Text("저장된 박스와 메모가 전부 삭제됩니다.")
}
```

### resetAllData() 구현
```swift
private func resetAllData() {
    boxes.forEach { modelContext.delete($0) }
    memos.forEach { modelContext.delete($0) }
    do {
        try modelContext.save()
    } catch {
        storageErrorMessage = error.localizedDescription
    }
}
```

> `boxes`, `memos`는 이미 `@Query`로 선언되어 있으므로 별도 fetch 불필요.

---

## 3. Phase B — BoxVolumeView RealityView + Entity 전환

### 수정 파일
`DesktopOrganizer/Views/BoxVolumeView.swift`

### 핵심 변경: Model3D → RealityView

```swift
import RealityKit
import RealityKitContent
import SwiftUI

struct BoxVolumeView: View {
    let payload: BoxPayload?

    @State private var horizontalRotation = CGFloat.zero
    @State private var verticalRotation = CGFloat.zero
    @State private var endHorizontalRotation = CGFloat.zero
    @State private var endVerticalRotation = CGFloat.zero

    var body: some View {
        RealityView { content in
            guard let entity = try? await Entity(named: "TravelCaseScene",
                                                 in: realityKitContentBundle) else { return }
            // entity bounding box 기준으로 window 안에 꼭 맞게 scale 조정
            let bounds = entity.visualBounds(relativeTo: nil)
            let maxExtent = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
            if maxExtent > 0 {
                let targetSize: Float = 0.35  // 목표 최대 축 길이(meters)
                entity.scale = SIMD3<Float>(repeating: targetSize / maxExtent)
            }
            content.add(entity)
        }
        .rotation3DEffect(.degrees(horizontalRotation), axis: .y)
        .rotation3DEffect(.degrees(-verticalRotation), axis: .x)
        .gesture(
            DragGesture()
                .onChanged { value in
                    horizontalRotation = value.translation.width + endHorizontalRotation
                    verticalRotation = value.translation.height + endVerticalRotation
                }
                .onEnded { _ in
                    endHorizontalRotation = horizontalRotation
                    endVerticalRotation = verticalRotation
                }
        )
    }
}

#Preview(windowStyle: .volumetric) {
    BoxVolumeView(payload: BoxPayload(name: "Preview Box"))
}
```

### DesktopOrganizerApp.swift defaultSize 조정
RealityView + entity로 전환 후 window 크기를 entity scale에 맞춰 조정:

```swift
.defaultSize(width: 0.6, height: 0.6, depth: 0.6, in: .meters)
```

> `targetSize: 0.35`이면 entity는 최대 0.35m이므로 0.6m window에 여유있게 들어감.
> 실제 실행 후 크기 확인하고 조정 가능.

### 설계 이유
- `Model3D`는 내부 렌더링 크기를 코드로 제어할 수 없어 window와 불일치 발생
- `RealityView + Entity`는 `visualBounds`로 bounding box를 런타임에 계산하여 scale 자동 조정
- 어떤 usdz 모델이 들어와도 window 안에 맞게 표시됨

---

## 4. Phase C — ImmersiveSpace 수동 버튼으로 전환

### 수정 파일
`DesktopOrganizer/Views/ControlPanelView.swift`

### 제거
```swift
// 제거
.task {
    guard !isSensingOpen else { return }
    isSensingOpen = true
    let result = await openImmersiveSpace(id: "sensing")
    ...
}
```

`@State private var isSensingOpen = false` — 유지 (버튼 상태 관리에 계속 사용)

### 상태 표시 개선
planeService.statusText 위에 공간 인식 상태를 더 명확하게 표시:

```swift
// 기존 상태 텍스트 + 인식 시작 버튼을 함께 구성
VStack(spacing: 8) {
    HStack(spacing: 8) {
        // 감지 상태 인디케이터
        Circle()
            .fill(isSensingOpen ? .green : .gray)
            .frame(width: 8, height: 8)
        Text(planeService.statusText)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    if !isSensingOpen {
        Button("공간 인식 시작") {
            startSensing()
        }
        .buttonStyle(.bordered)
        .font(.caption)
    }
}
```

### startSensing() 구현
```swift
private func startSensing() {
    guard !isSensingOpen else { return }
    isSensingOpen = true
    Task {
        let result = await openImmersiveSpace(id: "sensing")
        switch result {
        case .opened:
            break
        case .userCancelled, .error:
            isSensingOpen = false
            planeService.statusText = "공간 인식 시작 실패"
        @unknown default:
            isSensingOpen = false
        }
    }
}
```

### 설계 이유
- `.task` 자동 열기를 제거하면 scene restoration과의 충돌 원천 차단
- 사용자가 버튼을 누를 때만 열리므로 재빌드 후 scene이 안정화된 뒤에 열기 가능
- `isSensingOpen` 상태가 시각적으로 표시되어 공간 인식 상태를 한눈에 확인

---

## 5. Phase D1 — DesktopOrganizerApp.swift 정리

### 수정 파일
`DesktopOrganizer/App/DesktopOrganizerApp.swift`

### 목표
- 현재 단일 body에 모든 Scene modifier가 나열된 구조를 extension으로 분리
- App.swift 자체는 Scene 목록만 선언, modifier 체인은 `makeXxxScene()` 헬퍼로 추출

### 구조

```swift
// DesktopOrganizerApp.swift — Scene 목록만
@main
struct DesktopOrganizerApp: App {
    @State private var planeService = PlaneDetectionService()

    var body: some Scene {
        controlPanelScene
        boxWindowScene
        memoWindowScene
        sensingSpaceScene
    }
}
```

```swift
// DesktopOrganizerApp+Scenes.swift — Scene 헬퍼
extension DesktopOrganizerApp {
    var controlPanelScene: some Scene {
        WindowGroup {
            ControlPanelView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 200)
        .modelContainer(for: [OrganizerBox.self, MemoItem.self])
        .environment(planeService)
    }

    var boxWindowScene: some Scene {
        WindowGroup(id: "boxWindow", for: BoxPayload.self) { $payload in
            BoxVolumeView(payload: payload)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.6, height: 0.6, depth: 0.6, in: .meters)
    }

    var memoWindowScene: some Scene {
        WindowGroup(for: MemoLabel.self) { $memo in
            MemoLabelView(memo: $memo).disabled(true)
        } defaultValue: {
            MemoLabel(text: "")
        }
        .windowResizability(.contentSize)
        .windowStyle(.plain)
    }

    var sensingSpaceScene: some Scene {
        ImmersiveSpace(id: "sensing") {
            PlaneOverlayView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .environment(planeService)
    }
}
```

### 추가 파일
`DesktopOrganizer/App/DesktopOrganizerApp+Scenes.swift` (신규)

> `some Scene`은 SwiftUI Scene protocol을 따르는 타입이라 computed property로 반환 가능.

---

## 6. Phase D2 — AppPreview.swift

### 추가 파일
`DesktopOrganizer/App/AppPreview.swift`

```swift
#if DEBUG
import SwiftData
import SwiftUI

// 앱의 주요 화면을 캔버스에서 탐색하기 위한 Preview 전용 컨테이너입니다.
// 실제 앱 빌드에는 포함되지 않습니다(#if DEBUG).
//
// 사용법: 이 파일의 캔버스를 열면 하단 탭으로 4개 화면을 전환할 수 있습니다.
struct AppPreviewContainer: View {
    var body: some View {
        TabView {
            Tab("ControlPanel", systemImage: "slider.horizontal.3") {
                ControlPanelView()
                    .modelContainer(for: [OrganizerBox.self, MemoItem.self],
                                    inMemory: true)
                    .environment(PlaneDetectionService())
            }

            Tab("Box", systemImage: "shippingbox") {
                BoxVolumeView(payload: BoxPayload(name: "Preview Box"))
            }

            Tab("Memo Editor", systemImage: "square.and.pencil") {
                MemoEditorSheet()
                    .modelContainer(for: [OrganizerBox.self, MemoItem.self],
                                    inMemory: true)
            }

            Tab("Memo Label", systemImage: "note.text") {
                MemoLabelView(memo: .constant(MemoLabel(
                    text: "메모 미리보기",
                    colorIndex: 0,
                    cornerRadius: 20
                )))
                .disabled(true)
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    AppPreviewContainer()
}
#endif
```

> `Tab(_:systemImage:content:)` syntax는 visionOS 26+ / iOS 18+에서 사용 가능.
> 구버전 target이면 `.tabItem { Label(...) }` 방식으로 대체.

---

## 7. 구현 순서 (Session Guide)

| Module | Phase | 수정 파일 | 완료 조건 |
|--------|-------|---------|---------|
| M1 | A (초기화 버튼) | ControlPanelView.swift | 버튼 → Alert → 데이터 삭제 동작 |
| M2 | C (ImmersiveSpace 수동) | ControlPanelView.swift | 재빌드 후 버튼 즉시 동작 |
| M3 | D1 (App.swift 정리) | DesktopOrganizerApp.swift + Scenes.swift | 빌드 성공 + App.swift 간결화 |
| M4 | D2 (AppPreview) | AppPreview.swift | 캔버스에서 4탭 탐색 |
| M5 | B (RealityView 전환) | BoxVolumeView.swift + App defaultSize | Simulator에서 박스 잘림 없음 |

> M1, M2는 ControlPanelView를 연속 수정하므로 같은 세션에서 진행 권장.
> M5를 마지막에 두는 이유: RealityView entity 로딩은 async 이슈가 있을 수 있어 별도 검증 세션이 유리.

---

## 8. 리스크 대응

| 리스크 | 대응 |
|--------|------|
| `Entity(named:in:)` async 실패 | guard let 처리 + PlaneDetectionService.statusText에 "모델 로딩 실패" 표시 |
| `visualBounds` 값이 0으로 반환 | maxExtent > 0 가드 + 기본 scale (0.3) fallback |
| `DesktopOrganizerApp+Scenes.swift`의 computed property 타입 불일치 | `some Scene` 반환 타입 명시, 필요 시 `@SceneBuilder` 검토 |
| AppPreview.swift `Tab` 초기화 API 미지원 | 구버전 `.tabItem` 방식으로 fallback |
