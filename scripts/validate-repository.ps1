$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$requiredPaths = @(
    'Package.swift'
    'VERSION.md'
    'Sources\StudyCoachCore\App\StudyCoachRootView.swift'
    'Sources\StudyCoachCore\App\StudyCoachSessionModel.swift'
    'Sources\StudyCoachCore\App\StudyCoachWorkspaceView.swift'
    'Sources\StudyCoachCore\Diagnostics\StudyCoachPaperKitDiagnosticView.swift'
    'Sources\StudyCoachCore\Diagnostics\StudyCoachPaperKitPDFDiagnosticView.swift'
    'Sources\StudyCoachCore\PDF\PDFKitContainerView.swift'
    'Sources\StudyCoachCore\PDF\PDFWorkspaceView.swift'
    'Sources\StudyCoachCore\Annotations\PencilPageCanvasView.swift'
    'Sources\StudyCoachCore\Annotations\PencilPageInkPresentation.swift'
    'Sources\StudyCoachCore\Annotations\PencilDrawingRenderView.swift'
    'Sources\StudyCoachCore\Persistence\StudyCoachDocumentStore.swift'
    'Tests\StudyCoachCoreTests\StudyCoachCoreSmokeTests.swift'
    'THIRD_PARTY_NOTICES.md'
    'docs\PAPERKIT_DIAGNOSTIC.md'
    'docs\PAPERKIT_PDF_DIAGNOSTIC.md'
)

foreach ($relativePath in $requiredPaths) {
    $absolutePath = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath)) {
        throw "Missing required path: $relativePath"
    }
}

$manifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'Package.swift') -Raw
$versionDocument = Get-Content -LiteralPath (Join-Path $repositoryRoot 'VERSION.md') -Raw
$rootView = Get-Content -LiteralPath (
    Join-Path $repositoryRoot 'Sources\StudyCoachCore\App\StudyCoachRootView.swift'
) -Raw
$pageCanvas = Get-Content -LiteralPath (
    Join-Path $repositoryRoot 'Sources\StudyCoachCore\Annotations\PencilPageCanvasView.swift'
) -Raw
$pdfContainer = Get-Content -LiteralPath (
    Join-Path $repositoryRoot 'Sources\StudyCoachCore\PDF\PDFKitContainerView.swift'
) -Raw
$paperKitDiagnostic = Get-Content -LiteralPath (
    Join-Path $repositoryRoot 'Sources\StudyCoachCore\Diagnostics\StudyCoachPaperKitDiagnosticView.swift'
) -Raw
$inkPresentation = Get-Content -LiteralPath (
    Join-Path $repositoryRoot 'Sources\StudyCoachCore\Annotations\PencilPageInkPresentation.swift'
) -Raw
$drawingRenderer = Get-Content -LiteralPath (
    Join-Path $repositoryRoot 'Sources\StudyCoachCore\Annotations\PencilDrawingRenderView.swift'
) -Raw
$paperKitPDFDiagnostic = Get-Content -LiteralPath (
    Join-Path $repositoryRoot 'Sources\StudyCoachCore\Diagnostics\StudyCoachPaperKitPDFDiagnosticView.swift'
) -Raw

foreach ($requiredManifestText in @(
    '// swift-tools-version: 5.9'
    'name: "StudyCoachCore"'
    '.library('
    '.iOS(.v17)'
)) {
    if (-not $manifest.Contains($requiredManifestText)) {
        throw "Package.swift is missing: $requiredManifestText"
    }
}

foreach ($requiredRootViewText in @(
    'public struct StudyCoachRootView'
    'public init()'
)) {
    if (-not $rootView.Contains($requiredRootViewText)) {
        throw "StudyCoachRootView is missing: $requiredRootViewText"
    }
}

foreach ($requiredDiagnosticText in @(
    'public struct StudyCoachPaperKitDiagnosticView'
    'public init()'
    '#if canImport(PaperKit)'
    'if #available(iOS 26.0, *)'
    'PaperMarkupViewController('
    'MarkupEditViewController('
    'dataRepresentation()'
    'PaperMarkup(dataRepresentation:'
)) {
    if (-not $paperKitDiagnostic.Contains($requiredDiagnosticText)) {
        throw "PaperKit diagnostic is missing: $requiredDiagnosticText"
    }
}

if ($rootView.Contains('StudyCoachPaperKitDiagnosticView')) {
    throw 'StudyCoachRootView must not route production users into the PaperKit diagnostic.'
}

if (-not $versionDocument.Contains('Current package version: `0.1.17`')) {
    throw 'VERSION.md must identify the source tree as package version 0.1.17.'
}

if ($rootView.Contains('StudyCoachPaperKitPDFDiagnosticView')) {
    throw 'StudyCoachRootView must not route production users into the PaperKit PDF diagnostic.'
}

foreach ($requiredPaperKitPDFText in @(
    'public struct StudyCoachPaperKitPDFDiagnosticView'
    'PaperMarkupViewController('
    'PaperKitPDFPageBackgroundView'
    'PaperKitPDFPageRasterizer'
    'baseImageView'
    'detailImageView'
    'contentVisibleFrame'
    'viewportMonitoringTask'
    'viewportSampleNanoseconds: UInt64 = 33_000_000'
    'descendantPinchGestureRecognizers'
    'observedPinchGestureChanged'
    'activePinchRecognizerIDs'
    'discardDetailImage()'
    'detailRenderIsInFlight'
    'pendingDetailRequest'
    'logicalPageScale: CGFloat = 2'
    'basePixelsPerPDFPoint: CGFloat = 4'
    'PaperMarkup(dataRepresentation:'
    'dataRepresentation()'
    'pageIndex: Int'
)) {
    if (-not $paperKitPDFDiagnostic.Contains($requiredPaperKitPDFText)) {
        throw "PaperKit PDF diagnostic is missing: $requiredPaperKitPDFText"
    }
}

if ($paperKitPDFDiagnostic.Contains('CATiledLayer')) {
    throw 'The adaptive PaperKit PDF diagnostic must not reveal asynchronous rectangular PDF tiles.'
}

foreach ($removedViewportDelayText in @(
    'viewportSettleDelay'
    'pendingViewportTask'
    'Timer(timeInterval:'
    'PaperMarkupViewController.Delegate'
)) {
    if ($paperKitPDFDiagnostic.Contains($removedViewportDelayText)) {
        throw "The adaptive PaperKit PDF diagnostic still contains a fixed viewport delay mechanism: $removedViewportDelayText"
    }
}

if ($paperKitDiagnostic.Contains('editor.delegate = paperController')) {
    throw 'Swift Playgrounds does not always expose PaperMarkupViewController as MarkupEditViewController.Delegate; use the guarded compatibility cast.'
}

foreach ($requiredPaperKitCompatibilityText in @(
    'as? any MarkupEditViewController.Delegate'
    'editor.delegate = editDelegate'
)) {
    if (-not $paperKitDiagnostic.Contains($requiredPaperKitCompatibilityText)) {
        throw "PaperKit Swift Playgrounds compatibility guard is missing: $requiredPaperKitCompatibilityText"
    }
}

if ($pageCanvas.Contains('override func hitTest')) {
    throw 'PencilPageCanvasView must not route input by overriding hitTest; it can discard Pencil touches on a physical iPad.'
}

if (-not $pageCanvas.Contains('isUserInteractionEnabled = true')) {
    throw 'PencilPageCanvasView must accept Pencil interaction immediately.'
}

if ($pageCanvas.Contains('delegate = self')) {
    throw 'PencilPageCanvasView must not be its own PKCanvasViewDelegate; this recursively crashes PencilKit when drawing begins.'
}

foreach ($requiredCanvasText in @(
    'drawingPolicy = .pencilOnly'
    'drawingGestureRecognizer.isEnabled = true'
    'PencilPageCanvasDelegate'
    'PKCanvasViewDelegate'
    'canvasViewDrawingDidChange'
)) {
    if (-not $pageCanvas.Contains($requiredCanvasText)) {
        throw "PencilPageCanvasView is missing native PencilKit routing: $requiredCanvasText"
    }
}

foreach ($forbiddenCanvasText in @(
    'drawingPolicy = .anyInput'
    'drawingGestureRecognizer.allowedTouchTypes'
    'isScrollEnabled = false'
    'minimumZoomScale = 1'
    'maximumZoomScale = 1'
    'zoomScale = 1'
)) {
    if ($pageCanvas.Contains($forbiddenCanvasText)) {
        throw "PencilPageCanvasView contains unsupported input or fixed-scale configuration: $forbiddenCanvasText"
    }
}

foreach ($requiredRendererText in @(
    'PencilPageInkPresentation'
    'PencilDrawingRenderView'
    'canvasView.onToolUseBegan'
    'canvasView.onToolUseEnded'
    'canvasView.addSubview(drawingRenderView)'
    'canvasView.bringSubviewToFront(drawingRenderView)'
)) {
    if (-not $inkPresentation.Contains($requiredRendererText)) {
        throw "PencilPageInkPresentation is missing high-resolution display wiring: $requiredRendererText"
    }
}

foreach ($forbiddenPresentationText in @(
    'canvasView.superview'
    'host.addSubview(drawingRenderView)'
    'canvasView.layer.opacity ='
)) {
    if ($inkPresentation.Contains($forbiddenPresentationText)) {
        throw "PencilPageInkPresentation must not modify PDFKit's page hierarchy or canvas opacity: $forbiddenPresentationText"
    }
}

foreach ($requiredRendererText in @(
    'CATiledLayer'
    'levelsOfDetailBias = 4'
    'drawing.image(from: sourceRect, scale: boundedScale)'
)) {
    if (-not $drawingRenderer.Contains($requiredRendererText)) {
        throw "PencilDrawingRenderView is missing zoom-aware rendering: $requiredRendererText"
    }
}

if ($drawingRenderer.Contains('contentScaleFactor =')) {
    throw 'Do not reintroduce the contentScaleFactor-only workaround; it does not rerender PencilKit ink.'
}

if (Test-Path -LiteralPath (
    Join-Path $repositoryRoot 'Sources\StudyCoachCore\Annotations\PencilStrokeGestureRecognizer.swift'
)) {
    throw 'The manual Pencil stroke synthesizer must not be part of the native PencilKit editor.'
}

foreach ($requiredInteractionText in @(
    'enablePageOverlayInteraction(canvas, in: pdfView)'
    'pdfView.documentView?.isUserInteractionEnabled = true'
    'pdfView.documentView?.subviews.forEach'
    'view.isUserInteractionEnabled = true'
    'pdfView.isInMarkupMode = true'
    'scrollView.panGestureRecognizer.require(toFail: canvas.drawingGestureRecognizer)'
    'UIPencilInteractionDelegate'
    'PencilPageCanvasView(frame: .zero)'
    'PencilPageInkPresentation(canvasView: canvas)'
    'presentation?.installInsideCanvas()'
    'presentation?.showRenderedDrawing()'
)) {
    if (-not $pdfContainer.Contains($requiredInteractionText)) {
        throw "PDFKitContainerView is missing overlay interaction setup: $requiredInteractionText"
    }
}

Push-Location $repositoryRoot
try {
    & git diff --check
    if ($LASTEXITCODE -ne 0) {
        throw 'git diff --check failed.'
    }

    $secretPatterns = @(
        'sk-[A-Za-z0-9_-]{16,}'
        'ghp_[A-Za-z0-9]{20,}'
        '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    )
    $searchableFiles = Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File |
        Where-Object {
            $_.FullName -ne $PSCommandPath -and
            $_.FullName -notmatch '[\\/]\.git[\\/]' -and
            $_.Extension -in @('.swift', '.md', '.json', '.yml', '.yaml', '.ps1')
        }

    foreach ($pattern in $secretPatterns) {
        $hits = $searchableFiles | Select-String -Pattern $pattern
        if ($hits) {
            throw "Potential secret material found for pattern: $pattern"
        }
    }
} finally {
    Pop-Location
}

Write-Output 'StudyCoachCore repository validation passed.'
Write-Output 'This Windows check does not compile Apple frameworks; use the GitHub macOS workflow or Swift Playgrounds for that evidence.'
