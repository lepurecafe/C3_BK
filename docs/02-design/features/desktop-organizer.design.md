# Desktop Organizer — Design

Last updated: 2026-05-19
Phase: Design
Feature: desktop-organizer
Architecture: Option C (Pragmatic Balance)

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | visionOS 공간 정리 앱의 핵심 상호작용(박스·메모 생성, ARKit 책상 인식)이 성립하는지 검증 |
| **WHO** | BK (iOS 입문, 애플 아카데미 C3 프로젝트) |
| **RISK** | ARKit plane detection Simulator 제한 / RealityKitContent 패키지 연결 복잡도 |
| **SUCCESS** | 앱 실행 → 책상 인식 → 박스/메모 생성 → 재실행 후 복원까지 crash 없이 동작 |
| **SCOPE** | 생성·표시·영속성. 박스-메모 관계는 Sprint 2 |

---

## 1. 아키텍처 개요

### 1.1 설계 원칙

- **참조 프로젝트 구조 최대 활용**: SeaCreatures(박스) + LabelMaker(메모) 패턴을 직접 이식
- **Phase별 독립 빌드**: 각 Phase 완료 후 빌드·검증 가능하도록 파일 의존성 최소화
- **과도한 추상화 금지**: MVP 규모에 맞는 분리만 적용

### 1.2 전체 Scene 구성

```
DesktopOrganizerApp
  ├── WindowGroup (기본)           → ControlPanelView
  ├── WindowGroup(id: "boxWindow") → BoxVolumeView        [.volumetric]
  ├── WindowGroup(for: MemoLabel)  → MemoLabelView        [.plain]
  └── ImmersiveSpace(id: "sensing")→ PlaneOverlayView     [.mixed]
```

### 1.3 환경(Environment) 흐름

```
PlaneDetectionService (@Observable)
  ↑ ImmersiveSpace에서 ARKit 실행
  ↓ ControlPanelView가 .environment()로 읽음
  ↓ 박스 생성 시 tablePlanePosition 사용
```

---

## 2. 폴더 구조

```
C3_BK/
  project.yml
  1890s_Travel_Case.usdz           ← 원본 (A2에서 Package로 복사)
  DesktopOrganizer/
    App/
      DesktopOrganizerApp.swift
    Models/
      BoxPayload.swift             ← Hashable+Codable window payload
      MemoLabel.swift              ← Hashable+Codable window payload
      OrganizerBox.swift           ← @Model SwiftData (E Phase)
      MemoItem.swift               ← @Model SwiftData (E Phase)
    Services/
      PlaneDetectionService.swift  ← @Observable ARKit (B Phase)
      SeedDataService.swift        ← SwiftData seed (E Phase)
    Views/
      ControlPanelView.swift
      MemoEditorSheet.swift        ← 메모 작성 Sheet
      MemoLabelView.swift          ← plain window 라벨
      BoxVolumeView.swift          ← volumetric window
      PlaneOverlayView.swift       ← ImmersiveSpace 내부
      ColorButton.swift            ← 색상 선택 버튼 (LabelMaker 이식)
    Resources/
      Info.plist
      Assets.xcassets/
  Packages/
    RealityKitContent/
      Package.swift
      Sources/RealityKitContent/
        RealityKitContent.swift
        RealityKitContent.rkassets/
          TravelCase/
            1890s_Travel_Case.usdz ← A2에서 복사
          TravelCaseScene.usda
```

---

## 3. 파일별 설계

### 3.1 project.yml

```yaml
name: DesktopOrganizer
options:
  bundleIdPrefix: com.bk
  deploymentTarget:
    visionOS: "2.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    DEVELOPMENT_TEAM: ""
packages:
  RealityKitContent:
    path: Packages/RealityKitContent
targets:
  DesktopOrganizer:
    type: application
    platform: visionOS
    sources:
      - DesktopOrganizer
    dependencies:
      - package: RealityKitContent
        product: RealityKitContent
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.bk.DesktopOrganizer
        GENERATE_INFOPLIST_FILE: NO
        INFOPLIST_FILE: DesktopOrganizer/Resources/Info.plist
```

### 3.2 DesktopOrganizerApp.swift (최종 형태)

```swift
import SwiftUI
import SwiftData

@main
struct DesktopOrganizerApp: App {
    @State private var planeService = PlaneDetectionService()

    var body: some Scene {
        WindowGroup {
            ControlPanelView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 200)
        .modelContainer(for: [OrganizerBox.self, MemoItem.self])
        .environment(planeService)

        WindowGroup(id: "boxWindow", for: BoxPayload.self) { $payload in
            BoxVolumeView(payload: payload)
                .padding3D(.all, 80)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.4, height: 0.35, depth: 0.4, in: .meters)

        WindowGroup(for: MemoLabel.self) { $memo in
            MemoLabelView(memo: $memo)
                .disabled(true)
        } defaultValue: {
            MemoLabel(text: "")
        }
        .windowResizability(.contentSize)
        .windowStyle(.plain)

        ImmersiveSpace(id: "sensing") {
            PlaneOverlayView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
```

> Phase 진행에 따라 점진적으로 Scene이 추가됨.
> A Phase: WindowGroup(기본)만 있는 최소 구조로 시작.

### 3.3 Models

#### BoxPayload.swift
```swift
import Foundation

struct BoxPayload: Hashable, Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var posX: Float = 0
    var posY: Float = -0.3
    var posZ: Float = -0.8

    init(id: UUID = UUID(), name: String,
         posX: Float = 0, posY: Float = -0.3, posZ: Float = -0.8) {
        self.id = id; self.name = name
        self.posX = posX; self.posY = posY; self.posZ = posZ
    }
}
```

#### MemoLabel.swift
```swift
import SwiftUI

struct MemoLabel: Hashable, Codable, Identifiable {
    var id: UUID = UUID()
    var text: String = ""
    var colorIndex: Int = 0
    var cornerRadius: Double = 20.0

    func selectedColor() -> Color { MemoLabel.colors[colorIndex] }
    static let colors: [Color] = [.cyan, .green, .yellow, .pink]
}
```

#### OrganizerBox.swift (E Phase)
```swift
import Foundation
import SwiftData

@Model
final class OrganizerBox {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var isOpen: Bool

    init(id: UUID = UUID(), name: String,
         createdAt: Date = .now, isOpen: Bool = false) {
        self.id = id; self.name = name
        self.createdAt = createdAt; self.isOpen = isOpen
    }
}
```

#### MemoItem.swift (E Phase)
```swift
import Foundation
import SwiftData

@Model
final class MemoItem {
    @Attribute(.unique) var id: UUID
    var text: String
    var createdAt: Date
    var colorIndex: Int
    var cornerRadius: Double
    var containerBoxID: UUID?

    init(id: UUID = UUID(), text: String, createdAt: Date = .now,
         colorIndex: Int = 0, cornerRadius: Double = 20.0) {
        self.id = id; self.text = text; self.createdAt = createdAt
        self.colorIndex = colorIndex; self.cornerRadius = cornerRadius
    }
}
```

### 3.4 Services

#### PlaneDetectionService.swift (B Phase)
```swift
import ARKit
import RealityKit

@Observable
@MainActor
final class PlaneDetectionService {
    var statusText: String = "책상 인식 중..."
    var detectedTablePlane: PlaneAnchor?

    private var arkitSession = ARKitSession()
    private var planeDetection = PlaneDetectionProvider(alignments: [.horizontal])

    func startDetection() async {
        guard PlaneDetectionProvider.isSupported else {
            statusText = "이 기기에서 지원되지 않음"
            return
        }
        do {
            try await arkitSession.run([planeDetection])
            for await update in planeDetection.anchorUpdates {
                switch update.event {
                case .added, .updated:
                    if update.anchor.geometry.extent.width > 0.3 {
                        detectedTablePlane = update.anchor
                        statusText = "책상 감지됨 ✓"
                    }
                case .removed:
                    if detectedTablePlane?.id == update.anchor.id {
                        detectedTablePlane = nil
                        statusText = "책상 인식 중..."
                    }
                }
            }
        } catch {
            statusText = "인식 실패: \(error.localizedDescription)"
        }
    }

    // 감지된 책상 중심 위치 (없으면 기본 fallback 위치)
    var tablePlaneOrigin: (x: Float, y: Float, z: Float) {
        guard let plane = detectedTablePlane else {
            return (0, -0.3, -0.8)
        }
        let col = plane.originFromAnchorTransform.columns.3
        return (col.x, col.y - 0.05, col.z)
    }
}
```

#### SeedDataService.swift (E Phase)
```swift
import Foundation
import SwiftData

@MainActor
enum SeedDataService {
    static func ensureReady(boxes: [OrganizerBox], context: ModelContext) {
        // MVP에서는 seed 불필요 — 사용자가 직접 생성
    }
}
```

### 3.5 Views

#### PlaneOverlayView.swift (B Phase)
```swift
import SwiftUI
import RealityKit

struct PlaneOverlayView: View {
    @Environment(PlaneDetectionService.self) private var planeService

    var body: some View {
        RealityView { _ in }
            .task { await planeService.startDetection() }
    }
}
```

#### ControlPanelView.swift

```swift
import SwiftUI
import SwiftData

struct ControlPanelView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(PlaneDetectionService.self) private var planeService
    @Environment(\.modelContext) private var modelContext          // E Phase

    @Query(sort: \OrganizerBox.createdAt) private var boxes: [OrganizerBox]  // E Phase
    @Query(sort: \MemoItem.createdAt) private var memos: [MemoItem]          // E Phase

    @State private var showMemoEditor = false
    @State private var isSensingOpen = false

    var body: some View {
        VStack(spacing: 16) {
            // 감지 상태
            Text(planeService.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            // 버튼 2개
            HStack(spacing: 12) {
                Button("박스 생성") { createBox() }
                    .buttonStyle(.borderedProminent)
                Button("메모 생성") { showMemoEditor = true }
                    .buttonStyle(.bordered)
            }

            // 재열기 목록 (E Phase)
            if !boxes.isEmpty || !memos.isEmpty {
                Divider()
                reopenList
            }
        }
        .padding(20)
        .sheet(isPresented: $showMemoEditor) {
            MemoEditorSheet()
        }
        .task {
            if !isSensingOpen {
                isSensingOpen = true
                await openImmersiveSpace(id: "sensing")
            }
        }
    }

    private var reopenList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(boxes) { box in
                Button("📦 \(box.name)") {
                    openWindow(id: "boxWindow",
                               value: BoxPayload(id: box.id, name: box.name))
                }
                .font(.caption)
            }
            ForEach(memos) { memo in
                Button("📝 \(memo.text.prefix(20))") {
                    openWindow(value: MemoLabel(id: memo.id, text: memo.text,
                                               colorIndex: memo.colorIndex,
                                               cornerRadius: memo.cornerRadius))
                }
                .font(.caption)
            }
        }
    }

    private func createBox() {
        let origin = planeService.tablePlaneOrigin
        let box = OrganizerBox(name: "Box \(boxes.count + 1)")  // E Phase
        modelContext.insert(box)                                  // E Phase
        try? modelContext.save()                                  // E Phase

        let payload = BoxPayload(
            id: box.id,
            name: box.name,
            posX: origin.x, posY: origin.y, posZ: origin.z
        )
        openWindow(id: "boxWindow", value: payload)
    }
}
```

> **A~D Phase 구현 시 주의**: SwiftData 관련 코드(@Query, modelContext.insert 등)는
> E Phase 전까지 임시로 제거하거나 주석 처리. E Phase에서 점진적으로 추가.

#### MemoEditorSheet.swift (D Phase)
```swift
import SwiftUI
import SwiftData

struct MemoEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext  // E Phase

    @State private var text = ""
    @State private var colorIndex = 0
    @State private var cornerRadius = 20.0

    var previewMemo: MemoLabel {
        MemoLabel(text: text.isEmpty ? "메모 미리보기" : text,
                  colorIndex: colorIndex, cornerRadius: cornerRadius)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("메모 작성").font(.headline)

            // 미리보기
            MemoLabelView(memo: .constant(previewMemo))
                .disabled(true)
                .frame(maxHeight: 180)

            // 텍스트 입력
            TextEditor(text: $text)
                .frame(height: 80)
                .padding(6)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // 색상 선택
            HStack(spacing: 10) {
                ForEach(MemoLabel.colors.indices, id: \.self) { i in
                    ColorButton(color: MemoLabel.colors[i], isSelected: colorIndex == i) {
                        colorIndex = i
                    }
                }
            }

            // 모서리 조절
            HStack {
                Text("모서리").font(.caption).foregroundStyle(.secondary)
                Slider(value: $cornerRadius, in: 0...60)
            }

            // 버튼
            HStack(spacing: 16) {
                Button("취소") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Create") { createMemo() }
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }

    private func createMemo() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let memo = MemoItem(text: trimmed,           // E Phase
                            colorIndex: colorIndex,
                            cornerRadius: cornerRadius)
        modelContext.insert(memo)                     // E Phase
        try? modelContext.save()                      // E Phase

        let label = MemoLabel(id: memo.id,           // E Phase (non-E: MemoLabel())
                              text: trimmed,
                              colorIndex: colorIndex,
                              cornerRadius: cornerRadius)
        openWindow(value: label)
        dismiss()
    }
}
```

#### MemoLabelView.swift (LabelView 이식)
```swift
import SwiftUI

struct MemoLabelView: View {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var memo: MemoLabel

    var body: some View {
        TextField("메모 내용을 입력하세요", text: $memo.text, axis: .vertical)
            .frame(width: 400, height: isEnabled ? 400 : nil)
            .padding(40)
            .padding()
            .background(
                memo.selectedColor().opacity(0.85),
                in: RoundedRectangle(cornerRadius: memo.cornerRadius)
            )
            .foregroundStyle(.black)
            .font(.system(size: 36, weight: .semibold))
            .multilineTextAlignment(.center)
    }
}
```

#### BoxVolumeView.swift (SeaCreatureDetailView 이식)
```swift
import SwiftUI
import RealityKit
import RealityKitContent

struct BoxVolumeView: View {
    let payload: BoxPayload?

    @State private var horizontalRotation = CGFloat.zero
    @State private var verticalRotation = CGFloat.zero
    @State private var endHorizontalRotation = CGFloat.zero
    @State private var endVerticalRotation = CGFloat.zero

    var body: some View {
        Model3D(named: "TravelCaseScene", bundle: realityKitContentBundle)
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
```

#### ColorButton.swift (LabelMaker 이식)
```swift
import SwiftUI

struct ColorButton: View {
    let color: Color
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle().stroke(.white, lineWidth: isSelected ? 3 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}
```

---

## 4. RealityKitContent Package

### 4.1 Package.swift
```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "RealityKitContent",
    platforms: [.visionOS(.v2)],
    products: [
        .library(name: "RealityKitContent", targets: ["RealityKitContent"])
    ],
    targets: [
        .target(
            name: "RealityKitContent",
            path: "Sources/RealityKitContent",
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        )
    ]
)
```

### 4.2 RealityKitContent.swift
```swift
import Foundation

public let realityKitContentBundle = Bundle.module
```

### 4.3 TravelCaseScene.usda

ClamScene.usda와 동일한 구조. scale은 실제 모델 크기에 맞게 실험 후 조정.

```
#usda 1.0
(
    customLayerData = {
        string creator = "Reality Composer Pro Version 2.0"
    }
    defaultPrim = "Root"
    metersPerUnit = 1
    upAxis = "Y"
)

def Xform "Root"
{
    def "TravelCase" (
        active = true
        prepend references = @TravelCase/1890s_Travel_Case.usdz@
    )
    {
        float3 xformOp:scale = (0.003, 0.003, 0.003)
        uniform token[] xformOpOrder = ["xformOp:translate", "xformOp:orient", "xformOp:scale"]
    }
}
```

---

## 5. Info.plist 필수 항목

```xml
<key>NSWorldSensingUsageDescription</key>
<string>책상 위에 박스와 메모를 배치하기 위해 공간 인식이 필요합니다.</string>
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <true/>
</dict>
```

---

## 6. 빌드 커맨드 (참조)

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project DesktopOrganizer.xcodeproj \
  -scheme DesktopOrganizer \
  -destination 'generic/platform=visionOS Simulator' \
  build
```

---

## 7. Phase별 파일 변경 매트릭스

| 파일 | A1 | A2 | B1 | B2 | C1 | C2 | D1 | D2 | D3 | E1 | E2 |
|------|----|----|----|----|----|----|----|----|----|----|-----|
| project.yml | ✦ | | | | | | | | | | |
| DesktopOrganizerApp.swift | ✦ | | ✦ | | ✦ | | ✦ | | | ✦ | |
| Info.plist | ✦ | | ✦ | | | | | | | | |
| RealityKitContent/ | | ✦ | | | | | | | | | |
| TravelCaseScene.usda | | ✦ | | | | | | | | | |
| PlaneDetectionService.swift | | | ✦ | | | | | | | | |
| PlaneOverlayView.swift | | | ✦ | | | | | | | | |
| ControlPanelView.swift | ✦ | | | ✦ | | ✦ | | | ✦ | | ✦ |
| BoxPayload.swift | | | | | ✦ | | | | | | |
| BoxVolumeView.swift | | | | | | ✦ | | | | | |
| MemoLabel.swift | | | | | | | ✦ | | | | |
| MemoLabelView.swift | | | | | | | | ✦ | | | |
| MemoEditorSheet.swift | | | | | | | | | ✦ | | |
| ColorButton.swift | | | | | | | | ✦ | | | |
| OrganizerBox.swift | | | | | | | | | | ✦ | |
| MemoItem.swift | | | | | | | | | | ✦ | |
| SeedDataService.swift | | | | | | | | | | ✦ | |

✦ = 해당 단계에서 생성 또는 수정

---

## 8. Success Criteria 추적

| SC | 관련 파일 | Phase |
|----|---------|-------|
| SC-1: ControlPanel crash 없이 열림 | DesktopOrganizerApp, ControlPanelView | A1 |
| SC-2: 권한 요청 자동 팝업 | PlaneDetectionService, Info.plist | B1~B2 |
| SC-3: 감지 상태 업데이트 | PlaneDetectionService, ControlPanelView | B2 |
| SC-4: volumetric window + 3D 모델 표시 | BoxVolumeView, TravelCaseScene.usda | C2 |
| SC-5: drag 회전 동작 | BoxVolumeView | C2 |
| SC-6: 메모 작성 창 조작 | MemoEditorSheet, ColorButton | D3 |
| SC-7: plain label window 생성 | MemoLabelView, DesktopOrganizerApp | D3 |
| SC-8: 재실행 후 목록 복원 | OrganizerBox, MemoItem, ControlPanelView | E2 |

---

## 9. 주요 리스크와 대응

| 리스크 | 대응 |
|--------|------|
| XcodeGen local package 연결 실패 | project.yml `packages.path` 시도 → 실패 시 xcodeproj를 Xcode에서 직접 Package 추가 |
| `Model3D` TravelCase 로딩 실패 | ClamScene.usda 구조 동일하게 작성 확인 / scale 0.001 단위로 재시험 |
| `.immersionStyle` API 버전 불일치 | visionOS 2.0+ API 확인 / 구버전이면 `ImmersiveSpace` 단독으로 시도 |
| `openImmersiveSpace` 반환값 처리 | `@discardableResult` 또는 result 처리로 warning 제거 |
| Simulator plane detection 미작동 | B2 완료 기준 = "권한 팝업". 실제 감지는 Vision Pro 디바이스 확인 |

---

## 10. 구현 가이드 — Phase별 상세

### Module 1: Phase A — 프로젝트 뼈대

**A1 작업 목록**:
1. `project.yml` 작성 (RealityKitContent 로컬 패키지 포함)
2. `DesktopOrganizer/App/DesktopOrganizerApp.swift` — WindowGroup(기본)만 있는 최소 구조
3. `DesktopOrganizer/Views/ControlPanelView.swift` — `Text("Hello")` placeholder
4. `DesktopOrganizer/Resources/Info.plist` — 최소 구성
5. `DesktopOrganizer/Resources/Assets.xcassets/` — 빈 카탈로그
6. `xcodegen generate` 실행
7. `xcodebuild build` 확인

**A2 작업 목록**:
1. `Packages/RealityKitContent/Package.swift` 작성
2. `Packages/RealityKitContent/Sources/RealityKitContent/RealityKitContent.swift` 작성
3. `Packages/RealityKitContent/Sources/RealityKitContent/RealityKitContent.rkassets/TravelCase/` 생성
4. `1890s_Travel_Case.usdz` 복사
5. `TravelCaseScene.usda` 작성
6. `xcodebuild build` 재확인 (패키지 링크 성공)

### Module 2: Phase B — ARKit

**B1 작업 목록**:
1. `PlaneDetectionService.swift` 작성
2. `PlaneOverlayView.swift` 작성
3. `DesktopOrganizerApp.swift`에 `ImmersiveSpace(id: "sensing")` 추가
4. `DesktopOrganizerApp.swift`에 `@State private var planeService` + `.environment()` 추가
5. `Info.plist`에 `NSWorldSensingUsageDescription` 추가
6. `xcodebuild build` 확인

**B2 작업 목록**:
1. `ControlPanelView.swift`에 감지 상태 Text 추가
2. `.task { await openImmersiveSpace(id: "sensing") }` 연결
3. Simulator 실행 → 권한 팝업 확인

### Module 3: Phase C — 박스 Window

**C1 작업 목록**:
1. `BoxPayload.swift` 작성
2. `DesktopOrganizerApp.swift`에 boxWindow Scene 추가
3. `BoxVolumeView.swift` — placeholder Text 버전
4. `xcodebuild build` 확인

**C2 작업 목록**:
1. `BoxVolumeView.swift` — Model3D + drag gesture 완성
2. `ControlPanelView.swift`에 "박스 생성" 버튼 + `createBox()` 추가
3. Simulator 실행 → volumetric window + 3D 모델 확인

### Module 4: Phase D — 메모 Window

**D1 작업 목록**:
1. `MemoLabel.swift` 작성
2. `DesktopOrganizerApp.swift`에 memo WindowGroup 추가
3. `MemoLabelView.swift` — placeholder 버전
4. `xcodebuild build` 확인

**D2 작업 목록**:
1. `MemoLabelView.swift` — LabelView 구조 완성
2. `ColorButton.swift` 작성

**D3 작업 목록**:
1. `MemoEditorSheet.swift` 작성
2. `ControlPanelView.swift`에 "메모 생성" 버튼 + sheet 연결
3. Simulator 실행 → 작성 → Create → plain window 확인

### Module 5: Phase E — SwiftData

**E1 작업 목록**:
1. `OrganizerBox.swift` 작성
2. `MemoItem.swift` 작성
3. `DesktopOrganizerApp.swift`에 `.modelContainer` 추가
4. `xcodebuild build` 확인 (crash 없음)

**E2 작업 목록**:
1. `ControlPanelView.swift`에 `@Query` + 재열기 목록 추가
2. `createBox()`, `createMemo()` 에서 SwiftData insert 추가
3. Simulator 실행 → 재실행 → 목록 복원 확인

### 11.3 Session Guide

| Module | Phase | 예상 소요 | 핵심 완료 조건 |
|--------|-------|---------|--------------|
| Module 1 | A1 + A2 | 1 session | `xcodebuild build` 성공 + RealityKitContent 링크 |
| Module 2 | B1 + B2 | 1 session | Simulator에서 권한 팝업 + 상태 텍스트 동작 |
| Module 3 | C1 + C2 | 1 session | volumetric window + 3D 모델 + drag 회전 |
| Module 4 | D1~D3 | 1 session | plain window 메모 라벨 생성 |
| Module 5 | E1 + E2 | 1 session | 재실행 후 목록 복원 |
