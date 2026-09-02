$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$requiredPaths = @(
    'Package.swift'
    'Sources\StudyCoachCore\App\StudyCoachRootView.swift'
    'Sources\StudyCoachCore\App\StudyCoachSessionModel.swift'
    'Sources\StudyCoachCore\App\StudyCoachWorkspaceView.swift'
    'Sources\StudyCoachCore\Diagnostics\StudyCoachPaperKitDiagnosticView.swift'
    'Sources\StudyCoachCore\Diagnostics\StudyCoachPaperKitPDFDiagnosticView.swift'
    'Sources\StudyCoachCore\PDF\PDFKitContainerView.swift'
    'Sources\StudyCoachCore\PDF\PDFWorkspaceView.swift'
    'Sources\StudyCoachCore\Annotations\PencilPageCanvasView.swift'
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

if ($rootView.Contains('StudyCoachPaperKitPDFDiagnosticView')) {
    throw 'StudyCoachRootView must not route production users into the PaperKit PDF diagnostic.'
}

foreach ($requiredPaperKitPDFText in @(
    'public struct StudyCoachPaperKitPDFDiagnosticView'
    'PaperMarkupViewController('
    'PaperKitPDFPageBackgroundView'
    'CATiledLayer.self'
    'PaperMarkup(dataRepresentation:'
    'dataRepresentation()'
    'pageIndex: Int'
)) {
    if (-not $paperKitPDFDiagnostic.Contains($requiredPaperKitPDFText)) {
        throw "PaperKit PDF diagnostic is missing: $requiredPaperKitPDFText"
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
    'drawingPolicy = .anyInput'
    'drawingGestureRecognizer.isEnabled = true'
    'drawingGestureRecognizer.allowedTouchTypes'
    'PencilPageCanvasDelegate'
    'PKCanvasViewDelegate'
    'canvasViewDrawingDidChange'
)) {
    if (-not $pageCanvas.Contains($requiredCanvasText)) {
        throw "PencilPageCanvasView is missing native PencilKit routing: $requiredCanvasText"
    }
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
