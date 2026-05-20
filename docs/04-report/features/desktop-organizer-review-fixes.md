# Desktop Organizer — Code Review Fix Handoff

Last updated: 2026-05-19
Feature: desktop-organizer
Audience: Claude / Codex / future AI handoff
Status: Applied and build-verified

---

## 1. Context

Codex 코드 리뷰에서 발견된 안정성/저장/버전관리 이슈를 정리하고, 바로 수정 가능한 항목을 반영했다.

이번 문서는 다음 AI가 현재 코드 상태를 오해하지 않도록 남기는 handoff 문서다.

중요 기준:

- 설계 원칙은 `desktop-organizer.design.md` 유지
- 구현 기준 경로는 `/Users/bk/DEV/C3_BK`
- Xcode 프로젝트는 `DesktopOrganizer.xcodeproj`
- RealityKitContent는 상위 repo 안의 일반 Swift Package 폴더로 관리

---

## 2. Applied Fixes

### FIX-01 — SwiftData 저장 실패 처리

대상 파일:

- `DesktopOrganizer/Views/ControlPanelView.swift`
- `DesktopOrganizer/Views/MemoEditorSheet.swift`

이전 상태:

```swift
try? modelContext.save()
```

문제:

- 저장 실패가 발생해도 조용히 무시됨
- 사용자는 박스/메모가 저장된 줄 알 수 있음
- 재실행 후 목록 복원이 안 되면 원인을 찾기 어려움

수정:

- `do/catch`로 저장 실패 처리
- 실패 시 방금 insert한 모델을 `modelContext.delete(...)`로 되돌림
- 사용자에게 `저장 실패` alert 표시
- 저장 실패 시 window를 열지 않음

현재 동작:

```swift
do {
    try modelContext.save()
} catch {
    modelContext.delete(box)
    storageErrorMessage = error.localizedDescription
    return
}
```

메모 생성도 같은 정책으로 처리한다.

---

### FIX-02 — MemoLabel colorIndex crash 방지

대상 파일:

- `DesktopOrganizer/Models/MemoLabel.swift`

이전 상태:

```swift
MemoLabel.colors[colorIndex]
```

문제:

- 저장된 `colorIndex`가 배열 범위를 벗어나면 라벨 렌더링 중 crash 가능
- 색상 배열 변경 또는 오래된 저장 데이터와 충돌할 수 있음

수정:

```swift
guard MemoLabel.colors.indices.contains(colorIndex) else {
    return MemoLabel.colors[0]
}

return MemoLabel.colors[colorIndex]
```

현재 정책:

- 정상 index면 해당 색상 사용
- 잘못된 index면 첫 번째 색상으로 fallback

---

### FIX-03 — openImmersiveSpace error 처리 보강

대상 파일:

- `DesktopOrganizer/Views/ControlPanelView.swift`

이전 상태:

- `openImmersiveSpace(id: "sensing")` 결과가 `.error`여도 열린 것으로 간주
- `isSensingOpen`이 true로 남아 재시도 불가할 수 있음

수정:

- `.error` 시 `isSensingOpen = false`
- `planeService.statusText = "공간 인식 시작 실패"` 표시
- `@unknown default`도 재시도 가능하도록 false 처리

현재 의미:

- ImmersiveSpace 시작 실패가 사용자에게 드러남
- 다음 `.task` 또는 화면 재진입 때 재시도 가능한 상태가 됨

주의:

- scene restoration에 의해 이미 열려 있는 케이스와 실제 error를 완벽히 구분하지는 않는다.
- 필요하면 Sprint 2에서 별도 immersive state machine으로 분리할 수 있다.

---

### FIX-04 — Reality Composer Pro 로컬 상태 ignore

대상 파일:

- `.gitignore`

추가 항목:

```gitignore
# Reality Composer Pro user/plugin workspace state
*.rcuserdata
**/Package.realitycomposerpro/PluginData/
```

문제:

- Reality Composer Pro가 `WorkspaceData/*.rcuserdata`와 `PluginData/`를 생성함
- 사용자별 workspace/plugin 상태라 Git 커밋에 넣으면 noise가 커짐

현재 정책:

- Reality Composer Pro의 프로젝트 구조 파일은 유지
  - `Package.realitycomposerpro/ProjectData/main.json`
  - `Package.realitycomposerpro/WorkspaceData/SceneMetadataList.json`
  - `Package.realitycomposerpro/WorkspaceData/Settings.rcprojectdata`
- 사용자 상태 파일은 제외
  - `*.rcuserdata`
  - `PluginData/`

---

### FIX-05 — USDA EOF whitespace 정리

대상 파일:

- `Packages/RealityKitContent/Sources/RealityKitContent/RealityKitContent.rkassets/TravelCaseScene.usda`

문제:

- `git diff --check`에서 `new blank line at EOF` 경고

수정:

- EOF blank line 제거
- `git diff --check` 통과 확인

---

## 3. Verification

실행한 검증:

```bash
git diff --check
```

결과:

```text
PASS
```

빌드 검증:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project DesktopOrganizer.xcodeproj \
  -scheme DesktopOrganizer \
  -destination 'generic/platform=visionOS Simulator' \
  build
```

결과:

```text
BUILD SUCCEEDED
```

---

## 4. Current Git Status Notes

현재 의미 있는 수정 파일:

```text
.gitignore
DesktopOrganizer/App/DesktopOrganizerApp.swift
DesktopOrganizer/Models/MemoLabel.swift
DesktopOrganizer/Views/ControlPanelView.swift
DesktopOrganizer/Views/MemoEditorSheet.swift
Packages/RealityKitContent/Package.realitycomposerpro/ProjectData/main.json
Packages/RealityKitContent/Package.realitycomposerpro/WorkspaceData/SceneMetadataList.json
Packages/RealityKitContent/Package.realitycomposerpro/WorkspaceData/Settings.rcprojectdata
Packages/RealityKitContent/Sources/RealityKitContent/RealityKitContent.rkassets/TravelCaseScene.usda
```

ignored로 남는 파일은 의도된 로컬 상태 파일:

```text
.DS_Store
.bkit/
DesktopOrganizer.xcodeproj/**/xcuserdata/
Packages/RealityKitContent/.swiftpm/
Packages/RealityKitContent/Package.realitycomposerpro/PluginData/
Packages/RealityKitContent/Package.realitycomposerpro/WorkspaceData/*.rcuserdata
```

---

## 5. Remaining Open Issue

### OPEN-01 — 책상 위치 기반 실제 window 배치

현재 상태:

- `PlaneDetectionService.tablePlaneOrigin`은 책상 후보 위치를 계산한다.
- `ControlPanelView.createBox()`는 이 값을 `BoxPayload.posX/Y/Z`에 넣는다.
- 그러나 `BoxVolumeView`는 `payload` 위치 값을 실제 volumetric window 배치에 사용하지 않는다.

중요:

- 현재 구현은 "책상 위치 후보를 계산하고 payload로 전달"하는 단계까지다.
- visionOS volumetric window 자체를 ARKit plane 좌표에 직접 고정하는 동작은 아직 구현되지 않았다.

다음 설계 후보:

1. `BoxVolumeView` 내부를 `Model3D` 단독에서 `RealityView` 기반으로 전환
2. `WorldAnchor` 또는 RealityKit entity transform을 사용해 감지 평면 기준 배치
3. `OrganizerBox`에 position 필드 추가 후 재실행 복원까지 연결

판단:

- 이 항목은 단순 버그 수정이 아니라 Sprint 2 설계 항목으로 분리하는 것이 안전하다.
- MVP 현재 상태에서는 box window 생성, model 표시, drag 회전, SwiftData 복원은 유지된다.

---

## 6. Handoff Summary for Claude

Claude가 이어받을 때 우선순위:

1. `desktop-organizer.design.md`와 이 문서를 함께 읽는다.
2. 이번 리뷰에서 저장 실패/색상 crash/ignore/EOF 문제는 이미 수정 완료로 본다.
3. 남은 핵심 판단은 `OPEN-01`이다.
4. `OPEN-01`을 진행할 경우 먼저 visionOS에서 volumetric window 위치 제어가 가능한지, 아니면 RealityView 내부 entity 배치로 우회해야 하는지 조사한다.
5. 실제 Vision Pro 디바이스에서 SC-2, SC-3 권한/plane 감지 확인이 필요하다.

현재 검증 기준:

- `git diff --check`: PASS
- `xcodebuild`: BUILD SUCCEEDED

