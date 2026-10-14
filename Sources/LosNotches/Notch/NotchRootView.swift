import NookCore
import SwiftUI

struct NotchRootView: View {
    let model: NotchViewModel

    private var mode: NotchMode { model.state.mode }
    private var topRadius: CGFloat { mode == .open ? 10 : 6 }
    private var bottomRadius: CGFloat { mode == .open ? 24 : 10 }

    var body: some View {
        let rect = model.shapeRect.insetBy(dx: -topRadius, dy: 0)
        ZStack(alignment: .topLeading) {
            Color.clear
            ZStack(alignment: .top) {
                NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
                    .fill(Color.black)
                    .opacity(mode == .hidden ? 0.001 : 1)
                content
                    .padding(.horizontal, topRadius)
                    .clipShape(NotchShape(topRadius: topRadius, bottomRadius: bottomRadius))
            }
            .frame(width: rect.width, height: rect.height)
            .contentShape(NotchShape(topRadius: topRadius, bottomRadius: bottomRadius))
            .onTapGesture { if mode != .open { model.send(.click) } }
            .contextMenu {
                Button("Settings…") { SettingsWindowController.shared.show() }
                Divider()
                Button("Quit LosNotches") { NSApp.terminate(nil) }
            }
            .offset(x: rect.minX, y: rect.minY)
        }
        .frame(width: model.windowFrame.width, height: model.windowFrame.height, alignment: .topLeading)
        .opacity(model.hiddenForFullscreen ? 0 : 1)
        .animation(.nook, value: mode)
        .animation(.nook, value: model.state.isHovering)
        .animation(.nook, value: model.activity?.id)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var content: some View {
        switch mode {
        case .open:
            if model.state.isDropTarget {
                DropTargetsView(model: model)
            } else if !model.settings.general.onboardingCompleted {
                OnboardingView(model: model)
            } else {
                NookView(model: model)
            }
        case .activity, .peek:
            if let a = model.activity { ActivityContainer(activity: a, model: model) }
        case .closed:
            if !model.hasNotch, !model.settings.general.transparentHandle {
                Capsule().fill(Color.white.opacity(0.35))
                    .frame(width: NotchGeometry.handleVisualSize.width, height: NotchGeometry.handleVisualSize.height)
                    .padding(.top, 3)
            }
        case .hidden:
            EmptyView()
        }
    }
}
