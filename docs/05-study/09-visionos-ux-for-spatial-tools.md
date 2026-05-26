# 09. visionOS UX 설계: 공간 도구를 사용자가 이해하게 만들기

Last updated: 2026-05-26

이 교재는 Desktop Organizer를 통해 visionOS 공간 도구 UX를 공부하기 위한 아홉 번째 교재다. 목표는 기능이 "작동한다"를 넘어, 사용자가 지금 무엇을 보고 있고, 무엇을 조작할 수 있고, 어떤 상태가 되었는지 이해하게 만드는 방법을 배우는 것이다.

## 1. 이 주제를 배우는 이유

공간 앱에서 UX 문제는 화면 안의 버튼 배치 문제보다 넓다.

사용자는 실제 공간을 보면서 앱 오브젝트를 함께 본다. 그래서 앱은 계속 알려줘야 한다.

- 지금 공간 인식이 켜져 있는가?
- 어느 면이 책상으로 잡혔는가?
- 이 박스는 선택 가능한가?
- 이 버튼은 삭제인가, 닫기인가?
- 이 메모는 이미 공간에 열려 있는가?
- 지금 드래그하면 무엇이 생기는가?
- pin이 켜지면 무엇이 달라지는가?

Desktop Organizer는 이런 질문에 대한 UX 답을 작은 패턴으로 구현하고 있다.

## 2. 이 앱의 UX 목표

최종 앱의 목표는 단순하다.

사용자가 Vision Pro를 착용하고 앱을 실행하면 책상을 찾고, 그 위에 이름 있는 박스를 만들고, 박스 안에서 메모를 생성/조회/삭제하며, 박스와 메모를 공간에 고정할 수 있어야 한다.

이 목표를 UX 언어로 바꾸면 다음과 같다.

| 사용자의 질문 | 앱이 보여줘야 하는 답 |
| --- | --- |
| 앱이 준비됐나? | 기본 패널과 상태 문구 |
| 책상을 찾았나? | `statusText`와 cyan 평면 |
| 박스를 만들 수 있나? | `박스 만들기` 버튼 |
| 어떤 박스인가? | 박스 아래 이름 표시 |
| 삭제인가 닫기인가? | trash와 xmark 아이콘 구분 |
| 고정됐나? | pin 아이콘과 초록 tint |
| 어떤 메모를 보고 있나? | hover/보고 있음 피드백 |
| 드래그하면 열리나? | 반투명 preview와 "놓으면 열림" |

## 3. 기본 패널은 앱의 리모컨이다

`ControlPanelView`는 공간 속 박스 자체가 아니라 앱 전체를 조작하는 리모컨이다.

현재 기본 패널에는 세 가지가 있다.

```text
상태 영역
인사말
박스 만들기 버튼
```

코드에서는 `homePanel`이 기본 경험을 만든다.

```swift
private var homePanel: some View {
    VStack(spacing: 18) {
        Text("안녕하세요. 당신의 친구 직박구리입니다.")
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

        Button("박스 만들기") {
            draftBoxName = ""
            controlStatusText = "박스 이름 입력"
            panelMode = .namingBox
        }
        .buttonStyle(.borderedProminent)
    }
}
```

이 패널은 박스 하나에 종속되지 않는다. 그래서 RealityKit attachment가 아니라 `WindowGroup` 안의 SwiftUI view가 적합하다.

## 4. 공간 상태는 항상 보여줘야 한다

사용자가 공간 인식을 믿으려면 현재 상태를 알아야 한다.

```swift
Circle()
    .fill(isSensingOpen ? .green : .gray)
    .frame(width: 8, height: 8)

Text(planeService.statusText)
    .font(.caption)
    .foregroundStyle(.secondary)
```

여기서 작은 원은 공간이 열려 있는지 보여주고, `statusText`는 ARKit 감지 상태를 설명한다.

이런 상태 표시가 없으면 사용자는 "앱이 아무것도 안 하는 건지, 감지 중인지, 실패한 건지" 구분하기 어렵다.

## 5. 수동 재시도 버튼은 신뢰를 만든다

공간 인식은 언제나 안정적이지 않다. 그래서 사용자가 직접 다시 시도할 수 있어야 한다.

```swift
Button("책상 다시 인식") {
    requestTableRescan()
}
.buttonStyle(.bordered)
.disabled(!isSensingOpen)
```

버튼을 항상 없애기보다, 비활성 상태로 보여주는 것도 UX 신호가 된다.

사용자는 "공간 시작 후 다시 인식 가능하구나"를 배운다.

## 6. cyan 평면은 디버그이면서 UX다

감지된 책상 후보는 cyan plane으로 표시된다.

```swift
let material = SimpleMaterial(
    color: UIColor.cyan.withAlphaComponent(0.45),
    roughness: 0.7,
    isMetallic: false
)

debugEntity.name = "DebugTablePlane"
debugEntity.model = ModelComponent(mesh: mesh, materials: [material])
```

이것은 개발용 디버그 overlay이지만, 실기기 테스트 단계에서는 강력한 UX 장치다.

사용자는 앱이 어느 면을 책상으로 잡았는지 즉시 알 수 있다.

제품 최종 단계에서는 이 overlay를 항상 보여줄지, 인식 직후 잠깐만 보여줄지, 디버그 모드에서만 보여줄지 결정해야 한다.

## 7. 박스 아래 컨트롤은 물체의 이름표다

박스 아래에는 삭제, 이름, 고정 버튼이 하나의 블록으로 붙는다.

```swift
HStack(spacing: 10) {
    Button(role: .destructive) { ... } label: {
        Image(systemName: "trash")
    }

    Text(boxName)

    Button { ... } label: {
        Image(systemName: isAnchored ? "pin.fill" : "pin")
    }
}
.glassBackgroundEffect()
```

이 컨트롤은 단순 버튼 모음이 아니라 박스의 이름표이자 조작 핸들이다.

| 요소 | UX 의미 |
| --- | --- |
| trash | 박스와 그 안 메모를 삭제 |
| 이름 | 사용자가 어떤 박스인지 인식 |
| pin | 실제 공간에 고정 또는 임시 고정 |

박스와 같이 움직여야 하므로 RealityKit attachment로 구현한다.

## 8. 삭제와 닫기는 분리해야 한다

공간 메모에는 `xmark`와 `trash`가 둘 다 있다.

```swift
Button {
    onClose()
} label: {
    Image(systemName: "xmark")
}

Button(role: .destructive) {
    onDelete()
} label: {
    Image(systemName: "trash")
}
```

이 구분은 중요하다.

| 아이콘 | 의미 | 데이터 |
| --- | --- | --- |
| `xmark` | 공간에서 접기 | 메모는 박스 안에 남음 |
| `trash` | 메모 삭제 | `MemoItem` 삭제 |

공간 앱에서는 "안 보이게 하기"와 "데이터 삭제"가 쉽게 헷갈린다. 그래서 아이콘, accessibility label, 동작을 분명히 나눠야 한다.

## 9. pin은 상태 버튼이다

pin 버튼은 단순 명령 버튼이 아니라 현재 상태를 보여주는 토글이다.

```swift
Image(systemName: isAnchored ? "pin.fill" : "pin")
    .font(.caption)

.tint(isAnchored ? .green : .gray)
```

사용자는 아이콘 모양과 색으로 상태를 읽는다.

- `pin`: 아직 고정되지 않음
- `pin.fill` + 초록색: 고정됨

고정 상태에서는 드래그가 막혀야 한다. 시각 상태와 실제 동작이 일치해야 UX가 신뢰를 얻는다.

## 10. 박스 hover는 조작 가능 신호다

박스가 사용자를 바라볼 때 살짝 밝아지는 효과는 앱이 직접 색상 animation을 만든 것이 아니다.

```swift
entity.components.set(InputTargetComponent())
entity.components.set(HoverEffectComponent())
```

이것은 visionOS/RealityKit 기본 hover feedback이다.

UX 관점에서는 "이 물체는 볼 수만 있는 장식이 아니라 조작 가능한 대상"이라는 신호다.

가능하면 시스템 기본 효과를 먼저 쓰는 것이 좋다. 사용자가 visionOS 전체에서 배운 상호작용 감각과 일치하기 때문이다.

## 11. 박스 위 메모 목록은 작은 창처럼 보인다

박스를 클릭하면 박스 위에 메모 목록 attachment가 뜬다.

```swift
.frame(width: 420, alignment: .topLeading)
.glassBackgroundEffect()
```

이 UI는 창처럼 보이지만 실제 window가 아니다. 박스의 자식 attachment이므로 박스를 따라 움직인다.

UX적으로는 "이 박스 안에 들어 있는 내용"이라는 소속감이 중요하다.

## 12. 메모 목록 상단 버튼은 한 행으로 모은다

현재 메모 목록 상단에는 `메모 추가`, `선택`, `삭제`가 한 행에 있다.

```swift
Button { ... } label: {
    Label("메모 추가", systemImage: "plus")
}

Button { ... } label: {
    Text(isSelectingMemos ? "완료" : "선택")
}

Button(role: .destructive) { ... } label: {
    Label("삭제", systemImage: "trash")
}
```

이 배치는 사용자가 목록 관리 기능을 한 곳에서 찾게 한다.

다만 실기기에서는 버튼이 너무 작거나 시선 선택이 어려운지 확인해야 한다.

## 13. 메모는 줄이 아니라 미리보기 카드다

메모 목록은 단순 텍스트 줄이 아니라 색상 카드로 표시된다.

```swift
.background(MemoPalette.color(for: memo.colorIndex).opacity(0.82))
.clipShape(RoundedRectangle(cornerRadius: 8))
```

카드는 다음 정보를 한 번에 준다.

- 메모 색상
- 본문 앞부분
- 선택 상태
- 공간에 열림 상태
- 드래그 중 상태
- 보고 있음 상태

공간 UI에서는 작은 텍스트 줄보다 시각적으로 구분되는 카드가 더 빠르게 읽힌다.

## 14. 색상 선택은 단순해야 한다

메모 생성 시 색상은 작은 원형 버튼으로 고른다.

```swift
Circle()
    .fill(color)
    .frame(width: 28, height: 28)
    .overlay {
        Circle()
            .stroke(.white, lineWidth: isSelected ? 3 : 0)
    }
```

이 프로젝트에서는 코너 곡률 제어를 제거하고, 사용자가 고르는 값은 색상과 본문만 남겼다.

좋은 UX는 항상 옵션이 많은 것이 아니다. 지금 앱의 핵심은 공간 정리이므로, 메모 작성 UI는 가볍게 유지하는 것이 맞다.

## 15. 보고 있는 메모는 표시해야 한다

메모 카드에는 hover와 "보고 있음" 상태가 있다.

```swift
.hoverEffect(.highlight)
.onHover { isHovered in
    hoveredMemoID = isHovered ? memo.id : nil
}
```

카드 내부에서는 눈 아이콘과 테두리로 표시한다.

```swift
if isLookedAt {
    Image(systemName: "eye.fill")
}
```

공간 앱에서는 사용자의 시선이 곧 포인터처럼 느껴질 수 있다. 그래서 보고 있는 대상이 시각적으로 구분되어야 한다.

## 16. 드래그는 예고가 있어야 한다

메모를 드래그할 때는 원본 카드가 사라지지 않는다. 대신 원본은 살짝 투명해지고, 반투명 preview가 공간으로 나온다.

```swift
.opacity(draggingMemoID == memo.id ? 0.72 : 1)
```

preview에는 "놓으면 열림"이 표시된다.

```swift
SpatialMemoCard(
    text: text,
    colorIndex: colorIndex,
    opacity: 0.62,
    title: "놓으면 열림"
)
```

이 UX는 사용자가 "지금 원본을 옮기는 중인지, 복사본을 꺼내는 중인지" 이해하게 한다.

## 17. 상태가 겹칠 때 우선순위가 필요하다

메모 카드는 선택, 공간에 열림, 드래그, 보고 있음 상태가 동시에 생길 수 있다.

그래서 border color는 우선순위를 둔다.

```swift
if isOpenedInSpace {
    return .green.opacity(0.78)
}

if isReadyToOpen {
    return .green
}

if isDragging {
    return .white.opacity(0.85)
}

if isLookedAt {
    return .white.opacity(0.72)
}

if isSelected {
    return .blue
}
```

이런 우선순위가 없으면 카드가 여러 상태를 동시에 애매하게 보여준다.

## 18. 공간 메모는 읽기 쉬워야 한다

공간에 열린 메모는 큰 카드로 표시된다.

이 UI의 실제 타입은 `SpatialMemoOpenedAttachment`이고, 그 안에서 `SpatialMemoCard`와 아래쪽 control bar를 함께 보여준다.

```swift
Text(text)
    .font(.system(size: 24, weight: .semibold))
    .lineLimit(8)
```

그리고 hover 상태에서는 "보고 있음"을 표시한다.

```swift
Label("보고 있음", systemImage: "eye.fill")
```

공간 메모는 사용자의 주변 공간에 놓이는 도구다. 너무 작으면 읽기 어렵고, 너무 크면 공간을 방해한다. 현재 크기는 실기기에서 거리와 가독성 튜닝이 필요하다.

## 19. ControlPanel의 개발용 UI는 분리 대상이다

현재 DEBUG 빌드에는 저장 항목 요약과 데이터 초기화 버튼이 있다.

```swift
Text("저장 항목 · 박스 \(boxes.count) · 메모 \(memos.count)")

Button("데이터 초기화", role: .destructive) { ... }
```

개발 중에는 매우 유용하다. 하지만 최종 사용자에게 항상 노출할지는 별도 판단이 필요하다.

추천 방향은 다음과 같다.

- 일반 사용자 흐름: 인사말, 공간 상태, 박스 만들기
- 개발자/테스트 흐름: 저장 개수, 데이터 초기화, debug overlay toggle

## 20. 실기기에서만 판단할 수 있는 UX

visionOS UX는 Simulator만으로 판단하기 어렵다.

| 항목 | 실기기에서 봐야 하는 이유 |
| --- | --- |
| 버튼 크기 | 시선/핀치 선택이 편한지 확인 |
| 박스 아래 컨트롤 위치 | 너무 낮거나 박스에 가려지는지 확인 |
| 메모 목록 폭 | 카드가 충분히 읽히는지 확인 |
| 공간 메모 크기 | 실제 거리에서 읽을 수 있는지 확인 |
| hover 효과 | 사용자가 보고 있음을 확실히 느끼는지 확인 |
| cyan 평면 | 도움인지 방해인지 확인 |
| pin 상태 | 고정됐다는 느낌이 분명한지 확인 |
| 삭제/닫기 | 실수 가능성이 큰지 확인 |

특히 공간 높이, 시선 선택감, 거리감은 실기기에서만 제대로 판단할 수 있다.

## 21. 남은 UX 결정

현재 구현을 기준으로 남은 UX 결정은 다음과 같다.

| 결정할 것 | 현재 상태 | 결정 방향 |
| --- | --- | --- |
| cyan 평면 표시 | 항상 표시 | 최종에서는 일시 표시/디버그 모드 검토 |
| 데이터 초기화 | DEBUG에 표시 | 최종 사용자 UI와 분리 |
| 삭제 확인 | 일부 즉시 삭제 | confirmation 또는 undo 검토 |
| 공간 메모 크기 | 고정 크기 | 실기기 거리 기준 튜닝 |
| 박스 배치 | x offset | grid/ring 배치 검토 |
| pin 피드백 | 아이콘/초록 tint | 성공/실패 문구와 함께 유지 |

## 22. 코드 읽는 순서

visionOS UX 설계를 공부하려면 아래 순서가 좋다.

1. `docs/01-plan/features/final-product-shape.plan.md`
2. `DesktopOrganizer/Views/ControlPanelView.swift`
3. `DesktopOrganizer/Views/WorkspaceRealityView+Boxes.swift`
4. `DesktopOrganizer/Views/BoxControlAttachmentView.swift`
5. `DesktopOrganizer/Views/BoxMemoAttachmentView.swift`
6. `DesktopOrganizer/Views/SpatialMemoAttachmentViews.swift`
7. `DesktopOrganizer/Views/WorkspaceRealityView+Attachments.swift`
8. `DesktopOrganizer/Views/ColorButton.swift`
9. `DesktopOrganizer/Models/MemoPalette.swift`

## 23. 다음 교재와의 연결

이 교재를 읽은 뒤에는 `10-spatial-app-refactoring-guide.html`로 넘어가면 좋다.

9번 교재에서 사용자가 이해하는 경험 단위를 봤다면, 10번 교재에서는 그 경험이 커지면서 코드를 어떻게 나누고 관리할지 공부한다.

## 24. 체크리스트

아래 질문에 답할 수 있으면 9번 교재의 목표를 달성한 것이다.

- 공간 인식 상태를 텍스트와 시각 overlay로 모두 보여주는 이유를 설명할 수 있는가?
- `xmark`와 `trash`를 분리해야 하는 이유를 말할 수 있는가?
- pin 버튼이 상태 버튼이어야 하는 이유를 설명할 수 있는가?
- 박스 hover와 메모 hover가 사용자에게 주는 UX 신호를 설명할 수 있는가?
- 메모 드래그 preview가 원본과 분리되어야 하는 이유를 말할 수 있는가?
- 최종 사용자 UI와 개발용 UI를 분리해야 하는 이유를 설명할 수 있는가?
