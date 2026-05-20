# Sprint 2 Fixes — Plan

Last updated: 2026-05-19
Phase: Plan
Feature: sprint2-fixes

---

## Executive Summary

| 항목 | 내용 |
|------|------|
| Feature | Sprint 2 수정 및 개선 4건 |
| 기반 | Desktop Organizer MVP (sprint1 완료 상태) |

### Value Delivered

| 관점 | 내용 |
|------|------|
| **Problem** | 박스 잘림, 재빌드 시 버튼 불작동, App.swift 가독성 저하, 데이터 초기화 수단 없음 |
| **Solution** | RealityView 전환으로 잘림 근본 해결 + ImmersiveSpace 관리 개선 + 앱 구조 정리 + 삭제 버튼 |
| **Function UX Effect** | 박스가 온전히 표시, 재빌드 후 즉시 버튼 동작, 각 화면 캔버스 확인 가능 |
| **Core Value** | 개발 안정성과 시뮬레이터 테스트 효율 확보 |

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | MVP 빌드는 됐지만 박스 잘림·재빌드 불안정 문제로 실질 검증이 막혀있음 |
| **WHO** | BK (iOS 입문, 애플 아카데미 C3 프로젝트) |
| **RISK** | RealityView entity 로딩 방식이 Model3D와 다를 수 있음 / ImmersiveSpace 관리 복잡도 |
| **SUCCESS** | 박스 잘림 없음 + 재빌드 후 버튼 즉시 동작 + 각 View Preview 동작 |
| **SCOPE** | 4건 개선. 박스-메모 관계(Sprint 3)는 포함 안 함 |

---

## 1. 작업 목록

### A. 데이터 초기화 버튼

**목표**: ControlPanel에 전체 데이터(OrganizerBox + MemoItem) 삭제 버튼 추가

**구현**:
- ControlPanelView 하단에 "초기화" 버튼 추가
- 탭 시 확인 Alert 표시 ("박스와 메모가 전부 삭제됩니다. 계속할까요?")
- 확인 시 `@Query`로 읽은 boxes/memos를 전부 `modelContext.delete()` + `save()`
- `#if DEBUG` 조건 컴파일로 감싸서 릴리즈 빌드에서는 숨김

**수정 파일**:
- `ControlPanelView.swift`

**완료 조건**:
- 버튼 탭 → Alert → 확인 → 박스/메모 목록이 비워짐
- 앱 재실행 후에도 데이터 없는 상태 유지

---

### B. BoxVolumeView — Model3D → RealityView + Entity 전환

**목표**: `Model3D`의 window 크기 의존성 문제를 제거하고 entity를 코드로 직접 제어

**현재 문제**:
- `Model3D`는 내부 렌더링 크기를 직접 제어할 수 없음
- `defaultSize`와 실제 모델 크기 불일치 → 잘림 발생
- `windowResizability(.contentSize)`와 `defaultSize`가 충돌

**전환 방향**:
```swift
// 기존
Model3D(named: "TravelCaseScene", bundle: realityKitContentBundle)

// 변경
RealityView { content in
    if let entity = try? await Entity(named: "TravelCaseScene",
                                      in: realityKitContentBundle) {
        // bounding box 측정 후 window에 맞게 scale 조정
        let bounds = entity.visualBounds(relativeTo: nil)
        let maxExtent = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        if maxExtent > 0 {
            entity.scale = SIMD3<Float>(repeating: 0.8 / maxExtent)
        }
        content.add(entity)
    }
}
```

**장점**:
- entity scale을 런타임에 bounding box 기준으로 자동 계산
- window 크기와 독립적으로 모델 크기 제어 가능
- drag 회전 gesture는 `RealityView` 위에 `.gesture()` modifier로 유지

**수정 파일**:
- `BoxVolumeView.swift`

**완료 조건**:
- Simulator에서 박스 volumetric window 생성 시 모델이 잘리지 않음
- drag 회전 동작 유지

---

### C. 재빌드 시 버튼 불작동 근본 해결

**목표**: Simulator 재시동 없이 재빌드해도 버튼이 즉시 동작

**현재 문제 분석**:
- `UIApplicationSupportsMultipleScenes: true` → scene session restoration
- scene restoration이 ImmersiveSpace를 자동 복원하면서 App의 `.task`에서 또 `openImmersiveSpace` 호출 → 충돌
- window/input 시스템이 불안정 상태 → 버튼 불응

**해결 방향 — ImmersiveSpace 관리를 App 레벨로 이동**:

현재 `ControlPanelView.task`에서 열던 것을 `DesktopOrganizerApp`의 Scene 변화 감지로 이동:

```swift
// DesktopOrganizerApp.swift
WindowGroup {
    ControlPanelView()
}
.onChange(of: openedSpaceID) { ... }
```

또는 `@Environment(\.scenePhase)`를 `WindowGroup` modifier로 관찰해서 처리.

**대안**: ControlPanel 내 명시적 "공간 인식 시작" 버튼으로 UX 변경 (자동 열기 제거).
- 사용자가 버튼을 눌러야 ImmersiveSpace가 열림
- 자동 scene restoration과 충돌 없음
- 단, UX 변경이므로 설계 단계에서 선택 필요

**수정 파일**:
- `ControlPanelView.swift`
- `DesktopOrganizerApp.swift`

**완료 조건**:
- Simulator를 종료하지 않고 재빌드 후 박스/메모 생성 버튼이 즉시 동작

---

### D. DesktopOrganizerApp.swift 정리 + AppPreview.swift

**목표**: App.swift 가독성 개선 + 주요 화면을 캔버스에서 탐색 가능한 Preview 제작

**D1. App.swift 정리**:
- Scene 등록 코드를 각 Scene별 `extension DesktopOrganizerApp` 또는 명시적 주석 섹션으로 분리
- App body는 "Scene 목록" 역할에 집중, modifier 체인을 줄임

**D2. AppPreview.swift 제작**:
```swift
// AppPreview.swift — 캔버스 전용, 앱 빌드에는 포함되지 않음
#if DEBUG
struct AppPreviewContainer: View {
    var body: some View {
        TabView {
            ControlPanelView()
                .tabItem { Label("Control", systemImage: "slider.horizontal.3") }
                .modelContainer(for: [OrganizerBox.self, MemoItem.self], inMemory: true)
                .environment(PlaneDetectionService())

            BoxVolumeView(payload: BoxPayload(name: "Preview Box"))
                .tabItem { Label("Box", systemImage: "shippingbox") }

            MemoEditorSheet()
                .tabItem { Label("Memo Editor", systemImage: "square.and.pencil") }
                .modelContainer(for: [OrganizerBox.self, MemoItem.self], inMemory: true)

            MemoLabelView(memo: .constant(MemoLabel(text: "메모 미리보기")))
                .disabled(true)
                .tabItem { Label("Memo Label", systemImage: "note.text") }
        }
    }
}

#Preview(windowStyle: .automatic) {
    AppPreviewContainer()
}
#endif
```

**수정/추가 파일**:
- `DesktopOrganizer/App/DesktopOrganizerApp.swift` (정리)
- `DesktopOrganizer/App/AppPreview.swift` (신규)

**완료 조건**:
- Xcode 캔버스에서 `AppPreview.swift` 열면 ControlPanel, BoxVolume, MemoEditor, MemoLabel 4개 화면 탐색 가능
- App.swift가 100줄 이하로 정리됨

---

## 2. 구현 순서

```
A (데이터 초기화) → D1 (App.swift 정리) → D2 (AppPreview.swift) → B (RealityView 전환) → C (ImmersiveSpace 개선)
```

**순서 이유**:
- A는 독립적이고 단순해서 먼저 완료
- D는 코드 정리라 B/C 작업 전에 하면 충돌 없이 깔끔
- B가 C보다 범위가 명확하므로 먼저
- C는 설계에서 접근 방식을 결정해야 하므로 마지막

---

## 3. Success Criteria

| SC | 기준 |
|----|------|
| SC-A | ControlPanel에 초기화 버튼 → Alert → 확인 → 데이터 전부 삭제 |
| SC-B | Simulator에서 박스 volumetric window 생성 시 모델 잘림 없음 |
| SC-B2 | drag 회전 동작 유지 |
| SC-C | Simulator 재시동 없이 재빌드 후 버튼 즉시 동작 |
| SC-D1 | DesktopOrganizerApp.swift 100줄 이하 정리 |
| SC-D2 | AppPreview.swift 캔버스에서 4개 화면 탐색 가능 |

---

## 4. 리스크

| 리스크 | 가능성 | 대응 |
|--------|--------|------|
| `Entity(named:in:)` async 초기화가 `@MainActor` 제약과 충돌 | 중간 | `RealityView` make 클로저 내 `async`이므로 정상. 실패 시 `ModelEntity.loadModel` 대안 |
| `visualBounds` 계산이 entity 로딩 전에 실행 | 중간 | `update:` 클로저에서 bounds 재계산하거나 `onAppear` 활용 |
| C (ImmersiveSpace) 해결책이 또 다른 부작용 | 높음 | 설계 단계에서 "자동 열기 제거" vs "App 레벨 이동" 중 선택 후 진행 |
| AppPreview.swift의 일부 View가 앱 환경 없이 크래시 | 낮음 | `inMemory: true` modelContainer + PlaneDetectionService mock으로 격리 |

---

## 5. Out of Scope

- 박스-메모 관계 (넣기/꺼내기) — Sprint 3
- ARKit plane 위치 기반 실제 box window 배치 (OPEN-01)
- WorldAnchor persistence
- Vision Pro 실기기 검증
