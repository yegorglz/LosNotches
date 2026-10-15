import NookCore
import SwiftUI

struct NookView: View {
    let model: NotchViewModel

    var body: some View {
        let s = model.settings
        let layout = NookGridLayout.layout(s.nook.widgets)
        let carded = s.appearance.widgetBackgroundOpacity > 0 || s.appearance.widgetBorderWidth > 0
        VStack(spacing: 0) {
            topBar.frame(height: max(model.closedScreenRect.height, 28))
            if model.tab == .tray {
                TrayWidgetView(model: model, wide: true)
                    .padding(.horizontal, 6)
                    .frame(width: NookGridLayout.width(cells: NookGridLayout.maxCells), height: 150)
            } else {
            ZStack(alignment: .topLeading) {
                ForEach(Array(layout.frames.enumerated()), id: \.element.kind) { i, f in
                    WidgetRegistry.view(for: f.kind, model: model)
                        .padding(s.general.widgetPadding / 2 + (carded ? 4 + s.appearance.widgetCornerRadius * 0.3 : 0))
                        .frame(width: f.width, height: 150)
                        .widgetCard(s.appearance)
                        .offset(x: f.x)
                    if s.general.showDividers, !carded, i > 0 {
                        Rectangle().fill(.white.opacity(0.08)).frame(width: 1, height: 120)
                            .offset(x: f.x - NookGridLayout.spacing / 2, y: 15)
                    }
                }
            }
            .frame(width: NookGridLayout.width(cells: NookGridLayout.maxCells), height: 150, alignment: .topLeading)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }

    private func tabButton(_ t: NookTab, _ symbol: String, _ title: String) -> some View {
        Button { withAnimation(.nook) { model.tab = t } } label: {
            Label(title, systemImage: symbol).labelStyle(.titleAndIcon).font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(NookButtonStyle())
        .opacity(model.tab == t ? 1 : 0.45)
    }

    private var topBar: some View {
        HStack(spacing: 6) {
            tabButton(.nook, "square.grid.2x2.fill", "Nook")
            tabButton(.tray, "tray.full.fill", "Tray\(AppServices.shared.tray.items.isEmpty ? "" : " \(AppServices.shared.tray.items.count)")")
            Spacer()
            Button { model.send(.toggleLock) } label: {
                Image(systemName: model.state.isLocked ? "lock.fill" : "lock.open")
            }
            .help("Keep the Nook open")
            Button { SettingsWindowController.shared.show() } label: { Image(systemName: "gearshape") }
        }
        .buttonStyle(NookButtonStyle())
        .font(.system(size: 12))
        .padding(.horizontal, 20)
    }
}

extension View {
    /// User-styled widget card: fill, border and corner radius from Appearance settings.
    func widgetCard(_ a: AppearanceSettings) -> some View {
        let shape = RoundedRectangle(cornerRadius: max(0, a.widgetCornerRadius), style: .continuous)
        return background(shape.fill(Color.white.opacity(a.widgetBackgroundOpacity)))
            .overlay(shape.strokeBorder(Color(hex: a.widgetBorderColorHex).opacity(a.widgetBorderOpacity), lineWidth: max(0, a.widgetBorderWidth)))
    }
}

struct NookButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 7).padding(.vertical, 4)
            .nookGlass(round: AppServices.shared.settings.settings.general.preferRoundButtons)
            .brightness(configuration.isPressed ? 0.15 : 0)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

enum WidgetRegistry {
    @MainActor @ViewBuilder
    static func view(for kind: WidgetKind, model: NotchViewModel) -> some View {
        switch kind {
        case .media: MediaWidgetView()
        case .calendar: CalendarWidgetView()
        case .notes: NotesWidgetView(model: model)
        case .todos: TodoWidgetView(model: model)
        case .timer: TimerWidgetView(model: model)
        case .mirror: MirrorWidgetView()
        case .shortcuts: ShortcutsWidgetView(model: model)
        case .quickApps: QuickAppsWidgetView(model: model)
        case .tray: TrayWidgetView(model: model)
        }
    }
}

struct WidgetHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased()).font(.system(size: 9, weight: .bold)).opacity(0.45)
    }
}
