struct StudyCoachToolPaletteState: Equatable, Sendable {
    private(set) var selectedTool: AnnotationTool
    private(set) var showsApplePalette: Bool

    init(
        selectedTool: AnnotationTool = .pen,
        showsApplePalette: Bool = false
    ) {
        self.selectedTool = selectedTool
        self.showsApplePalette = showsApplePalette
    }

    mutating func select(_ tool: AnnotationTool) {
        selectedTool = tool
    }

    mutating func reflectSystemSelection(_ tool: AnnotationTool) {
        selectedTool = tool
    }

    mutating func setApplePaletteVisible(_ isVisible: Bool) {
        showsApplePalette = isVisible
    }
}
