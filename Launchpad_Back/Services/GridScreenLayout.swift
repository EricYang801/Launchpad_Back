//
//  GridScreenLayout.swift
//  Launchpad_Back
//
//  Created by Codex on 2026/4/6.
//

import CoreGraphics

struct GridScreenLayout {
    let frame: CGRect
    let columns: Int
    let itemWidth: CGFloat
    let itemHeight: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    private var cellWidth: CGFloat {
        itemWidth + horizontalSpacing
    }

    private var cellHeight: CGFloat {
        itemHeight + verticalSpacing
    }

    func rawIndex(at screenLocation: CGPoint) -> Int? {
        let column = Int((screenLocation.x - frame.minX + cellWidth / 2) / cellWidth)
        let row = Int((screenLocation.y - frame.minY + cellHeight / 2) / cellHeight)

        guard column >= 0, column < columns, row >= 0 else {
            return nil
        }

        return row * columns + column
    }

    func clampedIndex(at screenLocation: CGPoint, itemCount: Int, allowsTrailingSlot: Bool) -> Int? {
        guard let rawIndex = rawIndex(at: screenLocation) else {
            return nil
        }

        let upperBound = allowsTrailingSlot ? itemCount : max(itemCount - 1, 0)
        return min(max(0, rawIndex), upperBound)
    }

    func itemCenter(at index: Int) -> CGPoint {
        let column = index % columns
        let row = index / columns

        return CGPoint(
            x: frame.minX + CGFloat(column) * cellWidth + cellWidth / 2,
            y: frame.minY + CGFloat(row) * cellHeight + itemHeight / 2
        )
    }

    func leadingIndicatorPosition(at index: Int) -> CGPoint {
        let column = index % columns
        let row = index / columns

        return CGPoint(
            x: frame.minX + CGFloat(column) * cellWidth,
            y: frame.minY + CGFloat(row) * cellHeight + itemHeight / 2
        )
    }

    func isNearItemCenter(
        at screenLocation: CGPoint,
        index: Int,
        horizontalRatio: CGFloat,
        verticalRatio: CGFloat,
        visualHeight: CGFloat? = nil
    ) -> Bool {
        let center = itemCenter(at: index)
        let thresholdX = cellWidth * horizontalRatio
        let thresholdY = (visualHeight ?? itemHeight) * verticalRatio

        return abs(screenLocation.x - center.x) < thresholdX &&
            abs(screenLocation.y - center.y) < thresholdY
    }
}
