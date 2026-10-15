@preconcurrency import AVFoundation // AVCaptureSession is used only on its own serial queue
import NookCore
import SwiftUI

@MainActor
@Observable
final class CameraController {
    private(set) var authorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    private(set) var devices: [(id: String, name: String)] = []
    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let queue = DispatchQueue(label: "losnotches.camera")
    @ObservationIgnored private var users = 0

    init(settings: SettingsStore) {
        self.settings = settings
        refreshDevices()
    }

    private var discovery: AVCaptureDevice.DiscoverySession {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera], mediaType: .video, position: .unspecified)
    }

    func refreshDevices() { devices = discovery.devices.map { ($0.uniqueID, $0.localizedName) } }

    func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { ok in
            DispatchQueue.main.async { self.authorized = ok; if ok { self.restart() } }
        }
    }

    /// Reference-counted so several displays can show the mirror; camera stops when nobody shows it.
    func acquire() { users += 1; if users == 1 { restart() } }

    func release() {
        users = max(0, users - 1)
        if users == 0 { queue.async { [session] in session.stopRunning() } }
    }

    func restart() {
        guard authorized, users > 0 else { return }
        refreshDevices()
        let wanted = settings.settings.mirror.deviceUniqueID
        let device = discovery.devices.first { $0.uniqueID == wanted } ?? AVCaptureDevice.default(for: .video)
        let mirrored = settings.settings.mirror.mirrored
        queue.async { [session] in
            session.beginConfiguration()
            session.sessionPreset = .high
            session.inputs.forEach { session.removeInput($0) }
            if let device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) { session.addInput(input) }
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
            DispatchQueue.main.async { PreviewLayerRegistry.setMirrored(mirrored) }
        }
    }
}

/// Keeps preview layers in sync with the "Mirror video" setting.
@MainActor enum PreviewLayerRegistry {
    static var layers = NSHashTable<AVCaptureVideoPreviewLayer>.weakObjects()
    static func setMirrored(_ m: Bool) {
        for l in layers.allObjects {
            guard let c = l.connection, c.isVideoMirroringSupported else { continue }
            c.automaticallyAdjustsVideoMirroring = false
            c.isVideoMirrored = m
        }
    }
}

struct MirrorWidgetView: View {
    private var camera: CameraController { AppServices.shared.camera }

    var body: some View {
        Group {
            if camera.authorized {
                CameraPreview(session: camera.session)
                    .onAppear { camera.acquire() }
                    .onDisappear { camera.release() }
                    .onChange(of: AppServices.shared.settings.settings.mirror) { _, _ in camera.restart() }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "person.crop.square").font(.system(size: 22)).opacity(0.5)
                    Text("Mirror").font(.system(size: 11, weight: .semibold))
                    Button("Allow camera") { camera.requestAccess() }.controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.06))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        v.layer = layer
        v.wantsLayer = true
        PreviewLayerRegistry.layers.add(layer)
        PreviewLayerRegistry.setMirrored(AppServices.shared.settings.settings.mirror.mirrored)
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {}
}
