# Goodnotes·Notability 기능 비교와 StudyCoach 대응표

최종 조사일: 2026-09-04  
기준 StudyCoach 버전: `0.1.20` 실기 합격

## 이 표를 읽는 기준

Goodnotes와 Notability 열은 각 회사의 공개 지원 문서에서 확인할 수
있는 사용자 기능만 비교한다. 두 앱은 비공개 상용 앱이므로 내부 구현
방식은 추측하지 않는다. 요금제, 기기, 운영체제에 따라 일부 기능의
제공 범위가 달라질 수 있다.

StudyCoach 열은 다음 상태를 구분한다.

| 표시 | 의미 |
|---|---|
| ✅ 기기 확인 | 현재 PaperKit 시험 경로에서 사용자가 iPadOS 26 실기로 확인함 |
| 🧪 구현·재검증 필요 | 코드 또는 시스템 기능은 존재하지만 현재 경로에서 전체 회귀 시험이 끝나지 않음 |
| 🟨 일부 | 일부만 있거나 기존 `StudyCoachRootView`의 PDFKit/PencilKit 경로에만 있음 |
| 🐞 오류 | 기능은 있으나 알려진 오류가 있음 |
| ❌ 없음 | 현재 사용할 수 있는 구현이 없음 |
| 🔎 조사 필요 | 공개 API 또는 실제 기기에서 가능 범위를 더 확인해야 함 |

중요: 사용자가 실제로 만족한 `0.1.19` PaperKit PDF 편집기는 아직
`StudyCoachPaperKitPDFDiagnosticView()`라는 시험 진입점이다. 기본 공개
진입점 `StudyCoachRootView()`는 과거 PDFKit/PencilKit 편집기를 연다.
따라서 아래의 “현재 앱”은 **앞으로 제품화할 PaperKit 시험 경로**를
기준으로 하고, 과거 경로에만 있는 기능은 따로 표시한다.

## 1. 필기감과 필기 도구

| 기능 | Goodnotes | Notability | 현재 StudyCoach `0.1.20` 대응 |
|---|---|---|---|
| Apple Pencil 저지연 필기 | 지원 | 지원 | ✅ PaperKit 필기감과 좌표 일치를 실기 확인 |
| 손가락 이동·두 손가락 확대 | 지원 | 지원 | ✅ 실기 확인 |
| 펜 | 지원 | 지원 | ✅ Apple 시스템 도구로 실기 확인 |
| 형광펜 | 지원 | 지원 | ✅ Apple 시스템 도구로 실기 확인 |
| 연필/그래파이트 계열 | 지원 | 지원 | 🧪 시스템 도구 선택기에 포함될 수 있으나 현재 회귀 시험 필요 |
| 펜 종류·프리셋 여러 개 | 지원 | 지원, 도구 복제 가능 | 🟨 사용자 지정 얇은 펜 항목 코드는 있으나 표시·선택·실제 굵기 재검증 필요 |
| 도구별 색상 | 지원 | 지원 | 🟨 앱 자체 빠른 색상 슬롯 없음; `0.1.21` 정밀 도구 상태로 설계 완료 |
| 도구별 굵기 | 지원 | 지원 | 🟨 현재 고정 얇은 도구만 있음; 10단계/연속 폭과 native 유효 범위 설계 완료 |
| 점선·파선 자유 필기 | 지원 | 지원 | 🔎 공개 `PKInkingTool`에 pattern 속성이 없어 별도 격리 시험 필요 |
| 형광펜 펜촉 각도 | 제품 설정 범위에 따름 | 제품 설정 범위에 따름 | 🔎 공개 azimuth API로 설계 가능; iPad marker 동작 검증 필요 |
| 필압·기울기 반응 | 지원 | 지원 | ✅ PaperKit 시스템 필기 엔진이 담당; 앱이 획을 직접 합성하지 않음 |
| 획 전체 지우개 | 지원 | 지원 | 🟨 현재 단일 시스템 지우개는 작동; `.vector` 폭 직접 조절 미구현 |
| 부분/정밀 지우개 | 지원 | 지원 | 🟨 현재 단일 시스템 지우개는 작동; `.bitmap`/`.fixedWidthBitmap` 분리 미구현 |
| 지우개 사용 뒤 펜 자동 복귀 | 설정/동작 제공 | 설정 제공 | ❌ 앱 설정 없음 |
| 자유형 선택(올가미) | 지원 | 지원 | 🧪 PaperKit 최신 기능 세트에 포함되지만 현재 PDF 경로 실기 확인 필요 |
| 사각형 선택 | 선택 기능 제공 | 지원 | 🔎 PaperKit 노출 방식과 현재 SDK에서의 동작 조사 필요 |
| 선택 항목 이동·크기·회전 | 지원 | 지원 | 🧪 PaperKit 기능 세트로 예상되지만 현재 PDF 경로 실기 확인 필요 |
| 실행 취소·다시 실행 | 지원 | 지원 | ✅ StudyCoach 전용 버튼 실기 확인 |
| Apple Pencil 두 번 탭 | 지원 | 지원 | ✅ `0.1.20` 시험 항목에서 실기 확인 |
| Apple Pencil Pro 스퀴즈 | 지원 기기에서 지원 | 지원 기기에서 지원 | 🧪 시스템 도구 선택기를 통해 유지될 가능성이 있으나 실기 확인 필요 |
| 선을 긋고 유지해 직선 보정 | 지원 | 지원 | 🐞 PaperKit 보정은 작동하지만 사용자가 원하는 동작·정도까지 개선되지 않음 |
| 도형 인식/보정 | 지원 | 지원 | 🧪 PaperKit 기능 세트에 포함될 수 있으나 실기 확인 필요 |
| 자 | 지원 | 지원 | 🧪 시스템 도구에 노출될 수 있으나 현재 회귀 시험 필요 |
| 테이프/가리기 학습 도구 | 지원 | 지원 | ❌ 없음 |
| 레이저 포인터 | 지원 | 지원 | ❌ 없음 |
| 자체 디자인 필기 툴바 | 지원 | 지원 | ✅ 최소 연결층 실기 합격; 정밀 프리셋과 삽입 도구는 미구현 |
| 툴바 도구 순서·표시 맞춤 | 지원 | 지원 | ❌ 없음 |
| 툴바 이동·도킹 | 지원 | 지원 | ❌ 없음 |

## 2. PDF, 페이지, 노트 편집

| 기능 | Goodnotes | Notability | 현재 StudyCoach `0.1.20` 대응 |
|---|---|---|---|
| PDF 가져오기 | 지원 | 지원 | ✅ Files 선택기로 실기 확인 |
| PDF 위 필기 | 지원 | 지원 | ✅ PaperKit 경로에서 실기 확인 |
| 확대 시 선명한 필기 | 지원 | 지원 | ✅ PaperKit 필기가 벡터처럼 선명함을 실기 확인 |
| 확대 후 PDF 고해상도 표시 | 지원 | 지원 | ✅ `0.1.19`에서 동작; Notability보다 다소 느리지만 사용 가능하다고 수용 |
| 확대 중 불필요한 재렌더링 방지 | 지원되는 사용감 | 지원되는 사용감 | ✅ 핀치 중간 렌더링을 멈추고 종료 후 필요한 해상도를 요청 |
| 고정 배율 화면 이동 시 선명도 유지 | 지원되는 사용감 | 지원되는 사용감 | ✅ 완성 타일을 유지하며 새 영역만 요청하는 `0.1.19` 방식 수용 |
| 스캔 PDF CropBox/회전 표시 | 지원되는 뷰어 동작 | 지원되는 뷰어 동작 | 🐞 일부 스캔 PDF가 잘려 보이거나 확대 범위가 달라짐 |
| 서로 다른 페이지 크기 | 지원 | 지원 | 🔎 현재 기하 오류와 함께 대표 문서 시험 필요 |
| 이전/다음 페이지 | 지원 | 지원 | ✅ 현재 시험 화면에 있음 |
| 페이지 번호 직접 이동 | 지원 | 지원 | 🟨 과거 기본 편집기에만 있고 PaperKit 시험 화면에는 없음 |
| 페이지 썸네일 | 지원 | 지원 | ❌ 없음 |
| 빈 노트/빈 페이지 생성 | 지원 | 지원 | ❌ 없음 |
| 페이지 템플릿 | 지원 | 지원 | ❌ 없음 |
| 페이지 추가·삭제·복제·순서 변경 | 지원 | 지원 | ❌ 없음 |
| 북마크/즐겨찾기 페이지 | 지원 | 지원 | ❌ 없음 |
| 세로 연속 페이지 | 지원 | 지원 | ❌ 현재 한 페이지씩 표시 |
| 이미지·카메라·문서 스캔 삽입 | 지원 | 지원 | 🟨 없음; PaperKit `insertNewImage` 기반 설계 가능 |
| 텍스트 상자 | 지원 | 지원 | 🟨 없음; PaperKit `insertNewTextbox` 기반 설계 가능 |
| 도형·스티커 | 지원 | 지원 | 🧪 PaperKit 요소 기능은 있으나 앱 UI·저장·PDF 경로 시험 없음 |
| PDF 목차·내부 링크 | 지원 | 지원 | ❌ 없음 |
| 화면 분할/여러 노트 보기 | 지원 | 지원 | ❌ 없음 |

## 3. 저장, 문서함, 내보내기

| 기능 | Goodnotes | Notability | 현재 StudyCoach `0.1.20` 대응 |
|---|---|---|---|
| 자동 저장 | 지원 | 지원 | 🟨 저장 버튼, 페이지 이동, 백그라운드, 화면 해제 시 저장하지만 획 변화 즉시 추적은 미완성 |
| 원자적 저장/이전 파일 보호 | 제품 내부 방식은 비공개 | 제품 내부 방식은 비공개 | 🧪 `.atomic` 쓰기는 있으나 최신 변경 유실 방지 회귀 시험 필요 |
| 앱 재실행 뒤 필기 복원 | 지원 | 지원 | 🧪 페이지별 `PaperMarkup` 복원 코드가 있으며 과거 실기 성공; 현재 전체 회귀 필요 |
| 페이지별 편집 가능한 필기 | 지원 | 지원 | 🧪 페이지별 `PaperMarkup` 파일로 구현 |
| 여러 문서가 보이는 문서함 | 지원 | 지원 | 🟨 마지막 PDF 복원 중심; 문서함 UI와 목록 모델 없음 |
| 폴더·분류 | 지원 | 지원 | ❌ 없음 |
| 최근 문서·즐겨찾기 | 지원 | 지원 | ❌ 없음 |
| 이름 변경·정렬·격자/목록 | 지원 | 지원 | ❌ 없음 |
| 휴지통·삭제 복구 | 지원 | 지원 | ❌ 없음 |
| iCloud/기기 간 동기화 | 지원 | 지원 | ❌ 없음 |
| 편집 가능한 전용 형식 백업 | 지원 | 지원 | ❌ 없음 |
| 평면화 PDF 내보내기 | 지원 | 지원 | ❌ 없음 |
| 이미지 내보내기·공유 | 지원 | 지원 | ❌ 없음 |
| 원본 PDF 비파괴 보관 | 지원되는 작업 방식 | 지원되는 작업 방식 | ✅ 원본 PDF와 `PaperMarkup`을 별도 저장하는 구조 |

## 4. 검색, 공부, 오디오, AI

| 기능 | Goodnotes | Notability | 현재 StudyCoach `0.1.20` 대응 |
|---|---|---|---|
| PDF 텍스트 검색 | 지원 | 지원 | ❌ 없음 |
| 손글씨 인식·검색 | 지원 | 지원 | ❌ 없음 |
| 손글씨를 텍스트로 변환 | 지원 | 지원 | ❌ 없음 |
| 수식 인식/변환 | 지원 범위는 제품별 상이 | 지원 | ❌ 없음 |
| 오디오 녹음·재생 | 지원 | 지원 | ❌ 없음 |
| 필기와 녹음 시점 연결 | 지원 범위는 제품별 상이 | 지원 | ❌ 없음 |
| 녹음 전사 | 지원 범위는 제품별 상이 | 지원 | ❌ 없음 |
| 플래시카드/학습 세트 | 지원 | 학습 기능 형태가 다름 | ❌ 없음 |
| 간격 반복 학습 | Smart Learn 제공 | 제품별 학습 기능 | ❌ 없음 |
| 현재 페이지 기반 AI 질문 | 지원 | 지원 | ❌ 없음 |
| 선택 영역/손글씨를 AI 문맥으로 사용 | 지원 | 제품별 기능 | ❌ 없음 |
| 요약·퀴즈 생성 | 지원 | 지원 | ❌ 없음 |
| 학습 기록·약점 복습 | 제품별 기능 | 제품별 기능 | ❌ 없음 |

## 현재 위치 요약

| 영역 | 현재 판단 |
|---|---|
| 필기 엔진과 필기감 | **핵심 성공**. PaperKit 방식을 유지해야 함 |
| PDF 배경 렌더링 | **사용 가능 판정**. 새로운 오류가 없으면 더 손대지 않음 |
| 필기 도구 UI | **가장 큰 사용자 화면 공백**. 아직 Apple 기본 UI에 의존 |
| PDF 페이지 기하 | **확인된 오류 존재**. 일부 스캔 PDF의 잘림·확대 범위 불일치 |
| 저장 안정성 | **기초 구현 존재, 완결되지 않음**. 강제 종료 직전 변경까지 보장하는 시험 필요 |
| 노트 앱 기본 구조 | **대부분 없음**. 문서함·빈 노트·페이지 관리부터 필요 |
| 검색·공부·오디오·AI | **아직 없음**. 안정적인 노트·PDF 편집 위에 추가할 영역 |

이 문서는 기능 존재 여부만 기록한다. 이후 단계와 버전 경계는
[개발 순서](DEVELOPMENT_SEQUENCE.md)에 따로 기록한다.

## 공개 근거

### Apple

- [Meet PaperKit (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/285/)
- [PaperMarkupViewController](https://developer.apple.com/documentation/paperkit/papermarkupviewcontroller)
- [Configuring the PencilKit tool picker](https://developer.apple.com/documentation/pencilkit/configuring-the-pencilkit-tool-picker)

### Goodnotes

- [Improved User Interface](https://support.goodnotes.com/hc/en-us/articles/13682253498767-Improved-User-Interface)
- [Customize the toolbar](https://support.goodnotes.com/hc/en-us/articles/8900755183631-Customize-the-toolbar)
- [Pen tool and Draw and Hold](https://support.goodnotes.com/hc/en-us/articles/7353756785679-Write-and-customize-ink-with-the-Pen-tool)
- [Import files](https://support.goodnotes.com/hc/en-us/articles/7353717816463-Import-files-into-Goodnotes)
- [Favorites and bookmarks](https://support.goodnotes.com/hc/en-us/articles/7353727934095-Use-Favorites-and-bookmarks-in-Goodnotes)
- [Reorder pages](https://support.goodnotes.com/hc/en-us/articles/7353718659343-Reordering-pages-in-a-document)
- [Notebook templates](https://support.goodnotes.com/hc/en-us/articles/7353728093199-Import-and-manage-custom-notebook-templates)
- [Study Sets and Smart Learn](https://support.goodnotes.com/hc/en-us/articles/7353756529551-Getting-Started-with-Study-Sets-and-Smart-Learn)
- [Goodnotes AI](https://support.goodnotes.com/hc/en-us/articles/10779112528399-A-guide-to-Goodnotes-AI)
- [Presentation Mode and laser pointer](https://support.goodnotes.com/hc/en-us/articles/7353727934223-Presentation-Mode)

### Notability

- [Customize your Toolbox](https://support.gingerlabs.com/hc/en-us/articles/6272405402650-Customize-your-Toolbox)
- [Editor tools](https://support.gingerlabs.com/hc/en-us/articles/4867633230234-Getting-Started-with-Notability)
- [Select tool](https://support.gingerlabs.com/hc/en-us/articles/360018646412-Select-Tool)
- [Handwriting and math conversion](https://support.gingerlabs.com/hc/en-us/articles/360003878731-Handwriting-and-Math-Conversion)
- [Custom templates and note backgrounds](https://support.gingerlabs.com/hc/en-us/articles/227864627-Custom-Templates-and-Note-Background)
- [Recording and playing audio](https://support.gingerlabs.com/hc/en-us/articles/206060617-Recording-and-Playing-Audio)
