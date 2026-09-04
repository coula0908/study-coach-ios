import Foundation

enum StudyCoachPaletteTool: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case pen
    case highlighter
    case eraser
    case lasso
    case text
    case image

    var id: Self { self }
    var isInkingTool: Bool { self == .pen || self == .highlighter }
}

enum StudyCoachPaletteEraserMode: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case precision
    case partial
    case stroke

    var id: Self { self }
}

struct StudyCoachRGBAColor: Codable, Equatable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red.clamped(to: 0...1)
        self.green = green.clamped(to: 0...1)
        self.blue = blue.clamped(to: 0...1)
        self.alpha = alpha.clamped(to: 0...1)
    }

    static let black = StudyCoachRGBAColor(red: 0.08, green: 0.08, blue: 0.09)
    static let blue = StudyCoachRGBAColor(red: 0.08, green: 0.35, blue: 0.90)
    static let red = StudyCoachRGBAColor(red: 0.91, green: 0.18, blue: 0.20)
    static let green = StudyCoachRGBAColor(red: 0.08, green: 0.62, blue: 0.35)
    static let purple = StudyCoachRGBAColor(red: 0.51, green: 0.25, blue: 0.82)
    static let brown = StudyCoachRGBAColor(red: 0.48, green: 0.29, blue: 0.17)

    static let yellow = StudyCoachRGBAColor(red: 1.00, green: 0.84, blue: 0.12)
    static let orange = StudyCoachRGBAColor(red: 1.00, green: 0.52, blue: 0.10)
    static let pink = StudyCoachRGBAColor(red: 1.00, green: 0.36, blue: 0.58)
    static let mint = StudyCoachRGBAColor(red: 0.20, green: 0.79, blue: 0.61)
    static let cyan = StudyCoachRGBAColor(red: 0.18, green: 0.69, blue: 0.93)
    static let lavender = StudyCoachRGBAColor(red: 0.67, green: 0.48, blue: 0.93)
}

struct StudyCoachToolPaletteState: Codable, Equatable, Sendable {
    static let penWidths: [Double] = [0.25, 0.35, 0.5, 0.7, 0.9, 1.2, 1.6, 2.2, 3.0, 4.2]
    static let highlighterWidths: [Double] = [1, 1.5, 2, 3, 4, 5.5, 7.5, 10, 14, 20]
    static let eraserWidths: [Double] = [4, 6, 8, 12, 16, 24, 32, 48, 64, 96]
    static let highlighterAzimuths: [Double] = [0, .pi / 4, .pi / 2]

    private(set) var selectedTool: StudyCoachPaletteTool
    private(set) var previousTool: StudyCoachPaletteTool
    private(set) var lastInkingTool: StudyCoachPaletteTool
    private(set) var penWidthLevel: Int
    private(set) var highlighterWidthLevel: Int
    private(set) var eraserWidthLevel: Int
    private(set) var selectedPenColorSlot: Int
    private(set) var selectedHighlighterColorSlot: Int
    private(set) var penColors: [StudyCoachRGBAColor]
    private(set) var highlighterColors: [StudyCoachRGBAColor]
    private(set) var highlighterAzimuthIndex: Int
    private(set) var eraserMode: StudyCoachPaletteEraserMode
    private(set) var isContextPanelExpanded: Bool

    init(
        selectedTool: StudyCoachPaletteTool = .pen,
        penWidthLevel: Int = 2,
        highlighterWidthLevel: Int = 2,
        eraserWidthLevel: Int = 4,
        penColors: [StudyCoachRGBAColor] = [.black, .blue, .red, .green, .purple, .brown],
        highlighterColors: [StudyCoachRGBAColor] = [.yellow, .orange, .pink, .mint, .cyan, .lavender]
    ) {
        let initialInkingTool = selectedTool.isInkingTool ? selectedTool : .pen
        self.selectedTool = selectedTool
        previousTool = initialInkingTool
        lastInkingTool = initialInkingTool
        self.penWidthLevel = Self.clampedLevel(penWidthLevel, count: Self.penWidths.count)
        self.highlighterWidthLevel = Self.clampedLevel(
            highlighterWidthLevel,
            count: Self.highlighterWidths.count
        )
        self.eraserWidthLevel = Self.clampedLevel(eraserWidthLevel, count: Self.eraserWidths.count)
        self.penColors = Self.normalizedColors(penColors, fallback: [.black])
        self.highlighterColors = Self.normalizedColors(highlighterColors, fallback: [.yellow])
        selectedPenColorSlot = 0
        selectedHighlighterColorSlot = 0
        highlighterAzimuthIndex = 0
        eraserMode = .precision
        isContextPanelExpanded = true
    }

    var penWidth: Double { Self.penWidths[penWidthLevel] }
    var highlighterWidth: Double { Self.highlighterWidths[highlighterWidthLevel] }
    var eraserWidth: Double { Self.eraserWidths[eraserWidthLevel] }
    var highlighterAzimuth: Double { Self.highlighterAzimuths[highlighterAzimuthIndex] }
    var penColor: StudyCoachRGBAColor { penColors[selectedPenColorSlot] }
    var highlighterColor: StudyCoachRGBAColor { highlighterColors[selectedHighlighterColorSlot] }

    mutating func select(_ tool: StudyCoachPaletteTool) {
        guard selectedTool != tool else {
            isContextPanelExpanded = true
            return
        }
        previousTool = selectedTool
        selectedTool = tool
        if tool.isInkingTool { lastInkingTool = tool }
        isContextPanelExpanded = true
    }

    mutating func toggleEraser() {
        if selectedTool == .eraser {
            select(lastInkingTool)
        } else {
            select(.eraser)
        }
    }

    mutating func switchToPreviousTool() {
        let target = previousTool
        previousTool = selectedTool
        selectedTool = target
        if target.isInkingTool { lastInkingTool = target }
        isContextPanelExpanded = true
    }

    mutating func setPenWidthLevel(_ level: Int) {
        penWidthLevel = Self.clampedLevel(level, count: Self.penWidths.count)
    }

    mutating func setHighlighterWidthLevel(_ level: Int) {
        highlighterWidthLevel = Self.clampedLevel(level, count: Self.highlighterWidths.count)
    }

    mutating func setEraserWidthLevel(_ level: Int) {
        eraserWidthLevel = Self.clampedLevel(level, count: Self.eraserWidths.count)
    }

    mutating func setHighlighterAzimuthIndex(_ index: Int) {
        highlighterAzimuthIndex = Self.clampedLevel(index, count: Self.highlighterAzimuths.count)
    }

    mutating func setEraserMode(_ mode: StudyCoachPaletteEraserMode) {
        eraserMode = mode
    }

    mutating func selectPenColor(slot: Int) {
        selectedPenColorSlot = Self.clampedLevel(slot, count: penColors.count)
    }

    mutating func selectHighlighterColor(slot: Int) {
        selectedHighlighterColorSlot = Self.clampedLevel(slot, count: highlighterColors.count)
    }

    mutating func replaceSelectedPenColor(with color: StudyCoachRGBAColor) {
        penColors[selectedPenColorSlot] = color
    }

    mutating func replaceSelectedHighlighterColor(with color: StudyCoachRGBAColor) {
        highlighterColors[selectedHighlighterColorSlot] = color
    }

    mutating func setContextPanelExpanded(_ isExpanded: Bool) {
        isContextPanelExpanded = isExpanded
    }

    private static func clampedLevel(_ level: Int, count: Int) -> Int {
        min(max(level, 0), max(count - 1, 0))
    }

    private static func normalizedColors(
        _ colors: [StudyCoachRGBAColor],
        fallback: [StudyCoachRGBAColor]
    ) -> [StudyCoachRGBAColor] {
        colors.isEmpty ? fallback : colors
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
