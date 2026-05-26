# 교재 제작 자동화 가이드

Last updated: 2026-05-26

이 문서는 Desktop Organizer 학습 교재를 반복해서 만들 때 토큰과 수작업을 줄이기 위한 작업 규칙이다.

## 목표

AI가 매번 HTML 스타일, 목차 생성, iCloud 복사, 키워드 검증 코드를 다시 만들지 않게 한다.

앞으로 교재를 만들 때 AI는 Markdown 본문 작성에 집중하고, HTML 변환과 검증은 `tools/workbook_builder.py`를 사용한다.

## 기본 흐름

1. `docs/05-study/`에 Markdown 교재를 작성한다.
2. `tools/workbook_builder.py`로 HTML을 만든다.
3. `--publish` 옵션으로 iCloud Drive의 Workbooks 폴더에 복사한다.
4. 출력된 검증 결과에서 목차 수, 코드 블록 수, 키워드를 확인한다.

## 명령 예시

```sh
python3 tools/workbook_builder.py docs/05-study/10-spatial-app-refactoring-guide.md \
  --publish \
  --label "Desktop Organizer Study Guide 10" \
  --subtitle "공간 앱이 커질 때 파일, 상태, 서비스, Entity 로직을 어떤 기준으로 나누고 성장시킬지 정리한 입문 교재입니다." \
  --keyword WorkspaceRealityView \
  --keyword PlaneDetectionService \
  --keyword 리팩토링
```

기본 출력 위치는 `/private/tmp/<markdown-file-name>.html`이다.

`--publish`를 붙이면 다음 위치에도 복사된다.

```text
/Users/bk/Library/Mobile Documents/com~apple~CloudDocs/Workbooks/swift/
```

## 스크립트가 자동으로 하는 일

- Markdown 제목을 HTML 제목으로 사용
- `##` 제목을 목차 링크로 변환
- 표, 목록, 코드 블록 변환
- 기존 교재와 비슷한 HTML 스타일 적용
- iCloud Workbooks 폴더로 복사
- Markdown/HTML에 지정 키워드가 들어 있는지 확인
- `h2`, `toc`, `code_blocks` 개수 출력

## AI에게 요청할 때 짧게 말하는 방법

앞으로는 이렇게 말하면 된다.

```text
다음 교재 만들어줘. workbook_builder.py로 HTML까지 publish하고 키워드 검증해줘.
```

또는 특정 주제가 있으면 이렇게 말한다.

```text
Swift Concurrency 교재를 11번으로 만들어줘. 기존 교재 스타일로, workbook_builder.py 사용해서 HTML까지 publish해줘.
```

## 토큰을 아끼는 운영 규칙

- HTML 스타일 코드는 다시 설명하지 않는다.
- 변환 스크립트는 수정이 필요할 때만 읽는다.
- 새 교재 작업에서는 기존 교재 1개만 참고한다.
- 검증 키워드는 3개에서 8개 정도만 지정한다.
- 교재 본문에 들어갈 코드 근거가 필요할 때만 프로젝트 파일을 읽는다.
- 단순 HTML 재생성은 Markdown을 다시 읽지 않고 스크립트만 실행한다.

## 현재 한계

이 스크립트는 이 프로젝트 교재용 Markdown subset만 지원한다.

지원하는 문법은 다음과 같다.

- `#`, `##`, `###` 제목
- 문단
- `-` bullet list
- `1.` numbered list
- GitHub 스타일 표
- fenced code block
- inline code
- bold text

이미지, Mermaid, footnote, nested list 같은 문법이 필요하면 스크립트를 확장해야 한다.
