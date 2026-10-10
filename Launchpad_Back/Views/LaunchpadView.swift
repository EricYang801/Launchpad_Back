import AppKit
import SwiftUI

/// The full-screen Launchpad: blurred wallpaper, search field, paged icons, page dots and an open folder on top.
struct LaunchpadView: View {
    static let coordinateSpace = "launchpad"

    @Bindable var store: LaunchpadStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let metrics = store.metrics
            let presented = store.isPresented

            ZStack {
                Backdrop(image: store.backdrop)
                    .opacity(presented ? 1 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { store.backgroundTapped() }
                    .gesture(swipeGesture)

                ZStack {
                    SearchField(text: $store.query, focused: $searchFocused)
                        .position(x: size.width / 2, y: metrics.frame.minY * 0.5)

                    PagedIcons(
                        store: store,
                        items: store.gridItems,
                        metrics: metrics,
                        page: store.page,
                        pageWidth: size.width,
                        offset: store.pageOffset,
                        selection: store.isSearching ? store.selection : nil
                    )

                    if store.isSearching && store.searchResults.isEmpty {
                        Text("No Results")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .position(x: size.width / 2, y: size.height / 2)
                    } else if store.pageCount > 1 {
                        PageDots(count: store.pageCount, current: store.page) { store.goToPage($0) }
                            .position(x: size.width / 2, y: metrics.frame.maxY + (size.height - metrics.frame.maxY) * 0.45)
                    }
                }
                .blur(radius: store.showsFolder ? 24 : 0)
                .scaleEffect(presented ? 1 : 1.08)
                .opacity(presented ? 1 : 0)

                if let folder = store.openFolder {
                    FolderView(store: store, folder: folder)
                        .id(folder.id)
                        .opacity(store.showsFolder && presented ? 1 : 0)
                        .allowsHitTesting(store.showsFolder)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }

                if let item = store.drag?.item {
                    DragGhost(store: store, item: item, size: metrics.iconSize)
                }
            }
            .coordinateSpace(.named(Self.coordinateSpace))
            .onAppear { store.size = size }
            .onChange(of: size) { store.size = size }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onChange(of: store.isPresented) {
            if store.isPresented { searchFocused = true }
        }
        .onChange(of: store.query) {
            if !store.query.isEmpty { searchFocused = true }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { store.swipeChanged($0.translation.width) }
            .onEnded { store.swipeEnded($0.translation.width, velocity: $0.predictedEndTranslation.width - $0.translation.width) }
    }
}

/// The icon under the pointer while dragging; the only view that follows every mouse move.
struct DragGhost: View {
    let store: LaunchpadStore
    let item: LaunchItem
    let size: CGFloat

    var body: some View {
        ItemIconImage(item: item, size: size)
            .scaleEffect(1.08)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
            .position(store.dragLocation)
            .allowsHitTesting(false)
    }
}

/// The desktop picture, blurred; falls back to a system material when the wallpaper can't be read.
struct Backdrop: View {
    let image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                VisualEffectBackground()
            }
            Color.black.opacity(0.2)
        }
        .ignoresSafeArea()
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct SearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))
            TextField("", text: $text, prompt: Text("Search").foregroundStyle(.white.opacity(0.5)))
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .focused(focused)
        }
        .font(.system(size: 13))
        .tint(.white)
        .padding(.horizontal, 8)
        .frame(width: 230, height: 28)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
    }
}

struct PageDots: View {
    let count: Int
    let current: Int
    let select: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(index == current ? 0.9 : 0.35))
                    .frame(width: 8, height: 8)
                    .padding(5)
                    .contentShape(Rectangle())
                    .onTapGesture { select(index) }
            }
        }
        .animation(.easeOut(duration: 0.2), value: current)
    }
}
