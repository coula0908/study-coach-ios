# 자체 툴바 상태 구조 초안

상태: **미승인 초안**  
작성일: 2026-09-04

이 문서는 다음 설계 턴에서 검토하기 위한 작업 초안이다. 사용자의
승인을 받은 최종 설계가 아니며, 검토 전에는 구현 근거나 버전 계획으로
사용하지 않는다.

## 목표 경계

현재 사용자가 만족한 PaperKit 필기감은 그대로 유지하고 화면에 보이는
도구 UI만 StudyCoach 고유 툴바로 교체한다.

- `PaperMarkupViewController`가 Pencil 입력, 획 보정, 선택, 지우기,
  렌더링, 확대와 이동을 계속 담당한다.
- 앱은 터치 표본을 직접 수집하거나 `PKStroke`를 직접 만들지 않는다.
- `PKToolPicker`는 화면에서 숨겨도 활성 상태로 유지해 Apple Pencil
  두 번 탭, Pencil Pro 스퀴즈와 시스템 도구 상태의 연결을 보존한다.
- 문제가 생기면 Apple 기본 도구 UI로 즉시 돌아갈 수 있는 시험용 전환
  수단을 초기 버전에 둔다.

## 제안 구성

```text
CustomToolPaletteView (SwiftUI)
          │ 사용자 선택
          ▼
ToolPaletteStore (앱 상태와 프리셋)
          │ 명령/동기화
          ▼
PaperKitToolBridge (@MainActor)
     ├── PKToolPicker (활성, 필요 시 숨김)
     └── PaperMarkupViewController
          │ 시스템 변경 알림
          └──────────────► ToolPaletteStore
```

### 책임 분리

| 구성 요소 | 책임 | 책임지지 않는 것 |
|---|---|---|
| `CustomToolPaletteView` | 버튼, 색상, 굵기, 선택 표시, 배치 | PaperKit 객체 직접 조작 |
| `ToolPaletteStore` | 선택 도구, 프리셋, 마지막 필기 도구, 표시 환경설정 | 획 데이터와 PDF 좌표 |
| `PaperKitToolBridge` | 앱 상태를 시스템 도구로 변환하고 시스템 변경을 앱에 반영 | 툴바 레이아웃과 영구 문서 저장 |
| `PKToolPicker` | 시스템 도구 항목과 Pencil 제스처 연결 | StudyCoach 프리셋 파일 |
| `PaperMarkupViewController` | 실제 입력·필기·선택·undo | 앱 문서함과 툴바 UI |

## 상태 모델 초안

PaperKit/UIKit 객체 자체는 저장하지 않고 식별 가능한 값만 저장한다.

```swift
enum StudyToolKind: String, Codable, Sendable {
    case pen
    case highlighter
    case eraser
    case selection
    case ruler
}

enum StudyEraserMode: String, Codable, Sendable {
    case stroke
    case partial
}

struct InkStyle: Codable, Equatable, Sendable {
    var colorRGBA: RGBAColor
    var widthInPagePoints: Double
    var opacity: Double
}

struct ToolPreset: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: StudyToolKind
    var inkStyle: InkStyle?
    var eraserMode: StudyEraserMode?
    var title: String
}

struct ToolPalettePreferences: Codable, Equatable, Sendable {
    var orderedPresetIDs: [UUID]
    var hiddenPresetIDs: Set<UUID>
    var selectedPresetID: UUID
    var lastInkingPresetID: UUID
    var returnsToInkAfterErase: Bool
    var placement: PalettePlacement
}
```

검토할 쟁점:

- 실제 PaperKit/PencilKit가 허용하는 최소 굵기와 앱 UI 최소값을 분리할지
- 색상은 sRGB RGBA로 저장할지, 동적 시스템 색상을 허용할지
- 펜 종류를 공개 API 식별자로 안정적으로 직렬화할 수 있는지
- 시스템에 새 도구가 추가됐을 때 알 수 없는 식별자를 어떻게 보존할지

## 양방향 동기화 규칙 초안

### 앱 UI에서 시스템으로

1. 사용자가 프리셋을 선택한다.
2. 저장소가 선택 상태를 먼저 갱신한다.
3. 브리지가 해당 프리셋과 일치하는 `PKToolPickerItem` 또는
   `drawingTool`을 선택한다.
4. PaperKit가 실제 선택을 수용했는지 시스템 상태를 다시 읽는다.
5. 수용되지 않은 값이면 가장 가까운 안전한 도구로 되돌리고 UI에도
   실제 상태를 표시한다.

### 시스템에서 앱 UI로

1. Pencil 두 번 탭, 스퀴즈, 시스템 미니 팔레트 등으로 도구가 바뀐다.
2. 브리지가 시스템 선택 식별자를 받는다.
3. 일치하는 프리셋이 있으면 `selectedPresetID`만 갱신한다.
4. 일치하는 프리셋이 없으면 임시 시스템 프리셋을 표시하거나 안전한
   기본 도구로 표시한다.
5. 동일 상태를 시스템에 다시 쓰지 않아 피드백 루프를 막는다.

동기화에는 `isApplyingAppSelection` 같은 단순 불리언보다 변경 출처와
증가하는 revision을 쓰는 편이 안전한지 다음 턴에서 검토한다.

## UI 초안 범위

첫 시험 화면은 디자인 완성본이 아니라 연결 검증용으로 한정한다.

- 펜, 형광펜, 지우개, undo, redo
- 현재 선택 상태
- 선택 도구의 색상과 굵기
- Apple 도구 / StudyCoach 도구 A/B 전환
- PDF 화면을 가리거나 페이지 좌표를 바꾸지 않는 배치

다음 단계에서만 추가할 항목:

- 여러 프리셋, 순서 변경, 숨김
- 획/부분 지우개와 자동 복귀
- 올가미, 자, 도형, 레이저, 테이프
- 떠 있는 배치와 도킹
- Pencil Pro 스퀴즈용 빠른 도구 UI

## 시험 초안

### 순수 상태 시험

- 프리셋 직렬화와 복원
- 알 수 없는 향후 도구 식별자의 안전한 처리
- UI 선택 → 브리지 명령 변환
- 시스템 선택 → UI 상태 변환
- 양방향 갱신이 무한 반복되지 않음
- 지우개 ↔ 마지막 필기 도구 상태 전환

### iPadOS 26 실기 시험

- 같은 글씨를 Apple 기본 UI와 자체 UI에서 번갈아 쓰고 지연, 필압,
  보정, 선명도 차이가 없는지 비교
- 펜, 형광펜, 두 지우개, undo/redo
- Pencil 두 번 탭과 지원 기기의 스퀴즈 후 UI 선택 표시 동기화
- 손가락 이동·두 손가락 확대·가장자리 필기가 툴바에 막히지 않음
- 자체 UI가 실패해도 Apple UI로 돌아가 필기할 수 있음

## 공개 근거

- [Apple: Meet PaperKit](https://developer.apple.com/videos/play/wwdc2025/285/)
- [Apple: PKToolPicker](https://developer.apple.com/documentation/pencilkit/pktoolpicker)
- [Apple: Configuring the PencilKit tool picker](https://developer.apple.com/documentation/pencilkit/configuring-the-pencilkit-tool-picker)
- [Goodnotes: Customize the toolbar](https://support.goodnotes.com/hc/en-us/articles/8900755183631-Customize-the-toolbar)
- [Notability: Customize your Toolbox](https://support.gingerlabs.com/hc/en-us/articles/6272405402650-Customize-your-Toolbox)

