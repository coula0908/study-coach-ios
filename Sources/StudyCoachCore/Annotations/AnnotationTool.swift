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

struct AnnotationToolConfiguration {
    let tool: AnnotationTool
    let color: UIColor
    let width: CGFloat

    func apply(to canvas: PKCanvasView) {
        switch tool {
        case .pen:
            canvas.tool = PKInkingTool(.pen, color: color, width: width)
        case .highlighter:
            canvas.tool = PKInkingTool(
                .marker,
                color: color.withAlphaComponent(0.45),
                width: max(width * 2.5, 8)
            )
        case .eraser:
            canvas.tool = PKEraserTool(.vector)
        }
    }
}
