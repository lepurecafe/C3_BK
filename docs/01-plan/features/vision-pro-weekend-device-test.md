# Vision Pro Weekend Device Test Checklist

Last updated: 2026-05-20
Project: Desktop Organizer
Context: 주말에 Apple Vision Pro 실기기를 사용할 수 있을 때, 개발 중인 앱 검증과 visionOS 감각 학습을 최대한 많이 가져오기 위한 체크리스트

---

## 0. 목표

이번 실기기 테스트의 목표는 단순히 "앱이 켜진다"를 확인하는 것이 아니다.

1. Desktop Organizer의 MVP 루프가 실제 공간에서 성립하는지 확인한다.
2. Simulator에서 검증할 수 없던 ARKit plane detection, mixed ImmersiveSpace, volumetric window 감각을 확인한다.
3. Vision Pro에서 창, 볼륨, 실제 책상, 손/눈 조작이 어떤 느낌인지 몸으로 이해한다.
4. 이후 개발 방향을 정할 수 있도록 실패 지점과 UX 감각을 영상/메모로 남긴다.

---

## 1. 주말 전 준비

### 1.1 개발 환경 준비

- [ ] Mac과 Vision Pro를 연결할 수 있는 케이블/네트워크 상태를 확인한다.
- [ ] Apple Developer 계정 로그인 상태를 확인한다.
- [ ] Xcode에서 Vision Pro 실기기가 인식되는지 확인할 수 있는 시간을 확보한다.
- [ ] `DesktopOrganizer.xcodeproj`가 최신 코드 기준인지 확인한다.
- [ ] XcodeGen을 다시 돌려야 하는 상황에 대비한다.

```bash
xcodegen generate
```

- [ ] 실기기 빌드 전 Simulator 빌드를 통과시킨다.

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project DesktopOrganizer.xcodeproj \
  -scheme DesktopOrganizer \
  -destination 'generic/platform=visionOS Simulator' \
  build
```

### 1.2 앱 상태 정리

- [ ] Git 상태를 확인하고, 어떤 파일이 이미 수정 중인지 기록한다.

```bash
git status --short
```

- [ ] 실기기 테스트용으로 앱에 남길 최소 로그/화면 문구를 정리한다.
  - `PlaneDetectionService.statusText`
  - 공간 인식 시작 성공/실패 상태
  - 박스/메모 저장 실패 alert
- [ ] `DEBUG`의 "데이터 초기화" 버튼이 실기기 빌드에서도 필요한지 확인한다.
- [ ] 테스트 전 초기 데이터가 필요 없다면 앱 내 데이터 초기화 버튼으로 깨끗한 상태에서 시작한다.

### 1.3 기록 준비

- [ ] 테스트용 노트 파일 또는 종이를 준비한다.
- [ ] 아래 항목을 바로 기록할 수 있게 표를 만들어 둔다.
  - 시간
  - 장소/책상 종류
  - 조명 상태
  - 앱 동작
  - 기대와 다른 점
  - 다음 코드 수정 후보
- [ ] 가능하다면 화면 녹화 또는 외부 촬영 방법을 준비한다.
- [ ] Vision Pro 착용자가 직접 느낀 감각과, 옆에서 보는 사람이 느낀 문제를 따로 기록한다.

---

## 2. Desktop Organizer 필수 테스트

### 2.1 앱 실행과 기본 창

- [ ] 앱이 실기기에서 설치된다.
- [ ] 앱 실행 후 ControlPanel 창이 열린다.
- [ ] ControlPanel 크기가 너무 크거나 작지 않다.
- [ ] ControlPanel을 이동했을 때 시야를 방해하지 않는다.
- [ ] 버튼 텍스트가 실제 Vision Pro 거리감에서 읽기 쉽다.
- [ ] "박스 생성", "메모 생성", "공간 인식 시작" 버튼을 시선+핀치로 누르기 편하다.

기록할 것:

- ControlPanel 기본 크기 적절성
- 버튼 간격
- 눈으로 선택할 때 오작동 여부
- 창을 어디에 두면 가장 편한지

### 2.2 공간 인식 시작

- [ ] "공간 인식 시작" 버튼을 누르면 권한 요청이 정상적으로 나타난다.
- [ ] 권한 허용 후 앱이 멈추지 않는다.
- [ ] `statusText`가 "책상 인식 중..."에서 실제 감지 상태로 바뀐다.
- [ ] 권한 거부 시 앱이 어떻게 보이는지 확인한다.
- [ ] ImmersiveSpace 진입 후 ControlPanel과 실제 공간이 함께 보이는지 확인한다.
- [ ] 실패 시 "공간 인식 시작 실패" 또는 적절한 실패 상태가 표시되는지 확인한다.

장소별로 반복:

- [ ] 밝은 책상
- [ ] 어두운 책상
- [ ] 흰색/무늬 없는 책상
- [ ] 물건이 많은 책상
- [ ] 작은 테이블
- [ ] 바닥이 책상으로 오인되는지

기록할 것:

- 감지까지 걸린 시간
- 어떤 표면을 책상으로 잡는지
- 책상 대신 바닥/벽/다른 물체를 잡는지
- 현재 `width > 0.3` 필터가 충분한지

### 2.3 박스 생성

- [ ] 책상 감지 전 "박스 생성"을 눌렀을 때 fallback 위치가 자연스러운지 확인한다.
- [ ] 책상 감지 후 "박스 생성"을 눌렀을 때 의도한 위치에 생성되는지 확인한다.
- [ ] 1890s Travel Case 모델이 잘리지 않고 보인다.
- [ ] 모델 크기가 실제 책상 위 오브젝트로 느껴지는지 확인한다.
- [ ] 모델이 너무 크거나 작다면 적절한 목표 크기를 기록한다.
- [ ] 드래그 회전이 기대한 방향으로 동작한다.
- [ ] 여러 박스를 생성했을 때 창이 겹치거나 관리가 어려운지 확인한다.

기록할 것:

- volumetric window 기본 크기 `0.6m` 적절성
- `BoxVolumeView`의 `targetSize = 0.35` 적절성
- 모델이 뜨는 위치와 책상 표면 사이의 거리감
- 회전 제스처가 필요한 기능인지, 오히려 방해되는지

### 2.4 메모 생성

- [ ] "메모 생성" 버튼으로 작성 sheet가 열린다.
- [ ] Vision Pro에서 TextEditor 입력이 가능한지 확인한다.
- [ ] 한글 입력이 불편하지 않은지 확인한다.
- [ ] 색상 버튼을 시선+핀치로 누르기 쉽다.
- [ ] cornerRadius slider 조작이 편하다.
- [ ] 빈 텍스트일 때 Create가 비활성화된다.
- [ ] Create 후 plain memo window가 열린다.
- [ ] 메모 창이 공간 속 라벨처럼 느껴지는지 확인한다.
- [ ] 메모 텍스트 크기가 실제 거리에서 읽기 쉽다.

기록할 것:

- 메모 기본 크기
- 글자 크기 `36` 적절성
- 배경색 opacity `0.85` 적절성
- TextField 기반 라벨이 읽기 전용 창처럼 보이는지
- 메모 작성 UX를 sheet로 유지할지 별도 창으로 바꿀지

### 2.5 저장과 재열기

- [ ] 박스 생성 후 ControlPanel 목록에 나타난다.
- [ ] 메모 생성 후 ControlPanel 목록에 나타난다.
- [ ] 앱을 종료했다가 다시 실행해도 목록이 복원된다.
- [ ] 목록에서 박스를 다시 열 수 있다.
- [ ] 목록에서 메모를 다시 열 수 있다.
- [ ] 데이터 초기화 버튼으로 저장 데이터가 삭제된다.
- [ ] 저장 실패 alert는 정상적으로 보이는지 확인한다. 실제 실패를 만들기 어렵다면 코드상 정책만 재확인한다.

주의:

- 현재 `BoxPayload.posX/Y/Z`는 창의 실제 배치에 직접 쓰이지 않는다.
- 재열기 시 박스 위치 복원은 아직 MVP 이후 과제다.
- 이번 테스트에서는 "저장된 항목을 다시 창으로 열 수 있는가"를 우선 확인한다.

---

## 3. Vision Pro 감각 학습 과제

### 3.1 창, 볼륨, 몰입 공간 차이 느끼기

- [ ] 일반 앱 window를 여러 개 배치해 본다.
- [ ] window를 가까이/멀리/좌우로 옮겨보며 읽기 좋은 거리를 찾는다.
- [ ] volumetric window가 일반 window와 어떻게 다르게 느껴지는지 관찰한다.
- [ ] mixed ImmersiveSpace에 들어갔을 때 사용자가 "앱 안으로 들어갔다"고 느끼는지 확인한다.
- [ ] 앱 창과 실제 책상이 동시에 보일 때 시선 이동이 피곤하지 않은지 확인한다.

질문:

- ControlPanel은 항상 떠 있어야 하는가?
- 박스는 window로 충분한가, 실제 anchor 기반 entity여야 하는가?
- 메모는 plain window가 맞는가, 아니면 책상 위 anchor가 필요한가?

### 3.2 시선+핀치 조작 감각

- [ ] 작은 버튼을 누를 때 눈 선택이 흔들리는지 확인한다.
- [ ] 현재 버튼 크기와 간격이 실기기에서 충분한지 본다.
- [ ] slider가 편한지, stepper나 preset 버튼이 더 나은지 비교한다.
- [ ] 드래그 회전이 직관적인지 확인한다.
- [ ] 손을 책상 위에 둔 상태에서 조작이 자연스러운지 확인한다.

### 3.3 실제 책상 위 앱 컨셉 검증

- [ ] 실제 책상 정리 상황을 만든다.
- [ ] 물건 옆에 메모를 띄우는 것이 의미 있는지 확인한다.
- [ ] 박스가 "정리함"처럼 느껴지는지 확인한다.
- [ ] 메모를 박스에 넣고 싶다는 욕구가 자연스럽게 생기는지 관찰한다.
- [ ] 박스가 열리고 닫히는 인터랙션이 꼭 필요한지 판단한다.
- [ ] 여러 메모가 있을 때 공간이 지저분해지는지 확인한다.

핵심 판단:

- 이 앱의 다음 Sprint는 "박스-메모 관계"가 맞는가?
- 아니면 먼저 "공간 배치/앵커/위치 기억"을 해야 하는가?

### 3.4 기본 visionOS 앱 사용 관찰

Vision Pro를 이해하기 위해 기본 앱도 짧게 관찰한다.

- [ ] Photos 또는 Safari 같은 기본 window 앱의 크기와 거리감을 본다.
- [ ] 여러 window를 배치했을 때 사용자가 어떻게 정리하는지 본다.
- [ ] system keyboard 입력 감각을 확인한다.
- [ ] 앱을 닫고 다시 여는 흐름을 확인한다.
- [ ] Digital Crown으로 몰입 정도를 조절하는 감각을 확인한다.
- [ ] 주변 공간과 앱 콘텐츠가 섞일 때 피로도가 생기는 지점을 확인한다.

---

## 4. 기술적으로 확인할 질문

### 4.1 ARKit

- [ ] `PlaneDetectionProvider.isSupported`가 true인지 확인한다.
- [ ] `NSWorldSensingUsageDescription` 권한 문구가 자연스러운지 확인한다.
- [ ] horizontal plane detection이 책상과 바닥을 어떻게 구분하는지 관찰한다.
- [ ] plane anchor의 extent width만으로 책상 후보를 고르는 것이 충분한지 판단한다.
- [ ] table/floor classification을 활용할 수 있는지 추가 조사 대상으로 남긴다.

### 4.2 RealityKit / 3D 모델

- [ ] `Entity(named: "TravelCaseScene", in: realityKitContentBundle)` 로딩이 실기기에서도 안정적인지 확인한다.
- [ ] `visualBounds(relativeTo: nil)` 기반 자동 scale이 실제 모델에서 적절한지 확인한다.
- [ ] 모델 재질, 조명, 그림자 느낌이 어색하지 않은지 본다.
- [ ] 모델이 책상 위 실제 오브젝트처럼 느껴지는지 확인한다.

### 4.3 SwiftUI WindowGroup

- [ ] `WindowGroup(id: "boxWindow", for: BoxPayload.self)`가 여러 박스를 다룰 때 기대대로 동작하는지 확인한다.
- [ ] `WindowGroup(for: MemoLabel.self)` plain window가 여러 메모를 다룰 때 충분한지 확인한다.
- [ ] 앱 재실행 후 scene restoration과 SwiftData 재열기 목록이 충돌하지 않는지 본다.

---

## 5. 테스트 중 바로 적어야 할 결정 후보

아래 항목은 실기기를 써보지 않으면 판단이 어렵다. 테스트 중 바로 결론 후보를 적는다.

| 항목 | 현재값/현재방식 | 실기기 판단 |
|------|----------------|-------------|
| ControlPanel 기본 크기 | 320 x 200 | |
| 박스 volumetric size | 0.6m cube | |
| TravelCase targetSize | 0.35m | |
| 메모 라벨 width | 400pt | |
| 메모 font size | 36 | |
| 메모 색상 | cyan/green/yellow/pink | |
| 공간 인식 시작 | 수동 버튼 | |
| 책상 후보 필터 | width > 0.3 | |
| 박스 위치 저장 | 아직 없음 | |
| 메모 위치 저장 | 아직 없음 | |
| 박스-메모 관계 | Sprint 2 후보 | |

---

## 6. 주말 후 바로 할 일

### 6.1 결과 정리

- [ ] 테스트 노트를 `docs/03-analysis/` 아래에 정리한다.
- [ ] 실패/불편/좋았던 점을 각각 분리한다.
- [ ] 실기기에서만 드러난 문제는 "Simulator에서 재현 불가"라고 명시한다.
- [ ] 영상/스크린샷이 있다면 어떤 테스트의 증거인지 파일명과 함께 기록한다.

### 6.2 다음 Sprint 우선순위 정하기

실기기 결과를 보고 아래 중 하나를 다음 Sprint로 고른다.

1. **공간 배치 안정화**
   - WorldAnchor 또는 실제 plane anchor 기반 배치
   - 박스/메모 위치 기억
   - 재실행 후 같은 공간에 복원

2. **박스-메모 관계**
   - 메모를 박스에 넣기
   - 박스 열기/닫기
   - 박스 안 메모 목록

3. **기본 UX 개선**
   - ControlPanel 크기/위치/버튼 개선
   - 메모 작성 흐름 개선
   - 실기기용 디버그 상태 표시

4. **3D 모델/시각 개선**
   - TravelCase 크기/재질/조명 조정
   - 책상 위에 놓인 느낌 강화
   - 박스 선택/회전/상태 표현

---

## 7. 참고할 Apple 공식 문서

- [visionOS - Apple Developer](https://developer.apple.com/visionos/)
- [ARKit in visionOS](https://developer.apple.com/documentation/arkit/arkit-in-visionos)
- [Placing content on detected planes](https://developer.apple.com/documentation/visionos/placing-content-on-detected-planes)
- [Combining spatial support from multiple frameworks](https://developer.apple.com/documentation/visionos/combining-spatial-support-from-multiple-frameworks)

