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
    /// PaperKit uses a page coordinate space twice the PDF-point dimensions,
    /// so one logical point remains a fine 0.5 PDF-point pen. Starting at one
    /// also avoids multiple sub-minimum choices collapsing to the same native
    /// PencilKit width after `validWidthRange` clamping.
    static let penWidths: [Double] = [1, 1.5, 2.2, 3.2, 4.6, 6.5, 9, 12.5, 17, 24]
    static let highlighterWidths: [Double] = [1, 2, 3.5, 5.5, 8, 12, 17, 24, 34, 48]
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
    private(set) var highlighterOpacity: Double
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
        highlighterOpacity = 0.35
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

    mutating func setHighlighterOpacity(_ opacity: Double) {
        highlighterOpacity = opacity.clamped(to: 0.10...0.80)
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

    private enum CodingKeys: String, CodingKey {
        case selectedTool
        case previousTool
        case lastInkingTool
        case penWidthLevel
        case highlighterWidthLevel
        case eraserWidthLevel
        case selectedPenColorSlot
        case selectedHighlighterColorSlot
        case penColors
        case highlighterColors
        case highlighterOpacity
        case highlighterAzimuthIndex
        case eraserMode
        case isContextPanelExpanded
    }

    init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        selectedTool = try container.decodeIfPresent(
            StudyCoachPaletteTool.self,
            forKey: .selectedTool
        ) ?? selectedTool
        previousTool = try container.decodeIfPresent(
            StudyCoachPaletteTool.self,
            forKey: .previousTool
        ) ?? previousTool
        lastInkingTool = try container.decodeIfPresent(
            StudyCoachPaletteTool.self,
            forKey: .lastInkingTool
        ) ?? lastInkingTool
        penWidthLevel = Self.clampedLevel(
            try container.decodeIfPresent(Int.self, forKey: .penWidthLevel) ?? penWidthLevel,
            count: Self.penWidths.count
        )
        highlighterWidthLevel = Self.clampedLevel(
            try container.decodeIfPresent(Int.self, forKey: .highlighterWidthLevel)
                ?? highlighterWidthLevel,
            count: Self.highlighterWidths.count
        )
        eraserWidthLevel = Self.clampedLevel(
            try container.decodeIfPresent(Int.self, forKey: .eraserWidthLevel) ?? eraserWidthLevel,
            count: Self.eraserWidths.count
        )

        penColors = Self.normalizedColors(
            try container.decodeIfPresent([StudyCoachRGBAColor].self, forKey: .penColors)
                ?? penColors,
            fallback: [.black]
        )
        highlighterColors = Self.normalizedColors(
            try container.decodeIfPresent(
                [StudyCoachRGBAColor].self,
                forKey: .highlighterColors
            ) ?? highlighterColors,
            fallback: [.yellow]
        )
        selectedPenColorSlot = Self.clampedLevel(
            try container.decodeIfPresent(Int.self, forKey: .selectedPenColorSlot)
                ?? selectedPenColorSlot,
            count: penColors.count
        )
        selectedHighlighterColorSlot = Self.clampedLevel(
            try container.decodeIfPresent(Int.self, forKey: .selectedHighlighterColorSlot)
                ?? selectedHighlighterColorSlot,
            count: highlighterColors.count
        )
        highlighterOpacity = (
            try container.decodeIfPresent(Double.self, forKey: .highlighterOpacity) ?? 0.35
        ).clamped(to: 0.10...0.80)
        highlighterAzimuthIndex = Self.clampedLevel(
            try container.decodeIfPresent(Int.self, forKey: .highlighterAzimuthIndex)
                ?? highlighterAzimuthIndex,
            count: Self.highlighterAzimuths.count
        )
        eraserMode = try container.decodeIfPresent(
            StudyCoachPaletteEraserMode.self,
            forKey: .eraserMode
        ) ?? eraserMode
        isContextPanelExpanded = try container.decodeIfPresent(
            Bool.self,
            forKey: .isContextPanelExpanded
        ) ?? isContextPanelExpanded
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedTool, forKey: .selectedTool)
        try container.encode(previousTool, forKey: .previousTool)
        try container.encode(lastInkingTool, forKey: .lastInkingTool)
        try container.encode(penWidthLevel, forKey: .penWidthLevel)
        try container.encode(highlighterWidthLevel, forKey: .highlighterWidthLevel)
        try container.encode(eraserWidthLevel, forKey: .eraserWidthLevel)
        try container.encode(selectedPenColorSlot, forKey: .selectedPenColorSlot)
        try container.encode(selectedHighlighterColorSlot, forKey: .selectedHighlighterColorSlot)
        try container.encode(penColors, forKey: .penColors)
        try container.encode(highlighterColors, forKey: .highlighterColors)
        try container.encode(highlighterOpacity, forKey: .highlighterOpacity)
        try container.encode(highlighterAzimuthIndex, forKey: .highlighterAzimuthIndex)
        try container.encode(eraserMode, forKey: .eraserMode)
        try container.encode(isContextPanelExpanded, forKey: .isContextPanelExpanded)
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
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
