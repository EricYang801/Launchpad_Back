import Foundation
import Observation

/// User settings, persisted in `UserDefaults`.
@Observable
final class Preferences {
    static let shared = Preferences()

    /// Launchpad's default grid is 7 × 5.
    static let defaultColumns = 7
    static let defaultRows = 5
    static let columnRange = 4...12
    static let rowRange = 3...9

    var columns: Int { didSet { defaults.set(columns, forKey: "columns") } }
    var rows: Int { didSet { defaults.set(rows, forKey: "rows") } }
    var showsDockIcon: Bool { didSet { defaults.set(showsDockIcon, forKey: "showsDockIcon") } }
    var hotKey: HotKey {
        didSet { defaults.set(try? JSONEncoder().encode(hotKey), forKey: "globalToggleHotKey") }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        columns = (defaults.object(forKey: "columns") as? Int).map { Self.columnRange.clamped($0) } ?? Self.defaultColumns
        rows = (defaults.object(forKey: "rows") as? Int).map { Self.rowRange.clamped($0) } ?? Self.defaultRows
        showsDockIcon = defaults.object(forKey: "showsDockIcon") as? Bool ?? true
        hotKey = defaults.data(forKey: "globalToggleHotKey").flatMap { try? JSONDecoder().decode(HotKey.self, from: $0) } ?? .default
    }
}

extension ClosedRange<Int> {
    nonisolated func clamped(_ value: Int) -> Int {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
