import AppKit
import NookCore
import SwiftUI

@MainActor
@Observable
final class ShortcutsService {
    private(set) var all: [String] = []

    func reload() async {
        let out = await Task.detached { () -> String in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            p.arguments = ["list"]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            guard (try? p.run()) != nil else { return "" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return String(decoding: data, as: UTF8.self)
        }.value
        all = ShortcutsListParser.parse(out)
    }

    func run(_ name: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        p.arguments = ["run", name]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }
}

struct ShortcutsWidgetView: View {
    let model: NotchViewModel
    var body: some View {
        let names = AppServices.shared.settings.settings.content.shortcutNames
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: "Shortcuts")
            if names.isEmpty {
                Text("Choose your shortcuts in settings.").font(.system(size: 10)).opacity(0.45)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture { SettingsWindowController.shared.show(tab: .nook) }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.fixed(48)), GridItem(.fixed(48))], spacing: 6) {
                        ForEach(names, id: \.self) { name in
                            Button { AppServices.shared.shortcuts.run(name) } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: "square.stack.3d.up.fill").font(.system(size: 14))
                                    Text(name).font(.system(size: 9, weight: .medium)).lineLimit(1)
                                }
                                .frame(width: 92, height: 46)
                                .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08)))
                            }
                            .buttonStyle(PressScaleStyle())
                        }
                    }
                }
            }
        }
    }
}

struct QuickAppsWidgetView: View {
    let model: NotchViewModel
    var body: some View {
        let paths = AppServices.shared.settings.settings.content.quickAppPaths
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: "Quick Apps")
            if paths.isEmpty {
                Text("Add apps in settings.").font(.system(size: 10)).opacity(0.45).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture { SettingsWindowController.shared.show(tab: .nook) }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 6)], spacing: 6) {
                    ForEach(paths, id: \.self) { path in
                        Button {
                            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: .init())
                            model.send(.closeRequested)
                        } label: {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 36, height: 36)
                        }
                        .buttonStyle(PressScaleStyle())
                        .help(FileManager.default.displayName(atPath: path))
                    }
                }
            }
        }
    }
}
