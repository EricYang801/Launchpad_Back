import AppKit
import SwiftUI

/// An app's icon, loaded asynchronously and cached.
struct AppIconImage: View {
    let app: AppItem
    let size: CGFloat
    private let pixels: Int
    @State private var image: NSImage?

    init(app: AppItem, size: CGFloat) {
        self.app = app
        self.size = size
        pixels = IconCache.pixels(for: size)
        _image = State(initialValue: IconCache.shared.cachedIcon(for: app.url, pixels: pixels))
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .padding(size * 0.09)
            }
        }
        .frame(width: size, height: size)
        .task(id: IconRequest(url: app.url, pixels: pixels)) {
            if let image, IconCache.shared.cachedIcon(for: app.url, pixels: pixels) === image { return }
            image = await IconCache.shared.icon(for: app.url, pixels: pixels)
        }
    }
}

private struct IconRequest: Equatable {
    let url: URL
    let pixels: Int
}

/// A folder as it appears in the grid: a translucent tile previewing the first nine apps.
struct FolderIconImage: View {
    let folder: Folder
    let size: CGFloat

    var body: some View {
        let tile = size * 0.82
        let mini = tile * 0.24
        let spacing = tile * 0.06
        RoundedRectangle(cornerRadius: tile * 0.23, style: .continuous)
            .fill(.white.opacity(0.22))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: tile * 0.23, style: .continuous))
            .frame(width: tile, height: tile)
            .overlay {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(mini), spacing: spacing), count: 3), spacing: spacing) {
                    ForEach(folder.apps.prefix(9)) { app in
                        AppIconImage(app: app, size: mini)
                    }
                }
                .frame(width: mini * 3 + spacing * 2, height: mini * 3 + spacing * 2, alignment: .top)
            }
            .frame(width: size, height: size)
    }
}

struct ItemIconImage: View {
    let item: LaunchItem
    let size: CGFloat

    var body: some View {
        switch item {
        case .app(let app): AppIconImage(app: app, size: size)
        case .folder(let folder): FolderIconImage(folder: folder, size: size)
        }
    }
}

/// One grid cell: icon, label and all the gestures (click, long press, drag).
struct IconCell: View {
    let store: LaunchpadStore
    let item: LaunchItem
    let metrics: GridMetrics
    /// The open folder this cell belongs to, or nil for the main grid.
    let folderID: UUID?
    var isSelected = false
    var isDragged = false
    var isMergeTarget = false

    var body: some View {
        let iconSize = metrics.iconSize

        VStack(spacing: iconSize * 0.07) {
            ItemIconImage(item: item, size: iconSize)
                .background {
                    if isMergeTarget {
                        RoundedRectangle(cornerRadius: iconSize * 0.26, style: .continuous)
                            .fill(.white.opacity(0.28))
                            .frame(width: iconSize * 1.12, height: iconSize * 1.12)
                    }
                }
                .scaleEffect(isMergeTarget ? 1.1 : 1)
            Text(item.name)
                .font(.system(size: max(11, (iconSize * 0.15).rounded()), weight: .regular))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 1.5, y: 0.5)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: metrics.cellSize.width * 0.92)
        }
        .padding(iconSize * 0.08)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: iconSize * 0.2, style: .continuous).fill(.white.opacity(0.2))
            }
        }
        .modifier(Wiggle(active: store.isEditing && !isDragged, clockwise: item.id.hashValue.isMultiple(of: 2)))
        .opacity(isDragged ? 0.001 : 1)
        .contentShape(Rectangle())
        .highPriorityGesture(dragGesture, including: store.isSearching ? .subviews : .all)
        .simultaneousGesture(TapGesture().onEnded { store.activate(item) })
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.6).onEnded { _ in
            guard !store.isSearching else { return }
            withAnimation { store.isEditing = true }
        })
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(LaunchpadView.coordinateSpace))
            .onChanged { store.dragChanged(item, from: folderID, to: $0.location) }
            .onEnded { _ in store.endDrag() }
    }
}

/// The edit-mode jiggle. Neighbouring icons rock in opposite directions so the grid doesn't move in lockstep.
struct Wiggle: ViewModifier {
    let active: Bool
    let clockwise: Bool

    func body(content: Content) -> some View {
        if active {
            let angle = clockwise ? 1.6 : -1.6
            content.keyframeAnimator(initialValue: 0.0, repeating: true) { view, value in
                view.rotationEffect(.degrees(value))
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(angle, duration: 0.12)
                    CubicKeyframe(-angle, duration: 0.24)
                    CubicKeyframe(0, duration: 0.12)
                }
            }
        } else {
            content
        }
    }
}

/// Pages of icons laid out on `metrics`, sliding horizontally. Only the visible page and its neighbours are built.
struct PagedIcons: View {
    let store: LaunchpadStore
    let items: [LaunchItem]
    let metrics: GridMetrics
    let page: Int
    let pageWidth: CGFloat
    var offset: CGFloat = 0
    var folderID: UUID?
    var selection: Int?

    var body: some View {
        let draggedID = store.drag?.item.id
        let mergeTarget = store.drag?.mergeTarget
        let visible = items.enumerated().filter { index, item in
            abs(index / metrics.perPage - page) <= 1 || item.id == draggedID
        }
        ZStack {
            ForEach(visible, id: \.element.id) { index, item in
                let center = metrics.center(of: index)
                IconCell(
                    store: store, item: item, metrics: metrics, folderID: folderID,
                    isSelected: index == selection, isDragged: item.id == draggedID, isMergeTarget: item.id == mergeTarget
                )
                    .position(x: center.x + CGFloat(index / metrics.perPage - page) * pageWidth + offset, y: center.y)
            }
        }
    }
}
