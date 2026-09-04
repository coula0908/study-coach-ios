# StudyCoach 자체 툴바와 확장 필기 기능 설계

상태: **`0.1.20` 최소 연결층 실기 합격, 확장 설계 검토 완료, 구현 전**
최종 조사일: 2026-09-04

## 확인된 기준선

사용자가 iPadOS 26의 Swift Playgrounds에서 `0.1.20` 시험 항목 1~13을
모두 통과했다고 확인했다. 따라서 다음은 이미 성립한 기준선이다.

- StudyCoach 자체 버튼으로 펜, 형광펜, 지우개, undo, redo를 조작할 수 있다.
- 손가락 이동, 두 손가락 확대, Apple Pencil 필기와 좌표가 유지된다.
- Apple 기본 도구 UI와 StudyCoach UI를 바꿔도 PaperKit 필기감과 현재
  렌더러가 깨지지 않는다.

`0.1.20`은 연결 가능성만 검증한 버전이다. 최종 툴바가 Apple 팔레트의
다섯 단계 값을 그대로 흉내 내는 구조로 굳어져서는 안 된다.

## 핵심 결정

StudyCoach 상태가 도구 설정의 **유일한 기준(source of truth)** 이 된다.

- 자체 UI가 정확한 펜 종류, 색, 굵기, 펜촉 각도, 지우개 종류와 폭을
  보관한다.
- `PaperMarkupViewController.drawingTool`에 그 값으로 만든
  `PKInkingTool`, `PKEraserTool`, `PKLassoTool`을 직접 적용한다.
- 실제 StudyCoach 모드에서는 숨긴 `PKToolPicker`를 값이나 하드웨어
  동작의 중계기로 사용하지 않는다. `UIPencilInteraction`을 편집기 뷰에
  직접 붙여 Apple Pencil 두 번 탭과 Pencil Pro 스퀴즈를 받는다.
- `0.1.20`의 `PKToolPicker`는 연결 비교가 필요할 때만 쓰는 격리된 Apple
  UI A/B fallback으로 남긴다. 제품 툴바의 일부가 아니다.
- 하드웨어 동작이 펜 또는 지우개 종류를 바꾸면 StudyCoach는 해당
  종류의 마지막 정밀 프리셋을 다시 적용한다. Apple 팔레트의 굵기나
  색이 StudyCoach 값을 덮어쓰게 하지 않는다.
- Pencil 표본 수집, 획 보정, 저지연 렌더링은 계속 PaperKit/PencilKit가
  담당한다. 일반 필기 획을 앱이 직접 다시 그리지 않는다.

공개 PencilKit API는 `PKInkingTool`의 정확한 `width`, `color`,
`azimuth`와 잉크 종류별 `validWidthRange`를 제공한다. `PKEraserTool`도
부분/획 지우개 종류와 정확한 `width` 및 유효 범위를 제공한다. 따라서
Apple UI의 단계 수는 엔진 제한이 아니라 기본 UI의 선택 방식이다.

## 사용자 화면 구조

Goodnotes의 Active Tool Menu와 Notability의 도구별 프리셋 방식을
참조한다. 화면 자산을 복제하지 않고 다음 상호작용 원칙만 사용한다.

```text
상단 주 도구줄
  펜 | 형광펜 | 지우개 | 선택 | 텍스트 | 이미지 | 녹음 | undo | redo
                 │
                 └─ 선택한 도구의 맥락 패널
                    굵기 · 빠른 색 · 각도 · 모드 · 자동 복귀 등
```

- 주 도구를 한 번 누르면 즉시 마지막 프리셋으로 전환한다.
- 이미 선택된 주 도구를 다시 누르면 상세 설정을 펼친다.
- 펜과 형광펜을 선택하면 저장 색상과 굵기가 바로 옆에 나타난다.
- 텍스트와 이미지는 한 번 삽입한 뒤 선택 도구로 자동 복귀한다.
- 녹음 중에는 빨간 상태, 경과 시간, 일시정지/종료를 항상 분명하게
  표시한다.
- iPad 가로 화면에서는 한 줄을 우선하고, 좁은 화면에서는 덜 쓰는
  삽입 도구를 `+` 메뉴로 접는다.

## 상태와 책임 분리

```text
StudyCoachToolPaletteView (SwiftUI)
              │ 사용자 의도
              ▼
StudyCoachToolStore (정밀 설정과 프리셋의 기준)
        ├─────┼──────────┬───────────────┐
        ▼     ▼          ▼               ▼
 NativeToolFactory  PaperElementInserter  AudioSessionController
        │                 │               │
        ▼                 ▼               ▼
 PaperMarkupViewController / PaperMarkup  문서별 오디오 파일·시간축
        ▲
        │ 도구 종류 전환만 전달
 PencilHardwareBridge (UIPencilInteraction)
```

| 구성 요소 | 책임 | 책임지지 않는 것 |
|---|---|---|
| `StudyCoachToolPaletteView` | 도구 버튼, 맥락 패널, 접근성, 배치 | PaperKit 객체 직접 조작 |
| `StudyCoachToolStore` | 활성 도구, 10단계 굵기, 색상 슬롯, 각도, 지우개 폭, 마지막 도구 | 획 렌더링과 PDF 좌표 |
| `NativeToolFactory` | 앱 값을 유효 범위로 제한하고 정확한 `PKTool` 생성 | Apple 팔레트 상태 저장 |
| `PencilHardwareBridge` | `UIPencilInteraction`으로 두 번 탭/스퀴즈를 직접 받고 선호 동작을 앱 상태로 전달 | 굵기·색·각도의 기준, Apple 팔레트 표시 |
| `PaperElementInserter` | PaperKit 텍스트·이미지·도형을 현재 페이지 좌표에 삽입 | 자유 필기 엔진 |
| `AudioSessionController` | 권한, 녹음 파일, 중단/재개, 미터, 시간축 | PaperMarkup 내부 저장 |
| `PaperMarkupViewController` | 입력, 보정, 표시, 선택, undo/redo, 페이지 좌표 | 앱 툴바 프리셋과 문서함 |

## 기능별 구현 판단

### 1. 펜·형광펜의 10단계 굵기

**기본 엔진을 그대로 사용해 구현 가능하다.**

- 도구별로 `0...9` 단계와 정확한 페이지 포인트 값을 저장한다.
- 시작 시 실제 `InkType.validWidthRange`를 읽어 지원 범위를 확인한다.
- 10단계는 단순 등간격보다 얇은 구간을 촘촘하게 하는 비선형 배열을
  사용한다. 공부 필기에서는 0.3과 0.5의 차이가 8과 8.2의 차이보다
  훨씬 중요하기 때문이다.
- 현재 `logicalPageScale = 2`에 맞춰 초기 값을 제안하되, 실제 iPad에서
  한글 필기와 형광펜을 보고 별도의 펜/형광펜 표를 조정한다.
- 단계 버튼과 연속 슬라이더를 같이 둘 수 있다. 버튼은 빠른 선택,
  슬라이더는 세밀 조절이며 둘 다 같은 정확한 `width`를 갱신한다.
- 새 값은 새 획에만 적용하고 기존 획은 바꾸지 않는다.

### 2. 빠른 색상 슬롯

**기본 엔진을 그대로 사용해 구현 가능하다.**

- 펜과 형광펜이 각각 독립된 색상 모음을 가진다.
- 기본 화면에는 6개를 노출하고 최대 12개까지 저장한다.
- 색을 한 번 누르면 즉시 선택하고, 선택된 색을 다시 누르거나 길게
  누르면 시스템 색상 선택기를 연다.
- 색의 순서 변경, 추가, 삭제와 최근 색을 앱 설정에 저장한다.
- 키보드가 연결된 경우 `⌥⌘1...8` 같은 색상 단축키를 나중에 추가할
  수 있도록 슬롯에 안정적인 ID를 둔다.

### 3. 형광펜 기울기

**공개 API상 가능하지만 물리 기기 확인이 필요한 기능이다.**

- `PKInkingTool(.marker, color:width:azimuth:)`의 기본 `azimuth`를
  StudyCoach가 직접 지정한다.
- 첫 UI는 0°, 45°, 90° 세 프리셋과 상세 슬라이더를 제공한다.
- 이 값은 마커 펜촉의 기본 방향이다. Apple Pencil을 실제로 기울일 때
  들어오는 실시간 각도와 필압은 계속 PencilKit가 처리한다.
- marker가 세 각도를 눈에 띄게 구분하는지, 방향 전환 때 필기감과
  기존 PaperMarkup 복원이 같은지는 iPad에서 별도 A/B 시험한다.

### 4. 부분·획 지우개와 범위

**기본 엔진을 그대로 사용해 구현 가능하다.**

- 정밀 지우개: `.fixedWidthBitmap` + 폭 슬라이더
- 부분 지우개: `.bitmap` + 폭 슬라이더
- 획 지우개: `.vector` + 폭 슬라이더
- 각 종류의 `validWidthRange` 안에서 10단계 또는 연속 폭을 제공한다.
  획 지우개도 충돌 판정 폭을 직접 정할 수 있으므로 Apple UI에 폭
  조절이 보이지 않는 것이 엔진 제한은 아니다.
- `필기만`, `형광펜만` 같은 Goodnotes식 필터는 `PKEraserTool` 단독
  속성이 아니다. 필요하면 지우기 전후의 획 종류를 비교하는 별도
  데이터 조작이 필요하므로 기본 세 지우개가 안정된 뒤 다룬다.
- `한 번 지우고 이전 펜으로 복귀` 옵션은 Store의
  `lastInkingPresetID`로 처리한다.
- Apple Pencil 두 번 탭과 스퀴즈는 `UIPencilInteraction`의
  `preferredTapAction`/`preferredSqueezeAction`을 존중하면서 현재 정밀
  프리셋과 지우개 또는 이전 도구를 직접 전환한다.

### 5. 라쏘

**자유형 선택은 기본 엔진으로 가능하다.**

- `PKLassoTool()`을 `drawingTool`에 적용하고 PaperKit의 선택,
  이동, 크기 변경, 회전, 복사, 삭제 UI를 사용한다.
- StudyCoach 툴바는 자유형 라쏘 버튼과 선택된 객체의 맥락 메뉴를
  제공한다.
- 공개 `PKLassoTool`에는 사각형/자유형 모드 속성이 없다. 사각형
  선택은 PaperKit가 현재 SDK에서 별도로 노출하는지 먼저 시험하고,
  없다면 나중에 앱의 사각 선택 제스처를 PaperKit 선택 ID로 변환하는
  독립 기능으로 취급한다.

### 6. 텍스트 추가

**Apple 기본 도구 UI 없이 PaperKit 구조화 객체로 구현 가능하다.**

- 텍스트 버튼을 누르고 페이지를 탭하거나 드래그해 삽입 위치를 정한다.
- `suggestedFrameForInserting`로 현재 보이는 페이지 안의 안전한 프레임을
  구한 뒤 `PaperMarkup.insertNewTextbox`를 사용한다.
- 폰트, 크기, 정렬, 색, 배경과 자주 쓰는 텍스트 스타일은 StudyCoach
  맥락 패널에서 관리한다.
- 결과는 비트맵이나 Pencil 획이 아니라 선택·이동·편집 가능한 PaperKit
  요소로 PaperMarkup에 함께 저장한다.

### 7. 이미지 추가

**Apple 기본 도구 UI 없이 PaperKit 구조화 객체로 구현 가능하다.**

- StudyCoach 이미지 버튼이 PhotosPicker 또는 파일 선택기를 연다.
- 이미지를 디코딩하고 방향을 정규화한 뒤 페이지의 안전한 삽입 프레임에
  `PaperMarkup.insertNewImage`로 넣는다.
- 삽입 직후 선택 상태로 전환해 이동, 비율 유지 크기 변경, 회전과
  삭제를 할 수 있게 한다.
- 원본이 매우 큰 경우 표시용 축소본과 원본 자산 보존 정책을 문서
  저장 형식과 함께 정해야 한다. 개인 PDF에 이미지를 평면화하지 않는다.

### 8. 녹음

**PaperKit 기능이 아니라 별도의 문서 서비스로 구현해야 한다.**

- `AVAudioRecorder`로 문서별 오디오 파일을 만들고
  `AVAudioApplication`을 통해 마이크 권한을 요청한다.
- 녹음 파일, 구간, 생성 시각, 길이와 중단 원인을 PaperMarkup 밖의
  문서 메타데이터에 저장한다.
- 첫 단계는 시작/일시정지/종료/재생과 백그라운드·전화 중단 복구다.
- Notability식 Note Replay는 다음 단계다. PaperKit의 그리기 시작·변경
  이벤트 시각과 오디오의 단조 증가 시간을 같은 타임라인에 기록해,
  필기나 객체를 탭하면 해당 시점으로 이동한다.
- 현재 Swift Playgrounds에서는 `PaperMarkupViewController.Delegate`
  직접 conformance가 Xcode CI와 다르게 거부된 이력이 있다. 따라서
  시간축 관찰은 해당 delegate에 바로 의존하지 않고, 별도 adapter가
  실제 기기에서 컴파일되는지 격리 시험하거나 observable markup 변경을
  사용하는 방식으로 결정한다.
- 녹음 중임을 나타내는 색, 타이머와 시스템 마이크 표시를 숨기지 않는다.
- 현재 자동 저장과 문서 컨테이너가 아직 제품화되지 않았으므로, 버튼의
  자리만 툴바 설계에 포함하고 실제 녹음은 저장 구조 이후에 구현한다.

### 9. 점선·파선 자유 필기

**현재 공개 기본 도구에 직접 대응하는 속성이 없다. 별도 기술 시험이
필요하다.**

`PKInkingTool`이 공개하는 도구 속성은 잉크 종류, 색, 굵기와 기본
azimuth이며 dash pattern은 없다. Goodnotes와 Notability가 점선·파선을
지원한다는 사실은 확인되지만 두 앱의 내부 구현은 공개되지 않았다.

우선순위는 다음과 같다.

1. PaperKit의 구조화 직선/도형에서 파선 스타일이 현재 SDK에 노출되는지
   확인한다. 가능하면 직선과 도형의 점선부터 공식 엔진으로 제공한다.
2. 자유 필기는 PencilKit의 완료된 `PKStroke`를 일정 거리로 나누거나
   mask 처리하면서 `renderState`와 `renderGroupID`를 보존하는 격리 시험을
   한다.
3. 이 방식은 쓰는 동안 실선이었다가 손을 뗀 뒤 점선으로 바뀌거나,
   지우개·라쏘·undo·저장과 충돌할 수 있다. 그런 문제가 하나라도 있으면
   현재 만족한 필기감을 희생해 넣지 않는다.
4. 처음부터 별도 터치 수집/Metal 필기 엔진을 만드는 선택은 마지막
   수단이다. 현재 목표인 빠른 공부 시작과 맞지 않는다.

## 프리셋 데이터 초안

PaperKit/UIKit 객체는 저장하지 않고 앱이 소유하는 값만 직렬화한다.

```swift
enum StudyToolKind: String, Codable, Sendable {
    case pen, highlighter, eraser, lasso, text, image, audio
}

enum StudyEraserMode: String, Codable, Sendable {
    case precision, partial, stroke
}

enum StudyStrokePattern: String, Codable, Sendable {
    case solid, dashed, dotted
}

struct InkPreset: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var toolKind: StudyToolKind
    var inkIdentifier: String
    var colorRGBA: RGBAColor
    var widthInPagePoints: Double
    var azimuthRadians: Double
    var pattern: StudyStrokePattern
}

struct EraserPreset: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var mode: StudyEraserMode
    var widthInPagePoints: Double
    var returnsToPreviousInk: Bool
}

struct ToolPalettePreferences: Codable, Equatable, Sendable {
    var orderedToolKinds: [StudyToolKind]
    var selectedToolKind: StudyToolKind
    var selectedPresetIDByTool: [StudyToolKind: UUID]
    var colorSlotIDsByTool: [StudyToolKind: [UUID]]
    var lastInkingPresetID: UUID
    var placement: PalettePlacement
}
```

`pattern`은 미래 호환을 위해 상태에 둘 수 있지만, 점선 기술 시험이
통과하기 전에는 UI에서 활성화하지 않는다.

## 시행착오를 줄이기 위한 구현 묶음

다음 항목은 모두 툴바에 속하지만 한 번에 합치지 않는다.

1. **정밀 native tool 묶음:** 10단계 펜/형광펜 굵기, 빠른 색상,
   형광펜 azimuth, 세 지우개와 폭, 자동 복귀. `drawingTool` 직접 적용이
   기준이며 Pencil 입력·PaperMarkup 형식은 변경하지 않는다.
2. **선택·삽입 묶음:** 자유형 라쏘, 텍스트 상자, 이미지 삽입. 모두
   PaperKit 구조화 요소와 현재 좌표계를 사용한다.
3. **패턴 획 격리 시험:** 점선·파선의 live/commit 모양, undo, 두 지우개,
   라쏘, 저장·복원, 확대 선명도를 하나씩 검증한다.
4. **오디오 묶음:** 문서 저장과 자동 복구가 안정된 뒤 녹음 파일과
   타임라인을 추가한다. 툴바 모양과 기능 구현 시점을 분리한다.

각 묶음은 Windows 정적 검사와 Apple CI 뒤 실제 iPadOS 26에서 시험한다.
한 묶음이 실패하면 다음 묶음으로 진행하지 않고, 합격한 앞 묶음은
되돌리지 않는다.

## 공개 구현에서 가져올 구조와 경계

| 자료 | 확인한 구조 | StudyCoach 적용 | 라이선스/경계 |
|---|---|---|---|
| Cecilia's Notes | PencilKit 필기와 텍스트·PDF·이미지·오디오를 동등한 문서 구성요소로 분리, 로컬 우선 | 혼합 콘텐츠와 서비스 분리 원칙 | MIT. 현재는 구조만 참고, 코드 미복사 |
| Sketchbook app | `EditorViewModel`이 색, 폭, 지우개 폭, 도구 모드를 소유하고 Canvas가 실행 | Store가 도구 값의 기준이 되는 구조 | MIT. Swift Playgrounds용 패키지로 직접 채택하지 않음 |
| Pieces of Paper | 실제 PencilKit 앱의 picker/input 함정과 물리 기기 격리 시험 기록 | picker를 값 저장소로 취급하지 않고 단일 변경 시험 | MIT. 문서의 검증 교훈만 참고 |
| Jottre | App Store에 배포된 PencilKit 중심 최소 필기 앱 | 빠른 진입과 필기 우선 UX만 참고 | GPL-3.0이므로 코드를 복사·적용하지 않음 |

외부 코드를 실제로 복사하거나 변형할 때는 정확한 commit, 파일, 라이선스와
이유를 `THIRD_PARTY_NOTICES.md`에 먼저 기록한다. 이번 설계에서는 외부
코드를 복사하지 않았고 새 패키지 의존성도 추가하지 않았다.

## 다음 구현 전 확인할 합격 기준

- Apple 팔레트 없이도 `drawingTool`과 `UIPencilInteraction`만으로 필기,
  두 번 탭과 지원 기기의 스퀴즈가 작동한다.
- 10개 굵기가 실제 페이지에서 구분되고 가장 얇은 값이 공부 필기에
  충분하다.
- 펜/형광펜의 색 슬롯과 굵기 상태가 페이지 이동 후에도 유지된다.
- 형광펜 각도 변경이 예상한 펜촉 방향을 만들며 필기 지연이 늘지 않는다.
- 세 지우개와 획 지우개 폭이 실제로 다르게 동작한다.
- 두 번 탭과 스퀴즈가 마지막 정밀 펜 프리셋과 지우개 사이를 전환한다.
- 자유형 라쏘가 기존 ink와 PaperKit 요소를 선택하고 손가락 이동/확대와
  충돌하지 않는다.
- 텍스트와 이미지가 선택·이동·저장·복원되며 PDF 좌표와 어긋나지 않는다.
- 위 기능을 추가한 뒤에도 `0.1.20`에서 통과한 1~13 항목이 전부 유지된다.

## 공개 근거

### Apple

- [PaperKit](https://developer.apple.com/documentation/paperkit)
- [Integrating PaperKit into your app](https://developer.apple.com/documentation/paperkit/getting-started-with-paperkit)
- [PaperMarkup](https://developer.apple.com/documentation/paperkit/papermarkup)
- [PaperMarkupViewController.drawingTool](https://developer.apple.com/documentation/paperkit/papermarkupviewcontroller/drawingtool)
- [PKInkingTool](https://developer.apple.com/documentation/pencilkit/pkinkingtool-swift.struct)
- [PKEraserTool](https://developer.apple.com/documentation/pencilkit/pkerasertool-swift.struct)
- [PKLassoTool](https://developer.apple.com/documentation/pencilkit/pklassotool-swift.struct)
- [UIPencilInteraction](https://developer.apple.com/documentation/uikit/uipencilinteraction)
- [Handling double taps from Apple Pencil](https://developer.apple.com/documentation/applepencil/handling-double-taps-from-apple-pencil)
- [Controlling stroke rendering for animation and editing](https://developer.apple.com/documentation/pencilkit/controlling-stroke-rendering-for-animation-and-editing)
- [AVAudioRecorder](https://developer.apple.com/documentation/avfaudio/avaudiorecorder)

### 제품 UX

- [Goodnotes pen, pattern, thickness and color presets](https://support.goodnotes.com/hc/en-us/articles/7353756785679-Write-and-customize-ink-with-the-Pen-tool)
- [Goodnotes eraser modes and filters](https://support.goodnotes.com/hc/en-us/articles/7353718249231-Erase-handwriting-and-page-content-with-the-Eraser-tool)
- [Goodnotes image insertion](https://support.goodnotes.com/hc/en-us/articles/7353727617295-Insert-images-into-Goodnotes)
- [Goodnotes improved toolbar and object menu](https://support.goodnotes.com/hc/en-us/articles/13682253498767-Improved-User-Interface)
- [Notability editor tools and per-tool presets](https://support.gingerlabs.com/hc/en-us/articles/4867633230234-Getting-Started-with-Notability)
- [Notability selection tool](https://support.gingerlabs.com/hc/en-us/articles/360018646412-Select-Tool)
- [Notability text and text boxes](https://support.gingerlabs.com/hc/en-us/articles/206059387-Text-and-Text-Boxes)
- [Notability audio and Note Replay](https://support.gingerlabs.com/hc/en-us/articles/206060617-Recording-and-Playing-Audio)

### 공개 앱

- [Cecilia's Notes](https://github.com/TheProductArchitect/cecilias-notes)
- [Sketchbook app](https://github.com/alfredang/sketchbookapp)
- [Pieces of Paper](https://github.com/0si43/PiecesOfPaper)
- [Jottre](https://github.com/antonlorani/jottre)
