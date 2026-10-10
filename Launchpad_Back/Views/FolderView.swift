import SwiftUI

/// An open folder: its editable name above a translucent panel of paged icons.
struct FolderView: View {
    let store: LaunchpadStore
    let folder: Folder
    @State private var name: String
    @FocusState private var nameFocused: Bool

    init(store: LaunchpadStore, folder: Folder) {
        self.store = store
        self.folder = folder
        _name = State(initialValue: folder.name)
    }

    var body: some View {
        let grid = store.folderMetrics(for: folder)
        let apps = store.folderApps(folder).map(LaunchItem.app)
        let pageCount = grid.pageCount(for: apps.count)
        let panel = grid.frame.insetBy(dx: -grid.cellSize.width * 0.15, dy: -grid.cellSize.height * 0.12)

        ZStack {
            // Clicking outside the panel closes the folder.
            Color.black.opacity(0.001)
                .onTapGesture { store.closeFolder() }

            TextField("", text: $name)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.white)
                .tint(.white)
                .frame(width: panel.width)
                .focused($nameFocused)
                .onSubmit { nameFocused = false }
                .position(x: panel.midX, y: panel.minY - 40)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white.opacity(0.12))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .frame(width: panel.width, height: panel.height)
                .position(x: panel.midX, y: panel.midY)
                .onTapGesture { nameFocused = false }

            PagedIcons(store: store, items: apps, metrics: grid, page: store.folderPage, pageWidth: panel.width, folderID: folder.id)
                .mask {
                    Rectangle().frame(width: panel.width, height: panel.height).position(x: panel.midX, y: panel.midY)
                }

            if pageCount > 1 {
                PageDots(count: pageCount, current: store.folderPage) { store.goToPage($0) }
                    .position(x: panel.midX, y: panel.maxY + 20)
            }
        }
        .onChange(of: nameFocused) {
            store.isRenaming = nameFocused
            if !nameFocused { store.rename(folder.id, to: name) }
        }
        .onChange(of: folder.name) { name = folder.name }
        .onDisappear {
            store.isRenaming = false
            if name != folder.name { store.rename(folder.id, to: name) }
        }
    }
}
