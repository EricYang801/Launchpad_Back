import CoreGraphics

/// Geometry of one page of icons, in the Launchpad window's coordinate space.
nonisolated struct GridMetrics: Equatable, Sendable {
    var columns: Int
    var rows: Int
    /// The area covered by the cells of one page.
    var frame: CGRect

    var perPage: Int { columns * rows }
    var cellSize: CGSize { CGSize(width: frame.width / CGFloat(columns), height: frame.height / CGFloat(rows)) }
    var iconSize: CGFloat { min(max((min(cellSize.width * 0.56, cellSize.height * 0.62)).rounded(), 40), 128) }

    /// Launchpad's proportions: a search field on top, page dots at the bottom, generous side margins.
    static func main(in size: CGSize, columns: Int, rows: Int) -> GridMetrics {
        let side = size.width * 0.1
        let top = max(size.height * 0.12, 72)
        let bottom = max(size.height * 0.1, 56)
        return GridMetrics(
            columns: columns,
            rows: rows,
            frame: CGRect(x: side, y: top, width: max(size.width - side * 2, 1), height: max(size.height - top - bottom, 1))
        )
    }

    /// An open folder uses the same cell size as the main grid, centered in the window.
    static func folder(in size: CGSize, main: GridMetrics, appCount: Int) -> GridMetrics {
        let columns = min(main.columns, 5)
        let rows = min(main.rows, 3, max(1, (appCount + columns - 1) / columns))
        let cell = main.cellSize
        let gridSize = CGSize(width: cell.width * CGFloat(columns), height: cell.height * CGFloat(rows))
        return GridMetrics(
            columns: columns,
            rows: rows,
            frame: CGRect(
                x: (size.width - gridSize.width) / 2,
                y: (size.height - gridSize.height) / 2 + 24,
                width: gridSize.width,
                height: gridSize.height
            )
        )
    }

    func pageCount(for itemCount: Int) -> Int {
        max(1, (itemCount + perPage - 1) / perPage)
    }

    /// Center of a cell on the current page; `index` may be global, only its slot on the page matters.
    func center(of index: Int) -> CGPoint {
        let slot = index % perPage
        let cell = cellSize
        return CGPoint(
            x: frame.minX + cell.width * (CGFloat(slot % columns) + 0.5),
            y: frame.minY + cell.height * (CGFloat(slot / columns) + 0.5)
        )
    }

    /// The slot under `point`, or nil outside the grid.
    func slot(at point: CGPoint) -> Int? {
        guard frame.insetBy(dx: -cellSize.width / 2, dy: -cellSize.height / 4).contains(point) else { return nil }
        let column = min(max(Int((point.x - frame.minX) / cellSize.width), 0), columns - 1)
        let row = min(max(Int((point.y - frame.minY) / cellSize.height), 0), rows - 1)
        return row * columns + column
    }

    /// Whether `point` is over the icon (not the gap or label) of the slot, where dropping an app makes a folder.
    func isOverIcon(_ point: CGPoint, slot: Int) -> Bool {
        let center = iconCenter(of: slot)
        let reach = iconSize * 0.36
        return abs(point.x - center.x) < reach && abs(point.y - center.y) < reach
    }

    /// Icons sit slightly above the cell center to leave room for the label.
    func iconCenter(of index: Int) -> CGPoint {
        let center = center(of: index)
        return CGPoint(x: center.x, y: center.y - labelHeight / 2)
    }

    var labelHeight: CGFloat { 18 }
}
