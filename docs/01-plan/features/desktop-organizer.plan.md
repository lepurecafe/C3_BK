# Desktop Organizer — Plan

Last updated: 2026-05-19
Phase: Plan
Feature: desktop-organizer

---

## Executive Summary

| 항목 | 내용 |
|------|------|
| Feature | Desktop Organizer MVP |
| 시작일 | 2026-05-19 |
| 목표 완료 | 미정 (Phase별 순차 진행) |

### Value Delivered (4 perspectives)

| 관점 | 내용 |
|------|------|
| **Problem** | visionOS 공간에서 메모와 오브젝트를 현실 책상 위에 자연스럽게 배치·정리하는 수단이 없다 |
| **Solution** | ARKit으로 책상을 인식하고, 박스(3D volumetric)와 메모(plain label)를 공간 오브젝트로 생성·관리한다 |
| **Function UX Effect** | 작은 ControlPanel에서 버튼 두 번으로 공간 오브젝트를 생성, 메모는 LabelMaker 방식으로 직관적으로 작성 |
| **Core Value** | 현실 책상과 연동된 visionOS 공간 정리 경험의 최소 동작 루프를 검증한다 |

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | visionOS 공간 정리 앱의 핵심 상호작용(박스·메모 생성, ARKit 책상 인식)이 성립하는지 검증 |
| **WHO** | BK (iOS 입문, 애플 아카데미 C3 프로젝트) |
| **RISK** | ARKit plane detection이 Simulator에서 제한적 / RealityKitContent 패키지 연결 복잡도 |
| **SUCCESS** | 앱 실행 → 책상 인식 → 박스/메모 생성 → 재실행 후 복원까지 전체 흐름이 crash 없이 동작 |
| **SCOPE** | 생성·표시·영속성까지. 박스-메모 관계(넣기/꺼내기)는 Sprint 2 |

---

## 1. Feature Overview

### 1.1 앱 목표

visionOS 공간 안에서 다음 최소 흐름이 동작하는지 검증한다.

1. 앱 실행 → ARKit이 자동으로 공간 인식 시작
2. ControlPanel이 책상(horizontal plane) 감지 상태를 표시
3. "박스 생성" 버튼 → 감지된 책상 위에 1890s_Travel_Case volumetric window 생성
4. "메모 생성" 버튼 → 메모 작성 창 열기 (텍스트 + 색상 + 모서리 조절)
5. Create 버튼 → 메모가 plain window 라벨로 공간에 생성
6. 앱 재실행 → ControlPanel 목록에서 이전 박스/메모를 다시 열 수 있음

### 1.2 참조 프로젝트

| 프로젝트 | 경로 | 차용하는 것 |
|---------|------|------------|
| Vision_002_LabelMaker | `/Users/bk/DEV/Vision_002_LabelMaker` | 메모: plain window, contentSize, LabelView 구조 |
| Vision_003_SeaCreatures | `/Users/bk/DEV/Vision_003_SeaCreatures` | 박스: volumetric window, Model3D, RealityKitContent Package 구조 |

### 1.3 에셋

- `1890s_Travel_Case.usdz` — 현재 `/Users/bk/DEV/C3_BK/` 에 위치
- MVP 완료 후 `Packages/RealityKitContent/Sources/.../TravelCase/` 로 이동

---

## 2. Requirements

### 2.1 ARKit Plane Detection (B Phase)

| ID | 요구사항 |
|----|---------|
| R-B1 | 앱 실행 즉시 ARKit으로 horizontal plane 감지를 자동 시작한다 |
| R-B2 | ControlPanel 상단에 감지 상태를 표시한다 ("감지 중..." / "책상 감지됨 ✓") |
| R-B3 | `NSWorldSensingUsageDescription` 권한 요청이 뜬다 |
| R-B4 | ImmersiveSpace(.mixed) 방식으로 일반 창과 공존한다 |

### 2.2 ControlPanel Window (공통)

| ID | 요구사항 |
|----|---------|
| R-CP1 | 앱 실행 시 작은 ControlPanel 창 하나만 열린다 |
| R-CP2 | ControlPanel은 windowResizability(.contentSize)로 최소 크기를 유지한다 |
| R-CP3 | "박스 생성" 버튼과 "메모 생성" 버튼 2개만 배치한다 |

### 2.3 박스 (C Phase)

| ID | 요구사항 |
|----|---------|
| R-C1 | "박스 생성" → 감지된 책상 위 위치에 volumetric window 생성 |
| R-C2 | BoxVolumeView는 `Model3D(named: "TravelCaseScene", bundle: realityKitContentBundle)` 로 1890s_Travel_Case 표시 |
| R-C3 | BoxVolumeView에서 drag gesture로 박스를 회전할 수 있다 (SeaCreatureDetailView 동일 구조) |
| R-C4 | 책상이 아직 감지되지 않은 경우 사용자 앞 기본 위치에 fallback으로 배치 |

### 2.4 메모 (D Phase)

| ID | 요구사항 |
|----|---------|
| R-D1 | "메모 생성" 버튼 → 메모 작성 창(편집 모드 ControlPanel 내 시트 또는 별도 창) 열기 |
| R-D2 | 메모 작성 창: TextField(multiline) + 색상 선택(4가지) + cornerRadius Slider |
| R-D3 | "Create" 버튼 → `openWindow(value: memoLabel)` 로 plain window 생성 |
| R-D4 | 생성된 메모 창: `.windowStyle(.plain)` + `.windowResizability(.contentSize)` |
| R-D5 | LabelMaker의 LabelView와 동일한 텍스트·배경 스타일 |

### 2.5 SwiftData 영속성 (E Phase)

| ID | 요구사항 |
|----|---------|
| R-E1 | `OrganizerBox`, `MemoItem` SwiftData 모델로 저장 |
| R-E2 | 재실행 후 ControlPanel 하단 목록에 이전 박스/메모가 표시됨 |
| R-E3 | 목록 항목 탭 → `openWindow` 로 해당 박스/메모 창 다시 열기 |

---

## 3. Success Criteria

| SC | 기준 |
|----|------|
| SC-1 | 앱 실행 후 ControlPanel이 crash 없이 열린다 |
| SC-2 | 공간 인식 권한 요청이 자동으로 뜬다 |
| SC-3 | 책상 감지 상태가 ControlPanel 상단에 업데이트된다 |
| SC-4 | "박스 생성" → volumetric window에 1890s_Travel_Case 3D 모델이 표시된다 |
| SC-5 | BoxVolumeView에서 drag로 박스를 회전할 수 있다 |
| SC-6 | "메모 생성" → 작성 창이 열리고, 텍스트/색상/모서리를 조절할 수 있다 |
| SC-7 | Create → plain label window가 열린다 |
| SC-8 | 재실행 후 ControlPanel 목록에서 박스/메모를 다시 열 수 있다 |

---

## 4. Implementation Phases

각 Phase는 독립적으로 빌드·검증 후 다음 단계 진행.

### Phase A — 프로젝트 뼈대

| 단계 | 작업 | 완료 조건 |
|------|------|---------|
| A1 | `project.yml` + XcodeGen으로 visionOS 프로젝트 생성 | `xcodebuild build` 성공 |
| A2 | `Packages/RealityKitContent` 구성 + 1890s_Travel_Case.usdz 배치 + TravelCaseScene.usda 작성 | 빌드 성공, 패키지 링크 오류 없음 |

### Phase B — ARKit Plane Detection

| 단계 | 작업 | 완료 조건 |
|------|------|---------|
| B1 | `PlaneDetectionService` (@Observable) + `ImmersiveSpace` 등록 + Info.plist 권한 추가 | 빌드 성공 |
| B2 | ControlPanel `.task { openImmersiveSpace }` 연결 + 감지 상태 상단 표시 | 앱 실행 시 권한 팝업 + 상태 텍스트 업데이트 |

### Phase C — 박스 Volumetric Window

| 단계 | 작업 | 완료 조건 |
|------|------|---------|
| C1 | `BoxPayload` 모델 + `WindowGroup(id: "boxWindow", for: BoxPayload.self)` 등록 | 빌드 성공 |
| C2 | `BoxVolumeView`: Model3D + drag 회전 gesture | 박스 생성 버튼 → volumetric window 열림 + 3D 모델 표시 + 드래그 회전 동작 |

### Phase D — 메모 Plain Window

| 단계 | 작업 | 완료 조건 |
|------|------|---------|
| D1 | `MemoLabel` 모델 + `WindowGroup(for: MemoLabel.self)` 등록 | 빌드 성공 |
| D2 | `MemoLabelView` (LabelView 구조 동일) | 빌드 성공 |
| D3 | ControlPanel "메모 생성" → sheet로 작성 창 열기 → Create → `openWindow(value:)` | 메모 작성 → plain window 라벨 생성 동작 |

### Phase E — SwiftData 영속성

| 단계 | 작업 | 완료 조건 |
|------|------|---------|
| E1 | `OrganizerBox`, `MemoItem` @Model + `.modelContainer` 연결 | 빌드 성공, crash 없음 |
| E2 | `@Query` 목록 + 재열기 액션 | 재실행 후 이전 박스/메모 목록에서 창 다시 열기 성공 |

### 구현 순서 요약

```
A1 → A2 → B1 → B2 → C1 → C2 → D1 → D2 → D3 → E1 → E2
```

---

## 5. Risk & Constraints

| 위험 | 가능성 | 대응 |
|------|--------|------|
| ARKit plane detection이 Simulator에서 미작동 | 높음 | B2 완료 기준을 "권한 팝업 뜸"으로 제한. 실제 감지는 Vision Pro 디바이스에서 확인 |
| RealityKitContent 로컬 패키지 XcodeGen 연결 실패 | 중간 | project.yml `packages` 섹션으로 시도, 실패 시 수동 xcodeproj 편집 |
| `Model3D(named:bundle:)` 로딩 실패 | 중간 | TravelCaseScene.usda scale 조정 + ClamScene.usda 구조 그대로 복사 |
| ImmersiveSpace + WindowGroup 공존 문제 | 낮음 | `.immersionStyle(.mixed)` 사용, 창이 숨겨지면 사용 흐름 재검토 |

---

## 6. Out of Scope (MVP 이후)

- 박스-메모 관계 (메모를 박스에 넣기/꺼내기)
- 메모 위치 기억 (WorldAnchor persistence)
- 박스 open/close 인터랙션
- Scene Reconstruction / 메시 충돌
- CloudKit 동기화
- 손가락 끝 추적 (HandTrackingProvider)
- Reality Composer Pro 고급 에셋

---

## 7. 기술 스택

| 항목 | 선택 |
|------|------|
| Platform | visionOS 26 |
| Language | Swift 6 |
| UI | SwiftUI |
| 3D | RealityKit + Model3D |
| 에셋 관리 | Packages/RealityKitContent (로컬 Swift Package) |
| 공간 인식 | ARKit — PlaneDetectionProvider(.horizontal) |
| 영속성 | SwiftData |
| 프로젝트 생성 | XcodeGen (project.yml) |
