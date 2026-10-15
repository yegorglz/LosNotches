import NookCore
import SwiftUI

struct NotchRootView: View {
    let model: NotchViewModel

    private var mode: NotchMode { model.state.mode }
    private var look: AppearanceSettings { model.settings.appearance }
    private var topRadius: CGFloat { look.flareRadius + (mode == .open ? 4 : 0) }
    private var bottomRadius: CGFloat { mode == .open ? look.openCornerRadius : look.closedCornerRadius }
    private var showsBorder: Bool { look.islandBorderWidth > 0 && mode != .hidden && !(mode == .closed && !model.hasNotch) }

    var body: some View {
        let rect = model.shapeRect.insetBy(dx: -topRadius, dy: 0)
        ZStack(alignment: .topLeading) {
            Color.clear
            ZStack(alignment: .top) {
                background
                    .opacity(mode == .hidden || (mode == .closed && !model.hasNotch && !model.settings.general.fakeNotchOnPlainScreens) ? 0.001 : 1)
                    .shadow(color: .black.opacity(mode == .open && look.openShadow ? 0.45 : 0), radius: 10, y: 5)
                content
                    .padding(.horizontal, topRadius)
                    .clipShape(NotchShape(topRadius: topRadius, bottomRadius: bottomRadius))
                if showsBorder {
                    NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, outlineOnly: true)
                        .stroke(Color(hex: look.islandBorderColorHex).opacity(look.islandBorderOpacity), lineWidth: look.islandBorderWidth)
                        .allowsHitTesting(false)
                }
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

    @ViewBuilder private var background: some View {
        let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
        if mode == .open, look.translucentBackground {
            ZStack {
                VisualEffectBlur().clipShape(shape)
                shape.fill(Color.black.opacity(0.55))
            }
        } else {
            shape.fill(Color.black)
        }
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
            if !model.hasNotch, !model.settings.general.transparentHandle, !model.settings.general.fakeNotchOnPlainScreens {
                Capsule().fill(Color.white.opacity(0.35))
                    .frame(width: NotchGeometry.handleVisualSize.width, height: NotchGeometry.handleVisualSize.height)
                    .padding(.top, 3)
            }
        case .hidden:
            EmptyView()
        }
    }
}
