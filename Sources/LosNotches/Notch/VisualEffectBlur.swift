import AppKit
import SwiftUI

/// Behind-window blur used for the translucent open Nook.
struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

extension View {
    /// Native Liquid Glass on macOS 26+, a material capsule before that.
    @ViewBuilder func nookGlass(round: Bool) -> some View {
        if #available(macOS 26, *) {
            if round { glassEffect(.regular, in: Capsule()) } else { glassEffect(.regular, in: RoundedRectangle(cornerRadius: 6)) }
        } else {
            if round { background(Capsule().fill(.white.opacity(0.1))) } else { background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.1))) }
        }
    }
}
