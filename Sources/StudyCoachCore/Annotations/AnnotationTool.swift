import PencilKit
import SwiftUI
import UIKit

enum AnnotationTool: String, CaseIterable, Identifiable {
    case pen
    case highlighter
    case eraser

    var id: Self { self }

    var title: String {
        switch self {
        case .pen: "펜"
        case .highlighter: "형광펜"
        case .eraser: "지우개"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        }
    }
}

enum AnnotationEraserMode: String, CaseIterable, Identifiable {
    case stroke
    case partial

    var id: Self { self }

    var title: String {
        switch self {
        case .stroke: "획 지우개"
        case .partial: "부분 지우개"
        }
    }
}

struct AnnotationToolConfiguration {
    let tool: AnnotationTool
    let color: UIColor
    let width: CGFloat
    let eraserMode: AnnotationEraserMode

    func apply(to canvas: PencilPageCanvasView) {
        switch tool {
        case .pen:
            canvas.tool = PKInkingTool(.pen, color: color, width: width)
        case .highlighter:
            canvas.tool = PKInkingTool(
                .marker,
                color: color.withAlphaComponent(0.45),
                width: width
            )
        case .eraser:
            canvas.tool = PKEraserTool(
                eraserMode == .stroke ? .vector : .bitmap
            )
        }
    }
}
