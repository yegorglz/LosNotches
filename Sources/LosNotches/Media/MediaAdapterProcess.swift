import Foundation
import NookCore

/// Runs `/usr/bin/perl mediaremote-adapter.pl <framework> stream` and restarts it with backoff if it dies.
final class MediaAdapterProcess {
    var onUpdate: ((NowPlaying?) -> Void)?
    private let scriptURL: URL
    private let frameworkURL: URL
    private var process: Process?
    private var decoder = AdapterStreamDecoder()
    private var lines = LineBuffer()
    private var backoff = RestartBackoff()
    private var startedAt = Date()
    private var stopped = true
    private let queue = DispatchQueue(label: "losnotches.media-adapter")

    init?(bundle: Bundle = .main) {
        guard let script = bundle.url(forResource: "mediaremote-adapter", withExtension: "pl"),
              let fw = bundle.privateFrameworksURL?.appendingPathComponent("MediaRemoteAdapter.framework"),
              FileManager.default.fileExists(atPath: fw.path) else { return nil }
        scriptURL = script
        frameworkURL = fw
    }

    func start() {
        queue.async {
            // Clear orphans from a previous run that crashed (children outlive a crashed parent).
            SystemProcessRunner().run("/usr/bin/pkill", ["-9", "-f", self.scriptURL.path])
            self.stopped = false
            self.launch()
        }
    }

    /// SIGKILL: the child inherits our ignored SIGTERM (see AppDelegate signal handlers), so terminate() won't do.
    func stop() {
        queue.sync {
            stopped = true
            if let p = process, p.isRunning { kill(p.processIdentifier, SIGKILL) }
            process = nil
        }
    }

    func send(_ c: MediaCommand) { oneShot(["send", String(c.adapterID)]) }
    func seek(to seconds: TimeInterval) { oneShot(["seek", String(Int(max(0, seconds) * 1_000_000))]) }

    private func launch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [scriptURL.path, frameworkURL.path, "stream", "--debounce=50"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        decoder = AdapterStreamDecoder()
        lines = LineBuffer()
        out.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard let self, !data.isEmpty else { return }
            self.queue.async { self.consume(data) }
        }
        p.terminationHandler = { [weak self] _ in
            out.fileHandleForReading.readabilityHandler = nil
            self?.queue.async { self?.scheduleRestart() }
        }
        do {
            try p.run()
            process = p
            startedAt = Date()
        } catch {
            scheduleRestart()
        }
    }

    private func consume(_ data: Data) {
        for line in lines.append(data) where !line.isEmpty {
            guard let now = try? decoder.ingest(line: line) else { continue } // malformed: skip, keep state
            DispatchQueue.main.async { self.onUpdate?(now) }
        }
    }

    private func scheduleRestart() {
        guard !stopped else { return }
        process = nil
        if Date().timeIntervalSince(startedAt) > 10 { backoff.reset() }
        queue.asyncAfter(deadline: .now() + backoff.nextDelay()) { [weak self] in
            guard let self, !self.stopped else { return }
            self.launch()
        }
    }

    private func oneShot(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [scriptURL.path, frameworkURL.path] + args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }
}
