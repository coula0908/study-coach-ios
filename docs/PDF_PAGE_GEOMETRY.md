# PDF 페이지 기하 구조 초안

상태: **미승인 초안**  
작성일: 2026-09-04

이 문서는 일부 스캔 PDF의 잘림과 확대 범위 차이를 다음 설계 턴에서
논의하기 위한 작업 초안이다. 사용자의 승인을 받은 최종 설계가 아니며,
검토 전에는 렌더러 또는 저장 형식을 변경하지 않는다.

## 해결할 문제

현재 PaperKit PDF 경로는 대체로 잘 작동하지만 일부 스캔 PDF에서 다음
현상이 보고됐다.

- 페이지 일부가 잘려 보임
- 일반 PDF와 초기 맞춤 또는 확대·축소 범위가 다르게 느껴짐
- CropBox, MediaBox, 0이 아닌 페이지 원점, `/Rotate`가 한 좌표 정책으로
  정규화되지 않았을 가능성

현재 코드는 CropBox 크기로 PaperKit 논리 페이지를 만들고 일부 렌더링
변환을 수동으로 구성한다. 기본 전체 페이지 이미지, 고해상도 타일,
PaperKit bounds와 화면 맞춤이 같은 불변 기하 값에서 파생되지 않으면
특수 PDF에서 서로 다른 영역이나 비율을 사용할 수 있다.

## 불변 조건 초안

1. 한 페이지에는 하나의 정규화된 `PDFPageGeometry`만 존재한다.
2. 기본 이미지, 고해상도 타일, PaperKit bounds, 초기 fit, hit testing,
   미래 PDF 내보내기가 모두 그 값을 사용한다.
3. 화면 픽셀이나 현재 줌 배율은 저장 좌표가 아니다.
4. 페이지 회전과 0이 아닌 box 원점을 별도 예외 코드로 흩뜨리지 않는다.
5. PaperKit 논리 좌표와 PDF page 좌표의 왕복 변환이 가능해야 한다.
6. 이미 저장된 `PaperMarkup` 좌표를 조용히 재해석하거나 덮어쓰지 않는다.
7. 렌더링 타일 크기·LOD·캐시·스케줄링은 이번 기하 수정과 분리한다.

## 표시 영역 정책 초안

```swift
enum PDFDisplayAreaPreference: String, Codable, Sendable {
    case automatic
    case croppedArea
    case fullMedia
}
```

- `automatic`: 유효한 CropBox를 기본으로 사용하되 비정상/빈 box,
  MediaBox 밖의 값, 스캔에서 내용이 잘릴 가능성을 감지하면 안전한
  정책을 적용한다.
- `croppedArea`: 작성자가 지정한 CropBox만 표시한다.
- `fullMedia`: MediaBox 전체를 표시해 숨겨진 여백이나 스캔 가장자리를
  사용자가 직접 확인할 수 있게 한다.

모든 PDF를 무조건 MediaBox로 바꾸면 정상 문서의 의도된 재단과 여백이
달라지므로, 문서별 선택과 안전한 기본값을 함께 두는 방안을 검토한다.

## 기하 값 초안

```swift
struct PDFPageGeometry: Equatable, Sendable {
    let pageIndex: Int
    let mediaBox: CGRect
    let cropBox: CGRect
    let selectedDisplayBox: PDFDisplayBox
    let selectedBounds: CGRect
    let normalizedRotation: Int
    let rotatedPDFSize: CGSize
    let paperBounds: CGRect
    let pdfToPaper: CGAffineTransform
    let paperToPDF: CGAffineTransform
    let signature: GeometrySignature
}
```

`paperBounds`는 원점이 `(0, 0)`인 회전 적용 후 크기여야 한다. 현재의
PaperKit 논리 배율을 유지한다면 그 값도 기하 생성 시 한 번만 반영하고
기본 이미지와 타일이 각자 다시 곱하지 않게 한다.

## 변환 생성 원칙 초안

수동으로 `translate`와 Y축 반전을 조합하기보다 Core Graphics의
`CGPDFPage.getDrawingTransform`을 페이지 box, 대상 rect, 회전 정책과
함께 사용한다.

```text
PDF page coordinates
        │ CGPDFPage drawing transform
        ▼
normalized paper coordinates
        │ PaperKit viewport
        ▼
screen coordinates
```

- 기본 전체 페이지 렌더러와 타일 렌더러가 같은 PDF→Paper 변환을 쓴다.
- 타일은 별도 전체 페이지 변환을 재계산하지 않고 Paper 좌표의 타일
  rect를 같은 역변환으로 PDF 영역에 대응시킨다.
- `PDFPage.rotation`은 0/90/180/270으로 정규화한다.
- CropBox의 원점이 0이 아니어도 Paper 좌표의 `(0, 0)`으로 정확히
  이동되어야 한다.

## 화면 맞춤과 확대 범위 초안

초기 fit은 임의의 PDF 포인트 크기가 아니라 회전까지 적용된
`paperBounds`와 `PaperMarkupViewController.contentVisibleFrame`을 기준으로
계산한다. 같은 화면에서 A4 벡터 PDF와 A4 스캔 PDF가 같은 물리 페이지
비율이면 같은 정도로 맞아 보여야 한다.

검토할 항목:

- PaperKit `zoomRange`가 절대 배율인지 fit 대비 배율인지
- 방향 전환과 Stage Manager 크기 변경 시 fit 유지 정책
- 최대 확대를 페이지 크기와 무관하게 지각적으로 맞출 방법
- 페이지 전환 시 페이지별 줌을 복원할지 문서 공통 줌을 쓸지

## 기존 필기 보호 초안

기하 정책이 달라지면 이미 저장된 PaperMarkup의 좌표 의미도 달라질 수
있다. 각 저장 파일의 메타데이터에 geometry signature를 두는 방안을
검토한다.

```text
document identity
page index
selected PDF box
normalized rotation
logical page scale
paper bounds
geometry schema version
```

- signature가 같으면 그대로 복원한다.
- signature가 다르면 자동 덮어쓰지 않는다.
- 안전한 아핀 변환이 증명된 경우에만 복사본으로 마이그레이션한다.
- 그렇지 않으면 기존 방식으로 열 수 있는 복구 경로를 유지한다.

## 시험 PDF 초안

개인 PDF를 저장소에 넣지 않고 테스트에서 생성 가능한 작은 합성 PDF를
사용한다.

| 시험 페이지 | 확인할 내용 |
|---|---|
| 표준 portrait, CropBox=MediaBox | 기존 정상 문서 회귀 없음 |
| 작은 CropBox, 큰 MediaBox | 재단/전체 표시 선택 |
| 0이 아닌 box 원점 | 네 모서리 매핑 |
| 90/180/270도 회전 | 방향, 비율, 좌표 왕복 |
| landscape | fit과 최대 확대 |
| 매우 긴 스캔 페이지 | 비율 유지와 잘림 없음 |
| 한 문서 안의 서로 다른 페이지 크기 | 페이지별 기하 분리 |

### 자동 시험 후보

- 네 모서리와 중앙점의 PDF→Paper→PDF 왕복 오차
- 회전 후 예상 width/height
- 선택 box 밖이 렌더링되지 않음
- 기본 이미지와 각 타일의 경계 좌표가 일치함
- 잘못된 CropBox에 대한 automatic fallback

### iPadOS 26 실기 시험 후보

- 사용자가 알려준 실패 스캔 PDF가 잘리지 않음
- 기존 정상 PDF의 방향·비율·필기 위치가 변하지 않음
- 확대·축소 범위가 페이지 종류에 따라 비정상적으로 달라지지 않음
- 확대 후 필기, 페이지 이동, 재실행 뒤에도 글씨가 같은 인쇄 위치에 있음
- Cropped/Full media 변경 시 원본과 필기 파일이 손상되지 않음

## 공개 근거

- [Apple: PDFPage bounds(for:)](https://developer.apple.com/documentation/pdfkit/pdfpage/bounds%28for%3A%29)
- [Apple: CGPDFPage](https://developer.apple.com/documentation/coregraphics/cgpdfpage)
- [Apple: Quartz 2D PDF drawing transforms](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_pdf/dq_pdf.html)
- [Apple: PaperMarkupViewController contentVisibleFrame](https://developer.apple.com/documentation/paperkit/papermarkupviewcontroller/contentvisibleframe)

